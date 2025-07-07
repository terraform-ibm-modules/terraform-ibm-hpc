package tests

import (
	"encoding/json"
	"fmt"
	"os"
	"strconv"
	"testing"

	"github.com/stretchr/testify/require"
	"github.com/terraform-ibm-modules/ibmcloud-terratest-wrapper/testhelper"
	utils "github.com/terraform-ibm-modules/terraform-ibm-hpc/utilities"
	"golang.org/x/crypto/ssh"
)

type ExpectedClusterConfig struct {
	MasterName     string
	ResourceGroup  string
	KeyManagement  string
	Zone           string
	NumOfKeys      int
	DnsDomainName  string
	Hyperthreading bool
	LsfVersion     string
}

// GetExpectedClusterConfig retrieves and structures the expected cluster
// configuration from Terraform output. It parses relevant variables like
// cluster name, resource group, key management, and DNS settings.
func GetExpectedClusterConfig(t *testing.T, options *testhelper.TestOptions) ExpectedClusterConfig {

	masterName := utils.GetStringVarWithDefault(options.TerraformVars, "cluster_prefix", "")
	resourceGroup := utils.GetStringVarWithDefault(options.TerraformVars, "existing_resource_group", "")
	keyManagement := utils.GetStringVarWithDefault(options.TerraformVars, "key_management", "null")
	lsfVersion := utils.GetStringVarWithDefault(options.TerraformVars, "lsf_version", "")

	zone := options.TerraformVars["zones"].([]string)[0]
	numOfKeys := len(options.TerraformVars["ssh_keys"].([]string))

	dnsStr := options.TerraformVars["dns_domain_names"].(string)
	var dnsMap map[string]string
	require.NoError(t, json.Unmarshal([]byte(dnsStr), &dnsMap), "Failed to unmarshal dns_domain_names")

	hyperthreading, err := strconv.ParseBool(options.TerraformVars["enable_hyperthreading"].(string))
	require.NoError(t, err, "Failed to parse enable_hyperthreading from Terraform vars - check variable type and value")

	return ExpectedClusterConfig{
		MasterName:     masterName,
		ResourceGroup:  resourceGroup,
		KeyManagement:  keyManagement,
		Zone:           zone,
		NumOfKeys:      numOfKeys,
		DnsDomainName:  dnsMap["compute"],
		Hyperthreading: hyperthreading,
		LsfVersion:     lsfVersion,
	}
}

// runClusterValidationsOnManagementNode performs a series of validation
// checks on the management nodes of the LSF cluster. This includes
// verifying configuration, SSH keys, DNS, failover, and daemon restarts.
func runClusterValidationsOnManagementNode(t *testing.T, sshClient *ssh.Client, bastionIP string, managementNodeIPs []string, expected ExpectedClusterConfig, jobCmd string, logger *utils.AggregatedLogger) {

	logger.Info(t, "Running management node and App Center validations sequentially...")

	// Verify management node configuration
	VerifyManagementNodeConfig(t, sshClient, expected.MasterName, expected.Hyperthreading, managementNodeIPs, expected.LsfVersion, logger)

	// Run job
	VerifyJobs(t, sshClient, jobCmd, logger)

	// Verify application center configuration
	VerifyAPPCenterConfig(t, sshClient, logger)

	// Verify noVNC configuration
	VerifyNoVNCConfig(t, sshClient, logger)

	// Verify SSH key on management nodes
	VerifySSHKey(t, sshClient, bastionIP, LSF_PUBLIC_HOST_NAME, LSF_PRIVATE_HOST_NAME, "management", managementNodeIPs, expected.NumOfKeys, logger)

	// Verify LSF DNS on management nodes
	VerifyLSFDNS(t, sshClient, managementNodeIPs, expected.DnsDomainName, logger)

	// Perform failover and failback
	FailoverAndFailback(t, sshClient, jobCmd, logger)

	// Restart LSF daemon
	RestartLsfDaemon(t, sshClient, logger)

	// Reboot instance
	RebootInstance(t, sshClient, bastionIP, LSF_PUBLIC_HOST_NAME, LSF_PRIVATE_HOST_NAME, managementNodeIPs[0], logger)

	logger.Info(t, "Management node and App Center validations completed sequentially.")
}

// runClusterValidationsOnComputeNode executes validation steps specific
// to the compute nodes in the LSF cluster. This includes running jobs,
// verifying node configuration, SSH keys, and DNS settings.
func runClusterValidationsOnComputeNode(t *testing.T, sshClient *ssh.Client, bastionIP string, staticWorkerNodeIPs []string, expected ExpectedClusterConfig, jobCmd string, logger *utils.AggregatedLogger) {

	logger.Info(t, "Running compute node validations sequentially...")

	// Run job
	VerifyJobs(t, sshClient, jobCmd, logger)

	// Get compute node IPs and handle errors
	computeNodeIPList, err := GetComputeNodeIPs(t, sshClient, staticWorkerNodeIPs, logger)
	if err != nil {
		t.Fatalf("Failed to retrieve dynamic compute node IPs: %v", err)
	}

	// Verify compute node configuration
	VerifyComputeNodeConfig(t, sshClient, expected.Hyperthreading, computeNodeIPList, logger)

	// Verify SSH key on compute nodes
	VerifySSHKey(t, sshClient, bastionIP, LSF_PUBLIC_HOST_NAME, LSF_PRIVATE_HOST_NAME, "compute", computeNodeIPList, expected.NumOfKeys, logger)

	// Verify LSF DNS on compute nodes
	VerifyLSFDNS(t, sshClient, computeNodeIPList, expected.DnsDomainName, logger)

	logger.Info(t, "Compute node validations completed sequentially.")
}

// runClusterValidationsOnLoginNode conducts validations on the LSF login
// node, including verifying its configuration and SSH connectivity to
// management and compute nodes.
func runClusterValidationsOnLoginNode(t *testing.T, bastionIP, loginNodeIP string, expected ExpectedClusterConfig, managementNodeIPs, computeNodeIPs []string, jobCmd string, logger *utils.AggregatedLogger) {

	logger.Info(t, "Running login node validations sequentially...")

	loginSSHClient, err := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, loginNodeIP)
	require.NoError(t, err, "Failed to connect to login node via SSH")

	defer func() {
		if cerr := loginSSHClient.Close(); cerr != nil {
			logger.Info(t, fmt.Sprintf("Failed to close SSH connection: %v", cerr))
		}
	}()

	// Verify login node configuration
	VerifyLoginNodeConfig(t, loginSSHClient, expected.MasterName, expected.Hyperthreading, loginNodeIP, jobCmd, expected.LsfVersion, logger)

	// Verify SSH connectivity from login node
	VerifySSHConnectivityToNodesFromLogin(t, loginSSHClient, managementNodeIPs, computeNodeIPs, logger)

	logger.Info(t, "Login node validations completed sequentially.")
}

