package tests

import (
	"bufio"
	"fmt"
	"log"
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
	timeOutForDynamicNodeDisappear = 15 * time.Minute
	jobCompletionWaitTime          = 50 * time.Second
)

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

// ValidateCustomImageBuilderCreation verifies if the custom-image are being created successfully or not
// and correctly set in the specified resource group and cluster prefix.
// Returns: An error if the verification fails, otherwise nil
func ValidateCustomImageBuilderCreation(t *testing.T, apiKey, region, resourceGroup, customImageBuilderName string, logger *utils.AggregatedLogger) error {

	// If the resource group is "null", set it to a custom resource group with the format "customImageBuilderName-workload-rg"
	if strings.Contains(resourceGroup, "null") {
		resourceGroup = fmt.Sprintf("%s-Default", customImageBuilderName)
	}
	// Log in to IBM Cloud using the API key and region
	if err := utils.LoginIntoIBMCloudUsingCLI(t, apiKey, region, resourceGroup); err != nil {
		return fmt.Errorf("failed to log in to IBM Cloud: %w", err)
	}

	// Wait for the packer VSI to install all packages
	for count := range [7]int{} {
		time.Sleep(5 * time.Minute)
		count_ := fmt.Sprintf("%v", count+1)
		fmt.Printf("Waiting of 5 minutes count is %s, for the packer VSI to install all packages " + count_)
	}

	// Install VPC-Infrastructure if not installed
	_, error := exec.Command("ibmcloud", "plugin", "install", "vpc-infrastructure", "-f").Output()
	if error != nil {
		log.Fatalf("cmd.Run() failed with %s\n", error)
	}

	for {
		// Fetching the image details
		retrieveImageStatus := fmt.Sprintf("ibmcloud is image %s | grep -e available | awk '{print $2}' ", customImageBuilderName)
		cmdRetrieveImageStatus := exec.Command("bash", "-c", retrieveImageStatus)
		cutomImageStatusOutput, err := cmdRetrieveImageStatus.CombinedOutput()
		if err != nil {
			return fmt.Errorf("failed to retrieve custom image status: %w", err)
		}
		if strings.Contains(string(cutomImageStatusOutput), "available") {
			break
		} else {
			fmt.Printf("The custom image named as %s, is still in pending state. Wait for 5 more minutes, to recheck the status of the image", customImageBuilderName)
			time.Sleep(5 * time.Minute)
		}
	}

	logger.Info(t, fmt.Sprintf("Custom image status for  '%s' retrieved as available", customImageBuilderName))
	return nil
}
