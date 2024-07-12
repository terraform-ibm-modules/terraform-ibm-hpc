package tests

import (
	"os"
	"strconv"
	"testing"

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
	// Retrieve cluster information from options
	expectedClusterID := options.TerraformVars["cluster_id"].(string)
	expectedReservationID := options.TerraformVars["reservation_id"].(string)
	expectedMasterName := options.TerraformVars["cluster_prefix"].(string)
	expectedResourceGroup := options.TerraformVars["resource_group"].(string)
	expectedKeyManagement := options.TerraformVars["key_management"].(string)
	expectedZone := options.TerraformVars["zones"].([]string)[0]
	expectedNumOfKeys := len(options.TerraformVars["compute_ssh_keys"].([]string))
	expectedDnsDomainName, ok := options.TerraformVars["dns_domain_name"].(map[string]string)["compute"]
	require.True(t, ok, "Key 'compute' does not exist in dns_domain_name map or dns_domain_name is not of type map[string]string")

	expectedHyperthreadingEnabled, err := strconv.ParseBool(options.TerraformVars["hyperthreading_enabled"].(string))
	require.NoError(t, err, "Error parsing hyperthreading_enabled: %v", err)

	JOB_COMMAND_LOW := GetJobCommand(expectedZone, "low")
	JOB_COMMAND_MED := GetJobCommand(expectedZone, "med")

	// Run the test consistency check
	output, err := options.RunTestConsistency()
	require.NoError(t, err, "Error running consistency test: %v", err)
	require.NotNil(t, output, "Expected non-nil output, but got nil")

	// Log successful cluster creation
	testLogger.Info(t, t.Name()+" Cluster created successfully")

	// Retrieve server IPs
	bastionIP, managementNodeIPList, loginNodeIP, ipRetrievalError := utils.GetServerIPs(t, options, testLogger)
	require.NoError(t, ipRetrievalError, "Error occurred while getting server IPs: %v", ipRetrievalError)

	// Log validation start
	testLogger.Info(t, t.Name()+" Validation started ......")

	// Connect to the master node via SSH and handle connection errors
	sshClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPList[0])
	require.NoError(t, connectionErr, "Failed to connect to the master via SSH: %v", connectionErr)
	defer sshClient.Close()

	testLogger.Info(t, "SSH connection to the master successful")
	t.Log("Validation in progress. Please wait...")

	// Verify management node configuration
	VerifyManagementNodeConfig(t, sshClient, expectedClusterID, expectedMasterName, expectedReservationID, expectedHyperthreadingEnabled, managementNodeIPList, JOB_COMMAND_LOW, EXPECTED_LSF_VERSION, testLogger)

	// Verify SSH key on management nodes
	VerifySSHKey(t, sshClient, bastionIP, LSF_PUBLIC_HOST_NAME, LSF_PRIVATE_HOST_NAME, "management", managementNodeIPList, expectedNumOfKeys, testLogger)

	// Verify LSF DNS on management nodes
	VerifyLSFDNS(t, sshClient, managementNodeIPList, expectedDnsDomainName, testLogger)

	// Perform failover and failback
	FailoverAndFailback(t, sshClient, JOB_COMMAND_MED, testLogger)

	// Restart LSF daemon
	RestartLsfDaemon(t, sshClient, JOB_COMMAND_LOW, testLogger)

	// Reboot instance
	RebootInstance(t, sshClient, bastionIP, LSF_PUBLIC_HOST_NAME, LSF_PRIVATE_HOST_NAME, managementNodeIPList[0], JOB_COMMAND_MED, testLogger)

	// Reconnect to the management node after reboot
	sshClient, connectionErr = utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPList[0])
	require.NoError(t, connectionErr, "Failed to reconnect to the master via SSH: %v", connectionErr)
	defer sshClient.Close()

	// Wait for dynamic node disappearance and handle potential errors
	defer func() {
		if err := LSFWaitForDynamicNodeDisappearance(t, sshClient, testLogger); err != nil {
			t.Errorf("Error in LSFWaitForDynamicNodeDisappearance: %v", err)
		}
	}()

	// Get dynamic compute node IPs and handle errors
	computeNodeIPList, computeIPErr := LSFGETDynamicComputeNodeIPs(t, sshClient, testLogger)
	require.NoError(t, computeIPErr, "Error getting dynamic compute node IPs: %v", computeIPErr)

	// Verify compute node configuration
	VerifyComputeNodeConfig(t, sshClient, expectedHyperthreadingEnabled, computeNodeIPList, testLogger)

	// Verify SSH key on compute nodes
	VerifySSHKey(t, sshClient, bastionIP, LSF_PUBLIC_HOST_NAME, LSF_PRIVATE_HOST_NAME, "compute", computeNodeIPList, expectedNumOfKeys, testLogger)

	// Verify LSF DNS on compute nodes
	VerifyLSFDNS(t, sshClient, computeNodeIPList, expectedDnsDomainName, testLogger)

	// Verify SSH connectivity from login node and handle connection errors
	sshLoginNodeClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, loginNodeIP)
	require.NoError(t, connectionErr, "Failed to connect to the login node via SSH: %v", connectionErr)
	defer sshLoginNodeClient.Close()

	// Verify login node configuration
	VerifyLoginNodeConfig(t, sshLoginNodeClient, expectedClusterID, expectedMasterName, expectedReservationID, expectedHyperthreadingEnabled, loginNodeIP, JOB_COMMAND_LOW, EXPECTED_LSF_VERSION, testLogger)

	// Get dynamic compute node IPs and handle errors
	computeNodeIPList, computeIPErr = LSFGETDynamicComputeNodeIPs(t, sshClient, testLogger)
	require.NoError(t, computeIPErr, "Error getting dynamic compute node IPs: %v", computeIPErr)

	// Verify SSH connectivity from login node
	VerifySSHConnectivityToNodesFromLogin(t, sshLoginNodeClient, managementNodeIPList, computeNodeIPList, testLogger)

	// Verify PTR records
	VerifyPTRRecordsForManagementAndLoginNodes(t, sshClient, LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPList, loginNodeIP, expectedDnsDomainName, testLogger)

	// Verify LSF DNS on login node
	VerifyLSFDNS(t, sshClient, []string{loginNodeIP}, expectedDnsDomainName, testLogger)

	// Verify file share encryption
	VerifyFileShareEncryption(t, os.Getenv("TF_VAR_ibmcloud_api_key"), utils.GetRegion(expectedZone), expectedResourceGroup, expectedMasterName, expectedKeyManagement, testLogger)

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
	// Retrieve cluster information from options
	expectedClusterID := options.TerraformVars["cluster_id"].(string)
	expectedReservationID := options.TerraformVars["reservation_id"].(string)
	expectedMasterName := options.TerraformVars["cluster_prefix"].(string)
	expectedResourceGroup := options.TerraformVars["resource_group"].(string)
	expectedKeyManagement := options.TerraformVars["key_management"].(string)
	expectedZone := options.TerraformVars["zones"].([]string)[0]
	expectedNumOfKeys := len(options.TerraformVars["compute_ssh_keys"].([]string))
	expectedDnsDomainName, ok := options.TerraformVars["dns_domain_name"].(map[string]string)["compute"]
	require.True(t, ok, "Key 'compute' does not exist in dns_domain_name map or dns_domain_name is not of type map[string]string")

	expectedHyperthreadingEnabled, err := strconv.ParseBool(options.TerraformVars["hyperthreading_enabled"].(string))
	require.NoError(t, err, "Error parsing hyperthreading_enabled: %v", err)

	JOB_COMMAND_LOW := GetJobCommand(expectedZone, "low")
	JOB_COMMAND_MED := GetJobCommand(expectedZone, "med")

	// Run the test consistency check
	output, err := options.RunTestConsistency()
	require.NoError(t, err, "Error running consistency test: %v", err)
	require.NotNil(t, output, "Expected non-nil output, but got nil")

	// Log successful cluster creation
	testLogger.Info(t, t.Name()+" Cluster created successfully")

	// Retrieve server IPs
	bastionIP, managementNodeIPList, loginNodeIP, ipRetrievalError := utils.GetServerIPs(t, options, testLogger)
	require.NoError(t, ipRetrievalError, "Error occurred while getting server IPs: %v", ipRetrievalError)

	// Log validation start
	testLogger.Info(t, t.Name()+" Validation started ......")

	// Connect to the master node via SSH and handle connection errors
	sshClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPList[0])
	require.NoError(t, connectionErr, "Failed to connect to the master via SSH: %v", connectionErr)
	defer sshClient.Close()

	testLogger.Info(t, "SSH connection to the master successful")
	t.Log("Validation in progress. Please wait...")

	// Verify management node configuration
	VerifyManagementNodeConfig(t, sshClient, expectedClusterID, expectedMasterName, expectedReservationID, expectedHyperthreadingEnabled, managementNodeIPList, JOB_COMMAND_LOW, EXPECTED_LSF_VERSION, testLogger)

	// Verify SSH key on management nodes
	VerifySSHKey(t, sshClient, bastionIP, LSF_PUBLIC_HOST_NAME, LSF_PRIVATE_HOST_NAME, "management", managementNodeIPList, expectedNumOfKeys, testLogger)

	// Verify LSF DNS on management nodes
	VerifyLSFDNS(t, sshClient, managementNodeIPList, expectedDnsDomainName, testLogger)

	// Perform failover and failback
	FailoverAndFailback(t, sshClient, JOB_COMMAND_MED, testLogger)

	// Restart LSF daemon
	RestartLsfDaemon(t, sshClient, JOB_COMMAND_LOW, testLogger)

	// Reboot instance
	RebootInstance(t, sshClient, bastionIP, LSF_PUBLIC_HOST_NAME, LSF_PRIVATE_HOST_NAME, managementNodeIPList[0], JOB_COMMAND_MED, testLogger)

	// Reconnect to the management node after reboot
	sshClient, connectionErr = utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPList[0])
	require.NoError(t, connectionErr, "Failed to reconnect to the master via SSH: %v", connectionErr)
	defer sshClient.Close()

	// Wait for dynamic node disappearance and handle potential errors
	defer func() {
		if err := LSFWaitForDynamicNodeDisappearance(t, sshClient, testLogger); err != nil {
			t.Errorf("Error in LSFWaitForDynamicNodeDisappearance: %v", err)
		}
	}()

	// Get dynamic compute node IPs and handle errors
	computeNodeIPList, computeIPErr := LSFGETDynamicComputeNodeIPs(t, sshClient, testLogger)
	require.NoError(t, computeIPErr, "Error getting dynamic compute node IPs: %v", computeIPErr)

	// Verify compute node configuration
	VerifyComputeNodeConfig(t, sshClient, expectedHyperthreadingEnabled, computeNodeIPList, testLogger)

	// Verify SSH key on compute nodes
	VerifySSHKey(t, sshClient, bastionIP, LSF_PUBLIC_HOST_NAME, LSF_PRIVATE_HOST_NAME, "compute", computeNodeIPList, expectedNumOfKeys, testLogger)

	// Verify LSF DNS on compute nodes
	VerifyLSFDNS(t, sshClient, computeNodeIPList, expectedDnsDomainName, testLogger)

	// Verify SSH connectivity from login node and handle connection errors
	sshLoginNodeClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, loginNodeIP)
	require.NoError(t, connectionErr, "Failed to connect to the login node via SSH: %v", connectionErr)
	defer sshLoginNodeClient.Close()

	// Verify login node configuration
	VerifyLoginNodeConfig(t, sshLoginNodeClient, expectedClusterID, expectedMasterName, expectedReservationID, expectedHyperthreadingEnabled, loginNodeIP, JOB_COMMAND_LOW, EXPECTED_LSF_VERSION, testLogger)

	// Get dynamic compute node IPs and handle errors
	computeNodeIPList, computeIPErr = LSFGETDynamicComputeNodeIPs(t, sshClient, testLogger)
	require.NoError(t, computeIPErr, "Error getting dynamic compute node IPs: %v", computeIPErr)

	// Verify SSH connectivity from login node
	VerifySSHConnectivityToNodesFromLogin(t, sshLoginNodeClient, managementNodeIPList, computeNodeIPList, testLogger)

	// Verify application center configuration
	VerifyAPPCenterConfig(t, sshClient, testLogger)

	// Verify noVNC configuration
	VerifyNoVNCConfig(t, sshClient, testLogger)

	// Verify PTR records
	VerifyPTRRecordsForManagementAndLoginNodes(t, sshClient, LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPList, loginNodeIP, expectedDnsDomainName, testLogger)

	// Verify LSF DNS on login node
	VerifyLSFDNS(t, sshClient, []string{loginNodeIP}, expectedDnsDomainName, testLogger)

	// Verify file share encryption
	VerifyFileShareEncryption(t, os.Getenv("TF_VAR_ibmcloud_api_key"), utils.GetRegion(expectedZone), expectedResourceGroup, expectedMasterName, expectedKeyManagement, testLogger)

	// Log validation end
	testLogger.Info(t, t.Name()+" Validation ended")
}