// ValidateClusterConfiguration performs comprehensive validation on the cluster setup.
// It connects to various cluster components via SSH and verifies their configurations and functionality.
// This includes the following validations:
// - Management Node: Verifies the configuration of the management node, including failover and failback procedures.
// - Compute Nodes: Ensures proper configuration and SSH connectivity to compute nodes.
// - Login Node: Validates the configuration and SSH connectivity to the login node.
// - Dynamic Compute Nodes: Verifies the proper setup and functionality of dynamic compute nodes.
// - Application Center: Validates the configuration of the application center.
// - noVNC: Verifies the noVNC configuration.
// Additionally, this function logs detailed information throughout the validation process.
// This function doesn't return any value but logs errors and validation steps during the process.
func ValidateClusterConfiguration(t *testing.T, options *testhelper.TestOptions, testLogger *utils.AggregatedLogger) {

	// Retrieve common cluster details from options
	expected := GetExpectedClusterConfig(t, options)

	// Retrieve server IPs (different logic for HPC vs LSF solutions)
	bastionIP, managementNodeIPs, _, staticWorkerNodeIPs, getClusterIPErr := GetClusterIPs(t, options, testLogger)
	require.NoError(t, getClusterIPErr, "Failed to get cluster IPs from Terraform outputs - check network configuration")

	deployerIP, getdeployerIPErr := GetDeployerIPs(t, options, testLogger)
	require.NoError(t, getdeployerIPErr, "Failed to get deployer IP from Terraform outputs - check deployer configuration")

	// Set job commands for low and medium memory tasks, ignoring high memory command
	jobCommandLow, jobCommandMed, _ := GenerateLSFJobCommandsForMemoryTypes()

	// Log validation start
	testLogger.Info(t, t.Name()+" Validation started ......")

	VerifyTestTerraformOutputs(t, bastionIP, deployerIP, false, false, false, testLogger)

	// Connect to the master node via SSH and handle connection errors
	sshClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPs[0])
	require.NoError(t, connectionErr, "Failed to establish SSH connection to master node - check network and credentials")

	defer func() {
		if err := sshClient.Close(); err != nil {
			testLogger.Info(t, fmt.Sprintf("failed to close sshClient: %v", err))
		}
	}()

	testLogger.Info(t, "SSH connection to the master successful")
	t.Log("Validation in progress. Please wait...")

	runClusterValidationsOnManagementNode(t, sshClient, bastionIP, managementNodeIPs, expected, jobCommandMed, testLogger)

	// Reconnect to the management node after reboot
	sshClient, connectionErr = utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPs[0])
	require.NoError(t, connectionErr, "Failed to re-establish SSH connection after reboot - check node recovery")

	// Wait for dynamic node disappearance and handle potential errors
	defer func() {
		if err := WaitForDynamicNodeDisappearance(t, sshClient, testLogger); err != nil {
			t.Errorf("Error in WaitForDynamicNodeDisappearance: %v", err)
		}
	}()

	runClusterValidationsOnComputeNode(t, sshClient, bastionIP, staticWorkerNodeIPs, expected, jobCommandLow, testLogger)

	//runClusterValidationsOnLoginNode(t, bastionIP, loginNodeIP, expected, managementNodeIPs, staticWorkerNodeIPs, jobCommandLow, testLogger)

	// Verify PTR records
	VerifyPTRRecordsForManagement(t, sshClient, LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPs, expected.DnsDomainName, testLogger)

	// Verify LSF DNS on login node
	//VerifyLSFDNS(t, sshClient, []string{loginNodeIP}, expected.DnsDomainName, testLogger)

	// Verify file share encryption
	VerifyFileShareEncryption(t, sshClient, os.Getenv("TF_VAR_ibmcloud_api_key"), utils.GetRegion(expected.Zone), expected.ResourceGroup, expected.MasterName, expected.KeyManagement, managementNodeIPs, testLogger)

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
	expected := GetExpectedClusterConfig(t, options)

	// Retrieve server IPs (different logic for HPC vs LSF solutions)
	bastionIP, managementNodeIPs, _, staticWorkerNodeIPs, getClusterIPErr := GetClusterIPs(t, options, testLogger)
	require.NoError(t, getClusterIPErr, "Failed to get cluster IPs from Terraform outputs - check network configuration")

	// Set job commands for low and medium memory tasks, ignoring high memory command
	jobCommandLow, jobCommandMed, _ := GenerateLSFJobCommandsForMemoryTypes()

	// Log validation start
	testLogger.Info(t, t.Name()+" Validation started ......")

	// Connect to the master node via SSH and handle connection errors
	sshClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPs[0])
	require.NoError(t, connectionErr, "Failed to establish SSH connection to master node - check network and credentials")

	defer func() {
		if err := sshClient.Close(); err != nil {
			testLogger.Info(t, fmt.Sprintf("failed to close sshClient: %v", err))
		}
	}()

	testLogger.Info(t, "SSH connection to the master successful")
	t.Log("Validation in progress. Please wait...")

	runClusterValidationsOnManagementNode(t, sshClient, bastionIP, managementNodeIPs, expected, jobCommandMed, testLogger)

	// Reconnect to the management node after reboot
	sshClient, connectionErr = utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPs[0])
	require.NoError(t, connectionErr, "Failed to re-establish SSH connection after reboot - check node recovery")

	// Wait for dynamic node disappearance and handle potential errors
	defer func() {
		if err := WaitForDynamicNodeDisappearance(t, sshClient, testLogger); err != nil {
			t.Errorf("Error in WaitForDynamicNodeDisappearance: %v", err)
		}
	}()

	// Verify PACHA configuration by validating the application center setup.
	ValidatePACHAOnManagementNodes(t, sshClient, expected.DnsDomainName, bastionIP, managementNodeIPs, testLogger)

	runClusterValidationsOnComputeNode(t, sshClient, bastionIP, staticWorkerNodeIPs, expected, jobCommandLow, testLogger)

	//runClusterValidationsOnLoginNode(t, bastionIP, loginNodeIP, expected, managementNodeIPs, staticWorkerNodeIPs, jobCommandLow, testLogger)

	// Verify PTR records
	VerifyPTRRecordsForManagement(t, sshClient, LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPs, expected.DnsDomainName, testLogger)

	// Verify LSF DNS on login node
	//VerifyLSFDNS(t, sshClient, []string{loginNodeIP}, expected.DnsDomainName, testLogger)

	// Verify file share encryption
	VerifyFileShareEncryption(t, sshClient, os.Getenv("TF_VAR_ibmcloud_api_key"), utils.GetRegion(expected.Zone), expected.ResourceGroup, expected.MasterName, expected.KeyManagement, managementNodeIPs, testLogger)

	// Verify PACHA Failover configuration by validating the application center setup.
	ValidatePACHAFailoverHealthCheckOnManagementNodes(t, sshClient, expected.DnsDomainName, bastionIP, managementNodeIPs, testLogger)

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
	expected := GetExpectedClusterConfig(t, options)

	// Retrieve server IPs (different logic for HPC vs LSF solutions)
	bastionIP, managementNodeIPs, _, staticWorkerNodeIPs, getClusterIPErr := GetClusterIPs(t, options, testLogger)
	require.NoError(t, getClusterIPErr, "Failed to get cluster IPs from Terraform outputs - check network configuration")

	deployerIP, getdeployerIPErr := GetDeployerIPs(t, options, testLogger)
	require.NoError(t, getdeployerIPErr, "Failed to get deployer IP from Terraform outputs - check deployer configuration")

	// Get the job command for low memory tasks and ignore the other ones
	jobCommandLow, _, _ := GenerateLSFJobCommandsForMemoryTypes()

	// Log validation start
	testLogger.Info(t, t.Name()+" Validation started ......")

	VerifyTestTerraformOutputs(t, bastionIP, deployerIP, false, false, false, testLogger)

	// Connect to the master node via SSH and handle connection errors
	sshClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPs[0])
	require.NoError(t, connectionErr, "Failed to establish SSH connection to master node - check network and credentials")

	defer func() {
		if err := sshClient.Close(); err != nil {
			testLogger.Info(t, fmt.Sprintf("failed to close sshClient: %v", err))
		}
	}()

	testLogger.Info(t, "SSH connection to the master successful")
	t.Log("Validation in progress. Please wait...")

	// Verify management node configuration
	VerifyManagementNodeConfig(t, sshClient, expected.MasterName, expected.Hyperthreading, managementNodeIPs, expected.LsfVersion, testLogger)

	// Wait for dynamic node disappearance and handle potential errors
	defer func() {
		if err := WaitForDynamicNodeDisappearance(t, sshClient, testLogger); err != nil {
			t.Errorf("Error in WaitForDynamicNodeDisappearance: %v", err)
		}
	}()

	// Run job
	VerifyJobs(t, sshClient, jobCommandLow, testLogger)

	// Get compute node IPs and handle errors
	computeNodeIPList, err := GetComputeNodeIPs(t, sshClient, staticWorkerNodeIPs, testLogger)
	if err != nil {
		t.Fatalf("Failed to retrieve dynamic compute node IPs: %v", err)
	}

	// Verify compute node configuration
	VerifyComputeNodeConfig(t, sshClient, expected.Hyperthreading, computeNodeIPList, testLogger)

	//runClusterValidationsOnLoginNode(t, bastionIP, loginNodeIP, expected, managementNodeIPs, staticWorkerNodeIPs, jobCommandLow, testLogger)

	// Verify file share encryption
	VerifyFileShareEncryption(t, sshClient, os.Getenv("TF_VAR_ibmcloud_api_key"), utils.GetRegion(expected.Zone), expected.ResourceGroup, expected.MasterName, expected.KeyManagement, managementNodeIPs, testLogger)

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
	expected := GetExpectedClusterConfig(t, options)

	// Retrieve server IPs (different logic for HPC vs LSF solutions)
	bastionIP, managementNodeIPs, _, staticWorkerNodeIPs, getClusterIPErr := GetClusterIPs(t, options, testLogger)
	require.NoError(t, getClusterIPErr, "Failed to get cluster IPs from Terraform outputs - check network configuration")

	// Set job commands for low and medium memory tasks, ignoring high memory command
	_, jobCommandMed, _ := GenerateLSFJobCommandsForMemoryTypes()

	// Log validation start
	testLogger.Info(t, t.Name()+" Validation started ......")

	// Connect to the master node via SSH and handle connection errors
	sshClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPs[0])
	require.NoError(t, connectionErr, "Failed to establish SSH connection to master node - check network and credentials")

	defer func() {
		if err := sshClient.Close(); err != nil {
			testLogger.Info(t, fmt.Sprintf("failed to close sshClient: %v", err))
		}
	}()

	testLogger.Info(t, "SSH connection to the master successful")
	t.Log("Validation in progress. Please wait...")

	// Verify management node configuration
	VerifyManagementNodeConfig(t, sshClient, expected.MasterName, expected.Hyperthreading, managementNodeIPs, expected.LsfVersion, testLogger)

	// Wait for dynamic node disappearance and handle potential errors
	defer func() {
		if err := WaitForDynamicNodeDisappearance(t, sshClient, testLogger); err != nil {
			t.Errorf("Error in WaitForDynamicNodeDisappearance: %v", err)
		}
	}()

	// Run job
	VerifyJobs(t, sshClient, jobCommandMed, testLogger)

	// Verify dynamic node profile
	ValidateDynamicNodeProfile(t, os.Getenv("TF_VAR_ibmcloud_api_key"), utils.GetRegion(expected.Zone), expected.ResourceGroup, expected.MasterName, options, testLogger)

	// Get compute node IPs and handle errors
	computeNodeIPList, err := GetComputeNodeIPs(t, sshClient, staticWorkerNodeIPs, testLogger)
	if err != nil {
		t.Fatalf("Failed to retrieve dynamic compute node IPs: %v", err)
	}

	// Verify compute node configuration
	VerifyComputeNodeConfig(t, sshClient, expected.Hyperthreading, computeNodeIPList, testLogger)

	//runClusterValidationsOnLoginNode(t, bastionIP, loginNodeIP, expected, managementNodeIPs, staticWorkerNodeIPs, jobCommandLow, testLogger)

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
	expected := GetExpectedClusterConfig(t, options)

	expectedLdapDomain, ldapAdminPassword, ldapUserName, ldapUserPassword, getLDAPCredentialsErr := GetValidatedLDAPCredentials(t, options, testLogger)
	require.NoError(t, getLDAPCredentialsErr, "Error occurred while getting LDAP credentials")

	// Retrieve server IPs (different logic for HPC vs LSF solutions)
	bastionIP, managementNodeIPs, _, staticWorkerNodeIPs, ldapServerIP, getClusterIPErr := GetClusterIPsWithLDAP(t, options, testLogger)
	require.NoError(t, getClusterIPErr, "Failed to get cluster IPs from Terraform outputs - check network configuration")

	deployerIP, getdeployerIPErr := GetDeployerIPs(t, options, testLogger)
	require.NoError(t, getdeployerIPErr, "Error occurred while getting deployer IPs")

	// Set job commands for low and medium memory tasks, ignoring high memory command
	jobCommandLow, jobCommandMed, _ := GenerateLSFJobCommandsForMemoryTypes()

	// Log validation start
	testLogger.Info(t, t.Name()+" Validation started ......")

	VerifyTestTerraformOutputs(t, bastionIP, deployerIP, false, false, true, testLogger)

	// Connect to the master node via SSH and handle connection errors
	sshClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPs[0])
	require.NoError(t, connectionErr, "Failed to establish SSH connection to master node - check network and credentials")

	defer func() {
		if err := sshClient.Close(); err != nil {
			testLogger.Info(t, fmt.Sprintf("failed to close sshClient: %v", err))
		}
	}()

	testLogger.Info(t, "SSH connection to the master successful")
	t.Log("Validation in progress. Please wait...")

	runClusterValidationsOnManagementNode(t, sshClient, bastionIP, managementNodeIPs, expected, jobCommandMed, testLogger)

	// Reconnect to the management node after reboot
	sshClient, connectionErr = utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPs[0])
	require.NoError(t, connectionErr, "Failed to re-establish SSH connection after reboot - check node recovery")

	// Wait for dynamic node disappearance and handle potential errors
	defer func() {
		if err := WaitForDynamicNodeDisappearance(t, sshClient, testLogger); err != nil {
			t.Errorf("Error in WaitForDynamicNodeDisappearance: %v", err)
		}
	}()

	runClusterValidationsOnComputeNode(t, sshClient, bastionIP, staticWorkerNodeIPs, expected, jobCommandLow, testLogger)

	// Verify SSH connectivity from login node and handle connection errors
	// sshLoginNodeClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, loginNodeIP)
	// require.NoError(t, connectionErr, "Failed to connect to the login node via SSH")

	// defer func() {
	// 	if err := sshLoginNodeClient.Close(); err != nil {
	// 		testLogger.Info(t, fmt.Sprintf("failed to close sshLoginNodeClient: %v", err))
	// 	}
	// }()

	//runClusterValidationsOnLoginNode(t, bastionIP, loginNodeIP, expected, managementNodeIPs, staticWorkerNodeIPs, jobCommandLow, testLogger)

	// Verify LSF DNS settings on login node
	//VerifyLSFDNS(t, sshClient, []string{loginNodeIP}, expected.DnsDomainName, testLogger)

	// Verify file share encryption
	VerifyFileShareEncryption(t, sshClient, os.Getenv("TF_VAR_ibmcloud_api_key"), utils.GetRegion(expected.Zone), expected.ResourceGroup, expected.MasterName, expected.KeyManagement, managementNodeIPs, testLogger)

	// Connect to the LDAP server via SSH and handle connection errors
	sshLdapClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_LDAP_HOST_NAME, ldapServerIP)
	require.NoError(t, connectionErr, "Failed to connect to the LDAP server via SSH")

	defer func() {
		if err := sshLdapClient.Close(); err != nil {
			testLogger.Info(t, fmt.Sprintf("failed to close sshLdapClient: %v", err))
		}
	}()

	// Run job
	VerifyJobs(t, sshClient, jobCommandLow, testLogger)

	// Get compute node IPs and handle errors
	computeNodeIPList, err := GetComputeNodeIPs(t, sshClient, staticWorkerNodeIPs, testLogger)
	if err != nil {
		t.Fatalf("Failed to retrieve dynamic compute node IPs: %v", err)
	}

	// Check LDAP server status
	CheckLDAPServerStatus(t, sshLdapClient, ldapAdminPassword, expectedLdapDomain, ldapUserName, testLogger)

	// Verify management node LDAP config
	VerifyManagementNodeLDAPConfig(t, sshClient, bastionIP, ldapServerIP, managementNodeIPs, jobCommandLow, expectedLdapDomain, ldapUserName, ldapUserPassword, testLogger)

	// Verify compute node LDAP config
	VerifyComputeNodeLDAPConfig(t, bastionIP, ldapServerIP, computeNodeIPList, expectedLdapDomain, ldapUserName, ldapUserPassword, testLogger)

	// Verify login node LDAP config
	//VerifyLoginNodeLDAPConfig(t, sshLoginNodeClient, bastionIP, loginNodeIP, ldapServerIP, jobCommandLow, expectedLdapDomain, ldapUserName, ldapUserPassword, testLogger)

	// Verify PTR records
	VerifyPTRRecordsForManagement(t, sshClient, LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPs, expected.DnsDomainName, testLogger)

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
	expected := GetExpectedClusterConfig(t, options)

	expectedLdapDomain, ldapAdminPassword, ldapUserName, ldapUserPassword, getLDAPCredentialsErr := GetValidatedLDAPCredentials(t, options, testLogger)
	require.NoError(t, getLDAPCredentialsErr, "Error occurred while getting LDAP credentials")

	// Retrieve server IPs (different logic for HPC vs LSF solutions)
	bastionIP, managementNodeIPs, loginNodeIP, staticWorkerNodeIPs, ldapServerIP, getClusterIPErr := GetClusterIPsWithLDAP(t, options, testLogger)
	require.NoError(t, getClusterIPErr, "Failed to get cluster IPs from Terraform outputs - check network configuration")

	deployerIP, getdeployerIPErr := GetDeployerIPs(t, options, testLogger)
	require.NoError(t, getdeployerIPErr, "Failed to get deployer IP from Terraform outputs - check deployer configuration")

	// Set job commands for low and medium memory tasks, ignoring high memory command
	jobCommandLow, jobCommandMed, _ := GenerateLSFJobCommandsForMemoryTypes()

	// Log validation start
	testLogger.Info(t, t.Name()+" Validation started ......")

	// verify terraform outpu
	VerifyTestTerraformOutputs(t, bastionIP, deployerIP, false, false, true, testLogger)

	// Connect to the master node via SSH and handle connection errors
	sshClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPs[0])
	require.NoError(t, connectionErr, "Failed to establish SSH connection to master node - check network and credentials")

	defer func() {
		if err := sshClient.Close(); err != nil {
			testLogger.Info(t, fmt.Sprintf("failed to close sshClient: %v", err))
		}
	}()

	testLogger.Info(t, "SSH connection to the master successful")
	t.Log("Validation in progress. Please wait...")

	runClusterValidationsOnManagementNode(t, sshClient, bastionIP, managementNodeIPs, expected, jobCommandMed, testLogger)

	// Reconnect to the management node after reboot
	sshClient, connectionErr = utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPs[0])
	require.NoError(t, connectionErr, "Failed to re-establish SSH connection after reboot - check node recovery")

	// Wait for dynamic node disappearance and handle potential errors
	defer func() {
		if err := WaitForDynamicNodeDisappearance(t, sshClient, testLogger); err != nil {
			t.Errorf("Error in WaitForDynamicNodeDisappearance: %v", err)
		}
	}()

	runClusterValidationsOnComputeNode(t, sshClient, bastionIP, staticWorkerNodeIPs, expected, jobCommandLow, testLogger)

	// Verify SSH connectivity from login node and handle connection errors
	sshLoginNodeClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, loginNodeIP)
	require.NoError(t, connectionErr, "Failed to connect to the login node via SSH")

	defer func() {
		if err := sshLoginNodeClient.Close(); err != nil {
			testLogger.Info(t, fmt.Sprintf("failed to close sshLoginNodeClient: %v", err))
		}
	}()

	//runClusterValidationsOnLoginNode(t, bastionIP, loginNodeIP, expected, managementNodeIPs, staticWorkerNodeIPs, jobCommandLow, testLogger)

	// Verify file share encryption
	VerifyFileShareEncryption(t, sshClient, os.Getenv("TF_VAR_ibmcloud_api_key"), utils.GetRegion(expected.Zone), expected.ResourceGroup, expected.MasterName, expected.KeyManagement, managementNodeIPs, testLogger)

	// Connect to the LDAP server via SSH and handle connection errors
	sshLdapClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_LDAP_HOST_NAME, ldapServerIP)
	require.NoError(t, connectionErr, "Failed to connect to the LDAP server via SSH")

	defer func() {
		if err := sshLdapClient.Close(); err != nil {
			testLogger.Info(t, fmt.Sprintf("failed to close sshLdapClient: %v", err))
		}
	}()

	// Get compute node IPs and handle errors
	computeNodeIPList, err := GetComputeNodeIPs(t, sshClient, staticWorkerNodeIPs, testLogger)
	if err != nil {
		t.Fatalf("Failed to retrieve dynamic compute node IPs: %v", err)
	}

	// Check LDAP server status
	CheckLDAPServerStatus(t, sshLdapClient, ldapAdminPassword, expectedLdapDomain, ldapUserName, testLogger)

	// Verify management node LDAP config
	VerifyManagementNodeLDAPConfig(t, sshClient, bastionIP, ldapServerIP, managementNodeIPs, jobCommandLow, expectedLdapDomain, ldapUserName, ldapUserPassword, testLogger)

	// Verify compute node LDAP config
	VerifyComputeNodeLDAPConfig(t, bastionIP, ldapServerIP, computeNodeIPList, expectedLdapDomain, ldapUserName, ldapUserPassword, testLogger)

	// Verify login node LDAP config
	VerifyLoginNodeLDAPConfig(t, sshLoginNodeClient, bastionIP, loginNodeIP, ldapServerIP, jobCommandLow, expectedLdapDomain, ldapUserName, ldapUserPassword, testLogger)

	// Verify ability to create LDAP user and perform LSF actions using new user
	VerifyCreateNewLdapUserAndManagementNodeLDAPConfig(t, sshLdapClient, bastionIP, ldapServerIP, managementNodeIPs, jobCommandLow, ldapAdminPassword, expectedLdapDomain, NEW_LDAP_USER_NAME, NEW_LDAP_USER_PASSWORD, testLogger)

	// Verify PTR records
	VerifyPTRRecordsForManagement(t, sshClient, LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPs, expected.DnsDomainName, testLogger)

	// Log validation end
	testLogger.Info(t, t.Name()+" Validation ended")
}

