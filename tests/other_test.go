package tests

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/stretchr/testify/require"

	"github.com/gruntwork-io/terratest/modules/terraform"

	"github.com/stretchr/testify/assert"
	utils "github.com/terraform-ibm-modules/terraform-ibm-hpc/common_utils"
	lsf "github.com/terraform-ibm-modules/terraform-ibm-hpc/lsf"
)

// Constants for better organization
const (
	createVpcTerraformDir = "examples/create_vpc/solutions/hpc" // Brand new VPC
)

// TestRunBasic validates the cluster configuration and creation of an HPC cluster.
func TestRunBasic(t *testing.T) {

	// Parallelize the test
	t.Parallel()

	// Setup test suite
	setupTestSuite(t)

	testLogger.Info(t, "Cluster creation process initiated for "+t.Name())

	// HPC cluster prefix
	hpcClusterPrefix := utils.GenerateRandomString()

	// Retrieve cluster information from environment variables
	envVars := GetEnvVars()

	// Create test options
	options, err := setupOptions(t, hpcClusterPrefix, terraformDir, envVars.DefaultResourceGroup, ignoreDestroys)
	require.NoError(t, err, "Error setting up test options: %v", err)

	options.SkipTestTearDown = true
	defer options.TestTearDown()

	lsf.ValidateClusterConfiguration(t, options, testLogger)

}

// TestRunCustomRGAsNull validates cluster creation with a null resource group value.
func TestRunCustomRGAsNull(t *testing.T) {
	// Parallelize the test
	t.Parallel()

	// Setup test suite
	setupTestSuite(t)

	testLogger.Info(t, "Cluster creation process initiated for "+t.Name())

	// HPC cluster prefix
	hpcClusterPrefix := utils.GenerateRandomString()

	// Create test options
	options, err := setupOptions(t, hpcClusterPrefix, terraformDir, LSF_CUSTOM_RESOURCE_GROUP_VALUE_AS_NULL, ignoreDestroys)
	require.NoError(t, err, "Error setting up test options: %v", err)

	options.SkipTestTearDown = true
	defer options.TestTearDown()

	lsf.ValidateBasicClusterConfiguration(t, options, testLogger)

}

// TestRunCustomRGAsNonDefault validates cluster creation with a non-default resource group value.
func TestRunCustomRGAsNonDefault(t *testing.T) {
	// Parallelize the test
	t.Parallel()

	// Setup test suite
	setupTestSuite(t)

	testLogger.Info(t, "Cluster creation process initiated for "+t.Name())

	// HPC cluster prefix
	hpcClusterPrefix := utils.GenerateRandomString()

	// Retrieve cluster information from environment variables
	envVars := GetEnvVars()

	// Create test options
	options, err := setupOptions(t, hpcClusterPrefix, terraformDir, envVars.NonDefaultResourceGroup, ignoreDestroys)
	require.NoError(t, err, "Error setting up test options: %v", err)

	options.SkipTestTearDown = true
	defer options.TestTearDown()

	lsf.ValidateBasicClusterConfiguration(t, options, testLogger)

}

// TestRunAppCenter validates cluster creation with the Application Center.
func TestRunAppCenter(t *testing.T) {
	// Parallelize the test
	t.Parallel()

	// Setup test suite
	setupTestSuite(t)

	// HPC cluster prefix
	hpcClusterPrefix := utils.GenerateRandomString()

	testLogger.Info(t, "Cluster creation process initiated for "+t.Name())

	// Retrieve cluster information from environment variables
	envVars := GetEnvVars()

	// Create test options
	options, err := setupOptions(t, hpcClusterPrefix, terraformDir, envVars.DefaultResourceGroup, ignoreDestroys)
	require.NoError(t, err, "Error setting up test options: %v", err)
	options.TerraformVars["enable_app_center"] = strings.ToLower(envVars.EnableAppCenter)
	options.TerraformVars["app_center_gui_pwd"] = envVars.AppCenterGuiPassword //pragma: allowlist secret

	options.SkipTestTearDown = true
	defer options.TestTearDown()

	lsf.ValidateClusterConfigurationWithAPPCenter(t, options, testLogger)

}

// TestRunNoKMSAndHTOff validates cluster creation with KMS set to null and hyperthreading disabled.
func TestRunNoKMSAndHTOff(t *testing.T) {
	// Parallelize the test
	t.Parallel()

	// Setup test suite
	setupTestSuite(t)

	testLogger.Info(t, "Cluster creation process initiated for "+t.Name())

	// HPC cluster prefix
	hpcClusterPrefix := utils.GenerateRandomString()

	// Retrieve cluster information from environment variables
	envVars := GetEnvVars()

	// Create test options
	options, err := setupOptions(t, hpcClusterPrefix, terraformDir, envVars.DefaultResourceGroup, ignoreDestroys)
	require.NoError(t, err, "Error setting up test options: %v", err)
	options.TerraformVars["enable_cos_integration"] = false
	options.TerraformVars["enable_vpc_flow_logs"] = false
	options.TerraformVars["key_management"] = "null"
	options.TerraformVars["hyperthreading_enabled"] = strings.ToLower("false")

	options.SkipTestTearDown = true
	defer options.TestTearDown()

	lsf.ValidateBasicClusterConfiguration(t, options, testLogger)
}

// TestRunInUsEastRegion validates cluster creation in the US East region.
func TestRunInUsEastRegion(t *testing.T) {
	// Parallelize the test to run concurrently with others
	t.Parallel()

	// Setup test suite
	setupTestSuite(t)

	testLogger.Info(t, "Cluster creation process initiated for "+t.Name())

	// HPC cluster prefix
	hpcClusterPrefix := utils.GenerateRandomString()

	// Retrieve cluster information from environment variables
	envVars := GetEnvVars()

	// Extract US East zone, cluster ID, and reservation ID
	usEastZone := utils.SplitAndTrim(envVars.USEastZone, ",")
	usEastClusterID := envVars.USEastClusterID
	usEastReservationID := envVars.USEastReservationID

	// Ensure Reservation , cluster ID and zone are provided
	if len(usEastClusterID) == 0 || len(usEastZone) == 0 || len(usEastReservationID) == 0 {
		require.FailNow(t, "Reservation ID ,cluster ID and zone must be provided.")
	}

	// Create test options, set up test environment
	options, err := setupOptions(t, hpcClusterPrefix, terraformDir, envVars.DefaultResourceGroup, ignoreDestroys)
	require.NoError(t, err, "Error setting up test options: %v", err)

	// Set Terraform variables
	options.TerraformVars["zones"] = usEastZone
	options.TerraformVars["reservation_id"] = usEastReservationID
	options.TerraformVars["cluster_id"] = usEastClusterID

	// Skip test teardown for further inspection
	options.SkipTestTearDown = true
	defer options.TestTearDown()

	lsf.ValidateBasicClusterConfiguration(t, options, testLogger)
}

