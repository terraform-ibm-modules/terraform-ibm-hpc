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
	Zones          string
	NumOfKeys      int
	DnsDomainName  string
	Hyperthreading bool
	LsfVersion     string
	AcPassword     string
}

// GetExpectedClusterConfig retrieves and structures the expected cluster
// configuration from Terraform output variables.
func GetExpectedClusterConfig(t *testing.T, options *testhelper.TestOptions) ExpectedClusterConfig {
	masterName := utils.GetStringVarWithDefault(options.TerraformVars, "cluster_prefix", "")
	resourceGroup := utils.GetStringVarWithDefault(options.TerraformVars, "existing_resource_group", "")
	keyManagement := utils.GetStringVarWithDefault(options.TerraformVars, "key_management", "null")
	lsfVersion := utils.GetStringVarWithDefault(options.TerraformVars, "lsf_version", "")
	acPassword := utils.GetStringVarWithDefault(options.TerraformVars, "webservice_appcenter_password", "") //pragma: allowlist secret

	zone := options.TerraformVars["zones"].([]string)[0]
	numKeys := len(options.TerraformVars["ssh_keys"].([]string))

	dnsJSON := options.TerraformVars["dns_domain_name"].(string)
	var dnsMap map[string]string
	require.NoError(t, json.Unmarshal([]byte(dnsJSON), &dnsMap), "Failed to unmarshal dns_domain_name")

	hyperthreading, err := strconv.ParseBool(options.TerraformVars["enable_hyperthreading"].(string))
	require.NoError(t, err, "Failed to parse enable_hyperthreading from Terraform vars")

	return ExpectedClusterConfig{
		MasterName:     masterName,
		ResourceGroup:  resourceGroup,
		KeyManagement:  keyManagement,
		Zones:          zone,
		NumOfKeys:      numKeys,
		DnsDomainName:  dnsMap["compute"],
		Hyperthreading: hyperthreading,
		LsfVersion:     lsfVersion,
		AcPassword:     acPassword, //pragma: allowlist secret
	}
}

// runClusterValidationsOnManagementNode performs a series of validation
// checks on the management nodes of the LSF cluster. This includes
// verifying configuration, SSH keys, DNS, failover, and daemon restarts.
// NOTE: This function calls RebootInstance internally, which invalidates
// the passed sshClient. Callers must reconnect after this returns.
func runClusterValidationsOnManagementNode(t *testing.T, sshClient *ssh.Client, bastionIP string, managementNodeIPs []string, expected ExpectedClusterConfig, jobCmd string, logger *utils.AggregatedLogger) {

	logger.Info(t, "Running management node and App Center validations sequentially...")

	VerifyManagementNodeConfig(t, sshClient, expected.MasterName, expected.Hyperthreading, managementNodeIPs, expected.LsfVersion, logger)

	VerifyJobs(t, sshClient, jobCmd, logger)

	//VerifyNoVNCConfig(t, sshClient, logger)

	VerifySSHKey(t, sshClient, bastionIP, LSF_PUBLIC_HOST_NAME, LSF_PRIVATE_HOST_NAME, "management", managementNodeIPs, expected.NumOfKeys, logger)

	VerifyLSFDNS(t, sshClient, managementNodeIPs, expected.DnsDomainName, logger)

	//FailoverAndFailback(t, sshClient, jobCmd, logger)

	RestartLsfDaemon(t, sshClient, logger)

	RebootInstance(t, sshClient, bastionIP, LSF_PUBLIC_HOST_NAME, LSF_PRIVATE_HOST_NAME, managementNodeIPs[0], logger)

	VerifyLSFWebServicesConfig(t, sshClient, bastionIP, LSF_PUBLIC_HOST_NAME, LSF_PRIVATE_HOST_NAME, managementNodeIPs, logger)

	logger.Info(t, "Management node and App Center validations completed.")
}

// runClusterValidationsOnComputeNode executes validation steps specific
// to the compute nodes in the LSF cluster. This includes running jobs,
// verifying node configuration, SSH keys, and DNS settings.
func runClusterValidationsOnComputeNode(t *testing.T, sshClient *ssh.Client, bastionIP string, staticWorkerNodeIPs []string, expected ExpectedClusterConfig, jobCmd string, logger *utils.AggregatedLogger) {

	logger.Info(t, "Running compute node validations sequentially...")

	VerifyJobs(t, sshClient, jobCmd, logger)

	computeNodeIPList, err := GetComputeNodeIPs(t, sshClient, staticWorkerNodeIPs, logger)
	if err != nil {
		t.Fatalf("Failed to retrieve dynamic compute node IPs: %v", err)
	}

	VerifyComputeNodeConfig(t, sshClient, expected.Hyperthreading, computeNodeIPList, logger)

	VerifySSHKey(t, sshClient, bastionIP, LSF_PUBLIC_HOST_NAME, LSF_PRIVATE_HOST_NAME, "compute", computeNodeIPList, expected.NumOfKeys, logger)

	VerifyLSFDNS(t, sshClient, computeNodeIPList, expected.DnsDomainName, logger)

	logger.Info(t, "Compute node validations completed.")
}

// runClusterValidationsOnLoginNode conducts validations on the LSF login
// node, including verifying its configuration and SSH connectivity to
// management and compute nodes.
func runClusterValidationsOnLoginNode(t *testing.T, bastionIP, loginNodeIP string, expected ExpectedClusterConfig, managementNodeIPs, computeNodeIPs []string, jobCmd string, logger *utils.AggregatedLogger) {

	logger.Info(t, "Running login node validations sequentially...")

	loginSSHClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, loginNodeIP)
	if connectionErr != nil {
		msg := fmt.Sprintf("Failed to establish SSH connection to login node via bastion (%s) -> private IP (%s): %v", bastionIP, loginNodeIP, connectionErr)
		logger.FAIL(t, msg)
		require.FailNow(t, msg)
	}

	defer func() {
		if err := loginSSHClient.Close(); err != nil {
			logger.Info(t, fmt.Sprintf("Failed to close SSH connection: %v", err))
		}
	}()

	VerifyLoginNodeConfig(t, loginSSHClient, expected.MasterName, expected.Hyperthreading, loginNodeIP, jobCmd, expected.LsfVersion, logger)

	computeNodeIPs, connectionErr = GetComputeNodeIPs(t, loginSSHClient, computeNodeIPs, logger)
	if connectionErr != nil {
		t.Fatalf("Failed to retrieve dynamic compute node IPs: %v", connectionErr)
	}

	VerifySSHConnectivityToNodesFromLogin(t, loginSSHClient, managementNodeIPs, computeNodeIPs, logger)

	logger.Info(t, "Login node validations completed.")
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
func ValidateClusterConfiguration(t *testing.T, options *testhelper.TestOptions, logger *utils.AggregatedLogger) {

	expected := GetExpectedClusterConfig(t, options)

	bastionIP, managementNodeIPs, loginNodeIP, staticWorkerNodeIPs, getClusterIPErr := GetClusterIPs(t, options, logger)
	require.NoError(t, getClusterIPErr, "Failed to get cluster IPs from Terraform outputs - check network configuration")

	deployerIP, getdeployerIPErr := GetDeployerIPs(t, options, logger)
	require.NoError(t, getdeployerIPErr, "Failed to get deployer IP from Terraform outputs - check deployer configuration")

	jobCommandLow, jobCommandMed, _ := GenerateLSFJobCommandsForMemoryTypes()

	computeProfiles, _ := utils.GetComputeProfiles(t, options.TerraformVars, logger)
	mgmtProfiles, _ := utils.GetMgntProfiles(t, options.TerraformVars, logger)
	loginProfiles, _ := utils.GetLoginProfile(t, options.TerraformVars, logger)

	logger.Info(t, t.Name()+" Validation started ......")

	VerifyTestTerraformOutputs(t, bastionIP, deployerIP, false, false, false, logger)

	sshClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPs[0])
	if connectionErr != nil {
		msg := fmt.Sprintf("Failed to establish SSH connection to master node via bastion (%s) -> private IP (%s): %v", bastionIP, managementNodeIPs[0], connectionErr)
		logger.FAIL(t, msg)
		require.FailNow(t, msg)
	}

	defer func() {
		if err := sshClient.Close(); err != nil {
			logger.Info(t, fmt.Sprintf("failed to close sshClient: %v", err))
		}
	}()

	logger.Info(t, "SSH connection to the master successful")
	t.Log("Validation in progress. Please wait...")

	runClusterValidationsOnManagementNode(t, sshClient, bastionIP, managementNodeIPs, expected, jobCommandMed, logger)

	if err := sshClient.Close(); err != nil {
		logger.Info(t, fmt.Sprintf("failed to close pre-reboot sshClient: %v", err))
	}

	sshClient, connectionErr = utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPs[0])
	if connectionErr != nil {
		msg := fmt.Sprintf("SSH connection to master node via bastion (%s) -> private IP (%s) failed after reboot: %v", bastionIP, managementNodeIPs[0], connectionErr)
		logger.FAIL(t, msg)
		require.FailNow(t, msg)
	}

	defer func() {
		if err := WaitForDynamicNodeDisappearance(t, sshClient, logger); err != nil {
			logger.Error(t, fmt.Sprintf("error in WaitForDynamicNodeDisappearance: %v", err))
			t.Errorf("error in WaitForDynamicNodeDisappearance: %v", err)
		}
	}()

	runClusterValidationsOnComputeNode(t, sshClient, bastionIP, staticWorkerNodeIPs, expected, jobCommandLow, logger)

	runClusterValidationsOnLoginNode(t, bastionIP, loginNodeIP, expected, managementNodeIPs, staticWorkerNodeIPs, jobCommandLow, logger)

	VerifyPTRRecordsForManagement(t, sshClient, LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPs, expected.DnsDomainName, logger)

	VerifyLSFDNS(t, sshClient, []string{loginNodeIP}, expected.DnsDomainName, logger)

	VerifyFileShareEncryption(t, sshClient, os.Getenv("TF_VAR_ibmcloud_api_key"), utils.GetRegion(expected.Zones), expected.ResourceGroup, expected.MasterName, expected.KeyManagement, managementNodeIPs, logger)

	VerifyProfile(t, sshClient, computeProfiles, mgmtProfiles, loginProfiles, logger)

	logger.Info(t, t.Name()+" Validation ended")
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
func ValidateClusterConfigurationWithPACHA(t *testing.T, options *testhelper.TestOptions, logger *utils.AggregatedLogger) {

	expected := GetExpectedClusterConfig(t, options)

	bastionIP, managementNodeIPs, loginNodeIP, staticWorkerNodeIPs, getClusterIPErr := GetClusterIPs(t, options, logger)
	require.NoError(t, getClusterIPErr, "Failed to get cluster IPs from Terraform outputs - check network configuration")

	deployerIP, getdeployerIPErr := GetDeployerIPs(t, options, logger)
	require.NoError(t, getdeployerIPErr, "Failed to get deployer IP from Terraform outputs - check deployer configuration")

	jobCommandLow, jobCommandMed, _ := GenerateLSFJobCommandsForMemoryTypes()

	logger.Info(t, t.Name()+" Validation started ......")

	VerifyTestTerraformOutputs(t, bastionIP, deployerIP, false, false, false, logger)

	sshClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPs[0])
	if connectionErr != nil {
		msg := fmt.Sprintf("Failed to establish SSH connection to master node via bastion (%s) -> private IP (%s): %v", bastionIP, managementNodeIPs[0], connectionErr)
		logger.FAIL(t, msg)
		require.FailNow(t, msg)
	}

	defer func() {
		if err := sshClient.Close(); err != nil {
			logger.Info(t, fmt.Sprintf("failed to close sshClient: %v", err))
		}
	}()

	logger.Info(t, "SSH connection to the master successful")
	t.Log("Validation in progress. Please wait...")

	runClusterValidationsOnManagementNode(t, sshClient, bastionIP, managementNodeIPs, expected, jobCommandMed, logger)

	if err := sshClient.Close(); err != nil {
		logger.Info(t, fmt.Sprintf("failed to close pre-reboot sshClient: %v", err))
	}

	var managementNodeIP string
	if len(managementNodeIPs) == 1 {
		managementNodeIP = managementNodeIPs[0]
	} else {
		managementNodeIP = managementNodeIPs[1]
	}

	sshClient, connectionErr = utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIP)
	if connectionErr != nil {
		msg := fmt.Sprintf("SSH connection to master node via bastion (%s) -> private IP (%s) failed after reboot: %v", bastionIP, managementNodeIP, connectionErr)
		logger.FAIL(t, msg)
		require.FailNow(t, msg)
	}

	defer func() {
		if err := WaitForDynamicNodeDisappearance(t, sshClient, logger); err != nil {
			logger.Error(t, fmt.Sprintf("error in WaitForDynamicNodeDisappearance: %v", err))
			t.Errorf("error in WaitForDynamicNodeDisappearance: %v", err)
		}
	}()

	ValidatePACHAOnManagementNodes(t, sshClient, expected.DnsDomainName, bastionIP, managementNodeIPs, logger)

	runClusterValidationsOnComputeNode(t, sshClient, bastionIP, staticWorkerNodeIPs, expected, jobCommandLow, logger)

	runClusterValidationsOnLoginNode(t, bastionIP, loginNodeIP, expected, managementNodeIPs, staticWorkerNodeIPs, jobCommandLow, logger)

	VerifyPTRRecordsForManagement(t, sshClient, LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPs, expected.DnsDomainName, logger)

	VerifyLSFDNS(t, sshClient, []string{loginNodeIP}, expected.DnsDomainName, logger)

	VerifyFileShareEncryption(t, sshClient, os.Getenv("TF_VAR_ibmcloud_api_key"), utils.GetRegion(expected.Zones), expected.ResourceGroup, expected.MasterName, expected.KeyManagement, managementNodeIPs, logger)

	ValidatePACHAFailoverHealthCheckOnManagementNodes(t, sshClient, expected.DnsDomainName, bastionIP, managementNodeIPs, logger)

	logger.Info(t, t.Name()+" Validation ended")
}

