package tests

import (
	"os"
	"strings"
	"testing"

	"github.com/stretchr/testify/require"

	utils "github.com/terraform-ibm-modules/terraform-ibm-hpc/common_utils"
	lsf "github.com/terraform-ibm-modules/terraform-ibm-hpc/lsf"
)

// TestRunBasic validates the cluster configuration and creation of an HPC cluster.
func TestRunBasic(t *testing.T) {

	// Parallelize the test
	t.Parallel()

	// Setup test suite
	setupTestSuite(t)

	testLogger.Info(t, "Cluster creation process initiated for "+t.Name())

	// HPC cluster prefix
	hpcClusterPrefix := "cicd-" + utils.GenerateRandomString()

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
	hpcClusterPrefix := "cicd-" + utils.GenerateRandomString()

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
	hpcClusterPrefix := "cicd-" + utils.GenerateRandomString()

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
	hpcClusterPrefix := "cicd-" + utils.GenerateRandomString()

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
	hpcClusterPrefix := "cicd-" + utils.GenerateRandomString()

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
	hpcClusterPrefix := "cicd-" + utils.GenerateRandomString()

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

// TestRunInEuGbRegion validates cluster creation in the Frankfurt region.
func TestRunInEuDeRegion(t *testing.T) {
	// Parallelize the test to run concurrently with others
	t.Parallel()

	// Setup test suite
	setupTestSuite(t)

	testLogger.Info(t, "Cluster creation process initiated for "+t.Name())

	// HPC cluster prefix
	hpcClusterPrefix := "cicd-" + utils.GenerateRandomString()

	// Retrieve cluster information from environment variables
	envVars := GetEnvVars()

	// Extract EU GB zone, cluster ID, and reservation ID
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
	hpcClusterPrefix := "cicd-" + utils.GenerateRandomString()

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
	hpcClusterPrefix := "cicd-" + utils.GenerateRandomString()

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
	hpcClusterPrefix := "cicd-" + utils.GenerateRandomString()

	// Retrieve cluster information from environment variables
	envVars := GetEnvVars()

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
	hpcClusterPrefix := "cicd-" + utils.GenerateRandomString()

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
