package tests

import (
	"fmt"
	"os"
	"strconv"
	"strings"
	"testing"

	"github.com/stretchr/testify/require"
	"github.com/terraform-ibm-modules/ibmcloud-terratest-wrapper/testhelper"
	utils "github.com/terraform-ibm-modules/terraform-ibm-hpc/utilities"
)

// ValidateClusterConfiguration performs comprehensive validation on the cluster setup.
// It connects to various cluster components via SSH and verifies their configurations and functionality.
// This includes the following validations:
// - Management Node: Verifies the configuration of the management node, including failover and failback procedures.
// - Compute Nodes: Ensures proper configuration and SSH connectivity to compute nodes.
// - Login Node: Validates the configuration and SSH connectivity to the login node.
// - Dynamic Compute Nodes: Verifies the proper setup and functionality of dynamic compute nodes.
// Additionally, this function logs detailed information throughout the validation process.
// This function doesn't return any value but logs errors and validation steps during the process.
func ValidateClusterConfiguration(t *testing.T, options *testhelper.TestOptions, testLogger *utils.AggregatedLogger) {
	// Retrieve common cluster details from options
	expectedSolution := strings.ToLower(options.TerraformVars["solution"].(string))
	expectedClusterName, expectedReservationID, expectedMasterName := GetClusterInfo(options)

	expectedResourceGroup := options.TerraformVars["existing_resource_group"].(string)
	expectedKeyManagement := options.TerraformVars["key_management"].(string)
	expectedZone := options.TerraformVars["zones"].([]string)[0]
	expectedNumOfKeys := len(options.TerraformVars["compute_ssh_keys"].([]string))

	expectedDnsDomainName, ok := options.TerraformVars["dns_domain_name"].(map[string]string)["compute"]
	require.True(t, ok, "Key 'compute' does not exist in dns_domain_name map or dns_domain_name is not of type map[string]string")

	expectedHyperthreadingEnabled, err := strconv.ParseBool(options.TerraformVars["hyperthreading_enabled"].(string))
	require.NoError(t, err, "Error parsing hyperthreading_enabled: %v", err)

	// Set job commands based on solution type
	jobCommandLow, jobCommandMed := SetJobCommands(expectedSolution, expectedZone)

	// Run the test consistency check
	clusterCreationErr := ValidateClusterCreation(t, options, testLogger)
	if clusterCreationErr != nil {
		require.NoError(t, clusterCreationErr, "Cluster creation validation failed: %v")
	}

	// Retrieve server IPs (different logic for HPC vs LSF solutions)
	bastionIP, managementNodeIPList, loginNodeIP, staticWorkerNodeIPList, ipRetrievalError := GetClusterIPs(t, options, expectedSolution, testLogger)
	require.NoError(t, ipRetrievalError, "Error occurred while getting server IPs: %v", ipRetrievalError)

	// Log validation start
	testLogger.Info(t, t.Name()+" Validation started ......")

	// Connect to the master node via SSH and handle connection errors
	sshClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPList[0])
	require.NoError(t, connectionErr, "Failed to connect to the master via SSH")
	defer sshClient.Close()

	testLogger.Info(t, "SSH connection to the master successful")
	t.Log("Validation in progress. Please wait...")

	// Verify management node configuration
	VerifyManagementNodeConfig(t, sshClient, expectedClusterName, expectedMasterName, expectedReservationID, expectedHyperthreadingEnabled, managementNodeIPList, EXPECTED_LSF_VERSION, expectedSolution, testLogger)

	// Verify SSH key on management nodes
	VerifySSHKey(t, sshClient, bastionIP, LSF_PUBLIC_HOST_NAME, LSF_PRIVATE_HOST_NAME, "management", managementNodeIPList, expectedNumOfKeys, testLogger)

	// Verify LSF DNS on management nodes
	VerifyLSFDNS(t, sshClient, managementNodeIPList, expectedDnsDomainName, testLogger)

	// Perform failover and failback
	FailoverAndFailback(t, sshClient, jobCommandMed, testLogger)

	// Restart LSF daemon
	RestartLsfDaemon(t, sshClient, testLogger)

	// Reboot instance
	RebootInstance(t, sshClient, bastionIP, LSF_PUBLIC_HOST_NAME, LSF_PRIVATE_HOST_NAME, managementNodeIPList[0], testLogger)

	// Reconnect to the management node after reboot
	sshClient, connectionErr = utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPList[0])
	require.NoError(t, connectionErr, "Failed to reconnect to the master via SSH")
	defer sshClient.Close()

	// Wait for dynamic node disappearance and handle potential errors
	defer func() {
		if err := WaitForDynamicNodeDisappearance(t, sshClient, testLogger); err != nil {
			t.Errorf("Error in WaitForDynamicNodeDisappearance: %v", err)
		}
	}()

	// Run job
	VerifyJobs(t, sshClient, jobCommandLow, testLogger)

	// Get compute node IPs and handle errors
	computeNodeIPList, err := GetComputeNodeIPs(t, sshClient, testLogger, expectedSolution, staticWorkerNodeIPList)
	if err != nil {
		t.Fatalf("Failed to retrieve dynamic compute node IPs: %v", err)
	}

	// Verify compute node configuration
	VerifyComputeNodeConfig(t, sshClient, expectedHyperthreadingEnabled, computeNodeIPList, testLogger)

	// Verify SSH key on compute nodes
	VerifySSHKey(t, sshClient, bastionIP, LSF_PUBLIC_HOST_NAME, LSF_PRIVATE_HOST_NAME, "compute", computeNodeIPList, expectedNumOfKeys, testLogger)

	// Verify LSF DNS on compute nodes
	VerifyLSFDNS(t, sshClient, computeNodeIPList, expectedDnsDomainName, testLogger)

	// Verify SSH connectivity from login node and handle connection errors
	sshLoginNodeClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, loginNodeIP)
	require.NoError(t, connectionErr, "Failed to connect to the login node via SSH")
	defer sshLoginNodeClient.Close()

	// Verify login node configuration
	VerifyLoginNodeConfig(t, sshLoginNodeClient, expectedClusterName, expectedMasterName, expectedReservationID, expectedHyperthreadingEnabled, loginNodeIP, jobCommandLow, EXPECTED_LSF_VERSION, testLogger)

	// Verify SSH connectivity from login node
	VerifySSHConnectivityToNodesFromLogin(t, sshLoginNodeClient, managementNodeIPList, computeNodeIPList, testLogger)

	// Verify PTR records
	VerifyPTRRecordsForManagementAndLoginNodes(t, sshClient, LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPList, loginNodeIP, expectedDnsDomainName, testLogger)

	// Verify LSF DNS on login node
	VerifyLSFDNS(t, sshClient, []string{loginNodeIP}, expectedDnsDomainName, testLogger)

	// Verify file share encryption
	VerifyFileShareEncryption(t, sshClient, os.Getenv("TF_VAR_ibmcloud_api_key"), utils.GetRegion(expectedZone), expectedResourceGroup, expectedMasterName, expectedKeyManagement, managementNodeIPList, testLogger)

	// Log validation end
	testLogger.Info(t, t.Name()+" Validation ended")
}

// ValidateClusterConfigurationWithAPPCenter performs validation tasks on the cluster configuration
// with additional verification for an application center and noVNC configurations.
// It extends the validation performed by ValidateClusterConfiguration to include checks for these additional components.
// This function connects to various cluster components via SSH and verifies their configurations and functionality.
// It includes the following validations:
// - Management Node: Verifies the configuration of the management node, including failover and failback procedures.
// - Compute Nodes: Ensures proper configuration and SSH connectivity to compute nodes.
// - Login Node: Validates the configuration and SSH connectivity to the login node.
// - Dynamic Compute Nodes: Verifies the proper setup and functionality of dynamic compute nodes.
// - Application Center: Validates the configuration of the application center.
// - noVNC: Verifies the noVNC configuration.
// Additionally, this function logs detailed information throughout the validation process.
// This function doesn't return any value but logs errors and validation steps during the process.
func ValidateClusterConfigurationWithAPPCenter(t *testing.T, options *testhelper.TestOptions, testLogger *utils.AggregatedLogger) {
	// Retrieve common cluster details from options
	expectedSolution := strings.ToLower(options.TerraformVars["solution"].(string))
	expectedClusterName, expectedReservationID, expectedMasterName := GetClusterInfo(options)

	expectedResourceGroup := options.TerraformVars["existing_resource_group"].(string)
	expectedKeyManagement := options.TerraformVars["key_management"].(string)
	expectedZone := options.TerraformVars["zones"].([]string)[0]
	expectedNumOfKeys := len(options.TerraformVars["compute_ssh_keys"].([]string))

	expectedDnsDomainName, ok := options.TerraformVars["dns_domain_name"].(map[string]string)["compute"]
	require.True(t, ok, "Key 'compute' does not exist in dns_domain_name map or dns_domain_name is not of type map[string]string")

	expectedHyperthreadingEnabled, err := strconv.ParseBool(options.TerraformVars["hyperthreading_enabled"].(string))
	require.NoError(t, err, "Error parsing hyperthreading_enabled: %v", err)

	// Set job commands based on solution type
	jobCommandLow, jobCommandMed := SetJobCommands(expectedSolution, expectedZone)

	// Run the test consistency check
	clusterCreationErr := ValidateClusterCreation(t, options, testLogger)
	if clusterCreationErr != nil {
		require.NoError(t, clusterCreationErr, "Cluster creation validation failed: %v")
	}

	// Retrieve server IPs (different logic for HPC vs LSF solutions)
	bastionIP, managementNodeIPList, loginNodeIP, staticWorkerNodeIPList, ipRetrievalError := GetClusterIPs(t, options, expectedSolution, testLogger)
	require.NoError(t, ipRetrievalError, "Error occurred while getting server IPs: %v", ipRetrievalError)

	// Log validation start
	testLogger.Info(t, t.Name()+" Validation started ......")

	// Connect to the master node via SSH and handle connection errors
	sshClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPList[0])
	require.NoError(t, connectionErr, "Failed to connect to the master via SSH")
	defer sshClient.Close()

	testLogger.Info(t, "SSH connection to the master successful")
	t.Log("Validation in progress. Please wait...")

	// Verify management node configuration
	VerifyManagementNodeConfig(t, sshClient, expectedClusterName, expectedMasterName, expectedReservationID, expectedHyperthreadingEnabled, managementNodeIPList, EXPECTED_LSF_VERSION, expectedSolution, testLogger)

	// Verify application center configuration
	VerifyAPPCenterConfig(t, sshClient, testLogger)

	// Verify noVNC configuration
	VerifyNoVNCConfig(t, sshClient, testLogger)

	// Verify SSH key on management nodes
	VerifySSHKey(t, sshClient, bastionIP, LSF_PUBLIC_HOST_NAME, LSF_PRIVATE_HOST_NAME, "management", managementNodeIPList, expectedNumOfKeys, testLogger)

	// Verify LSF DNS on management nodes
	VerifyLSFDNS(t, sshClient, managementNodeIPList, expectedDnsDomainName, testLogger)

	// Perform failover and failback
	FailoverAndFailback(t, sshClient, jobCommandMed, testLogger)

	// Restart LSF daemon
	RestartLsfDaemon(t, sshClient, testLogger)

	// Reboot instance
	RebootInstance(t, sshClient, bastionIP, LSF_PUBLIC_HOST_NAME, LSF_PRIVATE_HOST_NAME, managementNodeIPList[0], testLogger)

	// Reconnect to the management node after reboot
	sshClient, connectionErr = utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPList[0])
	require.NoError(t, connectionErr, "Failed to reconnect to the master via SSH")
	defer sshClient.Close()

	// Wait for dynamic node disappearance and handle potential errors
	defer func() {
		if err := WaitForDynamicNodeDisappearance(t, sshClient, testLogger); err != nil {
			t.Errorf("Error in WaitForDynamicNodeDisappearance: %v", err)
		}
	}()

	// Run job
	VerifyJobs(t, sshClient, jobCommandLow, testLogger)

	// Get compute node IPs and handle errors
	computeNodeIPList, err := GetComputeNodeIPs(t, sshClient, testLogger, expectedSolution, staticWorkerNodeIPList)
	if err != nil {
		t.Fatalf("Failed to retrieve dynamic compute node IPs: %v", err)
	}

	// Verify compute node configuration
	VerifyComputeNodeConfig(t, sshClient, expectedHyperthreadingEnabled, computeNodeIPList, testLogger)

	// Verify SSH key on compute nodes
	VerifySSHKey(t, sshClient, bastionIP, LSF_PUBLIC_HOST_NAME, LSF_PRIVATE_HOST_NAME, "compute", computeNodeIPList, expectedNumOfKeys, testLogger)

	// Verify LSF DNS on compute nodes
	VerifyLSFDNS(t, sshClient, computeNodeIPList, expectedDnsDomainName, testLogger)

	// Verify SSH connectivity from login node and handle connection errors
	sshLoginNodeClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, loginNodeIP)
	require.NoError(t, connectionErr, "Failed to connect to the login node via SSH")
	defer sshLoginNodeClient.Close()

	// Verify login node configuration
	VerifyLoginNodeConfig(t, sshLoginNodeClient, expectedClusterName, expectedMasterName, expectedReservationID, expectedHyperthreadingEnabled, loginNodeIP, jobCommandLow, EXPECTED_LSF_VERSION, testLogger)

	// Verify SSH connectivity from login node
	VerifySSHConnectivityToNodesFromLogin(t, sshLoginNodeClient, managementNodeIPList, computeNodeIPList, testLogger)

	// Verify PTR records
	VerifyPTRRecordsForManagementAndLoginNodes(t, sshClient, LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPList, loginNodeIP, expectedDnsDomainName, testLogger)

	// Verify LSF DNS on login node
	VerifyLSFDNS(t, sshClient, []string{loginNodeIP}, expectedDnsDomainName, testLogger)

	// Verify file share encryption
	VerifyFileShareEncryption(t, sshClient, os.Getenv("TF_VAR_ibmcloud_api_key"), utils.GetRegion(expectedZone), expectedResourceGroup, expectedMasterName, expectedKeyManagement, managementNodeIPList, testLogger)

	// Log validation end
	testLogger.Info(t, t.Name()+" Validation ended")
}

