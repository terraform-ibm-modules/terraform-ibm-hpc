package tests

import (
	"os"
	"strconv"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"github.com/terraform-ibm-modules/ibmcloud-terratest-wrapper/testhelper"

	utils "github.com/terraform-ibm-modules/terraform-ibm-hpc/common_utils"
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
	// Retrieve cluster information
	expectedClusterID := options.TerraformVars["cluster_id"].(string)
	expectedReservationID := options.TerraformVars["reservation_id"].(string)
	expectedMasterName := options.TerraformVars["cluster_prefix"].(string)
	expectedResourceGroup := options.TerraformVars["resource_group"].(string)
	expectedKeyManagement := options.TerraformVars["key_management"].(string)
	expectedZone := options.TerraformVars["zones"].([]string)[0]
	expectedDnsDomainName, ok := options.TerraformVars["dns_domain_name"].(map[string]string)["compute"]
	assert.False(t, !ok, "Key 'compute' does not exist in dns_domain_name map or dns_domain_name is not of type map[string]string")

	expectedHyperthreadingEnabled, _ := strconv.ParseBool(options.TerraformVars["hyperthreading_enabled"].(string))
	JOB_COMMAND_LOW := GetJobCommand(expectedZone, "low")
	JOB_COMMAND_MED := GetJobCommand(expectedZone, "med")

	// Run the test and handle errors
	output, err := options.RunTestConsistency()
	require.NoError(t, err, "Error running consistency test: %v", err)
	require.NotNil(t, output, "Expected non-nil output, but got nil")

	// Proceed with SSH connection and verification if there are no errors
	testLogger.Info(t, t.Name()+" Cluster created successfully")

	bastionIP, managementNodeIPList, loginNodeIP, ipRetrievalError := utils.GetServerIPs(t, options, testLogger)
	require.NoError(t, ipRetrievalError, "Error occurred while getting server IPs: %v", ipRetrievalError)

	testLogger.Info(t, t.Name()+" Validation started ......")

	// Connect to the master node via SSH and handle connection errors
	sshClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPList[0])
	require.Nil(t, connectionErr, "Failed to connect to the master via SSH: %v", connectionErr)

	testLogger.Info(t, "SSH connection to the master successful")
	t.Log("Validation in progress. Please wait...")

	// Verify management node configuration
	VerifyManagementNodeConfig(t, sshClient, expectedClusterID, expectedMasterName, expectedReservationID, expectedHyperthreadingEnabled, managementNodeIPList, JOB_COMMAND_LOW, EXPECTED_LSF_VERSION, testLogger)

	// Verify SSH key
	VerifySSHKey(t, sshClient, bastionIP, LSF_PUBLIC_HOST_NAME, LSF_PRIVATE_HOST_NAME, "management", managementNodeIPList, testLogger)

	// Perform failover and failback
	FailoverAndFailback(t, sshClient, JOB_COMMAND_MED, testLogger)

	// Restart LSF daemon
	RestartLsfDaemon(t, sshClient, JOB_COMMAND_LOW, testLogger)

	// Reboot instance
	RebootInstance(t, sshClient, bastionIP, LSF_PUBLIC_HOST_NAME, LSF_PRIVATE_HOST_NAME, managementNodeIPList[0], JOB_COMMAND_MED, testLogger)

	// Connect to the master node via SSH and handle connection errors
	sshClient, connectionErr = utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPList[0])
	require.Nil(t, connectionErr, "Failed to connect to the master via SSH: %v", connectionErr)
	defer sshClient.Close()
	defer func() {
		if err := LSFWaitForDynamicNodeDisappearance(t, sshClient, testLogger); err != nil {
			t.Errorf("Error in LSFWaitForDynamicNodeDisappearance: %v", err)
		}
	}()

	// Get dynamic compute node IPs and handle errors
	computeNodeIPList, computeIPErr := LSFGETDynamicComputeNodeIPs(t, sshClient, testLogger)
	require.Nil(t, computeIPErr, "Error getting dynamic compute node IPs: %v", computeIPErr)

	// Verify compute node configuration
	VerifyComputetNodeConfig(t, sshClient, expectedHyperthreadingEnabled, computeNodeIPList, testLogger)

	// Verify SSH key
	VerifySSHKey(t, sshClient, bastionIP, LSF_PUBLIC_HOST_NAME, LSF_PRIVATE_HOST_NAME, "compute", computeNodeIPList, testLogger)

	// Connect to the login node via SSH and handle connection errors
	sshLoginNodeClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, loginNodeIP)
	require.NoError(t, connectionErr, "Failed to connect to the login node via SSH: %v", connectionErr)
	defer sshLoginNodeClient.Close()

	// Verify login node configuration
	VerifyLoginNodeConfig(t, sshLoginNodeClient, expectedClusterID, expectedMasterName, expectedReservationID, expectedHyperthreadingEnabled, loginNodeIP, JOB_COMMAND_LOW, EXPECTED_LSF_VERSION, testLogger)

	// Get dynamic compute node IPs and handle errors
	computeNodeIPList, computeIPErr = LSFGETDynamicComputeNodeIPs(t, sshClient, testLogger)
	require.Nil(t, computeIPErr, "Error getting dynamic compute node IPs: %v", computeIPErr)

	// Verify SSH connectivity to nodes from login
	VerifySSHConnectivityToNodesFromLogin(t, sshLoginNodeClient, managementNodeIPList, computeNodeIPList, testLogger)

	// Verify PTR records
	VerifyPTRRecordsForManagementAndLoginNodes(t, sshClient, LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPList, loginNodeIP, expectedDnsDomainName, testLogger)

	// Verify file share encryption
	VerifyFileShareEncryption(t, os.Getenv("TF_VAR_ibmcloud_api_key"), utils.GetRegion(expectedZone), expectedResourceGroup, expectedMasterName, expectedKeyManagement, testLogger)
	testLogger.Info(t, t.Name()+" Validation ended")
}

