package tests

import (
	"bufio"
	"errors"
	"fmt"
	"maps"
	"os"
	"os/exec"
	"regexp"
	"sort"
	"strings"
	"testing"
	"time"

	utils "github.com/terraform-ibm-modules/terraform-ibm-hpc/common_utils"
	"golang.org/x/crypto/ssh"
)

const (
	defaultSleepDuration           = 30 * time.Second
	timeOutForDynamicNodeDisappear = 15 * time.Minute
	jobCompletionWaitTime          = 50 * time.Second
	dynamicNodeWaitTime            = 3 * time.Minute
	appCenterPort                  = 8443
)

// LSFMTUCheck checks the MTU setting for multiple nodes of a specified type.
// It returns an error if any node's MTU is not set to 9000.
func LSFMTUCheck(t *testing.T, sClient *ssh.Client, ipsList []string, logger *utils.AggregatedLogger) error {
	// commands to check MTU on different OS types
	ubuntuMTUCheckCmd := "ip addr show"
	rhelMTUCheckCmd := "ifconfig"

	// Check if the node list is empty
	if len(ipsList) == 0 {
		return fmt.Errorf("ERROR: ips cannot be empty")
	}

	// Loop through each IP in the list
	for _, ip := range ipsList {
		var mtuCmd string

		// Get the OS name of the compute node.
		osName, osNameErr := GetOSNameOfNode(t, sClient, ip, logger)
		if osNameErr != nil {
			// Determine the expected command to check MTU based on the OS.
			switch osName {
			case "Ubuntu":
				mtuCmd = ubuntuMTUCheckCmd
			default:
				mtuCmd = rhelMTUCheckCmd
			}
		} else {
			// Return error if OS name retrieval fails.
			return osNameErr
		}

		// Build the SSH command to check MTU on the node
		command := fmt.Sprintf("ssh %s %s", ip, mtuCmd)

		// Execute the command and get the output
		output, err := utils.RunCommandInSSHSession(sClient, command)
		if err != nil {
			return fmt.Errorf("failed to execute '%s' command on (%s) node", mtuCmd, ip)
		}

		// Check if the output contains "mtu 9000"
		if !utils.VerifyDataContains(t, output, "mtu 9000", logger) {
			return fmt.Errorf("MTU is not set to 9000 for (%s) node and found:\n%s", ip, output)
		}

		// Log a success message if MTU is set to 9000
		logger.Info(t, fmt.Sprintf("MTU is set to 9000 for (%s) node", ip))
	}

	return nil
}

// LSFIPRouteCheck verifies that the IP routes on the specified nodes have the MTU set to 9000.
// It returns an error if any node's IP route does not have the expected MTU value.
func LSFIPRouteCheck(t *testing.T, sClient *ssh.Client, ipsList []string, logger *utils.AggregatedLogger) error {

	// Check if the node list is empty
	if len(ipsList) == 0 {
		return fmt.Errorf("IPs list cannot be empty")
	}

	// Loop through each IP one by one
	for _, ip := range ipsList {
		command := fmt.Sprintf("ssh %s ip route", ip)
		output, err := utils.RunCommandInSSHSession(sClient, command)
		if err != nil {
			return fmt.Errorf("failed to execute 'ip route' command on (%s) node: %v", ip, err)
		}

		if !utils.VerifyDataContains(t, output, "mtu 9000", logger) {
			return fmt.Errorf("IP route MTU is not set to 9000 for (%s) node. Found: \n%s", ip, output)
		}
		logger.Info(t, fmt.Sprintf("IP route MTU is set to 9000 for (%s) node", ip))
	}

	return nil
}

// LSFCheckClusterID checks if the provided cluster ID matches the expected value.
// It uses the provided SSH client to execute the 'lsid' command and verifies
// if the expected cluster ID is present in the command output.
// Returns an error if the checks fail.
func LSFCheckClusterID(t *testing.T, sClient *ssh.Client, expectedClusterID string, logger *utils.AggregatedLogger) error {

	// Execute the 'lsid' command to get the cluster ID
	command := "source /opt/ibm/lsf/conf/profile.lsf; lsid"
	output, err := utils.RunCommandInSSHSession(sClient, command)
	if err != nil {
		return fmt.Errorf("failed to execute 'lsid' command: %w", err)
	}

	// Verify if the expected cluster ID is present in the output
	if !utils.VerifyDataContains(t, output, "My cluster name is "+expectedClusterID, logger) {
		// Extract actual cluster version from the output for better error reporting
		actualValue := strings.TrimSpace(strings.Split(strings.Split(output, "My cluster name is")[1], "My master name is")[0])
		return fmt.Errorf("expected cluster ID %s , but found %s", expectedClusterID, actualValue)
	}
	// Log success if no errors occurred
	logger.Info(t, fmt.Sprintf("Cluster ID is set as expected : %s", expectedClusterID))
	return nil
}

// LSFCheckMasterName checks if the provided master name matches the expected value.
// It uses the provided SSH client to execute the 'lsid' command and verifies
// if the expected master name is present in the command output.
// Returns an error if the checks fail.
func LSFCheckMasterName(t *testing.T, sClient *ssh.Client, expectedMasterName string, logger *utils.AggregatedLogger) error {
	// Execute the 'lsid' command to get the cluster ID
	command := "source /opt/ibm/lsf/conf/profile.lsf; lsid"
	output, err := utils.RunCommandInSSHSession(sClient, command)
	if err != nil {
		return fmt.Errorf("failed to execute 'lsid' command: %w", err)
	}

	// Verify if the expected master name is present in the output
	if !utils.VerifyDataContains(t, output, "My master name is "+expectedMasterName+"-mgmt-1", logger) {
		// Extract actual cluster version from the output for better error reporting
		actualValue := strings.TrimSpace(strings.Split(output, "My master name is")[1])
		return fmt.Errorf("expected master name %s , but found %s", expectedMasterName, actualValue)
	}
	// Log success if no errors occurred
	logger.Info(t, fmt.Sprintf("Master name is set as expected : %s", expectedMasterName))
	return nil
}

// HPCCheckReservationID verifies if the provided SSH client's 'lsid' command output
// contains the expected Reservation ID. Logs and returns an error if verification fails.
func HPCCheckReservationID(t *testing.T, sClient *ssh.Client, expectedReservationID string, logger *utils.AggregatedLogger) error {

	ibmCloudHPCConfigPath := "/opt/ibm/lsf/conf/resource_connector/ibmcloudhpc/conf/ibmcloudhpc_config.json"

	command := fmt.Sprintf("cat %s", ibmCloudHPCConfigPath)
	output, err := utils.RunCommandInSSHSession(sClient, command)
	if err != nil || !utils.VerifyDataContains(t, output, expectedReservationID, logger) {
		return fmt.Errorf("failed Reservation ID verification: %w", err)
	}
	// Log success if no errors occurred
	logger.Info(t, fmt.Sprintf("Reservation ID verified: %s", expectedReservationID))
	return nil
}

// LSFCheckManagementNodeCount checks if the actual count of management nodes matches the expected count.
// It uses the provided SSH client to execute the 'bhosts' command with filters to
// count the number of nodes containing 'mgmt' in their names. The function then verifies
// if the actual count matches the expected count.
// Returns an error if the checks fail.
func LSFCheckManagementNodeCount(t *testing.T, sClient *ssh.Client, expectedManagementCount string, logger *utils.AggregatedLogger) error {
	// Execute the 'bhosts' command to get the management node count
	command := "bhosts -w | grep 'mgmt' | wc -l"
	output, err := utils.RunCommandInSSHSession(sClient, command)
	if err != nil {
		return fmt.Errorf("failed to execute 'bhosts' command: %w", err)
	}

	// Verify if the expected management node count is present in the output
	if !utils.VerifyDataContains(t, output, expectedManagementCount, logger) {
		return fmt.Errorf("expected %s management nodes, but found %s", expectedManagementCount, strings.TrimSpace(output))
	}

	// Log success if no errors occurred
	logger.Info(t, fmt.Sprintf("Management node count is as expected: %s", expectedManagementCount))
	return nil
}

// LSFRestartDaemons restarts the LSF daemons on the provided SSH client.
// It executes the 'lsf_daemons restart' command as root, checks for a successful
// restart, and waits for LSF to start up.
func LSFRestartDaemons(t *testing.T, sClient *ssh.Client, logger *utils.AggregatedLogger) error {

	// Restart LSF daemons
	restartCmd := "sudo su -l root -c 'lsf_daemons restart'"
	out, err := utils.RunCommandInSSHSession(sClient, restartCmd)
	if err != nil {
		return fmt.Errorf("failed to run 'lsf_daemons restart' command: %w", err)
	}

	logger.Info(t, string(out))

	time.Sleep(defaultSleepDuration)

	// Check if the restart was successful
	if !(utils.VerifyDataContains(t, string(out), "Stopping", logger) && utils.VerifyDataContains(t, string(out), "Starting", logger)) {
		return fmt.Errorf("lsf_daemons restart failed")
	}

	// Wait for LSF to start up
	for {
		// Run 'bhosts -w' command on the remote SSH server
		command := "bhosts -w"
		startOut, err := utils.RunCommandInSSHSession(sClient, command)
		if err != nil {
			return fmt.Errorf("failed to run 'bhosts' command: %w", err)
		}
		if !utils.VerifyDataContains(t, string(startOut), "LSF is down", logger) {
			break
		}
		time.Sleep(5 * time.Second)
	}
	// Log success if no errors occurred
	logger.Info(t, "lsf_daemons restart successfully")
	return nil
}

// LSFControlBctrld performs start or stop operations on the bctrld daemon on the specified machine.
// It returns an error if any step fails or if an invalid value (other than 'start' or 'stop') is provided.
// It executes the 'bctrld' command with the specified operation and waits for the daemon to start or stop.
func LSFControlBctrld(t *testing.T, sClient *ssh.Client, startOrStop string, logger *utils.AggregatedLogger) error {
	// Make startOrStop case-insensitive
	startOrStop = strings.ToLower(startOrStop)

	// Validate the operation type
	if startOrStop != "start" && startOrStop != "stop" {
		return fmt.Errorf("invalid operation type. Please specify 'start' or 'stop'")
	}

	var command string

	// Construct the command based on the operation type
	if startOrStop == "stop" {
		command = "bctrld stop sbd"
	} else {
		command = "sudo su -l root -c 'systemctl restart lsfd'"
	}

	// Execute the command
	if _, err := utils.RunCommandInSSHSession(sClient, command); err != nil {
		return fmt.Errorf("failed to run '%s' command: %w", command, err)
	}

	// Sleep for a specified duration to allow time for the daemon to start or stop
	if startOrStop == "stop" {
		time.Sleep(30 * time.Second)
	} else {
		time.Sleep(120 * time.Second)
	}

	// Check the status of the daemon using the 'bhosts -w' command on the remote SSH server
	statusCmd := "bhosts -w"
	out, err := utils.RunCommandInSSHSession(sClient, statusCmd)
	if err != nil {
		return fmt.Errorf("failed to run 'bhosts' command: %w", err)
	}

	// Count the number of unreachable nodes
	unreachCount := strings.Count(string(out), "unreach")

	// Check the output based on the startOrStop parameter
	expectedUnreachCount := 0
	if startOrStop == "stop" {
		expectedUnreachCount = 1
	}

	if unreachCount != expectedUnreachCount {
		// If the unreachable node count does not match the expected count, return an error
		return fmt.Errorf("failed to %s the sbd daemon on the management node", startOrStop)
	}

	// Log success if no errors occurred
	logger.Info(t, fmt.Sprintf("Daemon %s successfully", startOrStop))
	return nil
}