// ValidateClusterConfigurationWithPACHA performs validation tasks on the cluster configuration
// with additional verification for an application center and noVNC configurations.
// It extends the validation performed by ValidateClusterConfiguration to include checks for these additional components.
// This function connects to various cluster components via SSH and verifies their configurations and functionality.
// It includes the following validations:
// - Management Node: Verifies the configuration of the management node, including failover and failback procedures.
// - Compute Nodes: Ensures proper configuration and SSH connectivity to compute nodes.
// - Login Node: Validates the configuration and SSH connectivity to the login node.
// - Dynamic Compute Nodes: Verifies the proper setup and functionality of dynamic compute nodes.
// - Application Center: Validates the configuration of the application center.
// - noVNC: Verifies the noVNC configuration.
// Additionally, this function logs detailed information throughout the validation process.
// This function doesn't return any value but logs errors and validation steps during the process.
func ValidateClusterConfigurationWithPACHA(t *testing.T, options *testhelper.TestOptions, testLogger *utils.AggregatedLogger) {
	// Retrieve common cluster details from options
	expectedSolution := strings.ToLower(options.TerraformVars["solution"].(string))
	expectedClusterName, expectedReservationID, expectedMasterName := GetClusterInfo(options)

	expectedResourceGroup := options.TerraformVars["existing_resource_group"].(string)
	expectedKeyManagement := options.TerraformVars["key_management"].(string)
	expectedZone := options.TerraformVars["zones"].([]string)[0]
	expectedNumOfKeys := len(options.TerraformVars["compute_ssh_keys"].([]string))

	expectedDnsDomainName, ok := options.TerraformVars["dns_domain_name"].(map[string]string)["compute"]
	require.True(t, ok, "Key 'compute' does not exist in dns_domain_name map or dns_domain_name is not of type map[string]string")

	expectedHyperthreadingEnabled, err := strconv.ParseBool(options.TerraformVars["hyperthreading_enabled"].(string))
	require.NoError(t, err, "Error parsing hyperthreading_enabled: %v", err)

	// Set job commands based on solution type
	jobCommandLow, jobCommandMed := SetJobCommands(expectedSolution, expectedZone)

	// Run the test consistency check
	output, err := options.RunTestConsistency()
	if err != nil {
		testLogger.Error(t, fmt.Sprintf("Error running consistency test: %v", err))
		require.NoError(t, err, "error running consistency test: %v", err)
	}

	// Ensure that the output is non-nil
	if output == nil {
		testLogger.Error(t, "Expected non-nil output, but got nil")
		require.NotNil(t, output, "expected non-nil output, but got nil")
	}

	outputErr := ValidateTerraformPACOutputs(t, options.LastTestTerraformOutputs, expectedDnsDomainName, testLogger)
	require.NoError(t, outputErr, "Error occurred while out server IPs: %v", outputErr)

	// Log success message
	testLogger.Info(t, t.Name()+" Cluster created successfully")

	// Retrieve server IPs (different logic for HPC vs LSF solutions)
	bastionIP, managementNodeIPList, loginNodeIP, staticWorkerNodeIPList, ipRetrievalError := GetClusterIPs(t, options, expectedSolution, testLogger)
	require.NoError(t, ipRetrievalError, "Error occurred while getting server IPs: %v", ipRetrievalError)

	// Log validation start
	testLogger.Info(t, t.Name()+" Validation started ......")

	// Connect to the master node via SSH and handle connection errors
	sshClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPList[0])
	require.NoError(t, connectionErr, "Failed to connect to the master via SSH")
	defer sshClient.Close()

	testLogger.Info(t, "SSH connection to the master successful")
	t.Log("Validation in progress. Please wait...")

	// Verify management node configuration
	VerifyManagementNodeConfig(t, sshClient, expectedClusterName, expectedMasterName, expectedReservationID, expectedHyperthreadingEnabled, managementNodeIPList, EXPECTED_LSF_VERSION, expectedSolution, testLogger)

	// Verify application center configuration
	VerifyAPPCenterConfig(t, sshClient, testLogger)

	// Verify PACHA configuration by validating the application center setup.
	ValidatePACHAOnManagementNodes(t, sshClient, expectedDnsDomainName, bastionIP, managementNodeIPList, testLogger)

	// Verify noVNC configuration
	VerifyNoVNCConfig(t, sshClient, testLogger)

	// Verify SSH key on management nodes
	VerifySSHKey(t, sshClient, bastionIP, LSF_PUBLIC_HOST_NAME, LSF_PRIVATE_HOST_NAME, "management", managementNodeIPList, expectedNumOfKeys, testLogger)

	// Verify LSF DNS on management nodes
	VerifyLSFDNS(t, sshClient, managementNodeIPList, expectedDnsDomainName, testLogger)

	// Perform failover and failback
	FailoverAndFailback(t, sshClient, jobCommandMed, testLogger)

	// Restart LSF daemon
	RestartLsfDaemon(t, sshClient, testLogger)

	// Reboot instance
	RebootInstance(t, sshClient, bastionIP, LSF_PUBLIC_HOST_NAME, LSF_PRIVATE_HOST_NAME, managementNodeIPList[0], testLogger)

	// Reconnect to the management node after reboot
	sshClient, connectionErr = utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPList[0])
	require.NoError(t, connectionErr, "Failed to reconnect to the master via SSH")
	defer sshClient.Close()

	// Wait for dynamic node disappearance and handle potential errors
	defer func() {
		if err := WaitForDynamicNodeDisappearance(t, sshClient, testLogger); err != nil {
			t.Errorf("Error in WaitForDynamicNodeDisappearance: %v", err)
		}
	}()

	// Verify PACHA configuration by validating the application center setup.
	ValidatePACHAOnManagementNodes(t, sshClient, expectedDnsDomainName, bastionIP, managementNodeIPList, testLogger)

	// Run job
	VerifyJobs(t, sshClient, jobCommandLow, testLogger)

	// Get compute node IPs and handle errors
	computeNodeIPList, err := GetComputeNodeIPs(t, sshClient, testLogger, expectedSolution, staticWorkerNodeIPList)
	if err != nil {
		t.Fatalf("Failed to retrieve dynamic compute node IPs: %v", err)
	}

	// Verify compute node configuration
	VerifyComputeNodeConfig(t, sshClient, expectedHyperthreadingEnabled, computeNodeIPList, testLogger)

	// Verify SSH key on compute nodes
	VerifySSHKey(t, sshClient, bastionIP, LSF_PUBLIC_HOST_NAME, LSF_PRIVATE_HOST_NAME, "compute", computeNodeIPList, expectedNumOfKeys, testLogger)

	// Verify LSF DNS on compute nodes
	VerifyLSFDNS(t, sshClient, computeNodeIPList, expectedDnsDomainName, testLogger)

	// Verify SSH connectivity from login node and handle connection errors
	sshLoginNodeClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, loginNodeIP)
	require.NoError(t, connectionErr, "Failed to connect to the login node via SSH")
	defer sshLoginNodeClient.Close()

	// Verify login node configuration
	VerifyLoginNodeConfig(t, sshLoginNodeClient, expectedClusterName, expectedMasterName, expectedReservationID, expectedHyperthreadingEnabled, loginNodeIP, jobCommandLow, EXPECTED_LSF_VERSION, testLogger)

	// Verify SSH connectivity from login node
	VerifySSHConnectivityToNodesFromLogin(t, sshLoginNodeClient, managementNodeIPList, computeNodeIPList, testLogger)

	// Verify PTR records
	VerifyPTRRecordsForManagementAndLoginNodes(t, sshClient, LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPList, loginNodeIP, expectedDnsDomainName, testLogger)

	// Verify LSF DNS on login node
	VerifyLSFDNS(t, sshClient, []string{loginNodeIP}, expectedDnsDomainName, testLogger)

	// Verify file share encryption
	VerifyFileShareEncryption(t, sshClient, os.Getenv("TF_VAR_ibmcloud_api_key"), utils.GetRegion(expectedZone), expectedResourceGroup, expectedMasterName, expectedKeyManagement, managementNodeIPList, testLogger)

	// Verify PACHA Failover configuration by validating the application center setup.
	ValidatePACHAFailoverHealthCheckOnManagementNodes(t, sshClient, expectedDnsDomainName, bastionIP, managementNodeIPList, testLogger)

	// Log validation end
	testLogger.Info(t, t.Name()+" Validation ended")
}

// ValidateBasicClusterConfiguration validates basic cluster configuration.
// It performs validation tasks on essential aspects of the cluster setup,
// including the management node, compute nodes, and login node configurations.
// Additionally, it ensures proper connectivity and functionality.
// This function doesn't return any value but logs errors and validation steps during the process.
func ValidateBasicClusterConfiguration(t *testing.T, options *testhelper.TestOptions, testLogger *utils.AggregatedLogger) {
	// Retrieve common cluster details from options
	expectedSolution := strings.ToLower(options.TerraformVars["solution"].(string))
	expectedClusterName, expectedReservationID, expectedMasterName := GetClusterInfo(options)

	expectedResourceGroup := options.TerraformVars["existing_resource_group"].(string)
	expectedKeyManagement := options.TerraformVars["key_management"].(string)
	expectedZone := options.TerraformVars["zones"].([]string)[0]

	expectedDnsDomainName, ok := options.TerraformVars["dns_domain_name"].(map[string]string)["compute"]
	require.True(t, ok, "Key 'compute' does not exist in dns_domain_name map or dns_domain_name is not of type map[string]string")

	expectedHyperthreadingEnabled, err := strconv.ParseBool(options.TerraformVars["hyperthreading_enabled"].(string))
	require.NoError(t, err, "Error parsing hyperthreading_enabled: %v", err)

	// Set job commands based on solution type
	jobCommandLow, _ := SetJobCommands(expectedSolution, expectedZone)

	// Run the test consistency check
	clusterCreationErr := ValidateClusterCreation(t, options, testLogger)
	if clusterCreationErr != nil {
		require.NoError(t, clusterCreationErr, "Cluster creation validation failed: %v")
	}

	// Retrieve server IPs (different logic for HPC vs LSF solutions)
	bastionIP, managementNodeIPList, loginNodeIP, staticWorkerNodeIPList, ipRetrievalError := GetClusterIPs(t, options, expectedSolution, testLogger)
	require.NoError(t, ipRetrievalError, "Error occurred while getting server IPs: %v", ipRetrievalError)

	// Log validation start
	testLogger.Info(t, t.Name()+" Validation started ......")

	// Connect to the master node via SSH and handle connection errors
	sshClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPList[0])
	require.NoError(t, connectionErr, "Failed to connect to the master via SSH")
	defer sshClient.Close()

	testLogger.Info(t, "SSH connection to the master successful")
	t.Log("Validation in progress. Please wait...")

	// Verify management node configuration
	VerifyManagementNodeConfig(t, sshClient, expectedClusterName, expectedMasterName, expectedReservationID, expectedHyperthreadingEnabled, managementNodeIPList, EXPECTED_LSF_VERSION, expectedSolution, testLogger)

	// Wait for dynamic node disappearance and handle potential errors
	defer func() {
		if err := WaitForDynamicNodeDisappearance(t, sshClient, testLogger); err != nil {
			t.Errorf("Error in WaitForDynamicNodeDisappearance: %v", err)
		}
	}()

	// Run job
	VerifyJobs(t, sshClient, jobCommandLow, testLogger)

	// Get compute node IPs and handle errors
	computeNodeIPList, err := GetComputeNodeIPs(t, sshClient, testLogger, expectedSolution, staticWorkerNodeIPList)
	if err != nil {
		t.Fatalf("Failed to retrieve dynamic compute node IPs: %v", err)
	}

	// Verify compute node configuration
	VerifyComputeNodeConfig(t, sshClient, expectedHyperthreadingEnabled, computeNodeIPList, testLogger)

	// Verify SSH connectivity from login node and handle connection errors
	sshLoginNodeClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, loginNodeIP)
	require.NoError(t, connectionErr, "Failed to connect to the login node via SSH")
	defer sshLoginNodeClient.Close()

	// Verify login node configuration
	VerifyLoginNodeConfig(t, sshLoginNodeClient, expectedClusterName, expectedMasterName, expectedReservationID, expectedHyperthreadingEnabled, loginNodeIP, jobCommandLow, EXPECTED_LSF_VERSION, testLogger)

	// Verify PTR records
	VerifyPTRRecordsForManagementAndLoginNodes(t, sshClient, LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPList, loginNodeIP, expectedDnsDomainName, testLogger)

	// Verify LSF DNS on login node
	VerifyLSFDNS(t, sshClient, []string{loginNodeIP}, expectedDnsDomainName, testLogger)

	// Verify file share encryption
	VerifyFileShareEncryption(t, sshClient, os.Getenv("TF_VAR_ibmcloud_api_key"), utils.GetRegion(expectedZone), expectedResourceGroup, expectedMasterName, expectedKeyManagement, managementNodeIPList, testLogger)

	// Log validation end
	testLogger.Info(t, t.Name()+" Validation ended")
}

