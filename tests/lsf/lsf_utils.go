package lsf

import (
	"bufio"
	"fmt"
	"regexp"
	"sort"
	"strings"
	"testing"
	"time"

	"github.com/terraform-ibm-modules/terraform-ibm-hpc/utils"
	util "github.com/terraform-ibm-modules/terraform-ibm-hpc/utils"
	"golang.org/x/crypto/ssh"
)

const (
	startSleepDuration             = 30 * time.Second
	stopSleepDuration              = 30 * time.Second
	timeOutForDynamicNodeDisappear = 12 * time.Minute
)

// LSFMTUCheck checks the MTU setting for multiple nodes of a specified type.
// and returns an error if any node's MTU is not 9000.

func LSFMTUCheck(t *testing.T, client *ssh.Client, ipsList []string, logger *util.AggregatedLogger) error {

	if len(ipsList) == 0 {
		return fmt.Errorf("ips cannot be empty")
	}

	for _, ip := range ipsList {
		command := fmt.Sprintf("ssh %s ifconfig", ip)
		output, err := util.RunCommandInSSHSession(client, command)
		if err != nil {
			return fmt.Errorf("failed to execute 'ifconfig' command on (%s) node : %w", ip, err)
		}

		if !utils.VerifyDataContains(t, output, "mtu 9000", logger) {
			return fmt.Errorf("MTU is not set to 9000 for (%s) node  and found : \n%s", ip, output)
		}
		logger.Info(t, fmt.Sprintf("MTU is set to 9000 for (%s) node ", ip))
	}

	return nil
}

// LSFCheckClusterID checks if the provided cluster ID matches the expected value.
// It uses the provided SSH client to execute the 'lsid' command and verifies
// if the expected cluster ID is present in the command output.
// Returns an error if the checks fail.
func LSFCheckClusterID(t *testing.T, sClient *ssh.Client, expectedClusterID string, logger *util.AggregatedLogger) error {

	// Execute the 'lsid' command to get the cluster ID
	command := "lsid"
	output, err := util.RunCommandInSSHSession(sClient, command)
	if err != nil {
		return fmt.Errorf("failed to execute 'lsid' command: %w", err)
	}

	// Verify if the expected cluster ID is present in the output
	if !utils.VerifyDataContains(t, output, "My cluster name is "+expectedClusterID, logger) {
		actualValue := strings.TrimSpace(strings.Split(strings.Split(output, "My cluster name is")[1], "My master name is")[0])
		return fmt.Errorf("expected cluster ID %s , but found \n%s", expectedClusterID, actualValue)
	}

	logger.Info(t, fmt.Sprintf("Cluster ID is set as expected : %s", expectedClusterID))
	return nil
}

// LSFCheckMasterName checks if the provided master name matches the expected value.
// It uses the provided SSH client to execute the 'lsid' command and verifies
// if the expected master name is present in the command output.
// Returns an error if the checks fail.
func LSFCheckMasterName(t *testing.T, sClient *ssh.Client, expectedMasterName string, logger *util.AggregatedLogger) error {
	// Execute the 'lsid' command to get the cluster ID
	command := "lsid"
	output, err := util.RunCommandInSSHSession(sClient, command)
	if err != nil {
		return fmt.Errorf("failed to execute 'lsid' command: %w", err)
	}

	// Verify if the expected master name is present in the output
	if !utils.VerifyDataContains(t, output, "My master name is "+expectedMasterName+"-mgmt-1", logger) {
		actualValue := strings.TrimSpace(strings.Split(output, "My master name is")[1])
		return fmt.Errorf("expected master name %s , but found \n%s", expectedMasterName, actualValue)
	}

	logger.Info(t, fmt.Sprintf("Master name is set as expected : %s", expectedMasterName))
	return nil
}

// HPCCheckContractID verifies if the provided SSH client's 'lsid' command output
// contains the expected Contract ID. Logs and returns an error if verification fails.
func HPCCheckContractID(t *testing.T, sClient *ssh.Client, expectedContractID string, logger *util.AggregatedLogger) error {

	ibmCloudHPCConfigPath := "/opt/ibm/lsf/conf/resource_connector/ibmcloudhpc/conf/ibmcloudhpc_config.json"

	command := fmt.Sprintf("cat %s", ibmCloudHPCConfigPath)
	output, err := util.RunCommandInSSHSession(sClient, command)
	if err != nil || !utils.VerifyDataContains(t, output, expectedContractID, logger) {
		return fmt.Errorf("failed Contract ID verification: %w", err)
	}
	logger.Info(t, fmt.Sprintf("Contract ID verified: %s", expectedContractID))
	return nil
}

