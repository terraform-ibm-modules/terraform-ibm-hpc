package tests

import (
	"bufio"
	"encoding/json"
	"errors"
	"fmt"
	"maps"
	"os"
	"os/exec"
	"regexp"
	"sort"
	"strconv"
	"strings"
	"testing"
	"time"

	"github.com/terraform-ibm-modules/ibmcloud-terratest-wrapper/testhelper"
	utils "github.com/terraform-ibm-modules/terraform-ibm-hpc/utilities"
	"golang.org/x/crypto/ssh"
)

const (
	defaultSleepDuration           = 30 * time.Second
	timeOutForDynamicNodeDisappear = 15 * time.Minute
	jobCompletionWaitTime          = 50 * time.Second
	dynamicNodeWaitTime            = 3 * time.Minute
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

// LSFCheckClusterName checks if the provided cluster ID matches the expected value.
// It uses the provided SSH client to execute the 'lsid' command and verifies
// if the expected cluster ID is present in the command output.
// Returns an error if the checks fail.
func LSFCheckClusterName(t *testing.T, sClient *ssh.Client, expectedClusterName string, logger *utils.AggregatedLogger) error {

	// Execute the 'lsid' command to get the cluster ID
	command := "source /opt/ibm/lsf/conf/profile.lsf; lsid"
	output, err := utils.RunCommandInSSHSession(sClient, command)
	if err != nil {
		return fmt.Errorf("failed to execute 'lsid' command: %w", err)
	}

	// Verify if the expected cluster ID is present in the output
	if !utils.VerifyDataContains(t, output, "My cluster name is "+expectedClusterName, logger) {
		// Extract actual cluster version from the output for better error reporting
		actualValue := strings.TrimSpace(strings.Split(strings.Split(output, "My cluster name is")[1], "My master name is")[0])
		return fmt.Errorf("expected cluster ID %s , but found %s", expectedClusterName, actualValue)
	}
	// Log success if no errors occurred
	logger.Info(t, fmt.Sprintf("Cluster ID is set as expected : %s", expectedClusterName))
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
	if !utils.VerifyDataContains(t, output, "My master name is "+expectedMasterName, logger) {
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
	if !utils.VerifyDataContains(t, string(out), "Stopping", logger) || !utils.VerifyDataContains(t, string(out), "Starting", logger) {
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
		time.Sleep(63 * time.Second)
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

// WaitForDynamicNodeDisappearance monitors the 'bhosts -w' command output over SSH, waiting for a dynamic node to disappear.
// It sets a timeout and checks for disappearance until completion. Returns an error if the timeout is exceeded or if
// there is an issue running the SSH command.
func WaitForDynamicNodeDisappearance(t *testing.T, sClient *ssh.Client, logger *utils.AggregatedLogger) error {

	const (
		statusOK      = "ok"
		workerKeyword = "-comp-"
	)

	// Record the start time of the job execution
	startTime := time.Now()

	// Continuously monitor the dynamic node until it disappears or the timeout occurs
	for time.Since(startTime) < timeOutForDynamicNodeDisappear {
		// Run the 'bhosts -w' command on the remote SSH server
		command := "bhosts -w"
		output, err := utils.RunCommandInSSHSession(sClient, command)
		if err != nil {
			return fmt.Errorf("failed to execute SSH command '%s': %w", command, err)
		}

		// Split the output into lines and process each line
		lines := strings.Split(output, "\n")
		foundRelevantNode := false
		for _, line := range lines {
			// Check if the line contains "ok" and does not contain "-comp-"
			if strings.Contains(line, statusOK) && !strings.Contains(line, workerKeyword) {
				foundRelevantNode = true
				logger.Info(t, fmt.Sprintf("Relevant dynamic node still present: %s", line))
				break
			}
		}

		if foundRelevantNode {
			// Wait and retry if a relevant node is still present
			time.Sleep(90 * time.Second)
		} else {
			// All relevant dynamic nodes have disappeared
			logger.Info(t, "All relevant dynamic nodes have disappeared!")
			return nil
		}
	}

	// Timeout exceeded while waiting for dynamic nodes to disappear
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

	// Check the result of CheckAppCenterSetup for any errors
	if err := CheckAppCenterSetup(t, sClient, logger); err != nil {
		// If there's an error, return it wrapped with a custom message
		return fmt.Errorf("CheckAppCenterSetup pmcadmin list validation failed : %w", err)
	}

	// Command to check if APP center port is listening as expected
	portStatusCommand := "netstat -tuln | grep 8443"
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

// // LSFGETDynamicComputeNodeIPs retrieves the IP addresses of static nodes with a status of "ok" in an LSF cluster.
// // It excludes nodes containing "worker" in their HOST_NAME and processes the IP addresses from the node names.
// // The function executes the "bhosts -w" command over an SSH session, parses the output, and returns a sorted slice of IP addresses.
// // Returns:
// // - A sorted slice of IP addresses as []string.
// // - An error if the command execution or output parsing fails.
// func LSFGETDynamicComputeNodeIPs(t *testing.T, sClient *ssh.Client, logger *utils.AggregatedLogger) ([]string, error) {
// 	const (
// 		statusOK      = "ok"
// 		workerKeyword = "worker"
// 	)

// 	// Run the "bhosts -w" command to get the node status
// 	nodeStatus, err := utils.RunCommandInSSHSession(sClient, "bhosts -w")
// 	if err != nil {
// 		return nil, fmt.Errorf("failed to execute 'bhosts' command: %w", err)
// 	}

// 	var workerIPs []string

// 	// Parse the command output
// 	scanner := bufio.NewScanner(strings.NewReader(nodeStatus))
// 	for scanner.Scan() {
// 		fields := strings.Fields(scanner.Text())

// 		// Ensure fields exist and match the required conditions
// 		if len(fields) > 1 && fields[1] == statusOK && !strings.Contains(fields[0], workerKeyword) {
// 			// Extract the IP address from the HOST_NAME (expected format: <host-name>-<ip-part>)
// 			parts := strings.Split(fields[0], "-")
// 			if len(parts) >= 4 { // Ensure enough segments exist
// 				ip := strings.Join(parts[len(parts)-4:], ".")
// 				workerIPs = append(workerIPs, ip)
// 			}
// 		}
// 	}

// 	// Check for scanning errors
// 	if err := scanner.Err(); err != nil {
// 		return nil, fmt.Errorf("error scanning node status: %w", err)
// 	}

// 	// Sort the IP addresses
// 	sort.Strings(workerIPs)

// 	// Log the retrieved IPs
// 	logger.Info(t, fmt.Sprintf("Retrieved Worker IPs: %v", workerIPs))

// 	return workerIPs, nil
// }

// LSFGETDynamicComputeNodeIPs retrieves the IP addresses of static nodes with a status of "ok" in an LSF cluster.
// It excludes nodes containing "worker" in their HOST_NAME and processes the IP addresses from the node names.
// The function executes the "bhosts -w" command over an SSH session, parses the output, and returns a sorted slice of IP addresses.
// Returns:
// - A sorted slice of IP addresses as []string.
// - An error if the command execution or output parsing fails.
func LSFGETDynamicComputeNodeIPs(t *testing.T, sClient *ssh.Client, logger *utils.AggregatedLogger) ([]string, error) {
	const (
		statusOK      = "ok"
		workerKeyword = "-comp-"
	)

	// Run the "bhosts -w" command to get the node status
	nodeStatus, err := utils.RunCommandInSSHSession(sClient, "bhosts -w")
	if err != nil {
		return nil, fmt.Errorf("failed to execute 'bhosts' command: %w", err)
	}

	var workerIPs []string

	// Parse the command output
	scanner := bufio.NewScanner(strings.NewReader(nodeStatus))
	for scanner.Scan() {
		fields := strings.Fields(scanner.Text())

		// Ensure fields exist and match the required conditions
		if len(fields) > 1 && fields[1] == statusOK && !strings.Contains(fields[0], workerKeyword) {
			// Extract the IP address from the HOST_NAME (expected format: <host-name>-<ip-part>)
			parts := strings.Split(fields[0], "-")
			if len(parts) >= 4 { // Ensure enough segments exist
				ip := strings.Join(parts[len(parts)-4:], ".")
				workerIPs = append(workerIPs, ip)
			}
		}
	}

	// Check for scanning errors
	if err := scanner.Err(); err != nil {
		return nil, fmt.Errorf("error scanning node status: %w", err)
	}

	// Sort the IP addresses
	sort.Strings(workerIPs)

	// Log the retrieved IPs
	logger.Info(t, fmt.Sprintf("Retrieved Dynamic Worker IPs: %v", workerIPs))

	return workerIPs, nil
}

// HPCGETDynamicComputeNodeIPs retrieves the IP addresses of dynamic worker nodes with a status of "ok".
// It returns a slice of IP addresses and an error if there was a problem executing the command or parsing the output.
func HPCGETDynamicComputeNodeIPs(t *testing.T, sClient *ssh.Client, logger *utils.AggregatedLogger) ([]string, error) {
	// Run the "bhosts -w" command to get the node status
	nodeStatus, err := utils.RunCommandInSSHSession(sClient, "bhosts -w")
	if err != nil {
		return nil, fmt.Errorf("failed to execute 'bhosts' command: %w", err)
	}

	var workerIPs []string

	scanner := bufio.NewScanner(strings.NewReader(nodeStatus))
	for scanner.Scan() {
		fields := strings.Fields(scanner.Text())

		if len(fields) > 1 && fields[1] == "ok" {
			// Split the input string by hyphen
			parts := strings.Split(fields[0], "-")

			// Extract the IP address part (expected format: <host-name>-<ip-part>)
			if len(parts) >= 4 {
				ip := strings.Join(parts[len(parts)-4:], ".")
				workerIPs = append(workerIPs, ip)
			}
		}
	}

	// Check for scanning errors
	if err := scanner.Err(); err != nil {
		return nil, fmt.Errorf("error scanning node status: %w", err)
	}

	// Sort the IP addresses
	sort.Strings(workerIPs)

	// Log the retrieved IPs
	logger.Info(t, fmt.Sprintf("Retrieved Dynamic Worker IPs: %v", workerIPs))

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
			if !utils.VerifyDataContains(t, line, processes[i], logger) || !utils.VerifyDataContains(t, line, expectedStatus, logger) {
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
// Validates the number of SSH keys in each authorized_keys file against expected values.
func LSFCheckSSHKeyForManagementNode(t *testing.T, sClient *ssh.Client, numOfKeys int, logger *utils.AggregatedLogger) error {
	// Retrieve authorized_keys paths from the management node
	pathList, err := runSSHCommandAndGetPaths(sClient)
	if err != nil {
		return fmt.Errorf("failed to retrieve authorized_keys paths: %w", err)
	}

	// Log the list of authorized_keys paths
	logger.Info(t, fmt.Sprintf("List of authorized_keys paths: %q", pathList))

	// Generate expected number of SSH keys for each file path
	filePathMap := HPCGenerateFilePathMap(numOfKeys)

	// Verify SSH key occurrences for each path
	for _, path := range pathList {
		cmd := fmt.Sprintf("sudo su -l root -c 'cat %s'", path)
		out, err := utils.RunCommandInSSHSession(sClient, cmd)
		if err != nil {
			return fmt.Errorf("failed to run command on %s: %w", path, err)
		}

		// Count occurrences of SSH keys and log information
		expectedCount := filePathMap[path]
		actualCount := utils.CountStringOccurrences(out, "ssh-rsa ")
		logger.Info(t, fmt.Sprintf("Expected: %d, Occurrences: %d, Path: %s", expectedCount, actualCount, path))

		// Validate the number of occurrences
		if expectedCount != actualCount {
			return fmt.Errorf("mismatch in occurrences for path %s: expected %d, got %d", path, expectedCount, actualCount)
		}
	}

	// Log success
	logger.Info(t, "SSH key check successful")
	return nil
}

// LSFCheckSSHKeyForManagementNodes verifies SSH key configurations for each management node in the provided list.
// Ensures that the number of keys in authorized_keys files match the expected values.
func LSFCheckSSHKeyForManagementNodes(t *testing.T, publicHostName, publicHostIP, privateHostName string, managementNodeIPList []string, numOfKeys int, logger *utils.AggregatedLogger) error {
	if len(managementNodeIPList) == 0 {
		return fmt.Errorf("management node IPs cannot be empty")
	}

	for _, mgmtIP := range managementNodeIPList {
		// Connect to the management node via SSH
		mgmtSshClient, err := utils.ConnectToHost(publicHostName, publicHostIP, privateHostName, mgmtIP)
		if err != nil {
			return fmt.Errorf("failed to connect to the management node %s via SSH: %w", mgmtIP, err)
		}

		defer func() {
			if err := mgmtSshClient.Close(); err != nil {
				logger.Info(t, fmt.Sprintf("failed to close mgmtSshClient: %v", err))
			}
		}()

		logger.Info(t, fmt.Sprintf("SSH connection to the management node %s successful", mgmtIP))

		// Verify SSH keys for the management node
		if err := LSFCheckSSHKeyForManagementNode(t, mgmtSshClient, numOfKeys, logger); err != nil {
			return fmt.Errorf("management node %s SSH key check failed: %w", mgmtIP, err)
		}
	}

	return nil
}

// HPCGenerateFilePathMap returns a map of authorized_keys paths to their expected
// number of SSH key occurrences based on the number of SSH keys provided (`numKeys`).
// It adjusts the expected values to account for default key counts.
func HPCGenerateFilePathMap(numKeys int) map[string]int {
	return map[string]int{
		"/home/vpcuser/.ssh/authorized_keys":  numKeys,     // Default value plus number of keys
		"/home/lsfadmin/.ssh/authorized_keys": numKeys + 1, // Default value plus number of keys
		"/root/.ssh/authorized_keys":          numKeys + 1, // Default value plus number of keys
	}
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
	if !utils.VerifyDataContains(t, output, "IBM Spectrum LSF "+expectedVersion, logger) {
		// Extract actual cluster version from the output for better error reporting
		actualValue := strings.TrimSpace(strings.Split(strings.Split(output, "IBM Spectrum LSF")[1], ", ")[0])
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

// HPCCheckFileMount checks if essential LSF directories (conf, config_done, das_staging_area, data, gui-conf, gui-logs, log, repository-path and work) exist
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

	// Define expected directories conditionally based on actual directories
	var expectedDirs []string

	switch {
	case utils.IsStringInSlice(actualDirs, "openldap"):
		expectedDirs = []string{
			"conf", "config_done", "das_staging_area", "data",
			"gui-logs", "log", "openldap", "repository-path", "work",
		}
	case utils.IsStringInSlice(actualDirs, "pac"):
		expectedDirs = []string{
			"conf", "config_done", "das_staging_area", "data",
			"gui-logs", "log", "lsf_packages", "pac", "repository-path", "work",
		}
	default:
		expectedDirs = []string{
			"conf", "config_done", "das_staging_area", "data",
			"gui-logs", "log", "repository-path", "work",
		}
	}

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
		lowMem = HPC_JOB_COMMAND_LOW_MEM_SOUTH
		medMem = HPC_JOB_COMMAND_MED_MEM_SOUTH
		highMem = HPC_JOB_COMMAND_HIGH_MEM_SOUTH
	} else {
		lowMem = HPC_JOB_COMMAND_LOW_MEM
		medMem = HPC_JOB_COMMAND_MED_MEM
		highMem = HPC_JOB_COMMAND_HIGH_MEM
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

	//	// Retrieve the list of file shares (retry once after 2s if it fails)
	fileSharesOutput, err := utils.RunCommandWithRetry(fileSharesCmd, 1, 60*time.Second)
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
				return fmt.Errorf("encryption-in-transit is unexpectedly enabled for the file shares")
			}
		} else {
			if !utils.VerifyDataContains(t, string(output), "user_managed", logger) {
				return fmt.Errorf("encryption-in-transit is unexpectedly disabled for the file shares")
			}
		}

	}
	logger.Info(t, "Encryption set as expected")
	return nil
}

// ValidateRequiredEnvironmentVariables checks if the required environment variables are set and valid
func ValidateRequiredEnvironmentVariables(envVars map[string]string) error {
	requiredVars := []string{"SSH_FILE_PATH", "SSH_KEY", "CLUSTER_NAME", "ZONE", "RESERVATION_ID"}
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

// HPCCheckFileMountAsLDAPUser checks if essential LSF directories (conf, config_done, das_staging_area, data, gui-conf, gui-logs, log, openldap, repository-path and work) exist
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
	expectedDirs := []string{"conf", "config_done", "das_staging_area", "data", "gui-logs", "log", "openldap", "repository-path", "work"}

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

	// Verify TLS_CACERT configuration
	expectedTLSCACert := "TLS_CACERT /etc/ssl/certs/ldap_cacert.pem"
	if !utils.VerifyDataContains(t, actual, expectedTLSCACert, logger) {
		return fmt.Errorf("TLS_CACERT verification failed: Expected configuration '%s' was not found in actual LDAP config: '%s'", expectedTLSCACert, actual)
	}

	// Verify TLS_REQCERT configuration
	expectedTLSReqCert := "TLS_REQCERT allow"
	if !utils.VerifyDataContains(t, actual, expectedTLSReqCert, logger) {
		return fmt.Errorf("TLS_REQCERT verification failed: Expected configuration '%s' was not found in actual LDAP config: '%s'", expectedTLSReqCert, actual)
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

		defer func() {
			if err := mgmtSshClient.Close(); err != nil {
				logger.Info(t, fmt.Sprintf("failed to close mgmtSshClient: %v", err))
			}
		}()

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

		defer func() {
			if err := loginSshClient.Close(); err != nil {
				logger.Info(t, fmt.Sprintf("failed to close loginSshClient: %v", err))
			}
		}()

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

	ldifContent = strings.ReplaceAll(ldifContent, "10000", "20000")

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
	flowLogName := fmt.Sprintf("%s-lsf-vpc", clusterPrefix)
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

// CheckSSSDServiceStatus checks the status of the SSSD service.
// It runs an SSH command to verify if the service is active and returns an error if it is not.
func CheckSSSDServiceStatus(t *testing.T, sClient *ssh.Client, logger *utils.AggregatedLogger) error {
	// Command to check the SSSD service status
	const sssdStatusCmd = "sudo systemctl status sssd.service -n 0"

	// Execute command to check service status
	sssdStatusOutput, err := utils.RunCommandInSSHSession(sClient, sssdStatusCmd)
	if err != nil {
		return fmt.Errorf("failed to execute command '%s' via SSH: %w", sssdStatusCmd, err)
	}

	// Verify if the SSSD service is active
	if utils.VerifyDataContains(t, sssdStatusOutput, "Active: active (running)", logger) {
		logger.Info(t, "The SSSD service is active.")
		return nil
	}

	// Return error if the service is not active, with output for debugging
	return fmt.Errorf("SSSD service is not active. Output: %s", sssdStatusOutput)
}

// GetLDAPServerCert retrieves the LDAP server certificate by connecting to the LDAP server via SSH.
// It requires the public host name, bastion IP, LDAP host name, and LDAP server IP as inputs.
// Returns the certificate as a string if successful, or an error otherwise.
func GetLDAPServerCert(publicHostName, bastionIP, ldapHostName, ldapServerIP string) (string, error) {
	// Establish SSH connection to LDAP server via bastion host
	sshClient, connectionErr := utils.ConnectToHost(publicHostName, bastionIP, ldapHostName, ldapServerIP)
	if connectionErr != nil {
		return "", fmt.Errorf("failed to connect to LDAP server via SSH: %w", connectionErr)
	}

	// Ensure SSH client is closed, log any close errors
	defer func() {
		if err := sshClient.Close(); err != nil {
			// Log the error instead of returning
			fmt.Printf("warning: failed to close sshClient: %v\n", err)
		}
	}()

	// Command to retrieve LDAP server certificate
	const ldapServerCertCmd = `cat /etc/ssl/certs/ldap_cacert.pem`

	// Execute command to retrieve certificate
	ldapServerCert, execErr := utils.RunCommandInSSHSession(sshClient, ldapServerCertCmd)
	if execErr != nil {
		return "", fmt.Errorf("failed to execute command '%s' via SSH: %w", ldapServerCertCmd, execErr)
	}

	return ldapServerCert, nil
}

// // GetClusterInfo retrieves key cluster-related information from Terraform variables.
// // It extracts the cluster ID, reservation ID, and cluster prefix from the provided test options.
// // Returns the cluster ID, reservation ID, and cluster prefix as strings.
// func GetClusterInfo(options *testhelper.TestOptions) (string, string, string) {
// 	var ClusterName, reservationID, clusterPrefix string

// 	// Retrieve values safely with type assertion
// 	if id, ok := options.TerraformVars["cluster_name"].(string); ok {
// 		ClusterName = id
// 	}
// 	if reservation, ok := options.TerraformVars["reservation_id"].(string); ok {
// 		reservationID = reservation
// 	}
// 	if prefix, ok := options.TerraformVars["cluster_prefix"].(string); ok {
// 		clusterPrefix = prefix
// 	}

// 	return ClusterName, reservationID, clusterPrefix
// }

// // GetClusterInfo extracts key cluster-related information from Terraform variables.
// // It returns the cluster name and cluster prefix as strings.
// func GetClusterInfo(options *testhelper.TestOptions) (clusterName string, clusterPrefix string) {
// 	// Retrieve the cluster name if present and of type string
// 	if name, ok := options.TerraformVars["cluster_name"].(string); ok {
// 		clusterName = name
// 	}

// 	// Retrieve the cluster prefix if present and of type string
// 	if prefix, ok := options.TerraformVars["cluster_prefix"].(string); ok {
// 		clusterPrefix = prefix
// 	}

// 	return
// }

// GetClusterInfo extracts key cluster-related information from Terraform variables.
// It returns cluster prefix as strings.
func GetClusterInfo(options *testhelper.TestOptions) (clusterPrefix string) {

	// Retrieve the cluster prefix if present and of type string
	if prefix, ok := options.TerraformVars["prefix"].(string); ok {
		clusterPrefix = prefix
	}

	return
}

// // SetJobCommands generates job commands customized for the specified solution type and zone.
// // For 'hpc' solutions, it dynamically generates commands based on the zone.
// // For other solution types, it applies predefined default commands for low and medium-memory tasks.
// func SetJobCommands(solution, zone string) (string, string) {
// 	var lowMemJobCmd, medMemJobCmd string

// 	// Determine the job commands based on the solution type
// 	if strings.Contains(strings.ToLower(solution), "hpc") {
// 		// For HPC solutions, generate job commands dynamically based on the zone
// 		lowMemJobCmd = GetJobCommand(zone, "low")
// 		medMemJobCmd = GetJobCommand(zone, "med")
// 	} else {
// 		// For non-HPC solutions, use predefined default commands
// 		lowMemJobCmd = LSF_JOB_COMMAND_LOW_MEM
// 		medMemJobCmd = LSF_JOB_COMMAND_MED_MEM
// 	}

// 	// Return the commands for low and medium memory jobs
// 	return lowMemJobCmd, medMemJobCmd
// }

// GenerateLSFJobCommandsForMemoryTypes generates the LSF job commands for low, medium, and high memory tasks.
// It returns the predefined commands for each job type.
func GenerateLSFJobCommandsForMemoryTypes() (string, string, string) {
	// Default job commands for low, medium, and high memory tasks
	lowMemJobCmd := LSF_JOB_COMMAND_LOW_MEM
	medMemJobCmd := LSF_JOB_COMMAND_MED_MEM
	highMemJobCmd := LSF_JOB_COMMAND_HIGH_MEM

	// Return the commands for low, medium, and high memory jobs
	return lowMemJobCmd, medMemJobCmd, highMemJobCmd
}

// VerifyClusterCreationAndConsistency validates successful cluster creation and operational
// consistency. It:
//  1. Executes a consistency test via RunTestConsistency()
//  2. Verifies non-nil output
//  3. Provides detailed, traceable errors on failure
//
// Returns nil on success, or an error with context on failure.
// All outcomes are logged through the provided logger.
func VerifyClusterCreationAndConsistency(t *testing.T, options *testhelper.TestOptions, logger *utils.AggregatedLogger) error {
	const op = "cluster creation and consistency check"

	// Execute the consistency test and handle any errors
	output, err := options.RunTestConsistency()
	if err != nil {
		logger.Error(t, fmt.Sprintf("%s failed: %v", op, err))
		return fmt.Errorf("%s failed: %w", op, err) // Wrapping the error with context
	}

	// Check if the output is non-nil
	if output == nil {
		msg := fmt.Sprintf("%s failed: nil consistency output", op)
		logger.Error(t, msg)
		return fmt.Errorf("%s: %s", op, msg) // Wrapping the error with context for nil output
	}

	// Log success if everything passes
	logger.Info(t, fmt.Sprintf("%s: %s passed", t.Name(), op))
	return nil

}

// // GetClusterIPs retrieves server IPs based on the solution type (HPC or LSF).
// // It returns the bastion IP, management node IPs, login node IP, and static worker node IPs,
// // and an error if the solution type is invalid or there is a problem retrieving the IPs.
// func GetClusterIPs(t *testing.T, options *testhelper.TestOptions, solution string, logger *utils.AggregatedLogger) (string, []string, string, []string, error) {
// 	var bastionIP, loginNodeIP string
// 	var managementNodeIPList, staticWorkerNodeIPList []string
// 	var err error

// 	// Retrieve server IPs based on solution type
// 	switch {
// 	case strings.EqualFold(solution, "hpc"):
// 		bastionIP, managementNodeIPList, loginNodeIP, err = utils.HPCGetClusterIPs(t, options, logger)
// 	case strings.EqualFold(solution, "lsf"):
// 		bastionIP, managementNodeIPList, loginNodeIP, staticWorkerNodeIPList, err = utils.LSFGetClusterIPs(t, options, logger)
// 	default:
// 		return "", nil, "", nil, fmt.Errorf("invalid solution type: %s", solution)
// 	}

// 	// Return error if any occurred while fetching server IPs
// 	if err != nil {
// 		return "", nil, "", nil, fmt.Errorf("error occurred while getting server IPs for solution %s: %w", solution, err)
// 	}

// 	return bastionIP, managementNodeIPList, loginNodeIP, staticWorkerNodeIPList, nil
// }

// GetClusterIPs fetches all key server IPs for an LSF cluster, including bastion, management, login, and static worker nodes.
// Returns individual IPs and lists along with an error if retrieval fails.
func GetClusterIPs(t *testing.T, options *testhelper.TestOptions, logger *utils.AggregatedLogger) (
	string, []string, string, []string, error) {

	bastionIP, managementNodeIPList, loginNodeIP, staticWorkerNodeIPList, err := utils.LSFGetClusterIPs(t, options, logger)
	if err != nil {
		return "", nil, "", nil, fmt.Errorf("failed to retrieve cluster IPs: %w", err)
	}

	return bastionIP, managementNodeIPList, loginNodeIP, staticWorkerNodeIPList, nil
}

// // GetClusterIPsWithLDAP retrieves server IPs along with LDAP information based on the solution type (HPC or LSF).
// // It returns the bastion IP, management node IPs, login node IP, static worker node IPs,
// // LDAP server IP, and an error if the solution type is invalid or there is an issue retrieving the IPs.
// func GetClusterIPsWithLDAP(t *testing.T, options *testhelper.TestOptions, solution string, logger *utils.AggregatedLogger) (string, []string, string, []string, string, error) {
// 	var bastionIP, loginNodeIP, ldapServerIP string
// 	var managementNodeIPList, staticWorkerNodeIPList []string
// 	var err error

// 	// Retrieve server IPs with LDAP information based on solution type
// 	switch {
// 	case strings.EqualFold(solution, "hpc"):
// 		bastionIP, managementNodeIPList, loginNodeIP, ldapServerIP, err = utils.HPCGetClusterIPsWithLDAP(t, options, logger)
// 	case strings.EqualFold(solution, "lsf"):
// 		bastionIP, managementNodeIPList, loginNodeIP, staticWorkerNodeIPList, ldapServerIP, err = utils.LSFGetClusterIPsWithLDAP(t, options, logger)
// 	default:
// 		return "", nil, "", nil, "", fmt.Errorf("invalid solution type: %s", solution)
// 	}

// 	// Return error if any occurred while fetching server IPs
// 	if err != nil {
// 		return "", nil, "", nil, "", fmt.Errorf("error occurred while getting server IPs for solution %s: %w", solution, err)
// 	}

// 	return bastionIP, managementNodeIPList, loginNodeIP, staticWorkerNodeIPList, ldapServerIP, nil
// }

// GetClusterIPsWithLDAP fetches all relevant server IPs for an LSF cluster, including LDAP information.
// Returns bastion, management, login, static worker node IPs, LDAP server IP, and an error if retrieval fails.
func GetClusterIPsWithLDAP(t *testing.T, options *testhelper.TestOptions, logger *utils.AggregatedLogger) (
	string, []string, string, []string, string, error) {

	bastionIP, managementNodeIPList, loginNodeIP, staticWorkerNodeIPList, ldapServerIP, err :=
		utils.LSFGetClusterIPsWithLDAP(t, options, logger)

	if err != nil {
		return "", nil, "", nil, "", fmt.Errorf("failed to retrieve LSF cluster IPs with LDAP: %w", err)
	}

	return bastionIP, managementNodeIPList, loginNodeIP, staticWorkerNodeIPList, ldapServerIP, nil
}

// // GetComputeNodeIPs retrieves dynamic compute node IPs based on the solution type (HPC or LSF).
// // It returns a list of compute node IPs and an error if the solution type is invalid or there is a problem retrieving the IPs.
// // It also appends static worker node IPs if provided in the input list.
// func GetComputeNodeIPs(t *testing.T, sshClient *ssh.Client, logger *utils.AggregatedLogger, solution string, staticWorkerNodeIPList []string) ([]string, error) {
// 	var computeNodeIPList []string
// 	var err error

// 	// Retrieve dynamic compute node IPs based on solution type
// 	if strings.Contains(solution, "hpc") {
// 		computeNodeIPList, err = HPCGETDynamicComputeNodeIPs(t, sshClient, logger)
// 		if err != nil {
// 			logger.Error(t, fmt.Sprintf("Error retrieving dynamic compute node IPs for HPC: %v", err))
// 			return nil, fmt.Errorf("error retrieving dynamic compute node IPs for HPC: %w", err)
// 		}
// 	} else if strings.Contains(solution, "lsf") {
// 		computeNodeIPList, err = LSFGETDynamicComputeNodeIPs(t, sshClient, logger)
// 		if err != nil {
// 			logger.Error(t, fmt.Sprintf("Error retrieving dynamic compute node IPs for LSF: %v", err))
// 			return nil, fmt.Errorf("error retrieving dynamic compute node IPs for LSF: %w", err)
// 		}
// 	} else {
// 		logger.Error(t, "Invalid solution type provided. Expected 'hpc' or 'lsf'.")
// 		return nil, fmt.Errorf("invalid solution type provided: %s", solution)
// 	}

// 	// Append static worker node IPs to the dynamic node IP list if provided
// 	if len(staticWorkerNodeIPList) > 0 {
// 		computeNodeIPList = append(computeNodeIPList, staticWorkerNodeIPList...)
// 		logger.Info(t, fmt.Sprintf("Appended %d static worker node IPs", len(staticWorkerNodeIPList)))
// 	}

// 	// Log the total count of retrieved compute node IPs
// 	logger.Info(t, fmt.Sprintf("Dynamic compute node IPs retrieved successfully. Total IPs: %d", len(computeNodeIPList)))

// 	return computeNodeIPList, nil
// }

// GetComputeNodeIPs retrieves compute node IPs for an LSF environment by combining
// dynamically discovered IPs with any optional static worker node IPs.
//
// Parameters:
//   - t: *testing.T for test logging context
//   - sshClient: Active SSH client for node communication
//   - logger: AggregatedLogger for structured logging
//   - staticWorkerNodeIPList: Optional list of static worker node IPs
//
// Returns:
//   - []string: Unique list of compute node IPs (dynamic + static)
//   - error: Wrapped error if retrieval fails or no valid IPs are found
func GetComputeNodeIPs(t *testing.T, sshClient *ssh.Client, staticWorkerNodeIPList []string, logger *utils.AggregatedLogger) ([]string, error) {
	const op = "LSF compute node IP retrieval"

	// Retrieve dynamic IPs from LSF environment
	dynamicIPs, err := LSFGETDynamicComputeNodeIPs(t, sshClient, logger)
	if err != nil {
		logger.Error(t, fmt.Sprintf("%s: failed to get dynamic IPs: %v", op, err))
		return nil, fmt.Errorf("%s: %w", op, err)
	}

	// Combine dynamic and static IPs
	allIPs := append(dynamicIPs, staticWorkerNodeIPList...)
	uniqueIPs := utils.RemoveDuplicateIPs(allIPs)

	if len(uniqueIPs) == 0 {
		err := fmt.Errorf("no compute node IPs found (dynamic or static)")
		logger.Error(t, fmt.Sprintf("%s: %v", op, err))
		return nil, fmt.Errorf("%s: %w", op, err)
	}

	logger.Info(t, fmt.Sprintf("%s completed: %d dynamic + %d static => %d unique IPs",
		op,
		len(dynamicIPs),
		len(staticWorkerNodeIPList),
		len(uniqueIPs)))

	return uniqueIPs, nil
}

// GetLDAPServerCredentialsInfo retrieves LDAP-related information from Terraform variables.
// It returns the expected LDAP domain, LDAP admin username,LDAP user username, and LDAP user password.
func GetLDAPServerCredentialsInfo(options *testhelper.TestOptions) (string, string, string, string) {
	var expectedLdapDomain, ldapAdminPassword, ldapUserName, ldapUserPassword string

	// Retrieve and type-assert values safely
	if domain, ok := options.TerraformVars["ldap_basedns"].(string); ok {
		expectedLdapDomain = domain
	}
	if adminPassword, ok := options.TerraformVars["ldap_admin_password"].(string); ok {
		ldapAdminPassword = adminPassword // pragma: allowlist secret
	}
	if userName, ok := options.TerraformVars["ldap_user_name"].(string); ok {
		ldapUserName = userName
	}
	if userPassword, ok := options.TerraformVars["ldap_user_password"].(string); ok {
		ldapUserPassword = userPassword // pragma: allowlist secret
	}

	return expectedLdapDomain, ldapAdminPassword, ldapUserName, ldapUserPassword
}

//*****************************LSF Logs*****************************

// Validate log files for a node (management or master)
func validateNodeLogFiles(t *testing.T, sClient *ssh.Client, node, sharedLogDir, nodeType string, logger *utils.AggregatedLogger) error {
	dirPath := fmt.Sprintf("%s/%s", sharedLogDir, node)
	logger.Info(t, fmt.Sprintf("Validating logs for %s node: %s", nodeType, node))

	_, err := utils.RunCommandInSSHSession(sClient, fmt.Sprintf("[ -d %s ] && echo 'exists'", dirPath))
	if err != nil {
		return fmt.Errorf("directory does not exist for %s node %s: %w", nodeType, node, err)
	}

	var logFiles []string
	switch nodeType {
	case "management":
		logFiles = []string{
			fmt.Sprintf("%s/sbatchd.log.%s", dirPath, node),
			fmt.Sprintf("%s/lim.log.%s", dirPath, node),
			fmt.Sprintf("%s/res.log.%s", dirPath, node),
			fmt.Sprintf("%s/pim.log.%s", dirPath, node),
			fmt.Sprintf("%s/Install.log", dirPath),
		}
	case "master":
		logFiles = []string{
			fmt.Sprintf("%s/mbatchd.log.%s", dirPath, node),
			fmt.Sprintf("%s/ebrokerd.log.%s", dirPath, node),
			fmt.Sprintf("%s/mbschd.log.%s", dirPath, node),
			fmt.Sprintf("%s/ibmcloudgen2-provider.log.%s", dirPath, node),
		}
	}

	for _, file := range logFiles {
		_, err := utils.RunCommandInSSHSession(sClient, fmt.Sprintf("[ -f %s ] && echo 'exists'", file))
		if err != nil {
			logger.Error(t, fmt.Sprintf("log file %s for %s node %s is missing: %v", file, nodeType, node, err))
			return fmt.Errorf("log file %s for %s node %s is missing: %w", file, nodeType, node, err)
		}
		logger.Info(t, fmt.Sprintf("Log file exists: %s", file))
	}

	return nil
}

// Helper function to get file modification time
func getFileModificationTime(t *testing.T, sClient *ssh.Client, sharedLogDir, masterName string, logger *utils.AggregatedLogger) (int64, error) {
	// Construct the command to fetch the file modification time
	command := fmt.Sprintf("stat -c %%Y %s/%s/mbatchd.log.%s", sharedLogDir, masterName, masterName)
	logger.Info(t, fmt.Sprintf("Executing command to get file modification time: %s", command))

	// Run the command on the remote server
	output, err := utils.RunCommandInSSHSession(sClient, command)
	if err != nil {
		logger.Error(t, fmt.Sprintf("Failed to execute command: %s. Error: %v", command, err))
		return 0, fmt.Errorf("failed to execute command to get file modification time: %w", err)
	}

	// Parse the output to extract modification time
	modTimeStr := strings.TrimSpace(output)
	modTime, err := strconv.ParseInt(modTimeStr, 10, 64)
	if err != nil {
		logger.Error(t, fmt.Sprintf("Failed to parse modification time from output: %s. Error: %v", modTimeStr, err))
		return 0, fmt.Errorf("failed to parse file modification time: %w", err)
	}

	// Log the retrieved modification time
	logger.Info(t, fmt.Sprintf("Successfully retrieved file modification time: %d", modTime))
	return modTime, nil
}

// Helper function to reboot the current master node and wait for the reboot to complete
func rebootMasterNode(t *testing.T, sClient *ssh.Client, masterName string, logger *utils.AggregatedLogger) error {
	logger.Info(t, fmt.Sprintf("Shutting down master node: %s", masterName))
	cmd := "sudo su -l root -c 'shutdown -r now'"
	_, err := utils.RunCommandInSSHSession(sClient, cmd)
	if !strings.Contains(err.Error(), "remote command exited without exit status or exit signal") {
		return fmt.Errorf("failed to shut down master node %s: %w", masterName, err)
	}

	// Wait for the system to reboot and settle
	logger.Info(t, fmt.Sprintf("Waiting for master node %s to reboot...", masterName))
	time.Sleep(1 * time.Minute)

	return nil
}

// LogFilesInSharedFolder validates the presence of LSF log files in a shared folder for both management and master nodes.
func LogFilesInSharedFolder(t *testing.T, sClient *ssh.Client, logger *utils.AggregatedLogger) error {

	masterName, err := utils.GetMasterNodeName(t, sClient, logger)
	if err != nil {
		return err
	}

	managementNodes, err := utils.GetManagementNodeNames(t, sClient, logger)
	if err != nil {
		return err
	}

	sharedLogDir := "/mnt/lsf/log"
	for _, node := range managementNodes {
		if err := validateNodeLogFiles(t, sClient, node, sharedLogDir, "management", logger); err != nil {
			return err
		}
	}

	if err := validateNodeLogFiles(t, sClient, masterName, sharedLogDir, "master", logger); err != nil {
		return err
	}

	return nil
}

// LogFilesAfterMasterReboot tests if log files are still available after the master node reboot.
func LogFilesAfterMasterReboot(t *testing.T, sClient *ssh.Client, bastionIP, managementNodeIP string, logger *utils.AggregatedLogger) error {

	masterName, err := utils.GetMasterNodeName(t, sClient, logger)
	if err != nil {
		return err
	}

	managementNodes, err := utils.GetManagementNodeNames(t, sClient, logger)
	if err != nil {
		return err
	}

	sharedLogDir := "/mnt/lsf/log"
	datePreRestart, err := getFileModificationTime(t, sClient, sharedLogDir, masterName, logger)
	if err != nil {
		return err
	}

	// Reboot the master node
	if err := rebootMasterNode(t, sClient, masterName, logger); err != nil {
		return err
	}

	// Reconnect to the management node after reboot
	sClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIP)
	if connectionErr != nil {
		logger.Error(t, fmt.Sprintf("Failed to reconnect to the master via SSH after Management node Reboot: %s", connectionErr))
		return fmt.Errorf("failed to reconnect to the master via SSH after Management node Reboot : %s", connectionErr)
	}

	defer func() {
		if err := sClient.Close(); err != nil {
			logger.Info(t, fmt.Sprintf("failed to close sClient: %v", err))
		}
	}()

	// Validate the log files after reboot
	for _, node := range managementNodes {
		if err := validateNodeLogFiles(t, sClient, node, sharedLogDir, "management", logger); err != nil {
			return err
		}
	}

	if err := validateNodeLogFiles(t, sClient, masterName, sharedLogDir, "master", logger); err != nil {
		return err
	}

	// Validate log modification time to ensure files were not lost
	datePostRestart, err := getFileModificationTime(t, sClient, sharedLogDir, masterName, logger)
	if err != nil {
		return err
	}

	if datePreRestart >= datePostRestart {
		return fmt.Errorf("log file modification time did not update after master node reboot")
	}
	logger.Info(t, "log file modification time did update after master node reboot")
	return nil
}

// Helper function to shutdown the current master node
func shutdownMasterNode(t *testing.T, sClient *ssh.Client, masterName string, logger *utils.AggregatedLogger) error {
	logger.Info(t, fmt.Sprintf("Shutting down master node: %s", masterName))
	cmd := "sudo su -l root -c 'shutdown  now'"
	_, err := utils.RunCommandInSSHSession(sClient, cmd)
	if !strings.Contains(err.Error(), "remote command exited without exit status or exit signal") {
		return fmt.Errorf("failed to shut down master node %s: %w", masterName, err)
	}

	return nil
}

// LogFilesAfterMasterShutdown tests if log files are still available after the master node shutdown.
func LogFilesAfterMasterShutdown(t *testing.T, sshClient *ssh.Client, apiKey, region, resourceGroup, bastionIP string, managementNodeIPList []string, logger *utils.AggregatedLogger) error {
	// Retrieve the current master node name
	oldMasterNodeName, err := utils.GetMasterNodeName(t, sshClient, logger)
	if err != nil {
		return fmt.Errorf("failed to get current master node name: %w", err)
	}

	sharedLogDir := "/mnt/lsf/log"

	// Shutdown the master node
	if err := shutdownMasterNode(t, sshClient, oldMasterNodeName, logger); err != nil {
		return fmt.Errorf("failed to shutdown master node %s: %w", oldMasterNodeName, err)
	}

	// Wait for the system to change to the new master node name
	logger.Info(t, fmt.Sprintf("Waiting for the system to switch to the new master node name from %s...", oldMasterNodeName))
	time.Sleep(2 * time.Minute)

	// Reconnect to the secondary management node after shutdown
	sshClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPList[1])
	if connectionErr != nil {
		errorMessage := fmt.Sprintf("failed to connect to the secondary node via SSH after shutdown: %s", connectionErr)
		logger.Error(t, errorMessage)
		return fmt.Errorf("%s", errorMessage)
	}

	defer func() {
		if err := sshClient.Close(); err != nil {
			logger.Info(t, fmt.Sprintf("failed to close sshClient: %v", err))
		}
	}()

	// Retrieve the new master node name after shutdown
	newMasterNodeName, err := utils.GetMasterNodeName(t, sshClient, logger)
	if err != nil {
		return fmt.Errorf("failed to get new master node name after shutdown: %w", err)
	}

	// Validate that the master node has changed after shutdown
	logger.Info(t, fmt.Sprintf("Old master node: %s, New master node: %s", oldMasterNodeName, newMasterNodeName))
	if newMasterNodeName == oldMasterNodeName {
		fmt.Println("Should not")
		logger.Error(t, fmt.Sprintf("Failed to switch to the new master node after shutdown. Old master node: %s, New master node: %s", oldMasterNodeName, newMasterNodeName))
		return fmt.Errorf("failed to switch to the new master node after shutdown. Old: %s, New: %s", oldMasterNodeName, newMasterNodeName)
	}

	// Retrieve the list of management nodes
	managementNodes, err := utils.GetManagementNodeNames(t, sshClient, logger)
	if err != nil {
		return fmt.Errorf("failed to get management node names: %w", err)
	}

	// Validate log files on management nodes
	for _, node := range managementNodes {
		if err := validateNodeLogFiles(t, sshClient, node, sharedLogDir, "management", logger); err != nil {
			return fmt.Errorf("failed to validate log files for management node %s: %w", node, err)
		}
	}

	// Validate log files on the new master node
	if err := validateNodeLogFiles(t, sshClient, newMasterNodeName, sharedLogDir, "master", logger); err != nil {
		return fmt.Errorf("failed to validate log files for new master node %s: %w", newMasterNodeName, err)
	}

	// Log in to IBM Cloud using the API key and region
	if err := utils.LoginIntoIBMCloudUsingCLI(t, apiKey, region, resourceGroup); err != nil {
		return fmt.Errorf("failed to log in to IBM Cloud: %w", err)
	}

	// Start the old master instance
	startInstanceCmd := fmt.Sprintf("ibmcloud is instance-start %s", oldMasterNodeName)
	cmd := exec.Command("bash", "-c", startInstanceCmd)
	startInstanceOutput, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("failed to start instance: %w", err)
	}

	// Validate the instance start output
	if !strings.Contains(strings.TrimSpace(string(startInstanceOutput)), fmt.Sprintf("Creating action start for instance %s", oldMasterNodeName)) {
		return fmt.Errorf("failed to start master instance node %s", oldMasterNodeName)
	}

	// Wait for the system to start instance and settle
	logger.Info(t, fmt.Sprintf("Waiting for instance start for node %s...", oldMasterNodeName))
	time.Sleep(1 * time.Minute)

	// Retrieve the new master node name after starting the instance
	postStartMasterNodeName, err := utils.GetMasterNodeName(t, sshClient, logger)
	if err != nil {
		return fmt.Errorf("failed to get new master node name after starting instance: %w", err)
	}

	// Validate that the master node has switched back
	if postStartMasterNodeName == newMasterNodeName {
		return fmt.Errorf("failed to switch back to original master node after instance start")
	}

	// Reconnect to the primary management node after instance start
	sshClient, connectionErr = utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPList[0])
	if connectionErr != nil {
		errorMessage := fmt.Sprintf("failed to connect to the primary master node via SSH after instance start: %s", connectionErr)
		logger.Error(t, errorMessage)
		return fmt.Errorf("%s", errorMessage)
	}

	defer func() {
		if err := sshClient.Close(); err != nil {
			logger.Info(t, fmt.Sprintf("failed to close sshClient: %v", err))
		}
	}()

	logger.Info(t, "Successfully switched back to the original master node after instance start")
	return nil
}

//*************************** PAC-HA ***************************

// validateLSFAddonHosts validates the LSF_ADDON_HOSTS configuration in the LSF configuration file.
func validateLSFAddonHosts(t *testing.T, sshClient *ssh.Client, logger *utils.AggregatedLogger) error {
	cmd := "sudo grep LSF_ADDON_HOSTS /opt/ibm/lsf/conf/lsf.conf | head -n 1"
	logger.Info(t, fmt.Sprintf("Executing command to validate LSF_ADDON_HOSTS: %s", cmd))

	output, err := utils.RunCommandInSSHSession(sshClient, cmd)
	if err != nil {
		logger.Error(t, fmt.Sprintf("Failed to execute command '%s': %v", cmd, err))
		return fmt.Errorf("failed to execute command '%s': %w", cmd, err)
	}

	// Retrieve management node names
	managementNodes, err := utils.GetManagementNodeNames(t, sshClient, logger)
	if err != nil {
		logger.Error(t, fmt.Sprintf("Failed to retrieve management node names: %v", err))
		return fmt.Errorf("failed to retrieve management node names: %w", err)
	}

	expected := fmt.Sprintf("LSF_ADDON_HOSTS=\"%s\"", strings.Join(managementNodes, " "))
	if !utils.VerifyDataContains(t, output, expected, logger) {
		logger.Error(t, fmt.Sprintf("LSF_ADDON_HOSTS validation failed: expected %s, got %s", expected, output))
		return fmt.Errorf("LSF_ADDON_HOSTS validation failed: expected %s, got %s", expected, output)
	}
	logger.Info(t, "LSF_ADDON_HOSTS validation passed successfully.")
	return nil
}

// validateNoVNCProxyHost validates the NoVNCProxyHost configuration in the PMC configuration file.
func validateNoVNCProxyHost(t *testing.T, sshClient *ssh.Client, domainName string, logger *utils.AggregatedLogger) error {
	cmd := "sudo grep NoVNCProxyHost /opt/ibm/lsfsuite/ext/gui/conf/pmc.conf"
	logger.Info(t, fmt.Sprintf("Executing command to validate NoVNCProxyHost: %s", cmd))

	output, err := utils.RunCommandInSSHSession(sshClient, cmd)
	if err != nil {
		logger.Error(t, fmt.Sprintf("Failed to execute command '%s': %v", cmd, err))
		return fmt.Errorf("failed to execute command '%s': %w", cmd, err)
	}

	expected := fmt.Sprintf("NoVNCProxyHost=pac.%s", domainName)
	if !utils.VerifyDataContains(t, output, expected, logger) {
		logger.Error(t, fmt.Sprintf("NoVNCProxyHost validation failed: expected %s, got %s", expected, output))
		return fmt.Errorf("NoVNCProxyHost validation failed: expected %s, got %s", expected, output)
	}
	logger.Info(t, "NoVNCProxyHost validation passed successfully.")
	return nil
}

// validateApplicationCenterLogs validates the Application Center installation logs.
func validateApplicationCenterLogs(t *testing.T, sshClient *ssh.Client, logger *utils.AggregatedLogger) error {

	cmd := "sudo grep 'Application Center' /tmp/configure_management.log"
	logger.Info(t, fmt.Sprintf("Executing command to validate Application Center logs: %s", cmd))

	output, err := utils.RunCommandInSSHSession(sshClient, cmd)
	if err != nil {
		logger.Error(t, fmt.Sprintf("Failed to execute command '%s': %v", cmd, err))
		return fmt.Errorf("failed to execute command '%s': %w", cmd, err)
	}

	// Check if logs contain the required phrases
	if !utils.VerifyDataContains(t, output, "Application Center package found!", logger) ||
		!utils.VerifyDataContains(t, output, "Application Center installation completed...", logger) {
		logger.Error(t, "Application Center installation log validation failed: expected phrases not found")
		return fmt.Errorf("application Center installation log validation failed: expected phrases not found")
	}
	logger.Info(t, "Application Center logs validation passed successfully.")
	return nil
}

// validateDatasourceConfig validates the datasource configuration in the datasource.xml file.
func validateDatasourceConfig(t *testing.T, sshClient *ssh.Client, logger *utils.AggregatedLogger) error {
	cmd := "cat /opt/ibm/lsfsuite/ext/perf/conf/datasource.xml | grep Connection"
	logger.Info(t, fmt.Sprintf("Executing command to validate datasource configuration: %s", cmd))

	output, err := utils.RunCommandInSSHSession(sshClient, cmd)
	if err != nil {
		logger.Error(t, fmt.Sprintf("Failed to execute command '%s': %v", cmd, err))
		return fmt.Errorf("failed to execute command '%s': %w", cmd, err)
	}

	// Check if the datasource configuration contains the required values
	if !utils.VerifyDataContains(t, output, "Connection  The database URL.", logger) ||
		!utils.VerifyDataContains(t, output, "Connection=\"jdbc:mariadb:", logger) {
		logger.Error(t, "Datasource configuration validation failed: expected values not found")
		return fmt.Errorf("datasource configuration validation failed: expected values not found")
	}
	logger.Info(t, "Datasource configuration validation passed successfully.")
	return nil
}

// validatePMCVersion validates the PMC version using the pmcadmin -V command.
func validatePMCVersion(t *testing.T, sshClient *ssh.Client, logger *utils.AggregatedLogger) error {
	cmd := "pmcadmin -V"
	logger.Info(t, fmt.Sprintf("Executing command to validate PMC version: %s", cmd))

	output, err := utils.RunCommandInSSHSession(sshClient, cmd)
	if err != nil {
		logger.Error(t, fmt.Sprintf("Failed to execute command '%s': %v", cmd, err))
		return fmt.Errorf("failed to execute command '%s': %w", cmd, err)
	}

	expected := "IBM Spectrum LSF Application Center Standard"
	if !utils.VerifyDataContains(t, output, expected, logger) {
		logger.Error(t, fmt.Sprintf("PMC version validation failed: expected '%s', got '%s'", expected, output))
		return fmt.Errorf("PMC version validation failed: expected '%s', got '%s'", expected, output)
	}
	logger.Info(t, "PMC version validation passed successfully.")
	return nil
}

// validateCertificateFile validates the presence of the certificate in the specified file.
func validateCertificateFile(t *testing.T, sshClient *ssh.Client, logger *utils.AggregatedLogger) error {
	cmd := "cat /opt/ibm/lsfsuite/ext/gui/conf/cert.pem"
	logger.Info(t, fmt.Sprintf("Executing command to validate certificate file: %s", cmd))

	output, err := utils.RunCommandInSSHSession(sshClient, cmd)
	if err != nil {
		logger.Error(t, fmt.Sprintf("Failed to execute command '%s': %v", cmd, err))
		return fmt.Errorf("failed to execute command '%s': %w", cmd, err)
	}

	// Check if the certificate contains the expected header
	if !utils.VerifyDataContains(t, output, "-----BEGIN CERTIFICATE-----", logger) {
		logger.Error(t, "Certificate validation failed: missing expected certificate header")
		return fmt.Errorf("certificate validation failed: missing expected certificate header")
	}
	logger.Info(t, "Certificate validation passed successfully.")
	return nil
}

// ValidatePACHAConfigOnManagementNode validates the PACHA (Performance and Application Center) configuration on the management node.
func ValidatePACHAConfigOnManagementNode(t *testing.T, sshClient *ssh.Client, domainName string, logger *utils.AggregatedLogger) error {
	logger.Info(t, "Starting PACHA configuration validation on the management node.")

	// Check the result of CheckAppCenterSetup for any errors
	if err := CheckAppCenterSetup(t, sshClient, logger); err != nil {
		return fmt.Errorf("CheckAppCenterSetup pmcadmin list validation failed: %w", err)
	}

	// Validate LSF_ADDON_HOSTS configuration
	if err := validateLSFAddonHosts(t, sshClient, logger); err != nil {
		return fmt.Errorf("LSF_ADDON_HOSTS validation failed: %w", err)
	}

	// Validate NoVNCProxyHost configuration
	if err := validateNoVNCProxyHost(t, sshClient, domainName, logger); err != nil {
		return fmt.Errorf("NoVNCProxyHost validation failed: %w", err)
	}

	// Validate Application Center logs
	if err := validateApplicationCenterLogs(t, sshClient, logger); err != nil {
		return fmt.Errorf("application Center logs validation failed: %w", err)
	}

	// Validate datasource configuration
	if err := validateDatasourceConfig(t, sshClient, logger); err != nil {
		return fmt.Errorf("datasource configuration validation failed: %w", err)
	}

	// Validate PMC version
	if err := validatePMCVersion(t, sshClient, logger); err != nil {
		return fmt.Errorf("PMC version validation failed: %w", err)
	}

	// Validate Certificate file
	if err := validateCertificateFile(t, sshClient, logger); err != nil {
		return fmt.Errorf("certificate file validation failed: %w", err)
	}

	logger.Info(t, "PACHA configuration validation on the management node completed successfully.")
	return nil
}

// ValidatePACHAConfigOnManagementNodes validates the PACHA (Performance and Application Center) configuration on multiple management nodes.
func ValidatePACHAConfigOnManagementNodes(t *testing.T, sshClient *ssh.Client, publicHostIP string, managementNodeIPList []string, domainName string, logger *utils.AggregatedLogger) error {
	logger.Info(t, "Starting PACHA configuration validation on management nodes.")

	// Validate input parameters
	if len(managementNodeIPList) == 0 {
		return fmt.Errorf("management node IP list is empty")
	}

	// Iterate over management node IPs and perform validations
	for _, mgmtIP := range managementNodeIPList {
		// Connect to the management node via SSH
		mgmtSshClient, err := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, publicHostIP, LSF_PRIVATE_HOST_NAME, mgmtIP)
		if err != nil {
			return fmt.Errorf("failed to establish SSH connection to management node %s: %w", mgmtIP, err)
		}

		// Log successful connection
		logger.Info(t, fmt.Sprintf("SSH connection to management node %s established successfully", mgmtIP))

		// Ensure SSH client is closed after use
		defer func(client *ssh.Client) {
			if err := client.Close(); err != nil {
				logger.Warn(t, fmt.Sprintf("Failed to close SSH connection for management node %s: %v", mgmtIP, err))
			}
		}(mgmtSshClient)

		// Validate LSF_ADDON_HOSTS configuration
		if err := validateLSFAddonHosts(t, mgmtSshClient, logger); err != nil {
			return fmt.Errorf("LSF_ADDON_HOSTS validation failed on node %s: %w", mgmtIP, err)
		}

		// Validate Application Center logs
		if err := validateApplicationCenterLogs(t, mgmtSshClient, logger); err != nil {
			return fmt.Errorf("application Center logs validation failed on node %s: %w", mgmtIP, err)
		}

		// Validate datasource configuration
		if err := validateDatasourceConfig(t, mgmtSshClient, logger); err != nil {
			return fmt.Errorf("datasource configuration validation failed on node %s: %w", mgmtIP, err)
		}

		// Validate PMC version
		if err := validatePMCVersion(t, mgmtSshClient, logger); err != nil {
			return fmt.Errorf("PMC version validation failed on node %s: %w", mgmtIP, err)
		}

		// Validate Certificate file
		if err := validateCertificateFile(t, mgmtSshClient, logger); err != nil {
			return fmt.Errorf("certificate file validation failed on node %s: %w", mgmtIP, err)
		}

		// Check the result of CheckAppCenterSetup for any errors
		if err := CheckAppCenterSetup(t, mgmtSshClient, logger); err != nil {
			return fmt.Errorf("CheckAppCenterSetup pmcadmin list validation failed on node %s: %w", mgmtIP, err)
		}
	}

	// Log the success message after all validations pass
	logger.Info(t, "PACHA configuration validation on all management nodes completed successfully.")
	return nil
}

// CheckAppCenterSetup verifies the configuration of APP Center GUI and PNC.
// It runs a command on the server to ensure that both components are properly configured
// and checks their statuses in the command output.
// Returns: - An error if the command execution fails or if the required statuses are not found.
func CheckAppCenterSetup(t *testing.T, sshClient *ssh.Client, logger *utils.AggregatedLogger) error {

	webguiStatus := "WEBGUI         STARTED"
	pncStatus := "PNC            STARTED"

	// Command to check if APP Center GUI or PNC is configured
	configCommand := "sudo su -l root -c 'pmcadmin list'"

	// Run the command to verify APP Center GUI or PNC setup
	commandOutput, err := utils.RunCommandInSSHSession(sshClient, configCommand)
	if err != nil {
		return fmt.Errorf("error executing command '%s': %w", configCommand, err)
	}

	// Check for required configuration statuses in the output
	if !utils.VerifyDataContains(t, commandOutput, webguiStatus, logger) || !utils.VerifyDataContains(t, commandOutput, pncStatus, logger) {
		return fmt.Errorf("APP Center GUI or PNC configuration mismatch: %s", commandOutput)
	}

	return nil
}

// ValidateTerraformPACOutputs validates essential Terraform outputs for PAC.
// Ensures the outputs contain required fields and match the expected domain name.
func ValidateTerraformPACOutputs(t *testing.T, terraformOutputs map[string]interface{}, domainName string, logger *utils.AggregatedLogger) error {
	requiredFields := []string{"application_center_tunnel", "application_center_url", "application_center_url_note"}

	// Check for the required fields at the top level in terraformOutputs
	for _, field := range requiredFields {
		value, exists := terraformOutputs[field]
		if !exists {
			return fmt.Errorf("terraform output validation failed: '%s' is missing", field)
		}

		valueStr, ok := value.(string)
		if !ok || len(strings.TrimSpace(valueStr)) == 0 {
			return fmt.Errorf("terraform output validation failed: '%s' is empty or not of type string", field)
		}
		logger.Info(t, fmt.Sprintf("%s = %s", field, valueStr))
	}

	// Validate application_center_url and application_center_url_note against the domain name
	for _, field := range []string{"application_center_url", "application_center_url_note"} {
		value := strings.TrimSpace(terraformOutputs[field].(string))
		expectedPrefix := "pac." + domainName
		if !strings.Contains(value, expectedPrefix) {
			return fmt.Errorf("terraform output validation failed: '%s' does not contain the expected domain prefix '%s'", field, expectedPrefix)
		}
	}

	// Log success if no errors occurred
	logger.Info(t, "Terraform output for PAC validation completed successfully.")
	return nil
}

// ValidatePACHAFailoverOnManagementNodes validates PACHA failover functionality on management nodes.
// Iterates over management nodes to verify configurations and service health.
func ValidatePACHAFailoverOnManagementNodes(t *testing.T, sshClient *ssh.Client, publicHostIP string, managementNodeIPList []string, logger *utils.AggregatedLogger) error {
	logger.Info(t, "Starting validation of PACHA failover on management nodes.")

	// Validate input parameters
	if len(managementNodeIPList) == 0 {
		return fmt.Errorf("management node IPs cannot be empty")
	}

	// Iterate over management node IPs and perform validations
	for _, mgmtIP := range managementNodeIPList {
		// Connect to the management node via SSH
		mgmtSshClient, err := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, publicHostIP, LSF_PRIVATE_HOST_NAME, mgmtIP)
		if err != nil {
			return fmt.Errorf("failed to connect to the management node %s via SSH: %w", mgmtIP, err)
		}

		// Log successful connection
		logger.Info(t, fmt.Sprintf("SSH connection to the management node %s successful", mgmtIP))

		// Ensure SSH client is closed after use
		defer func(client *ssh.Client) {
			if err := client.Close(); err != nil {
				logger.Warn(t, fmt.Sprintf("Failed to close SSH connection for management node %s: %v", mgmtIP, err))
			}
		}(mgmtSshClient)

		// Stop the sbatchd process
		if err := LSFControlBctrld(t, mgmtSshClient, "stop", logger); err != nil {
			return fmt.Errorf("bctrld stop operation failed on management node %s: %w", mgmtIP, err)
		}

		// Validate LSF_ADDON_HOSTS configuration
		if err := validateLSFAddonHosts(t, mgmtSshClient, logger); err != nil {
			return fmt.Errorf("LSF_ADDON_HOSTS validation failed on node %s: %w", mgmtIP, err)
		}

		// Validate Application Center logs
		if err := validateApplicationCenterLogs(t, mgmtSshClient, logger); err != nil {
			return fmt.Errorf("application Center logs validation failed on node %s: %w", mgmtIP, err)
		}

		// Validate datasource configuration
		if err := validateDatasourceConfig(t, mgmtSshClient, logger); err != nil {
			return fmt.Errorf("datasource configuration validation failed on node %s: %w", mgmtIP, err)
		}

		// Validate Certificate file
		if err := validateCertificateFile(t, mgmtSshClient, logger); err != nil {
			return fmt.Errorf("certificate file validation failed on node %s: %w", mgmtIP, err)
		}

		// Check the result of CheckAppCenterSetup for any errors
		if err := CheckAppCenterSetup(t, mgmtSshClient, logger); err != nil {
			// If there's an error, return it wrapped with a custom message
			return fmt.Errorf("CheckAppCenterSetup pmcadmin list validation failed on node %s: %w", mgmtIP, err)
		}

		// Restart the sbatchd process
		if err := LSFControlBctrld(t, mgmtSshClient, "start", logger); err != nil {
			return fmt.Errorf("bctrld start operation failed on management node %s: %w", mgmtIP, err)
		}
	}

	// Log the success message after all validations pass
	logger.Info(t, "All validations for PACHA failover on the management nodes passed successfully.")
	return nil
}

// verifyDedicatedHost checks if a dedicated host has the expected worker node count attached to it.
// It logs into IBM Cloud, checks for the dedicated host by using the provided cluster prefix,
// and verifies that the number of worker nodes matches the expected value.
func verifyDedicatedHost(t *testing.T, apiKey, region, resourceGroup, clusterPrefix string, expectedWorkerNodeCount int, expectedDedicatedHostPresence bool, logger *utils.AggregatedLogger) error {
	// If the resource group is "null", set a custom resource group based on the cluster prefix
	if strings.Contains(resourceGroup, "null") {
		resourceGroup = fmt.Sprintf("%s-workload-rg", clusterPrefix)
	}

	// Log in to IBM Cloud using the provided API key and region
	if err := utils.LoginIntoIBMCloudUsingCLI(t, apiKey, region, resourceGroup); err != nil {
		return fmt.Errorf("failed to log in to IBM Cloud: %w", err)
	}

	// Start the process to fetch the dedicated host ID
	dedicatedHostCmd := fmt.Sprintf("ibmcloud is dedicated-hosts | grep %s | awk '{print $1}'", clusterPrefix)
	cmd := exec.Command("bash", "-c", dedicatedHostCmd)
	dedicatedHostID, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("failed to retrieve dedicated host ID: %w", err)
	}

	if expectedDedicatedHostPresence {
		// Check if a valid dedicated host ID is found
		if len(dedicatedHostID) == 0 || string(dedicatedHostID) == "" {
			return fmt.Errorf("dedicated host not found for prefix '%s'", clusterPrefix)
		}

		// List the instances attached to the dedicated host
		listInstancesCmd := fmt.Sprintf("ibmcloud is dedicated-host %s", dedicatedHostID)
		cmd = exec.Command("bash", "-c", listInstancesCmd)
		output, err := cmd.Output()
		if err != nil {
			return fmt.Errorf("error executing command to list instances: %v, Output: %s", err, string(output))
		}

		// Count the number of worker nodes attached to the dedicated host
		actualCount := strings.Count(strings.TrimSpace(string(output)), clusterPrefix+"-worker")

		logger.Info(t, fmt.Sprintf("Actual worker node count: %d, Expected: %d", actualCount, expectedWorkerNodeCount))

		// Verify if the actual worker node count matches the expected count
		if !utils.VerifyDataContains(t, actualCount, expectedWorkerNodeCount, logger) {
			return fmt.Errorf("dedicated host worker node count mismatch: actual: '%d', expected: '%d', output: '%s'", actualCount, expectedWorkerNodeCount, output)
		}
	} else {
		// Check if no dedicated host ID is found
		if len(dedicatedHostID) != 0 && string(dedicatedHostID) != "" {
			return fmt.Errorf("dedicated host found for prefix '%s', but none was expected", clusterPrefix)
		}
		logger.Info(t, fmt.Sprintf("No dedicated host found as expected for prefix: %s", clusterPrefix))
	}

	logger.Info(t, fmt.Sprintf("Successfully validated dedicated host presence: %v", expectedDedicatedHostPresence))

	return nil
}