// ValidateBasicClusterConfigurationWithDynamicProfile validates basic cluster configuration.
// It performs validation tasks on essential aspects of the cluster setup,
// including the management node, compute nodes, and login node configurations.
// Additionally, it ensures proper connectivity and functionality.
// The dynamic worker node profile should be created based on the first worker instance type object.
// This function doesn't return any value but logs errors and validation steps during the process.
func ValidateBasicClusterConfigurationWithDynamicProfile(t *testing.T, options *testhelper.TestOptions, testLogger *utils.AggregatedLogger) {
	// Retrieve common cluster details from options
	expectedSolution := strings.ToLower(options.TerraformVars["solution"].(string))
	expectedClusterName, expectedReservationID, expectedMasterName := GetClusterInfo(options)

	expectedResourceGroup := options.TerraformVars["existing_resource_group"].(string)
	expectedKeyManagement := options.TerraformVars["key_management"].(string)

	expectedZone := options.TerraformVars["zones"].([]string)[0]

	expectedDnsDomainName, ok := options.TerraformVars["dns_domain_name"].(map[string]string)["compute"]
	require.True(t, ok, "Key 'compute' does not exist in dns_domain_name map or dns_domain_name is not of type map[string]string")

	expectedHyperthreadingEnabled, err := strconv.ParseBool(options.TerraformVars["hyperthreading_enabled"].(string))
	require.NoError(t, err, "Error parsing hyperthreading_enabled: %v", err)

	// Set job commands based on solution type
	jobCommandLow, jobCommandMed := SetJobCommands(expectedSolution, expectedZone)

	// Run the test consistency check
	clusterCreationErr := ValidateClusterCreation(t, options, testLogger)
	if clusterCreationErr != nil {
		require.NoError(t, clusterCreationErr, "Cluster creation validation failed: %v")
	}

	// Retrieve server IPs (different logic for HPC vs LSF solutions)
	bastionIP, managementNodeIPList, loginNodeIP, staticWorkerNodeIPList, ipRetrievalError := GetClusterIPs(t, options, expectedSolution, testLogger)
	require.NoError(t, ipRetrievalError, "Error occurred while getting server IPs: %v", ipRetrievalError)

	// Log validation start
	testLogger.Info(t, t.Name()+" Validation started ......")

	// Connect to the master node via SSH and handle connection errors
	sshClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPList[0])
	require.NoError(t, connectionErr, "Failed to connect to the master via SSH")
	defer sshClient.Close()

	testLogger.Info(t, "SSH connection to the master successful")
	t.Log("Validation in progress. Please wait...")

	// Verify management node configuration
	VerifyManagementNodeConfig(t, sshClient, expectedClusterName, expectedMasterName, expectedReservationID, expectedHyperthreadingEnabled, managementNodeIPList, EXPECTED_LSF_VERSION, expectedSolution, testLogger)

	// Wait for dynamic node disappearance and handle potential errors
	defer func() {
		if err := WaitForDynamicNodeDisappearance(t, sshClient, testLogger); err != nil {
			t.Errorf("Error in WaitForDynamicNodeDisappearance: %v", err)
		}
	}()

	// Run job
	VerifyJobs(t, sshClient, jobCommandMed, testLogger)

	// Verify dynamic node profile
	ValidateDynamicNodeProfile(t, os.Getenv("TF_VAR_ibmcloud_api_key"), utils.GetRegion(expectedZone), expectedResourceGroup, expectedMasterName, options, testLogger)

	// Get compute node IPs and handle errors
	computeNodeIPList, err := GetComputeNodeIPs(t, sshClient, testLogger, expectedSolution, staticWorkerNodeIPList)
	if err != nil {
		t.Fatalf("Failed to retrieve dynamic compute node IPs: %v", err)
	}

	// Verify compute node configuration
	VerifyComputeNodeConfig(t, sshClient, expectedHyperthreadingEnabled, computeNodeIPList, testLogger)

	// Verify SSH connectivity from login node and handle connection errors
	sshLoginNodeClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, loginNodeIP)
	require.NoError(t, connectionErr, "Failed to connect to the login node via SSH")
	defer sshLoginNodeClient.Close()

	// Verify login node configuration
	VerifyLoginNodeConfig(t, sshLoginNodeClient, expectedClusterName, expectedMasterName, expectedReservationID, expectedHyperthreadingEnabled, loginNodeIP, jobCommandLow, EXPECTED_LSF_VERSION, testLogger)

	// Verify PTR records
	VerifyPTRRecordsForManagementAndLoginNodes(t, sshClient, LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPList, loginNodeIP, expectedDnsDomainName, testLogger)

	// Verify LSF DNS on login node
	VerifyLSFDNS(t, sshClient, []string{loginNodeIP}, expectedDnsDomainName, testLogger)

	// Verify file share encryption
	VerifyFileShareEncryption(t, sshClient, os.Getenv("TF_VAR_ibmcloud_api_key"), utils.GetRegion(expectedZone), expectedResourceGroup, expectedMasterName, expectedKeyManagement, managementNodeIPList, testLogger)

	// Log validation end
	testLogger.Info(t, t.Name()+" Validation ended")
}

// ValidateLDAPClusterConfiguration performs comprehensive validation on the cluster setup.
// It connects to various cluster components via SSH and verifies their configurations and functionality.
// This includes validations for management nodes, compute nodes, login nodes, dynamic compute nodes, and LDAP integration.
// Additionally, this function logs detailed information throughout the validation process.
// This function doesn't return any value but logs errors and validation steps during the process.
func ValidateLDAPClusterConfiguration(t *testing.T, options *testhelper.TestOptions, testLogger *utils.AggregatedLogger) {
	// Retrieve common cluster details from options
	expectedSolution := strings.ToLower(options.TerraformVars["solution"].(string))
	expectedClusterName, expectedReservationID, expectedMasterName := GetClusterInfo(options)
	expectedLdapDomain, ldapAdminPassword, ldapUserName, ldapUserPassword := GetLDAPServerCredentialsInfo(options)
	expectedResourceGroup := options.TerraformVars["existing_resource_group"].(string)
	expectedKeyManagement := options.TerraformVars["key_management"].(string)
	expectedZone := options.TerraformVars["zones"].([]string)[0]
	expectedNumOfKeys := len(options.TerraformVars["compute_ssh_keys"].([]string))

	expectedDnsDomainName, ok := options.TerraformVars["dns_domain_name"].(map[string]string)["compute"]
	require.True(t, ok, "Key 'compute' does not exist in dns_domain_name map or dns_domain_name is not of type map[string]string")

	expectedHyperthreadingEnabled, err := strconv.ParseBool(options.TerraformVars["hyperthreading_enabled"].(string))
	require.NoError(t, err, "Error parsing hyperthreading_enabled: %v", err)

	// Set job commands based on solution type
	jobCommandLow, jobCommandMed := SetJobCommands(expectedSolution, expectedZone)

	// Run the test consistency check
	clusterCreationErr := ValidateClusterCreation(t, options, testLogger)
	if clusterCreationErr != nil {
		require.NoError(t, clusterCreationErr, "Cluster creation validation failed: %v")
	}

	// Retrieve server IPs (different logic for HPC vs LSF solutions)
	bastionIP, managementNodeIPList, loginNodeIP, staticWorkerNodeIPList, ldapServerIP, ipRetrievalError := GetClusterIPsWithLDAP(t, options, expectedSolution, testLogger)
	require.NoError(t, ipRetrievalError, "Error occurred while getting server IPs: %v", ipRetrievalError)

	// Log validation start
	testLogger.Info(t, t.Name()+" Validation started ......")

	// Connect to the master node via SSH and handle connection errors
	sshClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPList[0])
	require.NoError(t, connectionErr, "Failed to connect to the master via SSH")
	defer sshClient.Close()

	testLogger.Info(t, "SSH connection to the master successful")
	t.Log("Validation in progress. Please wait...")

	// Verify management node configuration
	VerifyManagementNodeConfig(t, sshClient, expectedClusterName, expectedMasterName, expectedReservationID, expectedHyperthreadingEnabled, managementNodeIPList, EXPECTED_LSF_VERSION, expectedSolution, testLogger)

	// Verify SSH key on management nodes
	VerifySSHKey(t, sshClient, bastionIP, LSF_PUBLIC_HOST_NAME, LSF_PRIVATE_HOST_NAME, "management", managementNodeIPList, expectedNumOfKeys, testLogger)

	// Verify LSF DNS on management nodes
	VerifyLSFDNS(t, sshClient, managementNodeIPList, expectedDnsDomainName, testLogger)

	// Perform failover and failback
	FailoverAndFailback(t, sshClient, jobCommandMed, testLogger)

	// Restart LSF daemon
	RestartLsfDaemon(t, sshClient, testLogger)

	// Reboot instance
	RebootInstance(t, sshClient, bastionIP, LSF_PUBLIC_HOST_NAME, LSF_PRIVATE_HOST_NAME, managementNodeIPList[0], testLogger)

	// Reconnect to the management node after reboot
	sshClient, connectionErr = utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPList[0])
	require.NoError(t, connectionErr, "Failed to reconnect to the master via SSH")
	defer sshClient.Close()

	// Wait for dynamic node disappearance and handle potential errors
	defer func() {
		if err := WaitForDynamicNodeDisappearance(t, sshClient, testLogger); err != nil {
			t.Errorf("Error in WaitForDynamicNodeDisappearance: %v", err)
		}
	}()

	// Run job
	VerifyJobs(t, sshClient, jobCommandLow, testLogger)

	// Get compute node IPs and handle errors
	computeNodeIPList, err := GetComputeNodeIPs(t, sshClient, testLogger, expectedSolution, staticWorkerNodeIPList)
	if err != nil {
		t.Fatalf("Failed to retrieve dynamic compute node IPs: %v", err)
	}

	// Verify compute node configuration
	VerifyComputeNodeConfig(t, sshClient, expectedHyperthreadingEnabled, computeNodeIPList, testLogger)

	// Verify SSH key on compute nodes
	VerifySSHKey(t, sshClient, bastionIP, LSF_PUBLIC_HOST_NAME, LSF_PRIVATE_HOST_NAME, "compute", computeNodeIPList, expectedNumOfKeys, testLogger)

	// Verify LSF DNS on compute nodes
	VerifyLSFDNS(t, sshClient, computeNodeIPList, expectedDnsDomainName, testLogger)

	// Verify SSH connectivity from login node and handle connection errors
	sshLoginNodeClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, loginNodeIP)
	require.NoError(t, connectionErr, "Failed to connect to the login node via SSH")
	defer sshLoginNodeClient.Close()

	// Verify login node configuration
	VerifyLoginNodeConfig(t, sshLoginNodeClient, expectedClusterName, expectedMasterName, expectedReservationID, expectedHyperthreadingEnabled, loginNodeIP, jobCommandLow, EXPECTED_LSF_VERSION, testLogger)

	// Verify SSH connectivity from login node
	VerifySSHConnectivityToNodesFromLogin(t, sshLoginNodeClient, managementNodeIPList, computeNodeIPList, testLogger)

	// Verify file share encryption
	VerifyFileShareEncryption(t, sshClient, os.Getenv("TF_VAR_ibmcloud_api_key"), utils.GetRegion(expectedZone), expectedResourceGroup, expectedMasterName, expectedKeyManagement, managementNodeIPList, testLogger)

	// Connect to the LDAP server via SSH and handle connection errors
	sshLdapClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_LDAP_HOST_NAME, ldapServerIP)
	require.NoError(t, connectionErr, "Failed to connect to the LDAP server via SSH")
	defer sshLdapClient.Close()

	// Check LDAP server status
	CheckLDAPServerStatus(t, sshLdapClient, ldapAdminPassword, expectedLdapDomain, ldapUserName, testLogger)

	// Verify management node LDAP config
	VerifyManagementNodeLDAPConfig(t, sshClient, bastionIP, ldapServerIP, managementNodeIPList, jobCommandLow, expectedLdapDomain, ldapUserName, ldapUserPassword, testLogger)

	// Verify compute node LDAP config
	VerifyComputeNodeLDAPConfig(t, bastionIP, ldapServerIP, computeNodeIPList, expectedLdapDomain, ldapUserName, ldapUserPassword, testLogger)

	// Verify login node LDAP config
	VerifyLoginNodeLDAPConfig(t, sshLoginNodeClient, bastionIP, loginNodeIP, ldapServerIP, jobCommandLow, expectedLdapDomain, ldapUserName, ldapUserPassword, testLogger)

	// Verify ability to create LDAP user and perform LSF actions using new user
	VerifyCreateNewLdapUserAndManagementNodeLDAPConfig(t, sshLdapClient, bastionIP, ldapServerIP, managementNodeIPList, jobCommandLow, ldapAdminPassword, expectedLdapDomain, ldapUserName, ldapUserPassword, "tester2", testLogger)

	// Verify PTR records
	VerifyPTRRecordsForManagementAndLoginNodes(t, sshClient, LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPList, loginNodeIP, expectedDnsDomainName, testLogger)

	// Log validation end
	testLogger.Info(t, t.Name()+" Validation ended")
}