// TestRunInEuDeRegion validates cluster creation in the Frankfurt region.
func TestRunInEuDeRegion(t *testing.T) {
	// Parallelize the test to run concurrently with others
	t.Parallel()

	// Setup test suite
	setupTestSuite(t)

	testLogger.Info(t, "Cluster creation process initiated for "+t.Name())

	// HPC cluster prefix
	hpcClusterPrefix := utils.GenerateRandomString()

	// Retrieve cluster information from environment variables
	envVars := GetEnvVars()

	// Extract EU DE zone, cluster ID, and reservation ID
	euDeZone := utils.SplitAndTrim(envVars.EUDEZone, ",")
	euDeClusterID := envVars.EUDEClusterID
	euDeReservationID := envVars.EUDEReservationID

	// Ensure Reservation ID ,cluster ID and zone are provided
	if len(euDeClusterID) == 0 || len(euDeZone) == 0 || len(euDeReservationID) == 0 {
		require.FailNow(t, "Reservation ID, cluster ID and zone must be provided.")
	}

	// Create test options, set up test environment
	options, err := setupOptions(t, hpcClusterPrefix, terraformDir, envVars.DefaultResourceGroup, ignoreDestroys)
	require.NoError(t, err, "Error setting up test options: %v", err)

	// Set Terraform variables
	options.TerraformVars["zones"] = euDeZone
	options.TerraformVars["reservation_id"] = euDeReservationID
	options.TerraformVars["cluster_id"] = euDeClusterID

	// Skip test teardown for further inspection
	options.SkipTestTearDown = true
	defer options.TestTearDown()

	lsf.ValidateBasicClusterConfiguration(t, options, testLogger)
}

// TestRunInUSSouthRegion validates cluster creation in the US South region.
func TestRunInUSSouthRegion(t *testing.T) {
	// Parallelize the test to run concurrently with others
	t.Parallel()

	// Setup test suite
	setupTestSuite(t)

	testLogger.Info(t, "Cluster creation process initiated for "+t.Name())

	// HPC cluster prefix
	hpcClusterPrefix := utils.GenerateRandomString()

	// Retrieve cluster information from environment variables
	envVars := GetEnvVars()

	// Extract US South zone, cluster ID, and reservation ID
	usSouthZone := utils.SplitAndTrim(envVars.USSouthZone, ",")
	usSouthClusterID := envVars.USSouthClusterID
	usSouthReservationID := envVars.USSouthReservationID

	// Ensure cluster ID ,Reservation ID and zone are provided
	if len(usSouthClusterID) == 0 || len(usSouthZone) == 0 || len(usSouthReservationID) == 0 {
		require.FailNow(t, "Reservation ID ,cluster ID and zone must be provided.")
	}

	// Create test options, set up test environment
	options, err := setupOptions(t, hpcClusterPrefix, terraformDir, envVars.DefaultResourceGroup, ignoreDestroys)
	require.NoError(t, err, "Error setting up test options: %v", err)

	// Set Terraform variables
	options.TerraformVars["zones"] = usSouthZone
	options.TerraformVars["reservation_id"] = usSouthReservationID
	options.TerraformVars["cluster_id"] = usSouthClusterID

	// Skip test teardown for further inspection
	options.SkipTestTearDown = true
	defer options.TestTearDown()

	lsf.ValidateBasicClusterConfiguration(t, options, testLogger)
}

// TestRunLDAP validates cluster creation with LDAP enabled.
func TestRunLDAP(t *testing.T) {
	// Parallelize the test to run concurrently with others
	t.Parallel()

	// Setup test suite
	setupTestSuite(t)

	testLogger.Info(t, "Cluster creation process initiated for "+t.Name())

	// HPC cluster prefix
	hpcClusterPrefix := utils.GenerateRandomString()

	// Retrieve cluster information from environment variables
	envVars := GetEnvVars()

	// Create test options, set up test environment
	options, err := setupOptions(t, hpcClusterPrefix, terraformDir, envVars.DefaultResourceGroup, ignoreDestroys)
	require.NoError(t, err, "Error setting up test options: %v", err)

	if strings.ToLower(envVars.EnableLdap) == "true" {
		// Check if the Reservation ID contains 'WES' and cluster ID is not empty
		if len(envVars.LdapAdminPassword) == 0 || len(envVars.LdapUserName) == 0 || len(envVars.LdapUserPassword) == 0 {
			require.FailNow(t, "LDAP credentials are missing. Make sure LDAP admin password, LDAP user name, and LDAP user password are provided.")
		}
	} else {
		require.FailNow(t, "LDAP is not enabled. Set the 'enable_ldap' environment variable to 'true' to enable LDAP.")
	}

	// Set Terraform variables
	options.TerraformVars["enable_ldap"] = strings.ToLower(envVars.EnableLdap)
	options.TerraformVars["ldap_basedns"] = envVars.LdapBaseDns
	options.TerraformVars["ldap_admin_password"] = envVars.LdapAdminPassword //pragma: allowlist secret
	options.TerraformVars["ldap_user_name"] = envVars.LdapUserName
	options.TerraformVars["ldap_user_password"] = envVars.LdapUserPassword //pragma: allowlist secret

	// Skip test teardown for further inspection
	options.SkipTestTearDown = true
	defer options.TestTearDown()

	lsf.ValidateLDAPClusterConfiguration(t, options, testLogger)
}

// TestRunUsingExistingKMS validates cluster creation using an existing KMS.
func TestRunUsingExistingKMS(t *testing.T) {
	// Parallelize the test to run concurrently with others
	t.Parallel()

	// Setup test suite
	setupTestSuite(t)

	testLogger.Info(t, "Cluster creation process initiated for "+t.Name())

	// Service instance name
	randomString := utils.GenerateRandomString()
	kmsInstanceName := "cicd-" + randomString

	// HPC cluster prefix
	hpcClusterPrefix := utils.GenerateRandomString()

	// Retrieve cluster information from environment variables
	envVars := GetEnvVars()

	// Create service instance and KMS key using IBMCloud CLI
	err := lsf.CreateServiceInstanceandKmsKey(t, os.Getenv("TF_VAR_ibmcloud_api_key"), utils.GetRegion(envVars.Zone), envVars.DefaultResourceGroup, kmsInstanceName, lsf.KMS_KEY_NAME, testLogger)
	require.NoError(t, err, "Service instance and KMS key creation failed")

	testLogger.Info(t, "Service instance and KMS key created successfully "+t.Name())

	// Create test options, set up test environment
	options, err := setupOptions(t, hpcClusterPrefix, terraformDir, envVars.DefaultResourceGroup, ignoreDestroys)
	require.NoError(t, err, "Error setting up test options: %v", err)

	// Set Terraform variables
	options.TerraformVars["key_management"] = "key_protect"
	options.TerraformVars["kms_instance_name"] = kmsInstanceName
	options.TerraformVars["kms_key_name"] = lsf.KMS_KEY_NAME

	// Skip test teardown for further inspection
	options.SkipTestTearDown = true

	// Ensure the service instance and KMS key are deleted after the test
	defer lsf.DeleteServiceInstanceAndAssociatedKeys(t, os.Getenv("TF_VAR_ibmcloud_api_key"), utils.GetRegion(envVars.Zone), envVars.DefaultResourceGroup, kmsInstanceName, testLogger)
	defer options.TestTearDown()

	lsf.ValidateBasicClusterConfiguration(t, options, testLogger)
}