// VerifyEncryptionCRN validates CRN encryption on management nodes by running
// SSH commands and verifying the configuration contains the expected CRN format.
// Returns an error if any node fails validation.
func VerifyEncryptionCRN(t *testing.T, sshClient *ssh.Client, keyManagement string, managementNodeIPList []string, logger *utils.AggregatedLogger) error {

	// Check if management node IP list is empty
	if len(managementNodeIPList) == 0 {
		return fmt.Errorf("management node IPs cannot be empty")
	}

	// Command to retrieve CRN configuration
	cmd := "cat /opt/ibm/lsfsuite/lsf/conf/resource_connector/ibmcloudgen2/conf/ibmcloudgen2_templates.json"

	// Iterate over each management node IP in the list
	for _, managementNodeIP := range managementNodeIPList {
		// Construct the SSH command to execute on the management node
		command := fmt.Sprintf("ssh %s %s", managementNodeIP, cmd)

		// Run the command on the management node
		actualOutput, err := utils.RunCommandInSSHSession(sshClient, command)
		if err != nil {
			return fmt.Errorf("failed to run SSH command on management node IP '%s': %w", managementNodeIP, err)
		}

		// Log the actual output for debugging
		logger.Info(t, fmt.Sprintf("Output from node '%s': %s", managementNodeIP, actualOutput))

		// Normalize the output to avoid formatting mismatches
		normalizedOutput := strings.ReplaceAll(strings.ReplaceAll(actualOutput, " ", ""), "\n", "")

		// Determine the expected CRN format based on key management type
		expectedCRN := "\"crn\":\"crn:v1:bluemix:public:kms"
		if strings.ToLower(keyManagement) != "key_protect" {
			expectedCRN = "\"crn\":\"\""
		}

		if !utils.VerifyDataContains(t, normalizedOutput, expectedCRN, logger) {
			return fmt.Errorf("management node with IP '%s' does not contain the expected CRN format: %s", managementNodeIP, expectedCRN)

		}

		// Log success for the current node
		logger.Info(t, fmt.Sprintf("Successfully validated CRN for management node '%s'", managementNodeIP))
	}

	// Log overall success
	logger.Info(t, "CRN encryption validation for all management nodes completed successfully")
	return nil
}