// ValidateBasicClusterConfiguration validates basic cluster configuration.
// It performs validation tasks on essential aspects of the cluster setup,
// including the management node, compute nodes, and login node configurations.
// Additionally, it ensures proper connectivity and functionality.
// This function doesn't return any value but logs errors and validation steps during the process.
func ValidateBasicClusterConfiguration(t *testing.T, options *testhelper.TestOptions, logger *utils.AggregatedLogger) {

	expected := GetExpectedClusterConfig(t, options)

	bastionIP, managementNodeIPs, loginNodeIP, staticWorkerNodeIPs, getClusterIPErr := GetClusterIPs(t, options, logger)
	require.NoError(t, getClusterIPErr, "Failed to get cluster IPs from Terraform outputs - check network configuration")

	deployerIP, getdeployerIPErr := GetDeployerIPs(t, options, logger)
	require.NoError(t, getdeployerIPErr, "Failed to get deployer IP from Terraform outputs - check deployer configuration")

	jobCommandLow, jobCommandMed, _ := GenerateLSFJobCommandsForMemoryTypes()

	logger.Info(t, t.Name()+" Validation started ......")

	VerifyTestTerraformOutputs(t, bastionIP, deployerIP, false, false, false, logger)

	sshClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPs[0])
	if connectionErr != nil {
		msg := fmt.Sprintf("Failed to establish SSH connection to master node via bastion (%s) -> private IP (%s): %v", bastionIP, managementNodeIPs[0], connectionErr)
		logger.FAIL(t, msg)
		require.FailNow(t, msg)
	}

	defer func() {
		if err := sshClient.Close(); err != nil {
			logger.Info(t, fmt.Sprintf("failed to close sshClient: %v", err))
		}
	}()

	logger.Info(t, "SSH connection to the master successful")
	t.Log("Validation in progress. Please wait...")

	VerifyManagementNodeConfig(t, sshClient, expected.MasterName, expected.Hyperthreading, managementNodeIPs, expected.LsfVersion, logger)

	defer func() {
		if err := WaitForDynamicNodeDisappearance(t, sshClient, logger); err != nil {
			logger.Error(t, fmt.Sprintf("error in WaitForDynamicNodeDisappearance: %v", err))
			t.Errorf("error in WaitForDynamicNodeDisappearance: %v", err)
		}
	}()

	VerifyJobs(t, sshClient, jobCommandLow, logger)

	computeNodeIPList, err := GetComputeNodeIPs(t, sshClient, staticWorkerNodeIPs, logger)
	if err != nil {
		t.Fatalf("Failed to retrieve dynamic compute node IPs: %v", err)
	}

	VerifyComputeNodeConfig(t, sshClient, expected.Hyperthreading, computeNodeIPList, logger)

	runClusterValidationsOnLoginNode(t, bastionIP, loginNodeIP, expected, managementNodeIPs, staticWorkerNodeIPs, jobCommandMed, logger)

	VerifyFileShareEncryption(t, sshClient, os.Getenv("TF_VAR_ibmcloud_api_key"), utils.GetRegion(expected.Zones), expected.ResourceGroup, expected.MasterName, expected.KeyManagement, managementNodeIPs, logger)

	logger.Info(t, t.Name()+" Validation ended")
}

// ValidateBasicClusterConfigurationWithAppcenter validates a deployed cluster with IBM Spectrum LSF Application Center.
// It verifies management node configuration, Application Center accessibility, compute node status, job execution,
// login node functionality, and file share encryption through SSH connections to cluster nodes.
// Additionally, it ensures proper connectivity and functionality.
// This function doesn't return any value but logs errors and validation steps during the process.
func ValidateBasicClusterConfigurationWithAppcenter(t *testing.T, options *testhelper.TestOptions, logger *utils.AggregatedLogger) {

	expected := GetExpectedClusterConfig(t, options)

	bastionIP, managementNodeIPs, loginNodeIP, staticWorkerNodeIPs, getClusterIPErr := GetClusterIPs(t, options, logger)
	require.NoError(t, getClusterIPErr, "Failed to get cluster IPs from Terraform outputs - check network configuration")

	deployerIP, getdeployerIPErr := GetDeployerIPs(t, options, logger)
	require.NoError(t, getdeployerIPErr, "Failed to get deployer IP from Terraform outputs - check deployer configuration")

	jobCommandLow, jobCommandMed, _ := GenerateLSFJobCommandsForMemoryTypes()

	logger.Info(t, t.Name()+" Validation started ......")

	VerifyTestTerraformOutputs(t, bastionIP, deployerIP, false, false, false, logger)

	sshClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPs[0])
	if connectionErr != nil {
		msg := fmt.Sprintf("Failed to establish SSH connection to master node via bastion (%s) -> private IP (%s): %v", bastionIP, managementNodeIPs[0], connectionErr)
		logger.FAIL(t, msg)
		require.FailNow(t, msg)
	}

	defer func() {
		if err := sshClient.Close(); err != nil {
			logger.Info(t, fmt.Sprintf("failed to close sshClient: %v", err))
		}
	}()

	logger.Info(t, "SSH connection to the master successful")
	t.Log("Validation in progress. Please wait...")

	VerifyManagementNodeConfig(t, sshClient, expected.MasterName, expected.Hyperthreading, managementNodeIPs, expected.LsfVersion, logger)

	VerifyAPPCenterConfig(t, sshClient, bastionIP, LSF_PUBLIC_HOST_NAME, LSF_PRIVATE_HOST_NAME, managementNodeIPs, logger)

	VerifyLSFClusterRESTConfig(t, sshClient, bastionIP, LSF_PUBLIC_HOST_NAME, LSF_PRIVATE_HOST_NAME, managementNodeIPs, expected.MasterName, expected.LsfVersion, expected.AcPassword, logger)

	defer func() {
		if err := WaitForDynamicNodeDisappearance(t, sshClient, logger); err != nil {
			logger.Error(t, fmt.Sprintf("error in WaitForDynamicNodeDisappearance: %v", err))
			t.Errorf("error in WaitForDynamicNodeDisappearance: %v", err)
		}
	}()

	VerifyJobs(t, sshClient, jobCommandMed, logger)

	computeNodeIPList, err := GetComputeNodeIPs(t, sshClient, staticWorkerNodeIPs, logger)
	if err != nil {
		t.Fatalf("Failed to retrieve dynamic compute node IPs: %v", err)
	}

	VerifyComputeNodeConfig(t, sshClient, expected.Hyperthreading, computeNodeIPList, logger)

	runClusterValidationsOnLoginNode(t, bastionIP, loginNodeIP, expected, managementNodeIPs, staticWorkerNodeIPs, jobCommandLow, logger)

	VerifyFileShareEncryption(t, sshClient, os.Getenv("TF_VAR_ibmcloud_api_key"), utils.GetRegion(expected.Zones), expected.ResourceGroup, expected.MasterName, expected.KeyManagement, managementNodeIPs, logger)

	logger.Info(t, t.Name()+" Validation ended")
}

// ValidateBasicClusterConfigurationWithDynamicProfile validates basic cluster configuration.
// It performs validation tasks on essential aspects of the cluster setup,
// including the management node, compute nodes, and login node configurations.
// Additionally, it ensures proper connectivity and functionality.
// The dynamic worker node profile should be created based on the first worker instance type object.
// This function doesn't return any value but logs errors and validation steps during the process.
func ValidateBasicClusterConfigurationWithDynamicProfile(t *testing.T, options *testhelper.TestOptions, logger *utils.AggregatedLogger) {

	expected := GetExpectedClusterConfig(t, options)

	bastionIP, managementNodeIPs, loginNodeIP, staticWorkerNodeIPs, getClusterIPErr := GetClusterIPs(t, options, logger)
	require.NoError(t, getClusterIPErr, "Failed to get cluster IPs from Terraform outputs - check network configuration")

	jobCommandLow, jobCommandMed, _ := GenerateLSFJobCommandsForMemoryTypes()

	logger.Info(t, t.Name()+" Validation started ......")

	sshClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPs[0])
	if connectionErr != nil {
		msg := fmt.Sprintf("Failed to establish SSH connection to master node via bastion (%s) -> private IP (%s): %v", bastionIP, managementNodeIPs[0], connectionErr)
		logger.FAIL(t, msg)
		require.FailNow(t, msg)
	}

	defer func() {
		if err := sshClient.Close(); err != nil {
			logger.Info(t, fmt.Sprintf("failed to close sshClient: %v", err))
		}
	}()

	logger.Info(t, "SSH connection to the master successful")
	t.Log("Validation in progress. Please wait...")

	VerifyManagementNodeConfig(t, sshClient, expected.MasterName, expected.Hyperthreading, managementNodeIPs, expected.LsfVersion, logger)

	defer func() {
		if err := WaitForDynamicNodeDisappearance(t, sshClient, logger); err != nil {
			logger.Error(t, fmt.Sprintf("error in WaitForDynamicNodeDisappearance: %v", err))
			t.Errorf("error in WaitForDynamicNodeDisappearance: %v", err)
		}
	}()

	VerifyJobs(t, sshClient, jobCommandMed, logger)

	ValidateDynamicNodeProfile(t, os.Getenv("TF_VAR_ibmcloud_api_key"), utils.GetRegion(expected.Zones), expected.ResourceGroup, expected.MasterName, options, logger)

	computeNodeIPList, err := GetComputeNodeIPs(t, sshClient, staticWorkerNodeIPs, logger)
	if err != nil {
		t.Fatalf("Failed to retrieve dynamic compute node IPs: %v", err)
	}

	VerifyComputeNodeConfig(t, sshClient, expected.Hyperthreading, computeNodeIPList, logger)

	runClusterValidationsOnLoginNode(t, bastionIP, loginNodeIP, expected, managementNodeIPs, staticWorkerNodeIPs, jobCommandLow, logger)

	logger.Info(t, t.Name()+" Validation ended")
}