// TestRunLDAPAndPac validates cluster creation with both Application Center (PAC) and LDAP enabled.
func TestRunLDAPAndPac(t *testing.T) {
	// Parallelize the test to run concurrently with others
	t.Parallel()

	// Setup test suite
	setupTestSuite(t)

	testLogger.Info(t, "Cluster creation process initiated for "+t.Name())

	// HPC cluster prefix
	hpcClusterPrefix := utils.GenerateRandomString()

	// Retrieve cluster information from environment variables
	envVars := GetEnvVars()

	// Create test options, set up test environment
	options, err := setupOptions(t, hpcClusterPrefix, terraformDir, envVars.DefaultResourceGroup, ignoreDestroys)
	require.NoError(t, err, "Error setting up test options: %v", err)

	if strings.ToLower(envVars.EnableLdap) == "true" {
		// Check if the Reservation ID contains 'WES' and cluster ID is not empty
		if len(envVars.LdapAdminPassword) == 0 || len(envVars.LdapUserName) == 0 || len(envVars.LdapUserPassword) == 0 {
			require.FailNow(t, "LDAP credentials are missing. Make sure LDAP admin password, LDAP user name, and LDAP user password are provided.")
		}
	} else {
		require.FailNow(t, "LDAP is not enabled. Set the 'enable_ldap' environment variable to 'true' to enable LDAP.")
	}

	// Set Terraform variables
	options.TerraformVars["enable_app_center"] = strings.ToLower(envVars.EnableAppCenter)
	options.TerraformVars["app_center_gui_pwd"] = envVars.AppCenterGuiPassword //pragma: allowlist secret
	options.TerraformVars["enable_ldap"] = strings.ToLower(envVars.EnableLdap)
	options.TerraformVars["ldap_basedns"] = envVars.LdapBaseDns
	options.TerraformVars["ldap_admin_password"] = envVars.LdapAdminPassword //pragma: allowlist secret
	options.TerraformVars["ldap_user_name"] = envVars.LdapUserName
	options.TerraformVars["ldap_user_password"] = envVars.LdapUserPassword //pragma: allowlist secret

	// Skip test teardown for further inspection
	options.SkipTestTearDown = true
	defer options.TestTearDown()

	lsf.ValidatePACANDLDAPClusterConfiguration(t, options, testLogger)
}

// TestRunCreateVpc as brand new
func TestRunCreateVpc(t *testing.T) {
	// Parallelize the test to run concurrently with others
	t.Parallel()

	// Setup test suite
	setupTestSuite(t)

	testLogger.Info(t, "Brand new VPC creation initiated for "+t.Name())

	// Define the HPC cluster prefix
	hpcClusterPrefix := utils.GenerateRandomString()

	// Retrieve cluster information from environment variables
	envVars := GetEnvVars()

	// Create test options, set up test environment
	options, err := setupOptionsVpc(t, hpcClusterPrefix, createVpcTerraformDir, envVars.DefaultResourceGroup)
	require.NoError(t, err, "Error setting up test options: %v", err)

	// Skip test teardown for further inspection
	options.SkipTestTearDown = true
	defer options.TestTearDown()

	// Run the test
	output, err := options.RunTest()
	require.NoError(t, err, "Error running consistency test: %v", err)
	require.NotNil(t, output, "Expected non-nil output, but got nil")

	outputs := (options.LastTestTerraformOutputs)
	vpcName := outputs["vpc_name"].(string)
	bastionsubnetId, computesubnetIds := utils.GetSubnetIds(outputs)

	RunHpcExistingVpcSubnetId(t, vpcName, bastionsubnetId, computesubnetIds)
	RunHpcExistingVpcCidr(t, vpcName)
}

// RunHpcExistingVpcCidr with Cidr blocks
func RunHpcExistingVpcCidr(t *testing.T, vpcName string) {
	// Setup test suite
	setupTestSuite(t)

	testLogger.Info(t, "Cluster creation process initiated for "+t.Name())

	// HPC cluster prefix
	hpcClusterPrefix := utils.GenerateRandomString()

	// Static values for CIDR other than default CIDR
	vpcClusterPrivateSubnetsCidrBlocks := "10.241.48.0/21"
	vpcClusterLoginPrivateSubnetsCidrBlocks := "10.241.60.0/22"

	// Retrieve cluster information from environment variables
	envVars := GetEnvVars()

	// Create test options
	options, err := setupOptions(t, hpcClusterPrefix, terraformDir, envVars.DefaultResourceGroup, ignoreDestroys)
	options.TerraformVars["vpc_name"] = vpcName
	options.TerraformVars["vpc_cluster_private_subnets_cidr_blocks"] = utils.SplitAndTrim(vpcClusterPrivateSubnetsCidrBlocks, ",")
	options.TerraformVars["vpc_cluster_login_private_subnets_cidr_blocks"] = utils.SplitAndTrim(vpcClusterLoginPrivateSubnetsCidrBlocks, ",")
	require.NoError(t, err, "Error setting up test options: %v", err)

	// Skip test teardown for further inspection
	options.SkipTestTearDown = true
	defer options.TestTearDown()

	lsf.ValidateClusterConfiguration(t, options, testLogger)
}

// RunHpcExistingVpcSubnetId with compute and login subnet id's
func RunHpcExistingVpcSubnetId(t *testing.T, vpcName string, bastionsubnetId string, computesubnetIds string) {
	// Setup test suite
	setupTestSuite(t)

	testLogger.Info(t, "Cluster creation process initiated for "+t.Name())

	// HPC cluster prefix
	hpcClusterPrefix := utils.GenerateRandomString()

	// Retrieve cluster information from environment variables
	envVars := GetEnvVars()

	// Create test options
	options, err := setupOptions(t, hpcClusterPrefix, terraformDir, envVars.DefaultResourceGroup, ignoreDestroys)
	options.TerraformVars["vpc_name"] = vpcName
	options.TerraformVars["login_subnet_id"] = bastionsubnetId
	options.TerraformVars["cluster_subnet_ids"] = utils.SplitAndTrim(computesubnetIds, ",")
	require.NoError(t, err, "Error setting up test options: %v", err)

	// Skip test teardown for further inspection
	options.SkipTestTearDown = true
	defer options.TestTearDown()

	lsf.ValidateClusterConfiguration(t, options, testLogger)
}

// TestRunCreateVpcWithCustomDns brand new VPC with DNS
func TestRunVpcWithCustomDns(t *testing.T) {
	// Parallelize the test to run concurrently with others
	t.Parallel()

	// Setup test suite
	setupTestSuite(t)

	testLogger.Info(t, "Cluster creation process initiated for "+t.Name())

	// Define the HPC cluster prefix
	hpcClusterPrefix := utils.GenerateRandomString()

	// Retrieve cluster information from environment variables
	envVars := GetEnvVars()

	// Create test options, set up test environment
	options, err := setupOptionsVpc(t, hpcClusterPrefix, createVpcTerraformDir, envVars.DefaultResourceGroup)
	options.TerraformVars["enable_hub"] = true

	require.NoError(t, err, "Error setting up test options: %v", err)

	// Skip test teardown for further inspection
	options.SkipTestTearDown = true
	defer options.TestTearDown()

	// Run the test
	output, err := options.RunTestConsistency()
	require.NoError(t, err, "Error running consistency test: %v", err)
	require.NotNil(t, output, "Expected non-nil output, but got nil")

	outputs := (options.LastTestTerraformOutputs)
	vpcName := outputs["vpc_name"].(string)
	instanceId, customResolverId := utils.GetDnsCustomResolverIds(outputs)
	bastionsubnetId, computesubnetIds := utils.GetSubnetIds(outputs)

	RunHpcExistingVpcCustomDnsExist(t, vpcName, bastionsubnetId, computesubnetIds, instanceId, customResolverId)
	RunHpcExistingVpcCustomExistDnsNew(t, vpcName, bastionsubnetId, computesubnetIds, customResolverId)
	RunHpcNewVpcCustomNullExistDns(t, instanceId)
	RunHpcNewVpcExistCustomDnsNull(t, customResolverId)
}