// VerifySCCInstance validates the SCC instance by verifying its configuration, region, and attachments.
// It checks the service instance details, extracts relevant GUIDs, and ensures attachments are in the expected state.
func VerifySCCInstance(t *testing.T, apiKey, region, resourceGroup, clusterPrefix, expectedRegion string, logger *utils.AggregatedLogger) error {

	// Default expected region if not provided
	if expectedRegion == "" {
		expectedRegion = "us-south"
	}

	// If the resource group is "null", set it to a custom resource group with the format "clusterPrefix-workload-rg"
	if strings.Contains(resourceGroup, "null") {
		resourceGroup = fmt.Sprintf("%s-workload-rg", clusterPrefix)
	}

	// Log in to IBM Cloud using the API key and region
	if err := utils.LoginIntoIBMCloudUsingCLI(t, apiKey, region, resourceGroup); err != nil {
		return fmt.Errorf("failed to log in to IBM Cloud with API key and region '%s': %w", region, err)
	}

	// Fetch the SCC instance
	command := fmt.Sprintf("ibmcloud resource service-instance %s-scc-instance", clusterPrefix)
	cmd := exec.Command("bash", "-c", command)
	output, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("failed to execute IBM Cloud CLI command to fetch SCC instance '%s': %w", clusterPrefix, err)
	}

	// Parse the output to extract instance details
	sccOutput := string(output)
	var guid string
	lines := strings.Split(sccOutput, "\n")
	for _, line := range lines {
		if strings.HasPrefix(line, "Name:") {
			actualInstanceName := strings.TrimSpace(strings.TrimPrefix(line, "Name:"))
			expectedInstanceName := fmt.Sprintf("%s-scc-instance", clusterPrefix)
			logger.Info(t, fmt.Sprintf("SCC instance name: %s", actualInstanceName))
			if !utils.VerifyDataContains(t, actualInstanceName, expectedInstanceName, logger) {
				return fmt.Errorf("SCC instance not found. Expected name: %s, but got: %s", expectedInstanceName, actualInstanceName)
			}
		}

		if strings.HasPrefix(line, "GUID:") {
			guid = strings.TrimSpace(strings.TrimPrefix(line, "GUID:"))
			logger.Info(t, fmt.Sprintf("GUID SCC instance details: %s", guid))
			if guid == "" {
				return fmt.Errorf("GUID not found in SCC instance details: %s", sccOutput)
			}
		}

		if strings.HasPrefix(line, "Location:") {
			actualRegionID := strings.TrimSpace(strings.TrimPrefix(line, "Location:"))
			logger.Info(t, fmt.Sprintf("SCC instance found in region: %s", actualRegionID))
			if !utils.VerifyDataContains(t, actualRegionID, expectedRegion, logger) {
				return fmt.Errorf("SCC instance found in incorrect region. Expected: %s, but got: %s", expectedRegion, actualRegionID)
			}
		}
	}

	// Fetch SCC settings
	sccSettingsCmd := fmt.Sprintf("ibmcloud security-compliance --region=\"%s\".compliance --instance-id=%s setting get --output=json", expectedRegion, guid)
	sccCmd := exec.Command("bash", "-c", sccSettingsCmd)
	settingsOutput, err := sccCmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("failed to fetch SCC settings for instance '%s' in region '%s': %w", guid, expectedRegion, err)
	}

	var settings map[string]interface{}
	if err := json.Unmarshal(settingsOutput, &settings); err != nil {
		return fmt.Errorf("error unmarshaling SCC settings JSON: %v, Output: %s", err, string(settingsOutput))
	}

	if len(settings) == 0 {
		return fmt.Errorf("no settings found for SCC instance: %s", string(settingsOutput))
	}

	// Extract required CRNs
	eventCRN, ok := settings["event_notifications"].(map[string]interface{})["instance_crn"].(string)
	if !ok {
		return fmt.Errorf("failed to extract event_notifications.instance_crn from SCC settings: %s", string(settingsOutput))
	}

	storageCRN, ok := settings["object_storage"].(map[string]interface{})["instance_crn"].(string)
	if !ok {
		return fmt.Errorf("failed to extract object_storage.instance_crn from SCC settings: %s", string(settingsOutput))
	}

	if len(eventCRN) == 0 {
		return fmt.Errorf("no settings found for Event Notifications CRN: %s", eventCRN)
	}
	if len(storageCRN) == 0 {
		return fmt.Errorf("no settings found for Object Storage CRN: %s", storageCRN)
	}

	logger.Info(t, fmt.Sprintf("Event Notifications CRN: %s", eventCRN))
	logger.Info(t, fmt.Sprintf("Object Storage CRN: %s", storageCRN))

	// Fetch attachment list
	attachmentCmd := fmt.Sprintf("ibmcloud security-compliance --region=\"%s\".compliance --instance-id=%s attachment list --output json", expectedRegion, guid)
	attachmentListCmd := exec.Command("bash", "-c", attachmentCmd)
	attachmentOutput, err := attachmentListCmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("failed to fetch attachment list for SCC instance '%s' in region '%s': %w", guid, expectedRegion, err)
	}

	var attachmentsData map[string]interface{}
	if err := json.Unmarshal(attachmentOutput, &attachmentsData); err != nil {
		return fmt.Errorf("error unmarshaling attachment list JSON: %v, Output: %s", err, string(attachmentOutput))
	}

	if len(attachmentsData) == 0 {
		return fmt.Errorf("no attachments found for SCC instance: %s", string(attachmentOutput))
	}

	attachments, ok := attachmentsData["attachments"].([]interface{})
	if !ok {
		return fmt.Errorf("failed to extract attachments from attachment list JSON: %s", string(attachmentOutput))
	}

	for _, attachment := range attachments {
		attachmentMap := attachment.(map[string]interface{})
		actualAttachmentName := attachmentMap["name"].(string)
		expectedAttachmentName := fmt.Sprintf("%s-scc-attachment", clusterPrefix)
		if !utils.VerifyDataContains(t, actualAttachmentName, expectedAttachmentName, logger) {
			return fmt.Errorf("attachment not found. Expected name: %s, but got: %s", expectedAttachmentName, actualAttachmentName)
		}

		actualAttachmentStatus := attachmentMap["status"].(string)
		if !utils.VerifyDataContains(t, actualAttachmentStatus, "enabled", logger) {
			return fmt.Errorf("attachment not enabled. Expected status: 'enabled', but got: %s", actualAttachmentStatus)
		}
	}

	return nil
}