// ValidateBasicClusterConfiguration validates basic cluster configuration.
// It performs validation tasks on essential aspects of the cluster setup,
// including the management node, compute nodes, and login node configurations.
// Additionally, it ensures proper connectivity and functionality.
// This function doesn't return any value but logs errors and validation steps during the process.
func ValidateBasicClusterConfiguration(t *testing.T, options *testhelper.TestOptions, testLogger *utils.AggregatedLogger) {
	// Retrieve cluster information from options
	expectedClusterID := options.TerraformVars["cluster_id"].(string)
	expectedReservationID := options.TerraformVars["reservation_id"].(string)
	expectedMasterName := options.TerraformVars["cluster_prefix"].(string)
	expectedResourceGroup := options.TerraformVars["resource_group"].(string)
	expectedKeyManagement := options.TerraformVars["key_management"].(string)
	expectedZone := options.TerraformVars["zones"].([]string)[0]

	expectedHyperthreadingEnabled, err := strconv.ParseBool(options.TerraformVars["hyperthreading_enabled"].(string))
	require.NoError(t, err, "Error parsing hyperthreading_enabled: %v", err)

	JOB_COMMAND_LOW := GetJobCommand(expectedZone, "low")

	// Run the test consistency check
	output, err := options.RunTestConsistency()
	require.NoError(t, err, "Error running consistency test: %v", err)
	require.NotNil(t, output, "Expected non-nil output, but got nil")

	// Log successful cluster creation
	testLogger.Info(t, t.Name()+" Cluster created successfully")

	// Retrieve server IPs
	bastionIP, managementNodeIPList, loginNodeIP, ipRetrievalError := utils.GetServerIPs(t, options, testLogger)
	require.NoError(t, ipRetrievalError, "Error occurred while getting server IPs: %v", ipRetrievalError)

	// Log validation start
	testLogger.Info(t, t.Name()+" Validation started ......")

	// Connect to the master node via SSH and handle connection errors
	sshClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPList[0])
	require.NoError(t, connectionErr, "Failed to connect to the master via SSH: %v", connectionErr)
	defer sshClient.Close()

	testLogger.Info(t, "SSH connection to the master successful")
	t.Log("Validation in progress. Please wait...")

	// Verify management node configuration
	VerifyManagementNodeConfig(t, sshClient, expectedClusterID, expectedMasterName, expectedReservationID, expectedHyperthreadingEnabled, managementNodeIPList, JOB_COMMAND_LOW, EXPECTED_LSF_VERSION, testLogger)

	// Reconnect to the management node after reboot
	sshClient, connectionErr = utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPList[0])
	require.NoError(t, connectionErr, "Failed to reconnect to the master via SSH: %v", connectionErr)
	defer sshClient.Close()

	// Wait for dynamic node disappearance and handle potential errors
	defer func() {
		if err := LSFWaitForDynamicNodeDisappearance(t, sshClient, testLogger); err != nil {
			t.Errorf("Error in LSFWaitForDynamicNodeDisappearance: %v", err)
		}
	}()

	// Get dynamic compute node IPs and handle errors
	computeNodeIPList, computeIPErr := LSFGETDynamicComputeNodeIPs(t, sshClient, testLogger)
	require.NoError(t, computeIPErr, "Error getting dynamic compute node IPs: %v", computeIPErr)

	// Verify compute node configuration
	VerifyComputeNodeConfig(t, sshClient, expectedHyperthreadingEnabled, computeNodeIPList, testLogger)

	// Verify SSH connectivity from login node and handle connection errors
	sshLoginNodeClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, loginNodeIP)
	require.NoError(t, connectionErr, "Failed to connect to the login node via SSH: %v", connectionErr)
	defer sshLoginNodeClient.Close()

	// Verify login node configuration
	VerifyLoginNodeConfig(t, sshLoginNodeClient, expectedClusterID, expectedMasterName, expectedReservationID, expectedHyperthreadingEnabled, loginNodeIP, JOB_COMMAND_LOW, EXPECTED_LSF_VERSION, testLogger)

	// Verify file share encryption
	VerifyFileShareEncryption(t, os.Getenv("TF_VAR_ibmcloud_api_key"), utils.GetRegion(expectedZone), expectedResourceGroup, expectedMasterName, expectedKeyManagement, testLogger)

	// Log validation end
	testLogger.Info(t, t.Name()+" Validation ended")
}