// ValidateLDAPClusterConfiguration performs comprehensive validation on the cluster setup.
// It connects to various cluster components via SSH and verifies their configurations and functionality.
// This includes validations for management nodes, compute nodes, login nodes, dynamic compute nodes, and LDAP integration.
// Additionally, this function logs detailed information throughout the validation process.
// This function doesn't return any value but logs errors and validation steps during the process.
func ValidateLDAPClusterConfiguration(t *testing.T, options *testhelper.TestOptions, logger *utils.AggregatedLogger) {

	expected := GetExpectedClusterConfig(t, options)

	expectedLdapDomain, ldapAdminPassword, ldapUserName, ldapUserPassword, getLDAPCredentialsErr := GetValidatedLDAPCredentials(t, options, logger)
	require.NoError(t, getLDAPCredentialsErr, "error occurred while getting LDAP credentials")

	bastionIP, managementNodeIPs, loginNodeIP, staticWorkerNodeIPs, ldapServerIP, getClusterIPErr := GetClusterIPsWithLDAP(t, options, logger)
	require.NoError(t, getClusterIPErr, "Failed to get cluster IPs from Terraform outputs - check network configuration")

	deployerIP, getdeployerIPErr := GetDeployerIPs(t, options, logger)
	require.NoError(t, getdeployerIPErr, "error occurred while getting deployer IPs")

	jobCommandLow, jobCommandMed, _ := GenerateLSFJobCommandsForMemoryTypes()

	logger.Info(t, t.Name()+" Validation started ......")

	VerifyTestTerraformOutputs(t, bastionIP, deployerIP, false, false, true, logger)

	sshClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPs[0])
	if connectionErr != nil {
		msg := fmt.Sprintf("Failed to establish SSH connection to master node via bastion (%s) -> private IP (%s): %v", bastionIP, managementNodeIPs[0], connectionErr)
		logger.FAIL(t, msg)
		require.FailNow(t, msg)
	}

	defer func() {
		if err := sshClient.Close(); err != nil {
			logger.Info(t, fmt.Sprintf("failed to close sshClient: %v", err))
		}
	}()

	logger.Info(t, "SSH connection to the master successful")
	t.Log("Validation in progress. Please wait...")

	runClusterValidationsOnManagementNode(t, sshClient, bastionIP, managementNodeIPs, expected, jobCommandMed, logger)

	if err := sshClient.Close(); err != nil {
		logger.Info(t, fmt.Sprintf("failed to close pre-reboot sshClient: %v", err))
	}

	sshClient, connectionErr = utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPs[0])
	if connectionErr != nil {
		msg := fmt.Sprintf("SSH connection to master node via bastion (%s) -> private IP (%s) failed after reboot: %v", bastionIP, managementNodeIPs[0], connectionErr)
		logger.FAIL(t, msg)
		require.FailNow(t, msg)
	}

	defer func() {
		if err := WaitForDynamicNodeDisappearance(t, sshClient, logger); err != nil {
			logger.Error(t, fmt.Sprintf("error in WaitForDynamicNodeDisappearance: %v", err))
			t.Errorf("error in WaitForDynamicNodeDisappearance: %v", err)
		}
	}()

	runClusterValidationsOnComputeNode(t, sshClient, bastionIP, staticWorkerNodeIPs, expected, jobCommandLow, logger)

	runClusterValidationsOnLoginNode(t, bastionIP, loginNodeIP, expected, managementNodeIPs, staticWorkerNodeIPs, jobCommandLow, logger)

	VerifyLSFDNS(t, sshClient, []string{loginNodeIP}, expected.DnsDomainName, logger)

	VerifyFileShareEncryption(t, sshClient, os.Getenv("TF_VAR_ibmcloud_api_key"), utils.GetRegion(expected.Zones), expected.ResourceGroup, expected.MasterName, expected.KeyManagement, managementNodeIPs, logger)

	sshLdapClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_LDAP_HOST_NAME, ldapServerIP)
	require.NoError(t, connectionErr, "Failed to connect to the LDAP server via SSH")

	defer func() {
		if err := sshLdapClient.Close(); err != nil {
			logger.Info(t, fmt.Sprintf("failed to close sshLdapClient: %v", err))
		}
	}()

	VerifyJobs(t, sshClient, jobCommandLow, logger)

	computeNodeIPList, err := GetComputeNodeIPs(t, sshClient, staticWorkerNodeIPs, logger)
	if err != nil {
		t.Fatalf("Failed to retrieve dynamic compute node IPs: %v", err)
	}

	CheckLDAPServerStatus(t, sshLdapClient, ldapAdminPassword, expectedLdapDomain, ldapUserName, logger)

	VerifyManagementNodeLDAPConfig(t, sshClient, bastionIP, ldapServerIP, managementNodeIPs, jobCommandLow, expectedLdapDomain, ldapUserName, ldapUserPassword, logger)

	VerifyComputeNodeLDAPConfig(t, bastionIP, ldapServerIP, computeNodeIPList, expectedLdapDomain, ldapUserName, ldapUserPassword, logger)

	sshLoginNodeClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, loginNodeIP)
	require.NoError(t, connectionErr, "Failed to connect to the login node via SSH")

	defer func() {
		if err := sshLoginNodeClient.Close(); err != nil {
			logger.Info(t, fmt.Sprintf("failed to close sshLoginNodeClient: %v", err))
		}
	}()

	VerifyLoginNodeLDAPConfig(t, sshLoginNodeClient, bastionIP, loginNodeIP, ldapServerIP, jobCommandLow, expectedLdapDomain, ldapUserName, ldapUserPassword, logger)

	VerifyCreateNewLdapUserAndManagementNodeLDAPConfig(t, sshLdapClient, bastionIP, ldapServerIP, managementNodeIPs, jobCommandLow, ldapUserName, ldapAdminPassword, expectedLdapDomain, NEW_LDAP_USER_NAME, NEW_LDAP_USER_PASSWORD, logger)

	VerifyPTRRecordsForManagement(t, sshClient, LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPs, expected.DnsDomainName, logger)

	logger.Info(t, t.Name()+" Validation ended")
}

// ValidateLDAPClusterConfigurationWithAppcenter performs comprehensive validation on the cluster setup with LDAP and Application Center.
// It connects to various cluster components via SSH and verifies their configurations and functionality including management nodes,
// compute nodes, login nodes, dynamic compute nodes, LDAP integration, and Application Center accessibility.
// The function validates LDAP user authentication, AppCenter web interface, job submission capabilities, and file share encryption.
// This validation ensures the complete cluster functionality with both LDAP and Application Center components working together.
// This function doesn't return any value but logs errors and validation steps during the process.
func ValidateLDAPClusterConfigurationWithAppcenter(t *testing.T, options *testhelper.TestOptions, logger *utils.AggregatedLogger) {

	expected := GetExpectedClusterConfig(t, options)

	expectedLdapDomain, ldapAdminPassword, ldapUserName, ldapUserPassword, getLDAPCredentialsErr := GetValidatedLDAPCredentials(t, options, logger)
	require.NoError(t, getLDAPCredentialsErr, "error occurred while getting LDAP credentials")

	bastionIP, managementNodeIPs, loginNodeIP, staticWorkerNodeIPs, ldapServerIP, getClusterIPErr := GetClusterIPsWithLDAP(t, options, logger)
	require.NoError(t, getClusterIPErr, "Failed to get cluster IPs from Terraform outputs - check network configuration")

	deployerIP, getdeployerIPErr := GetDeployerIPs(t, options, logger)
	require.NoError(t, getdeployerIPErr, "error occurred while getting deployer IPs")

	jobCommandLow, jobCommandMed, _ := GenerateLSFJobCommandsForMemoryTypes()

	logger.Info(t, t.Name()+" Validation started ......")

	VerifyTestTerraformOutputs(t, bastionIP, deployerIP, false, false, true, logger)

	sshClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPs[0])
	if connectionErr != nil {
		msg := fmt.Sprintf("Failed to establish SSH connection to master node via bastion (%s) -> private IP (%s): %v", bastionIP, managementNodeIPs[0], connectionErr)
		logger.FAIL(t, msg)
		require.FailNow(t, msg)
	}

	defer func() {
		if err := sshClient.Close(); err != nil {
			logger.Info(t, fmt.Sprintf("failed to close sshClient: %v", err))
		}
	}()

	logger.Info(t, "SSH connection to the master successful")
	t.Log("Validation in progress. Please wait...")

	runClusterValidationsOnManagementNode(t, sshClient, bastionIP, managementNodeIPs, expected, jobCommandMed, logger)

	VerifyAPPCenterConfig(t, sshClient, bastionIP, LSF_PUBLIC_HOST_NAME, LSF_PRIVATE_HOST_NAME, managementNodeIPs, logger)

	if err := sshClient.Close(); err != nil {
		logger.Info(t, fmt.Sprintf("failed to close pre-reboot sshClient: %v", err))
	}

	sshClient, connectionErr = utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPs[0])
	if connectionErr != nil {
		msg := fmt.Sprintf("SSH connection to master node via bastion (%s) -> private IP (%s) failed after reboot: %v", bastionIP, managementNodeIPs[0], connectionErr)
		logger.FAIL(t, msg)
		require.FailNow(t, msg)
	}

	defer func() {
		if err := WaitForDynamicNodeDisappearance(t, sshClient, logger); err != nil {
			logger.Error(t, fmt.Sprintf("error in WaitForDynamicNodeDisappearance: %v", err))
			t.Errorf("error in WaitForDynamicNodeDisappearance: %v", err)
		}
	}()

	runClusterValidationsOnComputeNode(t, sshClient, bastionIP, staticWorkerNodeIPs, expected, jobCommandLow, logger)

	runClusterValidationsOnLoginNode(t, bastionIP, loginNodeIP, expected, managementNodeIPs, staticWorkerNodeIPs, jobCommandLow, logger)

	VerifyLSFDNS(t, sshClient, []string{loginNodeIP}, expected.DnsDomainName, logger)

	VerifyFileShareEncryption(t, sshClient, os.Getenv("TF_VAR_ibmcloud_api_key"), utils.GetRegion(expected.Zones), expected.ResourceGroup, expected.MasterName, expected.KeyManagement, managementNodeIPs, logger)

	sshLdapClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_LDAP_HOST_NAME, ldapServerIP)
	require.NoError(t, connectionErr, "Failed to connect to the LDAP server via SSH")

	defer func() {
		if err := sshLdapClient.Close(); err != nil {
			logger.Info(t, fmt.Sprintf("failed to close sshLdapClient: %v", err))
		}
	}()

	VerifyJobs(t, sshClient, jobCommandLow, logger)

	computeNodeIPList, err := GetComputeNodeIPs(t, sshClient, staticWorkerNodeIPs, logger)
	if err != nil {
		t.Fatalf("Failed to retrieve dynamic compute node IPs: %v", err)
	}

	CheckLDAPServerStatus(t, sshLdapClient, ldapAdminPassword, expectedLdapDomain, ldapUserName, logger)

	VerifyManagementNodeLDAPConfig(t, sshClient, bastionIP, ldapServerIP, managementNodeIPs, jobCommandLow, expectedLdapDomain, ldapUserName, ldapUserPassword, logger)

	VerifyComputeNodeLDAPConfig(t, bastionIP, ldapServerIP, computeNodeIPList, expectedLdapDomain, ldapUserName, ldapUserPassword, logger)

	sshLoginNodeClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, loginNodeIP)
	require.NoError(t, connectionErr, "Failed to connect to the login node via SSH")

	defer func() {
		if err := sshLoginNodeClient.Close(); err != nil {
			logger.Info(t, fmt.Sprintf("failed to close sshLoginNodeClient: %v", err))
		}
	}()

	VerifyLoginNodeLDAPConfig(t, sshLoginNodeClient, bastionIP, loginNodeIP, ldapServerIP, jobCommandLow, expectedLdapDomain, ldapUserName, ldapUserPassword, logger)

	VerifyCreateNewLdapUserAndManagementNodeLDAPConfig(t, sshLdapClient, bastionIP, ldapServerIP, managementNodeIPs, jobCommandLow, ldapUserName, ldapAdminPassword, expectedLdapDomain, NEW_LDAP_USER_NAME, NEW_LDAP_USER_PASSWORD, logger)

	VerifyPTRRecordsForManagement(t, sshClient, LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPs, expected.DnsDomainName, logger)

	logger.Info(t, t.Name()+" Validation ended")
}