// VerifyCloudLogsURLFromTerraformOutput validates cloud logs URL in Terraform outputs.
// It checks required fields in the Terraform output map and validates the cloud logs URL
// when cloud logging is enabled for either management or compute nodes.
// Returns an error if validation fails.
func VerifyCloudLogsURLFromTerraformOutput(t *testing.T, LastTestTerraformOutputs map[string]interface{}, isCloudLogsEnabledForManagement, isCloudLogsEnabledForCompute bool, logger *utils.AggregatedLogger) error {

	logger.Info(t, fmt.Sprintf("Terraform Outputs: %+v", LastTestTerraformOutputs))

	// Required fields for validation
	requiredFields := []string{
		"ssh_to_management_node_1",
		"ssh_to_login_node",
		"region_name",
		"vpc_name",
	}

	// Validate required fields
	for _, field := range requiredFields {
		value, ok := LastTestTerraformOutputs[field].(string)
		if !ok || len(strings.TrimSpace(value)) == 0 {
			return fmt.Errorf("field '%s' is missing or empty in Terraform outputs", field)
		}
		logger.Info(t, fmt.Sprintf("%s = %s", field, value))
	}

	// Validate cloud_logs_url if logging is enabled
	if isCloudLogsEnabledForManagement || isCloudLogsEnabledForCompute {
		cloudLogsURL, ok := LastTestTerraformOutputs["cloud_logs_url"].(string)
		if !ok || len(strings.TrimSpace(cloudLogsURL)) == 0 {
			return errors.New("missing or empty 'cloud_logs_url' in Terraform outputs")
		}
		logger.Info(t, fmt.Sprintf("cloud_logs_url = %s", cloudLogsURL))
		statusCode, err := utils.CheckAPIStatus(cloudLogsURL)
		if err != nil {
			return fmt.Errorf("error checking cloud_logs_url API: %v", err)
		}

		logger.Info(t, fmt.Sprintf("API Status: %s - %d", cloudLogsURL, statusCode))

		if statusCode != 200 {
			logger.FAIL(t, fmt.Sprintf("API returned non-success status: %d", statusCode))
			return fmt.Errorf("API returned non-success status: %d", statusCode)
		}

		logger.PASS(t, fmt.Sprintf("API returned success status: %d", statusCode))

	}

	logger.Info(t, "Terraform output validation completed successfully")
	return nil
}