// ValidatePACANDLDAPClusterConfiguration performs comprehensive validation on the PAC and LDAP cluster setup.
// It connects to various cluster components via SSH and verifies their configurations and functionality.
// This includes validations for management nodes, compute nodes, login nodes, dynamic compute nodes, LDAP server, application center, and noVNC.
// Additionally, this function logs detailed information throughout the validation process.
// This function doesn't return any value but logs errors and validation steps during the process.
func ValidatePACANDLDAPClusterConfiguration(t *testing.T, options *testhelper.TestOptions, testLogger *utils.AggregatedLogger) {
	// Retrieve common cluster details from options
	expectedSolution := strings.ToLower(options.TerraformVars["solution"].(string))
	expectedClusterName, expectedReservationID, expectedMasterName := GetClusterInfo(options)
	expectedLdapDomain, ldapAdminPassword, ldapUserName, ldapUserPassword := GetLDAPServerCredentialsInfo(options)
	expectedResourceGroup := options.TerraformVars["existing_resource_group"].(string)
	expectedKeyManagement := options.TerraformVars["key_management"].(string)
	expectedZone := options.TerraformVars["zones"].([]string)[0]
	expectedNumOfKeys := len(options.TerraformVars["compute_ssh_keys"].([]string))

	expectedDnsDomainName, ok := options.TerraformVars["dns_domain_name"].(map[string]string)["compute"]
	require.True(t, ok, "Key 'compute' does not exist in dns_domain_name map or dns_domain_name is not of type map[string]string")

	expectedHyperthreadingEnabled, err := strconv.ParseBool(options.TerraformVars["hyperthreading_enabled"].(string))
	require.NoError(t, err, "Error parsing hyperthreading_enabled: %v", err)

	// Set job commands based on solution type
	jobCommandLow, jobCommandMed := SetJobCommands(expectedSolution, expectedZone)

	// Run the test consistency check
	clusterCreationErr := ValidateClusterCreation(t, options, testLogger)
	if clusterCreationErr != nil {
		require.NoError(t, clusterCreationErr, "Cluster creation validation failed: %v")
	}

	// Retrieve server IPs (different logic for HPC vs LSF solutions)
	bastionIP, managementNodeIPList, loginNodeIP, staticWorkerNodeIPList, ldapServerIP, ipRetrievalError := GetClusterIPsWithLDAP(t, options, expectedSolution, testLogger)
	require.NoError(t, ipRetrievalError, "Error occurred while getting server IPs: %v", ipRetrievalError)

	// Log validation start
	testLogger.Info(t, t.Name()+" Validation started ......")

	// Connect to the master node via SSH and handle connection errors
	sshClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPList[0])
	require.NoError(t, connectionErr, "Failed to connect to the master via SSH")
	defer sshClient.Close()

	testLogger.Info(t, "SSH connection to the master successful")
	t.Log("Validation in progress. Please wait...")

	// Verify management node configuration
	VerifyManagementNodeConfig(t, sshClient, expectedClusterName, expectedMasterName, expectedReservationID, expectedHyperthreadingEnabled, managementNodeIPList, EXPECTED_LSF_VERSION, expectedSolution, testLogger)

	// Verify application center configuration
	VerifyAPPCenterConfig(t, sshClient, testLogger)

	// Verify noVNC configuration
	VerifyNoVNCConfig(t, sshClient, testLogger)

	// Verify SSH key on management nodes
	VerifySSHKey(t, sshClient, bastionIP, LSF_PUBLIC_HOST_NAME, LSF_PRIVATE_HOST_NAME, "management", managementNodeIPList, expectedNumOfKeys, testLogger)

	// Verify LSF DNS on management nodes
	VerifyLSFDNS(t, sshClient, managementNodeIPList, expectedDnsDomainName, testLogger)

	// Perform failover and failback
	FailoverAndFailback(t, sshClient, jobCommandMed, testLogger)

	// Restart LSF daemon
	RestartLsfDaemon(t, sshClient, testLogger)

	// Reboot instance
	RebootInstance(t, sshClient, bastionIP, LSF_PUBLIC_HOST_NAME, LSF_PRIVATE_HOST_NAME, managementNodeIPList[0], testLogger)

	// Reconnect to the management node after reboot
	sshClient, connectionErr = utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPList[0])
	require.NoError(t, connectionErr, "Failed to reconnect to the master via SSH")
	defer sshClient.Close()

	// Wait for dynamic node disappearance and handle potential errors
	defer func() {
		if err := WaitForDynamicNodeDisappearance(t, sshClient, testLogger); err != nil {
			t.Errorf("Error in WaitForDynamicNodeDisappearance: %v", err)
		}
	}()

	// Run job
	VerifyJobs(t, sshClient, jobCommandLow, testLogger)

	// Get compute node IPs and handle errors
	computeNodeIPList, err := GetComputeNodeIPs(t, sshClient, testLogger, expectedSolution, staticWorkerNodeIPList)
	if err != nil {
		t.Fatalf("Failed to retrieve dynamic compute node IPs: %v", err)
	}

	// Verify compute node configuration
	VerifyComputeNodeConfig(t, sshClient, expectedHyperthreadingEnabled, computeNodeIPList, testLogger)

	// Verify SSH key on compute nodes
	VerifySSHKey(t, sshClient, bastionIP, LSF_PUBLIC_HOST_NAME, LSF_PRIVATE_HOST_NAME, "compute", computeNodeIPList, expectedNumOfKeys, testLogger)

	// Verify LSF DNS on compute nodes
	VerifyLSFDNS(t, sshClient, computeNodeIPList, expectedDnsDomainName, testLogger)

	// Verify SSH connectivity from login node and handle connection errors
	sshLoginNodeClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, loginNodeIP)
	require.NoError(t, connectionErr, "Failed to connect to the login node via SSH")
	defer sshLoginNodeClient.Close()

	// Verify login node configuration
	VerifyLoginNodeConfig(t, sshLoginNodeClient, expectedClusterName, expectedMasterName, expectedReservationID, expectedHyperthreadingEnabled, loginNodeIP, jobCommandLow, EXPECTED_LSF_VERSION, testLogger)

	// Verify SSH connectivity from login node
	VerifySSHConnectivityToNodesFromLogin(t, sshLoginNodeClient, managementNodeIPList, computeNodeIPList, testLogger)

	// Verify file share encryption
	VerifyFileShareEncryption(t, sshClient, os.Getenv("TF_VAR_ibmcloud_api_key"), utils.GetRegion(expectedZone), expectedResourceGroup, expectedMasterName, expectedKeyManagement, managementNodeIPList, testLogger)

	// Connect to the LDAP server via SSH and handle connection errors
	sshLdapClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_LDAP_HOST_NAME, ldapServerIP)
	require.NoError(t, connectionErr, "Failed to connect to the LDAP server via SSH")
	defer sshLdapClient.Close()

	// Check LDAP server status
	CheckLDAPServerStatus(t, sshLdapClient, ldapAdminPassword, expectedLdapDomain, ldapUserName, testLogger)

	// Verify management node LDAP config
	VerifyManagementNodeLDAPConfig(t, sshClient, bastionIP, ldapServerIP, managementNodeIPList, jobCommandLow, expectedLdapDomain, ldapUserName, ldapUserPassword, testLogger)

	// Verify compute node LDAP config
	VerifyComputeNodeLDAPConfig(t, bastionIP, ldapServerIP, computeNodeIPList, expectedLdapDomain, ldapUserName, ldapUserPassword, testLogger)

	// Verify login node LDAP config
	VerifyLoginNodeLDAPConfig(t, sshLoginNodeClient, bastionIP, loginNodeIP, ldapServerIP, jobCommandLow, expectedLdapDomain, ldapUserName, ldapUserPassword, testLogger)

	// Verify ability to create LDAP user and perform LSF actions using new user
	VerifyCreateNewLdapUserAndManagementNodeLDAPConfig(t, sshLdapClient, bastionIP, ldapServerIP, managementNodeIPList, jobCommandLow, ldapAdminPassword, expectedLdapDomain, ldapUserName, ldapUserPassword, "tester2", testLogger)

	// Verify PTR records
	VerifyPTRRecordsForManagementAndLoginNodes(t, sshClient, LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPList, loginNodeIP, expectedDnsDomainName, testLogger)

	// Log validation end
	testLogger.Info(t, t.Name()+" Validation ended")
}

// ValidateBasicClusterConfigurationWithVPCFlowLogsAndCos validates the basic cluster configuration
// including VPC flow logs and COS service instance.
// It performs validation tasks on essential aspects of the cluster setup,
// such as management node, compute nodes, and login node configurations.
// Additionally, it ensures proper connectivity and functionality.
// This function doesn't return any value but logs errors and validation steps during the process.
func ValidateBasicClusterConfigurationWithVPCFlowLogsAndCos(t *testing.T, options *testhelper.TestOptions, testLogger *utils.AggregatedLogger) {
	// Retrieve common cluster details from options
	expectedSolution := strings.ToLower(options.TerraformVars["solution"].(string))
	expectedClusterName, expectedReservationID, expectedMasterName := GetClusterInfo(options)

	expectedResourceGroup := options.TerraformVars["existing_resource_group"].(string)
	expectedKeyManagement := options.TerraformVars["key_management"].(string)
	expectedZone := options.TerraformVars["zones"].([]string)[0]

	expectedDnsDomainName, ok := options.TerraformVars["dns_domain_name"].(map[string]string)["compute"]
	require.True(t, ok, "Key 'compute' does not exist in dns_domain_name map or dns_domain_name is not of type map[string]string")

	expectedHyperthreadingEnabled, err := strconv.ParseBool(options.TerraformVars["hyperthreading_enabled"].(string))
	require.NoError(t, err, "Error parsing hyperthreading_enabled: %v", err)

	// Set job commands based on solution type
	jobCommandLow, _ := SetJobCommands(expectedSolution, expectedZone)

	// Run the test consistency check
	clusterCreationErr := ValidateClusterCreation(t, options, testLogger)
	if clusterCreationErr != nil {
		require.NoError(t, clusterCreationErr, "Cluster creation validation failed: %v")
	}

	// Retrieve server IPs (different logic for HPC vs LSF solutions)
	bastionIP, managementNodeIPList, loginNodeIP, staticWorkerNodeIPList, ipRetrievalError := GetClusterIPs(t, options, expectedSolution, testLogger)
	require.NoError(t, ipRetrievalError, "Error occurred while getting server IPs: %v", ipRetrievalError)

	//
	fmt.Println(loginNodeIP, expectedDnsDomainName)
	// Log validation start
	testLogger.Info(t, t.Name()+" Validation started ......")

	// Connect to the master node via SSH and handle connection errors
	sshClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPList[0])
	require.NoError(t, connectionErr, "Failed to connect to the master via SSH")
	defer sshClient.Close()

	testLogger.Info(t, "SSH connection to the master successful")
	t.Log("Validation in progress. Please wait...")

	// Verify management node configuration
	VerifyManagementNodeConfig(t, sshClient, expectedClusterName, expectedMasterName, expectedReservationID, expectedHyperthreadingEnabled, managementNodeIPList, EXPECTED_LSF_VERSION, expectedSolution, testLogger)

	// Wait for dynamic node disappearance and handle potential errors
	defer func() {
		if err := WaitForDynamicNodeDisappearance(t, sshClient, testLogger); err != nil {
			t.Errorf("Error in WaitForDynamicNodeDisappearance: %v", err)
		}
	}()

	// Run job
	VerifyJobs(t, sshClient, jobCommandLow, testLogger)

	// Get compute node IPs and handle errors
	computeNodeIPList, err := GetComputeNodeIPs(t, sshClient, testLogger, expectedSolution, staticWorkerNodeIPList)
	if err != nil {
		t.Fatalf("Failed to retrieve dynamic compute node IPs: %v", err)
	}

	// Verify compute node configuration
	VerifyComputeNodeConfig(t, sshClient, expectedHyperthreadingEnabled, computeNodeIPList, testLogger)

	// Verify SSH connectivity from login node and handle connection errors
	sshLoginNodeClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, loginNodeIP)
	require.NoError(t, connectionErr, "Failed to connect to the login node via SSH")
	defer sshLoginNodeClient.Close()

	// Verify login node configuration
	VerifyLoginNodeConfig(t, sshLoginNodeClient, expectedClusterName, expectedMasterName, expectedReservationID, expectedHyperthreadingEnabled, loginNodeIP, jobCommandLow, EXPECTED_LSF_VERSION, testLogger)

	// Verify PTR records
	VerifyPTRRecordsForManagementAndLoginNodes(t, sshClient, LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPList, loginNodeIP, expectedDnsDomainName, testLogger)

	// Verify LSF DNS on login node
	VerifyLSFDNS(t, sshClient, []string{loginNodeIP}, expectedDnsDomainName, testLogger)

	// Verify file share encryption
	VerifyFileShareEncryption(t, sshClient, os.Getenv("TF_VAR_ibmcloud_api_key"), utils.GetRegion(expectedZone), expectedResourceGroup, expectedMasterName, expectedKeyManagement, managementNodeIPList, testLogger)

	// Validate COS service instance and VPC flow logs
	ValidateCosServiceInstanceAndVpcFlowLogs(t, os.Getenv("TF_VAR_ibmcloud_api_key"), utils.GetRegion(expectedZone), expectedResourceGroup, expectedMasterName, testLogger)

	// Log validation end
	testLogger.Info(t, t.Name()+" Validation ended")
}