// LSFCheckManagementNodeCount checks if the actual count of management nodes matches the expected count.
// It uses the provided SSH client to execute the 'bhosts' command with filters to
// count the number of nodes containing 'mgmt' in their names. The function then verifies
// if the actual count matches the expected count.
// Returns an error if the checks fail.
func LSFCheckManagementNodeCount(t *testing.T, sClient *ssh.Client, expectedManagementCount string, logger *util.AggregatedLogger) error {
	// Execute the 'bhosts' command to get the management node count
	command := "bhosts -w | grep 'mgmt' | wc -l"
	output, err := util.RunCommandInSSHSession(sClient, command)
	if err != nil {
		return fmt.Errorf("failed to execute 'bhosts' command: %w", err)
	}

	// Verify if the expected management node count is present in the output
	if !utils.VerifyDataContains(t, output, expectedManagementCount, logger) {
		return fmt.Errorf("expected %s management nodes, but found %s", expectedManagementCount, strings.TrimSpace(output))
	}

	logger.Info(t, fmt.Sprintf("Management node count is as expected: %s", expectedManagementCount))
	return nil
}

// LSFRestartDaemons restarts the LSF daemons on the provided SSH client.
// It executes the 'lsf_daemons restart' command as root, checks for a successful
// restart, and waits for LSF to start up.
func LSFRestartDaemons(t *testing.T, sClient *ssh.Client, logger *util.AggregatedLogger) error {

	// Restart LSF daemons
	restartCmd := "sudo su -l root -c 'lsf_daemons restart'"
	out, err := util.RunCommandInSSHSession(sClient, restartCmd)
	if err != nil {
		return fmt.Errorf("failed to run 'lsf_daemons restart' command: %w", err)
	}

	// Check if the restart was successful
	if !(utils.VerifyDataContains(t, string(out), "Stopping", logger) && utils.VerifyDataContains(t, string(out), "Starting", logger)) {
		return fmt.Errorf("lsf_daemons restart failed")
	}

	// Wait for LSF to start up
	for {
		command := "bhosts -w"
		startOut, err := util.RunCommandInSSHSession(sClient, command)
		if err != nil {
			return fmt.Errorf("failed to run 'bhosts' command: %w", err)
		}
		if !utils.VerifyDataContains(t, string(startOut), "LSF is down", logger) {
			break
		}
		time.Sleep(5 * time.Second)
	}
	logger.Info(t, "lsf_daemons restart successfully")
	return nil
}

// LSFControlBctrld performs start or stop operation on the bctrld daemon on the specified machine.
// The function returns an error if any step fails or if an invalid startOrStop value is provided.
// It executes the 'bctrld' command with the specified operation and waits for the daemon to start or stop.
func LSFControlBctrld(t *testing.T, sClient *ssh.Client, startOrStop string, logger *util.AggregatedLogger) error {

	// Execute the 'bctrld' command to start or stop the sbd daemon
	command := fmt.Sprintf("bctrld %s sbd", startOrStop)
	_, bctrldErr := util.RunCommandInSSHSession(sClient, command)
	if bctrldErr != nil {
		return fmt.Errorf("failed to run '%s' command: %w", command, bctrldErr)
	}

	//log.Printf("Executing '%s' command to %s the sbd daemon", command, startOrStop)

	// Check the output based on the startOrStop parameter
	if startOrStop == "start" {
		// Sleep for 10 seconds to allow time for the daemon to start
		time.Sleep(startSleepDuration)
		//log.Printf("Waiting for %f seconds for the daemon to start", startSleepDuration.Seconds())

		// Check the status of the daemon using the 'bhosts' command
		command := "bhosts -w"
		startOut, err := util.RunCommandInSSHSession(sClient, command)
		if err != nil {
			return fmt.Errorf("failed to run 'bhosts' command on machine IP: %w", err)
		}
		// Count the number of unreachable nodes
		unreachCount := strings.Count(string(startOut), "unreach")

		// If the unreachable node count does not match the expected count, return an error
		if unreachCount != 0 {
			return fmt.Errorf("failed to start the sbd daemon on the management node")
		}
	} else if startOrStop == "stop" {
		// Sleep for 30 seconds to allow time for the daemon to stop
		time.Sleep(stopSleepDuration)
		//log.Printf("Waiting for %f seconds for the daemon to stop", stopSleepDuration.Seconds())

		// Check the status of the daemon using the 'bhosts' command
		command := "bhosts -w"
		stopOut, err := util.RunCommandInSSHSession(sClient, command)
		if err != nil {
			return fmt.Errorf("failed to run 'bhosts' command on machine IP: %w", err)
		}
		// Count the number of unreachable nodes
		unreachCount := strings.Count(string(stopOut), "unreach")
		// If the unreachable node count does not match the expected count, return an error
		if unreachCount != 1 {
			return fmt.Errorf("failed to stop the sbd daemon on the management node")
		}
	} else {
		// Return an error for an invalid operation
		return fmt.Errorf("invalid operation. Please specify 'start' or 'stop'")
	}

	logger.Info(t, fmt.Sprintf("Daemon %s successfully", startOrStop))
	return nil
}