// LSFFluentBitServiceForManagementNodes validates Fluent Bit service for management nodes.
// It connects via SSH to each management node, validates the Fluent Bit service state, and logs results.
// Returns an error if the process encounters any issues during validation, or nil if successful.
func LSFFluentBitServiceForManagementNodes(t *testing.T, sshClient *ssh.Client, managementNodeIPs []string, isCloudLogsManagementEnabled bool, logger *utils.AggregatedLogger) error {

	// Ensure management node IPs are provided if cloud logs are enabled
	if isCloudLogsManagementEnabled {
		if len(managementNodeIPs) == 0 {
			return errors.New("management node IPs cannot be empty")
		}

		for _, managementIP := range managementNodeIPs {

			err := VerifyFluentBitServiceForNode(t, sshClient, managementIP, isCloudLogsManagementEnabled, logger)
			if err != nil {
				return fmt.Errorf("failed Fluent Bit service verification for management node %s: %w", managementIP, err)
			}
		}
	}

	return nil
}

// LSFFluentBitServiceForComputeNodes initiates the process of validating Fluent Bit service
// on all compute nodes in a cluster. If cloud logging is enabled, it checks the service
// status for each compute node. It returns an error if any node fails the verification.
// Returns an error if the process encounters any issues during validation, or nil if successful.
func LSFFluentBitServiceForComputeNodes(
	t *testing.T,
	sshClient *ssh.Client,
	staticWorkerNodeIPs []string,
	isCloudLogsComputeEnabled bool,
	logger *utils.AggregatedLogger) error {

	// Ensure worker node IPs are provided if cloud logs are enabled
	if isCloudLogsComputeEnabled {
		if len(staticWorkerNodeIPs) == 0 {
			return errors.New("worker node IPs cannot be empty")
		}

		// Retrieve compute node IPs from the worker nodes
		computeNodeIPs, err := GetComputeNodeIPs(t, sshClient, staticWorkerNodeIPs, logger)
		if err != nil || len(computeNodeIPs) == 0 {
			return fmt.Errorf("failed to retrieve compute node IPs: %w", err)
		}

		// Iterate over each compute node and verify Fluent Bit service
		for _, computeIP := range computeNodeIPs {
			err := VerifyFluentBitServiceForNode(t, sshClient, computeIP, isCloudLogsComputeEnabled, logger)
			if err != nil {
				return fmt.Errorf("failed Fluent Bit service verification for compute node %s: %w", computeIP, err)
			}
		}
	}
	return nil
}