// LSFCheckIntelOneMpiOnComputeNodes checks the Intel OneAPI MPI on compute nodes.
// It verifies the existence of setvars.sh and mpi in the OneAPI folder, and initializes the OneAPI environment.
// and returns an error if any check fails.
func LSFCheckIntelOneMpiOnComputeNodes(t *testing.T, sClient *ssh.Client, ipsList []string, logger *utils.AggregatedLogger) error {

	// Check if the node list is empty
	if len(ipsList) == 0 {
		return fmt.Errorf("ERROR: ips cannot be empty")
	}

	// Check Intel OneAPI MPI on each compute node
	for _, ip := range ipsList {
		// Check if OneAPI folder exists and contains setvars.sh and mpi
		checkCmd := fmt.Sprintf("ssh %s 'ls /opt/intel/oneapi'", ip)

		checkOutput, checkErr := utils.RunCommandInSSHSession(sClient, checkCmd)
		if checkErr != nil {
			return fmt.Errorf("failed to run '%s' command: %w", checkCmd, checkErr)
		}

		if !utils.VerifyDataContains(t, checkOutput, "setvars.sh", logger) && !utils.VerifyDataContains(t, checkOutput, "mpi", logger) {
			return fmt.Errorf("setvars.sh or mpi not found in OneAPI folder: %s", checkOutput)
		}

		// Initialize OneAPI environment
		initCmd := fmt.Sprintf("ssh -t %s 'sudo su -l root -c \". /opt/intel/oneapi/setvars.sh\"'", ip)
		initOutput, initErr := utils.RunCommandInSSHSession(sClient, initCmd)
		if initErr != nil {
			return fmt.Errorf("failed to run '%s' command: %w", initCmd, initErr)
		}

		if !utils.VerifyDataContains(t, initOutput, ":: oneAPI environment initialized ::", logger) {
			return fmt.Errorf("OneAPI environment not initialized on machine: %s and but found : \n%s", ip, initOutput)
		}
		logger.Info(t, fmt.Sprintf("Intel OneAPI MPI successfully checked and initialized on compute machine: %s", ip))

	}

	return nil
}

// LSFRebootInstance reboots an LSF instance using SSH.
// It executes the 'sudo su -l root -c 'reboot” command on the provided SSH client.
func LSFRebootInstance(t *testing.T, sClient *ssh.Client, logger *utils.AggregatedLogger) error {

	// Execute the "sudo su -l root -c 'reboot'" command to reboot the cluster
	rebootCmd := "sudo su -l root -c 'reboot'"

	_, checkErr := utils.RunCommandInSSHSession(sClient, rebootCmd)
	if !strings.Contains(checkErr.Error(), "remote command exited without exit status or exit signal") {
		return fmt.Errorf("instance reboot failed")
	}

	// Sleep for a short duration to allow the instance to restart
	time.Sleep(2 * time.Minute)

	// Log success if no errors occurred
	logger.Info(t, "LSF instance successfully rebooted")
	return nil
}

// LSFCheckBhostsResponse checks if the output of the 'bhosts' command is empty.
// It executes the 'bhosts' command on the provided SSH client.
// Returns an error if the 'bhosts' command output is empty
func LSFCheckBhostsResponse(t *testing.T, sClient *ssh.Client, logger *utils.AggregatedLogger) error {

	// Run 'bhosts -w' command on the remote SSH server
	command := "bhosts -w"

	output, err := utils.RunCommandInSSHSession(sClient, command)
	if err != nil {
		return fmt.Errorf("failed to run '%s' command: %w", command, err)
	}

	// Check if the 'bhosts' command output is empty
	if len(strings.TrimSpace(output)) == 0 || !strings.Contains(strings.TrimSpace(output), "HOST_NAME") {
		return fmt.Errorf("non-empty response from 'bhosts' command: %s", output)
	}

	logger.Info(t, fmt.Sprintf("bhosts value: %s", output))
	return nil
}

// LSFRunJobs executes an LSF job on a remote server via SSH, monitors its status,
// and ensures its completion or terminates it if it exceeds a specified timeout.
// It returns an error if any step of the process fails.
func LSFRunJobs(t *testing.T, sClient *ssh.Client, jobCmd string, logger *utils.AggregatedLogger) error {
	// Set the maximum timeout for the job execution
	var jobMaxTimeout time.Duration

	// Record the start time of the job execution
	startTime := time.Now()

	// Run the LSF job command on the remote server
	jobOutput, err := utils.RunCommandInSSHSession(sClient, jobCmd)
	if err != nil {
		return fmt.Errorf("failed to run '%s' command: %w", jobCmd, err)
	}

	logger.Info(t, fmt.Sprintf("Submitted Job command: %s", jobCmd))

	jobTime := utils.SplitAndTrim(jobCmd, "sleep")[1]
	min, err := utils.StringToInt(jobTime)
	if err != nil {
		return err
	}
	min = 300 + min
	jobMaxTimeout = time.Duration(min) * time.Second

	// Log the job output for debugging purposes
	logger.Info(t, strings.TrimSpace(string(jobOutput)))

	// Extract the job ID from the job output
	jobID, err := LSFExtractJobID(jobOutput)
	if err != nil {
		return err
	}

	// Monitor the job's status until it completes or exceeds the timeout
	for time.Since(startTime) < jobMaxTimeout {

		// Run 'bjobs -a' command on the remote SSH server
		command := LOGIN_NODE_EXECUTION_PATH + "bjobs -a"

		// Run the 'bjobs' command to get information about all jobs
		jobStatus, err := utils.RunCommandInSSHSession(sClient, command)
		if err != nil {
			return fmt.Errorf("failed to run 'bjobs' command: %w", err)
		}

		// Create a regular expression pattern to match the job ID and status
		pattern := regexp.MustCompile(fmt.Sprintf(`\b%s\s+lsfadmi DONE`, jobID))

		// Check if the job ID appears in the 'bjobs' response with a status of 'DONE'
		if pattern.MatchString(jobStatus) {
			logger.Info(t, fmt.Sprintf("Job results : \n%s", jobStatus))
			logger.Info(t, fmt.Sprintf("Job %s has executed successfully", jobID))
			return nil
		}

		// Sleep for a minute before checking again
		logger.Info(t, fmt.Sprintf("Waiting for dynamic node creation and job completion. Elapsed time: %s", time.Since(startTime)))
		time.Sleep(jobCompletionWaitTime)
	}

	// If the job exceeds the specified timeout, attempt to terminate it
	_, err = utils.RunCommandInSSHSession(sClient, fmt.Sprintf("bkill %s", jobID))
	if err != nil {
		return fmt.Errorf("failed to run 'bkill' command: %w", err)
	}

	// Return an error indicating that the job execution exceeded the specified time
	return fmt.Errorf("job execution for ID %s exceeded the specified time", jobID)
}

// LSFExtractJobID extracts the first sequence of one or more digits from the input response string.
// It uses a regular expression to find all non-overlapping matches in the response string,
// and returns the first match as the job ID.
// If no matches are found, it returns an error indicating that no job ID was found in the response.
func LSFExtractJobID(response string) (string, error) {

	// Define a regular expression pattern to extract one or more consecutive digits
	re := regexp.MustCompile("[0-9]+")

	// Find all matches in the response
	matches := re.FindAllString(response, -1)

	// Check if any matches are found
	if len(matches) > 0 {
		// Return the first match as the job ID
		jobID := matches[0]
		return jobID, nil
	}

	// Return an error if no job ID is found
	return "", fmt.Errorf("no job ID found with given response: %s", response)
}

// LSFWaitForDynamicNodeDisappearance monitors the 'bhosts -w' command output over SSH, waiting for a dynamic node to disappear.
// It sets a timeout and checks for disappearance until completion. Returns an error if the timeout is exceeded or if
// there is an issue running the SSH command.

func LSFWaitForDynamicNodeDisappearance(t *testing.T, sClient *ssh.Client, logger *utils.AggregatedLogger) error {

	// Record the start time of the job execution
	startTime := time.Now()

	// Monitor the dynamic node;  until it disappears or exceeds the timeout.
	for time.Since(startTime) < timeOutForDynamicNodeDisappear {

		// Run 'bhosts -w' command on the remote SSH server
		command := "bhosts -w"
		output, err := utils.RunCommandInSSHSession(sClient, command)

		if err != nil {
			return fmt.Errorf("failed to run SSH command '%s': %w", command, err)
		}

		if utils.VerifyDataContains(t, output, "ok", logger) {
			logger.Info(t, fmt.Sprintf("Waiting dynamic node to disappeard : \n%v", output))
			time.Sleep(90 * time.Second)
		} else {
			logger.Info(t, "Dynamic node has disappeared!")
			return nil
		}
	}

	return fmt.Errorf("timeout of %s occurred while waiting for the dynamic node to disappear", timeOutForDynamicNodeDisappear.String())
}

// LSFAPPCenterConfiguration performs configuration validation for the APP Center by checking the status of essential services
// (WEBGUI and PNC) and ensuring that the APP center port (8081) is actively listening.
// Returns an error if the validation encounters issues, otherwise, nil is returned.
// LSFAPPCenterConfiguration checks and validates the configuration of the LSF App Center.
// It verifies whether the APP Center GUI or PNC is configured correctly,
// if the APP center port is listening as expected, if the APP center binary is installed,
// and if MariaDB packages are installed as expected.
// Returns an error if any validation check fails, otherwise nil.

func LSFAPPCenterConfiguration(t *testing.T, sClient *ssh.Client, logger *utils.AggregatedLogger) error {

	lsfAppCenterPkg := "lsf-appcenter-10."
	webguiStarted := "WEBGUI         STARTED"
	pncStarted := "PNC            STARTED"

	// Command to check if APP Center GUI or PNC is configured
	appConfigCommand := "sudo su -l root -c 'pmcadmin list'"

	appConfigOutput, err := utils.RunCommandInSSHSession(sClient, appConfigCommand)
	if err != nil {
		return fmt.Errorf("failed to execute command '%s': %w", appConfigCommand, err)
	}

	if !(utils.VerifyDataContains(t, appConfigOutput, webguiStarted, logger) && utils.VerifyDataContains(t, appConfigOutput, pncStarted, logger)) {
		return fmt.Errorf("APP Center GUI or PNC not configured as expected: %s", appConfigOutput)
	}

	// Command to check if APP center port is listening as expected
	portStatusCommand := fmt.Sprintf("netstat -tuln | grep %d", appCenterPort)
	portStatusOutput, err := utils.RunCommandInSSHSession(sClient, portStatusCommand)
	if err != nil {
		return fmt.Errorf("failed to execute command '%s': %w", portStatusCommand, err)
	}

	if !utils.VerifyDataContains(t, portStatusOutput, "LISTEN", logger) {
		return fmt.Errorf("APP center port not listening as expected: %s", portStatusOutput)
	}

	// Command to check if APP center binary is installed as expected
	appBinaryCommand := "rpm -qa | grep lsf-appcenter"
	appBinaryOutput, err := utils.RunCommandInSSHSession(sClient, appBinaryCommand)
	if err != nil {
		return fmt.Errorf("failed to execute command '%s': %w", appBinaryCommand, err)
	}

	if !utils.VerifyDataContains(t, appBinaryOutput, lsfAppCenterPkg, logger) {
		return fmt.Errorf("APP center binary not installed as expected: %s", appBinaryOutput)
	}

	// Command to check if MariaDB packages are installed as expected
	mariaDBCommand := "rpm -qa | grep MariaDB"
	mariaDBOutput, err := utils.RunCommandInSSHSession(sClient, mariaDBCommand)
	if err != nil {
		return fmt.Errorf("failed to execute command '%s': %w", mariaDBCommand, err)
	}

	mariaDBPackages := [4]string{"MariaDB-client", "MariaDB-common", "MariaDB-shared", "MariaDB-server"}
	for _, out := range mariaDBPackages {
		if !utils.VerifyDataContains(t, mariaDBOutput, out, logger) {
			return fmt.Errorf("MariaDB was not installed as expected binary: %s", mariaDBOutput)
		}
	}
	// Log success if no errors occurred
	logger.Info(t, "Appcenter configuration validated successfully")
	return nil
}