// ValidateExistingLDAPClusterConfig performs comprehensive validation on an existing LDAP cluster configuration.
// It connects to various cluster components via SSH to verify their configurations and functionality,
// including management nodes, compute nodes, login nodes, dynamic compute nodes, and LDAP integration.
// This function logs detailed information throughout the validation process and does not return any value.
func ValidateExistingLDAPClusterConfig(t *testing.T, ldapServerBastionIP, ldapServerIP, expectedLdapDomain, ldapAdminPassword, ldapUserName, ldapUserPassword string, options *testhelper.TestOptions, testLogger *utils.AggregatedLogger) {

	// Retrieve common cluster details from options
	expected := GetExpectedClusterConfig(t, options)

	// Retrieve server IPs (different logic for HPC vs LSF solutions)
	bastionIP, managementNodeIPs, _, staticWorkerNodeIPs, getClusterIPErr := GetClusterIPs(t, options, testLogger)
	require.NoError(t, getClusterIPErr, "Failed to get cluster IPs from Terraform outputs - check network configuration")

	// Set job commands for low and medium memory tasks, ignoring high memory command
	jobCommandLow, jobCommandMed, _ := GenerateLSFJobCommandsForMemoryTypes()

	// Log validation start
	testLogger.Info(t, t.Name()+" Validation started ......")

	// Connect to the master node via SSH and handle connection errors
	sshClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPs[0])
	require.NoError(t, connectionErr, "Failed to establish SSH connection to master node - check network and credentials")

	defer func() {
		if err := sshClient.Close(); err != nil {
			testLogger.Info(t, fmt.Sprintf("failed to close sshClient: %v", err))
		}
	}()

	testLogger.Info(t, "SSH connection to the master successful")
	t.Log("Validation in progress. Please wait...")

	runClusterValidationsOnManagementNode(t, sshClient, bastionIP, managementNodeIPs, expected, jobCommandMed, testLogger)

	// Reconnect to the management node after reboot
	sshClient, connectionErr = utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPs[0])
	require.NoError(t, connectionErr, "Failed to re-establish SSH connection after reboot - check node recovery")

	// Wait for dynamic node disappearance and handle potential errors
	defer func() {
		if err := WaitForDynamicNodeDisappearance(t, sshClient, testLogger); err != nil {
			t.Errorf("Error in WaitForDynamicNodeDisappearance: %v", err)
		}
	}()

	runClusterValidationsOnComputeNode(t, sshClient, bastionIP, staticWorkerNodeIPs, expected, jobCommandLow, testLogger)

	// Verify SSH connectivity from login node and handle connection errors
	// sshLoginNodeClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, loginNodeIP)
	// require.NoError(t, connectionErr, "Failed to connect to the login node via SSH")

	// defer func() {
	// 	if err := sshLoginNodeClient.Close(); err != nil {
	// 		testLogger.Info(t, fmt.Sprintf("failed to close sshLoginNodeClient: %v", err))
	// 	}
	// }()

	//runClusterValidationsOnLoginNode(t, bastionIP, loginNodeIP, expected, managementNodeIPs, staticWorkerNodeIPs, jobCommandLow, testLogger)

	// Verify PTR records
	VerifyPTRRecordsForManagement(t, sshClient, LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPs, expected.DnsDomainName, testLogger)

	// Verify file share encryption
	VerifyFileShareEncryption(t, sshClient, os.Getenv("TF_VAR_ibmcloud_api_key"), utils.GetRegion(expected.Zone), expected.ResourceGroup, expected.MasterName, expected.KeyManagement, managementNodeIPs, testLogger)

	// Connect to the LDAP server via SSH
	sshLdapClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, ldapServerBastionIP, LSF_LDAP_HOST_NAME, ldapServerIP)
	require.NoError(t, connectionErr, "Failed to connect to the LDAP server via SSH")

	defer func() {
		if err := sshLdapClient.Close(); err != nil {
			testLogger.Info(t, fmt.Sprintf("failed to close sshLdapClient: %v", err))
		}
	}()

	// Check LDAP server status
	CheckLDAPServerStatus(t, sshLdapClient, ldapAdminPassword, expectedLdapDomain, ldapUserName, testLogger)

	// Verify management node LDAP configuration
	VerifyManagementNodeLDAPConfig(t, sshClient, bastionIP, ldapServerIP, managementNodeIPs, jobCommandLow, expectedLdapDomain, ldapUserName, ldapUserPassword, testLogger)

	// Verify compute node LDAP configuration
	VerifyComputeNodeLDAPConfig(t, bastionIP, ldapServerIP, managementNodeIPs, expectedLdapDomain, ldapUserName, ldapUserPassword, testLogger)

	// Verify login node LDAP configuration
	//VerifyLoginNodeLDAPConfig(t, sshLoginNodeClient, bastionIP, loginNodeIP, ldapServerIP, jobCommandLow, expectedLdapDomain, ldapUserName, ldapUserPassword, testLogger)

	// Verify LDAP user creation and LSF actions using the new user
	VerifyCreateNewLdapUserAndManagementNodeLDAPConfig(t, sshLdapClient, bastionIP, ldapServerIP, managementNodeIPs, jobCommandLow, ldapAdminPassword, expectedLdapDomain, NEW_LDAP_USER_NAME, NEW_LDAP_USER_PASSWORD, testLogger)

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
	expected := GetExpectedClusterConfig(t, options)

	// Retrieve server IPs (different logic for HPC vs LSF solutions)
	bastionIP, managementNodeIPs, _, staticWorkerNodeIPs, getClusterIPErr := GetClusterIPs(t, options, testLogger)
	require.NoError(t, getClusterIPErr, "Failed to get cluster IPs from Terraform outputs - check network configuration")

	// Get the job command for low memory tasks and ignore the other ones
	jobCommandLow, _, _ := GenerateLSFJobCommandsForMemoryTypes()

	// Log validation start
	testLogger.Info(t, t.Name()+" Validation started ......")

	// Connect to the master node via SSH and handle connection errors
	sshClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPs[0])
	require.NoError(t, connectionErr, "Failed to establish SSH connection to master node - check network and credentials")

	defer func() {
		if err := sshClient.Close(); err != nil {
			testLogger.Info(t, fmt.Sprintf("failed to close sshClient: %v", err))
		}
	}()

	testLogger.Info(t, "SSH connection to the master successful")
	t.Log("Validation in progress. Please wait...")

	// Verify management node configuration
	VerifyManagementNodeConfig(t, sshClient, expected.MasterName, expected.Hyperthreading, managementNodeIPs, expected.LsfVersion, testLogger)

	// Reconnect to the management node after reboot
	sshClient, connectionErr = utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPs[0])
	require.NoError(t, connectionErr, "Failed to re-establish SSH connection after reboot - check node recovery")

	// Wait for dynamic node disappearance and handle potential errors
	defer func() {
		if err := WaitForDynamicNodeDisappearance(t, sshClient, testLogger); err != nil {
			t.Errorf("Error in WaitForDynamicNodeDisappearance: %v", err)
		}
	}()

	runClusterValidationsOnComputeNode(t, sshClient, bastionIP, staticWorkerNodeIPs, expected, jobCommandLow, testLogger)

	//runClusterValidationsOnLoginNode(t, bastionIP, loginNodeIP, expected, managementNodeIPs, staticWorkerNodeIPs, jobCommandLow, testLogger)

	// Verify LSF DNS on login node
	//VerifyLSFDNS(t, sshClient, []string{loginNodeIP}, expected.DnsDomainName, testLogger)

	// Verify file share encryption
	VerifyFileShareEncryption(t, sshClient, os.Getenv("TF_VAR_ibmcloud_api_key"), utils.GetRegion(expected.Zone), expected.ResourceGroup, expected.MasterName, expected.KeyManagement, managementNodeIPs, testLogger)

	// Validate COS service instance and VPC flow logs
	ValidateCosServiceInstanceAndVpcFlowLogs(t, os.Getenv("TF_VAR_ibmcloud_api_key"), utils.GetRegion(expected.Zone), expected.ResourceGroup, expected.MasterName, testLogger)

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

	// Retrieve common cluster details from options
	expected := GetExpectedClusterConfig(t, options)

	// Set job commands for low and medium memory tasks, ignoring high memory command
	jobCommandLow, jobCommandMed, _ := GenerateLSFJobCommandsForMemoryTypes()

	// Retrieve server IPs (different logic for HPC vs LSF solutions)
	bastionIP, managementNodeIPs, _, staticWorkerNodeIPs, getClusterIPErr := GetClusterIPs(t, options, testLogger)
	require.NoError(t, getClusterIPErr, "Failed to get cluster IPs from Terraform outputs - check network configuration")

	// Log validation start
	testLogger.Info(t, t.Name()+" Validation started ......")

	// Connect to the master node via SSH and handle connection errors
	sshClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPs[0])
	require.NoError(t, connectionErr, "Failed to establish SSH connection to master node - check network and credentials")

	defer func() {
		if err := sshClient.Close(); err != nil {
			testLogger.Info(t, fmt.Sprintf("failed to close sshClient: %v", err))
		}
	}()

	testLogger.Info(t, "SSH connection to the master successful")
	t.Log("Validation in progress. Please wait...")

	runClusterValidationsOnManagementNode(t, sshClient, bastionIP, managementNodeIPs, expected, jobCommandMed, testLogger)

	// Validate LSF logs: Check if the logs are stored in their correct directory and ensure symbolic links are present
	ValidateLSFLogs(t, sshClient, os.Getenv("TF_VAR_ibmcloud_api_key"), utils.GetRegion(expected.Zone), expected.ResourceGroup, bastionIP, managementNodeIPs, testLogger)

	// Reconnect to the master node via SSH after reboot
	sshClient, connectionErr = utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPs[0])
	require.NoError(t, connectionErr, "Failed to re-establish SSH connection after reboot - check node recovery")

	// Wait for dynamic node disappearance
	defer func() {
		if err := WaitForDynamicNodeDisappearance(t, sshClient, testLogger); err != nil {
			t.Errorf("Error in WaitForDynamicNodeDisappearance: %v", err)
		}
	}()

	runClusterValidationsOnComputeNode(t, sshClient, bastionIP, staticWorkerNodeIPs, expected, jobCommandLow, testLogger)

	//runClusterValidationsOnLoginNode(t, bastionIP, loginNodeIP, expected, managementNodeIPs, staticWorkerNodeIPs, jobCommandLow, testLogger)

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
	expected := GetExpectedClusterConfig(t, options)
	WorkerNodeMinCount, err := utils.GetTotalStaticComputeCount(t, options.TerraformVars, testLogger)
	require.NoError(t, err, "Error retrieving worker node total count")

	// Get the job command for low memory tasks and ignore the other ones
	jobCommandLow, _, _ := GenerateLSFJobCommandsForMemoryTypes()

	// Retrieve IPs for all the required nodes (bastion, management, login, and static worker)
	bastionIP, managementNodeIPs, _, staticWorkerNodeIPs, getClusterIPErr := GetClusterIPs(t, options, testLogger)
	require.NoError(t, getClusterIPErr, "Failed to get cluster IPs from Terraform outputs - check network configuration")

	// Log validation start
	testLogger.Info(t, t.Name()+" Validation started ......")

	// Connect to the master node via SSH and handle connection errors
	sshClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPs[0])
	require.NoError(t, connectionErr, "Failed to establish SSH connection to master node - check network and credentials")

	defer func() {
		if err := sshClient.Close(); err != nil {
			testLogger.Info(t, fmt.Sprintf("failed to close sshClient: %v", err))
		}
	}()

	testLogger.Info(t, "SSH connection to the master successful")
	t.Log("Validation in progress. Please wait...")

	// Verify management node configuration
	VerifyManagementNodeConfig(t, sshClient, expected.MasterName, expected.Hyperthreading, managementNodeIPs, expected.LsfVersion, testLogger)

	// Verify dedicated host configuration
	ValidateDedicatedHost(t, os.Getenv("TF_VAR_ibmcloud_api_key"), utils.GetRegion(expected.Zone), expected.ResourceGroup, expected.MasterName, WorkerNodeMinCount, expectedDedicatedHostPresence, testLogger)

	// Reconnect to the management node after reboot
	sshClient, connectionErr = utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPs[0])
	require.NoError(t, connectionErr, "Failed to re-establish SSH connection after reboot - check node recovery")

	// Wait for dynamic node disappearance and handle potential errors
	defer func() {
		if err := WaitForDynamicNodeDisappearance(t, sshClient, testLogger); err != nil {
			t.Errorf("Error in WaitForDynamicNodeDisappearance: %v", err)
		}
	}()

	runClusterValidationsOnComputeNode(t, sshClient, bastionIP, staticWorkerNodeIPs, expected, jobCommandLow, testLogger)

	//runClusterValidationsOnLoginNode(t, bastionIP, loginNodeIP, expected, managementNodeIPs, staticWorkerNodeIPs, jobCommandLow, testLogger)

	// Verify PTR records for management and login nodes
	VerifyPTRRecordsForManagement(t, sshClient, LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPs, expected.DnsDomainName, testLogger)

	// Verify LSF DNS settings on login node
	//VerifyLSFDNS(t, sshClient, []string{loginNodeIP}, expected.DnsDomainName, testLogger)

	// Verify file share encryption configuration
	VerifyFileShareEncryption(t, sshClient, os.Getenv("TF_VAR_ibmcloud_api_key"), utils.GetRegion(expected.Zone), expected.ResourceGroup, expected.MasterName, expected.KeyManagement, managementNodeIPs, testLogger)

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
	expected := GetExpectedClusterConfig(t, options)

	// Retrieve server IPs (different logic for HPC vs LSF solutions)
	bastionIP, managementNodeIPs, _, staticWorkerNodeIPs, getClusterIPErr := GetClusterIPs(t, options, testLogger)
	require.NoError(t, getClusterIPErr, "Failed to get cluster IPs from Terraform outputs - check network configuration")

	// Get the job command for low memory tasks and ignore the other ones
	jobCommandLow, _, _ := GenerateLSFJobCommandsForMemoryTypes()

	// Log validation start
	testLogger.Info(t, t.Name()+" Validation started ......")

	// Connect to the master node via SSH and handle connection errors
	sshClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPs[0])
	require.NoError(t, connectionErr, "Failed to establish SSH connection to master node - check network and credentials")

	defer func() {
		if err := sshClient.Close(); err != nil {
			testLogger.Info(t, fmt.Sprintf("failed to close sshClient: %v", err))
		}
	}()

	testLogger.Info(t, "SSH connection to the master successful")
	t.Log("Validation in progress. Please wait...")

	// Verify management node configuration
	VerifyManagementNodeConfig(t, sshClient, expected.MasterName, expected.Hyperthreading, managementNodeIPs, expected.LsfVersion, testLogger)

	// Verify SCC instance
	ValidateSCCInstance(t, os.Getenv("TF_VAR_ibmcloud_api_key"), utils.GetRegion(expected.Zone), expected.ResourceGroup, expected.MasterName, SCC_INSTANCE_REGION, testLogger)

	// Wait for dynamic node disappearance and handle potential errors
	defer func() {
		if err := WaitForDynamicNodeDisappearance(t, sshClient, testLogger); err != nil {
			t.Errorf("Error in WaitForDynamicNodeDisappearance: %v", err)
		}
	}()

	// Run job to verify job execution on the cluster
	VerifyJobs(t, sshClient, jobCommandLow, testLogger)

	// Get compute node IPs and handle errors
	computeNodeIPList, err := GetComputeNodeIPs(t, sshClient, staticWorkerNodeIPs, testLogger)
	if err != nil {
		t.Fatalf("Failed to retrieve dynamic compute node IPs: %v", err)
	}

	// Verify compute node configuration
	VerifyComputeNodeConfig(t, sshClient, expected.Hyperthreading, computeNodeIPList, testLogger)

	//runClusterValidationsOnLoginNode(t, bastionIP, loginNodeIP, expected, managementNodeIPs, staticWorkerNodeIPs, jobCommandLow, testLogger)

	// Verify file share encryption configuration
	VerifyFileShareEncryption(t, sshClient, os.Getenv("TF_VAR_ibmcloud_api_key"), utils.GetRegion(expected.Zone), expected.ResourceGroup, expected.MasterName, expected.KeyManagement, managementNodeIPs, testLogger)

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
	expected := GetExpectedClusterConfig(t, options)

	expectedLogsEnabledForManagement, err := strconv.ParseBool(fmt.Sprintf("%v", options.TerraformVars["observability_logs_enable_for_management"]))
	require.NoError(t, err, "Failed to parse observability_logs_enable_for_management from Terraform vars - check variable type and value")

	expectedLogsEnabledForCompute, err := strconv.ParseBool(fmt.Sprintf("%v", options.TerraformVars["observability_logs_enable_for_compute"]))
	require.NoError(t, err, "Failed to parse observability_logs_enable_for_compute from Terraform vars - check variable type and value")

	// Retrieve server IPs (different logic for HPC vs LSF solutions)
	bastionIP, managementNodeIPs, _, staticWorkerNodeIPs, getClusterIPErr := GetClusterIPs(t, options, testLogger)
	require.NoError(t, getClusterIPErr, "Failed to get cluster IPs from Terraform outputs - check network configuration")

	deployerIP, getdeployerIPErr := GetDeployerIPs(t, options, testLogger)
	require.NoError(t, getdeployerIPErr, "Failed to get deployer IP from Terraform outputs - check deployer configuration")

	// Set job commands for low and medium memory tasks, ignoring high memory command
	jobCommandLow, jobCommandMed, _ := GenerateLSFJobCommandsForMemoryTypes()

	// Log validation start
	testLogger.Info(t, t.Name()+" Validation started ......")

	VerifyTestTerraformOutputs(t, bastionIP, deployerIP, true, false, false, testLogger)

	// Connect to the master node via SSH and handle connection errors
	sshClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPs[0])
	require.NoError(t, connectionErr, "Failed to establish SSH connection to master node - check network and credentials")

	defer func() {
		if err := sshClient.Close(); err != nil {
			testLogger.Info(t, fmt.Sprintf("failed to close sshClient: %v", err))
		}
	}()

	testLogger.Info(t, "SSH connection to the master successful")
	t.Log("Validation in progress. Please wait...")

	// Verify management node configuration
	runClusterValidationsOnManagementNode(t, sshClient, bastionIP, managementNodeIPs, expected, jobCommandMed, testLogger)

	// Reconnect to the management node after reboot
	sshClient, connectionErr = utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPs[0])
	require.NoError(t, connectionErr, "Failed to re-establish SSH connection after reboot - check node recovery")

	// Wait for dynamic node disappearance and handle potential errors
	defer func() {
		if err := WaitForDynamicNodeDisappearance(t, sshClient, testLogger); err != nil {
			t.Errorf("Error in WaitForDynamicNodeDisappearance: %v", err)
		}
	}()

	runClusterValidationsOnComputeNode(t, sshClient, bastionIP, staticWorkerNodeIPs, expected, jobCommandLow, testLogger)

	// Verify that cloud logs are enabled and correctly configured
	VerifyCloudLogs(t, sshClient, options.LastTestTerraformOutputs, managementNodeIPs, staticWorkerNodeIPs, expectedLogsEnabledForManagement, expectedLogsEnabledForCompute, testLogger)

	//runClusterValidationsOnLoginNode(t, bastionIP, loginNodeIP, expected, managementNodeIPs, staticWorkerNodeIPs, jobCommandLow, testLogger)

	// Verify file share encryption
	VerifyFileShareEncryption(t, sshClient, os.Getenv("TF_VAR_ibmcloud_api_key"), utils.GetRegion(expected.Zone), expected.ResourceGroup, expected.MasterName, expected.KeyManagement, managementNodeIPs, testLogger)

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
	expected := GetExpectedClusterConfig(t, options)

	expectedMonitoringEnabledForManagement, err := strconv.ParseBool(fmt.Sprintf("%v", options.TerraformVars["observability_monitoring_enable"]))
	require.NoError(t, err, "Failed to parse observability_monitoring_enable from Terraform vars - check variable type and value")

	expectedMonitoringEnabledForCompute, err := strconv.ParseBool(fmt.Sprintf("%v", options.TerraformVars["observability_monitoring_on_compute_nodes_enable"]))
	require.NoError(t, err, "Failed to parse observability_monitoring_on_compute_nodes_enable from Terraform vars - check variable type and value")

	// Retrieve server IPs (different logic for HPC vs LSF solutions)
	bastionIP, managementNodeIPs, _, staticWorkerNodeIPs, getClusterIPErr := GetClusterIPs(t, options, testLogger)
	require.NoError(t, getClusterIPErr, "Failed to get cluster IPs from Terraform outputs - check network configuration")

	deployerIP, getdeployerIPErr := GetDeployerIPs(t, options, testLogger)
	require.NoError(t, getdeployerIPErr, "Failed to get deployer IP from Terraform outputs - check deployer configuration")

	// Set job commands for low and medium memory tasks, ignoring high memory command
	jobCommandLow, jobCommandMed, _ := GenerateLSFJobCommandsForMemoryTypes()

	// Log validation start
	testLogger.Info(t, t.Name()+" Validation started ......")

	VerifyTestTerraformOutputs(t, bastionIP, deployerIP, false, true, false, testLogger)

	// Connect to the master node via SSH and handle connection errors
	sshClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPs[0])
	require.NoError(t, connectionErr, "Failed to establish SSH connection to master node - check network and credentials")

	defer func() {
		if err := sshClient.Close(); err != nil {
			testLogger.Info(t, fmt.Sprintf("failed to close sshClient: %v", err))
		}
	}()

	testLogger.Info(t, "SSH connection to the master successful")
	t.Log("Validation in progress. Please wait...")

	// Verify management node configuration
	runClusterValidationsOnManagementNode(t, sshClient, bastionIP, managementNodeIPs, expected, jobCommandMed, testLogger)

	// Reconnect to the management node after reboot
	sshClient, connectionErr = utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPs[0])
	require.NoError(t, connectionErr, "Failed to re-establish SSH connection after reboot - check node recovery")

	// Wait for dynamic node disappearance and handle potential errors
	defer func() {
		if err := WaitForDynamicNodeDisappearance(t, sshClient, testLogger); err != nil {
			t.Errorf("Error in WaitForDynamicNodeDisappearance: %v", err)
		}
	}()

	runClusterValidationsOnComputeNode(t, sshClient, bastionIP, staticWorkerNodeIPs, expected, jobCommandLow, testLogger)

	//runClusterValidationsOnLoginNode(t, bastionIP, loginNodeIP, expected, managementNodeIPs, staticWorkerNodeIPs, jobCommandLow, testLogger)

	// Verify that cloud monitoring are enabled and correctly configured
	VerifyCloudMonitoring(t, sshClient, options.LastTestTerraformOutputs, managementNodeIPs, staticWorkerNodeIPs, expectedMonitoringEnabledForManagement, expectedMonitoringEnabledForCompute, testLogger)

	// Verify PTR records
	VerifyPTRRecordsForManagement(t, sshClient, LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPs, expected.DnsDomainName, testLogger)

	// Verify file share encryption
	VerifyFileShareEncryption(t, sshClient, os.Getenv("TF_VAR_ibmcloud_api_key"), utils.GetRegion(expected.Zone), expected.ResourceGroup, expected.MasterName, expected.KeyManagement, managementNodeIPs, testLogger)

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

	// Retrieve common cluster details from options
	expected := GetExpectedClusterConfig(t, options)

	expectedTargetType := options.TerraformVars["observability_atracker_target_type"].(string)

	expectedObservabilityAtrackerEnable, err := strconv.ParseBool(fmt.Sprintf("%v", options.TerraformVars["observability_atracker_enable"]))
	require.NoError(t, err, "Failed to parse observability_atracker_enable from Terraform vars - check variable type and value")

	// Retrieve server IPs (different logic for HPC vs LSF solutions)
	bastionIP, managementNodeIPs, _, staticWorkerNodeIPs, getClusterIPErr := GetClusterIPs(t, options, testLogger)
	require.NoError(t, getClusterIPErr, "Failed to get cluster IPs from Terraform outputs - check network configuration")

	// Set job commands for low and medium memory tasks, ignoring high memory command
	jobCommandLow, jobCommandMed, _ := GenerateLSFJobCommandsForMemoryTypes()

	// Log validation start
	testLogger.Info(t, t.Name()+" Validation started ......")

	// Connect to the master node via SSH and handle connection errors
	sshClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPs[0])
	require.NoError(t, connectionErr, "Failed to establish SSH connection to master node - check network and credentials")

	defer func() {
		if err := sshClient.Close(); err != nil {
			testLogger.Info(t, fmt.Sprintf("failed to close sshClient: %v", err))
		}
	}()

	testLogger.Info(t, "SSH connection to the master successful")
	t.Log("Validation in progress. Please wait...")

	runClusterValidationsOnManagementNode(t, sshClient, bastionIP, managementNodeIPs, expected, jobCommandMed, testLogger)

	// Reconnect to the management node after reboot
	sshClient, connectionErr = utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPs[0])
	require.NoError(t, connectionErr, "Failed to re-establish SSH connection after reboot - check node recovery")

	// Wait for dynamic node disappearance and handle potential errors
	defer func() {
		if err := WaitForDynamicNodeDisappearance(t, sshClient, testLogger); err != nil {
			t.Errorf("Error in WaitForDynamicNodeDisappearance: %v", err)
		}
	}()

	runClusterValidationsOnComputeNode(t, sshClient, bastionIP, staticWorkerNodeIPs, expected, jobCommandLow, testLogger)

	// Validate Atracker
	ibmCloudAPIKey := os.Getenv("TF_VAR_ibmcloud_api_key")
	ValidateAtracker(t, ibmCloudAPIKey, utils.GetRegion(expected.Zone), expected.ResourceGroup, expected.MasterName, expectedTargetType, expectedObservabilityAtrackerEnable, testLogger)

	//runClusterValidationsOnLoginNode(t, bastionIP, loginNodeIP, expected, managementNodeIPs, staticWorkerNodeIPs, jobCommandLow, testLogger)

	// Verify PTR records
	VerifyPTRRecordsForManagement(t, sshClient, LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPs, expected.DnsDomainName, testLogger)

	// Verify file share encryption
	VerifyFileShareEncryption(t, sshClient, ibmCloudAPIKey, utils.GetRegion(expected.Zone), expected.ResourceGroup, expected.MasterName, expected.KeyManagement, managementNodeIPs, testLogger)

	testLogger.Info(t, t.Name()+" Validation ended")
}