// ValidateLDAPClusterConfiguration performs comprehensive validation on the cluster setup.
// It connects to various cluster components via SSH and verifies their configurations and functionality.
// This includes validations for management nodes, compute nodes, login nodes, dynamic compute nodes, and LDAP integration.
// Additionally, this function logs detailed information throughout the validation process.
// This function doesn't return any value but logs errors and validation steps during the process.
func ValidateLDAPClusterConfiguration(t *testing.T, options *testhelper.TestOptions, testLogger *utils.AggregatedLogger) {
	// Retrieve cluster information from options
	expectedClusterID := options.TerraformVars["cluster_id"].(string)
	expectedReservationID := options.TerraformVars["reservation_id"].(string)
	expectedMasterName := options.TerraformVars["cluster_prefix"].(string)
	expectedResourceGroup := options.TerraformVars["resource_group"].(string)
	expectedKeyManagement := options.TerraformVars["key_management"].(string)
	expectedNumOfKeys := len(options.TerraformVars["compute_ssh_keys"].([]string))
	expectedLdapDomain := options.TerraformVars["ldap_basedns"].(string)
	ldapAdminPassword := options.TerraformVars["ldap_admin_password"].(string)
	ldapUserName := options.TerraformVars["ldap_user_name"].(string)
	ldapUserPassword := options.TerraformVars["ldap_user_password"].(string)
	expectedDnsDomainName, ok := options.TerraformVars["dns_domain_name"].(map[string]string)["compute"]
	require.True(t, ok, "Key 'compute' does not exist in dns_domain_name map or dns_domain_name is not of type map[string]string")

	expectedZone := options.TerraformVars["zones"].([]string)[0]

	expectedHyperthreadingEnabled, err := strconv.ParseBool(options.TerraformVars["hyperthreading_enabled"].(string))
	require.NoError(t, err, "Error parsing hyperthreading_enabled: %v", err)
	JOB_COMMAND_LOW := GetJobCommand(expectedZone, "low")
	JOB_COMMAND_MED := GetJobCommand(expectedZone, "med")

	// Run the test consistency check
	output, err := options.RunTestConsistency()
	require.NoError(t, err, "Error running consistency test: %v", err)
	require.NotNil(t, output, "Expected non-nil output, but got nil")

	// Log successful cluster creation
	testLogger.Info(t, t.Name()+" Cluster created successfully")

	// Retrieve server IPs
	bastionIP, managementNodeIPList, loginNodeIP, ldapServerIP, ipRetrievalError := utils.GetServerIPsWithLDAP(t, options, testLogger)
	require.NoError(t, ipRetrievalError, "Error occurred while getting server IPs: %v", ipRetrievalError)

	// Log validation start
	testLogger.Info(t, t.Name()+" Validation started")

	// Connect to the master node via SSH and handle connection errors
	sshClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPList[0])
	require.NoError(t, connectionErr, "Failed to connect to the master via SSH: %v", connectionErr)
	defer sshClient.Close()

	testLogger.Info(t, "SSH connection to the master successful")
	t.Log("Validation in progress. Please wait...")

	// Verify management node configuration
	VerifyManagementNodeConfig(t, sshClient, expectedClusterID, expectedMasterName, expectedReservationID, expectedHyperthreadingEnabled, managementNodeIPList, JOB_COMMAND_LOW, EXPECTED_LSF_VERSION, testLogger)

	// Verify SSH key on management nodes
	VerifySSHKey(t, sshClient, bastionIP, LSF_PUBLIC_HOST_NAME, LSF_PRIVATE_HOST_NAME, "management", managementNodeIPList, expectedNumOfKeys, testLogger)

	// Perform failover and failback
	FailoverAndFailback(t, sshClient, JOB_COMMAND_MED, testLogger)

	// Restart LSF daemon
	RestartLsfDaemon(t, sshClient, JOB_COMMAND_LOW, testLogger)

	// Reboot instance
	RebootInstance(t, sshClient, bastionIP, LSF_PUBLIC_HOST_NAME, LSF_PRIVATE_HOST_NAME, managementNodeIPList[0], JOB_COMMAND_MED, testLogger)

	// Reconnect to the management node after reboot
	sshClient, connectionErr = utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPList[0])
	require.NoError(t, connectionErr, "Failed to reconnect to the master via SSH: %v", connectionErr)
	defer sshClient.Close()

	// Wait for dynamic node disappearance and handle potential errors
	defer func() {
		if err := LSFWaitForDynamicNodeDisappearance(t, sshClient, testLogger); err != nil {
			t.Errorf("Error in LSFWaitForDynamicNodeDisappearance: %v", err)
		}
	}()

	// Get dynamic compute node IPs and handle errors
	computeNodeIPList, computeIPErr := LSFGETDynamicComputeNodeIPs(t, sshClient, testLogger)
	require.NoError(t, computeIPErr, "Error getting dynamic compute node IPs: %v", computeIPErr)

	// Verify compute node configuration
	VerifyComputeNodeConfig(t, sshClient, expectedHyperthreadingEnabled, computeNodeIPList, testLogger)

	// Verify SSH key on compute nodes
	VerifySSHKey(t, sshClient, bastionIP, LSF_PUBLIC_HOST_NAME, LSF_PRIVATE_HOST_NAME, "compute", computeNodeIPList, expectedNumOfKeys, testLogger)

	// Verify SSH connectivity from login node and handle connection errors
	sshLoginNodeClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, loginNodeIP)
	require.NoError(t, connectionErr, "Failed to connect to the login node via SSH: %v", connectionErr)
	defer sshLoginNodeClient.Close()

	// Verify login node configuration
	VerifyLoginNodeConfig(t, sshLoginNodeClient, expectedClusterID, expectedMasterName, expectedReservationID, expectedHyperthreadingEnabled, loginNodeIP, JOB_COMMAND_LOW, EXPECTED_LSF_VERSION, testLogger)

	// Verify SSH connectivity from login node
	VerifySSHConnectivityToNodesFromLogin(t, sshLoginNodeClient, managementNodeIPList, computeNodeIPList, testLogger)

	// Verify file share encryption
	VerifyFileShareEncryption(t, os.Getenv("TF_VAR_ibmcloud_api_key"), utils.GetRegion(expectedZone), expectedResourceGroup, expectedMasterName, expectedKeyManagement, testLogger)

	// Connect to the LDAP server via SSH and handle connection errors
	sshLdapClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_LDAP_HOST_NAME, ldapServerIP)
	require.NoError(t, connectionErr, "Failed to connect to the LDAP server via SSH: %v", connectionErr)
	defer sshLdapClient.Close()

	// Check LDAP server status
	CheckLDAPServerStatus(t, sshLdapClient, ldapAdminPassword, expectedLdapDomain, ldapUserName, testLogger)

	// Verify management node LDAP config
	VerifyManagementNodeLDAPConfig(t, sshClient, bastionIP, ldapServerIP, managementNodeIPList, JOB_COMMAND_LOW, expectedLdapDomain, ldapUserName, ldapUserPassword, testLogger)

	// Verify compute node LDAP config
	VerifyComputeNodeLDAPConfig(t, bastionIP, ldapServerIP, computeNodeIPList, expectedLdapDomain, ldapUserName, ldapUserPassword, testLogger)

	// Verify login node LDAP config
	VerifyLoginNodeLDAPConfig(t, sshLoginNodeClient, bastionIP, loginNodeIP, ldapServerIP, JOB_COMMAND_LOW, expectedLdapDomain, ldapUserName, ldapUserPassword, testLogger)

	// Verify ability to create LDAP user and perform LSF actions using new user
	VerifyCreateNewLdapUserAndManagementNodeLDAPConfig(t, sshLdapClient, bastionIP, ldapServerIP, managementNodeIPList, JOB_COMMAND_LOW, ldapAdminPassword, expectedLdapDomain, ldapUserName, ldapUserPassword, "user2", testLogger)

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
	// Retrieve cluster information from options
	expectedClusterID := options.TerraformVars["cluster_id"].(string)
	expectedReservationID := options.TerraformVars["reservation_id"].(string)
	expectedMasterName := options.TerraformVars["cluster_prefix"].(string)
	expectedResourceGroup := options.TerraformVars["resource_group"].(string)
	expectedKeyManagement := options.TerraformVars["key_management"].(string)
	expectedNumOfKeys := len(options.TerraformVars["compute_ssh_keys"].([]string))
	expectedLdapDomain := options.TerraformVars["ldap_basedns"].(string)
	ldapAdminPassword := options.TerraformVars["ldap_admin_password"].(string)
	ldapUserName := options.TerraformVars["ldap_user_name"].(string)
	ldapUserPassword := options.TerraformVars["ldap_user_password"].(string)
	expectedDnsDomainName, ok := options.TerraformVars["dns_domain_name"].(map[string]string)["compute"]
	require.True(t, ok, "Key 'compute' does not exist in dns_domain_name map or dns_domain_name is not of type map[string]string")

	expectedZone := options.TerraformVars["zones"].([]string)[0]

	expectedHyperthreadingEnabled, err := strconv.ParseBool(options.TerraformVars["hyperthreading_enabled"].(string))
	require.NoError(t, err, "Error parsing hyperthreading_enabled: %v", err)
	JOB_COMMAND_LOW := GetJobCommand(expectedZone, "low")
	JOB_COMMAND_MED := GetJobCommand(expectedZone, "med")

	// Run the test consistency check
	output, err := options.RunTestConsistency()
	require.NoError(t, err, "Error running consistency test: %v", err)
	require.NotNil(t, output, "Expected non-nil output, but got nil")

	// Log successful cluster creation
	testLogger.Info(t, t.Name()+" Cluster created successfully")

	// Retrieve server IPs
	bastionIP, managementNodeIPList, loginNodeIP, ldapServerIP, ipRetrievalError := utils.GetServerIPsWithLDAP(t, options, testLogger)
	require.NoError(t, ipRetrievalError, "Error occurred while getting server IPs: %v", ipRetrievalError)

	testLogger.Info(t, t.Name()+" Validation started")

	// Connect to the master node via SSH and handle connection errors
	sshClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPList[0])
	require.NoError(t, connectionErr, "Failed to connect to the master via SSH: %v", connectionErr)
	defer sshClient.Close()

	testLogger.Info(t, "SSH connection to the master successful")
	t.Log("Validation in progress. Please wait...")

	// Verify management node configuration
	VerifyManagementNodeConfig(t, sshClient, expectedClusterID, expectedMasterName, expectedReservationID, expectedHyperthreadingEnabled, managementNodeIPList, JOB_COMMAND_LOW, EXPECTED_LSF_VERSION, testLogger)

	// Verify SSH key on management nodes
	VerifySSHKey(t, sshClient, bastionIP, LSF_PUBLIC_HOST_NAME, LSF_PRIVATE_HOST_NAME, "management", managementNodeIPList, expectedNumOfKeys, testLogger)

	// Perform failover and failback
	FailoverAndFailback(t, sshClient, JOB_COMMAND_MED, testLogger)

	// Restart LSF daemon
	RestartLsfDaemon(t, sshClient, JOB_COMMAND_LOW, testLogger)

	// Reboot instance
	RebootInstance(t, sshClient, bastionIP, LSF_PUBLIC_HOST_NAME, LSF_PRIVATE_HOST_NAME, managementNodeIPList[0], JOB_COMMAND_MED, testLogger)

	// Reconnect to the management node after reboot
	sshClient, connectionErr = utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPList[0])
	require.NoError(t, connectionErr, "Failed to reconnect to the master via SSH: %v", connectionErr)
	defer sshClient.Close()

	// Wait for dynamic node disappearance and handle potential errors
	defer func() {
		if err := LSFWaitForDynamicNodeDisappearance(t, sshClient, testLogger); err != nil {
			t.Errorf("Error in LSFWaitForDynamicNodeDisappearance: %v", err)
		}
	}()

	// Get dynamic compute node IPs and handle errors
	computeNodeIPList, computeIPErr := LSFGETDynamicComputeNodeIPs(t, sshClient, testLogger)
	require.NoError(t, computeIPErr, "Error getting dynamic compute node IPs: %v", computeIPErr)

	// Verify compute node configuration
	VerifyComputeNodeConfig(t, sshClient, expectedHyperthreadingEnabled, computeNodeIPList, testLogger)

	// Verify SSH key on compute nodes
	VerifySSHKey(t, sshClient, bastionIP, LSF_PUBLIC_HOST_NAME, LSF_PRIVATE_HOST_NAME, "compute", computeNodeIPList, expectedNumOfKeys, testLogger)

	// Verify SSH connectivity from login node and handle connection errors
	sshLoginNodeClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, loginNodeIP)
	require.NoError(t, connectionErr, "Failed to connect to the login node via SSH: %v", connectionErr)
	defer sshLoginNodeClient.Close()

	// Verify login node configuration
	VerifyLoginNodeConfig(t, sshLoginNodeClient, expectedClusterID, expectedMasterName, expectedReservationID, expectedHyperthreadingEnabled, loginNodeIP, JOB_COMMAND_LOW, EXPECTED_LSF_VERSION, testLogger)

	// Verify SSH connectivity from login node
	VerifySSHConnectivityToNodesFromLogin(t, sshLoginNodeClient, managementNodeIPList, computeNodeIPList, testLogger)

	// Verify file share encryption
	VerifyFileShareEncryption(t, os.Getenv("TF_VAR_ibmcloud_api_key"), utils.GetRegion(expectedZone), expectedResourceGroup, expectedMasterName, expectedKeyManagement, testLogger)

	// Verify application center configuration
	VerifyAPPCenterConfig(t, sshClient, testLogger)

	// Verify noVNC configuration
	VerifyNoVNCConfig(t, sshClient, testLogger)

	// Connect to the LDAP server via SSH and handle connection errors
	sshLdapClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_LDAP_HOST_NAME, ldapServerIP)
	require.NoError(t, connectionErr, "Failed to connect to the LDAP server via SSH: %v", connectionErr)
	defer sshLdapClient.Close()

	// Check LDAP server status
	CheckLDAPServerStatus(t, sshLdapClient, ldapAdminPassword, expectedLdapDomain, ldapUserName, testLogger)

	// Verify management node LDAP config
	VerifyManagementNodeLDAPConfig(t, sshClient, bastionIP, ldapServerIP, managementNodeIPList, JOB_COMMAND_LOW, expectedLdapDomain, ldapUserName, ldapUserPassword, testLogger)

	// Verify compute node LDAP config
	VerifyComputeNodeLDAPConfig(t, bastionIP, ldapServerIP, computeNodeIPList, expectedLdapDomain, ldapUserName, ldapUserPassword, testLogger)

	// Verify login node LDAP config
	VerifyLoginNodeLDAPConfig(t, sshLoginNodeClient, bastionIP, loginNodeIP, ldapServerIP, JOB_COMMAND_LOW, expectedLdapDomain, ldapUserName, ldapUserPassword, testLogger)

	// Verify ability to create LDAP user and perform LSF actions using new user
	VerifyCreateNewLdapUserAndManagementNodeLDAPConfig(t, sshLdapClient, bastionIP, ldapServerIP, managementNodeIPList, JOB_COMMAND_LOW, ldapAdminPassword, expectedLdapDomain, ldapUserName, ldapUserPassword, "user2", testLogger)

	// Verify PTR records
	VerifyPTRRecordsForManagementAndLoginNodes(t, sshClient, LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPList, loginNodeIP, expectedDnsDomainName, testLogger)

	// Log validation end
	testLogger.Info(t, t.Name()+" Validation ended")
}