// RunHpcExistingVpcCustomDns with existing custom_reslover_id and dns_instance_id
func RunHpcExistingVpcCustomDnsExist(t *testing.T, vpcName string, bastionsubnetId string, computesubnetIds string, instanceId string, customResolverId string) {
	// Setup test suite
	setupTestSuite(t)

	testLogger.Info(t, "Cluster creation process initiated for "+t.Name())

	// HPC cluster prefix
	hpcClusterPrefix := utils.GenerateRandomString()

	// Retrieve cluster information from environment variables
	envVars := GetEnvVars()

	// Create test options
	options, err := setupOptions(t, hpcClusterPrefix, terraformDir, envVars.DefaultResourceGroup, ignoreDestroys)
	options.TerraformVars["vpc_name"] = vpcName
	options.TerraformVars["login_subnet_id"] = bastionsubnetId
	options.TerraformVars["cluster_subnet_ids"] = utils.SplitAndTrim(computesubnetIds, ",")
	options.TerraformVars["dns_instance_id"] = instanceId
	options.TerraformVars["dns_custom_resolver_id"] = customResolverId

	require.NoError(t, err, "Error setting up test options: %v", err)

	// Skip test teardown for further inspection
	options.SkipTestTearDown = true
	defer options.TestTearDown()

	lsf.ValidateClusterConfiguration(t, options, testLogger)
}

// RunHpcExistingVpcCustomExistDnsNew with existing custom_reslover_id and new dns_instance_id
func RunHpcExistingVpcCustomExistDnsNew(t *testing.T, vpcName string, bastionsubnetId string, computesubnetIds string, customResolverId string) {
	// Setup test suite
	setupTestSuite(t)

	testLogger.Info(t, "Cluster creation process initiated for "+t.Name())

	// HPC cluster prefix
	hpcClusterPrefix := utils.GenerateRandomString()

	// Retrieve cluster information from environment variables
	envVars := GetEnvVars()

	// Create test options
	options, err := setupOptions(t, hpcClusterPrefix, terraformDir, envVars.DefaultResourceGroup, ignoreDestroys)
	options.TerraformVars["vpc_name"] = vpcName
	options.TerraformVars["login_subnet_id"] = bastionsubnetId
	options.TerraformVars["cluster_subnet_ids"] = utils.SplitAndTrim(computesubnetIds, ",")
	options.TerraformVars["dns_custom_resolver_id"] = customResolverId

	require.NoError(t, err, "Error setting up test options: %v", err)

	// Skip test teardown for further inspection
	options.SkipTestTearDown = true
	defer options.TestTearDown()

	lsf.ValidateClusterConfiguration(t, options, testLogger)
}

// RunHpcNewVpcCustomNullExistDns with custom_reslover_id null and existing dns_instance_id
func RunHpcNewVpcCustomNullExistDns(t *testing.T, instanceId string) {
	// Setup test suite
	setupTestSuite(t)

	testLogger.Info(t, "Cluster creation process initiated for "+t.Name())

	// HPC cluster prefix
	hpcClusterPrefix := utils.GenerateRandomString()

	// Retrieve cluster information from environment variables
	envVars := GetEnvVars()

	// Create test options
	options, err := setupOptions(t, hpcClusterPrefix, terraformDir, envVars.DefaultResourceGroup, ignoreDestroys)
	options.TerraformVars["dns_instance_id"] = instanceId

	require.NoError(t, err, "Error setting up test options: %v", err)

	// Skip test teardown for further inspection
	options.SkipTestTearDown = true
	defer options.TestTearDown()

	lsf.ValidateClusterConfiguration(t, options, testLogger)
}

// RunHpcNewVpcExistCustomDnsNull with existing custom_reslover_id and dns_instance_id null
func RunHpcNewVpcExistCustomDnsNull(t *testing.T, customResolverId string) {
	// Setup test suite
	setupTestSuite(t)

	testLogger.Info(t, "Cluster creation process initiated for "+t.Name())

	// HPC cluster prefix
	hpcClusterPrefix := utils.GenerateRandomString()

	// Retrieve cluster information from environment variables
	envVars := GetEnvVars()

	// Create test options
	options, err := setupOptions(t, hpcClusterPrefix, terraformDir, envVars.DefaultResourceGroup, ignoreDestroys)
	options.TerraformVars["dns_instance_id"] = customResolverId

	require.NoError(t, err, "Error setting up test options: %v", err)

	// Skip test teardown for further inspection
	options.SkipTestTearDown = true
	defer options.TestTearDown()

	lsf.ValidateClusterConfiguration(t, options, testLogger)
}

// TestRunWithoutMandatory tests Terraform's behavior when mandatory variables are missing by checking for specific error messages.
func TestRunWithoutMandatory(t *testing.T) {
	t.Parallel()

	// Setup test suite
	setupTestSuite(t)

	testLogger.Info(t, "Cluster creation process initiated for "+t.Name())

	// Getting absolute path of solutions/hpc
	abs, err := filepath.Abs("solutions/hpc")
	require.NoError(t, err, "Unable to get absolute path")

	terrPath := strings.ReplaceAll(abs, "tests/", "")

	// Define Terraform options
	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: terrPath,
		Vars:         map[string]interface{}{},
	})

	// Initialize and plan the Terraform deployment
	_, err = terraform.InitAndPlanE(t, terraformOptions)

	// If there is an error, check if it contains specific mandatory fields
	if err != nil {
		result := utils.VerifyDataContains(t, err.Error(), "cluster_id", testLogger) &&
			utils.VerifyDataContains(t, err.Error(), "reservation_id", testLogger) &&
			utils.VerifyDataContains(t, err.Error(), "bastion_ssh_keys", testLogger) &&
			utils.VerifyDataContains(t, err.Error(), "compute_ssh_keys", testLogger) &&
			utils.VerifyDataContains(t, err.Error(), "remote_allowed_ips", testLogger)
		// Assert that the result is true if all mandatory fields are missing
		assert.True(t, result)
	} else {
		t.Error("Expected error did not occur")
	}

}