// ValidatePACANDLDAPClusterConfiguration performs comprehensive validation on the PAC and LDAP cluster setup.
// It connects to various cluster components via SSH and verifies their configurations and functionality.
// This includes validations for management nodes, compute nodes, login nodes, dynamic compute nodes, LDAP server, application center, and noVNC.
// Additionally, this function logs detailed information throughout the validation process.
// This function doesn't return any value but logs errors and validation steps during the process.
func ValidatePACANDLDAPClusterConfiguration(t *testing.T, options *testhelper.TestOptions, logger *utils.AggregatedLogger) {

	expected := GetExpectedClusterConfig(t, options)

	expectedLdapDomain, ldapAdminPassword, ldapUserName, ldapUserPassword, getLDAPCredentialsErr := GetValidatedLDAPCredentials(t, options, logger)
	require.NoError(t, getLDAPCredentialsErr, "error occurred while getting LDAP credentials")

	bastionIP, managementNodeIPs, loginNodeIP, staticWorkerNodeIPs, ldapServerIP, getClusterIPErr := GetClusterIPsWithLDAP(t, options, logger)
	require.NoError(t, getClusterIPErr, "Failed to get cluster IPs from Terraform outputs - check network configuration")

	deployerIP, getdeployerIPErr := GetDeployerIPs(t, options, logger)
	require.NoError(t, getdeployerIPErr, "Failed to get deployer IP from Terraform outputs - check deployer configuration")

	jobCommandLow, jobCommandMed, _ := GenerateLSFJobCommandsForMemoryTypes()

	logger.Info(t, t.Name()+" Validation started ......")

	VerifyTestTerraformOutputs(t, bastionIP, deployerIP, false, false, true, logger)

	sshClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPs[0])
	if connectionErr != nil {
		msg := fmt.Sprintf("Failed to establish SSH connection to master node via bastion (%s) -> private IP (%s): %v", bastionIP, managementNodeIPs[0], connectionErr)
		logger.FAIL(t, msg)
		require.FailNow(t, msg)
	}

	defer func() {
		if err := sshClient.Close(); err != nil {
			logger.Info(t, fmt.Sprintf("failed to close sshClient: %v", err))
		}
	}()

	logger.Info(t, "SSH connection to the master successful")
	t.Log("Validation in progress. Please wait...")

	runClusterValidationsOnManagementNode(t, sshClient, bastionIP, managementNodeIPs, expected, jobCommandMed, logger)

	if err := sshClient.Close(); err != nil {
		logger.Info(t, fmt.Sprintf("failed to close pre-reboot sshClient: %v", err))
	}

	sshClient, connectionErr = utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPs[0])
	if connectionErr != nil {
		msg := fmt.Sprintf("SSH connection to master node via bastion (%s) -> private IP (%s) failed after reboot: %v", bastionIP, managementNodeIPs[0], connectionErr)
		logger.FAIL(t, msg)
		require.FailNow(t, msg)
	}

	defer func() {
		if err := WaitForDynamicNodeDisappearance(t, sshClient, logger); err != nil {
			logger.Error(t, fmt.Sprintf("error in WaitForDynamicNodeDisappearance: %v", err))
			t.Errorf("error in WaitForDynamicNodeDisappearance: %v", err)
		}
	}()

	runClusterValidationsOnComputeNode(t, sshClient, bastionIP, staticWorkerNodeIPs, expected, jobCommandLow, logger)

	runClusterValidationsOnLoginNode(t, bastionIP, loginNodeIP, expected, managementNodeIPs, staticWorkerNodeIPs, jobCommandLow, logger)

	VerifyFileShareEncryption(t, sshClient, os.Getenv("TF_VAR_ibmcloud_api_key"), utils.GetRegion(expected.Zones), expected.ResourceGroup, expected.MasterName, expected.KeyManagement, managementNodeIPs, logger)

	sshLdapClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_LDAP_HOST_NAME, ldapServerIP)
	require.NoError(t, connectionErr, "Failed to connect to the LDAP server via SSH")

	defer func() {
		if err := sshLdapClient.Close(); err != nil {
			logger.Info(t, fmt.Sprintf("failed to close sshLdapClient: %v", err))
		}
	}()

	computeNodeIPList, err := GetComputeNodeIPs(t, sshClient, staticWorkerNodeIPs, logger)
	if err != nil {
		t.Fatalf("Failed to retrieve dynamic compute node IPs: %v", err)
	}

	CheckLDAPServerStatus(t, sshLdapClient, ldapAdminPassword, expectedLdapDomain, ldapUserName, logger)

	VerifyManagementNodeLDAPConfig(t, sshClient, bastionIP, ldapServerIP, managementNodeIPs, jobCommandLow, expectedLdapDomain, ldapUserName, ldapUserPassword, logger)

	VerifyComputeNodeLDAPConfig(t, bastionIP, ldapServerIP, computeNodeIPList, expectedLdapDomain, ldapUserName, ldapUserPassword, logger)

	sshLoginNodeClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, loginNodeIP)
	require.NoError(t, connectionErr, "Failed to connect to the login node via SSH")

	defer func() {
		if err := sshLoginNodeClient.Close(); err != nil {
			logger.Info(t, fmt.Sprintf("failed to close sshLoginNodeClient: %v", err))
		}
	}()

	VerifyLoginNodeLDAPConfig(t, sshLoginNodeClient, bastionIP, loginNodeIP, ldapServerIP, jobCommandLow, expectedLdapDomain, ldapUserName, ldapUserPassword, logger)

	VerifyCreateNewLdapUserAndManagementNodeLDAPConfig(t, sshLdapClient, bastionIP, ldapServerIP, managementNodeIPs, jobCommandLow, ldapUserName, ldapAdminPassword, expectedLdapDomain, NEW_LDAP_USER_NAME, NEW_LDAP_USER_PASSWORD, logger)

	VerifyPTRRecordsForManagement(t, sshClient, LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPs, expected.DnsDomainName, logger)

	logger.Info(t, t.Name()+" Validation ended")
}

// ValidateExistingLDAPClusterConfig performs comprehensive validation on an existing LDAP cluster configuration.
// It connects to various cluster components via SSH to verify their configurations and functionality,
// including management nodes, compute nodes, login nodes, dynamic compute nodes, and LDAP integration.
// This function logs detailed information throughout the validation process and does not return any value.
func ValidateExistingLDAPClusterConfig(t *testing.T, ldapServerBastionIP, ldapServerIP, expectedLdapDomain, ldapAdminPassword, ldapUserName, ldapUserPassword string, options *testhelper.TestOptions, logger *utils.AggregatedLogger) {

	expected := GetExpectedClusterConfig(t, options)

	bastionIP, managementNodeIPs, loginNodeIP, staticWorkerNodeIPs, getClusterIPErr := GetClusterIPs(t, options, logger)
	require.NoError(t, getClusterIPErr, "Failed to get cluster IPs from Terraform outputs - check network configuration")

	jobCommandLow, jobCommandMed, _ := GenerateLSFJobCommandsForMemoryTypes()

	logger.Info(t, t.Name()+" Validation started ......")

	sshClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPs[0])
	if connectionErr != nil {
		msg := fmt.Sprintf("Failed to establish SSH connection to master node  via bastion (%s) -> private IP (%s): %v", bastionIP, managementNodeIPs[0], connectionErr)
		logger.FAIL(t, msg)
		require.FailNow(t, msg)
	}

	defer func() {
		if err := sshClient.Close(); err != nil {
			logger.Info(t, fmt.Sprintf("failed to close sshClient: %v", err))
		}
	}()

	logger.Info(t, "SSH connection to the master successful")
	t.Log("Validation in progress. Please wait...")

	runClusterValidationsOnManagementNode(t, sshClient, bastionIP, managementNodeIPs, expected, jobCommandMed, logger)

	if err := sshClient.Close(); err != nil {
		logger.Info(t, fmt.Sprintf("failed to close pre-reboot sshClient: %v", err))
	}

	sshClient, connectionErr = utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPs[0])
	if connectionErr != nil {
		msg := fmt.Sprintf("SSH connection to master node via bastion (%s) -> private IP (%s) failed after reboot: %v", bastionIP, managementNodeIPs[0], connectionErr)
		logger.FAIL(t, msg)
		require.FailNow(t, msg)
	}

	defer func() {
		if err := WaitForDynamicNodeDisappearance(t, sshClient, logger); err != nil {
			logger.Error(t, fmt.Sprintf("error in WaitForDynamicNodeDisappearance: %v", err))
			t.Errorf("error in WaitForDynamicNodeDisappearance: %v", err)
		}
	}()

	runClusterValidationsOnComputeNode(t, sshClient, bastionIP, staticWorkerNodeIPs, expected, jobCommandLow, logger)

	runClusterValidationsOnLoginNode(t, bastionIP, loginNodeIP, expected, managementNodeIPs, staticWorkerNodeIPs, jobCommandLow, logger)

	VerifyPTRRecordsForManagement(t, sshClient, LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPs, expected.DnsDomainName, logger)

	VerifyFileShareEncryption(t, sshClient, os.Getenv("TF_VAR_ibmcloud_api_key"), utils.GetRegion(expected.Zones), expected.ResourceGroup, expected.MasterName, expected.KeyManagement, managementNodeIPs, logger)

	sshLdapClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, ldapServerBastionIP, LSF_LDAP_HOST_NAME, ldapServerIP)
	require.NoError(t, connectionErr, "Failed to connect to the LDAP server via SSH")

	defer func() {
		if err := sshLdapClient.Close(); err != nil {
			logger.Info(t, fmt.Sprintf("failed to close sshLdapClient: %v", err))
		}
	}()

	CheckLDAPServerStatus(t, sshLdapClient, ldapAdminPassword, expectedLdapDomain, ldapUserName, logger)

	VerifyManagementNodeLDAPConfig(t, sshClient, bastionIP, ldapServerIP, managementNodeIPs, jobCommandLow, expectedLdapDomain, ldapUserName, ldapUserPassword, logger)

	VerifyComputeNodeLDAPConfig(t, bastionIP, ldapServerIP, managementNodeIPs, expectedLdapDomain, ldapUserName, ldapUserPassword, logger)

	sshLoginNodeClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, loginNodeIP)
	require.NoError(t, connectionErr, "Failed to connect to the login node via SSH")

	defer func() {
		if err := sshLoginNodeClient.Close(); err != nil {
			logger.Info(t, fmt.Sprintf("failed to close sshLoginNodeClient: %v", err))
		}
	}()

	VerifyLoginNodeLDAPConfig(t, sshLoginNodeClient, bastionIP, loginNodeIP, ldapServerIP, jobCommandLow, expectedLdapDomain, ldapUserName, ldapUserPassword, logger)

	VerifyCreateNewLdapUserAndManagementNodeLDAPConfig(t, sshLdapClient, bastionIP, ldapServerIP, managementNodeIPs, jobCommandLow, ldapUserName, ldapAdminPassword, expectedLdapDomain, NEW_LDAP_USER_NAME, NEW_LDAP_USER_PASSWORD, logger)

	logger.Info(t, t.Name()+" Validation ended")
}