// VerifyFluentBitServiceForNode validates the Fluent Bit service state for a given node.
// It checks whether the Fluent Bit service is running as expected or if it has failed based on
// the cloud logging configuration. The function returns an error if the service state does not
// match the expected "active (running)" state.
// Returns an error if the Fluent Bit service is not in the expected state, or nil if successful.
func VerifyFluentBitServiceForNode(
	t *testing.T,
	sshClient *ssh.Client,
	nodeIP string,
	isCloudLogsEnabled bool,
	logger *utils.AggregatedLogger) error {

	// Command to check the status of Fluent Bit service on the node
	command := fmt.Sprintf("ssh %s systemctl status fluent-bit", nodeIP)
	output, err := utils.RunCommandInSSHSession(sshClient, command)
	if err != nil {
		// Return an error if the command fails to execute
		return fmt.Errorf("failed to execute command '%s' on node %s: %w", command, nodeIP, err)
	}

	// Expected Fluent Bit service state should be "active (running)"
	expectedState := "Active: active (running)"

	// Verify if the service is in the expected running state
	if !utils.VerifyDataContains(t, output, expectedState, logger) {
		// If the service state does not match the expected state, return an error with output
		return fmt.Errorf(
			"unexpected Fluent Bit service state for node %s: expected '%s', got:\n%s",
			nodeIP, expectedState, output,
		)
	}

	// Log success if Fluent Bit service is running as expected
	logger.Info(t, fmt.Sprintf("Fluent Bit service validation passed for node %s", nodeIP))
	return nil
}