// LSFGETDynamicComputeNodeIPs retrieves the IP addresses of dynamic worker nodes with a status of "ok".
// It returns a slice of IP addresses and an error if there was a problem executing the command or parsing the output.
func LSFGETDynamicComputeNodeIPs(t *testing.T, sClient *ssh.Client, logger *utils.AggregatedLogger) ([]string, error) {

	workerIPs := []string{}

	// Run the "bhosts -w" command to get the node status
	command := "bhosts -w"
	nodeStatus, err := utils.RunCommandInSSHSession(sClient, command)
	if err != nil {
		return nil, fmt.Errorf("failed to execute 'bhosts' command: %w", err)
	}

	scanner := bufio.NewScanner(strings.NewReader(nodeStatus))
	for scanner.Scan() {
		fields := strings.Fields(scanner.Text())

		if len(fields) > 1 && fields[1] == "ok" {
			// Split the input string by hyphen
			parts := strings.Split(fields[0], "-")

			// Extract the IP address part
			ip := strings.Join(parts[len(parts)-4:], ".")
			workerIPs = append(workerIPs, ip)
		}
	}
	sort.StringsAreSorted(workerIPs)
	logger.Info(t, fmt.Sprintf("Worker IPs:%v", workerIPs))

	return workerIPs, nil
}

// LSFDaemonsStatus checks the status of LSF daemons (lim, res, sbatchd) on a remote server using SSH.
// It executes the 'lsf_daemons status' command and verifies if the expected status is 'running' for each daemon.
// It returns an error on command execution failure or if any daemon is not in the 'running' state.
func LSFDaemonsStatus(t *testing.T, sClient *ssh.Client, logger *utils.AggregatedLogger) error {

	// expectedStatus is the status that each daemon should have (in this case, 'running').
	expectedStatus := "running"

	// i is used as an index to track the current daemon being checked.
	i := 0

	// Execute the 'lsf_daemons status' command to get the daemons status
	output, err := utils.RunCommandInSSHSession(sClient, "lsf_daemons status")
	if err != nil {
		return fmt.Errorf("failed to execute 'lsf_daemons status' command: %w", err)
	}

	// Check if lim, res, and sbatchd are running
	processes := []string{"lim", "res", "sbatchd"}
	scanner := bufio.NewScanner(strings.NewReader(output))
	for scanner.Scan() {
		line := scanner.Text()
		if utils.VerifyDataContains(t, line, "pid", logger) {
			if !(utils.VerifyDataContains(t, line, processes[i], logger) && utils.VerifyDataContains(t, line, expectedStatus, logger)) {
				return fmt.Errorf("%s is not running", processes[i])
			}
			i++
		}
	}
	// Log success if no errors occurred
	logger.Info(t, "All LSF daemons are running")
	return nil
}

// LSFCheckHyperthreading checks if hyperthreading is enabled on the system by
// inspecting the output of the 'lscpu' command via an SSH session.
// It returns true if hyperthreading is enabled, false if it's disabled, and an error if
// there's an issue running the command or parsing the output.
func LSFCheckHyperthreading(t *testing.T, sClient *ssh.Client, expectedHyperthreadingStatus bool, logger *utils.AggregatedLogger) error {

	// Run the 'lscpu' command to retrieve CPU information
	command := "lscpu"

	cpuInfo, err := utils.RunCommandInSSHSession(sClient, command)
	if err != nil {
		return fmt.Errorf("failed to run '%s' command: %w", command, err)
	}

	// Convert the command output to a string
	content := string(cpuInfo)

	// Check if there is an "Off-line CPU(s) list:" indicating hyperthreading is disabled
	hasOfflineCPU := utils.VerifyDataContains(t, content, "Off-line CPU(s) list:", logger)

	// Determine the actual hyperthreading status
	var actualHyperthreadingStatus bool
	if !hasOfflineCPU {
		logger.Info(t, "Hyperthreading is enabled")
		actualHyperthreadingStatus = true
	} else {
		logger.Info(t, "Hyperthreading is disabled")
		actualHyperthreadingStatus = false
	}

	// Compare actual and expected hyperthreading status
	if actualHyperthreadingStatus != expectedHyperthreadingStatus {
		return fmt.Errorf("hyperthreading status mismatch: expected %t, got %t", expectedHyperthreadingStatus, actualHyperthreadingStatus)
	}
	return nil
}

// runSSHCommandAndGetPaths executes an SSH command to discover authorized_keys files
// across the filesystem and returns a list of their absolute paths.
func runSSHCommandAndGetPaths(sClient *ssh.Client) ([]string, error) {
	sshKeyCheckCmd := "sudo su -l root -c 'cd / && find / -name authorized_keys'"
	var err error
	// Retry logic
	for attempt := 0; attempt < 3; attempt++ {
		output, err := utils.RunCommandInSSHSession(sClient, sshKeyCheckCmd)
		if err == nil {
			return strings.Split(strings.TrimSpace(output), "\n"), nil
		}

		time.Sleep(30 * time.Second)
	}

	return nil, fmt.Errorf("failed to run '%s' command: %w", sshKeyCheckCmd, err)
}

// LSFCheckSSHKeyForManagementNode checks the SSH key configurations on a management server.
// It retrieves a list of authorized_keys paths, compares them with expected paths,
// and validates the occurrences of SSH keys in each path.
func LSFCheckSSHKeyForManagementNode(t *testing.T, sClient *ssh.Client, logger *utils.AggregatedLogger) error {
	// Run a command to get a list of authorized_keys paths
	pathList, err := runSSHCommandAndGetPaths(sClient)
	if err != nil {
		return fmt.Errorf("failed to retrieve authorized_keys paths: %w", err)
	}

	// Log the list of authorized_keys paths
	logger.Info(t, fmt.Sprintf("List of authorized_keys paths: %q", pathList))

	// Create a map with paths as keys and expected values
	filePathMap := map[string]int{
		"/home/vpcuser/.ssh/authorized_keys":  1,
		"/home/lsfadmin/.ssh/authorized_keys": 2,
		"/root/.ssh/authorized_keys":          2,
	}

	// Iterate through the list of paths and check SSH key occurrences
	for _, path := range pathList {
		cmd := fmt.Sprintf("sudo su -l root -c 'cat %s'", path)
		out, err := utils.RunCommandInSSHSession(sClient, cmd)
		if err != nil {
			return fmt.Errorf("failed to run command on %s: %w", path, err)
		}

		// Log information about SSH key occurrences
		value := filePathMap[path]
		occur := utils.CountStringOccurrences(out, "ssh-rsa ")
		logger.Info(t, fmt.Sprintf("Value: %d, Occurrences: %d, Path: %s", value, occur, path))

		// Check for mismatch in occurrences
		if value != occur {
			return fmt.Errorf("mismatch in occurrences for path %s: expected %d, got %d", path, value, occur)
		}
	}

	// Log success for SSH key check
	logger.Info(t, "SSH key check successful")
	return nil
}

// LSFCheckSSHKeyForManagementNodes checks SSH key configurations for each management node in the provided list.
// It ensures the expected paths and occurrences of SSH keys are consistent.
func LSFCheckSSHKeyForManagementNodes(t *testing.T, publicHostName, publicHostIP, privateHostName string, managementNodeIPList []string, logger *utils.AggregatedLogger) error {
	// Check if the node list is empty
	if len(managementNodeIPList) == 0 {
		return fmt.Errorf("management node IPs cannot be empty")
	}

	for _, mgmtIP := range managementNodeIPList {
		// Connect to the management node via SSH
		mgmtSshClient, connectionErr := utils.ConnectToHost(publicHostName, publicHostIP, privateHostName, mgmtIP)
		if connectionErr != nil {
			return fmt.Errorf("failed to connect to the management node %s via SSH: %v", mgmtIP, connectionErr)
		}
		defer mgmtSshClient.Close()

		logger.Info(t, fmt.Sprintf("SSH connection to the management node %s successful", mgmtIP))

		// SSH key check for management node
		sshKeyErr := LSFCheckSSHKeyForManagementNode(t, mgmtSshClient, logger)
		if sshKeyErr != nil {
			return fmt.Errorf("management node %s SSH key check failed: %v", mgmtIP, sshKeyErr)
		}
	}

	return nil
}

// LSFCheckSSHKeyForComputeNode checks the SSH key configurations on a compute server.
// It considers OS variations, retrieves a list of authorized_keys paths, and validates SSH key occurrences.
func LSFCheckSSHKeyForComputeNode(t *testing.T, sClient *ssh.Client, computeIP string, logger *utils.AggregatedLogger) error {

	// authorizedKeysCmd is the command to find authorized_keys files.
	authorizedKeysCmd := "sudo su -l root -c 'cd / && find / -name authorized_keys'"
	// catAuthorizedKeysCmd is the command to concatenate authorized_keys files.
	catAuthorizedKeysCmd := "sudo su -l root -c 'cat %s'"
	expectedUbuntuPaths := 4
	expectedNonUbuntuPaths := 3

	var expectedAuthorizedKeysPaths int

	// Get the OS name of the compute node.
	osName, osNameErr := GetOSNameOfNode(t, sClient, computeIP, logger)
	if osNameErr != nil {
		// Determine the expected number of authorized_keys paths based on the OS.
		switch osName {
		case "Ubuntu":
			expectedAuthorizedKeysPaths = expectedUbuntuPaths
		default:
			expectedAuthorizedKeysPaths = expectedNonUbuntuPaths
		}
	} else {
		// Return error if OS name retrieval fails.
		return osNameErr
	}

	// Construct the SSH command to check authorized_keys paths.
	sshKeyCheckCmd := fmt.Sprintf("ssh %s \"%s\"", computeIP, authorizedKeysCmd)

	// Run the SSH command to get the list of authorized_keys paths.
	output, err := utils.RunCommandInSSHSession(sClient, sshKeyCheckCmd)
	if err != nil {
		return fmt.Errorf("failed to run '%s' command: %w", sshKeyCheckCmd, err)
	}

	// Split the output into a list of authorized_keys paths.
	pathList := strings.Split(strings.TrimSpace(output), "\n")

	logger.Info(t, fmt.Sprintf("List of authorized_keys paths: %q", pathList))

	// Check if the number of authorized_keys paths matches the expected value.
	if len(pathList) != expectedAuthorizedKeysPaths {
		return fmt.Errorf("mismatch in the number of authorized_keys paths: expected %d, got %d", expectedAuthorizedKeysPaths, len(pathList))
	}

	// Create a map with paths as keys and set specific values for certain paths.
	filePathMap := map[string]int{
		"/home/lsfadmin/.ssh/authorized_keys": 1,
	}

	// Iterate through the list of paths and check SSH key occurrences.
	for filePath := range filePathMap {
		cmd := fmt.Sprintf("ssh %s \"%s\"", computeIP, fmt.Sprintf(catAuthorizedKeysCmd, filePath))
		out, err := utils.RunCommandInSSHSession(sClient, cmd)
		if err != nil {
			return fmt.Errorf("failed to run '%s' command: %w", cmd, err)
		}

		// Log information about SSH key occurrences.
		expectedOccurrences := filePathMap[filePath]
		actualOccurrences := utils.CountStringOccurrences(out, "ssh-rsa ")

		// Check for mismatch in occurrences.
		if expectedOccurrences != actualOccurrences {
			return fmt.Errorf("mismatch in occurrences for path %s: expected %d, got %d", filePath, expectedOccurrences, actualOccurrences)
		}
	}

	// Log success for SSH key check.
	logger.Info(t, "SSH key check success")
	return nil
}