// ValidateClusterConfigurationWithAPPCenter performs validation tasks on the cluster configuration
// with additional verification for an application center.
// It extends the validation performed by ValidateClusterConfiguration to include checks for the application center configuration.
// It connects to various cluster components via SSH and verifies their configurations and functionality.
// This includes the following validations:
// - Management Node: Verifies the configuration of the management node, including failover and failback procedures.
// - Compute Nodes: Ensures proper configuration and SSH connectivity to compute nodes.
// - Login Node: Validates the configuration and SSH connectivity to the login node.
// - Dynamic Compute Nodes: Verifies the proper setup and functionality of dynamic compute nodes.
// Additionally, this function logs detailed information throughout the validation process.
// This function doesn't return any value but logs errors and validation steps during the process.
func ValidateClusterConfigurationWithAPPCenter(t *testing.T, options *testhelper.TestOptions, testLogger *utils.AggregatedLogger) {
	// Retrieve cluster information
	expectedClusterID := options.TerraformVars["cluster_id"].(string)
	expectedReservationID := options.TerraformVars["reservation_id"].(string)
	expectedMasterName := options.TerraformVars["cluster_prefix"].(string)
	expectedResourceGroup := options.TerraformVars["resource_group"].(string)
	expectedKeyManagement := options.TerraformVars["key_management"].(string)
	expectedZone := options.TerraformVars["zones"].([]string)[0]
	expectedDnsDomainName, ok := options.TerraformVars["dns_domain_name"].(map[string]string)["compute"]
	assert.False(t, !ok, "Key 'compute' does not exist in dns_domain_name map or dns_domain_name is not of type map[string]string")
	expectedHyperthreadingEnabled, _ := strconv.ParseBool(options.TerraformVars["hyperthreading_enabled"].(string))
	JOB_COMMAND_LOW := GetJobCommand(expectedZone, "low")
	JOB_COMMAND_MED := GetJobCommand(expectedZone, "med")

	// Run the test and handle errors
	output, err := options.RunTestConsistency()
	require.NoError(t, err, "Error running consistency test: %v", err)
	require.NotNil(t, output, "Expected non-nil output, but got nil")

	// Proceed with SSH connection and verification if there are no errors
	testLogger.Info(t, t.Name()+" Cluster created successfully")

	bastionIP, managementNodeIPList, loginNodeIP, ipRetrievalError := utils.GetServerIPs(t, options, testLogger)
	require.NoError(t, ipRetrievalError, "Error occurred while getting server IPs: %v", ipRetrievalError)

	testLogger.Info(t, t.Name()+" Validation started ......")

	// Connect to the master node via SSH and handle connection errors
	sshClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPList[0])
	require.Nil(t, connectionErr, "Failed to connect to the master via SSH: %v", connectionErr)

	testLogger.Info(t, "SSH connection to the master successful")
	t.Log("Validation in progress. Please wait...")

	// Verify management node configuration
	VerifyManagementNodeConfig(t, sshClient, expectedClusterID, expectedMasterName, expectedReservationID, expectedHyperthreadingEnabled, managementNodeIPList, JOB_COMMAND_LOW, EXPECTED_LSF_VERSION, testLogger)

	// Verify SSH key
	VerifySSHKey(t, sshClient, bastionIP, LSF_PUBLIC_HOST_NAME, LSF_PRIVATE_HOST_NAME, "management", managementNodeIPList, testLogger)

	// Perform failover and failback
	FailoverAndFailback(t, sshClient, JOB_COMMAND_MED, testLogger)

	// Restart LSF daemon
	RestartLsfDaemon(t, sshClient, JOB_COMMAND_LOW, testLogger)

	// Reboot instance
	RebootInstance(t, sshClient, bastionIP, LSF_PUBLIC_HOST_NAME, LSF_PRIVATE_HOST_NAME, managementNodeIPList[0], JOB_COMMAND_MED, testLogger)

	// Connect to the master node via SSH and handle connection errors
	sshClient, connectionErr = utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPList[0])
	require.Nil(t, connectionErr, "Failed to connect to the master via SSH: %v", connectionErr)
	defer sshClient.Close()
	defer func() {
		if err := LSFWaitForDynamicNodeDisappearance(t, sshClient, testLogger); err != nil {
			t.Errorf("Error in LSFWaitForDynamicNodeDisappearance: %v", err)
		}
	}()

	// Get dynamic compute node IPs and handle errors
	computeNodeIPList, computeIPErr := LSFGETDynamicComputeNodeIPs(t, sshClient, testLogger)
	require.Nil(t, computeIPErr, "Error getting dynamic compute node IPs: %v", computeIPErr)

	// Verify compute node configuration
	VerifyComputetNodeConfig(t, sshClient, expectedHyperthreadingEnabled, computeNodeIPList, testLogger)

	// Verify SSH key
	VerifySSHKey(t, sshClient, bastionIP, LSF_PUBLIC_HOST_NAME, LSF_PRIVATE_HOST_NAME, "compute", computeNodeIPList, testLogger)

	// Connect to the login node via SSH and handle connection errors
	sshLoginNodeClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, loginNodeIP)
	require.NoError(t, connectionErr, "Failed to connect to the login node via SSH: %v", connectionErr)
	defer sshLoginNodeClient.Close()

	// Verify login node configuration
	VerifyLoginNodeConfig(t, sshLoginNodeClient, expectedClusterID, expectedMasterName, expectedReservationID, expectedHyperthreadingEnabled, loginNodeIP, JOB_COMMAND_LOW, EXPECTED_LSF_VERSION, testLogger)

	// Get dynamic compute node IPs and handle errors
	computeNodeIPList, computeIPErr = LSFGETDynamicComputeNodeIPs(t, sshClient, testLogger)
	require.Nil(t, computeIPErr, "Error getting dynamic compute node IPs: %v", computeIPErr)

	// Verify SSH connectivity to nodes from login
	VerifySSHConnectivityToNodesFromLogin(t, sshLoginNodeClient, managementNodeIPList, computeNodeIPList, testLogger)

	// Verify application center configuration
	VerifyAPPCenterConfig(t, sshClient, testLogger)

	// Verify noVNC configuration
	VerifyNoVNCConfig(t, sshClient, testLogger)

	// Verify PTR records
	VerifyPTRRecordsForManagementAndLoginNodes(t, sshClient, LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPList, loginNodeIP, expectedDnsDomainName, testLogger)

	// Verify file share encryption
	VerifyFileShareEncryption(t, os.Getenv("TF_VAR_ibmcloud_api_key"), utils.GetRegion(expectedZone), expectedResourceGroup, expectedMasterName, expectedKeyManagement, testLogger)

	testLogger.Info(t, t.Name()+" Validation ended")
}