// FetchTenants retrieves the list of tenants using IBM Cloud Log Router API
func FetchTenants(region, token string) (string, error) {

	// Construct the curl command with the IAM token passed directly
	cmd := exec.Command("bash", "-c", fmt.Sprintf(`
		curl -X GET "https://management.%s.logs-router.cloud.ibm.com:443/v1/tenants" \
		-H "Authorization: Bearer $(ibmcloud iam oauth-tokens | awk '{print $4}')" \
		-H "IBM-API-Version: $(date +%%Y-%%m-%%d)"
	`, region))

	// Execute the command and capture the output
	output, err := cmd.CombinedOutput()
	if err != nil {
		return "", fmt.Errorf("failed to fetch tenants: %w\nOutput: %s", err, string(output))
	}

	return strings.TrimSpace(string(output)), nil

}

// CheckPlatformLogsPresent verifies whether the specified IBM Cloud service instance has platform logs enabled.
func CheckPlatformLogsPresent(t *testing.T, apiKey, region, resourceGroup string, logger *utils.AggregatedLogger) (bool, error) {
	// Log into IBM Cloud using the CLI
	err := utils.LoginIntoIBMCloudUsingCLI(t, apiKey, region, resourceGroup)
	if err != nil {
		return false, fmt.Errorf("failed to log in to IBM Cloud: %w", err)
	}

	// Retrieve IAM Token
	token, err := utils.GetIAMToken()
	if err != nil {
		logger.Info(t, fmt.Sprintf("Error getting IAM token: %v", err))
		return false, err
	}
	logger.Info(t, "Successfully retrieved IAM token") // Do not log the token itself

	// Fetch tenants from the API
	response, err := FetchTenants(region, token)
	if err != nil {
		logger.Info(t, fmt.Sprintf("Error fetching tenants: %v", err))
		return false, err
	}

	// Log the full response
	logger.Info(t, fmt.Sprintf("IBM Cloud Tenants Response: %s", response))

	expectedOutput := "{\"tenants\":[]}"
	// Check if the output contains the expected "platform logs" entry
	if utils.VerifyDataContains(t, response, expectedOutput, logger) {
		// This indicates that the "tenants" array is empty, so no platform logs were found
		logger.Info(t, fmt.Sprintf("No platform logs found for region '%s'.", region))
		return false, nil
	}

	// Log and return true if platform logs are found (i.e., tenants array is not empty)
	logger.Info(t, fmt.Sprintf("Platform logs found for region '%s'.", region))
	return true, nil
}

// VerifyCloudMonitoringURLFromTerraformOutput validates the cloud log URL in Terraform outputs.
// It checks required fields in the Terraform output map and ensures the cloud logs URL
// is present when cloud logging is enabled for either management or compute nodes.
// If validation fails, it returns an error; otherwise, it logs success.

func VerifycloudMonitoringURLFromTerraformOutput(t *testing.T, LastTestTerraformOutputs map[string]interface{}, isCloudMonitoringEnabledForManagement, isCloudMonitoringEnabledForCompute bool, logger *utils.AggregatedLogger) error {

	logger.Info(t, fmt.Sprintf("Terraform Outputs: %+v", LastTestTerraformOutputs))

	// Required fields for validation
	requiredFields := []string{
		"ssh_to_management_node_1",
		"ssh_to_login_node",
		"region_name",
		"vpc_name",
	}

	// Validate required fields
	for _, field := range requiredFields {
		value, ok := LastTestTerraformOutputs[field].(string)
		if !ok || len(strings.TrimSpace(value)) == 0 {
			return fmt.Errorf("field '%s' is missing or empty in Terraform outputs", field)
		}
		logger.Info(t, fmt.Sprintf("%s = %s", field, value))
	}

	// Validate cloud_monitoring_url if logging is enabled
	if isCloudMonitoringEnabledForManagement || isCloudMonitoringEnabledForCompute {
		cloudLogsURL, ok := LastTestTerraformOutputs["cloud_monitoring_url"].(string)
		if !ok || len(strings.TrimSpace(cloudLogsURL)) == 0 {
			return errors.New("missing or empty 'cloud_monitoring_url' in Terraform outputs")
		}

		logger.PASS(t, fmt.Sprintf("cloud_monitoring_url present: %s", cloudLogsURL))
	}

	logger.Info(t, "cloud_monitoring_url Terraform output validation completed successfully")
	return nil
}

// LSFPrometheusAndDragentServiceForManagementNodes validates the Prometheus and Dragent services for management nodes.
// If cloud monitoring is enabled, it connects via SSH to each management node and verifies service statuses.
// The function logs results and returns an error if any node fails validation.