// LSFCheckSSHKeyForComputeNodes checks SSH key configurations for each compute node in the provided list.
// It validates the expected paths and occurrences of SSH keys.
func LSFCheckSSHKeyForComputeNodes(t *testing.T, sClient *ssh.Client, computeNodeIPList []string, logger *utils.AggregatedLogger) error {
	// Check if the node list is empty
	if len(computeNodeIPList) == 0 {
		return fmt.Errorf("ERROR: compute node IPs cannot be empty")
	}

	for _, compIP := range computeNodeIPList {
		// SSH key check for compute node
		sshKeyErr := LSFCheckSSHKeyForComputeNode(t, sClient, compIP, logger)
		if sshKeyErr != nil {
			return fmt.Errorf("compute node %s SSH key check failed: %v", compIP, sshKeyErr)
		}
	}

	return nil
}

// CheckLSFVersion verifies if the IBM Spectrum LSF version on the cluster matches the expected version.
// It executes the 'lsid' command, retrieves the cluster ID, and compares it with the expected version.
func CheckLSFVersion(t *testing.T, sClient *ssh.Client, expectedVersion string, logger *utils.AggregatedLogger) error {

	// Execute the 'lsid' command to get the cluster ID
	command := LOGIN_NODE_EXECUTION_PATH + "lsid"

	output, err := utils.RunCommandInSSHSession(sClient, command)
	if err != nil {
		// Handle the error when executing the 'lsid' command
		return fmt.Errorf("failed to execute 'lsid' command: %w", err)
	}

	// Verify if the expected cluster ID is present in the output
	if !utils.VerifyDataContains(t, output, "IBM Spectrum LSF Standard "+expectedVersion, logger) {
		// Extract actual cluster version from the output for better error reporting
		actualValue := strings.TrimSpace(strings.Split(strings.Split(output, "IBM Spectrum LSF Standard")[1], ", ")[0])
		return fmt.Errorf("expected cluster Version %s, but found %s", expectedVersion, actualValue)
	}

	// Log information when the cluster version is set as expected
	logger.Info(t, fmt.Sprintf("Cluster Version is set as expected: %s", expectedVersion))
	// No errors occurred
	return nil
}

// IsDynamicNodeAvailable checks if a dynamic node is available by running
// the 'bhosts -w' command on the remote SSH server and verifying the output.
// It returns true if the output contains the string 'ok', indicating the node is available.
func IsDynamicNodeAvailable(t *testing.T, sClient *ssh.Client, logger *utils.AggregatedLogger) (bool, error) {

	// Run 'bhosts -w' command on the remote SSH server
	command := "bhosts -w"
	output, err := utils.RunCommandInSSHSession(sClient, command)

	if err != nil {
		//return if the command execution fails
		return false, fmt.Errorf("failed to run SSH command '%s': %w", command, err)
	}

	// Return true if the output contains 'ok'
	if utils.VerifyDataContains(t, output, "ok", logger) {
		return true, nil
	}

	// Return false if the output not contains 'ok'
	return false, nil
}

// GetOSNameOfNode retrieves the OS name of a remote node using SSH.
// It takes a testing.T instance for error reporting, an SSH client, the IP address of the remote node,
// and a logger for additional logging. It returns the OS name and an error if any.
func GetOSNameOfNode(t *testing.T, sClient *ssh.Client, hostIP string, logger *utils.AggregatedLogger) (string, error) {
	// Command to retrieve the content of /etc/os-release on the remote server
	//catOsReleaseCmd := "sudo su -l root -c 'cat /etc/os-release'"
	catOsReleaseCmd := "cat /etc/os-release"
	// Construct the SSH command
	OsReleaseCmd := fmt.Sprintf("ssh %s \"%s\"", hostIP, catOsReleaseCmd)
	output, err := utils.RunCommandInSSHSession(sClient, OsReleaseCmd)
	if err != nil {
		// Report an error and fail the test
		t.Fatal("Error executing SSH command:", err)
	}

	// Parse the OS name from the /etc/os-release content
	osName, parseErr := utils.ParsePropertyValue(strings.TrimSpace(string(output)), "NAME")
	if parseErr != nil {
		// Log information about the OS installation on the specified node.
		logger.Info(t, fmt.Sprintf("Operating System: %s, Installed on Node: %s", osName, hostIP))

		// Return the parsed OS name on success
		return osName, parseErr
	}

	// If parsing fails, return the error
	return "", parseErr
}

// HPCCheckFileMount checks if essential LSF directories (10.1, conf, config_done, das_staging_area, data, gui-conf, gui-logs, log, repository-path and work) exist
// on remote machines identified by the provided list of IP addresses. It utilizes SSH to
// query and validate the directories. Any missing directory triggers an error, and the
// function logs the success message if all directories are found.
func HPCCheckFileMount(t *testing.T, sClient *ssh.Client, ipsList []string, nodeType string, logger *utils.AggregatedLogger) error {
	// Define constants
	const (
		sampleText     = "Welcome to the ibm cloud HPC"
		SampleFileName = "testOne.txt"
	)

	// Check if the node list is empty
	if len(ipsList) == 0 {
		return fmt.Errorf("ERROR: ips cannot be empty")
	}

	// Iterate over each IP in the list
	for _, ip := range ipsList {
		// Run SSH command to get file system information
		commandOne := fmt.Sprintf("ssh %s 'df -h'", ip)
		outputOne, err := utils.RunCommandInSSHSession(sClient, commandOne)
		if err != nil {
			return fmt.Errorf("failed to run %s command on machine IP %s: %w", commandOne, ip, err)
		}
		actualMount := strings.TrimSpace(string(outputOne))

		// Check if it's not a login node
		if !(strings.Contains(strings.ToLower(nodeType), "login")) {
			// Define expected file system mounts
			expectedMount := []string{"/mnt/lsf", "/mnt/vpcstorage/tools", "/mnt/vpcstorage/data"}

			// Check if all expected mounts exist
			for _, mount := range expectedMount {
				if !utils.VerifyDataContains(t, actualMount, mount, logger) {
					return fmt.Errorf("actual filesystem '%v' does not match the expected filesystem '%v' for node IP '%s'", actualMount, expectedMount, ip)
				}
			}

			// Log filesystem existence
			logger.Info(t, fmt.Sprintf("Filesystems [/mnt/lsf, /mnt/vpcstorage/tools,/mnt/vpcstorage/data] exist on the node %s", ip))

			// Verify essential directories existence
			if err := verifyDirectories(t, sClient, ip, logger); err != nil {
				return err
			}

			// Create, read, verify and delete sample files in each mount
			for i := 1; i < len(expectedMount); i++ {
				// Create file
				_, fileCreationErr := utils.ToCreateFileWithContent(t, sClient, expectedMount[i], SampleFileName, sampleText, logger)
				if fileCreationErr != nil {
					return fmt.Errorf("failed to create file on %s for machine IP %s: %w", expectedMount[i], ip, fileCreationErr)
				}

				// Read file
				actualText, fileReadErr := utils.ReadRemoteFileContents(t, sClient, expectedMount[i], SampleFileName, logger)
				if fileReadErr != nil {
					// Delete file if reading fails
					_, fileDeletionErr := utils.ToDeleteFile(t, sClient, expectedMount[i], SampleFileName, logger)
					if fileDeletionErr != nil {
						return fmt.Errorf("failed to delete %s file on machine IP %s: %w", SampleFileName, ip, fileDeletionErr)
					}
					return fmt.Errorf("failed to read %s file content on %s machine IP %s: %w", SampleFileName, expectedMount[i], ip, fileReadErr)
				}

				// Verify file content
				if !utils.VerifyDataContains(t, actualText, sampleText, logger) {
					return fmt.Errorf("%s actual file content '%v' does not match the file content '%v' for node IP '%s'", SampleFileName, actualText, sampleText, ip)
				}

				// Delete file after verification
				_, fileDeletionErr := utils.ToDeleteFile(t, sClient, expectedMount[i], SampleFileName, logger)
				if fileDeletionErr != nil {
					return fmt.Errorf("failed to delete %s file on machine IP %s: %w", SampleFileName, ip, fileDeletionErr)
				}
			}
		} else {
			// For login nodes, only /mnt/lsf is checked
			expectedMount := "/mnt/lsf"

			// Verify /mnt/lsf existence
			if !utils.VerifyDataContains(t, actualMount, expectedMount, logger) {
				return fmt.Errorf("actual filesystem '%v' does not match the expected filesystem '%v' for node IP '%s'", actualMount, expectedMount, ip)
			}

			// Log /mnt/lsf existence
			logger.Info(t, fmt.Sprintf("Filesystems /mnt/lsf exist on the node %s", ip))

			// Verify essential directories existence
			if err := verifyDirectories(t, sClient, ip, logger); err != nil {
				return err
			}
		}
	}
	// Log success if no errors occurred
	logger.Info(t, fmt.Sprintf("File mount check has been successfully completed for %s", nodeType))
	// No errors occurred
	return nil
}

// verifyDirectories verifies the existence of essential directories in /mnt/lsf on the remote machine.
func verifyDirectories(t *testing.T, sClient *ssh.Client, ip string, logger *utils.AggregatedLogger) error {
	// Run SSH command to list directories in /mnt/lsf
	commandTwo := fmt.Sprintf("ssh %s 'cd /mnt/lsf && ls'", ip)
	outputTwo, err := utils.RunCommandInSSHSession(sClient, commandTwo)
	if err != nil {
		return fmt.Errorf("failed to run %s command on machine IP %s: %w", commandTwo, ip, err)
	}
	// Split the output into directory names
	actualDirs := strings.Fields(strings.TrimSpace(string(outputTwo)))
	// Define expected directories
	expectedDirs := []string{"10.1", "conf", "config_done", "das_staging_area", "data", "gui-conf", "gui-logs", "log", "repository-path", "work"}

	// Verify if all expected directories exist
	if !utils.VerifyDataContains(t, actualDirs, expectedDirs, logger) {
		return fmt.Errorf("actual directory '%v' does not match the expected directory '%v' for node IP '%s'", actualDirs, expectedDirs, ip)
	}

	// Log directories existence
	logger.Info(t, fmt.Sprintf("Directories [10.1, conf, config_done, das_staging_area, data, gui-conf, gui-logs, log, repository-path and work] exist on %s", ip))
	return nil
}