// ValidateBasicClusterConfiguration validates basic cluster configuration.
// It performs validation tasks on essential aspects of the cluster setup,
// including the management node, compute nodes, and login node configurations.
// Additionally, it ensures proper connectivity and functionality.
// This function doesn't return any value but logs errors and validation steps during the process.
func ValidateBasicClusterConfiguration(t *testing.T, options *testhelper.TestOptions, testLogger *utils.AggregatedLogger) {
	// Retrieve cluster information
	expectedClusterID := options.TerraformVars["cluster_id"].(string)
	expectedReservationID := options.TerraformVars["reservation_id"].(string)
	expectedMasterName := options.TerraformVars["cluster_prefix"].(string)
	expectedResourceGroup := options.TerraformVars["resource_group"].(string)
	expectedKeyManagement := options.TerraformVars["key_management"].(string)
	expectedZone := options.TerraformVars["zones"].([]string)[0]

	expectedHyperthreadingEnabled, _ := strconv.ParseBool(options.TerraformVars["hyperthreading_enabled"].(string))

	JOB_COMMAND_LOW := GetJobCommand(expectedZone, "low")

	// Run the test and handle errors
	output, err := options.RunTest()
	require.NoError(t, err, "Error running consistency test: %v", err)
	require.NotNil(t, output, "Expected non-nil output, but got nil")

	// Proceed with SSH connection and verification if there are no errors
	testLogger.Info(t, t.Name()+" Cluster created successfully")

	bastionIP, managementNodeIPList, loginNodeIP, ipRetrievalError := utils.GetServerIPs(t, options, testLogger)
	require.NoError(t, ipRetrievalError, "Error occurred while getting server IPs: %v", ipRetrievalError)

	testLogger.Info(t, t.Name()+" Validation started ......")

	// Connect to the master node via SSH and handle connection errors
	sshClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPList[0])
	require.Nil(t, connectionErr, "Failed to connect to the master via SSH: %v", connectionErr)

	testLogger.Info(t, "SSH connection to the master successful")
	t.Log("Validation in progress. Please wait...")

	// Verify management node configuration
	VerifyManagementNodeConfig(t, sshClient, expectedClusterID, expectedMasterName, expectedReservationID, expectedHyperthreadingEnabled, managementNodeIPList, JOB_COMMAND_LOW, EXPECTED_LSF_VERSION, testLogger)

	// Connect to the master node via SSH and handle connection errors
	sshClient, connectionErr = utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPList[0])
	require.Nil(t, connectionErr, "Failed to connect to the master via SSH: %v", connectionErr)
	defer sshClient.Close()
	defer func() {
		if err := LSFWaitForDynamicNodeDisappearance(t, sshClient, testLogger); err != nil {
			t.Errorf("Error in LSFWaitForDynamicNodeDisappearance: %v", err)
		}
	}()

	// Get dynamic compute node IPs and handle errors
	computeNodeIPList, computeIPErr := LSFGETDynamicComputeNodeIPs(t, sshClient, testLogger)
	require.Nil(t, computeIPErr, "Error getting dynamic compute node IPs: %v", computeIPErr)

	// Verify compute node configuration
	VerifyComputetNodeConfig(t, sshClient, expectedHyperthreadingEnabled, computeNodeIPList, testLogger)

	// Connect to the login node via SSH and handle connection errors
	sshLoginNodeClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, loginNodeIP)
	require.NoError(t, connectionErr, "Failed to connect to the login node via SSH: %v", connectionErr)
	defer sshLoginNodeClient.Close()

	// Verify login node configuration
	VerifyLoginNodeConfig(t, sshLoginNodeClient, expectedClusterID, expectedMasterName, expectedReservationID, expectedHyperthreadingEnabled, loginNodeIP, JOB_COMMAND_LOW, EXPECTED_LSF_VERSION, testLogger)

	// Verify file share encryption
	VerifyFileShareEncryption(t, os.Getenv("TF_VAR_ibmcloud_api_key"), utils.GetRegion(expectedZone), expectedResourceGroup, expectedMasterName, expectedKeyManagement, testLogger)

	testLogger.Info(t, t.Name()+" Validation ended")
}