// ValidateClusterConfigurationWithAPPCenterForExistingEnv validates the configuration of an existing cluster with App Center integration.
// It verifies various aspects including management node configuration, SSH keys, failover and failback, LSF daemon restart, dynamic compute node configuration,
// login node configuration, SSH connectivity, application center configuration, noVNC configuration, PTR records, and file share encryption.
//
// testLogger: *utils.AggregatedLogger - The logger for the test.
func ValidateClusterConfigurationWithAPPCenterForExistingEnv(
	t *testing.T,
	expectedNumOfKeys int,
	bastionIP, loginNodeIP, expectedClusterID, expectedReservationID, expectedMasterName, expectedResourceGroup,
	expectedKeyManagement, expectedZone, expectedDnsDomainName string,
	managementNodeIPList []string,
	expectedHyperthreadingEnabled bool,
	testLogger *utils.AggregatedLogger,
) {
	// Retrieve job commands for different levels
	JOB_COMMAND_LOW := GetJobCommand(expectedZone, "low")
	JOB_COMMAND_MED := GetJobCommand(expectedZone, "med")

	// Log validation start
	testLogger.Info(t, t.Name()+" Validation started ......")

	// Connect to the master node via SSH
	sshClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPList[0])
	require.NoError(t, connectionErr, "Failed to connect to the master via SSH: %v", connectionErr)
	defer sshClient.Close()

	testLogger.Info(t, "SSH connection to the master successful")
	t.Log("Validation in progress. Please wait...")

	// Verify management node configuration
	VerifyManagementNodeConfig(t, sshClient, expectedClusterID, expectedMasterName, expectedReservationID, expectedHyperthreadingEnabled, managementNodeIPList, JOB_COMMAND_LOW, EXPECTED_LSF_VERSION, testLogger)

	// Verify SSH key on management nodes
	VerifySSHKey(t, sshClient, bastionIP, LSF_PUBLIC_HOST_NAME, LSF_PRIVATE_HOST_NAME, "management", managementNodeIPList, expectedNumOfKeys, testLogger)

	// Perform failover and failback
	FailoverAndFailback(t, sshClient, JOB_COMMAND_MED, testLogger)

	// Restart LSF daemon
	RestartLsfDaemon(t, sshClient, JOB_COMMAND_LOW, testLogger)

	// Reboot instance
	RebootInstance(t, sshClient, bastionIP, LSF_PUBLIC_HOST_NAME, LSF_PRIVATE_HOST_NAME, managementNodeIPList[0], JOB_COMMAND_MED, testLogger)

	// Reconnect to the master node via SSH after reboot
	sshClient, connectionErr = utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPList[0])
	require.NoError(t, connectionErr, "Failed to reconnect to the master via SSH: %v", connectionErr)
	defer sshClient.Close()

	// Wait for dynamic node disappearance and handle potential errors
	defer func() {
		if err := LSFWaitForDynamicNodeDisappearance(t, sshClient, testLogger); err != nil {
			t.Errorf("Error in LSFWaitForDynamicNodeDisappearance: %v", err)
		}
	}()

	// Get dynamic compute node IPs
	computeNodeIPList, computeIPErr := LSFGETDynamicComputeNodeIPs(t, sshClient, testLogger)
	require.NoError(t, computeIPErr, "Error getting dynamic compute node IPs: %v", computeIPErr)

	// Verify compute node configuration
	VerifyComputeNodeConfig(t, sshClient, expectedHyperthreadingEnabled, computeNodeIPList, testLogger)

	// Verify SSH key for compute nodes
	VerifySSHKey(t, sshClient, bastionIP, LSF_PUBLIC_HOST_NAME, LSF_PRIVATE_HOST_NAME, "compute", computeNodeIPList, expectedNumOfKeys, testLogger)

	// Verify SSH connectivity from login node
	sshLoginNodeClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, loginNodeIP)
	require.NoError(t, connectionErr, "Failed to connect to the login node via SSH: %v", connectionErr)
	defer sshLoginNodeClient.Close()

	// Verify login node configuration
	VerifyLoginNodeConfig(t, sshLoginNodeClient, expectedClusterID, expectedMasterName, expectedReservationID, expectedHyperthreadingEnabled, loginNodeIP, JOB_COMMAND_LOW, EXPECTED_LSF_VERSION, testLogger)

	// Re-fetch dynamic compute node IPs
	computeNodeIPList, computeIPErr = LSFGETDynamicComputeNodeIPs(t, sshClient, testLogger)
	require.NoError(t, computeIPErr, "Error getting dynamic compute node IPs: %v", computeIPErr)

	// Verify SSH connectivity from login node
	VerifySSHConnectivityToNodesFromLogin(t, sshLoginNodeClient, managementNodeIPList, computeNodeIPList, testLogger)

	// Verify application center configuration
	VerifyAPPCenterConfig(t, sshClient, testLogger)

	// Verify noVNC configuration
	VerifyNoVNCConfig(t, sshClient, testLogger)

	// Verify PTR records for management and login nodes
	VerifyPTRRecordsForManagementAndLoginNodes(t, sshClient, LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPList, loginNodeIP, expectedDnsDomainName, testLogger)

	// Verify file share encryption
	VerifyFileShareEncryption(t, os.Getenv("TF_VAR_ibmcloud_api_key"), utils.GetRegion(expectedZone), expectedResourceGroup, expectedMasterName, expectedKeyManagement, testLogger)

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
	// Retrieve cluster information from options
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

	// Log successful cluster creation
	testLogger.Info(t, t.Name()+" Cluster created successfully")

	// Retrieve server IPs
	bastionIP, managementNodeIPList, loginNodeIP, ipRetrievalError := utils.GetServerIPs(t, options, testLogger)
	require.NoError(t, ipRetrievalError, "Error occurred while getting server IPs: %v", ipRetrievalError)

	// Log validation start
	testLogger.Info(t, t.Name()+" Validation started ......")

	// Connect to the master node via SSH and handle connection errors
	sshClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPList[0])
	require.NoError(t, connectionErr, "Failed to connect to the master via SSH: %v", connectionErr)
	defer sshClient.Close()

	testLogger.Info(t, "SSH connection to the master successful")
	t.Log("Validation in progress. Please wait...")

	// Verify management node configuration
	VerifyManagementNodeConfig(t, sshClient, expectedClusterID, expectedMasterName, expectedReservationID, expectedHyperthreadingEnabled, managementNodeIPList, JOB_COMMAND_LOW, EXPECTED_LSF_VERSION, testLogger)

	// Wait for dynamic node disappearance and handle potential errors
	defer func() {
		if err := LSFWaitForDynamicNodeDisappearance(t, sshClient, testLogger); err != nil {
			t.Errorf("Error in LSFWaitForDynamicNodeDisappearance: %v", err)
		}
	}()

	// Get dynamic compute node IPs
	computeNodeIPList, computeIPErr := LSFGETDynamicComputeNodeIPs(t, sshClient, testLogger)
	require.NoError(t, computeIPErr, "Error getting dynamic compute node IPs: %v", computeIPErr)

	// Verify compute node configuration
	VerifyComputeNodeConfig(t, sshClient, expectedHyperthreadingEnabled, computeNodeIPList, testLogger)

	// Verify SSH connectivity from login node
	sshLoginNodeClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, loginNodeIP)
	require.NoError(t, connectionErr, "Failed to connect to the login node via SSH: %v", connectionErr)
	defer sshLoginNodeClient.Close()

	// Verify login node configuration
	VerifyLoginNodeConfig(t, sshLoginNodeClient, expectedClusterID, expectedMasterName, expectedReservationID, expectedHyperthreadingEnabled, loginNodeIP, JOB_COMMAND_LOW, EXPECTED_LSF_VERSION, testLogger)

	// Verify file share encryption
	VerifyFileShareEncryption(t, os.Getenv("TF_VAR_ibmcloud_api_key"), utils.GetRegion(expectedZone), expectedResourceGroup, expectedMasterName, expectedKeyManagement, testLogger)

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
	// Retrieve cluster information from options
	expectedClusterID := options.TerraformVars["cluster_id"].(string)
	expectedReservationID := options.TerraformVars["reservation_id"].(string)
	expectedMasterName := options.TerraformVars["cluster_prefix"].(string)
	expectedResourceGroup := options.TerraformVars["resource_group"].(string)
	expectedKeyManagement := options.TerraformVars["key_management"].(string)
	expectedZone := options.TerraformVars["zones"].([]string)[0]
	expectedNumOfKeys := len(options.TerraformVars["compute_ssh_keys"].([]string))
	expectedDnsDomainName, ok := options.TerraformVars["dns_domain_name"].(map[string]string)["compute"]
	require.True(t, ok, "Key 'compute' does not exist in dns_domain_name map or dns_domain_name is not of type map[string]string")

	expectedHyperthreadingEnabled, _ := strconv.ParseBool(options.TerraformVars["hyperthreading_enabled"].(string))
	JOB_COMMAND_LOW := GetJobCommand(expectedZone, "low")
	JOB_COMMAND_MED := GetJobCommand(expectedZone, "med")

	// Run the test consistency check
	output, err := options.RunTestConsistency()
	require.NoError(t, err, "Error running consistency test: %v", err)
	require.NotNil(t, output, "Expected non-nil output, but got nil")

	// Log successful cluster creation
	testLogger.Info(t, t.Name()+" Cluster created successfully")

	// Retrieve server IPs
	bastionIP, managementNodeIPList, loginNodeIP, ipRetrievalError := utils.GetServerIPs(t, options, testLogger)
	require.NoError(t, ipRetrievalError, "Error occurred while getting server IPs: %v", ipRetrievalError)

	// Log validation start
	testLogger.Info(t, t.Name()+" Validation started ......")

	// Connect to the management node via SSH
	sshClientOne, sshClientTwo, connectionErrOne, connectionErrTwo := utils.ConnectToHostsWithMultipleUsers(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPList[0])
	require.NoError(t, connectionErrOne, "Failed to connect to the master via SSH: %v", connectionErrOne)
	require.NoError(t, connectionErrTwo, "Failed to connect to the master via SSH: %v", connectionErrTwo)
	defer sshClientOne.Close()
	defer sshClientTwo.Close()

	testLogger.Info(t, "SSH connection to the master successful")
	t.Log("Validation in progress. Please wait...")

	// Verify management node configuration
	VerifyManagementNodeConfig(t, sshClientOne, expectedClusterID, expectedMasterName, expectedReservationID, expectedHyperthreadingEnabled, managementNodeIPList, JOB_COMMAND_LOW, EXPECTED_LSF_VERSION, testLogger)
	VerifyManagementNodeConfig(t, sshClientTwo, expectedClusterID, expectedMasterName, expectedReservationID, expectedHyperthreadingEnabled, managementNodeIPList, JOB_COMMAND_LOW, EXPECTED_LSF_VERSION, testLogger)

	// Verify SSH key on management node
	VerifySSHKey(t, sshClientOne, bastionIP, LSF_PUBLIC_HOST_NAME, LSF_PRIVATE_HOST_NAME, "management", managementNodeIPList, expectedNumOfKeys, testLogger)

	// Perform failover and failback
	FailoverAndFailback(t, sshClientOne, JOB_COMMAND_MED, testLogger)

	// Restart LSF daemon
	RestartLsfDaemon(t, sshClientOne, JOB_COMMAND_LOW, testLogger)

	// Reboot instance
	RebootInstance(t, sshClientOne, bastionIP, LSF_PUBLIC_HOST_NAME, LSF_PRIVATE_HOST_NAME, managementNodeIPList[0], JOB_COMMAND_MED, testLogger)

	// Reconnect to the management node after reboot
	sshClientOne, connectionErrOne = utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPList[0])
	require.NoError(t, connectionErrOne, "Failed to reconnect to the master via SSH: %v", connectionErrOne)
	defer sshClientOne.Close()

	// Wait for dynamic node disappearance and handle errors
	defer func() {
		if err := LSFWaitForDynamicNodeDisappearance(t, sshClientOne, testLogger); err != nil {
			t.Errorf("Error in LSFWaitForDynamicNodeDisappearance: %v", err)
		}
	}()

	// Get dynamic compute node IPs and handle errors
	computeNodeIPList, computeIPErr := LSFGETDynamicComputeNodeIPs(t, sshClientOne, testLogger)
	require.NoError(t, computeIPErr, "Error getting dynamic compute node IPs: %v", computeIPErr)

	// Verify compute node configuration
	VerifyComputeNodeConfig(t, sshClientOne, expectedHyperthreadingEnabled, computeNodeIPList, testLogger)

	// Verify SSH key on compute nodes
	VerifySSHKey(t, sshClientOne, bastionIP, LSF_PUBLIC_HOST_NAME, LSF_PRIVATE_HOST_NAME, "compute", computeNodeIPList, expectedNumOfKeys, testLogger)

	// Verify LSF DNS on compute nodes
	VerifyLSFDNS(t, sshClientOne, computeNodeIPList, expectedDnsDomainName, testLogger)

	// Verify SSH connectivity from login node
	sshLoginNodeClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, loginNodeIP)
	require.NoError(t, connectionErr, "Failed to connect to the login node via SSH: %v", connectionErr)
	defer sshLoginNodeClient.Close()

	// Verify login node configuration
	VerifyLoginNodeConfig(t, sshLoginNodeClient, expectedClusterID, expectedMasterName, expectedReservationID, expectedHyperthreadingEnabled, loginNodeIP, JOB_COMMAND_LOW, EXPECTED_LSF_VERSION, testLogger)

	// Get dynamic compute node IPs again
	computeNodeIPList, computeIPErr = LSFGETDynamicComputeNodeIPs(t, sshClientOne, testLogger)
	require.NoError(t, computeIPErr, "Error getting dynamic compute node IPs: %v", computeIPErr)

	// Verify SSH connectivity from login node
	VerifySSHConnectivityToNodesFromLogin(t, sshLoginNodeClient, managementNodeIPList, computeNodeIPList, testLogger)

	// Verify LSF DNS on login node
	VerifyLSFDNS(t, sshClientOne, []string{loginNodeIP}, expectedDnsDomainName, testLogger)

	// Verify file share encryption
	VerifyFileShareEncryption(t, os.Getenv("TF_VAR_ibmcloud_api_key"), utils.GetRegion(expectedZone), expectedResourceGroup, expectedMasterName, expectedKeyManagement, testLogger)

	// Log validation end
	testLogger.Info(t, t.Name()+" Validation ended")
}