// ValidateBasicClusterConfigurationWithVPCFlowLogsAndCos validates the basic cluster configuration
// including VPC flow logs and COS service instance.
// It performs validation tasks on essential aspects of the cluster setup,
// such as management node, compute nodes, and login node configurations.
// Additionally, it ensures proper connectivity and functionality.
// This function doesn't return any value but logs errors and validation steps during the process.
func ValidateBasicClusterConfigurationWithVPCFlowLogsAndCos(t *testing.T, options *testhelper.TestOptions, logger *utils.AggregatedLogger) {

	expected := GetExpectedClusterConfig(t, options)

	bastionIP, managementNodeIPs, loginNodeIP, staticWorkerNodeIPs, getClusterIPErr := GetClusterIPs(t, options, logger)
	require.NoError(t, getClusterIPErr, "Failed to get cluster IPs from Terraform outputs - check network configuration")

	jobCommandLow, jobCommandMed, _ := GenerateLSFJobCommandsForMemoryTypes()

	logger.Info(t, t.Name()+" Validation started ......")

	sshClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPs[0])
	if connectionErr != nil {
		msg := fmt.Sprintf("Failed to establish SSH connection to master node via bastion (%s) -> private IP (%s): %v", bastionIP, managementNodeIPs[0], connectionErr)
		logger.FAIL(t, msg)
		require.FailNow(t, msg)
	}

	defer func() {
		if err := sshClient.Close(); err != nil {
			logger.Info(t, fmt.Sprintf("failed to close sshClient: %v", err))
		}
	}()

	logger.Info(t, "SSH connection to the master successful")
	t.Log("Validation in progress. Please wait...")

	VerifyManagementNodeConfig(t, sshClient, expected.MasterName, expected.Hyperthreading, managementNodeIPs, expected.LsfVersion, logger)

	if err := sshClient.Close(); err != nil {
		logger.Info(t, fmt.Sprintf("failed to close pre-reboot sshClient: %v", err))
	}

	sshClient, connectionErr = utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPs[0])
	if connectionErr != nil {
		msg := fmt.Sprintf("SSH connection to master node via bastion (%s) -> private IP (%s) failed after reboot: %v", bastionIP, managementNodeIPs[0], connectionErr)
		logger.FAIL(t, msg)
		require.FailNow(t, msg)
	}

	defer func() {
		if err := WaitForDynamicNodeDisappearance(t, sshClient, logger); err != nil {
			logger.Error(t, fmt.Sprintf("error in WaitForDynamicNodeDisappearance: %v", err))
			t.Errorf("error in WaitForDynamicNodeDisappearance: %v", err)
		}
	}()

	runClusterValidationsOnComputeNode(t, sshClient, bastionIP, staticWorkerNodeIPs, expected, jobCommandLow, logger)

	runClusterValidationsOnLoginNode(t, bastionIP, loginNodeIP, expected, managementNodeIPs, staticWorkerNodeIPs, jobCommandMed, logger)

	//VerifyLSFDNS(t, sshClient, []string{loginNodeIP}, expected.DnsDomainName, logger)

	VerifyFileShareEncryption(t, sshClient, os.Getenv("TF_VAR_ibmcloud_api_key"), utils.GetRegion(expected.Zones), expected.ResourceGroup, expected.MasterName, expected.KeyManagement, managementNodeIPs, logger)

	ValidateCosServiceInstanceAndVpcFlowLogs(t, os.Getenv("TF_VAR_ibmcloud_api_key"), utils.GetRegion(expected.Zones), expected.ResourceGroup, expected.MasterName, logger)

	logger.Info(t, t.Name()+" Validation ended")
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
func ValidateBasicClusterConfigurationLSFLogs(t *testing.T, options *testhelper.TestOptions, logger *utils.AggregatedLogger) {

	expected := GetExpectedClusterConfig(t, options)

	jobCommandLow, jobCommandMed, _ := GenerateLSFJobCommandsForMemoryTypes()

	bastionIP, managementNodeIPs, loginNodeIP, staticWorkerNodeIPs, getClusterIPErr := GetClusterIPs(t, options, logger)
	require.NoError(t, getClusterIPErr, "Failed to get cluster IPs from Terraform outputs - check network configuration")

	logger.Info(t, t.Name()+" Validation started ......")

	sshClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPs[0])
	if connectionErr != nil {
		msg := fmt.Sprintf("Failed to establish SSH connection to master node via bastion (%s) -> private IP (%s): %v", bastionIP, managementNodeIPs[0], connectionErr)
		logger.FAIL(t, msg)
		require.FailNow(t, msg)
	}

	defer func() {
		if err := sshClient.Close(); err != nil {
			logger.Info(t, fmt.Sprintf("failed to close sshClient: %v", err))
		}
	}()

	logger.Info(t, "SSH connection to the master successful")
	t.Log("Validation in progress. Please wait...")

	runClusterValidationsOnManagementNode(t, sshClient, bastionIP, managementNodeIPs, expected, jobCommandMed, logger)

	if err := sshClient.Close(); err != nil {
		logger.Info(t, fmt.Sprintf("failed to close pre-reboot sshClient: %v", err))
	}

	ValidateLSFLogs(t, bastionIP, managementNodeIPs, os.Getenv("TF_VAR_ibmcloud_api_key"), utils.GetRegion(expected.Zones), expected.ResourceGroup, logger)

	sshClient, connectionErr = utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPs[0])
	require.NoError(t, connectionErr, "Failed to re-establish SSH connection after reboot - check node recovery")

	defer func() {
		if err := WaitForDynamicNodeDisappearance(t, sshClient, logger); err != nil {
			logger.Error(t, fmt.Sprintf("error in WaitForDynamicNodeDisappearance: %v", err))
			t.Errorf("error in WaitForDynamicNodeDisappearance: %v", err)
		}
	}()

	runClusterValidationsOnComputeNode(t, sshClient, bastionIP, staticWorkerNodeIPs, expected, jobCommandLow, logger)

	runClusterValidationsOnLoginNode(t, bastionIP, loginNodeIP, expected, managementNodeIPs, staticWorkerNodeIPs, jobCommandLow, logger)

	logger.Info(t, t.Name()+" Validation ended")
}

// ValidateBasicClusterConfigurationWithDedicatedHost validates the basic configuration of a cluster
// with a dedicated host setup. It ensures that the management node, compute nodes, login node, and
// connectivity between all components are configured correctly. The function performs various
// validation tasks including checking cluster details, node configurations, IP retrieval,
// and job execution. This function logs all validation steps and errors during the process.
func ValidateBasicClusterConfigurationWithDedicatedHost(t *testing.T, options *testhelper.TestOptions, expectedDedicatedHostPresence bool, logger *utils.AggregatedLogger) {

	expected := GetExpectedClusterConfig(t, options)
	WorkerNodeMinCount, err := utils.GetTotalStaticComputeCount(t, options.TerraformVars, logger)
	require.NoError(t, err, "error retrieving worker node total count")

	jobCommandLow, jobCommandMed, _ := GenerateLSFJobCommandsForMemoryTypes()

	bastionIP, managementNodeIPs, loginNodeIP, staticWorkerNodeIPs, getClusterIPErr := GetClusterIPs(t, options, logger)
	require.NoError(t, getClusterIPErr, "Failed to get cluster IPs from Terraform outputs - check network configuration")

	logger.Info(t, t.Name()+" Validation started ......")

	sshClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPs[0])
	if connectionErr != nil {
		msg := fmt.Sprintf("Failed to establish SSH connection to master node via bastion (%s) -> private IP (%s): %v", bastionIP, managementNodeIPs[0], connectionErr)
		logger.FAIL(t, msg)
		require.FailNow(t, msg)
	}

	defer func() {
		if err := sshClient.Close(); err != nil {
			logger.Info(t, fmt.Sprintf("failed to close sshClient: %v", err))
		}
	}()

	logger.Info(t, "SSH connection to the master successful")
	t.Log("Validation in progress. Please wait...")

	VerifyManagementNodeConfig(t, sshClient, expected.MasterName, expected.Hyperthreading, managementNodeIPs, expected.LsfVersion, logger)

	ValidateDedicatedHost(t, os.Getenv("TF_VAR_ibmcloud_api_key"), utils.GetRegion(expected.Zones), expected.ResourceGroup, expected.MasterName, WorkerNodeMinCount, expectedDedicatedHostPresence, logger)

	if err := sshClient.Close(); err != nil {
		logger.Info(t, fmt.Sprintf("failed to close pre-reboot sshClient: %v", err))
	}

	sshClient, connectionErr = utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPs[0])
	if connectionErr != nil {
		msg := fmt.Sprintf("SSH connection to master node via bastion (%s) -> private IP (%s) failed after reboot: %v", bastionIP, managementNodeIPs[0], connectionErr)
		logger.FAIL(t, msg)
		require.FailNow(t, msg)
	}

	defer func() {
		if err := WaitForDynamicNodeDisappearance(t, sshClient, logger); err != nil {
			logger.Error(t, fmt.Sprintf("error in WaitForDynamicNodeDisappearance: %v", err))
			t.Errorf("error in WaitForDynamicNodeDisappearance: %v", err)
		}
	}()

	runClusterValidationsOnComputeNode(t, sshClient, bastionIP, staticWorkerNodeIPs, expected, jobCommandMed, logger)

	runClusterValidationsOnLoginNode(t, bastionIP, loginNodeIP, expected, managementNodeIPs, staticWorkerNodeIPs, jobCommandLow, logger)

	VerifyPTRRecordsForManagement(t, sshClient, LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPs, expected.DnsDomainName, logger)

	VerifyLSFDNS(t, sshClient, []string{loginNodeIP}, expected.DnsDomainName, logger)

	VerifyFileShareEncryption(t, sshClient, os.Getenv("TF_VAR_ibmcloud_api_key"), utils.GetRegion(expected.Zones), expected.ResourceGroup, expected.MasterName, expected.KeyManagement, managementNodeIPs, logger)

	logger.Info(t, t.Name()+" Validation ended")
}

// ValidateClusterConfigurationWithSCCWPAndCSPM validates the cluster configuration
// with SCCWP and CSPM enabled.
// It performs validation on critical components such as the management node,
// compute nodes, and login node to ensure proper setup and connectivity.
// All validation steps and errors are logged throughout the process.
func ValidateBasicClusterConfigurationWithSCCWPAndCSPM(t *testing.T, options *testhelper.TestOptions, logger *utils.AggregatedLogger) {

	expected := GetExpectedClusterConfig(t, options)

	bastionIP, managementNodeIPs, loginNodeIP, staticWorkerNodeIPs, getClusterIPErr := GetClusterIPs(t, options, logger)
	require.NoError(t, getClusterIPErr, "Failed to get cluster IPs from Terraform outputs - check network configuration")

	jobCommandLow, jobCommandMed, _ := GenerateLSFJobCommandsForMemoryTypes()

	logger.Info(t, t.Name()+" Validation started ......")

	sshClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPs[0])
	if connectionErr != nil {
		msg := fmt.Sprintf("Failed to establish SSH connection to master node via bastion (%s) -> private IP (%s): %v", bastionIP, managementNodeIPs[0], connectionErr)
		logger.FAIL(t, msg)
		require.FailNow(t, msg)
	}

	defer func() {
		if err := sshClient.Close(); err != nil {
			logger.Info(t, fmt.Sprintf("failed to close sshClient: %v", err))
		}
	}()

	logger.Info(t, "SSH connection to the master successful")
	t.Log("Validation in progress. Please wait...")

	VerifyManagementNodeConfig(t, sshClient, expected.MasterName, expected.Hyperthreading, managementNodeIPs, expected.LsfVersion, logger)

	//ValidateSCCInstance(t, os.Getenv("TF_VAR_ibmcloud_api_key"), utils.GetRegion(expected.Zones), expected.ResourceGroup, expected.MasterName, SCC_INSTANCE_REGION, logger)

	defer func() {
		if err := WaitForDynamicNodeDisappearance(t, sshClient, logger); err != nil {
			logger.Error(t, fmt.Sprintf("error in WaitForDynamicNodeDisappearance: %v", err))
			t.Errorf("error in WaitForDynamicNodeDisappearance: %v", err)
		}
	}()

	VerifyJobs(t, sshClient, jobCommandLow, logger)

	computeNodeIPList, err := GetComputeNodeIPs(t, sshClient, staticWorkerNodeIPs, logger)
	if err != nil {
		t.Fatalf("Failed to retrieve dynamic compute node IPs: %v", err)
	}

	VerifyComputeNodeConfig(t, sshClient, expected.Hyperthreading, computeNodeIPList, logger)

	runClusterValidationsOnLoginNode(t, bastionIP, loginNodeIP, expected, managementNodeIPs, staticWorkerNodeIPs, jobCommandMed, logger)

	VerifyFileShareEncryption(t, sshClient, os.Getenv("TF_VAR_ibmcloud_api_key"), utils.GetRegion(expected.Zones), expected.ResourceGroup, expected.MasterName, expected.KeyManagement, managementNodeIPs, logger)

	logger.Info(t, t.Name()+" Validation ended")
}