// ValidateBasicObservabilityClusterConfiguration verifies observability features in an HPC LSF cluster.
// It checks log/monitoring enablement, Atracker config, DNS, PTR records, and encryption settings.
// The function connects to management and compute nodes via SSH for validations.
// It ensures dynamic worker nodes disappear as expected after reboot.

func ValidateBasicObservabilityClusterConfiguration(t *testing.T, options *testhelper.TestOptions, testLogger *utils.AggregatedLogger) {
	// Retrieve common cluster details from options
	expected := GetExpectedClusterConfig(t, options)

	expectedLogsEnabledForManagement, err := strconv.ParseBool(fmt.Sprintf("%v", options.TerraformVars["observability_logs_enable_for_management"]))
	require.NoError(t, err, "Failed to parse observability_logs_enable_for_management from Terraform vars - check variable type and value")

	expectedLogsEnabledForCompute, err := strconv.ParseBool(fmt.Sprintf("%v", options.TerraformVars["observability_logs_enable_for_compute"]))
	require.NoError(t, err, "Failed to parse observability_logs_enable_for_compute from Terraform vars - check variable type and value")

	expectedEnabledPlatFormLogs, err := strconv.ParseBool(fmt.Sprintf("%v", options.TerraformVars["observability_enable_platform_logs"]))
	require.NoError(t, err, "Failed to parse observability_enable_platform_logs from Terraform vars - check variable type and value")

	expectedMonitoringEnabledForManagement, err := strconv.ParseBool(fmt.Sprintf("%v", options.TerraformVars["observability_monitoring_enable"]))
	require.NoError(t, err, "Failed to parse observability_monitoring_enable from Terraform vars - check variable type and value")

	expectedMonitoringEnabledForCompute, err := strconv.ParseBool(fmt.Sprintf("%v", options.TerraformVars["observability_monitoring_on_compute_nodes_enable"]))
	require.NoError(t, err, "Failed to parse observability_monitoring_on_compute_nodes_enable from Terraform vars - check variable type and value")

	expectedTargetType := options.TerraformVars["observability_atracker_target_type"].(string)

	expectedObservabilityAtrackerEnable, err := strconv.ParseBool(fmt.Sprintf("%v", options.TerraformVars["observability_atracker_enable"]))
	require.NoError(t, err, "Failed to parse observability_atracker_enable from Terraform vars - check variable type and value")

	// Retrieve server IPs
	bastionIP, managementNodeIPs, _, staticWorkerNodeIPs, getClusterIPErr := GetClusterIPs(t, options, testLogger)
	require.NoError(t, getClusterIPErr, "Failed to get cluster IPs from Terraform outputs - check network configuration")

	deployerIP, getdeployerIPErr := GetDeployerIPs(t, options, testLogger)
	require.NoError(t, getdeployerIPErr, "Failed to get deployer IP from Terraform outputs - check deployer configuration")

	// Set job commands for low and medium memory tasks (high memory command skipped)
	jobCommandLow, jobCommandMed, _ := GenerateLSFJobCommandsForMemoryTypes()

	testLogger.Info(t, t.Name()+" validation started")

	VerifyTestTerraformOutputs(t, bastionIP, deployerIP, true, true, false, testLogger)

	// Connect to the master node
	sshClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPs[0])
	require.NoError(t, connectionErr, "Failed to establish SSH connection to master node - check network and credentials")
	defer func() {
		if err := sshClient.Close(); err != nil {
			testLogger.Info(t, fmt.Sprintf("Failed to close SSH client: %v", err))
		}
	}()
	testLogger.Info(t, "SSH connection to the master successful")
	t.Log("Validation in progress. Please wait...")

	// Run validations
	runClusterValidationsOnManagementNode(t, sshClient, bastionIP, managementNodeIPs, expected, jobCommandMed, testLogger)

	// Reconnect after reboot
	sshClient, connectionErr = utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPs[0])
	require.NoError(t, connectionErr, "Failed to re-establish SSH connection after reboot - check node recovery")

	// Ensure dynamic worker nodes disappear
	defer func() {
		if err := WaitForDynamicNodeDisappearance(t, sshClient, testLogger); err != nil {
			t.Errorf("Error in WaitForDynamicNodeDisappearance: %v", err)
		}
	}()

	runClusterValidationsOnComputeNode(t, sshClient, bastionIP, staticWorkerNodeIPs, expected, jobCommandLow, testLogger)

	// Observability validations
	VerifyCloudLogs(t, sshClient, options.LastTestTerraformOutputs, managementNodeIPs, staticWorkerNodeIPs, expectedLogsEnabledForManagement, expectedLogsEnabledForCompute, testLogger)

	// Monitoring validations
	VerifyCloudMonitoring(t, sshClient, options.LastTestTerraformOutputs, managementNodeIPs, staticWorkerNodeIPs, expectedMonitoringEnabledForManagement, expectedMonitoringEnabledForCompute, testLogger)

	// Atracker validation
	ibmCloudAPIKey := os.Getenv("TF_VAR_ibmcloud_api_key")
	ValidateAtracker(t, ibmCloudAPIKey, utils.GetRegion(expected.Zone), expected.ResourceGroup, expected.MasterName, expectedTargetType, expectedObservabilityAtrackerEnable, testLogger)

	//Platform validation
	VerifyPlatformLogs(t, ibmCloudAPIKey, utils.GetRegion(expected.Zone), expected.ResourceGroup, expectedEnabledPlatFormLogs, testLogger)

	//runClusterValidationsOnLoginNode(t, bastionIP, loginNodeIP, expected, managementNodeIPs, staticWorkerNodeIPs, jobCommandLow, testLogger)

	// PTR and DNS validations
	VerifyPTRRecordsForManagement(t, sshClient, LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPs, expected.DnsDomainName, testLogger)

	// Verify LSF DNS
	//VerifyLSFDNS(t, sshClient, []string{loginNodeIP}, expected.DnsDomainName, testLogger)

	// Encryption validation
	VerifyFileShareEncryption(t, sshClient, ibmCloudAPIKey, utils.GetRegion(expected.Zone), expected.ResourceGroup, expected.MasterName, expected.KeyManagement, managementNodeIPs, testLogger)

	testLogger.Info(t, t.Name()+" validation ended")
}