func LSFPrometheusAndDragentServiceForManagementNodes(t *testing.T, sshClient *ssh.Client, managementNodeIPs []string, isCloudMonitoringEnabledForManagement bool, logger *utils.AggregatedLogger) error {

	// Ensure management node IPs are provided if cloud logs are enabled
	if isCloudMonitoringEnabledForManagement {
		if len(managementNodeIPs) == 0 {
			return errors.New("management node IPs cannot be empty")
		}

		for _, managementIP := range managementNodeIPs {

			err := VerifyLSFPrometheusServiceForNode(t, sshClient, managementIP, logger)
			if err != nil {
				return fmt.Errorf("failed Prometheus service verification for management node %s: %w", managementIP, err)
			}

			err = VerifyLSFdragentServiceForNode(t, sshClient, managementIP, logger)
			if err != nil {
				return fmt.Errorf("failed dragent service verification for management node %s: %w", managementIP, err)
			}
		}
	} else {
		logger.Warn(t, "Cloud monitoring are not enabled for the management node. As a result, the Prometheus and Fluent dragent service will not be validated.")
	}

	return nil
}

// LSFDragentServiceForComputeNodes validates the Dragent services for compute nodes.
// If cloud monitoring is enabled, it retrieves compute node IPs and verifies service statuses via SSH.
// The function logs results and returns an error if any node fails validation.

func LSFDragentServiceForComputeNodes(
	t *testing.T,
	sshClient *ssh.Client,
	staticWorkerNodeIPs []string,
	isCloudMonitoringEnabledForCompute bool,
	logger *utils.AggregatedLogger) error {

	// Ensure worker node IPs are provided if cloud logs are enabled
	if isCloudMonitoringEnabledForCompute {
		if len(staticWorkerNodeIPs) == 0 {
			return errors.New("worker node IPs cannot be empty")
		}

		// Retrieve compute node IPs from the worker nodes
		computeNodeIPs, err := GetComputeNodeIPs(t, sshClient, staticWorkerNodeIPs, logger)
		if err != nil || len(computeNodeIPs) == 0 {
			return fmt.Errorf("failed to retrieve compute node IPs: %w", err)
		}

		// Iterate over each compute node and verify dragent service
		for _, computeIP := range computeNodeIPs {

			err = VerifyLSFdragentServiceForNode(t, sshClient, computeIP, logger)
			if err != nil {
				return fmt.Errorf("failed dragent service verification for compute node %s: %w", computeIP, err)
			}

		}
	} else {
		logger.Warn(t, "Cloud monitoring are not enabled for the compute node. As a result, the dragent service will not be validated.")
	}
	return nil
}

// VerifyLSFPrometheusServiceForNode checks the status of the Prometheus service on a given node.
// It ensures the service is running and returns an error if its state does not match "active (running)."
func VerifyLSFPrometheusServiceForNode(
	t *testing.T,
	sshClient *ssh.Client,
	nodeIP string,
	logger *utils.AggregatedLogger) error {

	// Command to check the status of Prometheus service on the node
	command := fmt.Sprintf("ssh %s systemctl status prometheus", nodeIP)
	output, err := utils.RunCommandInSSHSession(sshClient, command)
	if err != nil {
		// Return an error if the command fails to execute
		return fmt.Errorf("failed to execute command '%s' on node %s: %w", command, nodeIP, err)
	}

	// Expected Fluent Bit service state should be "active (running)"
	expectedState := "Active: active (running)"

	// Verify if the service is in the expected running state
	if !utils.VerifyDataContains(t, output, expectedState, logger) {
		// If the service state does not match the expected state, return an error with output
		return fmt.Errorf(
			"unexpected Prometheus service state for node %s: expected '%s', got:\n%s",
			nodeIP, expectedState, output,
		)
	}

	// Log success if Fluent Bit service is running as expected
	logger.Info(t, fmt.Sprintf("Prometheus service validation passed for node %s", nodeIP))
	return nil
}

// VerifyLSFDragentServiceForNode checks the status of the Dragent service on a given node.
// It ensures the service is running and returns an error if its state does not match "active (running)."
func VerifyLSFdragentServiceForNode(
	t *testing.T,
	sshClient *ssh.Client,
	nodeIP string,
	logger *utils.AggregatedLogger) error {

	// Command to check the status of Prometheus service on the node
	command := fmt.Sprintf("ssh %s systemctl status dragent", nodeIP)
	output, err := utils.RunCommandInSSHSession(sshClient, command)
	if err != nil {
		// Return an error if the command fails to execute
		return fmt.Errorf("failed to execute command '%s' on node %s: %w", command, nodeIP, err)
	}

	// Expected Fluent Bit service state should be "active (running)"
	expectedState := "Active: active (running)"

	// Verify if the service is in the expected running state
	if !utils.VerifyDataContains(t, output, expectedState, logger) {
		// If the service state does not match the expected state, return an error with output
		return fmt.Errorf(
			"unexpected dragent service state for node %s: expected '%s', got:\n%s",
			nodeIP, expectedState, output,
		)
	}

	// Log success if Fluent Bit service is running as expected
	logger.Info(t, fmt.Sprintf("dragent service validation passed for node %s", nodeIP))
	return nil
}

// ValidateDynamicWorkerProfile checks if the dynamic worker node profile matches the expected value.
// It logs into IBM Cloud, fetches cluster resources, extracts the worker profile, and validates it.
// Returns an error if the actual profile differs from the expected profile; otherwise, it returns nil.
func ValidateDynamicWorkerProfile(t *testing.T, apiKey, region, resourceGroup, clusterPrefix, expectedDynamicWorkerProfile string, logger *utils.AggregatedLogger) error {

	// If the resource group is "null", set a custom resource group based on the cluster prefix
	if strings.Contains(resourceGroup, "null") {
		resourceGroup = fmt.Sprintf("%s-workload-rg", clusterPrefix)
	}

	// Log in to IBM Cloud using the provided API key and region
	if err := utils.LoginIntoIBMCloudUsingCLI(t, apiKey, region, resourceGroup); err != nil {
		return fmt.Errorf("failed to log in to IBM Cloud: %w", err)
	}

	// Fetch cluster resource list using IBM Cloud CLI
	fetchClusterResourcesCmd := fmt.Sprintf("ibmcloud is instances | grep %s", clusterPrefix)
	cmd := exec.Command("bash", "-c", fetchClusterResourcesCmd)
	clusterResourceList, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("failed to retrieve cluster resource list: %w", err)
	}

	// Fetch the dynamic worker node profile
	dynamicWorkerProfileCmd := fmt.Sprintf("ibmcloud is instances | grep %s | awk '/-compute-/ && !/-worker-|-login-|-mgmt-|-bastion-/ {print $6; exit}'", clusterPrefix)
	cmd = exec.Command("bash", "-c", dynamicWorkerProfileCmd)
	dynamicWorkerProfile, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("failed to retrieve dynamic worker node profile: %w", err)
	}

	// Convert output to string and trim spaces
	actualDynamicWorkerProfile := strings.TrimSpace(string(dynamicWorkerProfile))

	// Verify if the actual worker node profile matches the expected profile
	if !utils.VerifyDataContains(t, expectedDynamicWorkerProfile, actualDynamicWorkerProfile, logger) {
		return fmt.Errorf("dynamic worker node profile mismatch: actual: '%s', expected: '%s', output: '%s'", actualDynamicWorkerProfile, expectedDynamicWorkerProfile, clusterResourceList)
	}

	return nil
}

// GetAtrackerRouteTargetID retrieves the Atracker route target ID from IBM Cloud.
// It logs into IBM Cloud, fetches route details, and extracts the target ID if Observability Atracker is enabled.
// If Observability Atracker is disabled, it ensures no Atracker route exists.
// Returns the target ID if found or an error if retrieval or validation fails.
func GetAtrackerRouteTargetID(t *testing.T, apiKey, region, resourceGroup, clusterPrefix string, ObservabilityAtrackerEnable bool, logger *utils.AggregatedLogger) (string, error) {

	type Rule struct {
		TargetIDs []string `json:"target_ids"`
	}
	type RouteResponse struct {
		ID    string `json:"id"`
		Name  string `json:"name"`
		CRN   string `json:"crn"`
		Rules []Rule `json:"rules"`
	}

	if strings.Contains(resourceGroup, "null") {
		resourceGroup = fmt.Sprintf("%s-workload-rg", clusterPrefix)
	}

	if err := utils.LoginIntoIBMCloudUsingCLI(t, apiKey, region, resourceGroup); err != nil {
		return "", fmt.Errorf("failed to log in to IBM Cloud: %w", err)
	}

	cmd := exec.Command("ibmcloud", "atracker", "route", "get", "--route", fmt.Sprintf("%s-atracker-route", clusterPrefix), "--output", "JSON")
	output, err := cmd.CombinedOutput()
	if err != nil {
		return "", fmt.Errorf("failed to retrieve atracker route: %s, error: %w", string(output), err)
	}

	var response RouteResponse
	if err := json.Unmarshal(output, &response); err != nil {
		return "", fmt.Errorf("error unmarshaling JSON: %w. Raw output: %s", err, string(output))
	}

	jsonResp, _ := json.MarshalIndent(response, "", "  ")
	logger.Info(t, fmt.Sprintf("Atracker Route Response: %s", string(jsonResp)))

	expectedRouteName := fmt.Sprintf("%s-atracker-route", clusterPrefix)
	if !utils.VerifyDataContains(t, strings.TrimSpace(response.Name), expectedRouteName, logger) {
		return "", fmt.Errorf("unexpected atracker route name: got %s, want %s", response.Name, expectedRouteName)
	}

	if len(response.Rules) == 0 || len(response.Rules[0].TargetIDs) == 0 {
		return "", errors.New("no target IDs found in rules")
	}

	logger.Info(t, fmt.Sprintf("Target ID: %s", response.Rules[0].TargetIDs[0]))
	return response.Rules[0].TargetIDs[0], nil
}

// ValidateAtrackerRouteTarget verifies the properties of an Atracker route target in IBM Cloud.
// It logs into IBM Cloud, fetches the target details, and ensures that the target ID, name,
// type, write status, and CRN meet expected values. If any validation fails, it returns an error.
func ValidateAtrackerRouteTarget(t *testing.T, apiKey, region, resourceGroup, clusterPrefix, targetID, targetType string, logger *utils.AggregatedLogger) error {
	// Define response structures
	type WriteStatus struct {
		Status string `json:"status"`
	}
	type TargetResponse struct {
		ID          string      `json:"id"`
		Name        string      `json:"name"`
		CRN         string      `json:"crn"`
		TargetType  string      `json:"target_type"`
		WriteStatus WriteStatus `json:"write_status"`
	}

	// Handle null resourceGroup
	if strings.Contains(resourceGroup, "null") {
		resourceGroup = fmt.Sprintf("%s-workload-rg", clusterPrefix)
	}

	// Login to IBM Cloud
	if err := utils.LoginIntoIBMCloudUsingCLI(t, apiKey, region, resourceGroup); err != nil {
		return fmt.Errorf("failed to log in to IBM Cloud: %w", err)
	}

	// Execute command to get Atracker target details
	cmd := exec.Command("bash", "-c", fmt.Sprintf("ibmcloud atracker target validate --target %s --output JSON", targetID))
	output, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("failed to retrieve atracker target: %s, error: %w", string(output), err)
	}

	// Parse JSON response
	var response TargetResponse
	if err := json.Unmarshal(output, &response); err != nil {
		return fmt.Errorf("error unmarshaling JSON: %s, error: %w", string(output), err)
	}

	// Log the parsed response
	logger.Info(t, fmt.Sprintf("Atracker Target Response: %+v", response))

	// Expected target name based on targetType
	expectedTargetName := fmt.Sprintf("%s-atracker", clusterPrefix)
	if targetType == "cloudlogs" {
		expectedTargetName = fmt.Sprintf("%s-atracker-target", clusterPrefix)
	}

	// Validate target name
	if !utils.VerifyDataContains(t, strings.TrimSpace(response.Name), expectedTargetName, logger) {
		return fmt.Errorf("unexpected atracker target name: got %s, want %s", response.Name, expectedTargetName)
	}

	// Validate write status
	if !utils.VerifyDataContains(t, strings.TrimSpace(response.WriteStatus.Status), "success", logger) {
		return fmt.Errorf("unexpected write status: got %s, want success", response.WriteStatus.Status)
	}

	// Normalize targetType before validation
	expectedTargetType := targetType
	switch targetType {
	case "cloudlogs":
		expectedTargetType = "cloud_logs"
	case "cos":
		expectedTargetType = "cloud_object_storage"
	}

	// Validate target type
	if !utils.VerifyDataContains(t, strings.TrimSpace(response.TargetType), expectedTargetType, logger) {
		return fmt.Errorf("unexpected target type: got %s, want %s", response.TargetType, expectedTargetType)
	}

	// Validate CRN presence
	if response.CRN == "" {
		return errors.New("CRN value should not be empty")
	}

	return nil
}