// ValidateClusterConfigurationWithMultipleKeys performs a comprehensive validation on the cluster setup.
// It connects to various cluster components via SSH and verifies their configurations and functionality,
// including management nodes, compute nodes, login nodes, and dynamic compute nodes. It also performs
// additional validation checks like failover procedures, SSH key verification, and DNS verification.
// The function logs detailed information throughout the validation process but does not return any value.
func ValidateClusterConfigurationWithMultipleKeys(t *testing.T, options *testhelper.TestOptions, testLogger *utils.AggregatedLogger) {
	// Retrieve common cluster details from options
	expectedSolution := strings.ToLower(options.TerraformVars["solution"].(string))
	expectedClusterName, expectedReservationID, expectedMasterName := GetClusterInfo(options)

	expectedResourceGroup := options.TerraformVars["existing_resource_group"].(string)
	expectedKeyManagement := options.TerraformVars["key_management"].(string)
	expectedZone := options.TerraformVars["zones"].([]string)[0]
	expectedNumOfKeys := len(options.TerraformVars["compute_ssh_keys"].([]string))

	expectedDnsDomainName, ok := options.TerraformVars["dns_domain_name"].(map[string]string)["compute"]
	require.True(t, ok, "Key 'compute' does not exist in dns_domain_name map or dns_domain_name is not of type map[string]string")

	expectedHyperthreadingEnabled, err := strconv.ParseBool(options.TerraformVars["hyperthreading_enabled"].(string))
	require.NoError(t, err, "Error parsing hyperthreading_enabled: %v", err)

	// Set job commands based on solution type
	jobCommandLow, jobCommandMed := SetJobCommands(expectedSolution, expectedZone)

	// Run the test consistency check
	clusterCreationErr := ValidateClusterCreation(t, options, testLogger)
	if clusterCreationErr != nil {
		require.NoError(t, clusterCreationErr, "Cluster creation validation failed: %v")
	}

	// Retrieve server IPs (different logic for HPC vs LSF solutions)
	bastionIP, managementNodeIPList, loginNodeIP, staticWorkerNodeIPList, ipRetrievalError := GetClusterIPs(t, options, expectedSolution, testLogger)
	require.NoError(t, ipRetrievalError, "Error occurred while getting server IPs: %v", ipRetrievalError)

	// Log validation start
	testLogger.Info(t, t.Name()+" Validation started ......")

	// Connect to the management node via SSH
	sshClientOne, sshClientTwo, connectionErrOne, connectionErrTwo := utils.ConnectToHostsWithMultipleUsers(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPList[0])
	require.NoError(t, connectionErrOne, "Failed to connect to the master via SSH")
	require.NoError(t, connectionErrTwo, "Failed to connect to the master via SSH")
	defer sshClientOne.Close()
	defer sshClientTwo.Close()

	testLogger.Info(t, "SSH connection to the master successful")
	t.Log("Validation in progress. Please wait...")

	// Verify management node configuration
	VerifyManagementNodeConfig(t, sshClientOne, expectedClusterName, expectedMasterName, expectedReservationID, expectedHyperthreadingEnabled, managementNodeIPList, EXPECTED_LSF_VERSION, expectedSolution, testLogger)
	VerifyManagementNodeConfig(t, sshClientTwo, expectedClusterName, expectedMasterName, expectedReservationID, expectedHyperthreadingEnabled, managementNodeIPList, EXPECTED_LSF_VERSION, expectedSolution, testLogger)

	// Verify SSH key on management node
	VerifySSHKey(t, sshClientOne, bastionIP, LSF_PUBLIC_HOST_NAME, LSF_PRIVATE_HOST_NAME, "management", managementNodeIPList, expectedNumOfKeys, testLogger)

	// Perform failover and failback
	FailoverAndFailback(t, sshClientOne, jobCommandMed, testLogger)

	// Restart LSF daemon
	RestartLsfDaemon(t, sshClientOne, testLogger)

	// Reboot instance
	RebootInstance(t, sshClientOne, bastionIP, LSF_PUBLIC_HOST_NAME, LSF_PRIVATE_HOST_NAME, managementNodeIPList[0], testLogger)

	// Reconnect to the management node after reboot
	sshClientOne, connectionErrOne = utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPList[0])
	require.NoError(t, connectionErrOne, "Failed to reconnect to the master via SSH: %v", connectionErrOne)
	defer sshClientOne.Close()

	// Wait for dynamic node disappearance and handle potential errors
	defer func() {
		if err := WaitForDynamicNodeDisappearance(t, sshClientOne, testLogger); err != nil {
			t.Errorf("Error in WaitForDynamicNodeDisappearance: %v", err)
		}
	}()

	// Run job
	VerifyJobs(t, sshClientOne, jobCommandLow, testLogger)

	// Get compute node IPs and handle errors
	computeNodeIPList, err := GetComputeNodeIPs(t, sshClientOne, testLogger, expectedSolution, staticWorkerNodeIPList)
	if err != nil {
		t.Fatalf("Failed to retrieve dynamic compute node IPs: %v", err)
	}

	// Verify compute node configuration
	VerifyComputeNodeConfig(t, sshClientOne, expectedHyperthreadingEnabled, computeNodeIPList, testLogger)

	// Verify SSH key on compute nodes
	VerifySSHKey(t, sshClientOne, bastionIP, LSF_PUBLIC_HOST_NAME, LSF_PRIVATE_HOST_NAME, "compute", computeNodeIPList, expectedNumOfKeys, testLogger)

	// Verify LSF DNS on compute nodes
	VerifyLSFDNS(t, sshClientOne, computeNodeIPList, expectedDnsDomainName, testLogger)

	// Verify SSH connectivity from login node
	sshLoginNodeClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, loginNodeIP)
	require.NoError(t, connectionErr, "Failed to connect to the login node via SSH")
	defer sshLoginNodeClient.Close()

	// Verify login node configuration
	VerifyLoginNodeConfig(t, sshLoginNodeClient, expectedClusterName, expectedMasterName, expectedReservationID, expectedHyperthreadingEnabled, loginNodeIP, jobCommandLow, EXPECTED_LSF_VERSION, testLogger)

	// Get compute node IPs and handle errors
	computeNodeIPList, err = GetComputeNodeIPs(t, sshClientOne, testLogger, expectedSolution, staticWorkerNodeIPList)
	if err != nil {
		t.Fatalf("Failed to retrieve dynamic compute node IPs: %v", err)
	}

	// Verify SSH connectivity from login node
	VerifySSHConnectivityToNodesFromLogin(t, sshLoginNodeClient, managementNodeIPList, computeNodeIPList, testLogger)

	// Verify LSF DNS on login node
	VerifyLSFDNS(t, sshClientOne, []string{loginNodeIP}, expectedDnsDomainName, testLogger)

	// Verify file share encryption
	VerifyFileShareEncryption(t, sshClientOne, os.Getenv("TF_VAR_ibmcloud_api_key"), utils.GetRegion(expectedZone), expectedResourceGroup, expectedMasterName, expectedKeyManagement, managementNodeIPList, testLogger)

	// Log validation end
	testLogger.Info(t, t.Name()+" Validation ended")
}

// ValidateExistingLDAPClusterConfig performs comprehensive validation on an existing LDAP cluster configuration.
// It connects to various cluster components via SSH to verify their configurations and functionality,
// including management nodes, compute nodes, login nodes, dynamic compute nodes, and LDAP integration.
// This function logs detailed information throughout the validation process and does not return any value.
func ValidateExistingLDAPClusterConfig(t *testing.T, ldapServerBastionIP, ldapServerIP, expectedLdapDomain, ldapAdminPassword, ldapUserName, ldapUserPassword string, options *testhelper.TestOptions, testLogger *utils.AggregatedLogger) {

	// Retrieve common cluster details from options
	expectedSolution := strings.ToLower(options.TerraformVars["solution"].(string))
	expectedClusterName, expectedReservationID, expectedMasterName := GetClusterInfo(options)

	expectedResourceGroup := options.TerraformVars["existing_resource_group"].(string)
	expectedKeyManagement := options.TerraformVars["key_management"].(string)
	expectedZone := options.TerraformVars["zones"].([]string)[0]
	expectedNumOfKeys := len(options.TerraformVars["compute_ssh_keys"].([]string))

	expectedDnsDomainName, ok := options.TerraformVars["dns_domain_name"].(map[string]string)["compute"]
	require.True(t, ok, "Key 'compute' does not exist in dns_domain_name map or dns_domain_name is not of type map[string]string")

	expectedHyperthreadingEnabled, err := strconv.ParseBool(options.TerraformVars["hyperthreading_enabled"].(string))
	require.NoError(t, err, "Error parsing hyperthreading_enabled: %v", err)

	// Set job commands based on solution type
	jobCommandLow, jobCommandMed := SetJobCommands(expectedSolution, expectedZone)

	// Run the test consistency check
	clusterCreationErr := ValidateClusterCreation(t, options, testLogger)
	if clusterCreationErr != nil {
		require.NoError(t, clusterCreationErr, "Cluster creation validation failed: %v")
	}

	// Retrieve server IPs (different logic for HPC vs LSF solutions)
	bastionIP, managementNodeIPList, loginNodeIP, staticWorkerNodeIPList, ipRetrievalError := GetClusterIPs(t, options, expectedSolution, testLogger)
	require.NoError(t, ipRetrievalError, "Error occurred while getting server IPs: %v", ipRetrievalError)

	// Log validation start
	testLogger.Info(t, t.Name()+" Validation started ......")

	// Connect to the master node via SSH and handle connection errors
	sshClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPList[0])
	require.NoError(t, connectionErr, "Failed to connect to the master via SSH")
	defer sshClient.Close()

	testLogger.Info(t, "SSH connection to the master successful")
	t.Log("Validation in progress. Please wait...")

	// Verify management node configuration
	VerifyManagementNodeConfig(t, sshClient, expectedClusterName, expectedMasterName, expectedReservationID, expectedHyperthreadingEnabled, managementNodeIPList, EXPECTED_LSF_VERSION, expectedSolution, testLogger)

	// Verify SSH key on management nodes
	VerifySSHKey(t, sshClient, bastionIP, LSF_PUBLIC_HOST_NAME, LSF_PRIVATE_HOST_NAME, "management", managementNodeIPList, expectedNumOfKeys, testLogger)

	// Verify LSF DNS on management nodes
	VerifyLSFDNS(t, sshClient, managementNodeIPList, expectedDnsDomainName, testLogger)

	// Perform failover and failback
	FailoverAndFailback(t, sshClient, jobCommandMed, testLogger)

	// Restart LSF daemon
	RestartLsfDaemon(t, sshClient, testLogger)

	// Reboot instance
	RebootInstance(t, sshClient, bastionIP, LSF_PUBLIC_HOST_NAME, LSF_PRIVATE_HOST_NAME, managementNodeIPList[0], testLogger)

	// Reconnect to the management node after reboot
	sshClient, connectionErr = utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPList[0])
	require.NoError(t, connectionErr, "Failed to reconnect to the master via SSH")
	defer sshClient.Close()

	// Wait for dynamic node disappearance and handle potential errors
	defer func() {
		if err := WaitForDynamicNodeDisappearance(t, sshClient, testLogger); err != nil {
			t.Errorf("Error in WaitForDynamicNodeDisappearance: %v", err)
		}
	}()

	// Run job
	VerifyJobs(t, sshClient, jobCommandLow, testLogger)
	// Get compute node IPs and handle errors
	computeNodeIPList, err := GetComputeNodeIPs(t, sshClient, testLogger, expectedSolution, staticWorkerNodeIPList)
	if err != nil {
		t.Fatalf("Failed to retrieve dynamic compute node IPs: %v", err)
	}

	// Verify compute node configuration
	VerifyComputeNodeConfig(t, sshClient, expectedHyperthreadingEnabled, computeNodeIPList, testLogger)

	// Verify SSH key on compute nodes
	VerifySSHKey(t, sshClient, bastionIP, LSF_PUBLIC_HOST_NAME, LSF_PRIVATE_HOST_NAME, "compute", computeNodeIPList, expectedNumOfKeys, testLogger)

	// Verify LSF DNS on compute nodes
	VerifyLSFDNS(t, sshClient, computeNodeIPList, expectedDnsDomainName, testLogger)

	// Verify SSH connectivity from login node and handle connection errors
	sshLoginNodeClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, loginNodeIP)
	require.NoError(t, connectionErr, "Failed to connect to the login node via SSH")
	defer sshLoginNodeClient.Close()

	// Verify login node configuration
	VerifyLoginNodeConfig(t, sshLoginNodeClient, expectedClusterName, expectedMasterName, expectedReservationID, expectedHyperthreadingEnabled, loginNodeIP, jobCommandLow, EXPECTED_LSF_VERSION, testLogger)

	// Verify SSH connectivity from login node
	VerifySSHConnectivityToNodesFromLogin(t, sshLoginNodeClient, managementNodeIPList, computeNodeIPList, testLogger)

	// Verify PTR records
	VerifyPTRRecordsForManagementAndLoginNodes(t, sshClient, LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPList, loginNodeIP, expectedDnsDomainName, testLogger)

	// Verify file share encryption
	VerifyFileShareEncryption(t, sshClient, os.Getenv("TF_VAR_ibmcloud_api_key"), utils.GetRegion(expectedZone), expectedResourceGroup, expectedMasterName, expectedKeyManagement, managementNodeIPList, testLogger)

	// Connect to the LDAP server via SSH
	sshLdapClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, ldapServerBastionIP, LSF_LDAP_HOST_NAME, ldapServerIP)
	require.NoError(t, connectionErr, "Failed to connect to the LDAP server via SSH")
	defer sshLdapClient.Close()

	// Check LDAP server status
	CheckLDAPServerStatus(t, sshLdapClient, ldapAdminPassword, expectedLdapDomain, ldapUserName, testLogger)

	// Verify management node LDAP configuration
	VerifyManagementNodeLDAPConfig(t, sshClient, bastionIP, ldapServerIP, managementNodeIPList, jobCommandLow, expectedLdapDomain, ldapUserName, ldapUserPassword, testLogger)

	// Verify compute node LDAP configuration
	VerifyComputeNodeLDAPConfig(t, bastionIP, ldapServerIP, computeNodeIPList, expectedLdapDomain, ldapUserName, ldapUserPassword, testLogger)

	// Verify login node LDAP configuration
	VerifyLoginNodeLDAPConfig(t, sshLoginNodeClient, bastionIP, loginNodeIP, ldapServerIP, jobCommandLow, expectedLdapDomain, ldapUserName, ldapUserPassword, testLogger)

	// Verify LDAP user creation and LSF actions using the new user
	VerifyCreateNewLdapUserAndManagementNodeLDAPConfig(t, sshLdapClient, bastionIP, ldapServerIP, managementNodeIPList, jobCommandLow, ldapAdminPassword, expectedLdapDomain, ldapUserName, ldapUserPassword, "tester2", testLogger)

	// Log validation end
	testLogger.Info(t, t.Name()+" Validation ended")
}

// ValidateBasicClusterConfigurationLSFLogs validates the basic cluster configuration
// for a cluster setup. This function ensures the following:
// - Key nodes like management, compute, and login nodes are properly configured.
// - Connectivity, cluster creation, configuration validation, and job execution are verified.
// - LSF log files are validated, including checking their availability in the shared folders and ensuring symbolic links are present.
// - Validate cluster creation and retrieve required details such as cluster IDs and IPs.
// - Establish SSH connections to nodes and validate their configurations.
// - Validate LSF logs by checking the directory structure and symbolic links in the shared folder.
// - Reconnect to the master node after reboot and verify job execution.