func TestRunCIDRsAsNonDefault(t *testing.T) {
	// Parallelize the test
	t.Parallel()

	// Setup test suite
	setupTestSuite(t)

	testLogger.Info(t, "Cluster creation process initiated for "+t.Name())

	// HPC cluster prefix
	hpcClusterPrefix := utils.GenerateRandomString()

	// Retrieve cluster information from environment variables
	envVars := GetEnvVars()

	// Create test options
	options, err := setupOptions(t, hpcClusterPrefix, terraformDir, envVars.DefaultResourceGroup, ignoreDestroys)
	require.NoError(t, err, "Error setting up test options: %v", err)

	options.TerraformVars["vpc_cidr"] = "10.243.0.0/18"
	options.TerraformVars["vpc_cluster_private_subnets_cidr_blocks"] = []string{"10.243.0.0/20"}
	options.TerraformVars["vpc_cluster_login_private_subnets_cidr_blocks"] = []string{"10.243.16.0/28"}

	options.SkipTestTearDown = true
	defer options.TestTearDown()

	lsf.ValidateBasicClusterConfiguration(t, options, testLogger)
}

// TestRunExistingPACEnvironment tests the validation of an existing PAC environment configuration.
func TestRunExistingPACEnvironment(t *testing.T) {
	// Parallelize the test to run concurrently with others
	t.Parallel()

	// Setup the test suite environment
	setupTestSuite(t)

	// Log the initiation of cluster creation process
	testLogger.Info(t, "Cluster creation process initiated for "+t.Name())

	// Retrieve the environment variable for the JSON file path
	val, ok := os.LookupEnv("EXISTING_ENV_JSON_FILE_PATH")
	if !ok {
		t.Fatal("Environment variable 'EXISTING_ENV_JSON_FILE_PATH' is not set")
	}

	// Check if the JSON file exists
	if _, err := os.Stat(val); os.IsNotExist(err) {
		t.Fatalf("JSON file '%s' does not exist", val)
	}

	// Parse the JSON configuration file
	config, err := utils.ParseConfig(val)
	require.NoError(t, err, "Error parsing JSON configuration: %v", err)

	// Validate the cluster configuration
	lsf.ValidateClusterConfigurationWithAPPCenterForExistingEnv(t, config.BastionIP, config.LoginNodeIP, config.ClusterID, config.ReservationID, config.ClusterPrefixName, config.ResourceGroup,
		config.KeyManagement, config.Zones, config.DnsDomainName, config.ManagementNodeIPList, config.HyperthreadingEnabled, testLogger)
}

// TestRunInvalidReservationIDAndContractID tests invalid cluster_id and reservation_id values
func TestRunInvalidReservationIDAndContractID(t *testing.T) {
	t.Parallel()

	// Setup test suite
	setupTestSuite(t)

	// Log the initiation of cluster creation process
	testLogger.Info(t, "Cluster creation process initiated for "+t.Name())

	// HPC cluster prefix
	hpcClusterPrefix := utils.GenerateTimestampedClusterPrefix(utils.GenerateRandomString())

	// Retrieve cluster information from environment variables
	envVars := GetEnvVars()

	// Define invalid cluster_id and reservation_id values
	invalidClusterIDs := []string{
		"too_long_cluster_id_1234567890_abcdefghijklmnopqrstuvwxyz", //pragma: allowlist secret
		"invalid@cluster!id#",
		"",
	}

	invalidReservationIDs := []string{
		"1invalid_reservation",
		"invalid_reservation@id",
		"ContractIBM",
		"",
	}

	// Getting absolute path of solutions/hpc
	abs, err := filepath.Abs("solutions/hpc")
	require.NoError(t, err, "Unable to get absolute path")

	terrPath := strings.ReplaceAll(abs, "tests/", "")

	// Loop over all combinations of invalid cluster_id and reservation_id values
	for _, clusterID := range invalidClusterIDs {
		for _, reservationID := range invalidReservationIDs {

			// Define Terraform options
			terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
				TerraformDir: terrPath,
				Vars: map[string]interface{}{
					"cluster_prefix":     hpcClusterPrefix,
					"bastion_ssh_keys":   utils.SplitAndTrim(envVars.SSHKey, ","),
					"compute_ssh_keys":   utils.SplitAndTrim(envVars.SSHKey, ","),
					"zones":              utils.SplitAndTrim(envVars.Zone, ","),
					"remote_allowed_ips": utils.SplitAndTrim(envVars.RemoteAllowedIPs, ","),
					"cluster_id":         clusterID,
					"reservation_id":     reservationID,
				},
			})

			// Initialize and plan the Terraform deployment
			_, err := terraform.InitAndPlanE(t, terraformOptions)

			// If there is an error, check if it contains specific mandatory fields
			if err != nil {
				clusterIDError := utils.VerifyDataContains(t, err.Error(), "cluster_id", testLogger)
				reservationIDError := utils.VerifyDataContains(t, err.Error(), "reservation_id", testLogger)
				result := clusterIDError && reservationIDError
				// Assert that the result is true if all mandatory fields are missing
				assert.True(t, result)
				if result {
					testLogger.PASS(t, "Validation succeeded: Invalid clusterID and ReservationID")
				} else {
					testLogger.FAIL(t, "Validation failed: Expected error did not contain required fields: cluster_id or reservation_id")
				}
			} else {
				// Log an error if the expected error did not occur
				t.Error("Expected error did not occur")
				testLogger.FAIL(t, "Expected error did not occur on Invalid clusterID and ReservationID validation")
			}
		}
	}
}

// TestRunInvalidLDAPServerIP validates cluster creation with invalid LDAP server IP.
func TestRunInvalidLDAPServerIP(t *testing.T) {
	// Parallelize the test to run concurrently with others
	t.Parallel()

	// Setup test suite
	setupTestSuite(t)

	testLogger.Info(t, "Cluster creation process initiated for "+t.Name())

	// HPC cluster prefix
	hpcClusterPrefix := utils.GenerateTimestampedClusterPrefix(utils.GenerateRandomString())

	// Retrieve cluster information from environment variables
	envVars := GetEnvVars()

	if strings.ToLower(envVars.EnableLdap) == "true" {
		// Check if the LDAP credentials are provided
		if len(envVars.LdapAdminPassword) == 0 || len(envVars.LdapUserName) == 0 || len(envVars.LdapUserPassword) == 0 {
			require.FailNow(t, "LDAP credentials are missing. Make sure LDAP admin password, LDAP user name, and LDAP user password are provided.")
		}
	} else {
		require.FailNow(t, "LDAP is not enabled. Set the 'enable_ldap' environment variable to 'true' to enable LDAP.")
	}

	// Get the absolute path of solutions/hpc
	abs, err := filepath.Abs("solutions/hpc")
	require.NoError(t, err, "Unable to get absolute path")

	terrPath := strings.ReplaceAll(abs, "tests/", "")

	// Define Terraform options
	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: terrPath,
		Vars: map[string]interface{}{
			"cluster_prefix":      hpcClusterPrefix,
			"bastion_ssh_keys":    utils.SplitAndTrim(envVars.SSHKey, ","),
			"compute_ssh_keys":    utils.SplitAndTrim(envVars.SSHKey, ","),
			"zones":               utils.SplitAndTrim(envVars.Zone, ","),
			"remote_allowed_ips":  utils.SplitAndTrim(envVars.RemoteAllowedIPs, ","),
			"cluster_id":          envVars.ClusterID,
			"reservation_id":      envVars.ReservationID,
			"enable_ldap":         true,
			"ldap_admin_password": envVars.LdapAdminPassword, //pragma: allowlist secret
			"ldap_server":         "10.10.10.10",
		},
	})

	// Apply the Terraform configuration
	_, err = terraform.InitAndApplyE(t, terraformOptions)

	// Check if an error occurred during apply
	assert.Error(t, err, "Expected an error during apply")

	if err != nil {
		// Check if the error message contains specific keywords indicating LDAP server IP issues
		result := utils.VerifyDataContains(t, err.Error(), "The connection to the existing LDAP server 10.10.10.10 failed", testLogger)
		assert.True(t, result)
		if result {
			testLogger.PASS(t, "Validation succeeded: Invalid LDAP server IP")
		} else {
			testLogger.FAIL(t, "Validation failed: Invalid LDAP server IP")
		}
	} else {
		// Log an error if the expected error did not occur
		t.Error("Expected error did not occur")
		testLogger.FAIL(t, "Expected error did not occur on Invalid LDAP Server IP")
	}

	// Cleanup resources
	defer terraform.Destroy(t, terraformOptions)
}