// VerifyTerraformOutputs verifies specific fields in the Terraform outputs and ensures they are not empty based on the provided LastTestTerraformOutputs.
// Additional checks are performed for the application center and LDAP server based on the isAPPCenterEnabled and ldapServerEnabled flags.
// Any missing essential field results in an error being returned with detailed information.
func VerifyTerraformOutputs(t *testing.T, LastTestTerraformOutputs map[string]interface{}, isAPPCenterEnabled, ldapServerEnabled bool, logger *utils.AggregatedLogger) error {

	fields := []string{"ssh_to_management_node", "ssh_to_login_node", "vpc_name", "region_name"}
	actualOutput := make(map[string]interface{})
	maps.Copy(actualOutput, LastTestTerraformOutputs["cluster_info"].(map[string]interface{}))
	for _, field := range fields {
		value := actualOutput[field].(string)
		logger.Info(t, field+" = "+value)
		if len(value) == 0 {
			return fmt.Errorf("%s is missing terraform output", field)
		}
	}

	if isAPPCenterEnabled {
		if len(strings.TrimSpace(actualOutput["application_center"].(string))) == 0 {
			return errors.New("application_center is missing from terraform output")

		}
		if len(strings.TrimSpace(actualOutput["application_center_url"].(string))) == 0 {
			return errors.New("application_center_url is missing from terraform output")
		}
	}

	if ldapServerEnabled {
		if len(strings.TrimSpace(actualOutput["ssh_to_ldap_node"].(string))) == 0 {
			return fmt.Errorf("ssh_to_ldap_node is missing from terraform output")

		}
	}
	// Log success if no errors occurred
	logger.Info(t, "Terraform output check has been successfully completed")
	// No errors occurred
	return nil

}

// LSFCheckSSHConnectivityToNodesFromLogin checks SSH connectivity from the login node to other nodes.
func LSFCheckSSHConnectivityToNodesFromLogin(t *testing.T, sshLoginClient *ssh.Client, managementNodeIPList, computeNodeIPList []string, logger *utils.AggregatedLogger) error {

	// Check if management node IP list is empty
	if len(managementNodeIPList) == 0 {
		return fmt.Errorf("ERROR: management node IPs cannot be empty")
	}

	// Iterate over each management node IP in the list
	for _, managementNodeIP := range managementNodeIPList {
		// Run SSH command to get the hostname of the management node
		command := fmt.Sprintf("ssh %s 'hostname'", managementNodeIP)
		actualOutput, err := utils.RunCommandInSSHSession(sshLoginClient, command)
		if err != nil {
			return fmt.Errorf("failed to run SSH command on management node IP %s: %w", managementNodeIP, err)
		}
		// Check if the hostname contains "mgmt" substring
		if !utils.VerifyDataContains(t, actualOutput, "mgmt", logger) {
			return fmt.Errorf("compute node '%v' does not contain 'mgmt' substring for node IP '%s'", actualOutput, managementNodeIP)
		}
	}

	// Check if compute node IP list is empty
	if len(computeNodeIPList) == 0 {
		return fmt.Errorf("ERROR: compute node IPs cannot be empty")
	}
	// Iterate over each compute node IP in the list
	for _, computeNodeIP := range computeNodeIPList {
		// Run a simple SSH command to check connectivity
		command := fmt.Sprintf("ssh -o ConnectTimeout=12 -q %s exit", computeNodeIP)
		_, err := utils.RunCommandInSSHSession(sshLoginClient, command)
		if err != nil {
			return fmt.Errorf("failed to run SSH command on compute node IP %s: %w", computeNodeIP, err)
		}

	}
	// Log success if no errors occurred
	logger.Info(t, "SSH connectivity check from login node to other nodes completed successfully")
	// No errors occurred
	return nil
}

// HPCCheckNoVNC checks if NO VNC is properly configured on a remote machine.
// It executes a series of commands via SSH and verifies the expected output.
func HPCCheckNoVNC(t *testing.T, sClient *ssh.Client, logger *utils.AggregatedLogger) error {
	// Define commands to be executed and their expected outputs
	commands := map[string]string{
		"rpm -qa  | grep xterm":     "xterm",
		"rpm -qa | grep tigervnc":   "tigervnc",
		"ps aux | grep -i novnc":    "-Ddefault.novnc.port=6080",
		"netstat -tuln | grep 6080": "0.0.0.0:6080",
	}

	// Iterate over commands
	for command, expectedOutput := range commands {
		// Execute command on SSH session
		output, err := utils.RunCommandInSSHSession(sClient, command)
		if err != nil {
			return fmt.Errorf("failed to execute command '%s' via SSH: %v", command, err)
		}

		// Verify if the expected output is present in the actual output
		if !utils.VerifyDataContains(t, output, expectedOutput, logger) {
			return fmt.Errorf("NO VNC is not set as expected for command '%s'. Expected: '%s'. Actual: '%s'", command, expectedOutput, output)

		}
	}

	// Log success if no errors occurred
	logger.Info(t, "NO VNC configuration set as expected")

	// No errors occurred
	return nil
}

// GetJobCommand returns the appropriate job command based on the provided job type and zone.
// zones: a string indicating the zone (e.g., "us-south").
// jobType: a string indicating the type of job (e.g., "low", "med", "high").
// Returns: a string representing the job command.
func GetJobCommand(zone, jobType string) string {
	// Define job command constants
	var lowMem, medMem, highMem string
	if strings.Contains(zone, "us-south") {
		lowMem = JOB_COMMAND_LOW_MEM_SOUTH
		medMem = JOB_COMMAND_MED_MEM_SOUTH
		highMem = JOB_COMMAND_HIGH_MEM_SOUTH
	} else {
		lowMem = JOB_COMMAND_LOW_MEM
		medMem = JOB_COMMAND_MED_MEM
		highMem = JOB_COMMAND_HIGH_MEM
	}

	// Select appropriate job command based on job type
	switch strings.ToLower(jobType) {
	case "low":
		return lowMem
	case "med":
		return medMem
	case "high":
		return highMem
	default:
		// Default to low job command if job type is not recognized
		return lowMem
	}
}

// VerifyEncryption checks if encryption is enabled for file shares.
// It logs into IBM Cloud using the API key and VPC region, retrieves the list of file shares
// with the specified cluster prefix, and verifies encryption settings.
func VerifyEncryption(t *testing.T, apiKey, region, resourceGroup, clusterPrefix, keyManagement string, logger *utils.AggregatedLogger) error {

	// In case the resource group is null , Set custom resource group it to a "clusterPrefix-workload-rg"
	if strings.Contains(resourceGroup, "null") {
		resourceGroup = fmt.Sprintf("%s-workload-rg", clusterPrefix)
	}

	// Login to IBM Cloud using the API key and VPC region
	if err := utils.LoginIntoIBMCloudUsingCLI(t, apiKey, region, resourceGroup); err != nil {
		return fmt.Errorf("failed to log in to IBM Cloud: %w", err)
	}

	// Determine the command to get the list of file shares
	fileSharesCmd := fmt.Sprintf("ibmcloud is shares | grep %s | awk '{print $2}'", clusterPrefix)
	if strings.Contains(resourceGroup, "workload") {
		fileSharesCmd = fmt.Sprintf("ibmcloud is shares | grep %s | awk 'NR>1 {print $2}'", clusterPrefix)
	}

	// Retrieve the list of file shares
	fileSharesOutput, err := exec.Command("bash", "-c", fileSharesCmd).CombinedOutput()
	if err != nil {
		return fmt.Errorf("failed to retrieve file shares: %w", err)
	}

	fileShareNames := strings.Fields(string(fileSharesOutput))
	logger.Info(t, fmt.Sprintf("File share list: %s", fileShareNames))

	for _, fileShareName := range fileShareNames {
		fileShareCmd := exec.Command("ibmcloud", "is", "share", fileShareName)
		output, err := fileShareCmd.CombinedOutput()
		if err != nil {
			return fmt.Errorf("failed to retrieve file share details for '%s': %w", fileShareName, err)
		}

		if !utils.VerifyDataContains(t, strings.ToLower(keyManagement), "key_protect", logger) {
			if !utils.VerifyDataContains(t, string(output), "provider_managed", logger) {
				return fmt.Errorf("encryption in transit is unexpectedly enabled for the file shares ")
			}
		} else {
			if !utils.VerifyDataContains(t, string(output), "user_managed", logger) {
				return fmt.Errorf("encryption in transit is unexpectedly disabled for the file shares")
			}
		}
	}
	logger.Info(t, "Encryption set as expected")
	return nil
}

// ValidateRequiredEnvironmentVariables checks if the required environment variables are set and valid
func ValidateRequiredEnvironmentVariables(envVars map[string]string) error {
	requiredVars := []string{"SSH_FILE_PATH", "SSH_KEY", "CLUSTER_ID", "ZONE", "RESERVATION_ID"}
	for _, fieldName := range requiredVars {
		fieldValue, ok := envVars[fieldName]
		if !ok || fieldValue == "" {
			return fmt.Errorf("missing required environment variable: %s", fieldName)
		}
	}

	if _, err := os.Stat(envVars["SSH_FILE_PATH"]); os.IsNotExist(err) {
		return fmt.Errorf("SSH private key file '%s' does not exist", envVars["SSH_FILE_PATH"])
	} else if err != nil {
		return fmt.Errorf("error checking SSH private key file: %v", err)
	}

	return nil
}

// LSFRunJobsAsLDAPUser executes an LSF job on a remote server via SSH, monitors its status,
// and ensures its completion or terminates it if it exceeds a specified timeout.
// It returns an error if any step of the process fails.
func LSFRunJobsAsLDAPUser(t *testing.T, sClient *ssh.Client, jobCmd, ldapUser string, logger *utils.AggregatedLogger) error {
	// Set the maximum timeout for the job execution
	var jobMaxTimeout time.Duration

	// Record the start time of the job execution
	startTime := time.Now()

	// Run the LSF job command on the remote server
	jobOutput, err := utils.RunCommandInSSHSession(sClient, jobCmd)
	if err != nil {
		return fmt.Errorf("failed to run '%s' command: %w", jobCmd, err)
	}

	logger.Info(t, fmt.Sprintf("Submitted Job command: %s", jobCmd))

	jobTime := utils.SplitAndTrim(jobCmd, "sleep")[1]
	min, err := utils.StringToInt(jobTime)
	if err != nil {
		return err
	}
	min = 300 + min
	jobMaxTimeout = time.Duration(min) * time.Second

	// Log the job output for debugging purposes
	logger.Info(t, strings.TrimSpace(string(jobOutput)))

	// Extract the job ID from the job output
	jobID, err := LSFExtractJobID(jobOutput)
	if err != nil {
		return err
	}

	// Monitor the job's status until it completes or exceeds the timeout
	for time.Since(startTime) < jobMaxTimeout {

		// Run 'bjobs -a' command on the remote SSH server
		command := LOGIN_NODE_EXECUTION_PATH + "bjobs -a"

		// Run the 'bjobs' command to get information about all jobs
		jobStatus, err := utils.RunCommandInSSHSession(sClient, command)
		if err != nil {
			return fmt.Errorf("failed to run 'bjobs' command: %w", err)
		}

		// Create a regular expression pattern to match the job ID and status
		pattern := regexp.MustCompile(fmt.Sprintf(`\b%s\s+%s\s+DONE`, jobID, ldapUser))

		// Check if the job ID appears in the 'bjobs' response with a status of 'DONE'
		if pattern.MatchString(jobStatus) {
			logger.Info(t, fmt.Sprintf("Job results : \n%s", jobStatus))
			logger.Info(t, fmt.Sprintf("Job %s has executed successfully", jobID))
			return nil
		}

		// Sleep for a minute before checking again
		logger.Info(t, fmt.Sprintf("Waiting for dynamic node creation and job completion. Elapsed time: %s", time.Since(startTime)))
		time.Sleep(jobCompletionWaitTime)
	}

	// If the job exceeds the specified timeout, attempt to terminate it
	_, err = utils.RunCommandInSSHSession(sClient, fmt.Sprintf("bkill %s", jobID))
	if err != nil {
		return fmt.Errorf("failed to run 'bkill' command: %w", err)
	}

	// Return an error indicating that the job execution exceeded the specified time
	return fmt.Errorf("job execution for ID %s exceeded the specified time", jobID)
}