// LSFCheckIntelOneMpiOnComputeNodes checks the Intel OneAPI MPI on compute nodes.
// It verifies the existence of setvars.sh and mpi in the OneAPI folder, and initializes the OneAPI environment.
// and returns an error if any check fails.
func LSFCheckIntelOneMpiOnComputeNodes(t *testing.T, sClient *ssh.Client, ipsList []string, logger *util.AggregatedLogger) error {
	// Validate input parameters
	if len(ipsList) == 0 {
		return fmt.Errorf("ips cannot be empty")
	}

	// Check Intel OneAPI MPI on each compute node
	for _, ip := range ipsList {
		// Check if OneAPI folder exists and contains setvars.sh and mpi
		checkCmd := fmt.Sprintf("ssh %s 'ls /opt/intel/oneapi'", ip)

		checkOutput, checkErr := util.RunCommandInSSHSession(sClient, checkCmd)
		if checkErr != nil {
			return fmt.Errorf("failed to run '%s' command: %w", checkCmd, checkErr)
		}

		if !utils.VerifyDataContains(t, checkOutput, "setvars.sh", logger) && !utils.VerifyDataContains(t, checkOutput, "mpi", logger) {
			return fmt.Errorf("setvars.sh or mpi not found in OneAPI folder: %s", checkOutput)
		}

		// Initialize OneAPI environment
		initCmd := fmt.Sprintf("ssh -t %s 'sudo su -l root -c \". /opt/intel/oneapi/setvars.sh\"'", ip)
		initOutput, initErr := util.RunCommandInSSHSession(sClient, initCmd)
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
func LSFRebootInstance(t *testing.T, sClient *ssh.Client, logger *util.AggregatedLogger) error {

	restartCmd := "sudo su -l root -c 'reboot'"

	session, err := sClient.NewSession()
	if err != nil {
		return fmt.Errorf("failed to create SSH session: %w", err)
	}
	defer session.Close()

	err = session.Run(restartCmd)
	if err != nil {
		return fmt.Errorf("failed to run '%s' command: %w", restartCmd, err)
	}

	// Sleep for a short duration to allow the instance to restart
	time.Sleep(10 * time.Second)

	logger.Info(t, "LSF instance successfully rebooted")
	return nil
}

// LSFCheckBhostsResponse checks if the output of the 'bhosts' command is empty.
// It executes the 'bhosts' command on the provided SSH client.
// Returns an error if the 'bhosts' command output is empty
func LSFCheckBhostsResponse(t *testing.T, sClient *ssh.Client, logger *util.AggregatedLogger) error {
	command := "bhosts"

	output, err := util.RunCommandInSSHSession(sClient, command)
	if err != nil {
		return fmt.Errorf("failed to run '%s' command: %w", command, err)
	}

	// Check if the 'bhosts' command output is empty
	if len(strings.TrimSpace(output)) > 0 {
		return fmt.Errorf("non-empty response from 'bhosts' command: %s", output)
	}

	logger.Info(t, fmt.Sprintf("bhosts value: %s", output))
	return nil
}

// LSFRunJobs executes an LSF job on a remote server via SSH, monitors its status,
// and ensures its completion or terminates it if it exceeds a specified timeout.
// It returns an error if any step of the process fails.
func LSFRunJobs(t *testing.T, sClient *ssh.Client, jobCmd string, logger *util.AggregatedLogger) error {

	// Set the maximum time allowed for the job to run
	jobMaxTimeout := 10 * time.Minute

	// Record the start time of the job execution
	startTime := time.Now()

	// Run the LSF job command on the remote server
	jobOutput, err := util.RunCommandInSSHSession(sClient, jobCmd)
	if err != nil {
		return fmt.Errorf("failed to run '%s' command: %w", jobCmd, err)
	}

	// Log the job output for debugging purposes
	logger.Info(t, strings.TrimSpace(string(jobOutput)))

	// Extract the job ID from the job output
	jobID, err := LSFExtractJobID(jobOutput)
	if err != nil {
		return err
	}

	// Monitor the job's status until it completes or exceeds the timeout
	for time.Since(startTime) < jobMaxTimeout {
		command := "bjobs -a"
		// Run the 'bjobs' command to get information about all jobs
		jobsResp, err := util.RunCommandInSSHSession(sClient, command)
		if err != nil {
			return fmt.Errorf("failed to run 'bjobs' command: %w", err)
		}

		// Check if the job ID appears in the 'bjobs' response with a status of 'DONE'
		if utils.VerifyDataContains(t, jobsResp, jobID+"     lsfadmi DONE", logger) {
			logger.Info(t, fmt.Sprintf("Job %s has executed successfully", jobID))
			return nil
		}

		// Sleep for a minute before checking again
		logger.Info(t, "Waiting for dynamic node creation and job completion")
		time.Sleep(60 * time.Second)
	}

	// If the job exceeds the specified timeout, attempt to terminate it
	_, err = util.RunCommandInSSHSession(sClient, fmt.Sprintf("bkill %s", jobID))
	if err != nil {
		return fmt.Errorf("failed to run 'bkill' command: %w", err)
	}

	// Return an error indicating that the job execution exceeded the specified time
	return fmt.Errorf("job execution exceeded the specified time")
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

// LSFWaitForDynamicNodeDisappear monitors the 'bhosts -w' command output over SSH, waiting for a dynamic node to disappear.
// It sets a timeout and checks for disappearance until completion. Returns an error if the timeout is exceeded or if
// there is an issue running the SSH command.

func LSFWaitForDynamicNodeDisappear(t *testing.T, sClient *ssh.Client, logger *util.AggregatedLogger) error {

	// Record the start time of the job execution
	startTime := time.Now()

	// Monitor the dynamic node;  until it disappears or exceeds the timeout.
	for time.Since(startTime) < timeOutForDynamicNodeDisappear {
		command := "bhosts -w"
		output, err := util.RunCommandInSSHSession(sClient, command)

		if err != nil {
			return fmt.Errorf("failed to run SSH command '%s': %w", command, err)
		}

		if utils.VerifyDataContains(t, output, "ok", logger) {
			logger.Info(t, fmt.Sprintf("Waiting dynamic node to disappeard : \n%v", output))
			time.Sleep(1 * time.Minute)
		} else {
			logger.Info(t, "Dynamic node has disappeared!")
			return nil
		}
	}

	return fmt.Errorf("timeout of %s occurred while waiting for the dynamic node to disappear", timeOutForDynamicNodeDisappear.String())
}

// LSFAPPCenter performs configuration validation for the APP Center by checking the status of essential services
// (WEBGUI and PNC) and ensuring that the APP center port (8081) is actively listening.
// Returns an error if the validation encounters issues, otherwise, nil is returned.
func LSFAPPCenter(t *testing.T, sClient *ssh.Client, logger *util.AggregatedLogger) error {
	commandOne := "sudo su -l root -c 'pmcadmin list'"
	outputOne, err := util.RunCommandInSSHSession(sClient, commandOne)
	if err != nil {
		return fmt.Errorf("failed to run command '%s': %w", commandOne, err)
	}
	if !(utils.VerifyDataContains(t, outputOne, "WEBGUI         STARTED", logger) && utils.VerifyDataContains(t, outputOne, "PNC            STARTED", logger)) {
		return fmt.Errorf("APP Center GUI or PNC not configured: %s", outputOne)
	}

	commandTwo := "netstat -tuln | grep 8081"
	outputTwo, err := util.RunCommandInSSHSession(sClient, commandTwo)
	if err != nil {
		return fmt.Errorf("failed to run command '%s': %w", commandTwo, err)
	}
	if !utils.VerifyDataContains(t, outputTwo, "LISTEN", logger) {
		return fmt.Errorf("APP center port not listening as expected: %s", outputTwo)
	}

	logger.Info(t, "Appcenter configuration validated successfully")
	return nil
}

// HPCCheckFileMount checks if essential LSF directories (conf, das_staging_area, work) exist
// on remote machines identified by the provided list of IP addresses. It utilizes SSH to
// query and validate the directories. Any missing directory triggers an error, and the
// function logs the success message if all directories are found.
func HPCCheckFileMount(t *testing.T, client *ssh.Client, ipsList []string, logger *util.AggregatedLogger) error {

	if len(ipsList) == 0 {
		return fmt.Errorf("ips cannot be empty")
	}
	for _, ip := range ipsList {

		commandOne := fmt.Sprintf("ssh %s 'df -h'", ip)
		outputOne, err := util.RunCommandInSSHSession(client, commandOne)
		if err != nil {
			return fmt.Errorf("failed to run %s command on machine IP %s: %w", commandOne, ip, err)
		}
		actualMount := strings.TrimSpace(string(outputOne))

		expectedMount := []string{"/mnt/lsf", "/mnt/binaries", "/mnt/data"}

		for _, mount := range expectedMount {
			if !utils.VerifyDataContains(t, actualMount, mount, logger) {
				return fmt.Errorf("actual filesystem '%v' does not match the expected filesystem '%v' for node IP '%s'", actualMount, expectedMount, ip)
			}
		}

		logger.Info(t, "Filesystems [/mnt/lsf, /mnt/binaries, /mnt/data] exist on the node")

		commandTwo := fmt.Sprintf("ssh %s 'cd /mnt/lsf && ls'", ip)
		outputTwo, err := util.RunCommandInSSHSession(client, commandTwo)
		if err != nil {
			return fmt.Errorf("failed to run %s command on machine IP %s: %w", commandTwo, ip, err)
		}

		actualDirs := strings.Fields(strings.TrimSpace(string(outputTwo)))
		expectedDirs := []string{"conf", "das_staging_area", "work"}

		if !utils.VerifyDataContains(t, actualDirs, expectedDirs, logger) {
			return fmt.Errorf("actual directory '%v' does not match the expected directory '%v' for node IP '%s'", actualDirs, expectedDirs, ip)
		}

	}
	logger.Info(t, "Directories [conf,das_staging_area,and work] exist on ")
	return nil
}

// LSFGETDynamicComputeNodeIPs retrieves the IP addresses of dynamic worker nodes with a status of "ok".
// It returns a slice of IP addresses and an error if there was a problem executing the command or parsing the output.
func LSFGETDynamicComputeNodeIPs(t *testing.T, client *ssh.Client, logger *util.AggregatedLogger) ([]string, error) {
	workerIPs := []string{}

	// Run the "bhosts -w" command to get the node status
	command := "bhosts -w"
	nodeStatus, err := util.RunCommandInSSHSession(client, command)
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
func LSFDaemonsStatus(t *testing.T, sClient *ssh.Client, logger *util.AggregatedLogger) error {
	// expectedStatus is the status that each daemon should have (in this case, 'running').
	expectedStatus := "running"

	// i is used as an index to track the current daemon being checked.
	i := 0

	// Execute the 'lsf_daemons status' command to get the daemons status
	output, err := util.RunCommandInSSHSession(sClient, "lsf_daemons status")
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

	logger.Info(t, "All LSF daemons are running")
	return nil
}

// LSFCheckHyperthreadingIsEnabled checks if hyperthreading is enabled on the system by
// inspecting the output of the 'lscpu' command via an SSH session.
// It returns true if hyperthreading is enabled, false if it's disabled, and an error if
// there's an issue running the command or parsing the output.
func LSFCheckHyperthreadingIsEnabled(t *testing.T, sClient *ssh.Client, logger *util.AggregatedLogger) (bool, error) {
	// Run the 'lscpu' command to retrieve CPU information
	command := "lscpu"
	cpuInfo, err := util.RunCommandInSSHSession(sClient, command)
	if err != nil {
		return false, fmt.Errorf("failed to run '%s' command: %w", command, err)
	}

	// Convert the command output to a string
	content := string(cpuInfo)

	// Check if there is an "Off-line CPU(s) list:" indicating hyperthreading is disabled
	hasOfflineCPU := utils.VerifyDataContains(t, content, "Off-line CPU(s) list:", logger)

	// Print the result based on the hyperthreading status
	if !hasOfflineCPU {
		logger.Info(t, "Hyperthreading is enabled")
		return true, nil
	} else {
		logger.Info(t, "Hyperthreading is disabled")
		return false, nil
	}
}

// runSSHCommandAndGetPaths executes an SSH command to find all authorized_keys files and returns the list of paths.
func runSSHCommandAndGetPaths(sClient *ssh.Client) ([]string, error) {
	sshKeyCheckCmd := "sudo su -l root -c 'cd / && find / -name authorized_keys'"

	output, err := util.RunCommandInSSHSession(sClient, sshKeyCheckCmd)
	if err != nil {
		return nil, fmt.Errorf("failed to run '%s' command: %w", sshKeyCheckCmd, err)
	}

	return strings.Split(strings.TrimSpace(output), "\n"), nil
}

// LSFCheckSshKeyForManagement checks SSH key configurations for management servers.
func LSFCheckSshKeyForManagement(t *testing.T, sClient *ssh.Client, logger *util.AggregatedLogger) error {
	pathList, err := runSSHCommandAndGetPaths(sClient)
	if err != nil {
		return fmt.Errorf("failed to run 'cd / && find / -name authorized_keys' command: %w", err)
	}

	logger.Info(t, fmt.Sprintf("List of authorized_keys paths: %q", pathList))

	// Create a map with paths as keys and set specific values for certain paths
	pathMap := map[string]int{
		"/home/vpcuser/.ssh/authorized_keys":  1,
		"/home/lsfadmin/.ssh/authorized_keys": 2,
		"/root/.ssh/authorized_keys":          2,
	}

	for _, path := range pathList {
		cmd := fmt.Sprintf("sudo su -l root -c 'cat %s'", path)
		out, err := util.RunCommandInSSHSession(sClient, cmd)
		if err != nil {
			return fmt.Errorf("failed to run '%s' command: %w", cmd, err)
		}

		value := pathMap[path]
		occur := utils.CountStringOccurences(out, "ssh-rsa ")
		logger.Info(t, fmt.Sprintf("Value: %d, Occurrences: %d, Path: %s", value, occur, path))

		if value != occur {
			return fmt.Errorf("mismatch in occurrences for path %s: expected %d, got %d", path, value, occur)
		}
	}

	logger.Info(t, "SSH key check success")
	return nil
}

// LSFCheckSshKeyForCompute checks SSH key configurations for compute servers.
func LSFCheckSshKeyForCompute(t *testing.T, sClient *ssh.Client, logger *util.AggregatedLogger) error {
	const expectedAuthorizedKeysPaths = 3
	pathList, err := runSSHCommandAndGetPaths(sClient)
	if err != nil {
		return fmt.Errorf("failed to run 'cd / && find / -name authorized_keys' command: %w", err)
	}

	logger.Info(t, fmt.Sprintf("List of authorized_keys paths: %q", pathList))

	if len(pathList) != expectedAuthorizedKeysPaths {
		return fmt.Errorf("mismatch in the number of authorized_keys paths: expected %d, got %d", expectedAuthorizedKeysPaths, len(pathList))
	}

	// Create a map with paths as keys and set specific values for certain paths
	pathMap := map[string]int{
		"/home/lsfadmin/.ssh/authorized_keys": 2,
	}

	for path := range pathMap {
		cmd := fmt.Sprintf("sudo su -l root -c 'cat %s'", path)
		out, err := util.RunCommandInSSHSession(sClient, cmd)
		if err != nil {
			return fmt.Errorf("failed to run '%s' command: %w", cmd, err)
		}

		expectedOccurrences := pathMap[path]
		actualOccurrences := utils.CountStringOccurences(out, "ssh-rsa ")

		if expectedOccurrences != actualOccurrences {
			return fmt.Errorf("mismatch in occurrences for path %s: expected %d, got %d", path, expectedOccurrences, actualOccurrences)
		}
	}

	logger.Info(t, "SSH key check success")
	return nil
}