// ValidateClusterConfigurationWithMultipleKeys performs a comprehensive validation on the cluster setup.
// It connects to various cluster components via SSH and verifies their configurations and functionality,
// including management nodes, compute nodes, login nodes, and dynamic compute nodes. It also performs
// additional validation checks like failover procedures, SSH key verification, and DNS verification.
// The function logs detailed information throughout the validation process but does not return any value.
func ValidateClusterConfigurationWithMultipleKeys(t *testing.T, options *testhelper.TestOptions, testLogger *utils.AggregatedLogger) {

	// Retrieve common cluster details from options
	expected := GetExpectedClusterConfig(t, options)

	// Retrieve server IPs (different logic for HPC vs LSF solutions)
	bastionIP, managementNodeIPs, loginNodeIP, staticWorkerNodeIPs, getClusterIPErr := GetClusterIPs(t, options, testLogger)
	require.NoError(t, getClusterIPErr, "Failed to get cluster IPs from Terraform outputs - check network configuration")

	// Set job commands for low and medium memory tasks, ignoring high memory command
	jobCommandLow, jobCommandMed, _ := GenerateLSFJobCommandsForMemoryTypes()

	// Log validation start
	testLogger.Info(t, t.Name()+" Validation started ......")

	// Connect to the management node via SSH
	sshClientOne, sshClientTwo, connectionErrOne, connectionErrTwo := utils.ConnectToHostsWithMultipleUsers(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPs[0])
	require.NoError(t, connectionErrOne, "Failed to connect to the master via SSH")
	require.NoError(t, connectionErrTwo, "Failed to connect to the master via SSH")

	defer func() {
		if err := sshClientOne.Close(); err != nil {
			testLogger.Info(t, fmt.Sprintf("failed to close sshClientOne: %v", err))
		}
	}()

	defer func() {
		if err := sshClientTwo.Close(); err != nil {
			testLogger.Info(t, fmt.Sprintf("failed to close sshClientTwo: %v", err))
		}
	}()

	testLogger.Info(t, "SSH connection to the master successful")
	t.Log("Validation in progress. Please wait...")

	// Verify management node configuration
	VerifyManagementNodeConfig(t, sshClientOne, expected.MasterName, expected.Hyperthreading, managementNodeIPs, expected.LsfVersion, testLogger)
	VerifyManagementNodeConfig(t, sshClientTwo, expected.MasterName, expected.Hyperthreading, managementNodeIPs, expected.LsfVersion, testLogger)

	// Verify SSH key on management node
	VerifySSHKey(t, sshClientOne, bastionIP, LSF_PUBLIC_HOST_NAME, LSF_PRIVATE_HOST_NAME, "management", managementNodeIPs, expected.NumOfKeys, testLogger)

	// Perform failover and failback
	FailoverAndFailback(t, sshClientOne, jobCommandMed, testLogger)

	// Restart LSF daemon
	RestartLsfDaemon(t, sshClientOne, testLogger)

	// Reboot instance
	RebootInstance(t, sshClientOne, bastionIP, LSF_PUBLIC_HOST_NAME, LSF_PRIVATE_HOST_NAME, managementNodeIPs[0], testLogger)

	// Reconnect to the management node after reboot
	sshClientOne, connectionErrOne = utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPs[0])
	require.NoError(t, connectionErrOne, "Failed to reconnect to the master via SSH: %v", connectionErrOne)

	defer func() {
		if err := sshClientOne.Close(); err != nil {
			testLogger.Info(t, fmt.Sprintf("failed to close sshClientOne: %v", err))
		}
	}()

	// Wait for dynamic node disappearance and handle potential errors
	defer func() {
		if err := WaitForDynamicNodeDisappearance(t, sshClientOne, testLogger); err != nil {
			t.Errorf("Error in WaitForDynamicNodeDisappearance: %v", err)
		}
	}()

	// Run job
	VerifyJobs(t, sshClientOne, jobCommandLow, testLogger)

	// Get compute node IPs and handle errors
	computeNodeIPList, err := GetComputeNodeIPs(t, sshClientOne, staticWorkerNodeIPs, testLogger)
	if err != nil {
		t.Fatalf("Failed to retrieve dynamic compute node IPs: %v", err)
	}

	// Verify compute node configuration
	VerifyComputeNodeConfig(t, sshClientOne, expected.Hyperthreading, computeNodeIPList, testLogger)

	// Verify SSH key on compute nodes
	VerifySSHKey(t, sshClientOne, bastionIP, LSF_PUBLIC_HOST_NAME, LSF_PRIVATE_HOST_NAME, "compute", computeNodeIPList, expected.NumOfKeys, testLogger)

	// Verify LSF DNS on compute nodes
	VerifyLSFDNS(t, sshClientOne, computeNodeIPList, expected.DnsDomainName, testLogger)

	// Verify SSH connectivity from login node
	// sshLoginNodeClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, loginNodeIP)
	// require.NoError(t, connectionErr, "Failed to connect to the login node via SSH")

	// defer func() {
	// 	if err := sshLoginNodeClient.Close(); err != nil {
	// 		testLogger.Info(t, fmt.Sprintf("failed to close sshLoginNodeClient: %v", err))
	// 	}
	// }()

	// Verify login node configuration
	//VerifyLoginNodeConfig(t, sshLoginNodeClient, expected.MasterName, expected.Hyperthreading, loginNodeIP, jobCommandLow, EXPECTED_LSF_VERSION, testLogger)

	// Get compute node IPs and handle errors
	computeNodeIPList, err = GetComputeNodeIPs(t, sshClientOne, staticWorkerNodeIPs, testLogger)
	if err != nil {
		t.Fatalf("Failed to retrieve dynamic compute node IPs: %v", err)
	}

	// Verify SSH connectivity from login node
	//VerifySSHConnectivityToNodesFromLogin(t, sshLoginNodeClient, managementNodeIPs, computeNodeIPList, testLogger)

	// Verify LSF DNS on login node
	VerifyLSFDNS(t, sshClientOne, []string{loginNodeIP}, expected.DnsDomainName, testLogger)

	// Verify file share encryption
	VerifyFileShareEncryption(t, sshClientOne, os.Getenv("TF_VAR_ibmcloud_api_key"), utils.GetRegion(expected.Zone), expected.ResourceGroup, expected.MasterName, expected.KeyManagement, managementNodeIPs, testLogger)

	// Log validation end
	testLogger.Info(t, t.Name()+" Validation ended")
}