// HPCCheckFileMountAsLDAPUser checks if essential LSF directories (10.1, conf, config_done, das_staging_area, data, gui-conf, gui-logs, log, repository-path and work) exist
// on remote machines It utilizes SSH to
// query and validate the directories. Any missing directory triggers an error, and the
// function logs the success message if all directories are found.
func HPCCheckFileMountAsLDAPUser(t *testing.T, sClient *ssh.Client, nodeType string, logger *utils.AggregatedLogger) error {
	// Define constants
	const (
		sampleText     = "Welcome to the ibm cloud HPC"
		SampleFileName = "testOne.txt"
	)

	hostname, err := utils.RunCommandInSSHSession(sClient, "hostname")
	if err != nil {
		return fmt.Errorf("failed to run hostname command: %w", err)
	}

	commandOne := "df -h"
	outputOne, err := utils.RunCommandInSSHSession(sClient, commandOne)
	if err != nil {
		return fmt.Errorf("failed to run %s command: %w", commandOne, err)
	}
	actualMount := strings.TrimSpace(string(outputOne))

	if !strings.Contains(strings.ToLower(nodeType), "login") {
		expectedMount := []string{"/mnt/lsf", "/mnt/vpcstorage/tools", "/mnt/vpcstorage/data"}
		for _, mount := range expectedMount {
			if !utils.VerifyDataContains(t, actualMount, mount, logger) {
				return fmt.Errorf("actual filesystem '%v' does not match the expected filesystem '%v' for node %s", actualMount, expectedMount, hostname)
			}
		}
		logger.Info(t, fmt.Sprintf("Filesystems [/mnt/lsf, /mnt/vpcstorage/tools,/mnt/vpcstorage/data] exist on the node %s", hostname))

		if err := verifyDirectoriesAsLdapUser(t, sClient, hostname, logger); err != nil {
			return err
		}

		for i := 1; i < len(expectedMount); i++ {
			_, fileCreationErr := utils.ToCreateFileWithContent(t, sClient, expectedMount[i], SampleFileName, sampleText, logger)
			if fileCreationErr != nil {
				return fmt.Errorf("failed to create file on %s for machine %s: %w", expectedMount[i], hostname, fileCreationErr)
			}

			actualText, fileReadErr := utils.ReadRemoteFileContents(t, sClient, expectedMount[i], SampleFileName, logger)
			if fileReadErr != nil {
				_, fileDeletionErr := utils.ToDeleteFile(t, sClient, expectedMount[i], SampleFileName, logger)
				if fileDeletionErr != nil {
					return fmt.Errorf("failed to delete %s file on machine %s: %w", SampleFileName, hostname, fileDeletionErr)
				}
				return fmt.Errorf("failed to read %s file content on %s machine %s: %w", SampleFileName, expectedMount[i], hostname, fileReadErr)
			}

			if !utils.VerifyDataContains(t, actualText, sampleText, logger) {
				return fmt.Errorf("%s actual file content '%v' does not match the file content '%v' for node %s", SampleFileName, actualText, sampleText, hostname)
			}

			_, fileDeletionErr := utils.ToDeleteFile(t, sClient, expectedMount[i], SampleFileName, logger)
			if fileDeletionErr != nil {
				return fmt.Errorf("failed to delete %s file on machine %s: %w", SampleFileName, hostname, fileDeletionErr)
			}
		}
	} else {
		expectedMount := "/mnt/lsf"
		if !utils.VerifyDataContains(t, actualMount, expectedMount, logger) {
			return fmt.Errorf("actual filesystem '%v' does not match the expected filesystem '%v' for node %s", actualMount, expectedMount, hostname)
		}
		logger.Info(t, fmt.Sprintf("Filesystems /mnt/lsf exist on the node %s", hostname))

		if err := verifyDirectoriesAsLdapUser(t, sClient, hostname, logger); err != nil {
			return err
		}
	}

	logger.Info(t, fmt.Sprintf("File mount check has been successfully completed for %s", nodeType))
	return nil
}

// verifyDirectoriesAsLdapUser verifies the existence of essential directories in /mnt/lsf on the remote machine.
func verifyDirectoriesAsLdapUser(t *testing.T, sClient *ssh.Client, hostname string, logger *utils.AggregatedLogger) error {
	// Run SSH command to list directories in /mnt/lsf
	commandTwo := "cd /mnt/lsf && ls"
	outputTwo, err := utils.RunCommandInSSHSession(sClient, commandTwo)
	if err != nil {
		return fmt.Errorf("failed to run %s command on machine IP %s: %w", commandTwo, hostname, err)
	}
	// Split the output into directory names
	actualDirs := strings.Fields(strings.TrimSpace(string(outputTwo)))
	// Define expected directories
	expectedDirs := []string{"10.1", "conf", "config_done", "das_staging_area", "data", "gui-conf", "gui-logs", "log", "repository-path", "work"}

	// Verify if all expected directories exist
	if !utils.VerifyDataContains(t, actualDirs, expectedDirs, logger) {
		return fmt.Errorf("actual directory '%v' does not match the expected directory '%v' for node IP '%s'", actualDirs, expectedDirs, hostname)
	}

	// Log directories existence
	logger.Info(t, fmt.Sprintf("Directories [10.1, conf, config_done, das_staging_area, data, gui-conf, gui-logs, log, repository-path and work] exist on %s", hostname))
	return nil
}

// VerifyLSFCommands verifies the LSF commands on the remote machine.
// It checks the commands' execution based on the node type.
func VerifyLSFCommands(t *testing.T, sClient *ssh.Client, nodeType string, logger *utils.AggregatedLogger) error {
	// Define commands to be executed
	commands := []string{
		"lsid",
		"bjobs -a",
		"bhosts -w",
		"bqueues",
	}

	nodeType = strings.TrimSpace(strings.ToLower(nodeType))

	// Iterate over commands
	for _, command := range commands {
		var output string
		var err error

		// Execute command on SSH session
		switch {
		case strings.Contains(nodeType, "compute"):
			output, err = utils.RunCommandInSSHSession(sClient, COMPUTE_NODE_EXECUTION_PATH+command)
		case strings.Contains(nodeType, "login"):
			output, err = utils.RunCommandInSSHSession(sClient, LOGIN_NODE_EXECUTION_PATH+command)
		default:
			output, err = utils.RunCommandInSSHSession(sClient, command)
		}

		if err != nil {
			return fmt.Errorf("failed to execute command '%s' via SSH: %v", command, err)
		}

		if strings.TrimSpace(output) == "" {
			return fmt.Errorf("output for command '%s' is empty", command)
		}
	}

	return nil
}

// VerifyLSFCommandsAsLDAPUser verifies the LSF commands on the remote machine.
// It checks the commands' execution as the specified LDAP user.
func VerifyLSFCommandsAsLDAPUser(t *testing.T, sClient *ssh.Client, userName, nodeType string, logger *utils.AggregatedLogger) error {
	// Define commands to be executed
	commands := []string{
		"whoami",
		"lsid",
		"bhosts -w",
		"lshosts",
	}

	nodeType = strings.TrimSpace(strings.ToLower(nodeType))

	// Iterate over commands
	for _, command := range commands {
		var output string
		var err error

		// Execute command on SSH session
		if strings.Contains(nodeType, "compute") {
			output, err = utils.RunCommandInSSHSession(sClient, COMPUTE_NODE_EXECUTION_PATH+command)
		} else if strings.Contains(nodeType, "login") {
			output, err = utils.RunCommandInSSHSession(sClient, LOGIN_NODE_EXECUTION_PATH+command)
		} else {
			output, err = utils.RunCommandInSSHSession(sClient, command)
		}

		if err != nil {
			return fmt.Errorf("failed to execute command '%s' via SSH: %v", command, err)
		}

		if command == "whoami" {
			if !utils.VerifyDataContains(t, strings.TrimSpace(output), userName, logger) {
				return fmt.Errorf("unexpected user: expected '%s', got '%s'", userName, strings.TrimSpace(output))
			}
		} else if strings.TrimSpace(output) == "" {
			return fmt.Errorf("output for command '%s' is empty", command)
		}
	}

	return nil
}

// VerifyLDAPConfig verifies LDAP configuration on a remote machine by executing commands via SSH.
// It checks LDAP configuration files and performs an LDAP search to validate the configuration.
// Returns: Error if verification fails, nil otherwise.
func VerifyLDAPConfig(t *testing.T, sClient *ssh.Client, nodeType, ldapServerIP, ldapDomain, ldapUser string, logger *utils.AggregatedLogger) error {
	// Perform an LDAP search to validate the configuration
	ldapSearchCmd := fmt.Sprintf("ldapsearch -x -H ldap://%s -b dc=%s,dc=%s", ldapServerIP, strings.Split(ldapDomain, ".")[0], strings.Split(ldapDomain, ".")[1])
	ldapSearchActual, err := utils.RunCommandInSSHSession(sClient, ldapSearchCmd)
	if err != nil {
		return fmt.Errorf("failed to execute command '%s' via SSH: %v", ldapSearchCmd, err)
	}
	expected := fmt.Sprintf("dc=%s,dc=%s", strings.Split(ldapDomain, ".")[0], strings.Split(ldapDomain, ".")[1])
	if !utils.VerifyDataContains(t, ldapSearchActual, expected, logger) {
		return fmt.Errorf("LDAP search failed: Expected '%s', got '%s'", expected, ldapSearchActual)
	}

	// Verify the LDAP user exists in the search results
	if !utils.VerifyDataContains(t, ldapSearchActual, "uid: "+ldapUser, logger) {
		return fmt.Errorf("LDAP user %s not found in search results", ldapUser)
	}

	logger.Info(t, fmt.Sprintf("%s LDAP configuration verification completed successfully.", nodeType))
	return nil
}