func ValidateBasicClusterConfigurationLSFLogs(t *testing.T, options *testhelper.TestOptions, testLogger *utils.AggregatedLogger) {
	// Retrieve cluster details from the options provided for validation
	expectedSolution := strings.ToLower(options.TerraformVars["solution"].(string))
	expectedClusterName, expectedReservationID, expectedMasterName := GetClusterInfo(options)
	expectedZone := options.TerraformVars["zones"].([]string)[0]
	expectedResourceGroup := options.TerraformVars["existing_resource_group"].(string)

	// Parse hyperthreading setting
	expectedHyperthreadingEnabled, err := strconv.ParseBool(options.TerraformVars["hyperthreading_enabled"].(string))
	require.NoError(t, err, "Error parsing 'hyperthreading_enabled' setting: %v", err)

	// Set job command based on solution and zone
	jobCommandLow, _ := SetJobCommands(expectedSolution, expectedZone)

	// Validate cluster creation
	clusterCreationErr := ValidateClusterCreation(t, options, testLogger)
	if clusterCreationErr != nil {
		require.NoError(t, clusterCreationErr, "Cluster creation validation failed: %v")
	}

	// Retrieve server IPs (handles logic for HPC vs LSF)
	bastionIP, managementNodeIPList, loginNodeIP, staticWorkerNodeIPList, ipRetrievalError := GetClusterIPs(t, options, expectedSolution, testLogger)
	require.NoError(t, ipRetrievalError, "Error while retrieving server IPs: %v", ipRetrievalError)

	// Log the start of validation
	testLogger.Info(t, t.Name()+" Validation started ......")

	// Establish SSH connection to master node
	sshClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPList[0])
	require.NoError(t, connectionErr, "Failed to connect to the master via SSH")
	defer sshClient.Close()

	testLogger.Info(t, "SSH connection to the master successful")
	t.Log("Validation in progress. Please wait...")

	// Validate management node configuration
	VerifyManagementNodeConfig(t, sshClient, expectedClusterName, expectedMasterName, expectedReservationID, expectedHyperthreadingEnabled, managementNodeIPList, EXPECTED_LSF_VERSION, expectedSolution, testLogger)

	// Validate LSF logs: Check if the logs are stored in their correct directory and ensure symbolic links are present
	ValidateLSFLogs(t, sshClient, os.Getenv("TF_VAR_ibmcloud_api_key"), utils.GetRegion(expectedZone), expectedResourceGroup, bastionIP, managementNodeIPList, testLogger)

	// Reconnect to the master node via SSH after reboot
	sshClient, connectionErr = utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPList[0])
	require.NoError(t, connectionErr, "Failed to reconnect to the master via SSH")
	defer sshClient.Close()

	// Wait for dynamic node disappearance
	defer func() {
		if err := WaitForDynamicNodeDisappearance(t, sshClient, testLogger); err != nil {
			t.Errorf("Error in WaitForDynamicNodeDisappearance: %v", err)
		}
	}()

	// Execute job verification
	VerifyJobs(t, sshClient, jobCommandLow, testLogger)

	// Retrieve compute node IPs
	computeNodeIPList, err := GetComputeNodeIPs(t, sshClient, testLogger, expectedSolution, staticWorkerNodeIPList)
	if err != nil {
		t.Fatalf("Failed to retrieve dynamic compute node IPs: %v", err)
	}

	// Validate compute node configuration
	VerifyComputeNodeConfig(t, sshClient, expectedHyperthreadingEnabled, computeNodeIPList, testLogger)

	// Verify SSH connectivity from login node
	sshLoginNodeClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, loginNodeIP)
	require.NoError(t, connectionErr, "Failed to connect to the login node via SSH")
	defer sshLoginNodeClient.Close()

	// Validate login node configuration
	VerifyLoginNodeConfig(t, sshLoginNodeClient, expectedClusterName, expectedMasterName, expectedReservationID, expectedHyperthreadingEnabled, loginNodeIP, jobCommandLow, EXPECTED_LSF_VERSION, testLogger)

	// Log the end of validation
	testLogger.Info(t, t.Name()+" Validation ended")
}

// ValidateBasicClusterConfigurationWithDedicatedHost validates the basic configuration of a cluster
// with a dedicated host setup. It ensures that the management node, compute nodes, login node, and
// connectivity between all components are configured correctly. The function performs various
// validation tasks including checking cluster details, node configurations, IP retrieval,
// and job execution. This function logs all validation steps and errors during the process.
func ValidateBasicClusterConfigurationWithDedicatedHost(t *testing.T, options *testhelper.TestOptions, expectedDedicatedHostPresence bool, testLogger *utils.AggregatedLogger) {
	// Retrieve common cluster details from options
	expectedSolution := strings.ToLower(options.TerraformVars["solution"].(string))
	expectedClusterName, expectedReservationID, expectedMasterName := GetClusterInfo(options)
	expectedKeyManagement := options.TerraformVars["key_management"].(string)
	expectedResourceGroup := options.TerraformVars["existing_resource_group"].(string)
	WorkerNodeMinCount, err := utils.GetTotalWorkerNodeCount(t, options.TerraformVars, testLogger)
	require.NoError(t, err, "Error retrieving worker node total count")
	expectedZone := options.TerraformVars["zones"].([]string)[0]

	// Retrieve expected DNS domain name for compute nodes
	expectedDnsDomainName, ok := options.TerraformVars["dns_domain_name"].(map[string]string)["compute"]
	require.True(t, ok, "Key 'compute' does not exist in dns_domain_name map or dns_domain_name is not of type map[string]string")

	// Parse hyperthreading configuration
	expectedHyperthreadingEnabled, err := strconv.ParseBool(options.TerraformVars["hyperthreading_enabled"].(string))
	require.NoError(t, err, "Error parsing hyperthreading_enabled: %v", err)

	// Set job commands based on solution type
	jobCommandLow, _ := SetJobCommands(expectedSolution, expectedZone)

	// Run the test consistency check for cluster creation for cluster creation
	clusterCreationErr := ValidateClusterCreation(t, options, testLogger)
	if clusterCreationErr != nil {
		require.NoError(t, clusterCreationErr, "Cluster creation validation failed: %v")
	}

	// Retrieve IPs for all the required nodes (bastion, management, login, and static worker)
	bastionIP, managementNodeIPList, loginNodeIP, staticWorkerNodeIPList, ipRetrievalError := GetClusterIPs(t, options, expectedSolution, testLogger)
	require.NoError(t, ipRetrievalError, "Error occurred while getting server IPs: %v", ipRetrievalError)

	// Log validation start
	testLogger.Info(t, t.Name()+" Validation started ......")

	// Connect to the master node via SSH and handle connection errors
	sshClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPList[0])
	require.NoError(t, connectionErr, "Failed to connect to the master via SSH")
	defer sshClient.Close()

	testLogger.Info(t, "SSH connection to the master successful")
	t.Log("Validation in progress. Please wait...")

	// Verify management node configuration
	VerifyManagementNodeConfig(t, sshClient, expectedClusterName, expectedMasterName, expectedReservationID, expectedHyperthreadingEnabled, managementNodeIPList, EXPECTED_LSF_VERSION, expectedSolution, testLogger)

	// Verify dedicated host configuration
	ValidateDedicatedHost(t, os.Getenv("TF_VAR_ibmcloud_api_key"), utils.GetRegion(expectedZone), expectedResourceGroup, expectedMasterName, WorkerNodeMinCount, expectedDedicatedHostPresence, testLogger)

	// Wait for dynamic node disappearance and handle potential errors
	defer func() {
		if err := WaitForDynamicNodeDisappearance(t, sshClient, testLogger); err != nil {
			t.Errorf("Error in WaitForDynamicNodeDisappearance: %v", err)
		}
	}()

	// Run job to verify job execution on the cluster
	VerifyJobs(t, sshClient, jobCommandLow, testLogger)

	// Get compute node IPs and handle errors
	computeNodeIPList, err := GetComputeNodeIPs(t, sshClient, testLogger, expectedSolution, staticWorkerNodeIPList)
	if err != nil {
		t.Fatalf("Failed to retrieve dynamic compute node IPs: %v", err)
	}

	// Verify compute node configuration
	VerifyComputeNodeConfig(t, sshClient, expectedHyperthreadingEnabled, computeNodeIPList, testLogger)

	// Verify SSH connectivity from login node and handle connection errors
	sshLoginNodeClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, loginNodeIP)
	require.NoError(t, connectionErr, "Failed to connect to the login node via SSH")
	defer sshLoginNodeClient.Close()

	// Verify login node configuration
	VerifyLoginNodeConfig(t, sshLoginNodeClient, expectedClusterName, expectedMasterName, expectedReservationID, expectedHyperthreadingEnabled, loginNodeIP, jobCommandLow, EXPECTED_LSF_VERSION, testLogger)

	// Verify PTR records for management and login nodes
	VerifyPTRRecordsForManagementAndLoginNodes(t, sshClient, LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPList, loginNodeIP, expectedDnsDomainName, testLogger)

	// Verify LSF DNS settings on login node
	VerifyLSFDNS(t, sshClient, []string{loginNodeIP}, expectedDnsDomainName, testLogger)

	// Verify file share encryption configuration
	VerifyFileShareEncryption(t, sshClient, os.Getenv("TF_VAR_ibmcloud_api_key"), utils.GetRegion(expectedZone), expectedResourceGroup, expectedMasterName, expectedKeyManagement, managementNodeIPList, testLogger)

	// Log validation end
	testLogger.Info(t, t.Name()+" Validation ended")
}

// ValidateBasicClusterConfigurationWithSCC validates the basic cluster configuration.
// It performs validation tasks on essential aspects of the cluster setup,
// including the management node, compute nodes, and login node configurations.
// Additionally, it ensures proper connectivity and functionality.
// This function checks service instance details, extracts relevant GUIDs, and verifies attachments' states.
// Errors and validation steps are logged during the process.
func ValidateBasicClusterConfigurationWithSCC(t *testing.T, options *testhelper.TestOptions, testLogger *utils.AggregatedLogger) {
	// Retrieve common cluster details from options
	expectedSolution := strings.ToLower(options.TerraformVars["solution"].(string))
	expectedClusterName, expectedReservationID, expectedMasterName := GetClusterInfo(options)

	expectedResourceGroup := options.TerraformVars["existing_resource_group"].(string)
	expectedKeyManagement := options.TerraformVars["key_management"].(string)
	expectedZone := options.TerraformVars["zones"].([]string)[0]

	// Retrieve expected DNS domain name for compute nodes
	expectedDnsDomainName, ok := options.TerraformVars["dns_domain_name"].(map[string]string)["compute"]
	require.True(t, ok, "Key 'compute' does not exist in dns_domain_name map or dns_domain_name is not of type map[string]string")

	// Parse hyperthreading configuration
	expectedHyperthreadingEnabled, err := strconv.ParseBool(options.TerraformVars["hyperthreading_enabled"].(string))
	require.NoError(t, err, "Error parsing hyperthreading_enabled: %v", err)

	// Set job commands based on solution type
	jobCommandLow, _ := SetJobCommands(expectedSolution, expectedZone)

	// Run the test consistency check for cluster creation
	clusterCreationErr := ValidateClusterCreation(t, options, testLogger)
	if clusterCreationErr != nil {
		require.NoError(t, clusterCreationErr, "Cluster creation validation failed: %v")
	}

	// Retrieve server IPs (different logic for HPC vs LSF solutions)
	bastionIP, managementNodeIPList, loginNodeIP, staticWorkerNodeIPList, ipRetrievalError := GetClusterIPs(t, options, expectedSolution, testLogger)
	require.NoError(t, ipRetrievalError, "Error occurred while getting server IPs: %v", ipRetrievalError)

	// Log validation start
	testLogger.Info(t, t.Name()+" Validation started ......")

	// Connect to the master node via SSH and handle connection errors
	sshClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPList[0])
	require.NoError(t, connectionErr, "Failed to connect to the master via SSH")
	defer sshClient.Close()

	testLogger.Info(t, "SSH connection to the master successful")
	t.Log("Validation in progress. Please wait...")

	// Verify management node configuration
	VerifyManagementNodeConfig(t, sshClient, expectedClusterName, expectedMasterName, expectedReservationID, expectedHyperthreadingEnabled, managementNodeIPList, EXPECTED_LSF_VERSION, expectedSolution, testLogger)

	// Verify SCC instance
	ValidateSCCInstance(t, os.Getenv("TF_VAR_ibmcloud_api_key"), utils.GetRegion(expectedZone), expectedResourceGroup, expectedMasterName, SCC_INSTANCE_REGION, testLogger)

	// Wait for dynamic node disappearance and handle potential errors
	defer func() {
		if err := WaitForDynamicNodeDisappearance(t, sshClient, testLogger); err != nil {
			t.Errorf("Error in WaitForDynamicNodeDisappearance: %v", err)
		}
	}()

	// Run job to verify job execution on the cluster
	VerifyJobs(t, sshClient, jobCommandLow, testLogger)

	// Get compute node IPs and handle errors
	computeNodeIPList, err := GetComputeNodeIPs(t, sshClient, testLogger, expectedSolution, staticWorkerNodeIPList)
	if err != nil {
		t.Fatalf("Failed to retrieve dynamic compute node IPs: %v", err)
	}

	// Verify compute node configuration
	VerifyComputeNodeConfig(t, sshClient, expectedHyperthreadingEnabled, computeNodeIPList, testLogger)

	// Verify SSH connectivity from login node and handle connection errors
	sshLoginNodeClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, loginNodeIP)
	require.NoError(t, connectionErr, "Failed to connect to the login node via SSH")
	defer sshLoginNodeClient.Close()

	// Verify login node configuration
	VerifyLoginNodeConfig(t, sshLoginNodeClient, expectedClusterName, expectedMasterName, expectedReservationID, expectedHyperthreadingEnabled, loginNodeIP, jobCommandLow, EXPECTED_LSF_VERSION, testLogger)

	// Verify PTR records
	VerifyPTRRecordsForManagementAndLoginNodes(t, sshClient, LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPList, loginNodeIP, expectedDnsDomainName, testLogger)

	// Verify LSF DNS on login node
	VerifyLSFDNS(t, sshClient, []string{loginNodeIP}, expectedDnsDomainName, testLogger)

	// Verify file share encryption configuration
	VerifyFileShareEncryption(t, sshClient, os.Getenv("TF_VAR_ibmcloud_api_key"), utils.GetRegion(expectedZone), expectedResourceGroup, expectedMasterName, expectedKeyManagement, managementNodeIPList, testLogger)

	// Log validation end
	testLogger.Info(t, t.Name()+" Validation ended")
}

// ValidateBasicClusterConfigurationWithCloudLogs validates essential cluster configurations and logs errors.
// This function ensures that the management, compute, and login nodes meet the required configurations.
// It establishes SSH connections to nodes, validates DNS, encryption, and logs observability settings.
// Errors are handled explicitly, and validation steps are logged for debugging.
// Key validation and configuration checks ensure that the cluster setup adheres to standards.