//	ValidateBasicClusterConfigurationForMultiProfileStaticAndDynamic validates key components of an LSF cluster
//
// with static and dynamic compute node profiles. It checks SSH connectivity, management and compute node setups,
// job execution, and file share encryption. Validation results are logged, and critical issues fail the test.
func ValidateBasicClusterConfigurationForMultiProfileStaticAndDynamic(t *testing.T, options *testhelper.TestOptions, testLogger *utils.AggregatedLogger) {
	// Retrieve common cluster details from options
	expected := GetExpectedClusterConfig(t, options)

	// Retrieve server IPs (logic varies for HPC vs. LSF clusters)
	bastionIP, managementNodeIPs, _, staticWorkerNodeIPs, getClusterIPErr := GetClusterIPs(t, options, testLogger)
	require.NoError(t, getClusterIPErr, "Failed to get cluster IPs from Terraform outputs - check network configuration")

	// Get job command for high memory tasks
	_, _, jobCommandHigh := GenerateLSFJobCommandsForMemoryTypes()

	// Log validation start
	testLogger.Info(t, t.Name()+" validation started...")

	// Connect to master node via SSH
	sshClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPs[0])
	require.NoError(t, connectionErr, "Failed to establish SSH connection to master node - check network and credentials")

	defer func() {
		if err := sshClient.Close(); err != nil {
			testLogger.Info(t, fmt.Sprintf("Failed to close sshClient: %v", err))
		}
	}()

	testLogger.Info(t, "SSH connection to the master successful")
	t.Log("Validation in progress. Please wait...")

	// Verify management node configuration
	VerifyManagementNodeConfig(t, sshClient, expected.MasterName, expected.Hyperthreading, managementNodeIPs, expected.LsfVersion, testLogger)

	// Wait for dynamic node disappearance after job runs
	defer func() {
		if err := WaitForDynamicNodeDisappearance(t, sshClient, testLogger); err != nil {
			t.Errorf("Error in WaitForDynamicNodeDisappearance: %v", err)
		}
	}()

	// Run job to trigger dynamic node behavior
	VerifyJobs(t, sshClient, jobCommandHigh, testLogger)

	// Verify dynamic node profile
	ValidateDynamicNodeProfile(t, os.Getenv("TF_VAR_ibmcloud_api_key"), utils.GetRegion(expected.Zone), expected.ResourceGroup, expected.MasterName, options, testLogger)

	// Get compute node IPs (static + dynamic)
	computeNodeIPList, err := GetComputeNodeIPs(t, sshClient, staticWorkerNodeIPs, testLogger)
	if err != nil {
		t.Fatalf("Failed to retrieve compute node IPs: %v", err)
	}

	// Verify compute node configuration
	VerifyComputeNodeConfig(t, sshClient, expected.Hyperthreading, computeNodeIPList, testLogger)

	// Uncomment when login node validation is ready
	// runClusterValidationsOnLoginNode(t, bastionIP, loginNodeIP, expected, managementNodeIPs, staticWorkerNodeIPs, jobCommandLow, testLogger)

	// Verify PTR records
	VerifyPTRRecordsForManagement(t, sshClient, LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPs, expected.DnsDomainName, testLogger)

	// Verify file share encryption and key management
	VerifyFileShareEncryption(t, sshClient, os.Getenv("TF_VAR_ibmcloud_api_key"), utils.GetRegion(expected.Zone), expected.ResourceGroup, expected.MasterName, expected.KeyManagement, managementNodeIPs, testLogger)

	// Log validation end
	testLogger.Info(t, t.Name()+" validation ended")
}