// VerifyLDAPServerConfig verifies LDAP configuration on a remote machine by executing commands via SSH.
// It checks LDAP configuration files and performs an LDAP search to validate the configuration.
// Returns: Error if verification fails, nil otherwise.
func VerifyLDAPServerConfig(t *testing.T, sClient *ssh.Client, ldapAdminpassword, ldapDomain, ldapUser string, logger *utils.AggregatedLogger) error {
	// Check LDAP configuration files
	ldapConfigCheckCmd := "cat /etc/ldap/ldap.conf"
	actual, err := utils.RunCommandInSSHSession(sClient, ldapConfigCheckCmd)
	if err != nil {
		return fmt.Errorf("failed to execute command '%s' via SSH: %v", ldapConfigCheckCmd, err)
	}
	expected := fmt.Sprintf("BASE   dc=%s,dc=%s", strings.Split(ldapDomain, ".")[0], strings.Split(ldapDomain, ".")[1])
	if !utils.VerifyDataContains(t, actual, expected, logger) {
		return fmt.Errorf("LDAP configuration check failed: Expected '%s', got '%s'", expected, actual)
	}

	// Perform an LDAP search to validate the configuration
	ldapSearchCmd := fmt.Sprintf("ldapsearch -x -D \"cn=admin,dc=%s,dc=%s\" -w %s -b \"ou=people,dc=%s,dc=%s\" -s sub \"(objectClass=*)\"", strings.Split(ldapDomain, ".")[0], strings.Split(ldapDomain, ".")[1], ldapAdminpassword, strings.Split(ldapDomain, ".")[0], strings.Split(ldapDomain, ".")[1])
	ldapSearchActual, err := utils.RunCommandInSSHSession(sClient, ldapSearchCmd)
	if err != nil {
		return fmt.Errorf("failed to execute command '%s' via SSH: %v", ldapSearchCmd, err)
	}
	expected = fmt.Sprintf("dc=%s,dc=%s", strings.Split(ldapDomain, ".")[0], strings.Split(ldapDomain, ".")[1])
	if !utils.VerifyDataContains(t, ldapSearchActual, expected, logger) {
		return fmt.Errorf("LDAP search failed: Expected '%s', got '%s'", expected, ldapSearchActual)
	}

	// Verify the LDAP user exists in the search results
	if !utils.VerifyDataContains(t, ldapSearchActual, "uid: "+ldapUser, logger) {
		return fmt.Errorf("LDAP user %s not found in search results", ldapUser)
	}

	logger.Info(t, "LDAP Server configuration verification completed successfully.")
	return nil
}

// verifyPTRRecords verifies PTR records for 'mgmt' or 'login' nodes and ensures their resolution via SSH.
// It retrieves hostnames, performs nslookup to verify PTR records, and returns an error if any step fails.
func verifyPTRRecords(t *testing.T, sClient *ssh.Client, publicHostName, publicHostIP, privateHostName string, managementNodeIPList []string, loginNodeIP string, domainName string, logger *utils.AggregatedLogger) error {
	// Slice to hold the list of hostnames
	var hostNamesList []string

	// Check if the management node IP list is empty
	if len(managementNodeIPList) == 0 {
		return fmt.Errorf("management node IPs cannot be empty")
	}

	// Execute the command to get the hostnames
	hostNames, err := utils.RunCommandInSSHSession(sClient, "lshosts -w | awk 'NR>1' | awk '{print $1}' | grep -E 'mgmt|login'")
	if err != nil {
		return fmt.Errorf("failed to execute command to retrieve hostnames: %w", err)
	}

	// Process the retrieved hostnames
	for _, hostName := range strings.Split(strings.TrimSpace(hostNames), "\n") {
		// Append domain name to hostnames if not already present
		if !strings.Contains(hostName, domainName) {
			hostNamesList = append(hostNamesList, hostName+"."+domainName)
		} else {
			hostNamesList = append(hostNamesList, hostName)
		}
	}

	// Function to perform nslookup and verify PTR records
	verifyPTR := func(sshClient *ssh.Client, nodeDesc string) error {
		for _, hostName := range hostNamesList {
			// Execute nslookup command for the hostname
			nsOutput, err := utils.RunCommandInSSHSession(sshClient, "nslookup "+hostName)
			if err != nil {
				return fmt.Errorf("failed to execute nslookup command for %s: %w", hostName, err)
			}

			// Verify the PTR record existence in the search results
			if utils.VerifyDataContains(t, nsOutput, "server can't find", logger) {
				return fmt.Errorf("PTR record for %s not found in search results", hostName)
			}
		}
		logger.Info(t, fmt.Sprintf("PTR Records for %s completed successfully.", nodeDesc))
		return nil
	}

	// Iterate over management nodes
	for _, mgmtIP := range managementNodeIPList {
		// Connect to the management node via SSH
		mgmtSshClient, connectionErr := utils.ConnectToHost(publicHostName, publicHostIP, privateHostName, mgmtIP)
		if connectionErr != nil {
			return fmt.Errorf("failed to connect to the management node %s via SSH: %v", mgmtIP, connectionErr)
		}
		defer mgmtSshClient.Close()

		// Verify PTR records on management node
		if err := verifyPTR(mgmtSshClient, fmt.Sprintf("management node %s", mgmtIP)); err != nil {
			return err
		}
	}
	logger.Info(t, "Verify PTR Records for management nodes completed successfully.")

	// If login node IP is provided, verify PTR records on login node as well
	if loginNodeIP != "" {
		loginSshClient, connectionErr := utils.ConnectToHost(publicHostName, publicHostIP, privateHostName, loginNodeIP)
		if connectionErr != nil {
			return fmt.Errorf("failed to connect to the login node %s via SSH: %v", loginNodeIP, connectionErr)
		}
		defer loginSshClient.Close()

		// Verify PTR records on login node
		if err := verifyPTR(loginSshClient, fmt.Sprintf("login node %s", loginNodeIP)); err != nil {
			return err
		}
	}

	logger.Info(t, "Verify PTR Records for login node completed successfully.")
	logger.Info(t, "Verify PTR Records completed successfully.")
	return nil
}

// CreateServiceInstanceAndReturnGUID creates a service instance on IBM Cloud, verifies its creation, and retrieves the service instance ID.
// It logs into IBM Cloud using the provided API key, region, and resource group, then creates the service instance
// with the specified instance name. If the creation is successful, it retrieves and returns the service instance ID.
// Returns:
// - string: service instance ID if successful
// - error: error if any step fails
func CreateServiceInstanceAndReturnGUID(t *testing.T, apiKey, region, resourceGroup, instanceName string, logger *utils.AggregatedLogger) (string, error) {
	// Log in to IBM Cloud using the API key and region
	if err := utils.LoginIntoIBMCloudUsingCLI(t, apiKey, region, resourceGroup); err != nil {
		return "", fmt.Errorf("failed to log in to IBM Cloud: %w", err)
	}

	// Create the service instance
	createServiceInstanceCmd := fmt.Sprintf("ibmcloud resource service-instance-create %s kms tiered-pricing %s", instanceName, region)
	cmdCreate := exec.Command("bash", "-c", createServiceInstanceCmd)
	createOutput, err := cmdCreate.CombinedOutput()
	if err != nil {
		return "", fmt.Errorf("failed to create service instance: %w", err)
	}

	// Verify that the service instance was created successfully
	expectedMessage := fmt.Sprintf("Service instance %s was created", instanceName)
	if !utils.VerifyDataContains(t, string(createOutput), expectedMessage, logger) {
		return "", fmt.Errorf("service instance creation failed: %s", string(createOutput))
	}

	// Extract and return the service instance ID
	serviceInstanceID := strings.TrimSpace(strings.Split(strings.Split(string(createOutput), "GUID:")[1], "Location:")[0])
	if len(serviceInstanceID) == 0 {
		return "", fmt.Errorf("service instance ID not found")
	}

	logger.Info(t, fmt.Sprintf("Service Instance '%s' created successfully. Instance ID: %s", instanceName, serviceInstanceID))
	return serviceInstanceID, nil
}

// DeleteServiceInstance deletes a service instance on IBM Cloud and its associated keys, and verifies the deletion.
// It logs into IBM Cloud using the provided API key, region, and resource group, then deletes the service instance
// with the specified instance name. If the deletion is successful, it logs the success and returns nil;
// otherwise, it returns an error.
// Returns:
// - error: error if any step fails
func DeleteServiceInstance(t *testing.T, apiKey, region, resourceGroup, instanceName string, logger *utils.AggregatedLogger) error {

	// Log in to IBM Cloud using the API key and region
	if err := utils.LoginIntoIBMCloudUsingCLI(t, apiKey, region, resourceGroup); err != nil {
		return fmt.Errorf("failed to log in to IBM Cloud: %w", err)
	}

	// Retrieve the service instance GUID
	retrieveServiceCmd := fmt.Sprintf("ibmcloud resource service-instance --service-name %s --output", instanceName)
	cmdRetrieveGUID := exec.Command("bash", "-c", retrieveServiceCmd)
	retrieveOutput, err := cmdRetrieveGUID.CombinedOutput()
	if err != nil {
		return fmt.Errorf("failed to retrieve service instance GUID: %w", err)
	}
	serviceInstanceID := strings.TrimSpace(strings.Split(strings.Split(string(retrieveOutput), "GUID:")[1], "Location:")[0])

	if len(serviceInstanceID) == 0 {
		return fmt.Errorf("service instance ID not found")
	}

	logger.Info(t, fmt.Sprintf("Service instance '%s' retrieved successfully. Instance ID: %s", instanceName, serviceInstanceID))

	// Retrieve and delete associated keys
	getAssociatedKeysCmd := fmt.Sprintf("ibmcloud kp keys -i %s | awk 'NR>3' | awk '{print $1}'", serviceInstanceID)
	cmdKeysID := exec.Command("bash", "-c", getAssociatedKeysCmd)
	keysIDOutput, err := cmdKeysID.CombinedOutput()
	if err != nil {
		return fmt.Errorf("failed to retrieve associated keys: %w", err)
	}
	// Extract the GUID values of the keys
	keyLines := strings.Split(string(strings.TrimSpace(strings.Split(string(keysIDOutput), "kms.cloud.ibm.com")[1])), "\n")
	for _, key := range keyLines {
		if key != "" {
			// Delete each key
			deleteKeyCmd := fmt.Sprintf("ibmcloud kp key delete %s -i %s", key, serviceInstanceID)
			cmdDeleteKey := exec.Command("bash", "-c", deleteKeyCmd)
			deleteKeyOutput, err := cmdDeleteKey.CombinedOutput()
			if err != nil {
				return fmt.Errorf("failed to delete key %s: %w", key, err)
			}
			if !utils.VerifyDataContains(t, string(deleteKeyOutput), "Deleted Key", logger) {
				return fmt.Errorf("failed to delete key: %s", string(deleteKeyOutput))
			}
		}
	}

	// Delete the service instance
	deleteInstanceCmd := fmt.Sprintf("ibmcloud resource service-instance-delete %s -f", instanceName)
	cmdDeleteInstance := exec.Command("bash", "-c", deleteInstanceCmd)
	deleteInstanceOutput, err := cmdDeleteInstance.CombinedOutput()
	if err != nil {
		return fmt.Errorf("failed to delete instance %s: %w", instanceName, err)
	}

	if !utils.VerifyDataContains(t, string(deleteInstanceOutput), "deleted successfully", logger) {
		return fmt.Errorf("failed to delete instance: %s", string(deleteInstanceOutput))
	}

	logger.Info(t, "Service instance deleted successfully")
	return nil
}