// ValidateLDAPClusterConfiguration performs comprehensive validation on the cluster setup.
// It connects to various cluster components via SSH and verifies their configurations and functionality.
// This includes the following validations:
// - Management Node: Verifies the configuration of the management node, including failover and failback procedures.
// - Compute Nodes: Ensures proper configuration and SSH connectivity to compute nodes.
// - Login Node: Validates the configuration and SSH connectivity to the login node.
// - Dynamic Compute Nodes: Verifies the proper setup and functionality of dynamic compute nodes.
// Additionally, this function logs detailed information throughout the validation process.
// This function doesn't return any value but logs errors and validation steps during the process.
func ValidateLDAPClusterConfiguration(t *testing.T, options *testhelper.TestOptions, testLogger *utils.AggregatedLogger) {
	// Retrieve cluster information
	expectedClusterID := options.TerraformVars["cluster_id"].(string)
	expectedReservationID := options.TerraformVars["reservation_id"].(string)
	expectedMasterName := options.TerraformVars["cluster_prefix"].(string)
	expectedResourceGroup := options.TerraformVars["resource_group"].(string)
	expectedKeyManagement := options.TerraformVars["key_management"].(string)
	expectedLdapDomain := options.TerraformVars["ldap_basedns"].(string)
	expectedLdapAdminPassword := options.TerraformVars["ldap_admin_password"].(string)
	expectedLdapUserName := options.TerraformVars["ldap_user_name"].(string)
	expectedLdapUserPassword := options.TerraformVars["ldap_user_password"].(string)
	expectedDnsDomainName, ok := options.TerraformVars["dns_domain_name"].(map[string]string)["compute"]
	assert.False(t, !ok, "Key 'compute' does not exist in dns_domain_name map or dns_domain_name is not of type map[string]string")

	expectedZone := options.TerraformVars["zones"].([]string)[0]

	expectedHyperthreadingEnabled, _ := strconv.ParseBool(options.TerraformVars["hyperthreading_enabled"].(string))
	JOB_COMMAND_LOW := GetJobCommand(expectedZone, "low")
	JOB_COMMAND_MED := GetJobCommand(expectedZone, "med")

	// Run the test and handle errors
	output, err := options.RunTestConsistency()
	require.NoError(t, err, "Error running consistency test: %v", err)
	require.NotNil(t, output, "Expected non-nil output, but got nil")

	// Proceed with SSH connection and verification if there are no errors
	testLogger.Info(t, t.Name()+" Cluster created successfully")

	// Get server IPs and handle errors
	bastionIP, managementNodeIPList, loginNodeIP, LdapServerIP, ipRetrievalError := utils.GetServerIPsWithLDAP(t, options, testLogger)
	require.NoError(t, ipRetrievalError, "Error occurred while getting server IPs: %v", ipRetrievalError)

	testLogger.Info(t, t.Name()+" Validation started")

	// Connect to the master node via SSH and handle connection errors
	sshClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPList[0])
	require.Nil(t, connectionErr, "Failed to connect to the master via SSH: %v", connectionErr)

	testLogger.Info(t, "SSH connection to the master successful")
	t.Log("Validation in progress. Please wait...")

	// Verify management node configuration
	VerifyManagementNodeConfig(t, sshClient, expectedClusterID, expectedMasterName, expectedReservationID, expectedHyperthreadingEnabled, managementNodeIPList, JOB_COMMAND_LOW, EXPECTED_LSF_VERSION, testLogger)

	// Verify SSH key
	VerifySSHKey(t, sshClient, bastionIP, LSF_PUBLIC_HOST_NAME, LSF_PRIVATE_HOST_NAME, "management", managementNodeIPList, testLogger)

	// Perform failover and failback
	FailoverAndFailback(t, sshClient, JOB_COMMAND_MED, testLogger)

	// Restart LSF daemon
	RestartLsfDaemon(t, sshClient, JOB_COMMAND_LOW, testLogger)

	// Reboot instance
	RebootInstance(t, sshClient, bastionIP, LSF_PUBLIC_HOST_NAME, LSF_PRIVATE_HOST_NAME, managementNodeIPList[0], JOB_COMMAND_MED, testLogger)

	// Connect to the master node via SSH and handle connection errors
	sshClient, connectionErr = utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPList[0])
	require.Nil(t, connectionErr, "Failed to connect to the master via SSH: %v", connectionErr)
	defer sshClient.Close()
	defer func() {
		if err := LSFWaitForDynamicNodeDisappearance(t, sshClient, testLogger); err != nil {
			t.Errorf("Error in LSFWaitForDynamicNodeDisappearance: %v", err)
		}
	}()

	// Get dynamic compute node IPs and handle errors
	computeNodeIPList, computeIPErr := LSFGETDynamicComputeNodeIPs(t, sshClient, testLogger)
	require.Nil(t, computeIPErr, "Error getting dynamic compute node IPs: %v", computeIPErr)

	// Verify compute node configuration
	VerifyComputetNodeConfig(t, sshClient, expectedHyperthreadingEnabled, computeNodeIPList, testLogger)

	// Verify SSH key
	VerifySSHKey(t, sshClient, bastionIP, LSF_PUBLIC_HOST_NAME, LSF_PRIVATE_HOST_NAME, "compute", computeNodeIPList, testLogger)

	// Connect to the login node via SSH and handle connection errors
	sshLoginNodeClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, loginNodeIP)
	require.NoError(t, connectionErr, "Failed to connect to the login node via SSH: %v", connectionErr)

	// Verify login node configuration
	VerifyLoginNodeConfig(t, sshLoginNodeClient, expectedClusterID, expectedMasterName, expectedReservationID, expectedHyperthreadingEnabled, loginNodeIP, JOB_COMMAND_LOW, EXPECTED_LSF_VERSION, testLogger)

	// Verify SSH connectivity to nodes from login
	VerifySSHConnectivityToNodesFromLogin(t, sshLoginNodeClient, managementNodeIPList, computeNodeIPList, testLogger)

	// Verify file share encryption
	VerifyFileShareEncryption(t, os.Getenv("TF_VAR_ibmcloud_api_key"), utils.GetRegion(expectedZone), expectedResourceGroup, expectedMasterName, expectedKeyManagement, testLogger)

	// Connect to the ldap server via SSH and handle connection errors
	sshLdapClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_LDAP_HOST_NAME, LdapServerIP)
	require.NoError(t, connectionErr, "Failed to connect to the ldap server via SSH: %v", connectionErr)

	// Check ldap server status
	CheckLDAPServerStatus(t, sshLdapClient, expectedLdapAdminPassword, expectedLdapDomain, expectedLdapUserName, testLogger)

	// Verify management node ldap config
	VerifyManagementNodeLDAPConfig(t, sshClient, bastionIP, LdapServerIP, managementNodeIPList, JOB_COMMAND_LOW, expectedLdapDomain, expectedLdapUserName, expectedLdapUserPassword, testLogger)

	// Verify login node ldap config
	VerifyLoginNodeLDAPConfig(t, sshClient, bastionIP, loginNodeIP, LdapServerIP, JOB_COMMAND_LOW, expectedLdapDomain, expectedLdapUserName, expectedLdapUserPassword, testLogger)

	// Verify PTR records
	VerifyPTRRecordsForManagementAndLoginNodes(t, sshClient, LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPList, loginNodeIP, expectedDnsDomainName, testLogger)

	// Verify compute node ldap config
	VerifyComputeNodeLDAPConfig(t, bastionIP, LdapServerIP, computeNodeIPList, expectedLdapDomain, expectedLdapUserName, expectedLdapUserPassword, testLogger)

	testLogger.Info(t, t.Name()+" Validation ended")
}