// TestRunInvalidLDAPUsernamePassword tests invalid LDAP username and password
func TestRunInvalidLDAPUsernamePassword(t *testing.T) {
	t.Parallel()

	// Setup test suite
	setupTestSuite(t)

	// Log the initiation of cluster creation process
	testLogger.Info(t, "Cluster creation process initiated for "+t.Name())

	// HPC cluster prefix
	hpcClusterPrefix := utils.GenerateTimestampedClusterPrefix(utils.GenerateRandomString())

	// Retrieve cluster information from environment variables
	envVars := GetEnvVars()

	// Define invalid ldap username and password values
	invalidLDAPUsername := []string{
		"usr",
		"user@1234567890123456789012345678901",
		"",
		"user 1234",
	}

	invalidLDAPPassword := []string{
		"password",
		"PasswoRD123",
		"password123",
		"Password@",
		"Password123",
		"password@12345678901234567890",
	}

	// Getting absolute path of solutions/hpc
	abs, err := filepath.Abs("solutions/hpc")
	require.NoError(t, err, "Unable to get absolute path")

	terrPath := strings.ReplaceAll(abs, "tests/", "")

	// Loop over all combinations of invalid ldap username and password values
	for _, username := range invalidLDAPUsername {
		for _, password := range invalidLDAPPassword { //pragma: allowlist secret

			// Define Terraform options
			terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
				TerraformDir: terrPath,
				Vars: map[string]interface{}{
					"cluster_prefix":      hpcClusterPrefix,
					"bastion_ssh_keys":    utils.SplitAndTrim(envVars.SSHKey, ","),
					"compute_ssh_keys":    utils.SplitAndTrim(envVars.SSHKey, ","),
					"zones":               utils.SplitAndTrim(envVars.Zone, ","),
					"remote_allowed_ips":  utils.SplitAndTrim(envVars.RemoteAllowedIPs, ","),
					"cluster_id":          envVars.ClusterID,
					"reservation_id":      envVars.ReservationID,
					"enable_ldap":         true,
					"ldap_user_name":      username,
					"ldap_user_password":  password, //pragma: allowlist secret
					"ldap_admin_password": password, //pragma: allowlist secret
				},
			})

			// Initialize and plan the Terraform deployment
			_, err := terraform.InitAndPlanE(t, terraformOptions)

			// If there is an error, check if it contains specific mandatory fields
			if err != nil {
				usernameError := utils.VerifyDataContains(t, err.Error(), "ldap_user_name", testLogger)
				userPasswordError := utils.VerifyDataContains(t, err.Error(), "ldap_usr_pwd", testLogger)
				adminPasswordError := utils.VerifyDataContains(t, err.Error(), "ldap_adm_pwd", testLogger)
				result := usernameError && userPasswordError && adminPasswordError

				// Assert that the result is true if all mandatory fields are missing
				assert.True(t, result)
				if result {
					testLogger.PASS(t, "Validation succeeded: Invalid LDAP username  LDAP user password ,LDAP admin password")
				} else {
					testLogger.FAIL(t, "Validation failed: Expected error did not contain required fields: ldap_user_name, ldap_user_password or ldap_admin_password")
				}
			} else {
				// Log an error if the expected error did not occur
				t.Error("Expected error did not occur")
				testLogger.FAIL(t, "Expected error did not contain required fields: ldap_user_name, ldap_user_password or ldap_admin_password")
			}
		}
	}
}

// TestRunInvalidAPPCenterPassword tests invalid values for app center password
func TestRunInvalidAPPCenterPassword(t *testing.T) {
	t.Parallel()

	// Setup test suite
	setupTestSuite(t)

	// Log the initiation of cluster creation process
	testLogger.Info(t, "Cluster creation process initiated for "+t.Name())

	invalidAPPCenterPwd := []string{
		"pass@1234",
		"Pass1234",
		"Pas@12",
		"",
	}

	// Loop over all combinations of invalid cluster_id and reservation_id values
	for _, password := range invalidAPPCenterPwd { //pragma: allowlist secret

		// HPC cluster prefix
		hpcClusterPrefix := utils.GenerateTimestampedClusterPrefix(utils.GenerateRandomString())
		// Retrieve cluster information from environment variables
		envVars := GetEnvVars()

		// Getting absolute path of solutions/hpc
		abs, err := filepath.Abs("solutions/hpc")
		require.NoError(t, err, "Unable to get absolute path")

		terrPath := strings.ReplaceAll(abs, "tests/", "")

		// Define Terraform options
		terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
			TerraformDir: terrPath,
			Vars: map[string]interface{}{
				"cluster_prefix":     hpcClusterPrefix,
				"bastion_ssh_keys":   utils.SplitAndTrim(envVars.SSHKey, ","),
				"compute_ssh_keys":   utils.SplitAndTrim(envVars.SSHKey, ","),
				"zones":              utils.SplitAndTrim(envVars.Zone, ","),
				"remote_allowed_ips": utils.SplitAndTrim(envVars.RemoteAllowedIPs, ","),
				"cluster_id":         envVars.ClusterID,
				"reservation_id":     envVars.ReservationID,
				"enable_app_center":  true,
				"app_center_gui_pwd": password,
			},
		})

		// Initialize and plan the Terraform deployment
		_, err = terraform.InitAndPlanE(t, terraformOptions)

		// If there is an error, check if it contains specific mandatory fields
		if err != nil {
			result := utils.VerifyDataContains(t, err.Error(), "app_center_gui_pwd", testLogger)

			// Assert that the result is true if all mandatory fields are missing
			assert.True(t, result)
			if result {
				testLogger.PASS(t, "Validation succeeded: Invalid Application Center Password")
			} else {
				testLogger.FAIL(t, "Validation failed: Invalid Application Center Password")
			}
		} else {
			// Log an error if the expected error did not occur
			t.Error("Expected error did not occur")
			testLogger.FAIL(t, "Expected error did not occur on Invalid Application Center Password")
		}
	}
}