// ValidateBasicClusterConfigurationWithCloudLogs validates essential cluster configurations and logs errors.
// This function ensures that the management, compute, and login nodes meet the required configurations.
// It establishes SSH connections to nodes, validates DNS, encryption, and logs observability settings.
// Errors are handled explicitly, and validation steps are logged for debugging.
// Key validation and configuration checks ensure that the cluster setup adheres to standards.
func ValidateBasicClusterConfigurationWithCloudLogs(t *testing.T, options *testhelper.TestOptions, logger *utils.AggregatedLogger) {

	expected := GetExpectedClusterConfig(t, options)

	expectedLogsEnabledForManagement, err := strconv.ParseBool(fmt.Sprintf("%v", options.TerraformVars["observability_logs_enable_for_management"]))
	require.NoError(t, err, "Failed to parse observability_logs_enable_for_management from Terraform vars - check variable type and value")

	expectedLogsEnabledForCompute, err := strconv.ParseBool(fmt.Sprintf("%v", options.TerraformVars["observability_logs_enable_for_compute"]))
	require.NoError(t, err, "Failed to parse observability_logs_enable_for_compute from Terraform vars - check variable type and value")

	bastionIP, managementNodeIPs, loginNodeIP, staticWorkerNodeIPs, getClusterIPErr := GetClusterIPs(t, options, logger)
	require.NoError(t, getClusterIPErr, "Failed to get cluster IPs from Terraform outputs - check network configuration")

	deployerIP, getdeployerIPErr := GetDeployerIPs(t, options, logger)
	require.NoError(t, getdeployerIPErr, "Failed to get deployer IP from Terraform outputs - check deployer configuration")

	jobCommandLow, jobCommandMed, _ := GenerateLSFJobCommandsForMemoryTypes()

	logger.Info(t, t.Name()+" Validation started ......")

	VerifyTestTerraformOutputs(t, bastionIP, deployerIP, expectedLogsEnabledForManagement, false, false, logger)

	sshClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPs[0])
	if connectionErr != nil {
		msg := fmt.Sprintf("Failed to establish SSH connection to master node via bastion (%s) -> private IP (%s): %v", bastionIP, managementNodeIPs[0], connectionErr)
		logger.FAIL(t, msg)
		require.FailNow(t, msg)
	}

	defer func() {
		if err := sshClient.Close(); err != nil {
			logger.Info(t, fmt.Sprintf("failed to close sshClient: %v", err))
		}
	}()

	logger.Info(t, "SSH connection to the master successful")
	t.Log("Validation in progress. Please wait...")

	runClusterValidationsOnManagementNode(t, sshClient, bastionIP, managementNodeIPs, expected, jobCommandMed, logger)

	if err := sshClient.Close(); err != nil {
		logger.Info(t, fmt.Sprintf("failed to close pre-reboot sshClient: %v", err))
	}

	sshClient, connectionErr = utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPs[0])
	if connectionErr != nil {
		msg := fmt.Sprintf("SSH connection to master node via bastion (%s) -> private IP (%s) failed after reboot: %v", bastionIP, managementNodeIPs[0], connectionErr)
		logger.FAIL(t, msg)
		require.FailNow(t, msg)
	}

	defer func() {
		if err := WaitForDynamicNodeDisappearance(t, sshClient, logger); err != nil {
			logger.Error(t, fmt.Sprintf("error in WaitForDynamicNodeDisappearance: %v", err))
			t.Errorf("error in WaitForDynamicNodeDisappearance: %v", err)
		}
	}()

	runClusterValidationsOnComputeNode(t, sshClient, bastionIP, staticWorkerNodeIPs, expected, jobCommandLow, logger)

	VerifyCloudLogs(t, sshClient, options.LastTestTerraformOutputs, managementNodeIPs, staticWorkerNodeIPs, expectedLogsEnabledForManagement, expectedLogsEnabledForCompute, logger)

	runClusterValidationsOnLoginNode(t, bastionIP, loginNodeIP, expected, managementNodeIPs, staticWorkerNodeIPs, jobCommandLow, logger)

	VerifyFileShareEncryption(t, sshClient, os.Getenv("TF_VAR_ibmcloud_api_key"), utils.GetRegion(expected.Zones), expected.ResourceGroup, expected.MasterName, expected.KeyManagement, managementNodeIPs, logger)

	logger.Info(t, t.Name()+" Validation ended")
}

// ValidateBasicClusterConfigurationWithCloudMonitoring validates essential cluster configurations and logs errors.
// This function ensures that the management, compute, and login nodes meet the required configurations.
// It establishes SSH connections to nodes, validates DNS, encryption, and logs observability settings.
// Errors are handled explicitly, and validation steps are logged for debugging.
// Key validation and configuration checks ensure that the cluster setup adheres to standards.
func ValidateBasicClusterConfigurationWithCloudMonitoring(t *testing.T, options *testhelper.TestOptions, logger *utils.AggregatedLogger) {

	expected := GetExpectedClusterConfig(t, options)

	expectedMonitoringEnabledForManagement, err := strconv.ParseBool(fmt.Sprintf("%v", options.TerraformVars["observability_monitoring_enable"]))
	require.NoError(t, err, "Failed to parse observability_monitoring_enable from Terraform vars - check variable type and value")

	expectedMonitoringEnabledForCompute, err := strconv.ParseBool(fmt.Sprintf("%v", options.TerraformVars["observability_monitoring_on_compute_nodes_enable"]))
	require.NoError(t, err, "Failed to parse observability_monitoring_on_compute_nodes_enable from Terraform vars - check variable type and value")

	bastionIP, managementNodeIPs, loginNodeIP, staticWorkerNodeIPs, getClusterIPErr := GetClusterIPs(t, options, logger)
	require.NoError(t, getClusterIPErr, "Failed to get cluster IPs from Terraform outputs - check network configuration")

	deployerIP, getdeployerIPErr := GetDeployerIPs(t, options, logger)
	require.NoError(t, getdeployerIPErr, "Failed to get deployer IP from Terraform outputs - check deployer configuration")

	jobCommandLow, jobCommandMed, _ := GenerateLSFJobCommandsForMemoryTypes()

	logger.Info(t, t.Name()+" Validation started ......")

	VerifyTestTerraformOutputs(t, bastionIP, deployerIP, false, expectedMonitoringEnabledForManagement, false, logger)

	sshClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPs[0])
	if connectionErr != nil {
		msg := fmt.Sprintf("Failed to establish SSH connection to master node via bastion (%s) -> private IP (%s): %v", bastionIP, managementNodeIPs[0], connectionErr)
		logger.FAIL(t, msg)
		require.FailNow(t, msg)
	}

	defer func() {
		if err := sshClient.Close(); err != nil {
			logger.Info(t, fmt.Sprintf("failed to close sshClient: %v", err))
		}
	}()

	logger.Info(t, "SSH connection to the master successful")
	t.Log("Validation in progress. Please wait...")

	runClusterValidationsOnManagementNode(t, sshClient, bastionIP, managementNodeIPs, expected, jobCommandMed, logger)

	if err := sshClient.Close(); err != nil {
		logger.Info(t, fmt.Sprintf("failed to close pre-reboot sshClient: %v", err))
	}

	sshClient, connectionErr = utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPs[0])
	if connectionErr != nil {
		msg := fmt.Sprintf("SSH connection to master node via bastion (%s) -> private IP (%s) failed after reboot: %v", bastionIP, managementNodeIPs[0], connectionErr)
		logger.FAIL(t, msg)
		require.FailNow(t, msg)
	}

	defer func() {
		if err := WaitForDynamicNodeDisappearance(t, sshClient, logger); err != nil {
			logger.Error(t, fmt.Sprintf("error in WaitForDynamicNodeDisappearance: %v", err))
			t.Errorf("error in WaitForDynamicNodeDisappearance: %v", err)
		}
	}()

	runClusterValidationsOnComputeNode(t, sshClient, bastionIP, staticWorkerNodeIPs, expected, jobCommandLow, logger)

	runClusterValidationsOnLoginNode(t, bastionIP, loginNodeIP, expected, managementNodeIPs, staticWorkerNodeIPs, jobCommandLow, logger)

	VerifyCloudMonitoring(t, sshClient, options.LastTestTerraformOutputs, managementNodeIPs, staticWorkerNodeIPs, expectedMonitoringEnabledForManagement, expectedMonitoringEnabledForCompute, logger)

	VerifyPTRRecordsForManagement(t, sshClient, LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPs, expected.DnsDomainName, logger)

	VerifyFileShareEncryption(t, sshClient, os.Getenv("TF_VAR_ibmcloud_api_key"), utils.GetRegion(expected.Zones), expected.ResourceGroup, expected.MasterName, expected.KeyManagement, managementNodeIPs, logger)

	logger.Info(t, t.Name()+" Validation ended")
}

// ValidateBasicClusterConfigurationWithCloudAtracker verifies that the cluster setup aligns with the expected configuration
// when Observability Atracker is enabled or disabled. It performs validations across management, compute, and login nodes,
// ensuring compliance with DNS, encryption, logging, and Atracker settings.
// The function establishes SSH connections to validate node configurations, runs job verification tests,
// checks PTR records, and ensures file share encryption. If any configuration discrepancies are found,
// appropriate test errors are raised.
func ValidateBasicClusterConfigurationWithCloudAtracker(t *testing.T, options *testhelper.TestOptions, logger *utils.AggregatedLogger) {

	expected := GetExpectedClusterConfig(t, options)

	expectedTargetType := options.TerraformVars["observability_atracker_target_type"].(string)

	expectedObservabilityAtrackerEnable, err := strconv.ParseBool(fmt.Sprintf("%v", options.TerraformVars["observability_atracker_enable"]))
	require.NoError(t, err, "Failed to parse observability_atracker_enable from Terraform vars - check variable type and value")

	bastionIP, managementNodeIPs, loginNodeIP, staticWorkerNodeIPs, getClusterIPErr := GetClusterIPs(t, options, logger)
	require.NoError(t, getClusterIPErr, "Failed to get cluster IPs from Terraform outputs - check network configuration")

	jobCommandLow, jobCommandMed, _ := GenerateLSFJobCommandsForMemoryTypes()

	logger.Info(t, t.Name()+" Validation started ......")

	sshClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPs[0])
	if connectionErr != nil {
		msg := fmt.Sprintf("Failed to establish SSH connection to master node (%s) via bastion (%s) -> private IP (%s): %v",
			LSF_PUBLIC_HOST_NAME, bastionIP, managementNodeIPs[0], connectionErr)
		logger.FAIL(t, msg)
		require.FailNow(t, msg)
	}

	defer func() {
		if err := sshClient.Close(); err != nil {
			logger.Info(t, fmt.Sprintf("failed to close sshClient: %v", err))
		}
	}()

	logger.Info(t, "SSH connection to the master successful")
	t.Log("Validation in progress. Please wait...")

	runClusterValidationsOnManagementNode(t, sshClient, bastionIP, managementNodeIPs, expected, jobCommandMed, logger)

	if err := sshClient.Close(); err != nil {
		logger.Info(t, fmt.Sprintf("failed to close pre-reboot sshClient: %v", err))
	}

	sshClient, connectionErr = utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPs[0])
	if connectionErr != nil {
		msg := fmt.Sprintf("SSH connection to master node via bastion (%s) -> private IP (%s) failed after reboot: %v", bastionIP, managementNodeIPs[0], connectionErr)
		logger.FAIL(t, msg)
		require.FailNow(t, msg)
	}

	defer func() {
		if err := WaitForDynamicNodeDisappearance(t, sshClient, logger); err != nil {
			logger.Error(t, fmt.Sprintf("error in WaitForDynamicNodeDisappearance: %v", err))
			t.Errorf("error in WaitForDynamicNodeDisappearance: %v", err)
		}
	}()

	runClusterValidationsOnComputeNode(t, sshClient, bastionIP, staticWorkerNodeIPs, expected, jobCommandLow, logger)

	ibmCloudAPIKey := os.Getenv("TF_VAR_ibmcloud_api_key")
	ValidateAtracker(t, ibmCloudAPIKey, utils.GetRegion(expected.Zones), expected.ResourceGroup, expected.MasterName, expectedTargetType, expectedObservabilityAtrackerEnable, logger)

	runClusterValidationsOnLoginNode(t, bastionIP, loginNodeIP, expected, managementNodeIPs, staticWorkerNodeIPs, jobCommandLow, logger)

	VerifyPTRRecordsForManagement(t, sshClient, LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPs, expected.DnsDomainName, logger)

	VerifyFileShareEncryption(t, sshClient, ibmCloudAPIKey, utils.GetRegion(expected.Zones), expected.ResourceGroup, expected.MasterName, expected.KeyManagement, managementNodeIPs, logger)

	logger.Info(t, t.Name()+" Validation ended")
}