func ValidateBasicClusterConfigurationWithCloudLogs(t *testing.T, options *testhelper.TestOptions, testLogger *utils.AggregatedLogger) {
	// Retrieve common cluster details from options
	expectedSolution := strings.ToLower(options.TerraformVars["solution"].(string))
	expectedClusterName, expectedReservationID, expectedMasterName := GetClusterInfo(options)

	expectedResourceGroup := options.TerraformVars["existing_resource_group"].(string)
	expectedKeyManagement := options.TerraformVars["key_management"].(string)
	expectedZone := options.TerraformVars["zones"].([]string)[0]

	expectedDnsDomainName, ok := options.TerraformVars["dns_domain_name"].(map[string]string)["compute"]
	require.True(t, ok, "Key 'compute' does not exist in dns_domain_name map or dns_domain_name is not of type map[string]string")

	expectedHyperthreadingEnabled, err := strconv.ParseBool(options.TerraformVars["hyperthreading_enabled"].(string))
	require.NoError(t, err, "Error parsing hyperthreading_enabled: %v", err)

	expectedLogsEnabledForManagement, err := strconv.ParseBool(fmt.Sprintf("%v", options.TerraformVars["observability_logs_enable_for_management"]))
	require.NoError(t, err, "Error parsing observability_logs_enable_for_management")

	expectedLogsEnabledForCompute, err := strconv.ParseBool(fmt.Sprintf("%v", options.TerraformVars["observability_logs_enable_for_compute"]))
	require.NoError(t, err, "Error parsing observability_logs_enable_for_compute")

	// Set job commands based on solution type
	jobCommandLow, jobCommandMed := SetJobCommands(expectedSolution, expectedZone)

	// Run the test consistency check
	clusterCreationErr := ValidateClusterCreation(t, options, testLogger)
	if clusterCreationErr != nil {
		require.NoError(t, clusterCreationErr, "Cluster creation validation failed: %v")
	}

	// Retrieve server IPs (different logic for HPC vs LSF solutions)
	bastionIP, managementNodeIPList, loginNodeIP, staticWorkerNodeIPList, ipRetrievalError := GetClusterIPs(t, options, expectedSolution, testLogger)
	require.NoError(t, ipRetrievalError, "Error occurred while getting server IPs: %v", ipRetrievalError)

	// Log validation start
	testLogger.Info(t, t.Name()+" Validation started ......")

	// Connect to the master node via SSH and handle connection errors
	sshClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPList[0])
	require.NoError(t, connectionErr, "Failed to connect to the master via SSH")
	defer sshClient.Close()

	testLogger.Info(t, "SSH connection to the master successful")
	t.Log("Validation in progress. Please wait...")

	// Verify management node configuration
	VerifyManagementNodeConfig(t, sshClient, expectedClusterName, expectedMasterName, expectedReservationID, expectedHyperthreadingEnabled, managementNodeIPList, EXPECTED_LSF_VERSION, expectedSolution, testLogger)

	// Wait for dynamic node disappearance and handle potential errors
	defer func() {
		if err := WaitForDynamicNodeDisappearance(t, sshClient, testLogger); err != nil {
			t.Errorf("Error in WaitForDynamicNodeDisappearance: %v", err)
		}
	}()

	// Run job
	VerifyJobs(t, sshClient, jobCommandMed, testLogger)

	// Get static and dynamic compute node IPs and handle errors
	computeNodeIPList, err := GetComputeNodeIPs(t, sshClient, testLogger, expectedSolution, staticWorkerNodeIPList)
	if err != nil {
		t.Fatalf("Failed to retrieve dynamic compute node IPs: %v", err)
	}

	// Verify compute node configuration
	VerifyComputeNodeConfig(t, sshClient, expectedHyperthreadingEnabled, computeNodeIPList, testLogger)

	// Verify that cloud logs are enabled and correctly configured
	VerifyCloudLogs(t, sshClient, expectedSolution, options.LastTestTerraformOutputs, managementNodeIPList, staticWorkerNodeIPList, expectedLogsEnabledForManagement, expectedLogsEnabledForCompute, testLogger)

	// Verify SSH connectivity from login node and handle connection errors
	sshLoginNodeClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, loginNodeIP)
	require.NoError(t, connectionErr, "Failed to connect to the login node via SSH")
	defer sshLoginNodeClient.Close()

	// Verify login node configuration
	VerifyLoginNodeConfig(t, sshLoginNodeClient, expectedClusterName, expectedMasterName, expectedReservationID, expectedHyperthreadingEnabled, loginNodeIP, jobCommandLow, EXPECTED_LSF_VERSION, testLogger)

	// Verify PTR records
	VerifyPTRRecordsForManagementAndLoginNodes(t, sshClient, LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPList, loginNodeIP, expectedDnsDomainName, testLogger)

	// Verify LSF DNS on login node
	VerifyLSFDNS(t, sshClient, []string{loginNodeIP}, expectedDnsDomainName, testLogger)

	// Verify file share encryption
	VerifyFileShareEncryption(t, sshClient, os.Getenv("TF_VAR_ibmcloud_api_key"), utils.GetRegion(expectedZone), expectedResourceGroup, expectedMasterName, expectedKeyManagement, managementNodeIPList, testLogger)

	// Log validation end
	testLogger.Info(t, t.Name()+" Validation ended")
}

// ValidateBasicClusterConfigurationWithCloudMonitoring validates essential cluster configurations and logs errors.
// This function ensures that the management, compute, and login nodes meet the required configurations.
// It establishes SSH connections to nodes, validates DNS, encryption, and logs observability settings.
// Errors are handled explicitly, and validation steps are logged for debugging.
// Key validation and configuration checks ensure that the cluster setup adheres to standards.

func ValidateBasicClusterConfigurationWithCloudMonitoring(t *testing.T, options *testhelper.TestOptions, testLogger *utils.AggregatedLogger) {
	// Retrieve common cluster details from options
	expectedSolution := strings.ToLower(options.TerraformVars["solution"].(string))
	expectedClusterName, expectedReservationID, expectedMasterName := GetClusterInfo(options)

	expectedResourceGroup := options.TerraformVars["existing_resource_group"].(string)
	expectedKeyManagement := options.TerraformVars["key_management"].(string)
	expectedZone := options.TerraformVars["zones"].([]string)[0]

	expectedDnsDomainName, ok := options.TerraformVars["dns_domain_name"].(map[string]string)["compute"]
	require.True(t, ok, "Key 'compute' does not exist in dns_domain_name map or dns_domain_name is not of type map[string]string")

	expectedHyperthreadingEnabled, err := strconv.ParseBool(options.TerraformVars["hyperthreading_enabled"].(string))
	require.NoError(t, err, "Error parsing hyperthreading_enabled: %v", err)

	expectedMonitoringEnabledForManagement, err := strconv.ParseBool(fmt.Sprintf("%v", options.TerraformVars["observability_monitoring_enable"]))
	require.NoError(t, err, "Error parsing observability_monitoring_enable")

	expectedMonitoringEnabledForCompute, err := strconv.ParseBool(fmt.Sprintf("%v", options.TerraformVars["observability_monitoring_on_compute_nodes_enable"]))
	require.NoError(t, err, "Error parsing observability_monitoring_on_compute_nodes_enable")

	// Set job commands based on solution type
	jobCommandLow, jobCommandMed := SetJobCommands(expectedSolution, expectedZone)

	// Run the test consistency check
	clusterCreationErr := ValidateClusterCreation(t, options, testLogger)
	if clusterCreationErr != nil {
		require.NoError(t, clusterCreationErr, "Cluster creation validation failed: %v")
	}

	// Retrieve server IPs (different logic for HPC vs LSF solutions)
	bastionIP, managementNodeIPList, loginNodeIP, staticWorkerNodeIPList, ipRetrievalError := GetClusterIPs(t, options, expectedSolution, testLogger)
	require.NoError(t, ipRetrievalError, "Error occurred while getting server IPs: %v", ipRetrievalError)

	// Log validation start
	testLogger.Info(t, t.Name()+" Validation started ......")

	// Connect to the master node via SSH and handle connection errors
	sshClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPList[0])
	require.NoError(t, connectionErr, "Failed to connect to the master via SSH")
	defer sshClient.Close()

	testLogger.Info(t, "SSH connection to the master successful")
	t.Log("Validation in progress. Please wait...")

	// Verify management node configuration
	VerifyManagementNodeConfig(t, sshClient, expectedClusterName, expectedMasterName, expectedReservationID, expectedHyperthreadingEnabled, managementNodeIPList, EXPECTED_LSF_VERSION, expectedSolution, testLogger)

	// Wait for dynamic node disappearance and handle potential errors
	defer func() {
		if err := WaitForDynamicNodeDisappearance(t, sshClient, testLogger); err != nil {
			t.Errorf("Error in WaitForDynamicNodeDisappearance: %v", err)
		}
	}()

	// Run job
	VerifyJobs(t, sshClient, jobCommandMed, testLogger)

	// Get static and dynamic compute node IPs and handle errors
	computeNodeIPList, err := GetComputeNodeIPs(t, sshClient, testLogger, expectedSolution, staticWorkerNodeIPList)
	if err != nil {
		t.Fatalf("Failed to retrieve dynamic compute node IPs: %v", err)
	}

	// Verify compute node configuration
	VerifyComputeNodeConfig(t, sshClient, expectedHyperthreadingEnabled, computeNodeIPList, testLogger)

	// Verify that cloud monitoring are enabled and correctly configured
	VerifyCloudMonitoring(t, sshClient, expectedSolution, options.LastTestTerraformOutputs, managementNodeIPList, staticWorkerNodeIPList, expectedMonitoringEnabledForManagement, expectedMonitoringEnabledForCompute, testLogger)

	// Verify SSH connectivity from login node and handle connection errors
	sshLoginNodeClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, loginNodeIP)
	require.NoError(t, connectionErr, "Failed to connect to the login node via SSH")
	defer sshLoginNodeClient.Close()

	// Verify login node configuration
	VerifyLoginNodeConfig(t, sshLoginNodeClient, expectedClusterName, expectedMasterName, expectedReservationID, expectedHyperthreadingEnabled, loginNodeIP, jobCommandLow, EXPECTED_LSF_VERSION, testLogger)

	// Verify PTR records
	VerifyPTRRecordsForManagementAndLoginNodes(t, sshClient, LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPList, loginNodeIP, expectedDnsDomainName, testLogger)

	// Verify LSF DNS on login node
	VerifyLSFDNS(t, sshClient, []string{loginNodeIP}, expectedDnsDomainName, testLogger)

	// Verify file share encryption
	VerifyFileShareEncryption(t, sshClient, os.Getenv("TF_VAR_ibmcloud_api_key"), utils.GetRegion(expectedZone), expectedResourceGroup, expectedMasterName, expectedKeyManagement, managementNodeIPList, testLogger)

	// Log validation end
	testLogger.Info(t, t.Name()+" Validation ended")
}

// ValidateBasicClusterConfigurationWithCloudAtracker verifies that the cluster setup aligns with the expected configuration
// when Observability Atracker is enabled or disabled. It performs validations across management, compute, and login nodes,
// ensuring compliance with DNS, encryption, logging, and Atracker settings.
// The function establishes SSH connections to validate node configurations, runs job verification tests,
// checks PTR records, and ensures file share encryption. If any configuration discrepancies are found,
// appropriate test errors are raised.
func ValidateBasicClusterConfigurationWithCloudAtracker(t *testing.T, options *testhelper.TestOptions, testLogger *utils.AggregatedLogger) {
	// Retrieve common cluster details
	expectedSolution := strings.ToLower(options.TerraformVars["solution"].(string))
	expectedClusterName, expectedReservationID, expectedMasterName := GetClusterInfo(options)
	expectedResourceGroup := options.TerraformVars["existing_resource_group"].(string)
	expectedKeyManagement := options.TerraformVars["key_management"].(string)
	expectedZone := options.TerraformVars["zones"].([]string)[0]
	expectedTargetType := options.TerraformVars["observability_atracker_target_type"].(string)

	expectedObservabilityAtrackerEnable, err := strconv.ParseBool(fmt.Sprintf("%v", options.TerraformVars["observability_atracker_enable"]))
	require.NoError(t, err, "Error parsing observability_atracker_enable")

	expectedDnsDomainName, ok := options.TerraformVars["dns_domain_name"].(map[string]string)["compute"]
	require.True(t, ok, "Missing or invalid 'compute' key in dns_domain_name")

	expectedHyperthreadingEnabled, err := strconv.ParseBool(options.TerraformVars["hyperthreading_enabled"].(string))
	require.NoError(t, err, "Error parsing hyperthreading_enabled")

	// Set job commands
	jobCommandLow, jobCommandMed := SetJobCommands(expectedSolution, expectedZone)

	// Validate cluster creation
	require.NoError(t, ValidateClusterCreation(t, options, testLogger), "Cluster creation validation failed")

	// Retrieve server IPs
	bastionIP, managementNodeIPList, loginNodeIP, staticWorkerNodeIPList, err := GetClusterIPs(t, options, expectedSolution, testLogger)
	require.NoError(t, err, "Failed to retrieve cluster IPs")

	testLogger.Info(t, t.Name()+" Validation started ......")

	// Establish SSH connection to master node
	sshClient, err := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPList[0])
	require.NoError(t, err, "Failed to connect to the master node via SSH")
	defer sshClient.Close()
	testLogger.Info(t, "SSH connection to master node successful")

	t.Log("Validation in progress. Please wait...")

	// Verify management node configuration
	VerifyManagementNodeConfig(t, sshClient, expectedClusterName, expectedMasterName, expectedReservationID, expectedHyperthreadingEnabled, managementNodeIPList, EXPECTED_LSF_VERSION, expectedSolution, testLogger)

	// Ensure dynamic node disappearance check runs after validation
	defer func() {
		if err := WaitForDynamicNodeDisappearance(t, sshClient, testLogger); err != nil {
			t.Errorf("Error in WaitForDynamicNodeDisappearance: %v", err)
		}
	}()

	// Run job verification
	VerifyJobs(t, sshClient, jobCommandMed, testLogger)

	// Get compute node IPs
	computeNodeIPList, err := GetComputeNodeIPs(t, sshClient, testLogger, expectedSolution, staticWorkerNodeIPList)
	require.NoError(t, err, "Failed to retrieve dynamic compute node IPs")

	// Verify compute node configuration
	VerifyComputeNodeConfig(t, sshClient, expectedHyperthreadingEnabled, computeNodeIPList, testLogger)

	// Validate Atracker
	ibmCloudAPIKey := os.Getenv("TF_VAR_ibmcloud_api_key")
	ValidateAtracker(t, ibmCloudAPIKey, utils.GetRegion(expectedZone), expectedResourceGroup, expectedMasterName, expectedTargetType, expectedObservabilityAtrackerEnable, testLogger)

	// Establish SSH connection to login node
	sshLoginNodeClient, err := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, loginNodeIP)
	require.NoError(t, err, "Failed to connect to the login node via SSH")
	defer sshLoginNodeClient.Close()

	// Verify login node configuration
	VerifyLoginNodeConfig(t, sshLoginNodeClient, expectedClusterName, expectedMasterName, expectedReservationID, expectedHyperthreadingEnabled, loginNodeIP, jobCommandLow, EXPECTED_LSF_VERSION, testLogger)

	// Verify PTR records
	VerifyPTRRecordsForManagementAndLoginNodes(t, sshClient, LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPList, loginNodeIP, expectedDnsDomainName, testLogger)

	// Verify LSF DNS on login node
	VerifyLSFDNS(t, sshClient, []string{loginNodeIP}, expectedDnsDomainName, testLogger)

	// Verify file share encryption
	VerifyFileShareEncryption(t, sshClient, ibmCloudAPIKey, utils.GetRegion(expectedZone), expectedResourceGroup, expectedMasterName, expectedKeyManagement, managementNodeIPList, testLogger)

	testLogger.Info(t, t.Name()+" Validation ended")
}