// TestRunInvalidDomainName validates cluster creation with invalid domain name.
func TestRunInvalidDomainName(t *testing.T) {
	// Parallelize the test to run concurrently with others
	t.Parallel()

	// Setup test suite
	setupTestSuite(t)

	testLogger.Info(t, "Cluster creation process initiated for "+t.Name())

	// HPC cluster prefix
	hpcClusterPrefix := utils.GenerateTimestampedClusterPrefix(utils.GenerateRandomString())

	// Retrieve cluster information from environment variables
	envVars := GetEnvVars()

	// Get the absolute path of solutions/hpc
	abs, err := filepath.Abs("solutions/hpc")
	require.NoError(t, err, "Unable to get absolute path")

	terrPath := strings.ReplaceAll(abs, "tests/", "")

	// Define Terraform options
	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: terrPath,
		Vars: map[string]interface{}{
			"cluster_prefix":     hpcClusterPrefix,
			"bastion_ssh_keys":   utils.SplitAndTrim(envVars.SSHKey, ","),
			"compute_ssh_keys":   utils.SplitAndTrim(envVars.SSHKey, ","),
			"zones":              utils.SplitAndTrim(envVars.Zone, ","),
			"remote_allowed_ips": utils.SplitAndTrim(envVars.RemoteAllowedIPs, ","),
			"cluster_id":         envVars.ClusterID,
			"reservation_id":     envVars.ReservationID,
			"dns_domain_name":    map[string]string{"compute": "sample"},
		},
	})

	// Apply the Terraform configuration
	_, err = terraform.InitAndPlanE(t, terraformOptions)

	// Check if an error occurred during apply
	assert.Error(t, err, "Expected an error during apply")

	if err != nil {
		// Check if the error message contains specific keywords indicating domain name issues
		result := utils.VerifyDataContains(t, err.Error(), "The domain name provided for compute is not a fully qualified domain name", testLogger)
		assert.True(t, result)
		if result {
			testLogger.PASS(t, "Validation succeeded: Invalid domain name")
		} else {
			testLogger.FAIL(t, "Validation failed: Invalid domain name")
		}
	} else {
		// Log an error if the expected error did not occur
		t.Error("Expected error did not occur")
		testLogger.FAIL(t, "Expected error did not occur on Invalid domain name")
	}
}

// TestRunKMSInstanceNameAndKMSKeyNameWithInvalidValue tests the creation of KMS instances and KMS key names with invalid values
func TestRunKMSInstanceNameAndKMSKeyNameWithInvalidValue(t *testing.T) {
	// Parallelize the test to run concurrently with others
	t.Parallel()

	// Setup test suite
	setupTestSuite(t)

	testLogger.Info(t, "Cluster creation process initiated for "+t.Name())

	// Service instance name
	randomString := utils.GenerateRandomString()
	kmsInstanceName := "cicd-" + randomString

	// HPC cluster prefix
	hpcClusterPrefix := utils.GenerateTimestampedClusterPrefix(utils.GenerateRandomString())

	// Retrieve cluster information from environment variables
	envVars := GetEnvVars()

	// Create service instance and KMS key using IBMCloud CLI
	err := lsf.CreateServiceInstanceandKmsKey(t, os.Getenv("TF_VAR_ibmcloud_api_key"), utils.GetRegion(envVars.Zone), envVars.DefaultResourceGroup, kmsInstanceName, lsf.KMS_KEY_NAME, testLogger)
	require.NoError(t, err, "Failed to create service instance and KMS key")

	// Ensure the service instance and KMS key are deleted after the test
	defer lsf.DeleteServiceInstanceAndAssociatedKeys(t, os.Getenv("TF_VAR_ibmcloud_api_key"), utils.GetRegion(envVars.Zone), envVars.DefaultResourceGroup, kmsInstanceName, testLogger)

	testLogger.Info(t, "Service instance and KMS key created successfully: "+t.Name())

	abs, err := filepath.Abs("solutions/hpc")
	require.NoError(t, err, "Failed to get absolute path")

	terrPath := strings.ReplaceAll(abs, "tests/", "")

	const (
		invalidKMSKeyName      = "sample-key"
		invalidKMSInstanceName = "sample-ins"
		noKeyErrorMsg          = "No keys with name sample-key"
		noInstanceErrorMsg     = "No resource instance found with name [sample-ins]"
		noInstanceIDErrorMsg   = "Please make sure you are passing the kms_instance_name if you are passing kms_key_name"
	)

	// Test with valid instance ID and invalid key name
	terraformOptionsCase1 := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: terrPath,
		Vars: map[string]interface{}{
			"cluster_prefix":     hpcClusterPrefix,
			"bastion_ssh_keys":   utils.SplitAndTrim(envVars.SSHKey, ","),
			"compute_ssh_keys":   utils.SplitAndTrim(envVars.SSHKey, ","),
			"zones":              utils.SplitAndTrim(envVars.Zone, ","),
			"remote_allowed_ips": utils.SplitAndTrim(envVars.RemoteAllowedIPs, ","),
			"cluster_id":         envVars.ClusterID,
			"reservation_id":     envVars.ReservationID,
			"kms_instance_name":  kmsInstanceName,
			"kms_key_name":       invalidKMSKeyName,
		},
	})

	_, err = terraform.InitAndPlanE(t, terraformOptionsCase1)
	if err != nil {
		result := utils.VerifyDataContains(t, err.Error(), noKeyErrorMsg, testLogger)
		assert.True(t, result)
		if result {
			testLogger.PASS(t, "Validation succeeded: Valid instance ID and invalid key name")
		} else {
			testLogger.FAIL(t, "Validation failed: Valid instance ID and invalid key name")
		}
	} else {
		t.Error("Expected error did not occur")
		testLogger.FAIL(t, "Expected error did not occur with valid instance ID and invalid key name")
	}

	// Test with invalid instance ID and valid key name
	terraformOptionsCase2 := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: terrPath,
		Vars: map[string]interface{}{
			"cluster_prefix":     hpcClusterPrefix,
			"bastion_ssh_keys":   utils.SplitAndTrim(envVars.SSHKey, ","),
			"compute_ssh_keys":   utils.SplitAndTrim(envVars.SSHKey, ","),
			"zones":              utils.SplitAndTrim(envVars.Zone, ","),
			"remote_allowed_ips": utils.SplitAndTrim(envVars.RemoteAllowedIPs, ","),
			"cluster_id":         envVars.ClusterID,
			"reservation_id":     envVars.ReservationID,
			"kms_instance_name":  invalidKMSInstanceName,
			"kms_key_name":       lsf.KMS_KEY_NAME,
		},
	})

	_, err = terraform.InitAndPlanE(t, terraformOptionsCase2)
	if err != nil {
		result := utils.VerifyDataContains(t, err.Error(), noInstanceErrorMsg, testLogger)
		assert.True(t, result)
		if result {
			testLogger.PASS(t, "Validation succeeded: Invalid instance ID and valid key name")
		} else {
			testLogger.FAIL(t, "Validation failed: Invalid instance ID and valid key name")
		}
	} else {
		t.Error("Expected error did not occur")
		testLogger.FAIL(t, "Expected error did not occur with invalid instance ID and valid key name")
	}

	// Test without instance ID and valid key name
	terraformOptionsCase3 := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: terrPath,
		Vars: map[string]interface{}{
			"cluster_prefix":     hpcClusterPrefix,
			"bastion_ssh_keys":   utils.SplitAndTrim(envVars.SSHKey, ","),
			"compute_ssh_keys":   utils.SplitAndTrim(envVars.SSHKey, ","),
			"zones":              utils.SplitAndTrim(envVars.Zone, ","),
			"remote_allowed_ips": utils.SplitAndTrim(envVars.RemoteAllowedIPs, ","),
			"cluster_id":         envVars.ClusterID,
			"reservation_id":     envVars.ReservationID,
			"kms_key_name":       lsf.KMS_KEY_NAME,
		},
	})

	_, err = terraform.InitAndPlanE(t, terraformOptionsCase3)
	if err != nil {
		result := utils.VerifyDataContains(t, err.Error(), noInstanceIDErrorMsg, testLogger)
		assert.True(t, result)
		if result {
			testLogger.PASS(t, "Validation succeeded: Without instance ID and valid key name")
		} else {
			testLogger.FAIL(t, "Validation failed: Without instance ID and valid key name")
		}
	} else {
		t.Error("Expected error did not occur")
		testLogger.FAIL(t, "Expected error did not occur without instance ID and valid key name")
	}
}