// ValidateExistingLDAPClusterConfig performs comprehensive validation on an existing LDAP cluster configuration.
// It connects to various cluster components via SSH to verify their configurations and functionality,
// including management nodes, compute nodes, login nodes, dynamic compute nodes, and LDAP integration.
// This function logs detailed information throughout the validation process and does not return any value.
func ValidateExistingLDAPClusterConfig(t *testing.T, ldapServerBastionIP, ldapServerIP, expectedLdapDomain, ldapAdminPassword, ldapUserName, ldapUserPassword string, options *testhelper.TestOptions, testLogger *utils.AggregatedLogger) {
	// Retrieve cluster information from options
	expectedClusterID := options.TerraformVars["cluster_id"].(string)
	expectedReservationID := options.TerraformVars["reservation_id"].(string)
	expectedMasterName := options.TerraformVars["cluster_prefix"].(string)
	expectedResourceGroup := options.TerraformVars["resource_group"].(string)
	expectedKeyManagement := options.TerraformVars["key_management"].(string)
	expectedZone := options.TerraformVars["zones"].([]string)[0]

	// Parse hyperthreading enabled flag
	expectedHyperthreadingEnabled, err := strconv.ParseBool(options.TerraformVars["hyperthreading_enabled"].(string))
	require.NoError(t, err, "Error parsing hyperthreading_enabled: %v", err)

	// Define job commands for different priority levels
	jobCommandLow := GetJobCommand(expectedZone, "high")
	jobCommandMed := GetJobCommand(expectedZone, "med")

	// Run the test consistency check
	output, err := options.RunTestConsistency()
	require.NoError(t, err, "Error running consistency test: %v", err)
	require.NotNil(t, output, "Expected non-nil output, but got nil")

	// Log successful cluster creation
	testLogger.Info(t, t.Name()+" Cluster created successfully")

	// Retrieve server IPs
	bastionIP, managementNodeIPs, loginNodeIP, ipRetrievalErr := utils.GetServerIPs(t, options, testLogger)
	require.NoError(t, ipRetrievalErr, "Error occurred while getting server IPs: %v", ipRetrievalErr)

	// Log validation start
	testLogger.Info(t, t.Name()+" Validation started")

	// Connect to the master node via SSH
	sshClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPs[0])
	require.NoError(t, connectionErr, "Failed to connect to the master via SSH: %v", connectionErr)
	defer sshClient.Close()

	testLogger.Info(t, "SSH connection to the master successful")
	t.Log("Validation in progress. Please wait...")

	// Verify management node configuration
	VerifyManagementNodeConfig(t, sshClient, expectedClusterID, expectedMasterName, expectedReservationID, expectedHyperthreadingEnabled, managementNodeIPs, jobCommandLow, EXPECTED_LSF_VERSION, testLogger)

	// Restart LSF daemon
	RestartLsfDaemon(t, sshClient, jobCommandLow, testLogger)

	// Reboot instance
	RebootInstance(t, sshClient, bastionIP, LSF_PUBLIC_HOST_NAME, LSF_PRIVATE_HOST_NAME, managementNodeIPs[0], jobCommandMed, testLogger)

	// Reconnect to the management node after reboot
	sshClient, connectionErr = utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPs[0])
	require.NoError(t, connectionErr, "Failed to reconnect to the master via SSH: %v", connectionErr)
	defer sshClient.Close()

	// Wait for dynamic node disappearance and handle potential errors
	defer func() {
		if err := LSFWaitForDynamicNodeDisappearance(t, sshClient, testLogger); err != nil {
			t.Errorf("Error in LSFWaitForDynamicNodeDisappearance: %v", err)
		}
	}()

	// Get dynamic compute node IPs
	computeNodeIPs, computeIPErr := LSFGETDynamicComputeNodeIPs(t, sshClient, testLogger)
	require.NoError(t, computeIPErr, "Error getting dynamic compute node IPs: %v", computeIPErr)

	// Verify compute node configuration
	VerifyComputeNodeConfig(t, sshClient, expectedHyperthreadingEnabled, computeNodeIPs, testLogger)

	// Verify SSH connectivity from login node
	sshLoginNodeClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, loginNodeIP)
	require.NoError(t, connectionErr, "Failed to connect to the login node via SSH: %v", connectionErr)
	defer sshLoginNodeClient.Close()

	// Verify login node configuration
	VerifyLoginNodeConfig(t, sshLoginNodeClient, expectedClusterID, expectedMasterName, expectedReservationID, expectedHyperthreadingEnabled, loginNodeIP, jobCommandLow, EXPECTED_LSF_VERSION, testLogger)

	// Verify SSH connectivity to nodes from login node
	VerifySSHConnectivityToNodesFromLogin(t, sshLoginNodeClient, managementNodeIPs, computeNodeIPs, testLogger)

	// Verify file share encryption
	VerifyFileShareEncryption(t, os.Getenv("TF_VAR_ibmcloud_api_key"), utils.GetRegion(expectedZone), expectedResourceGroup, expectedMasterName, expectedKeyManagement, testLogger)

	// Connect to the LDAP server via SSH
	sshLdapClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, ldapServerBastionIP, LSF_LDAP_HOST_NAME, ldapServerIP)
	require.NoError(t, connectionErr, "Failed to connect to the LDAP server via SSH: %v", connectionErr)
	defer sshLdapClient.Close()

	// Check LDAP server status
	CheckLDAPServerStatus(t, sshLdapClient, ldapAdminPassword, expectedLdapDomain, ldapUserName, testLogger)

	// Verify management node LDAP configuration
	VerifyManagementNodeLDAPConfig(t, sshClient, bastionIP, ldapServerIP, managementNodeIPs, jobCommandLow, expectedLdapDomain, ldapUserName, ldapUserPassword, testLogger)

	// Verify compute node LDAP configuration
	VerifyComputeNodeLDAPConfig(t, bastionIP, ldapServerIP, computeNodeIPs, expectedLdapDomain, ldapUserName, ldapUserPassword, testLogger)

	// Verify login node LDAP configuration
	VerifyLoginNodeLDAPConfig(t, sshLoginNodeClient, bastionIP, loginNodeIP, ldapServerIP, jobCommandLow, expectedLdapDomain, ldapUserName, ldapUserPassword, testLogger)

	// Verify LDAP user creation and LSF actions using the new user
	VerifyCreateNewLdapUserAndManagementNodeLDAPConfig(t, sshLdapClient, bastionIP, ldapServerIP, managementNodeIPs, jobCommandLow, ldapAdminPassword, expectedLdapDomain, ldapUserName, ldapUserPassword, "user2", testLogger)

	// Log validation end
	testLogger.Info(t, t.Name()+" Validation ended")
}