// CreateKey creates a key in a specified service instance on IBM Cloud.
// It logs into IBM Cloud using the provided API key, region, and resource group, then creates a key
// with the specified key name in the specified service instance. If the creation is successful, it verifies the key's creation.
// Returns:
// - error: error if any step fails
func CreateKey(t *testing.T, apiKey, region, resourceGroup, instanceName, keyName string, logger *utils.AggregatedLogger) error {

	// Log in to IBM Cloud using the API key and region
	if err := utils.LoginIntoIBMCloudUsingCLI(t, apiKey, region, resourceGroup); err != nil {
		return fmt.Errorf("failed to log in to IBM Cloud: %w", err)
	}

	// Retrieve the service instance GUID
	retrieveServiceCmd := fmt.Sprintf("ibmcloud resource service-instance --service-name %s --output", instanceName)
	cmdRetrieveGUID := exec.Command("bash", "-c", retrieveServiceCmd)
	retrieveOutput, err := cmdRetrieveGUID.CombinedOutput()
	if err != nil {
		return fmt.Errorf("failed to retrieve service instance GUID: %w", err)
	}

	serviceInstanceID := strings.TrimSpace(strings.Split(strings.Split(string(retrieveOutput), "GUID:")[1], "Location:")[0])
	if len(serviceInstanceID) == 0 {
		return fmt.Errorf("service instance ID not found")
	}

	logger.Info(t, fmt.Sprintf("Service instance '%s' retrieved successfully. Instance ID: %s", instanceName, serviceInstanceID))

	// Create key

	createKeyCmd := fmt.Sprintf("ibmcloud kp key create %s -i %s", keyName, serviceInstanceID)
	cmdKey := exec.Command("bash", "-c", createKeyCmd)
	keyOutput, err := cmdKey.CombinedOutput()
	if err != nil {
		return fmt.Errorf("failed to create key: %w. Output: %s", err, string(keyOutput))
	}
	if !utils.VerifyDataContains(t, string(keyOutput), "OK", logger) {
		return fmt.Errorf("failed to create key: %s", string(keyOutput))
	}

	logger.Info(t, fmt.Sprintf("Key '%s' created successfully in service instance '%s'", keyName, serviceInstanceID))

	// Retrieve and verify key
	retrieveKeyCmd := fmt.Sprintf("ibmcloud kp keys -i %s", serviceInstanceID)
	cmdRetrieveKey := exec.Command("bash", "-c", retrieveKeyCmd)
	retrieveKeyOutput, err := cmdRetrieveKey.CombinedOutput()
	if err != nil {
		return fmt.Errorf("failed to retrieve keys: %w", err)
	}
	if !utils.VerifyDataContains(t, string(retrieveKeyOutput), keyName, logger) {
		return fmt.Errorf("key retrieval failed: %s", string(retrieveKeyOutput))
	}

	logger.Info(t, fmt.Sprintf("Key '%s' created successfully in service instance '%s'", keyName, serviceInstanceID))
	return nil
}

// LSFDNSCheck checks the DNS configuration on a list of nodes to ensure it contains the expected domain.
// It supports both Ubuntu and RHEL-based systems by executing the appropriate DNS check command.
// The function logs the results and returns an error if the DNS configuration is not as expected.
// Returns an error if the DNS configuration is not as expected or if any command execution fails.
func LSFDNSCheck(t *testing.T, sClient *ssh.Client, ipsList []string, domain string, logger *utils.AggregatedLogger) error {
	// Commands to check DNS on different OS types
	rhelDNSCheckCmd := "cat /etc/resolv.conf"
	ubuntuDNSCheckCmd := "resolvectl status"

	// Check if the node list is empty
	if len(ipsList) == 0 {
		return fmt.Errorf("ERROR: ips cannot be empty")
	}

	// Loop through each IP in the list
	for _, ip := range ipsList {
		var dnsCmd string

		// Get the OS name of the compute node
		osName, osNameErr := GetOSNameOfNode(t, sClient, ip, logger)
		if osNameErr != nil {
			return osNameErr
		}

		// Determine the appropriate command to check DNS based on the OS
		switch strings.ToLower(osName) {
		case "ubuntu":
			dnsCmd = ubuntuDNSCheckCmd
		default:
			dnsCmd = rhelDNSCheckCmd
		}

		// Build the SSH command to check DNS on the node
		command := fmt.Sprintf("ssh %s %s", ip, dnsCmd)

		// Execute the command and get the output
		output, err := utils.RunCommandInSSHSession(sClient, command)
		if err != nil {
			return fmt.Errorf("failed to execute '%s' command on (%s) node: %v", dnsCmd, ip, err)
		}

		// Check if the output contains the domain name
		if strings.Contains(strings.ToLower(osName), "rhel") {
			if !utils.VerifyDataContains(t, output, domain, logger) && utils.VerifyDataContains(t, output, "Generated by NetworkManager", logger) {
				return fmt.Errorf("DNS check failed on (%s) node and found:\n%s", ip, output)
			}
		} else { // For other OS types, currently only Ubuntu
			if !utils.VerifyDataContains(t, output, domain, logger) {
				return fmt.Errorf("DNS check failed on (%s) node and found:\n%s", ip, output)
			}
		}

		// Log a success message
		logger.Info(t, fmt.Sprintf("DNS is correctly set for (%s) node", ip))
	}

	return nil
}

// HPCAddNewLDAPUser adds a new LDAP user by modifying an existing user's configuration and running necessary commands.
// It reads the existing LDAP user configuration, replaces the existing user information with the new LDAP user
// information, creates a new LDIF file on the LDAP server, and then runs LDAP commands to add the new user. Finally, it
// verifies the addition of the new LDAP user by searching the LDAP server.
// Returns an error if the  if any step fails
func HPCAddNewLDAPUser(t *testing.T, sClient *ssh.Client, ldapAdminPassword, ldapDomain, ldapUser, newLdapUser string, logger *utils.AggregatedLogger) error {
	// Define the command to read the existing LDAP user configuration
	getLDAPUserConf := "cat /opt/users.ldif"
	actual, err := utils.RunCommandInSSHSession(sClient, getLDAPUserConf)
	if err != nil {
		return fmt.Errorf("failed to execute command '%s' via SSH: %v", getLDAPUserConf, err)
	}

	// Replace the existing LDAP user name with the new LDAP user name
	ldifContent := strings.ReplaceAll(actual, ldapUser, newLdapUser)

	// Create the new LDIF file on the LDAP server
	_, fileCreationErr := utils.ToCreateFileWithContent(t, sClient, ".", "user2.ldif", ldifContent, logger)
	if fileCreationErr != nil {
		return fmt.Errorf("failed to create file on LDAP server: %w", fileCreationErr)
	}

	// Parse the LDAP domain for reuse
	domainParts := strings.Split(ldapDomain, ".")
	if len(domainParts) != 2 {
		return fmt.Errorf("invalid LDAP domain format: %s", ldapDomain)
	}
	dc1, dc2 := domainParts[0], domainParts[1]

	// Define the command to add the new LDAP user using the ldapadd command
	ldapAddCmd := fmt.Sprintf(
		"ldapadd -x -D cn=admin,dc=%s,dc=%s -w %s -f user2.ldif",
		dc1, dc2, ldapAdminPassword,
	)
	ldapAddOutput, err := utils.RunCommandInSSHSession(sClient, ldapAddCmd)
	if err != nil {
		return fmt.Errorf("failed to execute command '%s' via SSH: %v", ldapAddCmd, err)
	}

	// Verify the new LDAP user exists in the search results
	if !utils.VerifyDataContains(t, ldapAddOutput, "uid="+newLdapUser, logger) {
		return fmt.Errorf("LDAP user %s not found in add command output", newLdapUser)
	}

	// Define the command to search for the new LDAP user to verify the addition
	ldapSearchCmd := fmt.Sprintf(
		"ldapsearch -x -D \"cn=admin,dc=%s,dc=%s\" -w %s -b \"ou=people,dc=%s,dc=%s\" -s sub \"(objectClass=*)\"",
		dc1, dc2, ldapAdminPassword, dc1, dc2,
	)
	ldapSearchOutput, err := utils.RunCommandInSSHSession(sClient, ldapSearchCmd)
	if err != nil {
		return fmt.Errorf("failed to execute command '%s' via SSH: %v", ldapSearchCmd, err)
	}

	// Verify the new LDAP user exists in the search results
	if !utils.VerifyDataContains(t, ldapSearchOutput, "uid: "+newLdapUser, logger) {
		return fmt.Errorf("LDAP user %s not found in search results", newLdapUser)
	}

	logger.Info(t, fmt.Sprintf("New LDAP user %s created successfully", newLdapUser))
	return nil
}

// VerifyCosServiceInstance verifies if the Cloud Object Storage (COS) service instance details.
// and correctly set in the specified resource group and cluster prefix.
// Returns: An error if the verification fails, otherwise nil
func VerifyCosServiceInstance(t *testing.T, apiKey, region, resourceGroup, clusterPrefix string, logger *utils.AggregatedLogger) error {

	// If the resource group is "null", set it to a custom resource group with the format "clusterPrefix-workload-rg"
	if strings.Contains(resourceGroup, "null") {
		resourceGroup = fmt.Sprintf("%s-workload-rg", clusterPrefix)
	}

	// Log in to IBM Cloud using the API key and VPC region
	if err := utils.LoginIntoIBMCloudUsingCLI(t, apiKey, region, resourceGroup); err != nil {
		return fmt.Errorf("failed to log in to IBM Cloud: %w", err)
	}

	// Construct the command to check for the COS service instance
	resourceCosServiceInstanceCmd := fmt.Sprintf("ibmcloud resource service-instances --service-name cloud-object-storage | grep %s-hpc-cos", clusterPrefix)
	cosServiceInstanceCmd := exec.Command("bash", "-c", resourceCosServiceInstanceCmd)
	output, err := cosServiceInstanceCmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("failed to execute command to check COS service instance: %w", err)
	}

	logger.Info(t, "cos details : "+string(output))

	// Check if the COS service instance contains the cluster prefix and is active
	if !utils.VerifyDataContains(t, string(output), clusterPrefix, logger) {
		return fmt.Errorf("COS service instance with prefix %s not found", clusterPrefix)
	}

	if !utils.VerifyDataContains(t, string(output), "active", logger) {
		return fmt.Errorf("COS service instance with prefix %s is not active", clusterPrefix)
	}

	logger.Info(t, "COS service instance verified as expected")
	return nil
}

// ValidateFlowLogs verifies if the flow logs are being created successfully or not
// and correctly set in the specified resource group and cluster prefix.
// Returns: An error if the verification fails, otherwise nil
func ValidateFlowLogs(t *testing.T, apiKey, region, resourceGroup, clusterPrefix string, logger *utils.AggregatedLogger) error {

	// If the resource group is "null", set it to a custom resource group with the format "clusterPrefix-workload-rg"
	if strings.Contains(resourceGroup, "null") {
		resourceGroup = fmt.Sprintf("%s-workload-rg", clusterPrefix)
	}
	// Log in to IBM Cloud using the API key and region
	if err := utils.LoginIntoIBMCloudUsingCLI(t, apiKey, region, resourceGroup); err != nil {
		return fmt.Errorf("failed to log in to IBM Cloud: %w", err)
	}
	flowLogName := fmt.Sprintf("%s-hpc-vpc", clusterPrefix)
	// Fetching the flow log details
	retrieveFlowLogs := fmt.Sprintf("ibmcloud is flow-logs %s", flowLogName)
	cmdRetrieveFlowLogs := exec.Command("bash", "-c", retrieveFlowLogs)
	flowLogsOutput, err := cmdRetrieveFlowLogs.CombinedOutput()
	if err != nil {
		return fmt.Errorf("failed to retrieve keys: %w", err)
	}
	if !utils.VerifyDataContains(t, string(flowLogsOutput), flowLogName, logger) {
		return fmt.Errorf("flow logs retrieval failed: %s", string(flowLogsOutput))
	}

	logger.Info(t, fmt.Sprintf("flow Logs '%s' retrieved successfully", flowLogName))
	return nil
}