// ValidatePACANDLDAPClusterConfiguration performs comprehensive validation on the PAC and LDAP cluster setup.
// It connects to various cluster components via SSH and verifies their configurations and functionality.
// This includes the following validations:
// - Management Node: Verifies the configuration of the management node, including failover and failback procedures.
// - Compute Nodes: Ensures proper configuration and SSH connectivity to compute nodes.
// - Login Node: Validates the configuration and SSH connectivity to the login node.
// - Dynamic Compute Nodes: Verifies the proper setup and functionality of dynamic compute nodes.
// - LDAP Server: Checks the LDAP server status and verifies LDAP configurations across nodes.
// - Application Center: Verifies the application center configuration.
// - noVNC: Verifies the noVNC configuration.
// Additionally, this function logs detailed information throughout the validation process.
// This function doesn't return any value but logs errors and validation steps during the process.
func ValidatePACANDLDAPClusterConfiguration(t *testing.T, options *testhelper.TestOptions, testLogger *utils.AggregatedLogger) {
	// Retrieve cluster information
	expectedClusterID := options.TerraformVars["cluster_id"].(string)
	expectedReservationID := options.TerraformVars["reservation_id"].(string)
	expectedMasterName := options.TerraformVars["cluster_prefix"].(string)
	expectedResourceGroup := options.TerraformVars["resource_group"].(string)
	expectedKeyManagement := options.TerraformVars["key_management"].(string)
	expectedLdapDomain := options.TerraformVars["ldap_basedns"].(string)
	expectedLdapAdminPassword := options.TerraformVars["ldap_admin_password"].(string)
	expectedLdapUserName := options.TerraformVars["ldap_user_name"].(string)
	expectedLdapUserPassword := options.TerraformVars["ldap_user_password"].(string)
	expectedDnsDomainName, ok := options.TerraformVars["dns_domain_name"].(map[string]string)["compute"]
	assert.False(t, !ok, "Key 'compute' does not exist in dns_domain_name map or dns_domain_name is not of type map[string]string")

	expectedZone := options.TerraformVars["zones"].([]string)[0]

	expectedHyperthreadingEnabled, _ := strconv.ParseBool(options.TerraformVars["hyperthreading_enabled"].(string))
	JOB_COMMAND_LOW := GetJobCommand(expectedZone, "low")
	JOB_COMMAND_MED := GetJobCommand(expectedZone, "med")

	// Run the test and handle errors
	output, err := options.RunTestConsistency()
	require.NoError(t, err, "Error running consistency test: %v", err)
	require.NotNil(t, output, "Expected non-nil output, but got nil")

	// Proceed with SSH connection and verification if there are no errors
	testLogger.Info(t, t.Name()+" Cluster created successfully")

	// Get server IPs and handle errors
	bastionIP, managementNodeIPList, loginNodeIP, LdapServerIP, ipRetrievalError := utils.GetServerIPsWithLDAP(t, options, testLogger)
	require.NoError(t, ipRetrievalError, "Error occurred while getting server IPs: %v", ipRetrievalError)

	testLogger.Info(t, t.Name()+" Validation started")

	// Connect to the master node via SSH and handle connection errors
	sshClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPList[0])
	require.Nil(t, connectionErr, "Failed to connect to the master via SSH: %v", connectionErr)

	testLogger.Info(t, "SSH connection to the master successful")
	t.Log("Validation in progress. Please wait...")

	// Verify management node configuration
	VerifyManagementNodeConfig(t, sshClient, expectedClusterID, expectedMasterName, expectedReservationID, expectedHyperthreadingEnabled, managementNodeIPList, JOB_COMMAND_LOW, EXPECTED_LSF_VERSION, testLogger)

	// Verify SSH key
	VerifySSHKey(t, sshClient, bastionIP, LSF_PUBLIC_HOST_NAME, LSF_PRIVATE_HOST_NAME, "management", managementNodeIPList, testLogger)

	// Perform failover and failback
	FailoverAndFailback(t, sshClient, JOB_COMMAND_MED, testLogger)

	// Restart LSF daemon
	RestartLsfDaemon(t, sshClient, JOB_COMMAND_LOW, testLogger)

	// Reboot instance
	RebootInstance(t, sshClient, bastionIP, LSF_PUBLIC_HOST_NAME, LSF_PRIVATE_HOST_NAME, managementNodeIPList[0], JOB_COMMAND_MED, testLogger)

	// Connect to the master node via SSH and handle connection errors
	sshClient, connectionErr = utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPList[0])
	require.Nil(t, connectionErr, "Failed to connect to the master via SSH: %v", connectionErr)
	defer sshClient.Close()
	defer func() {
		if err := LSFWaitForDynamicNodeDisappearance(t, sshClient, testLogger); err != nil {
			t.Errorf("Error in LSFWaitForDynamicNodeDisappearance: %v", err)
		}
	}()

	// Get dynamic compute node IPs and handle errors
	computeNodeIPList, computeIPErr := LSFGETDynamicComputeNodeIPs(t, sshClient, testLogger)
	require.Nil(t, computeIPErr, "Error getting dynamic compute node IPs: %v", computeIPErr)

	// Verify compute node configuration
	VerifyComputetNodeConfig(t, sshClient, expectedHyperthreadingEnabled, computeNodeIPList, testLogger)

	// Verify SSH key
	VerifySSHKey(t, sshClient, bastionIP, LSF_PUBLIC_HOST_NAME, LSF_PRIVATE_HOST_NAME, "compute", computeNodeIPList, testLogger)

	// Connect to the login node via SSH and handle connection errors
	sshLoginNodeClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, loginNodeIP)
	require.NoError(t, connectionErr, "Failed to connect to the login node via SSH: %v", connectionErr)

	// Verify login node configuration
	VerifyLoginNodeConfig(t, sshLoginNodeClient, expectedClusterID, expectedMasterName, expectedReservationID, expectedHyperthreadingEnabled, loginNodeIP, JOB_COMMAND_LOW, EXPECTED_LSF_VERSION, testLogger)

	// Verify SSH connectivity to nodes from login
	VerifySSHConnectivityToNodesFromLogin(t, sshLoginNodeClient, managementNodeIPList, computeNodeIPList, testLogger)

	// Verify file share encryption
	VerifyFileShareEncryption(t, os.Getenv("TF_VAR_ibmcloud_api_key"), utils.GetRegion(expectedZone), expectedResourceGroup, expectedMasterName, expectedKeyManagement, testLogger)

	// Verify application center configuration
	VerifyAPPCenterConfig(t, sshClient, testLogger)

	// Verify noVNC configuration
	VerifyNoVNCConfig(t, sshClient, testLogger)

	// Connect to the ldap server via SSH and handle connection errors
	sshLdapClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_LDAP_HOST_NAME, LdapServerIP)
	require.NoError(t, connectionErr, "Failed to connect to the ldap server via SSH: %v", connectionErr)

	// Check ldap server status
	CheckLDAPServerStatus(t, sshLdapClient, expectedLdapAdminPassword, expectedLdapDomain, expectedLdapUserName, testLogger)

	// Verify management node ldap config
	VerifyManagementNodeLDAPConfig(t, sshClient, bastionIP, LdapServerIP, managementNodeIPList, JOB_COMMAND_LOW, expectedLdapDomain, expectedLdapUserName, expectedLdapUserPassword, testLogger)

	// Verify login node ldap config
	VerifyLoginNodeLDAPConfig(t, sshClient, bastionIP, loginNodeIP, LdapServerIP, JOB_COMMAND_LOW, expectedLdapDomain, expectedLdapUserName, expectedLdapUserPassword, testLogger)

	// Verify PTR records
	VerifyPTRRecordsForManagementAndLoginNodes(t, sshClient, LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPList, loginNodeIP, expectedDnsDomainName, testLogger)

	// Verify compute node ldap config
	VerifyComputeNodeLDAPConfig(t, bastionIP, LdapServerIP, computeNodeIPList, expectedLdapDomain, expectedLdapUserName, expectedLdapUserPassword, testLogger)

	testLogger.Info(t, t.Name()+" Validation ended")
}