// ValidateBasicObservabilityClusterConfiguration verifies observability features in an HPC LSF cluster.
// It checks log/monitoring enablement, Atracker config, DNS, PTR records, and encryption settings.
// The function connects to management and compute nodes via SSH for validations.
// It ensures dynamic worker nodes disappear as expected after reboot.
func ValidateBasicObservabilityClusterConfiguration(t *testing.T, options *testhelper.TestOptions, logger *utils.AggregatedLogger) {
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

	bastionIP, managementNodeIPs, loginNodeIP, staticWorkerNodeIPs, getClusterIPErr := GetClusterIPs(t, options, logger)
	require.NoError(t, getClusterIPErr, "Failed to get cluster IPs from Terraform outputs - check network configuration")

	deployerIP, getdeployerIPErr := GetDeployerIPs(t, options, logger)
	require.NoError(t, getdeployerIPErr, "Failed to get deployer IP from Terraform outputs - check deployer configuration")

	jobCommandLow, jobCommandMed, _ := GenerateLSFJobCommandsForMemoryTypes()

	logger.Info(t, t.Name()+" validation started")

	VerifyTestTerraformOutputs(t, bastionIP, deployerIP, expectedLogsEnabledForManagement, expectedMonitoringEnabledForManagement, false, logger)

	sshClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPs[0])
	if connectionErr != nil {
		msg := fmt.Sprintf("Failed to establish SSH connection to master node via bastion (%s) -> private IP (%s): %v", bastionIP, managementNodeIPs[0], connectionErr)
		logger.FAIL(t, msg)
		require.FailNow(t, msg)
	}

	defer func() {
		if err := sshClient.Close(); err != nil {
			logger.Info(t, fmt.Sprintf("Failed to close SSH client: %v", err))
		}
	}()

	logger.Info(t, "SSH connection to the master successful")
	t.Log("Validation in progress. Please wait...")

	runClusterValidationsOnManagementNode(t, sshClient, bastionIP, managementNodeIPs, expected, jobCommandMed, logger)

	if err := sshClient.Close(); err != nil {
		logger.Info(t, fmt.Sprintf("failed to close pre-reboot sshClient: %v", err))
	}

	sshClient, connectionErr = utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPs[0])
	require.NoError(t, connectionErr, "Failed to re-establish SSH connection after reboot - check node recovery")

	defer func() {
		if err := WaitForDynamicNodeDisappearance(t, sshClient, logger); err != nil {
			logger.Error(t, fmt.Sprintf("error in WaitForDynamicNodeDisappearance: %v", err))
			t.Errorf("error in WaitForDynamicNodeDisappearance: %v", err)
		}
	}()

	runClusterValidationsOnComputeNode(t, sshClient, bastionIP, staticWorkerNodeIPs, expected, jobCommandLow, logger)

	VerifyCloudLogs(t, sshClient, options.LastTestTerraformOutputs, managementNodeIPs, staticWorkerNodeIPs, expectedLogsEnabledForManagement, expectedLogsEnabledForCompute, logger)

	VerifyCloudMonitoring(t, sshClient, options.LastTestTerraformOutputs, managementNodeIPs, staticWorkerNodeIPs, expectedMonitoringEnabledForManagement, expectedMonitoringEnabledForCompute, logger)

	ibmCloudAPIKey := os.Getenv("TF_VAR_ibmcloud_api_key")
	ValidateAtracker(t, ibmCloudAPIKey, utils.GetRegion(expected.Zones), expected.ResourceGroup, expected.MasterName, expectedTargetType, expectedObservabilityAtrackerEnable, logger)

	VerifyPlatformLogs(t, ibmCloudAPIKey, utils.GetRegion(expected.Zones), expected.ResourceGroup, expectedEnabledPlatFormLogs, logger)

	runClusterValidationsOnLoginNode(t, bastionIP, loginNodeIP, expected, managementNodeIPs, staticWorkerNodeIPs, jobCommandLow, logger)

	VerifyPTRRecordsForManagement(t, sshClient, LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPs, expected.DnsDomainName, logger)

	VerifyLSFDNS(t, sshClient, []string{loginNodeIP}, expected.DnsDomainName, logger)

	VerifyFileShareEncryption(t, sshClient, ibmCloudAPIKey, utils.GetRegion(expected.Zones), expected.ResourceGroup, expected.MasterName, expected.KeyManagement, managementNodeIPs, logger)

	logger.Info(t, t.Name()+" validation ended")
}

// ValidateClusterConfigurationWithMultipleKeys performs a comprehensive validation on the cluster setup.
// It connects to various cluster components via SSH and verifies their configurations and functionality,
// including management nodes, compute nodes, login nodes, and dynamic compute nodes. It also performs
// additional validation checks like failover procedures, SSH key verification, and DNS verification.
// The function logs detailed information throughout the validation process but does not return any value.
func ValidateClusterConfigurationWithMultipleKeys(t *testing.T, options *testhelper.TestOptions, logger *utils.AggregatedLogger) {

	expected := GetExpectedClusterConfig(t, options)

	bastionIP, managementNodeIPs, loginNodeIP, staticWorkerNodeIPs, getClusterIPErr := GetClusterIPs(t, options, logger)
	require.NoError(t, getClusterIPErr, "Failed to get cluster IPs from Terraform outputs - check network configuration")

	jobCommandLow, _, _ := GenerateLSFJobCommandsForMemoryTypes()

	logger.Info(t, t.Name()+" Validation started ......")

	sshClientOne, sshClientTwo, connectionErrOne, connectionErrTwo := utils.ConnectToHostsWithMultipleUsers(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPs[0])
	require.NoError(t, connectionErrOne, "Failed to connect to the master via SSH")
	require.NoError(t, connectionErrTwo, "Failed to connect to the master via SSH")

	defer func() {
		if err := sshClientTwo.Close(); err != nil {
			logger.Info(t, fmt.Sprintf("failed to close sshClientTwo: %v", err))
		}
	}()

	logger.Info(t, "SSH connection to the master successful")
	t.Log("Validation in progress. Please wait...")

	VerifyManagementNodeConfig(t, sshClientOne, expected.MasterName, expected.Hyperthreading, managementNodeIPs, expected.LsfVersion, logger)
	VerifyManagementNodeConfig(t, sshClientTwo, expected.MasterName, expected.Hyperthreading, managementNodeIPs, expected.LsfVersion, logger)

	VerifySSHKey(t, sshClientOne, bastionIP, LSF_PUBLIC_HOST_NAME, LSF_PRIVATE_HOST_NAME, "management", managementNodeIPs, expected.NumOfKeys, logger)

	//FailoverAndFailback(t, sshClientOne, jobCommandMed, logger)

	RestartLsfDaemon(t, sshClientOne, logger)

	RebootInstance(t, sshClientOne, bastionIP, LSF_PUBLIC_HOST_NAME, LSF_PRIVATE_HOST_NAME, managementNodeIPs[0], logger)

	if err := sshClientOne.Close(); err != nil {
		logger.Info(t, fmt.Sprintf("failed to close pre-reboot sshClientOne: %v", err))
	}

	sshClientOne, connectionErrOne = utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPs[0])
	require.NoError(t, connectionErrOne, "Failed to reconnect to the master via SSH")

	defer func() {
		if err := sshClientOne.Close(); err != nil {
			logger.Info(t, fmt.Sprintf("failed to close sshClientOne: %v", err))
		}
	}()

	defer func() {
		if err := WaitForDynamicNodeDisappearance(t, sshClientOne, logger); err != nil {
			logger.Error(t, fmt.Sprintf("error in WaitForDynamicNodeDisappearance: %v", err))
			t.Errorf("error in WaitForDynamicNodeDisappearance: %v", err)
		}
	}()

	VerifyJobs(t, sshClientOne, jobCommandLow, logger)

	computeNodeIPList, err := GetComputeNodeIPs(t, sshClientOne, staticWorkerNodeIPs, logger)
	if err != nil {
		t.Fatalf("Failed to retrieve dynamic compute node IPs: %v", err)
	}

	VerifyComputeNodeConfig(t, sshClientOne, expected.Hyperthreading, computeNodeIPList, logger)

	VerifySSHKey(t, sshClientOne, bastionIP, LSF_PUBLIC_HOST_NAME, LSF_PRIVATE_HOST_NAME, "compute", computeNodeIPList, expected.NumOfKeys, logger)

	VerifyLSFDNS(t, sshClientOne, computeNodeIPList, expected.DnsDomainName, logger)

	runClusterValidationsOnLoginNode(t, bastionIP, loginNodeIP, expected, managementNodeIPs, staticWorkerNodeIPs, jobCommandLow, logger)

	VerifyLSFDNS(t, sshClientOne, []string{loginNodeIP}, expected.DnsDomainName, logger)

	VerifyFileShareEncryption(t, sshClientOne, os.Getenv("TF_VAR_ibmcloud_api_key"), utils.GetRegion(expected.Zones), expected.ResourceGroup, expected.MasterName, expected.KeyManagement, managementNodeIPs, logger)

	logger.Info(t, t.Name()+" Validation ended")
}