// ValidateClusterConfigWithAPPCenterOnExistingEnvironment validates the configuration of an existing cluster with App Center integration.
// It verifies management node configuration, SSH keys, failover and failback, LSF daemon restart, dynamic compute node configuration,
// login node configuration, SSH connectivity, application center configuration, noVNC configuration, PTR records, and file share encryption.
// The function connects to various nodes, performs required actions, and logs results using the provided test logger.
// Parameters include expected values, IP addresses, and configuration settings to ensure the cluster operates correctly with the specified integrations.
func ValidateClusterConfigWithAPPCenterOnExistingEnvironment(
	t *testing.T,
	computeSshKeysList []string,
	bastionIP, loginNodeIP, expectedClusterName, expectedReservationID, expectedMasterName, expectedResourceGroup,
	expectedKeyManagement, expectedZone, expectedDnsDomainName string,
	managementNodeIPList []string,
	expectedHyperthreadingEnabled bool,
	testLogger *utils.AggregatedLogger,
) {

	expectedNumOfKeys := len(computeSshKeysList)

	// Retrieve job commands for different levels
	jobCommandLow := GetJobCommand(expectedZone, "low")
	jobCommandMed := GetJobCommand(expectedZone, "med")

	// Log validation start
	testLogger.Info(t, t.Name()+" Validation started...")

	// Connect to the master node via SSH
	sshClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPList[0])
	require.NoError(t, connectionErr, "Failed to connect to the master via SSH")
	defer sshClient.Close()

	testLogger.Info(t, "SSH connection to the master successful")
	t.Log("Validation in progress. Please wait...")

	// Verify management node configuration
	VerifyManagementNodeConfig(t, sshClient, expectedClusterName, expectedMasterName, expectedReservationID, expectedHyperthreadingEnabled, managementNodeIPList, EXPECTED_LSF_VERSION, "hpc", testLogger)

	// Verify SSH key on management nodes
	VerifySSHKey(t, sshClient, bastionIP, LSF_PUBLIC_HOST_NAME, LSF_PRIVATE_HOST_NAME, "management", managementNodeIPList, expectedNumOfKeys, testLogger)

	// Perform failover and failback
	FailoverAndFailback(t, sshClient, jobCommandMed, testLogger)

	// Restart LSF daemon
	RestartLsfDaemon(t, sshClient, testLogger)

	// Reboot instance
	RebootInstance(t, sshClient, bastionIP, LSF_PUBLIC_HOST_NAME, LSF_PRIVATE_HOST_NAME, managementNodeIPList[0], testLogger)

	// Reconnect to the master node via SSH after reboot
	sshClient, connectionErr = utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPList[0])
	require.NoError(t, connectionErr, "Failed to reconnect to the master via SSH")
	defer sshClient.Close()

	// Wait for dynamic node disappearance and handle potential errors
	defer func() {
		if err := WaitForDynamicNodeDisappearance(t, sshClient, testLogger); err != nil {
			t.Errorf("Error in WaitForDynamicNodeDisappearance: %v", err)
		}
	}()

	// Run job
	VerifyJobs(t, sshClient, jobCommandLow, testLogger)

	// Get dynamic compute node IPs
	computeNodeIPList, computeIPErr := HPCGETDynamicComputeNodeIPs(t, sshClient, testLogger)
	require.NoError(t, computeIPErr, "Error getting dynamic compute node IPs")

	// Verify compute node configuration
	VerifyComputeNodeConfig(t, sshClient, expectedHyperthreadingEnabled, computeNodeIPList, testLogger)

	// Verify SSH key for compute nodes
	VerifySSHKey(t, sshClient, bastionIP, LSF_PUBLIC_HOST_NAME, LSF_PRIVATE_HOST_NAME, "compute", computeNodeIPList, expectedNumOfKeys, testLogger)

	// Verify SSH connectivity from login node
	sshLoginNodeClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, loginNodeIP)
	require.NoError(t, connectionErr, "Failed to connect to the login node via SSH")
	defer sshLoginNodeClient.Close()

	// Verify login node configuration
	VerifyLoginNodeConfig(t, sshLoginNodeClient, expectedClusterName, expectedMasterName, expectedReservationID, expectedHyperthreadingEnabled, loginNodeIP, jobCommandLow, EXPECTED_LSF_VERSION, testLogger)

	// Re-fetch dynamic compute node IPs
	computeNodeIPList, computeIPErr = HPCGETDynamicComputeNodeIPs(t, sshClient, testLogger)
	require.NoError(t, computeIPErr, "Error getting dynamic compute node IPs")

	// Verify SSH connectivity from login node
	VerifySSHConnectivityToNodesFromLogin(t, sshLoginNodeClient, managementNodeIPList, computeNodeIPList, testLogger)

	// Verify application center configuration
	VerifyAPPCenterConfig(t, sshClient, testLogger)

	// Verify noVNC configuration
	VerifyNoVNCConfig(t, sshClient, testLogger)

	// Verify PTR records for management and login nodes
	VerifyPTRRecordsForManagementAndLoginNodes(t, sshClient, LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPList, loginNodeIP, expectedDnsDomainName, testLogger)

	// Verify file share encryption
	VerifyFileShareEncryption(t, sshClient, os.Getenv("TF_VAR_ibmcloud_api_key"), utils.GetRegion(expectedZone), expectedResourceGroup, expectedMasterName, expectedKeyManagement, managementNodeIPList, testLogger)

	// Log validation end
	testLogger.Info(t, t.Name()+" Validation ended")
}

// ValidateClusterConfigWithAPPCenterAndLDAPOnExistingEnvironment validates the configuration of an existing cluster with App Center and LDAP integration.
// It verifies management node configuration, SSH keys, failover and failback, LSF daemon restart, dynamic compute node configuration, login node configuration,
// SSH connectivity, application center configuration, noVNC configuration, PTR records, file share encryption, and LDAP server configuration and status.
// The function connects to various nodes, performs required actions, and logs results using the provided test logger.
// Parameters include expected values, IP addresses, credentials for validation, and configuration settings.
// This ensures the cluster operates correctly with the specified configurations and integrations, including LDAP.
func ValidateClusterConfigWithAPPCenterAndLDAPOnExistingEnvironment(
	t *testing.T,
	computeSshKeysList []string,
	bastionIP, loginNodeIP, expectedClusterName, expectedReservationID, expectedMasterName, expectedResourceGroup,
	expectedKeyManagement, expectedZone, expectedDnsDomainName string,
	managementNodeIPList []string,
	expectedHyperthreadingEnabled bool,
	ldapServerIP, expectedLdapDomain, ldapAdminPassword, ldapUserName, ldapUserPassword string,
	testLogger *utils.AggregatedLogger,
) {

	expectedNumOfKeys := len(computeSshKeysList)

	// Retrieve job commands for different levels
	jobCommandLow := GetJobCommand(expectedZone, "low")
	jobCommandMed := GetJobCommand(expectedZone, "med")

	// Log validation start
	testLogger.Info(t, t.Name()+" Validation started...")

	// Connect to the master node via SSH
	sshClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPList[0])
	require.NoError(t, connectionErr, "Failed to connect to the master via SSH")
	defer sshClient.Close()

	testLogger.Info(t, "SSH connection to the master successful")
	t.Log("Validation in progress. Please wait...")

	// Verify management node configuration
	VerifyManagementNodeConfig(t, sshClient, expectedClusterName, expectedMasterName, expectedReservationID, expectedHyperthreadingEnabled, managementNodeIPList, EXPECTED_LSF_VERSION, "hpc", testLogger)

	// Verify SSH key on management nodes
	VerifySSHKey(t, sshClient, bastionIP, LSF_PUBLIC_HOST_NAME, LSF_PRIVATE_HOST_NAME, "management", managementNodeIPList, expectedNumOfKeys, testLogger)

	// Perform failover and failback
	FailoverAndFailback(t, sshClient, jobCommandMed, testLogger)

	// Restart LSF daemon
	RestartLsfDaemon(t, sshClient, testLogger)

	// Reboot instance
	RebootInstance(t, sshClient, bastionIP, LSF_PUBLIC_HOST_NAME, LSF_PRIVATE_HOST_NAME, managementNodeIPList[0], testLogger)

	// Reconnect to the master node via SSH after reboot
	sshClient, connectionErr = utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPList[0])
	require.NoError(t, connectionErr, "Failed to reconnect to the master via SSH")
	defer sshClient.Close()

	// Wait for dynamic node disappearance and handle potential errors
	defer func() {
		if err := WaitForDynamicNodeDisappearance(t, sshClient, testLogger); err != nil {
			t.Errorf("Error in WaitForDynamicNodeDisappearance: %v", err)
		}
	}()

	// Run job
	VerifyJobs(t, sshClient, jobCommandLow, testLogger)

	// Get dynamic compute node IPs
	computeNodeIPList, err := HPCGETDynamicComputeNodeIPs(t, sshClient, testLogger)
	require.NoError(t, err, "Error getting dynamic compute node IPs")

	// Verify compute node configuration
	VerifyComputeNodeConfig(t, sshClient, expectedHyperthreadingEnabled, computeNodeIPList, testLogger)

	// Verify SSH key for compute nodes
	VerifySSHKey(t, sshClient, bastionIP, LSF_PUBLIC_HOST_NAME, LSF_PRIVATE_HOST_NAME, "compute", computeNodeIPList, expectedNumOfKeys, testLogger)

	// Verify SSH connectivity from login node
	sshLoginNodeClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, loginNodeIP)
	require.NoError(t, connectionErr, "Failed to connect to the login node via SSH")
	defer sshLoginNodeClient.Close()

	// Verify login node configuration
	VerifyLoginNodeConfig(t, sshLoginNodeClient, expectedClusterName, expectedMasterName, expectedReservationID, expectedHyperthreadingEnabled, loginNodeIP, jobCommandLow, EXPECTED_LSF_VERSION, testLogger)

	// Re-fetch dynamic compute node IPs
	computeNodeIPList, connectionErr = HPCGETDynamicComputeNodeIPs(t, sshClient, testLogger)
	require.NoError(t, connectionErr, "Error getting dynamic compute node IPs")

	// Verify SSH connectivity from login node
	VerifySSHConnectivityToNodesFromLogin(t, sshLoginNodeClient, managementNodeIPList, computeNodeIPList, testLogger)

	// Verify application center configuration
	VerifyAPPCenterConfig(t, sshClient, testLogger)

	// Verify noVNC configuration
	VerifyNoVNCConfig(t, sshClient, testLogger)

	// Verify PTR records for management and login nodes
	VerifyPTRRecordsForManagementAndLoginNodes(t, sshClient, LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPList, loginNodeIP, expectedDnsDomainName, testLogger)

	// Verify file share encryption
	VerifyFileShareEncryption(t, sshClient, os.Getenv("TF_VAR_ibmcloud_api_key"), utils.GetRegion(expectedZone), expectedResourceGroup, expectedMasterName, expectedKeyManagement, managementNodeIPList, testLogger)

	// Connect to the LDAP server via SSH and handle connection errors
	sshLdapClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_LDAP_HOST_NAME, ldapServerIP)
	require.NoError(t, connectionErr, "Failed to connect to the LDAP server via SSH")
	defer sshLdapClient.Close()

	// Check LDAP server status
	CheckLDAPServerStatus(t, sshLdapClient, ldapAdminPassword, expectedLdapDomain, ldapUserName, testLogger)

	// Verify management node LDAP config
	VerifyManagementNodeLDAPConfig(t, sshClient, bastionIP, ldapServerIP, managementNodeIPList, jobCommandLow, expectedLdapDomain, ldapUserName, ldapUserPassword, testLogger)

	// Verify compute node LDAP config
	VerifyComputeNodeLDAPConfig(t, bastionIP, ldapServerIP, computeNodeIPList, expectedLdapDomain, ldapUserName, ldapUserPassword, testLogger)

	// Verify login node LDAP config
	VerifyLoginNodeLDAPConfig(t, sshLoginNodeClient, bastionIP, loginNodeIP, ldapServerIP, jobCommandLow, expectedLdapDomain, ldapUserName, ldapUserPassword, testLogger)

	// Log validation end
	testLogger.Info(t, t.Name()+" Validation ended")
}