// Verify that existing subnet_id has an input value, then there should be an entry for 'vpc_name'
func TestRunExistSubnetIDVpcNameAsNull(t *testing.T) {
	// Parallelize the test to run concurrently with others
	t.Parallel()

	// Setup test suite
	setupTestSuite(t)

	testLogger.Info(t, "Cluster creation process initiated for "+t.Name())

	// HPC cluster prefix
	hpcClusterPrefix := utils.GenerateTimestampedClusterPrefix(utils.GenerateRandomString())

	// Retrieve cluster information from environment variables
	envVars := GetEnvVars()

	// Create test options, set up test environment
	options, err := setupOptionsVpc(t, hpcClusterPrefix, createVpcTerraformDir, envVars.DefaultResourceGroup)
	require.NoError(t, err, "Error setting up test options: %v", err)

	// Skip test teardown for further inspection
	options.SkipTestTearDown = true
	defer options.TestTearDown()

	// Run the test
	output, err := options.RunTest()
	require.NoError(t, err, "Error running consistency test: %v", err)
	require.NotNil(t, output, "Expected non-nil output, but got nil")
	outputs := (options.LastTestTerraformOutputs)

	bastionsubnetId, computesubnetIds := utils.GetSubnetIds(outputs)

	// Get the absolute path of solutions/hpc
	abs, err := filepath.Abs("solutions/hpc")
	require.NoError(t, err, "Unable to get absolute path")

	terrPath := strings.ReplaceAll(abs, "tests/", "")

	// Define Terraform options
	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: terrPath,
		Vars: map[string]interface{}{
			"cluster_prefix":     hpcClusterPrefix,
			"bastion_ssh_keys":   utils.SplitAndTrim(envVars.SSHKey, ","),
			"compute_ssh_keys":   utils.SplitAndTrim(envVars.SSHKey, ","),
			"zones":              utils.SplitAndTrim(envVars.Zone, ","),
			"remote_allowed_ips": utils.SplitAndTrim(envVars.RemoteAllowedIPs, ","),
			"cluster_id":         envVars.ClusterID,
			"reservation_id":     envVars.ReservationID,
			"cluster_subnet_ids": utils.SplitAndTrim(computesubnetIds, ","),
			"login_subnet_id":    bastionsubnetId,
		},
	})

	// Apply the Terraform configuration
	_, err = terraform.InitAndPlanE(t, terraformOptions)

	// Check if an error occurred during plan
	assert.Error(t, err, "Expected an error during plan")

	if err != nil {
		// Check if the error message contains specific keywords indicating vpc name issues
		result := utils.VerifyDataContains(t, err.Error(), "If the cluster_subnet_ids are provided, the user should also provide the vpc_name", testLogger) &&
			utils.VerifyDataContains(t, err.Error(), "Provided cluster subnets should be in appropriate zone", testLogger) &&
			utils.VerifyDataContains(t, err.Error(), "Provided login subnet should be within the vpc entered", testLogger) &&
			utils.VerifyDataContains(t, err.Error(), "Provided login subnet should be in appropriate zone", testLogger) &&
			utils.VerifyDataContains(t, err.Error(), "Provided cluster subnets should be within the vpc entered", testLogger) &&
			utils.VerifyDataContains(t, err.Error(), "Provided existing cluster_subnet_ids should have public gateway attached", testLogger)
		assert.True(t, result)
		if result {
			testLogger.PASS(t, "Validation succeeded: Without VPC name and with valid cluster_subnet_ids and login_subnet_id")
		} else {
			testLogger.FAIL(t, "Validation failed: Without VPC name and with valid cluster_subnet_ids and login_subnet_id")
		}
	} else {
		// Log an error if the expected error did not occur
		t.Error("Expected error did not occur")
		testLogger.FAIL(t, "Expected error did not occur on Without VPC name and with valid cluster_subnet_ids and login_subnet_id")
	}
}

// TestRunInvalidSshKeysAndRemoteAllowedIP validates cluster creation with invalid ssh keys and remote allowed IP.
func TestRunInvalidSshKeysAndRemoteAllowedIP(t *testing.T) {
	// Parallelize the test to run concurrently with others
	t.Parallel()

	// Setup test suite
	setupTestSuite(t)

	testLogger.Info(t, "Cluster creation process initiated for "+t.Name())

	// HPC cluster prefix
	hpcClusterPrefix := utils.GenerateTimestampedClusterPrefix(utils.GenerateRandomString())

	// Retrieve cluster information from environment variables
	envVars := GetEnvVars()

	// Get the absolute path of solutions/hpc
	abs, err := filepath.Abs("solutions/hpc")
	require.NoError(t, err, "Unable to get absolute path")

	terrPath := strings.ReplaceAll(abs, "tests/", "")

	// Define Terraform options
	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: terrPath,
		Vars: map[string]interface{}{
			"cluster_prefix":     hpcClusterPrefix,
			"bastion_ssh_keys":   []string{""},
			"compute_ssh_keys":   []string{""},
			"zones":              utils.SplitAndTrim(envVars.Zone, ","),
			"remote_allowed_ips": []string{""},
			"cluster_id":         envVars.ClusterID,
			"reservation_id":     envVars.ReservationID,
		},
	})

	// Apply the Terraform configuration
	_, err = terraform.InitAndPlanE(t, terraformOptions)

	// Check if an error occurred during apply
	assert.Error(t, err, "Expected an error during apply")

	if err != nil {
		// Check if the error message contains specific keywords indicating domain name issues
		result := utils.VerifyDataContains(t, err.Error(), "The provided IP address format is not valid", testLogger) &&
			utils.VerifyDataContains(t, err.Error(), "No SSH Key found with name", testLogger)
		assert.True(t, result)
		if result {
			testLogger.PASS(t, "Validation succeeded: Invalid ssh keys and remote allowed IP")
		} else {
			testLogger.FAIL(t, "Validation failed: Invalid ssh keys and remote allowed IP")
		}
	} else {
		// Log an error if the expected error did not occur
		t.Error("Expected error did not occur")
		testLogger.FAIL(t, "Expected error did not occur on Invalid ssh keys and remote allowed IP")
	}
}