// ValidateBasicClusterConfigurationForMultiProfileStaticAndDynamic validates key components of an LSF cluster
// with static and dynamic compute node profiles. It checks SSH connectivity, management and compute node setups,
// job execution, and file share encryption. Validation results are logged, and critical issues fail the test.
func ValidateBasicClusterConfigurationForMultiProfileStaticAndDynamic(t *testing.T, options *testhelper.TestOptions, logger *utils.AggregatedLogger) {
	expected := GetExpectedClusterConfig(t, options)

	bastionIP, managementNodeIPs, loginNodeIP, staticWorkerNodeIPs, getClusterIPErr := GetClusterIPs(t, options, logger)
	require.NoError(t, getClusterIPErr, "Failed to get cluster IPs from Terraform outputs - check network configuration")

	deployerIP, getdeployerIPErr := GetDeployerIPs(t, options, logger)
	require.NoError(t, getdeployerIPErr, "Failed to get deployer IP from Terraform outputs - check deployer configuration")

	jobCommandLow, _, jobCommandHigh := GenerateLSFJobCommandsForMemoryTypes()

	logger.Info(t, t.Name()+" Validation started ......")

	VerifyTestTerraformOutputs(t, bastionIP, deployerIP, false, false, false, logger)

	sshClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPs[0])
	if connectionErr != nil {
		msg := fmt.Sprintf("Failed to establish SSH connection to master node via bastion (%s) -> private IP (%s): %v", bastionIP, managementNodeIPs[0], connectionErr)
		logger.FAIL(t, msg)
		require.FailNow(t, msg)
	}

	defer func() {
		if err := sshClient.Close(); err != nil {
			logger.Info(t, fmt.Sprintf("Failed to close sshClient: %v", err))
		}
	}()

	logger.Info(t, "SSH connection to the master successful")
	t.Log("Validation in progress. Please wait...")

	VerifyManagementNodeConfig(t, sshClient, expected.MasterName, expected.Hyperthreading, managementNodeIPs, expected.LsfVersion, logger)

	defer func() {
		if err := WaitForDynamicNodeDisappearance(t, sshClient, logger); err != nil {
			logger.Error(t, fmt.Sprintf("error in WaitForDynamicNodeDisappearance: %v", err))
			t.Errorf("error in WaitForDynamicNodeDisappearance: %v", err)
		}
	}()

	VerifyJobs(t, sshClient, jobCommandHigh, logger)

	ValidateDynamicNodeProfile(t, os.Getenv("TF_VAR_ibmcloud_api_key"), utils.GetRegion(expected.Zones), expected.ResourceGroup, expected.MasterName, options, logger)

	computeNodeIPList, err := GetComputeNodeIPs(t, sshClient, staticWorkerNodeIPs, logger)
	if err != nil {
		t.Fatalf("Failed to retrieve compute node IPs: %v", err)
	}

	VerifyComputeNodeConfig(t, sshClient, expected.Hyperthreading, computeNodeIPList, logger)

	runClusterValidationsOnLoginNode(t, bastionIP, loginNodeIP, expected, managementNodeIPs, staticWorkerNodeIPs, jobCommandLow, logger)

	VerifyPTRRecordsForManagement(t, sshClient, LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPs, expected.DnsDomainName, logger)

	VerifyFileShareEncryption(t, sshClient, os.Getenv("TF_VAR_ibmcloud_api_key"), utils.GetRegion(expected.Zones), expected.ResourceGroup, expected.MasterName, expected.KeyManagement, managementNodeIPs, logger)

	logger.Info(t, t.Name()+" validation ended")
}

// ValidateClusterAPIConfiguration performs comprehensive validation on the cluster setup.
// It connects to various cluster components via SSH and verifies their configurations and functionality.
// This includes the following validations:
// - Management Node: Verifies the configuration of the management node, including failover and failback procedures.
// - Compute Nodes: Ensures proper configuration and SSH connectivity to compute nodes.
// - Login Node: Validates the configuration and SSH connectivity to the login node.
// - Application Center: Validates the configuration of the application center.
// Additionally, this function logs detailed information throughout the validation process.
// This function doesn't return any value but logs errors and validation steps during the process.
func ValidateClusterAPIConfiguration(t *testing.T, options *testhelper.TestOptions, logger *utils.AggregatedLogger) {
	expected := GetExpectedClusterConfig(t, options)

	jobCommandLow, jobCommandMed, _ := GenerateLSFJobCommandsForMemoryTypes()

	bastionIP, managementNodeIPs, loginNodeIP, staticWorkerNodeIPs, getClusterIPErr := GetClusterIPs(t, options, logger)
	require.NoError(t, getClusterIPErr, "Failed to get cluster IPs from Terraform outputs - check network configuration")

	logger.Info(t, t.Name()+" Validation started ......")

	sshClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPs[0])
	if connectionErr != nil {
		msg := fmt.Sprintf("Failed to establish SSH connection to master node via bastion (%s) -> private IP (%s): %v", bastionIP, managementNodeIPs[0], connectionErr)
		logger.FAIL(t, msg)
		require.FailNow(t, msg)
	}

	defer func() {
		if err := sshClient.Close(); err != nil {
			logger.Info(t, fmt.Sprintf("failed to close sshClient: %v", err))
		}
	}()

	logger.Info(t, "SSH connection to the master successful")
	t.Log("Validation in progress. Please wait...")

	VerifyManagementNodeConfig(t, sshClient, expected.MasterName, expected.Hyperthreading, managementNodeIPs, expected.LsfVersion, logger)

	if err := sshClient.Close(); err != nil {
		logger.Info(t, fmt.Sprintf("failed to close pre-reboot sshClient: %v", err))
	}

	sshClient, connectionErr = utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPs[0])
	if connectionErr != nil {
		msg := fmt.Sprintf("SSH connection to master node via bastion (%s) -> private IP (%s) failed after reboot: %v", bastionIP, managementNodeIPs[0], connectionErr)
		logger.FAIL(t, msg)
		require.FailNow(t, msg)
	}

	defer func() {
		if err := WaitForDynamicNodeDisappearance(t, sshClient, logger); err != nil {
			logger.Error(t, fmt.Sprintf("error in WaitForDynamicNodeDisappearance: %v", err))
			t.Errorf("error in WaitForDynamicNodeDisappearance: %v", err)
		}
	}()

	runClusterValidationsOnComputeNode(t, sshClient, bastionIP, staticWorkerNodeIPs, expected, jobCommandLow, logger)

	runClusterValidationsOnLoginNode(t, bastionIP, loginNodeIP, expected, managementNodeIPs, staticWorkerNodeIPs, jobCommandMed, logger)

	VerifyFileShareEncryption(t, sshClient, os.Getenv("TF_VAR_ibmcloud_api_key"), utils.GetRegion(expected.Zones), expected.ResourceGroup, expected.MasterName, expected.KeyManagement, managementNodeIPs, logger)

	logger.Info(t, t.Name()+" Validation ended")
}

// ValidateBasicClusterConfigurationHyperThreadingOn validates a cluster configured with hyper-threading enabled.
// It verifies the configuration and connectivity of the management, compute, and login nodes,
// executes LSF jobs to validate scheduling, and checks cluster components such as networking
// and file share encryption. Validation results are logged, and failures are reported via the testing framework.
func ValidateBasicClusterConfigurationHyperThreadingOn(t *testing.T, options *testhelper.TestOptions, logger *utils.AggregatedLogger) {

	expected := GetExpectedClusterConfig(t, options)

	bastionIP, managementNodeIPs, loginNodeIP, staticWorkerNodeIPs, getClusterIPErr := GetClusterIPs(t, options, logger)
	require.NoError(t, getClusterIPErr, "Failed to get cluster IPs from Terraform outputs - check network configuration")

	deployerIP, getdeployerIPErr := GetDeployerIPs(t, options, logger)
	require.NoError(t, getdeployerIPErr, "Failed to get deployer IP from Terraform outputs - check deployer configuration")

	jobCommandLow, jobCommandMed, _ := GenerateLSFJobCommandsForMemoryTypes()

	logger.Info(t, t.Name()+" Validation started ......")

	VerifyTestTerraformOutputs(t, bastionIP, deployerIP, false, false, false, logger)

	sshClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPs[0])
	if connectionErr != nil {
		msg := fmt.Sprintf("Failed to establish SSH connection to master node via bastion (%s) -> private IP (%s): %v", bastionIP, managementNodeIPs[0], connectionErr)
		logger.FAIL(t, msg)
		require.FailNow(t, msg)
	}

	defer func() {
		if err := sshClient.Close(); err != nil {
			logger.Info(t, fmt.Sprintf("failed to close sshClient: %v", err))
		}
	}()

	logger.Info(t, "SSH connection to the master successful")
	t.Log("Validation in progress. Please wait...")

	VerifyManagementNodeConfig(t, sshClient, expected.MasterName, expected.Hyperthreading, managementNodeIPs, expected.LsfVersion, logger)

	defer func() {
		if err := WaitForDynamicNodeDisappearance(t, sshClient, logger); err != nil {
			logger.Error(t, fmt.Sprintf("error in WaitForDynamicNodeDisappearance: %v", err))
			t.Errorf("error in WaitForDynamicNodeDisappearance: %v", err)
		}
	}()

	VerifyJobs(t, sshClient, jobCommandLow, logger)
	VerifyJobs(t, sshClient, jobCommandMed, logger)

	computeNodeIPList, err := GetComputeNodeIPs(t, sshClient, staticWorkerNodeIPs, logger)
	if err != nil {
		t.Fatalf("Failed to retrieve dynamic compute node IPs: %v", err)
	}

	VerifyComputeNodeConfig(t, sshClient, expected.Hyperthreading, computeNodeIPList, logger)

	runClusterValidationsOnLoginNode(t, bastionIP, loginNodeIP, expected, managementNodeIPs, staticWorkerNodeIPs, LSF_JOB_COMMAND_ULTRA_MEM, logger)

	VerifyFileShareEncryption(t, sshClient, os.Getenv("TF_VAR_ibmcloud_api_key"), utils.GetRegion(expected.Zones), expected.ResourceGroup, expected.MasterName, expected.KeyManagement, managementNodeIPs, logger)

	logger.Info(t, t.Name()+" Validation ended")
}

// ValidateBasicClusterConfigurationWithSpotInstance validates the overall
// cluster configuration, including management, compute, and login nodes.
// It verifies cluster connectivity, workload execution, and file share encryption.
// The function also validates dynamic compute instance VM type and spot instance
// configuration in the LSF resource connector templates and logs all results.
func ValidateBasicClusterConfigurationWithSpotInstance(t *testing.T, options *testhelper.TestOptions, logger *utils.AggregatedLogger) {

	expected := GetExpectedClusterConfig(t, options)

	bastionIP, managementNodeIPs, loginNodeIP, staticWorkerNodeIPs, getClusterIPErr := GetClusterIPs(t, options, logger)
	require.NoError(t, getClusterIPErr, "Failed to get cluster IPs from Terraform outputs - check network configuration")

	deployerIP, getdeployerIPErr := GetDeployerIPs(t, options, logger)
	require.NoError(t, getdeployerIPErr, "Failed to get deployer IP from Terraform outputs - check deployer configuration")

	jobCommandLow, jobCommandMed, _ := GenerateLSFJobCommandsForMemoryTypes()

	logger.Info(t, t.Name()+" Validation started ......")

	VerifyTestTerraformOutputs(t, bastionIP, deployerIP, false, false, false, logger)

	sshClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPs[0])
	if connectionErr != nil {
		msg := fmt.Sprintf("Failed to establish SSH connection to master node via bastion (%s) -> private IP (%s): %v", bastionIP, managementNodeIPs[0], connectionErr)
		logger.FAIL(t, msg)
		require.FailNow(t, msg)
	}

	defer func() {
		if err := sshClient.Close(); err != nil {
			logger.Info(t, fmt.Sprintf("failed to close sshClient: %v", err))
		}
	}()

	logger.Info(t, "SSH connection to the master successful")
	t.Log("Validation in progress. Please wait...")

	VerifyManagementNodeConfig(t, sshClient, expected.MasterName, expected.Hyperthreading, managementNodeIPs, expected.LsfVersion, logger)

	VerifySpotInstance(t, options, sshClient, logger)

	defer func() {
		if err := WaitForDynamicNodeDisappearance(t, sshClient, logger); err != nil {
			logger.Error(t, fmt.Sprintf("error in WaitForDynamicNodeDisappearance: %v", err))
			t.Errorf("error in WaitForDynamicNodeDisappearance: %v", err)
		}
	}()

	VerifyJobs(t, sshClient, jobCommandLow, logger)

	computeNodeIPList, err := GetComputeNodeIPs(t, sshClient, staticWorkerNodeIPs, logger)
	if err != nil {
		t.Fatalf("Failed to retrieve dynamic compute node IPs: %v", err)
	}

	VerifyComputeNodeConfig(t, sshClient, expected.Hyperthreading, computeNodeIPList, logger)

	runClusterValidationsOnLoginNode(t, bastionIP, loginNodeIP, expected, managementNodeIPs, staticWorkerNodeIPs, jobCommandMed, logger)

	VerifyFileShareEncryption(t, sshClient, os.Getenv("TF_VAR_ibmcloud_api_key"), utils.GetRegion(expected.Zones), expected.ResourceGroup, expected.MasterName, expected.KeyManagement, managementNodeIPs, logger)

	logger.Info(t, t.Name()+" Validation ended")
}
