package tests

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/stretchr/testify/require"

	"github.com/gruntwork-io/terratest/modules/terraform"

	"github.com/stretchr/testify/assert"
	lsf "github.com/terraform-ibm-modules/terraform-ibm-hpc/lsf"
	utils "github.com/terraform-ibm-modules/terraform-ibm-hpc/utilities"
)

// Constants for better organization
const (
	createVpcTerraformDir = "examples/create_vpc/solutions/hpc" // Brand new VPC
)

// TestRunBasic validates the cluster configuration.
func TestRunBasic(t *testing.T) {

	// Parallelize the test
	t.Parallel()

	// Set up the test suite and prepare the testing environment
	setupTestSuite(t)

	testLogger.Info(t, "Cluster creation process initiated for "+t.Name())

	// Generate a random prefix for the cluster to ensure uniqueness
	hpcClusterPrefix := utils.GenerateRandomString()

	// Retrieve necessary environment variables for the test
	envVars := GetEnvVars()

	// Set up the test options with the relevant parameters, including environment variables and resource group
	options, err := setupOptions(t, hpcClusterPrefix, terraformDir, envVars.DefaultExistingResourceGroup, ignoreDestroys, ignoreUpdates)
	require.NoError(t, err, "Error setting up test options: %v", err)

	options.SkipTestTearDown = true
	defer options.TestTearDown()

	// Validate that the basic cluster configuration is correct or not
	lsf.ValidateClusterConfiguration(t, options, testLogger)

}

// TestRunCustomRGAsNull validates cluster creation with a null resource group value.
func TestRunCustomRGAsNull(t *testing.T) {
	// Parallelize the test
	t.Parallel()

	// Set up the test suite and prepare the testing environment
	setupTestSuite(t)

	// Log the initiation of the cluster creation process
	testLogger.Info(t, "Cluster creation process initiated for "+t.Name())

	// Generate a random prefix for the cluster to ensure uniqueness
	hpcClusterPrefix := utils.GenerateRandomString()

	// Set up the test options with the relevant parameters, including environment variables and resource group
	options, err := setupOptions(t, hpcClusterPrefix, terraformDir, LSF_CUSTOM_EXISTING_RESOURCE_GROUP_VALUE_AS_NULL, ignoreDestroys, ignoreUpdates)
	require.NoError(t, err, "Error setting up test options: %v", err)

	options.SkipTestTearDown = true
	defer options.TestTearDown()

	// Validate that the basic cluster configuration is correct or not
	lsf.ValidateBasicClusterConfiguration(t, options, testLogger)

}

// TestRunCustomRGAsNonDefault validates cluster creation with a non-default resource group value.
func TestRunCustomRGAsNonDefault(t *testing.T) {
	// Parallelize the test
	t.Parallel()

	// Set up the test suite and prepare the testing environment
	setupTestSuite(t)

	// Log the initiation of the cluster creation process
	testLogger.Info(t, "Cluster creation process initiated for "+t.Name())

	// Generate a random prefix for the cluster to ensure uniqueness
	hpcClusterPrefix := utils.GenerateRandomString()

	// Retrieve necessary environment variables for the test
	envVars := GetEnvVars()

	// Set up the test options with the relevant parameters, including environment variables and resource group
	options, err := setupOptions(t, hpcClusterPrefix, terraformDir, envVars.NonDefaultExistingResourceGroup, ignoreDestroys, ignoreUpdates)
	require.NoError(t, err, "Error setting up test options: %v", err)

	options.SkipTestTearDown = true
	defer options.TestTearDown()

	// Validate that the basic cluster configuration is correct or not
	lsf.ValidateBasicClusterConfiguration(t, options, testLogger)

}

// TestRunAppCenter validates cluster creation with the Application Center.
func TestRunAppCenter(t *testing.T) {
	// Parallelize the test
	t.Parallel()

	// Set up the test suite and prepare the testing environment
	setupTestSuite(t)

	// Generate a random prefix for the cluster to ensure uniqueness
	hpcClusterPrefix := utils.GenerateRandomString()

	// Log the initiation of the cluster creation process
	testLogger.Info(t, "Cluster creation process initiated for "+t.Name())

	// Retrieve necessary environment variables for the test
	envVars := GetEnvVars()

	// Set up the test options with the relevant parameters, including environment variables and resource group
	options, err := setupOptions(t, hpcClusterPrefix, terraformDir, envVars.DefaultExistingResourceGroup, ignoreDestroys, ignoreUpdates)
	require.NoError(t, err, "Error setting up test options: %v", err)
	options.TerraformVars["enable_app_center"] = strings.ToLower(envVars.EnableAppCenter)
	options.TerraformVars["app_center_gui_pwd"] = envVars.AppCenterGuiPassword //pragma: allowlist secret

	options.SkipTestTearDown = true
	defer options.TestTearDown()

	// Validate that the basic cluster configuration is correct or not
	lsf.ValidateClusterConfigurationWithAPPCenter(t, options, testLogger)

}

// TestRunSCC validates cluster creation with the SCC.
func TestRunSCCEnabled(t *testing.T) {
	// Run the test in parallel
	t.Parallel()

	// Set up the test suite
	setupTestSuite(t)

	// Generate a random prefix for the HPC cluster
	hpcClusterPrefix := utils.GenerateRandomString()

	// Log the initiation of the cluster creation process
	testLogger.Info(t, "Cluster creation process initiated for "+t.Name())

	// Retrieve environment variables for cluster configuration
	envVars := GetEnvVars()

	if strings.ToLower(envVars.sccEnabled) == "false" {
		testLogger.Warn(t, fmt.Sprintf("%s will skip execution as the SCC enabled value in the %s_config.yml file is set to true", t.Name(), envVars.sccEnabled))
		return
	}

	// Configure test options
	options, err := setupOptions(t, hpcClusterPrefix, terraformDir, envVars.NonDefaultExistingResourceGroup, ignoreDestroys, ignoreUpdates)
	require.NoError(t, err, "Error setting up test options: %v", err)

	// Enable SCC and set the event notification plan
	options.TerraformVars["scc_enable"] = envVars.sccEnabled
	options.TerraformVars["scc_event_notification_plan"] = envVars.sccEventNotificationPlan
	options.TerraformVars["scc_location"] = envVars.sccLocation
	options.TerraformVars["existing_resource_group"] = envVars.NonDefaultExistingResourceGroup

	// Skip test teardown; defer teardown to the end of the test
	options.SkipTestTearDown = true
	defer options.TestTearDown()

	// Validate the basic cluster configuration with SCC
	lsf.ValidateBasicClusterConfigurationWithSCC(t, options, testLogger)
}

// TestRunPacHa validates the creation and configuration of an cluster with the Application Center
// in high-availability mode, ensuring that all required environment variables and configurations are set.
func TestRunPacHa(t *testing.T) {
	// Parallelize the test
	t.Parallel()

	// Setup the test suite
	setupTestSuite(t)

	// Generate a unique HPC cluster prefix
	hpcClusterPrefix := utils.GenerateRandomString()

	// Retrieve the environment variable for app_center_existing_certificate_instance
	existingCertInstance, ok := os.LookupEnv("APP_CENTER_EXISTING_CERTIFICATE_INSTANCE")
	if !ok {
		t.Fatal("When 'app_center_existing_certificate_instance' is set to true, the environment variable 'APP_CENTER_EXISTING_CERTIFICATE_INSTANCE' must be exported: export APP_CENTER_EXISTING_CERTIFICATE_INSTANCE=value")
	}

	testLogger.Info(t, "Cluster creation process initiated for test: "+t.Name())

	// Retrieve environment variables
	envVars := GetEnvVars()

	// Configure test options
	options, err := setupOptions(t, hpcClusterPrefix, terraformDir, envVars.DefaultExistingResourceGroup, ignoreDestroys, ignoreUpdates)
	require.NoError(t, err, "Error setting up test options: %v", err)

	// Set Terraform variables
	options.TerraformVars["management_node_count"] = 3
	options.TerraformVars["enable_app_center"] = strings.ToLower(envVars.EnableAppCenter)
	options.TerraformVars["app_center_gui_pwd"] = envVars.AppCenterGuiPassword // pragma: allowlist secret
	options.TerraformVars["app_center_high_availability"] = true               // pragma: allowlist secret
	options.TerraformVars["app_center_existing_certificate_instance"] = existingCertInstance

	// Skip teardown if specified
	options.SkipTestTearDown = true
	defer options.TestTearDown()

	// Validate cluster configuration with PACHA
	lsf.ValidateClusterConfigurationWithPACHA(t, options, testLogger)
}

// TestRunNoKMSAndHTOff validates cluster creation with KMS set to null and hyperthreading disabled.
func TestRunNoKMSAndHTOff(t *testing.T) {
	// Parallelize the test
	t.Parallel()

	// Set up the test suite and prepare the testing environment
	setupTestSuite(t)

	// Log the initiation of the cluster creation process
	testLogger.Info(t, "Cluster creation process initiated for "+t.Name())

	// Generate a random prefix for the cluster to ensure uniqueness
	hpcClusterPrefix := utils.GenerateRandomString()

	// Retrieve necessary environment variables for the test
	envVars := GetEnvVars()

	// Set up the test options with the relevant parameters, including environment variables and resource group
	options, err := setupOptions(t, hpcClusterPrefix, terraformDir, envVars.DefaultExistingResourceGroup, ignoreDestroys, ignoreUpdates)
	require.NoError(t, err, "Error setting up test options: %v", err)
	options.TerraformVars["enable_cos_integration"] = false
	options.TerraformVars["enable_vpc_flow_logs"] = false
	options.TerraformVars["key_management"] = "null"
	options.TerraformVars["hyperthreading_enabled"] = strings.ToLower("false")

	options.SkipTestTearDown = true
	defer options.TestTearDown()

	lsf.ValidateBasicClusterConfiguration(t, options, testLogger)
}

// TestRunLSFClusterCreationWithZeroWorkerNodes validates the cluster creation process
// for the LSF solution when the minimum worker node count is set to zero for both static profile counts.
func TestRunLSFClusterCreationWithZeroWorkerNodes(t *testing.T) {
	// Allow the test to run concurrently with others.
	t.Parallel()

	// Set up the test suite environment.
	setupTestSuite(t)
	testLogger.Info(t, "Initiating cluster creation process for "+t.Name())

	// Generate a unique prefix for the HPC cluster.
	hpcClusterPrefix := utils.GenerateRandomString()

	// Retrieve environment variables for the test.
	envVars := GetEnvVars()

	// Validate and apply LSF-specific configurations if the solution is LSF.
	if envVars.Solution == "lsf" {
		// Set up Terraform options.
		options, err := setupOptions(t, hpcClusterPrefix, terraformDir, envVars.DefaultExistingResourceGroup, ignoreDestroys, ignoreUpdates)
		require.NoError(t, err, "Failed to set up Terraform options: %v", err)

		// Configure the lower profile and the minimum worker node count for the cluster.
		options.TerraformVars["worker_node_instance_type"] = []map[string]interface{}{
			{
				"count":         0,
				"instance_type": "bx2-2x8",
			},
			{
				"count":         0,
				"instance_type": "cx2-2x4",
			},
		}
		// Skip automatic teardown for further inspection post-test.
		options.SkipTestTearDown = true
		defer options.TestTearDown()

		//Validate the basic cluster configuration.
		lsf.ValidateBasicClusterConfigurationWithDynamicProfile(t, options, testLogger)
		testLogger.Info(t, "Cluster configuration validation completed successfully.")
	} else {
		testLogger.Warn(t, "Test skipped as the solution is not 'lsf'.")
		t.Skip("This test is applicable only for the 'lsf' solution.")
	}
}

// TestRunInUsEastRegion validates the cluster creation process in the US East region using the b* profile.
func TestRunInUsEastRegion(t *testing.T) {
	// Allow the test to run concurrently with others.
	t.Parallel()

	// Set up the test suite environment.
	setupTestSuite(t)
	testLogger.Info(t, "Starting cluster creation process for test: "+t.Name())

	// Generate a unique prefix for the HPC cluster.
	hpcClusterPrefix := utils.GenerateRandomString()

	// Retrieve and validate environment variables.
	envVars := GetEnvVars()
	usEastZone := utils.SplitAndTrim(envVars.USEastZone, ",")
	require.NotEmpty(t, usEastZone, "Environment variable USEastZone must be provided and contain valid values.")
	testLogger.Info(t, fmt.Sprintf("Validated US East zone configuration: %v", usEastZone))

	// Declare variables for solution-specific configurations.
	var usEastClusterName, usEastReservationID string

	// Apply configurations based on the solution type.
	if envVars.Solution == "HPC" {
		usEastClusterName = envVars.USEastClusterName
		usEastReservationID = envVars.USEastReservationID

		// Validate HPC-specific configurations.
		require.NotEmpty(t, usEastClusterName, "Environment variable USEastClusterName is required for the HPC solution.")
		require.NotEmpty(t, usEastReservationID, "Environment variable USEastReservationID is required for the HPC solution.")
		testLogger.Info(t, fmt.Sprintf("HPC-specific configuration validated for US East: Cluster ID - %s, Reservation ID - %s", usEastClusterName, usEastReservationID))
	}

	// Set up Terraform options.
	options, err := setupOptions(t, hpcClusterPrefix, terraformDir, envVars.DefaultExistingResourceGroup, ignoreDestroys, ignoreUpdates)
	require.NoError(t, err, "Failed to set up Terraform options.")

	// Assign solution-specific Terraform variables.
	switch envVars.Solution {
	case "HPC":
		options.TerraformVars["zones"] = usEastZone
		options.TerraformVars["reservation_id"] = usEastReservationID
		options.TerraformVars["cluster_name"] = usEastClusterName
		testLogger.Info(t, "Terraform variables configured for HPC solution.")
	case "lsf":
		options.TerraformVars["zones"] = usEastZone
		options.TerraformVars["worker_node_instance_type"] = []map[string]interface{}{
			{
				"count":         2,
				"instance_type": "bx2-2x8",
			},
			{
				"count":         0,
				"instance_type": "cx2-2x4",
			},
		}
		testLogger.Info(t, "Terraform variables configured for LSF solution.")
	}

	// Skip automatic teardown for further inspection post-test.
	options.SkipTestTearDown = true
	defer options.TestTearDown()

	// Validate the basic cluster configuration.
	lsf.ValidateBasicClusterConfiguration(t, options, testLogger)
	testLogger.Info(t, "Cluster configuration validation completed successfully.")
}

// TestRunInEuDeRegion validates the cluster creation process in the Frankfurt region using the c* profile.
func TestRunInEuDeRegion(t *testing.T) {
	// Allow the test to run concurrently with others.
	t.Parallel()

	// Set up the test suite environment.
	setupTestSuite(t)
	testLogger.Info(t, "Initiating cluster creation process for test: "+t.Name())

	// Generate a unique prefix for the HPC cluster.
	hpcClusterPrefix := utils.GenerateRandomString()

	// Retrieve and validate environment variables.
	envVars := GetEnvVars()
	euDeZone := utils.SplitAndTrim(envVars.EUDEZone, ",")
	require.NotEmpty(t, euDeZone, "Frankfurt zone configuration must be provided.")
	testLogger.Info(t, fmt.Sprintf("Frankfurt zone configuration validated: %s", euDeZone))

	// Declare variables for solution-specific configurations.
	var euDeClusterName, euDeReservationID string

	// Configure based on the solution type.
	if envVars.Solution == "HPC" {
		euDeClusterName = envVars.EUDEClusterName
		euDeReservationID = envVars.EUDEReservationID

		require.NotEmpty(t, euDeClusterName, "Cluster ID for Frankfurt region must be provided in environment variables.")
		require.NotEmpty(t, euDeReservationID, "Reservation ID for Frankfurt region must be provided in environment variables.")
		testLogger.Info(t, fmt.Sprintf("HPC-specific configuration validated for Frankfurt: Cluster ID - %s, Reservation ID - %s", euDeClusterName, euDeReservationID))
	}

	// Set up Terraform options.
	options, err := setupOptions(t, hpcClusterPrefix, terraformDir, envVars.DefaultExistingResourceGroup, ignoreDestroys, ignoreUpdates)
	require.NoError(t, err, "Failed to set up Terraform options.")

	// Assign solution-specific Terraform variables.
	switch envVars.Solution {
	case "HPC":
		options.TerraformVars["zones"] = euDeZone
		options.TerraformVars["reservation_id"] = euDeReservationID
		options.TerraformVars["cluster_name"] = euDeClusterName
		testLogger.Info(t, "Terraform variables configured for HPC in Frankfurt.")
	case "lsf":
		options.TerraformVars["zones"] = euDeZone
		options.TerraformVars["worker_node_instance_type"] = []map[string]interface{}{
			{
				"count":         2,
				"instance_type": "cx2-2x4",
			},
			{
				"count":         0,
				"instance_type": "bx2-2x8",
			},
		}

		testLogger.Info(t, "Terraform variables configured for LSF in Frankfurt.")
	}

	// Skip automatic teardown for further inspection post-test.
	options.SkipTestTearDown = true
	defer options.TestTearDown()

	// Validate the basic cluster configuration.
	lsf.ValidateBasicClusterConfiguration(t, options, testLogger)
	testLogger.Info(t, "Cluster configuration validation completed successfully.")
}

// TestRunInUSSouthRegion validates the cluster creation process in the US South region using the m* profile.
func TestRunInUSSouthRegion(t *testing.T) {
	// Allow the test to run concurrently with others.
	t.Parallel()

	// Set up the test suite environment.
	setupTestSuite(t)
	testLogger.Info(t, "Initiating cluster creation process for test: "+t.Name())

	// Generate a unique prefix for the HPC cluster.
	hpcClusterPrefix := utils.GenerateRandomString()

	// Retrieve and validate environment variables.
	envVars := GetEnvVars()
	usSouthZone := utils.SplitAndTrim(envVars.USSouthZone, ",")
	require.NotEmpty(t, usSouthZone, "US South zone configuration must be provided.")
	testLogger.Info(t, fmt.Sprintf("US South zone configuration validated: %s", usSouthZone))

	// Declare variables for solution-specific configurations.
	var usSouthClusterName, usSouthReservationID string

	// Configure based on the solution type.
	if envVars.Solution == "HPC" {
		usSouthClusterName = envVars.USSouthClusterName
		usSouthReservationID = envVars.USSouthReservationID

		require.NotEmpty(t, usSouthClusterName, "Cluster ID for US South region must be provided in environment variables.")
		require.NotEmpty(t, usSouthReservationID, "Reservation ID for US South region must be provided in environment variables.")
		testLogger.Info(t, fmt.Sprintf("HPC-specific configuration validated for US South: Cluster ID - %s, Reservation ID - %s", usSouthClusterName, usSouthReservationID))
	}

	// Set up Terraform options.
	options, err := setupOptions(t, hpcClusterPrefix, terraformDir, envVars.DefaultExistingResourceGroup, ignoreDestroys, ignoreUpdates)
	require.NoError(t, err, "Failed to set up Terraform options.")

	// Assign solution-specific Terraform variables.
	switch envVars.Solution {
	case "HPC":
		options.TerraformVars["zones"] = usSouthZone
		options.TerraformVars["reservation_id"] = usSouthReservationID
		options.TerraformVars["cluster_name"] = usSouthClusterName
		testLogger.Info(t, "Terraform variables configured for HPC in US South.")
	case "lsf":
		options.TerraformVars["zones"] = usSouthZone
		options.TerraformVars["worker_node_instance_type"] = []map[string]interface{}{
			{
				"count":         2,
				"instance_type": "mx2-2x16",
			},
			{
				"count":         0,
				"instance_type": "cx2-2x4",
			},
		}
		testLogger.Info(t, "Terraform variables configured for LSF in US South.")
	}

	// Skip automatic teardown for further inspection post-test.
	options.SkipTestTearDown = true
	defer options.TestTearDown()

	// Validate the basic cluster configuration.
	lsf.ValidateBasicClusterConfiguration(t, options, testLogger)
	testLogger.Info(t, "Cluster configuration validation completed successfully.")
}

// TestRunInJPTokyoRegion validates the cluster creation process in the jp tokyo region using the m* profile.
func TestRunInJPTokyoRegion(t *testing.T) {
	// Allow the test to run concurrently with others.
	t.Parallel()

	// Set up the test suite environment.
	setupTestSuite(t)
	testLogger.Info(t, "Initiating cluster creation process for test: "+t.Name())

	// Generate a unique prefix for the HPC cluster.
	hpcClusterPrefix := utils.GenerateRandomString()

	// Retrieve and validate environment variables.
	envVars := GetEnvVars()
	jpTokyoZone := utils.SplitAndTrim(envVars.JPTokZone, ",")
	require.NotEmpty(t, jpTokyoZone, "JP Tokyo zone configuration must be provided.")
	testLogger.Info(t, fmt.Sprintf("JP Tokyo zone configuration validated: %s", jpTokyoZone))

	// Declare variables for solution-specific configurations.
	var jpTokyoClusterName, jpTokyoReservationID string

	// Configure based on the solution type.
	if envVars.Solution == "HPC" {
		jpTokyoClusterName = envVars.JPTokClusterName
		jpTokyoReservationID = envVars.JPTokReservationID

		require.NotEmpty(t, jpTokyoClusterName, "Cluster ID for JP Tokyo region must be provided in environment variables.")
		require.NotEmpty(t, jpTokyoReservationID, "Reservation ID for JP Tokyo  region must be provided in environment variables.")
		testLogger.Info(t, fmt.Sprintf("HPC-specific configuration validated for JP Tokyo : Cluster ID - %s, Reservation ID - %s", jpTokyoClusterName, jpTokyoReservationID))
	}

	// Set up Terraform options.
	options, err := setupOptions(t, hpcClusterPrefix, terraformDir, envVars.DefaultExistingResourceGroup, ignoreDestroys, ignoreUpdates)
	require.NoError(t, err, "Failed to set up Terraform options.")

	// Assign solution-specific Terraform variables.
	switch envVars.Solution {
	case "HPC":
		options.TerraformVars["zones"] = jpTokyoZone
		options.TerraformVars["cluster_name"] = jpTokyoClusterName
		options.TerraformVars["reservation_id"] = jpTokyoReservationID
		testLogger.Info(t, "Terraform variables configured for HPC in JP Tokyo.")
	case "lsf":
		options.TerraformVars["zones"] = jpTokyoZone
		options.TerraformVars["worker_node_instance_type"] = []map[string]interface{}{
			{
				"count":         1,
				"instance_type": "mx3d-128x1280",
			},
			{
				"count":         0,
				"instance_type": "cx3d-24x60",
			},
		}
		testLogger.Info(t, "Terraform variables configured for LSF in JP Tokyo.")
	}

	// Skip automatic teardown for further inspection post-test.
	options.SkipTestTearDown = true
	defer options.TestTearDown()

	// Validate the basic cluster configuration.
	lsf.ValidateBasicClusterConfiguration(t, options, testLogger)
	testLogger.Info(t, "Cluster configuration validation completed successfully.")
}

// TestRunLDAP validates cluster creation with LDAP enabled.
func TestRunLDAP(t *testing.T) {
	// Parallelize the test to run concurrently with others
	t.Parallel()

	// Set up the test suite and prepare the testing environment
	setupTestSuite(t)

	// Log the initiation of the cluster creation process
	testLogger.Info(t, "Cluster creation process initiated for "+t.Name())

	// Generate a random prefix for the cluster to ensure uniqueness
	hpcClusterPrefix := utils.GenerateRandomString()

	// Retrieve necessary environment variables for the test
	envVars := GetEnvVars()

	// Set up the test options with the relevant parameters, including environment variables and resource group, set up test environment
	options, err := setupOptions(t, hpcClusterPrefix, terraformDir, envVars.DefaultExistingResourceGroup, ignoreDestroys, ignoreUpdates)
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

	// Set up the test suite and prepare the testing environment
	setupTestSuite(t)

	// Log the initiation of the cluster creation process
	testLogger.Info(t, "Cluster creation process initiated for "+t.Name())

	// Service instance name
	randomString := utils.GenerateRandomString()
	kmsInstanceName := "cicd-" + randomString

	// Generate a random prefix for the cluster to ensure uniqueness
	hpcClusterPrefix := utils.GenerateRandomString()

	// Retrieve necessary environment variables for the test
	envVars := GetEnvVars()

	// Create service instance and KMS key using IBMCloud CLI
	err := lsf.CreateServiceInstanceAndKmsKey(t, os.Getenv("TF_VAR_ibmcloud_api_key"), utils.GetRegion(envVars.Zone), envVars.DefaultExistingResourceGroup, kmsInstanceName, lsf.KMS_KEY_NAME, testLogger)
	require.NoError(t, err, "Service instance and KMS key creation failed")

	testLogger.Info(t, "Service instance and KMS key created successfully "+t.Name())

	// Set up the test options with the relevant parameters, including environment variables and resource group, set up test environment
	options, err := setupOptions(t, hpcClusterPrefix, terraformDir, envVars.DefaultExistingResourceGroup, ignoreDestroys, ignoreUpdates)
	require.NoError(t, err, "Error setting up test options: %v", err)

	// Set Terraform variables
	options.TerraformVars["key_management"] = "key_protect"
	options.TerraformVars["kms_instance_name"] = kmsInstanceName
	options.TerraformVars["kms_key_name"] = lsf.KMS_KEY_NAME

	// Skip test teardown for further inspection
	options.SkipTestTearDown = true

	// Ensure the service instance and KMS key are deleted after the test
	defer lsf.DeleteServiceInstanceAndAssociatedKeys(t, os.Getenv("TF_VAR_ibmcloud_api_key"), utils.GetRegion(envVars.Zone), envVars.DefaultExistingResourceGroup, kmsInstanceName, testLogger)
	defer options.TestTearDown()

	lsf.ValidateBasicClusterConfiguration(t, options, testLogger)
}

// TestRunUsingExistingKMSInstanceIDAndWithOutKey validates cluster creation using an existing KMS.
func TestRunUsingExistingKMSInstanceIDAndWithoutKey(t *testing.T) {
	// Parallelize the test to run concurrently with others
	t.Parallel()

	// Set up the test suite and prepare the testing environment
	setupTestSuite(t)

	// Log the initiation of the cluster creation process
	testLogger.Info(t, "Cluster creation process initiated for "+t.Name())

	// Service instance name
	randomString := utils.GenerateRandomString()
	kmsInstanceName := "cicd-" + randomString

	// Generate a random prefix for the cluster to ensure uniqueness
	hpcClusterPrefix := utils.GenerateRandomString()

	// Retrieve necessary environment variables for the test
	envVars := GetEnvVars()

	// Create service instance and KMS key using IBMCloud CLI
	err := lsf.CreateServiceInstanceAndKmsKey(t, os.Getenv("TF_VAR_ibmcloud_api_key"), utils.GetRegion(envVars.Zone), envVars.DefaultExistingResourceGroup, kmsInstanceName, lsf.KMS_KEY_NAME, testLogger)
	require.NoError(t, err, "Service instance and KMS key creation failed")

	testLogger.Info(t, "Service instance and KMS key created successfully "+t.Name())

	// Set up the test options with the relevant parameters, including environment variables and resource group, set up test environment
	options, err := setupOptions(t, hpcClusterPrefix, terraformDir, envVars.DefaultExistingResourceGroup, ignoreDestroys, ignoreUpdates)
	require.NoError(t, err, "Error setting up test options: %v", err)

	// Set Terraform variables
	options.TerraformVars["key_management"] = "key_protect"
	options.TerraformVars["kms_instance_name"] = kmsInstanceName

	// Skip test teardown for further inspection
	options.SkipTestTearDown = true

	// Ensure the service instance and KMS key are deleted after the test
	defer lsf.DeleteServiceInstanceAndAssociatedKeys(t, os.Getenv("TF_VAR_ibmcloud_api_key"), utils.GetRegion(envVars.Zone), envVars.DefaultExistingResourceGroup, kmsInstanceName, testLogger)
	defer options.TestTearDown()

	lsf.ValidateBasicClusterConfiguration(t, options, testLogger)
}

// TestRunLDAPAndPac validates cluster creation with both Application Center (PAC) and LDAP enabled.
func TestRunLDAPAndPac(t *testing.T) {
	// Parallelize the test to run concurrently with others
	t.Parallel()

	// Set up the test suite and prepare the testing environment
	setupTestSuite(t)

	// Log the initiation of the cluster creation process
	testLogger.Info(t, "Cluster creation process initiated for "+t.Name())

	// Generate a random prefix for the cluster to ensure uniqueness
	hpcClusterPrefix := utils.GenerateRandomString()

	// Retrieve necessary environment variables for the test
	envVars := GetEnvVars()

	// Set up the test options with the relevant parameters, including environment variables and resource group, set up test environment
	options, err := setupOptions(t, hpcClusterPrefix, terraformDir, envVars.DefaultExistingResourceGroup, ignoreDestroys, ignoreUpdates)
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

	// Set up the test suite and prepare the testing environment
	setupTestSuite(t)

	testLogger.Info(t, "Brand new VPC creation initiated for "+t.Name())

	// Define the HPC cluster prefix
	hpcClusterPrefix := utils.GenerateRandomString()

	// Retrieve necessary environment variables for the test
	envVars := GetEnvVars()

	// Set up the test options with the relevant parameters, including environment variables and resource group, set up test environment
	options, err := setupOptionsVpc(t, hpcClusterPrefix, createVpcTerraformDir, envVars.DefaultExistingResourceGroup)
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

	RunHpcExistingVpcCidr(t, vpcName)
	RunHpcExistingVpcSubnetIdCustomNullDnsNull(t, vpcName, bastionsubnetId, computesubnetIds)
}

// RunHpcExistingVpcCidr with Cidr blocks
func RunHpcExistingVpcCidr(t *testing.T, vpcName string) {
	fmt.Println("********* Started Executing RunHpcExistingVpcCidr ********* ")
	// Set up the test suite and prepare the testing environment
	setupTestSuite(t)

	// Log the initiation of the cluster creation process
	testLogger.Info(t, "Cluster creation process initiated for "+t.Name())

	// Generate a random prefix for the cluster to ensure uniqueness
	hpcClusterPrefix := utils.GenerateRandomString()

	// Static values for CIDR other than default CIDR
	vpcClusterPrivateSubnetsCidrBlocks := "10.241.48.0/21"
	vpcClusterLoginPrivateSubnetsCidrBlocks := "10.241.60.0/22"

	// Retrieve necessary environment variables for the test
	envVars := GetEnvVars()

	// Set up the test options with the relevant parameters, including environment variables and resource group
	options, err := setupOptions(t, hpcClusterPrefix, terraformDir, envVars.DefaultExistingResourceGroup, ignoreDestroys, ignoreUpdates)
	options.TerraformVars["vpc_name"] = vpcName
	options.TerraformVars["vpc_cluster_private_subnets_cidr_blocks"] = utils.SplitAndTrim(vpcClusterPrivateSubnetsCidrBlocks, ",")
	options.TerraformVars["vpc_cluster_login_private_subnets_cidr_blocks"] = utils.SplitAndTrim(vpcClusterLoginPrivateSubnetsCidrBlocks, ",")
	require.NoError(t, err, "Error setting up test options: %v", err)

	// Skip test teardown for further inspection
	options.SkipTestTearDown = true
	defer options.TestTearDown()

	lsf.ValidateClusterConfiguration(t, options, testLogger)
	fmt.Println("********* Ended Executing RunHpcExistingVpcCidr ********* ")
}

// RunHpcExistingVpcSubnetIdCustomNullDnsNull with compute and login subnet id. Both custom_resolver and dns_instace null
func RunHpcExistingVpcSubnetIdCustomNullDnsNull(t *testing.T, vpcName string, bastionsubnetId string, computesubnetIds string) {
	fmt.Println("********* Started Executing RunHpcExistingVpcSubnetIdCustomNullDnsNull ********* ")
	// Set up the test suite and prepare the testing environment
	setupTestSuite(t)

	// Log the initiation of the cluster creation process
	testLogger.Info(t, "Cluster creation process initiated for "+t.Name())

	// Generate a random prefix for the cluster to ensure uniqueness
	hpcClusterPrefix := utils.GenerateRandomString()

	// Retrieve necessary environment variables for the test
	envVars := GetEnvVars()

	// Set up the test options with the relevant parameters, including environment variables and resource group
	options, err := setupOptions(t, hpcClusterPrefix, terraformDir, envVars.DefaultExistingResourceGroup, ignoreDestroys, ignoreUpdates)
	options.TerraformVars["vpc_name"] = vpcName
	options.TerraformVars["login_subnet_id"] = bastionsubnetId
	options.TerraformVars["cluster_subnet_ids"] = utils.SplitAndTrim(computesubnetIds, ",")
	require.NoError(t, err, "Error setting up test options: %v", err)

	// Skip test teardown for further inspection
	options.SkipTestTearDown = true
	defer options.TestTearDown()

	lsf.ValidateClusterConfiguration(t, options, testLogger)
	fmt.Println("********* Ended Executing RunHpcExistingVpcSubnetIdCustomNullDnsNull ********* ")
}

// TestRunCreateVpcWithCustomDns brand new VPC with DNS
func TestRunVpcWithCustomDns(t *testing.T) {
	// Parallelize the test to run concurrently with others
	t.Parallel()

	// Set up the test suite and prepare the testing environment
	setupTestSuite(t)

	// Log the initiation of the cluster creation process
	testLogger.Info(t, "Cluster creation process initiated for "+t.Name())

	// Define the HPC cluster prefix
	hpcClusterPrefix := utils.GenerateRandomString()

	// Retrieve necessary environment variables for the test
	envVars := GetEnvVars()

	// Set up the test options with the relevant parameters, including environment variables and resource group, set up test environment
	options, err := setupOptionsVpc(t, hpcClusterPrefix, createVpcTerraformDir, envVars.DefaultExistingResourceGroup)
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

	RunHpcExistingVpcBothCustomDnsExist(t, vpcName, bastionsubnetId, computesubnetIds, instanceId, customResolverId)
	RunHpcExistingVpcCustomExistDnsNull(t, vpcName, bastionsubnetId, computesubnetIds, customResolverId)
	RunHpcExistingVpcCustomNullDnsExist(t, instanceId)
}

// RunHpcExistingVpcCustomDns with existing custom_resolver_id and dns_instance_id
func RunHpcExistingVpcBothCustomDnsExist(t *testing.T, vpcName string, bastionsubnetId string, computesubnetIds string, instanceId string, customResolverId string) {
	fmt.Println("********* Started Executing RunHpcExistingVpcBothCustomDnsExist ********* ")
	// Set up the test suite and prepare the testing environment
	setupTestSuite(t)

	// Log the initiation of the cluster creation process
	testLogger.Info(t, "Cluster creation process initiated for "+t.Name())

	// Generate a random prefix for the cluster to ensure uniqueness
	hpcClusterPrefix := utils.GenerateRandomString()

	// Retrieve necessary environment variables for the test
	envVars := GetEnvVars()

	// Set up the test options with the relevant parameters, including environment variables and resource group
	options, err := setupOptions(t, hpcClusterPrefix, terraformDir, envVars.DefaultExistingResourceGroup, ignoreDestroys, ignoreUpdates)
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
	fmt.Println("********* Ended Executing RunHpcExistingVpcBothCustomDnsExist ********* ")
}

// RunHpcExistingVpcCustomExistDnsNull with existing custom_resolver_id and new dns_instance_id
func RunHpcExistingVpcCustomExistDnsNull(t *testing.T, vpcName string, bastionsubnetId string, computesubnetIds string, customResolverId string) {
	fmt.Println("********* Started Executing RunHpcExistingVpcCustomExistDnsNull ********* ")
	// Set up the test suite and prepare the testing environment
	setupTestSuite(t)

	// Log the initiation of the cluster creation process
	testLogger.Info(t, "Cluster creation process initiated for "+t.Name())

	// Generate a random prefix for the cluster to ensure uniqueness
	hpcClusterPrefix := utils.GenerateRandomString()

	// Retrieve necessary environment variables for the test
	envVars := GetEnvVars()

	// Set up the test options with the relevant parameters, including environment variables and resource group
	options, err := setupOptions(t, hpcClusterPrefix, terraformDir, envVars.DefaultExistingResourceGroup, ignoreDestroys, ignoreUpdates)
	options.TerraformVars["vpc_name"] = vpcName
	options.TerraformVars["login_subnet_id"] = bastionsubnetId
	options.TerraformVars["cluster_subnet_ids"] = utils.SplitAndTrim(computesubnetIds, ",")
	options.TerraformVars["dns_custom_resolver_id"] = customResolverId

	require.NoError(t, err, "Error setting up test options: %v", err)

	// Skip test teardown for further inspection
	options.SkipTestTearDown = true
	defer options.TestTearDown()

	lsf.ValidateClusterConfiguration(t, options, testLogger)
	fmt.Println("********* Ended Executing RunHpcExistingVpcCustomExistDnsNull ********* ")
}

// RunHpcExistingVpcCustomNullDnsExist with custom_resolver_id null and existing dns_instance_id
func RunHpcExistingVpcCustomNullDnsExist(t *testing.T, instanceId string) {
	fmt.Println("********* Started Executing RunHpcExistingVpcCustomNullDnsExist ********* ")
	// Set up the test suite and prepare the testing environment
	setupTestSuite(t)

	// Log the initiation of the cluster creation process
	testLogger.Info(t, "Cluster creation process initiated for "+t.Name())

	// Generate a random prefix for the cluster to ensure uniqueness
	hpcClusterPrefix := utils.GenerateRandomString()

	// Retrieve necessary environment variables for the test
	envVars := GetEnvVars()

	// Set up the test options with the relevant parameters, including environment variables and resource group
	options, err := setupOptions(t, hpcClusterPrefix, terraformDir, envVars.DefaultExistingResourceGroup, ignoreDestroys, ignoreUpdates)
	options.TerraformVars["dns_instance_id"] = instanceId

	require.NoError(t, err, "Error setting up test options: %v", err)

	// Skip test teardown for further inspection
	options.SkipTestTearDown = true
	defer options.TestTearDown()

	lsf.ValidateClusterConfiguration(t, options, testLogger)
	fmt.Println("********* Ended Executing RunHpcExistingVpcCustomNullDnsExist ********* ")
}

func TestRunCIDRsAsNonDefault(t *testing.T) {
	// Parallelize the test
	t.Parallel()

	// Set up the test suite and prepare the testing environment
	setupTestSuite(t)

	// Log the initiation of the cluster creation process
	testLogger.Info(t, "Cluster creation process initiated for "+t.Name())

	// Generate a random prefix for the cluster to ensure uniqueness
	hpcClusterPrefix := utils.GenerateRandomString()

	// Retrieve necessary environment variables for the test
	envVars := GetEnvVars()

	// Set up the test options with the relevant parameters, including environment variables and resource group
	options, err := setupOptions(t, hpcClusterPrefix, terraformDir, envVars.DefaultExistingResourceGroup, ignoreDestroys, ignoreUpdates)
	require.NoError(t, err, "Error setting up test options: %v", err)

	options.TerraformVars["vpc_cidr"] = "10.243.0.0/18"
	options.TerraformVars["vpc_cluster_private_subnets_cidr_blocks"] = []string{"10.243.0.0/20"}
	options.TerraformVars["vpc_cluster_login_private_subnets_cidr_blocks"] = []string{"10.243.16.0/28"}

	options.SkipTestTearDown = true
	defer options.TestTearDown()

	lsf.ValidateBasicClusterConfiguration(t, options, testLogger)
}

// TestRunCosAndVpcFlowLogs validates cluster creation with vpc flow logs and cos enabled.
func TestRunCosAndVpcFlowLogs(t *testing.T) {
	// Parallelize the test to run concurrently with others
	t.Parallel()

	// Set up the test suite and prepare the testing environment
	setupTestSuite(t)

	// Log the initiation of the cluster creation process
	testLogger.Info(t, "Cluster creation process initiated for "+t.Name())

	// Generate a random prefix for the cluster to ensure uniqueness
	hpcClusterPrefix := utils.GenerateRandomString()

	// Retrieve necessary environment variables for the test
	envVars := GetEnvVars()

	// Set up the test options with the relevant parameters, including environment variables and resource group, set up test environment
	options, err := setupOptions(t, hpcClusterPrefix, terraformDir, envVars.DefaultExistingResourceGroup, ignoreDestroys, ignoreUpdates)
	require.NoError(t, err, "Error setting up test options: %v", err)

	// Set Terraform variables
	options.TerraformVars["enable_cos_integration"] = true
	options.TerraformVars["enable_vpc_flow_logs"] = true

	// Skip test teardown for further inspection
	options.SkipTestTearDown = true
	defer options.TestTearDown()

	lsf.ValidateBasicClusterConfigurationWithVPCFlowLogsAndCos(t, options, testLogger)
}

// TestRunMultipleSSHKeys validates the cluster configuration.
func TestRunMultipleSSHKeys(t *testing.T) {

	// Parallelize the test
	t.Parallel()

	// Set up the test suite and prepare the testing environment
	setupTestSuite(t)

	// Log the initiation of the cluster creation process
	testLogger.Info(t, "Cluster creation process initiated for "+t.Name())

	// Generate a random prefix for the cluster to ensure uniqueness
	hpcClusterPrefix := utils.GenerateRandomString()

	// Retrieve necessary environment variables for the test
	envVars := GetEnvVars()

	// Set up the test options with the relevant parameters, including environment variables and resource group
	options, err := setupOptions(t, hpcClusterPrefix, terraformDir, envVars.DefaultExistingResourceGroup, ignoreDestroys, ignoreUpdates)
	require.NoError(t, err, "Error setting up test options: %v", err)

	options.SkipTestTearDown = true
	defer options.TestTearDown()

	lsf.ValidateClusterConfigurationWithMultipleKeys(t, options, testLogger)

}

// TestRunExistingLDAP validates the creation and configuration of HPC clusters with LDAP integration, including setup, validation, and error handling for both clusters.
func TestRunExistingLDAP(t *testing.T) {
	// Parallelize the test to run concurrently with others
	t.Parallel()

	// Setup the test suite
	setupTestSuite(t)

	// Log the initiation of the cluster creation process
	testLogger.Info(t, "Cluster creation process initiated for "+t.Name())

	// Generate random prefix for HPC cluster
	hpcClusterPrefix := utils.GenerateRandomString()

	// Retrieve environment variables
	envVars := GetEnvVars()

	// Ensure LDAP is enabled and credentials are provided
	if strings.ToLower(envVars.EnableLdap) == "true" {
		if len(envVars.LdapAdminPassword) == 0 || len(envVars.LdapUserName) == 0 || len(envVars.LdapUserPassword) == 0 {
			require.FailNow(t, "LDAP credentials are missing. Ensure LDAP admin password, LDAP user name, and LDAP user password are provided.")
		}
	} else {
		require.FailNow(t, "LDAP is not enabled. Set the 'enable_ldap' environment variable to 'true' to enable LDAP.")
	}

	// Set up the test options with the relevant parameters, including environment variables and resource group for the first cluster
	options1, err := setupOptions(t, hpcClusterPrefix, terraformDir, envVars.DefaultExistingResourceGroup, ignoreDestroys, ignoreUpdates)
	require.NoError(t, err, "Error setting up test options for the first cluster: %v", err)

	// Set Terraform variables for the first cluster
	options1.TerraformVars["management_node_count"] = 1
	options1.TerraformVars["enable_ldap"] = strings.ToLower(envVars.EnableLdap)
	options1.TerraformVars["ldap_basedns"] = envVars.LdapBaseDns
	options1.TerraformVars["ldap_admin_password"] = envVars.LdapAdminPassword // pragma: allowlist secret
	options1.TerraformVars["ldap_user_name"] = envVars.LdapUserName
	options1.TerraformVars["ldap_user_password"] = envVars.LdapUserPassword // pragma: allowlist secret
	options1.TerraformVars["key_management"] = "null"
	options1.TerraformVars["enable_cos_integration"] = false
	options1.TerraformVars["enable_vpc_flow_logs"] = false

	// Skip test teardown for further inspection
	options1.SkipTestTearDown = true
	defer options1.TestTearDown()

	// Run the test and validate output
	output, err := options1.RunTest()
	require.NoError(t, err, "Error running test: %v", err)
	require.NotNil(t, output, "Expected non-nil output, but got nil")

	// Retrieve custom resolver ID
	customResolverID, err := utils.GetCustomResolverID(t, os.Getenv("TF_VAR_ibmcloud_api_key"), utils.GetRegion(envVars.Zone), envVars.DefaultExistingResourceGroup, hpcClusterPrefix, testLogger)
	require.NoError(t, err, "Error retrieving custom resolver ID: %v", err)

	// Retrieve LDAP IP and Bastion IP
	ldapIP, err := utils.GetLdapIP(t, options1, testLogger)
	require.NoError(t, err, "Error retrieving LDAP IP address: %v", err)

	ldapServerBastionIP, err := utils.GetBastionIP(t, options1, testLogger)
	require.NoError(t, err, "Error retrieving LDAP server bastion IP address: %v", err)

	// Update security group for LDAP
	err = utils.RetrieveAndUpdateSecurityGroup(t, os.Getenv("TF_VAR_ibmcloud_api_key"), utils.GetRegion(envVars.Zone), envVars.DefaultExistingResourceGroup, hpcClusterPrefix, "10.241.0.0/18", "389", "389", testLogger)
	require.NoError(t, err, "Error updating security group: %v", err)

	testLogger.Info(t, "Cluster creation process for the second cluster initiated for "+t.Name())

	// Generate random prefix for the second HPC cluster
	hpcClusterPrefix2 := utils.GenerateRandomString()

	// Retrieve LDAP server certificate via SSH and assert no connection errors.
	ldapServerCert, serverCertErr := lsf.GetLDAPServerCert(lsf.LSF_PUBLIC_HOST_NAME, ldapServerBastionIP, lsf.LSF_LDAP_HOST_NAME, ldapIP)
	require.NoError(t, serverCertErr, "Failed to retrieve LDAP server certificate via SSH")

	testLogger.Info(t, ldapServerCert)

	// Set up the test options with the relevant parameters, including environment variables and resource group for the second cluster
	options2, err := setupOptions(t, hpcClusterPrefix2, terraformDir, envVars.DefaultExistingResourceGroup, ignoreDestroys, ignoreUpdates)
	require.NoError(t, err, "Error setting up test options for the second cluster: %v", err)

	// Set Terraform variables for the second cluster
	options2.TerraformVars["vpc_name"] = options1.TerraformVars["cluster_prefix"].(string) + "-lsf-vpc"
	options2.TerraformVars["vpc_cluster_private_subnets_cidr_blocks"] = []string{CLUSTER_TWO_VPC_CLUSTER_PRIVATE_SUBNETS_CIDR_BLOCKS}
	options2.TerraformVars["vpc_cluster_login_private_subnets_cidr_blocks"] = []string{CLUSTER_TWO_VPC_CLUSTER_LOGIN_PRIVATE_SUBNETS_CIDR_BLOCKS}
	options2.TerraformVars["management_node_count"] = 2
	options2.TerraformVars["dns_domain_name"] = map[string]string{"compute": CLUSTER_TWO_DNS_DOMAIN_NAME}
	options2.TerraformVars["dns_custom_resolver_id"] = customResolverID
	options2.TerraformVars["enable_ldap"] = strings.ToLower(envVars.EnableLdap)
	options2.TerraformVars["ldap_basedns"] = envVars.LdapBaseDns
	options2.TerraformVars["ldap_server"] = ldapIP
	options2.TerraformVars["ldap_server_cert"] = strings.TrimSpace(ldapServerCert)

	// Skip test teardown for further inspection
	options2.SkipTestTearDown = true
	defer options2.TestTearDown()

	// Validate LDAP configuration for the second cluster
	lsf.ValidateExistingLDAPClusterConfig(t, ldapServerBastionIP, ldapIP, envVars.LdapBaseDns, envVars.LdapAdminPassword, envVars.LdapUserName, envVars.LdapUserPassword, options2, testLogger)
}

// TestRunLSFLogs validates the cluster creation process, focusing on the following:
// Ensures cloud logs are correctly validated.
// Verifies that LSF management logs are stored in the designated directory within the shared folder.
// Checks for the presence of symbolic links to the logs.
// Confirms the cluster setup passes basic configuration and validation checks.
// Prerequisites:
// - The cluster should have at least two management nodes.
func TestRunLSFLogs(t *testing.T) {
	// Parallelize the test to run concurrently with others
	t.Parallel()

	// Set up the test suite and prepare the testing environment
	setupTestSuite(t)

	// Log the initiation of the cluster creation process
	testLogger.Info(t, "Cluster creation process initiated for "+t.Name())

	// Generate a random prefix for the cluster to ensure uniqueness
	hpcClusterPrefix := utils.GenerateRandomString()

	// Retrieve necessary environment variables for the test
	envVars := GetEnvVars()

	// Set up the test options with the relevant parameters, including environment variables and resource group, set up test environment
	options, err := setupOptions(t, hpcClusterPrefix, terraformDir, envVars.DefaultExistingResourceGroup, ignoreDestroys, ignoreUpdates)
	require.NoError(t, err, "Error setting up test options: %v", err)

	// Prevent automatic test teardown to allow for further inspection, if needed.
	options.SkipTestTearDown = true
	defer options.TestTearDown()

	// Validate the basic cluster configuration and LSF management logs.
	lsf.ValidateBasicClusterConfigurationLSFLogs(t, options, testLogger)
}

// TestRunDedicatedHost validates cluster creation
func TestRunDedicatedHost(t *testing.T) {
	// Parallelize the test
	t.Parallel()

	// Set up the test suite and prepare the testing environment
	setupTestSuite(t)

	// Generate a random prefix for the cluster to ensure uniqueness
	hpcClusterPrefix := utils.GenerateRandomString()

	// Log the initiation of the cluster creation process
	testLogger.Info(t, "Cluster creation process initiated for "+t.Name())

	// Retrieve necessary environment variables for the test
	envVars := GetEnvVars()

	// Set up the test options with the relevant parameters, including environment variables and resource group
	options, err := setupOptions(t, hpcClusterPrefix, terraformDir, envVars.DefaultExistingResourceGroup, ignoreDestroys, ignoreUpdates)
	require.NoError(t, err, "Error setting up test options: %v", err)
	options.TerraformVars["enable_dedicated_host"] = true
	options.TerraformVars["worker_node_instance_type"] = []map[string]interface{}{
		{
			"count":         1,
			"instance_type": "bx2-2x8",
		},
	}

	options.SkipTestTearDown = true
	defer options.TestTearDown()

	lsf.ValidateBasicClusterConfigurationWithDedicatedHost(t, options, true, testLogger)

}

// TestRunObservabilityCloudLogsManagementAndComputeEnabled validates the creation of a cluster
// with observability features enabled for both management and compute nodes. The test ensures that the
// cluster setup passes basic validation checks, confirming that the observability features for both management
// and compute are properly configured and functional, while platform logs and monitoring are disabled.
func TestRunObservabilityCloudLogsManagementAndComputeEnabled(t *testing.T) {
	// Run the test in parallel with other tests to optimize test execution
	t.Parallel()

	// Set up the test suite and environment configuration
	setupTestSuite(t)

	// Log the initiation of the cluster creation process
	testLogger.Info(t, "Cluster creation process initiated for "+t.Name())

	// Generate a random prefix for the cluster to ensure uniqueness
	hpcClusterPrefix := utils.GenerateRandomString()

	// Retrieve necessary environment variables to configure the test
	envVars := GetEnvVars()

	// Set up test options with relevant parameters, including resource group and environment variables
	options, err := setupOptions(t, hpcClusterPrefix, terraformDir, envVars.DefaultExistingResourceGroup, ignoreDestroys, ignoreUpdates)
	require.NoError(t, err, "Error setting up test options: %v", err)

	// Configure the observability settings for management and compute logs, with platform logs and monitoring disabled
	options.TerraformVars["observability_logs_enable_for_management"] = true
	options.TerraformVars["observability_logs_enable_for_compute"] = true
	options.TerraformVars["observability_enable_platform_logs"] = false
	options.TerraformVars["observability_monitoring_enable"] = false

	// Prevent automatic test teardown for inspection after the test runs
	options.SkipTestTearDown = true

	// Ensure test teardown is executed at the end of the test
	defer options.TestTearDown()

	// Validate that the basic cluster configuration is correct with cloud logs enabled for management and compute nodes
	lsf.ValidateBasicClusterConfigurationWithCloudLogs(t, options, testLogger)
}

// TestRunObservabilityCloudLogsManagementEnabled validates the creation of a cluster
// with observability features enabled only for management nodes. This test ensures:
// Management node logs are properly configured while compute node logs are disabled.
// Platform logs are enabled for platform-level observability.
// Monitoring features are explicitly disabled.
// The cluster setup passes basic validation checks.

func TestRunObservabilityCloudLogsManagementEnabled(t *testing.T) {
	// Run the test in parallel for efficiency
	t.Parallel()

	// Set up the test suite and initialize the environment
	setupTestSuite(t)

	// Log the initiation of the cluster creation process
	testLogger.Info(t, fmt.Sprintf("Cluster creation process initiated for test: %s", t.Name()))

	// Generate a unique cluster prefix for the test
	clusterPrefix := utils.GenerateRandomString()

	// Retrieve environment variables required for configuration
	envVars := GetEnvVars()

	// Configure test options with Terraform variables and environment settings
	options, err := setupOptions(t, clusterPrefix, terraformDir, envVars.DefaultExistingResourceGroup, ignoreDestroys, ignoreUpdates)
	require.NoError(t, err, "Failed to set up test options: %v", err)

	// Configure observability settings:
	options.TerraformVars["observability_logs_enable_for_management"] = true
	options.TerraformVars["observability_logs_enable_for_compute"] = false
	options.TerraformVars["observability_monitoring_enable"] = false

	// Check if platform logs already exist for the given region and resource group
	platformLogsExist, err := lsf.CheckPlatformLogsPresent(t, os.Getenv("TF_VAR_ibmcloud_api_key"), utils.GetRegion(envVars.Zone), envVars.DefaultExistingResourceGroup, testLogger)
	require.NoError(t, err, "Error checking platform logs for cluster: %v", err)

	// Set platform logs configuration based on their existence in the region
	if platformLogsExist {
		options.TerraformVars["observability_enable_platform_logs"] = false // Reuse existing platform logs
	} else {
		options.TerraformVars["observability_enable_platform_logs"] = true // Enable platform logs
	}

	testLogger.Info(t, fmt.Sprintf("%v", platformLogsExist))
	// Skip automatic test teardown to allow for manual inspection after the test
	options.SkipTestTearDown = true

	// Ensure teardown is executed at the end of the test
	defer options.TestTearDown()

	// Validate the basic cluster configuration with the specified observability settings
	lsf.ValidateBasicClusterConfigurationWithCloudLogs(t, options, testLogger)
}

// TestRunObservabilityCloudLogsManagementAndComputeDisabled validates the creation of a cluster
// with observability features disabled for both management and compute nodes. This test ensures:
// Both management and compute logs are disabled.
// Monitoring features are explicitly disabled.
// The cluster setup passes basic validation checks.
func TestRunObservabilityCloudLogsManagementAndComputeDisabled(t *testing.T) {
	// Run the test in parallel for efficiency
	t.Parallel()

	// Set up the test suite and initialize the environment
	setupTestSuite(t)

	// Log the initiation of the cluster creation process
	testLogger.Info(t, fmt.Sprintf("Cluster creation process initiated for test: %s", t.Name()))

	// Generate a unique cluster prefix for the test
	clusterPrefix := utils.GenerateRandomString()

	// Retrieve environment variables required for configuration
	envVars := GetEnvVars()

	// Configure test options with Terraform variables and environment settings
	options, err := setupOptions(t, clusterPrefix, terraformDir, envVars.DefaultExistingResourceGroup, ignoreDestroys, ignoreUpdates)
	require.NoErrorf(t, err, "Failed to set up test options: %v", err)

	// Ensure options is initialized before teardown
	if options == nil {
		t.Fatalf("Test options initialization failed, cannot proceed.")
	}

	// Defer teardown to ensure cleanup, with a nil check for safety
	defer func() {
		if options != nil {
			options.TestTearDown()
		}
	}()

	// Configure observability settings:
	options.TerraformVars["observability_logs_enable_for_management"] = false // Management logs disabled
	options.TerraformVars["observability_logs_enable_for_compute"] = false    // Compute logs disabled
	options.TerraformVars["observability_monitoring_enable"] = false          // Monitoring disabled
	options.TerraformVars["observability_enable_platform_logs"] = false       // Platform logs disabled

	// Skip automatic test teardown to allow for manual inspection after the test
	options.SkipTestTearDown = true

	// Validate the basic cluster configuration with the specified observability settings
	lsf.ValidateBasicClusterConfigurationWithCloudLogs(t, options, testLogger)
}

// TestRunObservabilityMonitoringForManagementAndComputeEnabled validates the creation of a cluster
// with observability features enabled for both management and compute nodes. The test ensures that the
// cluster setup passes basic validation checks, confirming that the observability features for both management
// and compute are properly configured and functional, while platform logs and monitoring are disabled.
func TestRunObservabilityMonitoringForManagementAndComputeEnabled(t *testing.T) {
	// Run the test in parallel with other tests to optimize test execution
	t.Parallel()

	// Set up the test suite and environment configuration
	setupTestSuite(t)

	// Log the initiation of the cluster creation process
	testLogger.Info(t, "Cluster creation process initiated for "+t.Name())

	// Generate a random prefix for the cluster to ensure uniqueness
	hpcClusterPrefix := utils.GenerateRandomString()

	// Retrieve necessary environment variables to configure the test
	envVars := GetEnvVars()

	// Set up test options with relevant parameters, including resource group and environment variables
	options, err := setupOptions(t, hpcClusterPrefix, terraformDir, envVars.DefaultExistingResourceGroup, ignoreDestroys, ignoreUpdates)
	require.NoError(t, err, "Error setting up test options: %v", err)

	// Configure the observability settings for management and compute logs,
	options.TerraformVars["observability_logs_enable_for_management"] = false
	options.TerraformVars["observability_monitoring_enable"] = true
	options.TerraformVars["observability_monitoring_on_compute_nodes_enable"] = true
	options.TerraformVars["observability_monitoring_plan"] = "graduated-tier"

	// Prevent automatic test teardown for inspection after the test runs
	options.SkipTestTearDown = true

	// Ensure test teardown is executed at the end of the test
	defer options.TestTearDown()

	// Validate that the basic cluster configuration is correct with cloud monitoring enabled for management and compute nodes
	lsf.ValidateBasicClusterConfigurationWithCloudMonitoring(t, options, testLogger)
}

// TestRunObservabilityMonitoringForManagementEnabledAndComputeDisabled validates the creation of a cluster
// with observability features enabled for management nodes and disabled for compute nodes. The test ensures that the
// cluster setup passes basic validation checks, confirming that the observability features for  management
// and compute are properly configured and functional, while platform logs and monitoring are disabled.
func TestRunObservabilityMonitoringForManagementEnabledAndComputeDisabled(t *testing.T) {
	// Run the test in parallel with other tests to optimize test execution
	t.Parallel()

	// Set up the test suite and environment configuration
	setupTestSuite(t)

	// Log the initiation of the cluster creation process
	testLogger.Info(t, "Cluster creation process initiated for "+t.Name())

	// Generate a random prefix for the cluster to ensure uniqueness
	hpcClusterPrefix := utils.GenerateRandomString()

	// Retrieve necessary environment variables to configure the test
	envVars := GetEnvVars()

	// Set up test options with relevant parameters, including resource group and environment variables
	options, err := setupOptions(t, hpcClusterPrefix, terraformDir, envVars.DefaultExistingResourceGroup, ignoreDestroys, ignoreUpdates)
	require.NoError(t, err, "Error setting up test options: %v", err)

	// Configure the observability settings for management and compute logs,
	options.TerraformVars["observability_logs_enable_for_management"] = false
	options.TerraformVars["observability_monitoring_enable"] = true
	options.TerraformVars["observability_monitoring_on_compute_nodes_enable"] = false
	options.TerraformVars["observability_monitoring_plan"] = "graduated-tier"

	// Prevent automatic test teardown for inspection after the test runs
	options.SkipTestTearDown = true

	// Ensure test teardown is executed at the end of the test
	defer options.TestTearDown()

	// Validate that the basic cluster configuration is correct with cloud monitoring enabled for management nodes and disabled for compute nodes
	lsf.ValidateBasicClusterConfigurationWithCloudMonitoring(t, options, testLogger)
}

// TestRunObservabilityMonitoringForManagementAndComputeDisabled validates the creation of a cluster
// with observability features enabled for both management and compute nodes. The test ensures that the
// cluster setup passes basic validation checks, confirming that the observability features for both management
// and compute are properly configured and functional, while platform logs and monitoring are disabled.
func TestRunObservabilityMonitoringForManagementAndComputeDisabled(t *testing.T) {
	// Run the test in parallel with other tests to optimize test execution
	t.Parallel()

	// Set up the test suite and environment configuration
	setupTestSuite(t)

	// Log the initiation of the cluster creation process
	testLogger.Info(t, "Cluster creation process initiated for "+t.Name())

	// Generate a random prefix for the cluster to ensure uniqueness
	hpcClusterPrefix := utils.GenerateRandomString()

	// Retrieve necessary environment variables to configure the test
	envVars := GetEnvVars()

	// Set up test options with relevant parameters, including resource group and environment variables
	options, err := setupOptions(t, hpcClusterPrefix, terraformDir, envVars.DefaultExistingResourceGroup, ignoreDestroys, ignoreUpdates)
	require.NoError(t, err, "Error setting up test options: %v", err)

	// Configure the observability settings for management and compute logs,
	options.TerraformVars["observability_logs_enable_for_management"] = false
	options.TerraformVars["observability_monitoring_enable"] = true
	options.TerraformVars["observability_monitoring_on_compute_nodes_enable"] = false
	options.TerraformVars["observability_monitoring_plan"] = "graduated-tier"

	// Prevent automatic test teardown for inspection after the test runs
	options.SkipTestTearDown = true

	// Ensure test teardown is executed at the end of the test
	defer options.TestTearDown()

	// Validate that the basic cluster configuration is correct with cloud monitoring disabled for management and compute nodes
	lsf.ValidateBasicClusterConfigurationWithCloudMonitoring(t, options, testLogger)
}

// TestRunobservabilityAtrackerEnabledAndTargetTypeAsCloudlogs validates cluster creation
// with Observability Atracker enabled and the target type set to Cloud Logs.
func TestRunobservabilityAtrackerEnabledAndTargetTypeAsCloudlogs(t *testing.T) {
	// Execute the test in parallel to improve efficiency
	t.Parallel()

	// Initialize the test suite and set up the environment
	setupTestSuite(t)

	// Log the initiation of the cluster creation process
	testLogger.Info(t, "Cluster creation process initiated for "+t.Name())

	// Generate a random prefix for the cluster to ensure uniqueness
	hpcClusterPrefix := utils.GenerateRandomString()

	// Retrieve environment variables required for configuration
	envVars := GetEnvVars()

	// Configure test options, including resource group and environment variables
	options, err := setupOptions(t, hpcClusterPrefix, terraformDir, envVars.DefaultExistingResourceGroup, ignoreDestroys, ignoreUpdates)
	require.NoError(t, err, "Error setting up test options: %v", err)

	// Set observability configurations for logs and monitoring
	options.TerraformVars["observability_logs_enable_for_management"] = false
	options.TerraformVars["observability_monitoring_enable"] = false
	options.TerraformVars["observability_monitoring_on_compute_nodes_enable"] = false
	options.TerraformVars["observability_atracker_enable"] = true
	options.TerraformVars["observability_atracker_target_type"] = "cloudlogs"

	// Prevent test teardown for post-test inspection
	options.SkipTestTearDown = true

	// Ensure proper cleanup after test execution
	defer options.TestTearDown()

	// Validate the cluster setup with Atracker enabled and target type as cloudlogs
	lsf.ValidateBasicClusterConfigurationWithCloudAtracker(t, options, testLogger)
}

// TestRunobservabilityAtrackerEnabledAndTargetTypeAsCos validates cluster creation
// with Observability Atracker enabled and the target type set to COS.
func TestRunobservabilityAtrackerEnabledAndTargetTypeAsCos(t *testing.T) {
	// Execute the test in parallel to improve efficiency
	t.Parallel()

	// Initialize the test suite and set up the environment
	setupTestSuite(t)

	// Log the initiation of the cluster creation process
	testLogger.Info(t, "Cluster creation process initiated for "+t.Name())

	// Generate a random prefix for the cluster to ensure uniqueness
	hpcClusterPrefix := utils.GenerateRandomString()

	// Retrieve environment variables required for configuration
	envVars := GetEnvVars()

	// Configure test options, including resource group and environment variables
	options, err := setupOptions(t, hpcClusterPrefix, terraformDir, envVars.DefaultExistingResourceGroup, ignoreDestroys, ignoreUpdates)
	require.NoError(t, err, "Error setting up test options: %v", err)

	// Set observability configurations for logs and monitoring
	options.TerraformVars["observability_logs_enable_for_management"] = false
	options.TerraformVars["observability_monitoring_enable"] = false
	options.TerraformVars["observability_monitoring_on_compute_nodes_enable"] = false
	options.TerraformVars["observability_atracker_enable"] = true
	options.TerraformVars["observability_atracker_target_type"] = "cos"

	// Prevent test teardown for post-test inspection
	options.SkipTestTearDown = true

	// Ensure proper cleanup after test execution
	defer options.TestTearDown()

	// Validate the cluster setup with Atracker enabled and target type as cos
	lsf.ValidateBasicClusterConfigurationWithCloudAtracker(t, options, testLogger)
}

// TestRunobservabilityAtrackerDisabledAndTargetTypeAsCos validates cluster creation
// with Observability Atracker disabled and the target type set to COS.
func TestRunobservabilityAtrackerDisabledAndTargetTypeAsCos(t *testing.T) {
	// Execute the test in parallel to improve efficiency
	t.Parallel()

	// Initialize the test suite and set up the environment
	setupTestSuite(t)

	// Log the initiation of the cluster creation process
	testLogger.Info(t, "Cluster creation process initiated for "+t.Name())

	// Generate a random prefix for the cluster to ensure uniqueness
	hpcClusterPrefix := utils.GenerateRandomString()

	// Retrieve environment variables required for configuration
	envVars := GetEnvVars()

	// Configure test options, including resource group and environment variables
	options, err := setupOptions(t, hpcClusterPrefix, terraformDir, envVars.DefaultExistingResourceGroup, ignoreDestroys, ignoreUpdates)
	require.NoError(t, err, "Error setting up test options: %v", err)

	// Set observability configurations for logs and monitoring
	options.TerraformVars["observability_logs_enable_for_management"] = false
	options.TerraformVars["observability_monitoring_enable"] = false
	options.TerraformVars["observability_monitoring_on_compute_nodes_enable"] = false
	options.TerraformVars["observability_atracker_enable"] = false
	options.TerraformVars["observability_atracker_target_type"] = "cos"

	// Prevent test teardown for post-test inspection
	options.SkipTestTearDown = true

	// Ensure proper cleanup after test execution
	defer options.TestTearDown()

	// Validate the cluster setup with Atracker disabled and target type as cos
	lsf.ValidateBasicClusterConfigurationWithCloudAtracker(t, options, testLogger)
}

// ############################## Negative Test cases ##########################################

// TestRunHPCWithoutMandatory tests Terraform's behavior when mandatory variables are missing by checking for specific error messages.
func TestRunHPCWithoutMandatory(t *testing.T) {
	t.Parallel()

	// Set up the test suite and prepare the testing environment
	setupTestSuite(t)

	// Log the initiation of the cluster creation process
	testLogger.Info(t, "Cluster creation process initiated for "+t.Name())

	// Getting absolute path of solutions/hpc
	abs, err := filepath.Abs("solutions/hpc")
	require.NoError(t, err, "Unable to get absolute path")

	terrPath := strings.ReplaceAll(abs, "tests/", "")

	// Define Terraform options
	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: terrPath,
		Vars: map[string]interface{}{
			"solution": "hpc",
		},
	})

	// Perform Terraform upgrade only once
	UpgradeTerraformOnce(t, terraformOptions)

	// Plan the Terraform deployment
	_, err = terraform.PlanE(t, terraformOptions)

	// If there is an error, check if it contains specific mandatory fields
	if err != nil {
		result :=
			utils.VerifyDataContains(t, err.Error(), "bastion_ssh_keys", testLogger) &&
				utils.VerifyDataContains(t, err.Error(), "compute_ssh_keys", testLogger) &&
				utils.VerifyDataContains(t, err.Error(), "remote_allowed_ips", testLogger)
		// Assert that the result is true if all mandatory fields are missing
		assert.True(t, result)
	} else {
		t.Error("Expected error did not occur")
		testLogger.FAIL(t, "Expected error did not occur on HPC without mandatory")
	}

}

// TestRunLSFWithoutMandatory tests Terraform's behavior when mandatory variables are missing by checking for specific error messages.
func TestRunLSFWithoutMandatory(t *testing.T) {
	t.Parallel()

	// Set up the test suite and prepare the testing environment
	setupTestSuite(t)

	// Log the initiation of the cluster creation process
	testLogger.Info(t, "Cluster creation process initiated for "+t.Name())

	// Getting absolute path of solutions/hpc
	abs, err := filepath.Abs("solutions/hpc")
	require.NoError(t, err, "Unable to get absolute path")

	terrPath := strings.ReplaceAll(abs, "tests/", "")

	// Define Terraform options
	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: terrPath,
		Vars: map[string]interface{}{
			"solution": "lsf",
		},
	})

	// Perform Terraform upgrade only once
	UpgradeTerraformOnce(t, terraformOptions)

	// Plan the Terraform deployment
	_, err = terraform.PlanE(t, terraformOptions)

	// If there is an error, check if it contains specific mandatory fields
	if err != nil {
		result := utils.VerifyDataContains(t, err.Error(), "bastion_ssh_keys", testLogger) &&
			utils.VerifyDataContains(t, err.Error(), "compute_ssh_keys", testLogger) &&
			utils.VerifyDataContains(t, err.Error(), "remote_allowed_ips", testLogger)
		// Assert that the result is true if all mandatory fields are missing
		assert.True(t, result)
	} else {
		t.Error("Expected error did not occur")
		testLogger.FAIL(t, "Expected error did not occur on LSF without mandatory")
	}

}

// TestRunHPCInvalidReservationID verifies Terraform's behavior when mandatory variables are missing.
// Specifically, it checks for appropriate error messages when "reservation_id" is not set correctly.
func TestRunHPCInvalidReservationID(t *testing.T) {
	// Parallelize the test for concurrent execution
	t.Parallel()

	// Set up the test suite environment
	setupTestSuite(t)

	// Log the initiation of the cluster creation process
	testLogger.Info(t, "Cluster creation process initiated for "+t.Name())

	// Retrieve required environment variables
	envVars := GetEnvVars()

	// Determine the absolute path to the Terraform directory
	absPath, err := filepath.Abs("solutions/hpc")
	require.NoError(t, err, "Unable to get the absolute path for the solutions directory")

	// Adjust the Terraform directory path to remove "tests/" if present
	terraformDir := strings.ReplaceAll(absPath, "tests/", "")

	// Define Terraform options with relevant variables
	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: terraformDir,
		Vars: map[string]interface{}{
			"bastion_ssh_keys":   utils.SplitAndTrim(envVars.SSHKey, ","),
			"compute_ssh_keys":   utils.SplitAndTrim(envVars.SSHKey, ","),
			"zones":              utils.SplitAndTrim(envVars.Zone, ","),
			"remote_allowed_ips": utils.SplitAndTrim(envVars.RemoteAllowedIPs, ","),
			"solution":           "hpc",
			"cluster_name":       envVars.ClusterName,
		},
	})

	// Perform Terraform upgrade only once
	UpgradeTerraformOnce(t, terraformOptions)

	// Plan the Terraform deployment
	_, err = terraform.PlanE(t, terraformOptions)

	// Ensure an error is returned during the planning stage
	assert.Error(t, err, "Expected an error during plan")

	// Validate the error message if an error occurred
	if err != nil {
		// Verify the error message contains expected substrings
		isErrorValid := utils.VerifyDataContains(t, err.Error(), "validate_reservation_id_new_msg", testLogger) &&
			utils.VerifyDataContains(t, err.Error(), "The provided reservation id doesn't have a valid reservation or the reservation id is not on the same account as HPC deployment.", testLogger)

		// Assert that all required validations passed
		assert.True(t, isErrorValid, "Error validation failed")
	} else {
		// Log failure if the expected error did not occur
		t.Error("Expected error did not occur")
		testLogger.FAIL(t, "Expected error did not occur for reservation ID")
	}
}

// TestRunInvalidSubnetCIDR validates cluster creation with invalid subnet CIDR ranges.
func TestRunInvalidSubnetCIDR(t *testing.T) {
	// Parallelize the test to run concurrently with others
	t.Parallel()

	// Set up the test suite and prepare the testing environment
	setupTestSuite(t)

	// Log the initiation of the cluster creation process
	testLogger.Info(t, "Cluster creation process initiated for "+t.Name())

	// Generate a random prefix for the cluster to ensure uniqueness
	hpcClusterPrefix := utils.GenerateTimestampedClusterPrefix(utils.GenerateRandomString())

	// Retrieve necessary environment variables for the test
	envVars := GetEnvVars()

	// Get the absolute path of solutions/hpc
	abs, err := filepath.Abs("solutions/hpc")
	require.NoError(t, err, "Unable to get absolute path")

	terrPath := strings.ReplaceAll(abs, "tests/", "")

	// Initialize the map to hold the variables
	vars := map[string]interface{}{
		"cluster_prefix":     hpcClusterPrefix,
		"bastion_ssh_keys":   utils.SplitAndTrim(envVars.SSHKey, ","),
		"compute_ssh_keys":   utils.SplitAndTrim(envVars.SSHKey, ","),
		"zones":              utils.SplitAndTrim(envVars.Zone, ","),
		"remote_allowed_ips": utils.SplitAndTrim(envVars.RemoteAllowedIPs, ","),
		"solution":           envVars.Solution,
		"cluster_name":       envVars.ClusterName,
		"vpc_cluster_private_subnets_cidr_blocks":       utils.SplitAndTrim("1.1.1.1/20", ","),
		"vpc_cluster_login_private_subnets_cidr_blocks": utils.SplitAndTrim("2.2.2.2/20", ","),
		"scc_enable": false,
	}

	// You can add conditional logic here to modify the map, for example:
	if envVars.Solution == "HPC" {
		// specific to HPC
		vars["reservation_id"] = envVars.ReservationID
	}

	// Define Terraform options
	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: terrPath,
		Vars:         vars,
	},
	)

	// Perform Terraform upgrade only once
	UpgradeTerraformOnce(t, terraformOptions)

	// Apply the Terraform configuration
	_, err = terraform.InitAndApplyE(t, terraformOptions)

	// Check if an error occurred during apply
	assert.Error(t, err, "Expected an error during apply")

	if err != nil {
		// Check if the error message contains specific keywords indicating Subnet CIDR block issues
		result := utils.VerifyDataContains(t, err.Error(), "Invalid json payload provided: Key: 'SubnetTemplateOneOf.SubnetTemplate.CIDRBlock' Error:Field validation for 'CIDRBlock' failed on the 'validcidr' tag", testLogger)
		assert.True(t, result)
		if result {
			testLogger.PASS(t, "Validation succeeded: Invalid Subnet CIDR range")
		} else {
			testLogger.FAIL(t, "Validation failed: Invalid Subnet CIDR range")
		}
	} else {
		// Log an error if the expected error did not occur
		t.Error("Expected error did not occur")
		testLogger.FAIL(t, "Expected error did not occur on Invalid Subnet CIDR range")
	}

	// Cleanup resources
	defer terraform.Destroy(t, terraformOptions)
}

// TestRunInvalidSshKeysAndRemoteAllowedIP validates cluster creation with invalid ssh keys and remote allowed IP.
func TestRunInvalidSshKeysAndRemoteAllowedIP(t *testing.T) {
	// Parallelize the test to run concurrently with others
	t.Parallel()

	// Set up the test suite and prepare the testing environment
	setupTestSuite(t)

	// Log the initiation of the cluster creation process
	testLogger.Info(t, "Cluster creation process initiated for "+t.Name())

	// Generate a random prefix for the cluster to ensure uniqueness
	hpcClusterPrefix := utils.GenerateTimestampedClusterPrefix(utils.GenerateRandomString())

	// Retrieve necessary environment variables for the test
	envVars := GetEnvVars()

	// Get the absolute path of solutions/hpc
	abs, err := filepath.Abs("solutions/hpc")
	require.NoError(t, err, "Unable to get absolute path")

	terrPath := strings.ReplaceAll(abs, "tests/", "")

	// Initialize the map to hold the variables
	vars := map[string]interface{}{
		"cluster_prefix":     hpcClusterPrefix,
		"bastion_ssh_keys":   []string{""},
		"compute_ssh_keys":   []string{""},
		"zones":              utils.SplitAndTrim(envVars.Zone, ","),
		"remote_allowed_ips": []string{""},
		"cluster_name":       envVars.ClusterName,
		"solution":           envVars.Solution,
	}

	// You can add conditional logic here to modify the map, for example:
	if envVars.Solution == "HPC" {
		// specific to HPC
		vars["reservation_id"] = envVars.ReservationID
	}

	// Define Terraform options
	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: terrPath,
		Vars:         vars,
	})

	// Perform Terraform upgrade only once
	UpgradeTerraformOnce(t, terraformOptions)

	// Plan the Terraform deployment
	_, err = terraform.PlanE(t, terraformOptions)

	// Check if an error occurred during plan
	assert.Error(t, err, "Expected an error during plan")

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

// TestRunHPCInvalidReservationIDAndContractID tests invalid cluster_name and reservation_id values
func TestRunHPCInvalidReservationIDAndContractID(t *testing.T) {
	t.Parallel()

	// Set up the test suite and prepare the testing environment
	setupTestSuite(t)

	// Log the initiation of cluster creation process
	testLogger.Info(t, "Cluster creation process initiated for "+t.Name())

	// Generate a random prefix for the cluster to ensure uniqueness
	hpcClusterPrefix := utils.GenerateTimestampedClusterPrefix(utils.GenerateRandomString())

	// Retrieve necessary environment variables for the test
	envVars := GetEnvVars()

	// Define invalid cluster_name and reservation_id values
	invalidClusterNames := []string{
		"too_long_cluster_name_1234567890_abcdefghijklmnopqrstuvwxyz", //pragma: allowlist secret
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

	// Loop over all combinations of invalid cluster_name and reservation_id values
	for _, ClusterName := range invalidClusterNames {
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
					"cluster_name":       ClusterName,
					"reservation_id":     reservationID,
					"solution":           "hpc",
				},
			})

			// Perform Terraform upgrade only once
			UpgradeTerraformOnce(t, terraformOptions)

			// Plan the Terraform deployment
			_, err = terraform.PlanE(t, terraformOptions)

			// If there is an error, check if it contains specific mandatory fields
			if err != nil {
				ClusterNameError := utils.VerifyDataContains(t, err.Error(), "cluster_name", testLogger)
				reservationIDError := utils.VerifyDataContains(t, err.Error(), "reservation_id", testLogger)
				result := ClusterNameError && reservationIDError
				// Assert that the result is true if all mandatory fields are missing
				assert.True(t, result)
				if result {
					testLogger.PASS(t, "Validation succeeded: Invalid ClusterName and ReservationID")
				} else {
					testLogger.FAIL(t, "Validation failed: Expected error did not contain required fields: cluster_name or reservation_id")
				}
			} else {
				// Log an error if the expected error did not occur
				t.Error("Expected error did not occur")
				testLogger.FAIL(t, "Expected error did not occur on Invalid ClusterName and ReservationID validation")
			}
		}
	}
}

// TestRunInvalidLDAPServerIP validates cluster creation with invalid LDAP server IP.
func TestRunInvalidLDAPServerIP(t *testing.T) {
	// Parallelize the test to run concurrently with others
	t.Parallel()

	// Set up the test suite and prepare the testing environment
	setupTestSuite(t)

	// Log the initiation of the cluster creation process
	testLogger.Info(t, "Cluster creation process initiated for "+t.Name())

	// Generate a random prefix for the cluster to ensure uniqueness
	hpcClusterPrefix := utils.GenerateTimestampedClusterPrefix(utils.GenerateRandomString())

	// Retrieve necessary environment variables for the test
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

	// Initialize the map to hold the variables
	vars := map[string]interface{}{
		"cluster_prefix":      hpcClusterPrefix,
		"bastion_ssh_keys":    utils.SplitAndTrim(envVars.SSHKey, ","),
		"compute_ssh_keys":    utils.SplitAndTrim(envVars.SSHKey, ","),
		"zones":               utils.SplitAndTrim(envVars.Zone, ","),
		"remote_allowed_ips":  utils.SplitAndTrim(envVars.RemoteAllowedIPs, ","),
		"cluster_name":        envVars.ClusterName,
		"enable_ldap":         true,
		"ldap_admin_password": envVars.LdapAdminPassword, //pragma: allowlist secret
		"ldap_server":         "10.10.10.10",
		"ldap_server_cert":    "SampleTest",
		"solution":            envVars.Solution,
		"scc_enable":          false,
	}

	// You can add conditional logic here to modify the map, for example:
	if envVars.Solution == "HPC" {
		// specific to HPC
		vars["reservation_id"] = envVars.ReservationID
	}

	// Define Terraform options
	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: terrPath,
		Vars:         vars,
	})

	// Perform Terraform upgrade only once
	UpgradeTerraformOnce(t, terraformOptions)

	// Apply the Terraform configuration
	output, err := terraform.InitAndApplyE(t, terraformOptions)

	// Check if an error occurred during apply
	assert.Error(t, err, "Expected an error during apply")

	if err != nil {

		// Check if the error message contains specific keywords indicating LDAP server IP issues
		result := utils.VerifyDataContains(t, output, "The connection to the existing LDAP server 10.10.10.10 failed", testLogger)
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

// TestRunInvalidLDAPServerCert validates cluster creation with invalid LDAP server Cert.
func TestRunInvalidLDAPServerCert(t *testing.T) {
	// Parallelize the test to run concurrently with others
	t.Parallel()

	// Set up the test suite and prepare the testing environment
	setupTestSuite(t)

	// Log the initiation of the cluster creation process
	testLogger.Info(t, "Cluster creation process initiated for "+t.Name())

	// Generate a random prefix for the cluster to ensure uniqueness
	hpcClusterPrefix := utils.GenerateTimestampedClusterPrefix(utils.GenerateRandomString())

	// Retrieve necessary environment variables for the test
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

	// Initialize the map to hold the variables
	vars := map[string]interface{}{
		"cluster_prefix":      hpcClusterPrefix,
		"bastion_ssh_keys":    utils.SplitAndTrim(envVars.SSHKey, ","),
		"compute_ssh_keys":    utils.SplitAndTrim(envVars.SSHKey, ","),
		"zones":               utils.SplitAndTrim(envVars.Zone, ","),
		"remote_allowed_ips":  utils.SplitAndTrim(envVars.RemoteAllowedIPs, ","),
		"cluster_name":        envVars.ClusterName,
		"enable_ldap":         true,
		"ldap_admin_password": envVars.LdapAdminPassword, //pragma: allowlist secret
		"ldap_server":         "10.10.10.10",
		"ldap_server_cert":    "",
		"solution":            envVars.Solution,
		"scc_enable":          false,
	}

	// You can add conditional logic here to modify the map, for example:
	if envVars.Solution == "HPC" {
		// specific to HPC
		vars["reservation_id"] = envVars.ReservationID
	}

	// Define Terraform options
	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: terrPath,
		Vars:         vars,
	})

	// Perform Terraform upgrade only once
	UpgradeTerraformOnce(t, terraformOptions)

	// plan the Terraform configuration
	_, err = terraform.InitAndPlanE(t, terraformOptions)

	// Check if an error occurred during plan
	assert.Error(t, err, "Expected an error during plan")

	if err != nil {

		// Check if the error message contains specific keywords indicating LDAP server IP issues
		result := utils.VerifyDataContains(t, err.Error(), "Provide the current LDAP server certificate. This is required if 'ldap_server' is not set to 'null'; otherwise, the LDAP configuration will not succeed.", testLogger)
		assert.True(t, result)
		if result {
			testLogger.PASS(t, "Validation succeeded: Invalid LDAP server Cert")
		} else {
			testLogger.FAIL(t, "Validation failed: Invalid LDAP server Cert")
		}
	} else {
		// Log an error if the expected error did not occur
		t.Error("Expected error did not occur")
		testLogger.FAIL(t, "Expected error did not occur on Invalid LDAP Server Cert")
	}

	// Cleanup resources
	defer terraform.Destroy(t, terraformOptions)
}

// TestRunInvalidLDAPUsernamePassword tests invalid LDAP username and password
func TestRunInvalidLDAPUsernamePassword(t *testing.T) {
	t.Parallel()

	// Set up the test suite and prepare the testing environment
	setupTestSuite(t)

	// Log the initiation of cluster creation process
	testLogger.Info(t, "Cluster creation process initiated for "+t.Name())

	// Generate a random prefix for the cluster to ensure uniqueness
	hpcClusterPrefix := utils.GenerateTimestampedClusterPrefix(utils.GenerateRandomString())

	// Retrieve necessary environment variables for the test
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

			// Initialize the map to hold the variables
			vars := map[string]interface{}{
				"cluster_prefix":      hpcClusterPrefix,
				"bastion_ssh_keys":    utils.SplitAndTrim(envVars.SSHKey, ","),
				"compute_ssh_keys":    utils.SplitAndTrim(envVars.SSHKey, ","),
				"zones":               utils.SplitAndTrim(envVars.Zone, ","),
				"remote_allowed_ips":  utils.SplitAndTrim(envVars.RemoteAllowedIPs, ","),
				"cluster_name":        envVars.ClusterName,
				"enable_ldap":         true,
				"ldap_user_name":      username,
				"ldap_user_password":  password, //pragma: allowlist secret
				"ldap_admin_password": password, //pragma: allowlist secret
				"solution":            envVars.Solution,
			}

			// You can add conditional logic here to modify the map, for example:
			if envVars.Solution == "HPC" {
				// specific to HPC
				vars["reservation_id"] = envVars.ReservationID
			}

			// Define Terraform options
			terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
				TerraformDir: terrPath,
				Vars:         vars,
			})

			// Perform Terraform upgrade only once
			UpgradeTerraformOnce(t, terraformOptions)

			// Plan the Terraform deployment
			_, err = terraform.PlanE(t, terraformOptions)

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

	// Set up the test suite and prepare the testing environment
	setupTestSuite(t)

	// Log the initiation of the cluster creation process
	testLogger.Info(t, "Cluster creation process initiated for "+t.Name())

	invalidAPPCenterPwd := []string{
		"pass@1234",
		"Pass1234",
		"Pas@12",
		"",
	}

	// Loop over all combinations of invalid cluster_name and reservation_id values
	for _, password := range invalidAPPCenterPwd { //pragma: allowlist secret

		// Generate a random prefix for the cluster to ensure uniqueness
		hpcClusterPrefix := utils.GenerateTimestampedClusterPrefix(utils.GenerateRandomString())
		// Retrieve necessary environment variables for the test
		envVars := GetEnvVars()

		// Getting absolute path of solutions/hpc
		abs, err := filepath.Abs("solutions/hpc")
		require.NoError(t, err, "Unable to get absolute path")

		terrPath := strings.ReplaceAll(abs, "tests/", "")

		// Initialize the map to hold the variables
		vars := map[string]interface{}{
			"cluster_prefix":     hpcClusterPrefix,
			"bastion_ssh_keys":   utils.SplitAndTrim(envVars.SSHKey, ","),
			"compute_ssh_keys":   utils.SplitAndTrim(envVars.SSHKey, ","),
			"zones":              utils.SplitAndTrim(envVars.Zone, ","),
			"remote_allowed_ips": utils.SplitAndTrim(envVars.RemoteAllowedIPs, ","),
			"cluster_name":       envVars.ClusterName,
			"enable_app_center":  true,
			"app_center_gui_pwd": password,
			"solution":           envVars.Solution,
		}

		// You can add conditional logic here to modify the map, for example:
		if envVars.Solution == "HPC" {
			// specific to HPC
			vars["reservation_id"] = envVars.ReservationID
		}

		// Define Terraform options
		terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
			TerraformDir: terrPath,
			Vars:         vars,
		})

		// Perform Terraform upgrade only once
		UpgradeTerraformOnce(t, terraformOptions)

		// Plan the Terraform deployment
		_, err = terraform.PlanE(t, terraformOptions)

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

	// Set up the test suite and prepare the testing environment
	setupTestSuite(t)

	// Log the initiation of the cluster creation process
	testLogger.Info(t, "Cluster creation process initiated for "+t.Name())

	// Generate a random prefix for the cluster to ensure uniqueness
	hpcClusterPrefix := utils.GenerateTimestampedClusterPrefix(utils.GenerateRandomString())

	// Retrieve necessary environment variables for the test
	envVars := GetEnvVars()

	// Get the absolute path of solutions/hpc
	abs, err := filepath.Abs("solutions/hpc")
	require.NoError(t, err, "Unable to get absolute path")

	terrPath := strings.ReplaceAll(abs, "tests/", "")

	// Initialize the map to hold the variables
	vars := map[string]interface{}{
		"cluster_prefix":     hpcClusterPrefix,
		"bastion_ssh_keys":   utils.SplitAndTrim(envVars.SSHKey, ","),
		"compute_ssh_keys":   utils.SplitAndTrim(envVars.SSHKey, ","),
		"zones":              utils.SplitAndTrim(envVars.Zone, ","),
		"remote_allowed_ips": utils.SplitAndTrim(envVars.RemoteAllowedIPs, ","),
		"cluster_name":       envVars.ClusterName,
		"dns_domain_name":    map[string]string{"compute": "sample"},
		"solution":           envVars.Solution,
	}

	// You can add conditional logic here to modify the map, for example:
	if envVars.Solution == "HPC" {
		// specific to HPC
		vars["reservation_id"] = envVars.ReservationID
	}

	// Define Terraform options
	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: terrPath,
		Vars:         vars,
	})

	// Perform Terraform upgrade only once
	UpgradeTerraformOnce(t, terraformOptions)

	// Plan the Terraform deployment
	_, err = terraform.PlanE(t, terraformOptions)

	// Check if an error occurred during plan
	assert.Error(t, err, "Expected an error during plan")

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

	// Set up the test suite and prepare the testing environment
	setupTestSuite(t)

	// Log the initiation of the cluster creation process
	testLogger.Info(t, "Cluster creation process initiated for "+t.Name())

	// Service instance name
	randomString := utils.GenerateRandomString()
	kmsInstanceName := "cicd-" + randomString

	// Generate a random prefix for the cluster to ensure uniqueness
	hpcClusterPrefix := utils.GenerateTimestampedClusterPrefix(utils.GenerateRandomString())

	// Retrieve necessary environment variables for the test
	envVars := GetEnvVars()

	// Create service instance and KMS key using IBMCloud CLI
	err := lsf.CreateServiceInstanceAndKmsKey(t, os.Getenv("TF_VAR_ibmcloud_api_key"), utils.GetRegion(envVars.Zone), envVars.DefaultExistingResourceGroup, kmsInstanceName, lsf.KMS_KEY_NAME, testLogger)
	require.NoError(t, err, "Failed to create service instance and KMS key")

	// Ensure the service instance and KMS key are deleted after the test
	defer lsf.DeleteServiceInstanceAndAssociatedKeys(t, os.Getenv("TF_VAR_ibmcloud_api_key"), utils.GetRegion(envVars.Zone), envVars.DefaultExistingResourceGroup, kmsInstanceName, testLogger)

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

	// Initialize the map to hold the variables
	vars1 := map[string]interface{}{
		"cluster_prefix":     hpcClusterPrefix,
		"bastion_ssh_keys":   utils.SplitAndTrim(envVars.SSHKey, ","),
		"compute_ssh_keys":   utils.SplitAndTrim(envVars.SSHKey, ","),
		"zones":              utils.SplitAndTrim(envVars.Zone, ","),
		"remote_allowed_ips": utils.SplitAndTrim(envVars.RemoteAllowedIPs, ","),
		"cluster_name":       envVars.ClusterName,
		"kms_instance_name":  kmsInstanceName,
		"kms_key_name":       invalidKMSKeyName,
		"solution":           envVars.Solution,
	}

	// You can add conditional logic here to modify the map, for example:
	if envVars.Solution == "HPC" {
		// specific to HPC
		vars1["reservation_id"] = envVars.ReservationID
	}

	// Test with valid instance ID and invalid key name
	terraformOptionsCase1 := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: terrPath,
		Vars:         vars1,
	})

	// Perform Terraform upgrade only once
	UpgradeTerraformOnce(t, terraformOptionsCase1)

	// Plan the Terraform deployment
	_, err = terraform.PlanE(t, terraformOptionsCase1)

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

	// Initialize the map to hold the variables
	vars2 := map[string]interface{}{
		"cluster_prefix":     hpcClusterPrefix,
		"bastion_ssh_keys":   utils.SplitAndTrim(envVars.SSHKey, ","),
		"compute_ssh_keys":   utils.SplitAndTrim(envVars.SSHKey, ","),
		"zones":              utils.SplitAndTrim(envVars.Zone, ","),
		"remote_allowed_ips": utils.SplitAndTrim(envVars.RemoteAllowedIPs, ","),
		"cluster_name":       envVars.ClusterName,
		"kms_instance_name":  invalidKMSInstanceName,
		"kms_key_name":       lsf.KMS_KEY_NAME,
		"solution":           envVars.Solution,
	}

	// You can add conditional logic here to modify the map, for example:
	if envVars.Solution == "HPC" {
		// specific to HPC
		vars2["reservation_id"] = envVars.ReservationID
	}

	// Test with invalid instance ID and valid key name
	terraformOptionsCase2 := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: terrPath,
		Vars:         vars2,
	})

	// Plan the Terraform deployment
	_, err = terraform.PlanE(t, terraformOptionsCase2)
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

	// Initialize the map to hold the variables
	vars3 := map[string]interface{}{
		"cluster_prefix":     hpcClusterPrefix,
		"bastion_ssh_keys":   utils.SplitAndTrim(envVars.SSHKey, ","),
		"compute_ssh_keys":   utils.SplitAndTrim(envVars.SSHKey, ","),
		"zones":              utils.SplitAndTrim(envVars.Zone, ","),
		"remote_allowed_ips": utils.SplitAndTrim(envVars.RemoteAllowedIPs, ","),
		"cluster_name":       envVars.ClusterName,
		"kms_key_name":       lsf.KMS_KEY_NAME,
		"solution":           envVars.Solution,
	}

	// You can add conditional logic here to modify the map, for example:
	if envVars.Solution == "HPC" {
		// specific to HPC
		vars3["reservation_id"] = envVars.ReservationID
	}

	// Test without instance ID and valid key name
	terraformOptionsCase3 := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: terrPath,
		Vars:         vars3,
	})

	// Plan the Terraform deployment
	_, err = terraform.PlanE(t, terraformOptionsCase3)
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

	// Set up the test suite and prepare the testing environment
	setupTestSuite(t)

	// Log the initiation of the cluster creation process
	testLogger.Info(t, "Cluster creation process initiated for "+t.Name())

	// Generate a random prefix for the cluster to ensure uniqueness
	hpcClusterPrefix := utils.GenerateTimestampedClusterPrefix(utils.GenerateRandomString())

	// Retrieve necessary environment variables for the test
	envVars := GetEnvVars()

	// Set up the test options with the relevant parameters, including environment variables and resource group, set up test environment
	options, err := setupOptionsVpc(t, hpcClusterPrefix, createVpcTerraformDir, envVars.DefaultExistingResourceGroup)
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

	// Initialize the map to hold the variables
	vars := map[string]interface{}{
		"cluster_prefix":     hpcClusterPrefix,
		"bastion_ssh_keys":   utils.SplitAndTrim(envVars.SSHKey, ","),
		"compute_ssh_keys":   utils.SplitAndTrim(envVars.SSHKey, ","),
		"zones":              utils.SplitAndTrim(envVars.Zone, ","),
		"remote_allowed_ips": utils.SplitAndTrim(envVars.RemoteAllowedIPs, ","),
		"cluster_name":       envVars.ClusterName,
		"cluster_subnet_ids": utils.SplitAndTrim(computesubnetIds, ","),
		"login_subnet_id":    bastionsubnetId,
		"solution":           envVars.Solution,
	}

	// You can add conditional logic here to modify the map, for example:
	if envVars.Solution == "HPC" {
		// specific to HPC
		vars["reservation_id"] = envVars.ReservationID
	}

	// Define Terraform options
	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: terrPath,
		Vars:         vars,
	})

	// Perform Terraform upgrade only once
	UpgradeTerraformOnce(t, terraformOptions)

	// Plan the Terraform deployment
	_, err = terraform.PlanE(t, terraformOptions)

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

// TestRunInvalidDedicatedHostConfigurationWithZeroWorkerNodes validates the behavior of cluster creation
// when a dedicated host is enabled but the worker node count is set to zero.
func TestRunInvalidDedicatedHostConfigurationWithZeroWorkerNodes(t *testing.T) {
	// Parallelize the test
	t.Parallel()

	// Set up the test suite and prepare the testing environment
	setupTestSuite(t)

	// Generate a random prefix for the cluster to ensure uniqueness
	hpcClusterPrefix := utils.GenerateRandomString()

	// Log the initiation of the cluster creation process
	testLogger.Info(t, "Cluster creation process initiated for "+t.Name())

	// Retrieve necessary environment variables for the test
	envVars := GetEnvVars()

	// Set up the test options with the relevant parameters, including environment variables and resource group
	options, err := setupOptions(t, hpcClusterPrefix, terraformDir, envVars.DefaultExistingResourceGroup, ignoreDestroys, ignoreUpdates)
	require.NoError(t, err, "Error setting up test options: %v", err)
	options.TerraformVars["enable_dedicated_host"] = true
	options.TerraformVars["worker_node_instance_type"] = []map[string]interface{}{
		{
			"count":         0,
			"instance_type": "bx2-2x8",
		},
	}

	options.SkipTestTearDown = true
	defer options.TestTearDown()

	lsf.ValidateBasicClusterConfigurationWithDedicatedHost(t, options, false, testLogger)

}

// TestRunInvalidDedicatedHostProfile validates cluster creation with an invalid instance profile.
func TestRunInvalidDedicatedHostProfile(t *testing.T) {
	// Parallelize the test to run concurrently with others
	t.Parallel()

	// Set up the test suite and prepare the testing environment
	setupTestSuite(t)

	// Log the initiation of the cluster creation process
	testLogger.Info(t, "Cluster creation process initiated for "+t.Name())

	// Generate a random prefix for the cluster to ensure uniqueness
	hpcClusterPrefix := utils.GenerateTimestampedClusterPrefix(utils.GenerateRandomString())

	// Retrieve necessary environment variables for the test
	envVars := GetEnvVars()

	// Get the absolute path of solutions/hpc
	abs, err := filepath.Abs("solutions/hpc")
	require.NoError(t, err, "Unable to get absolute path")

	terrPath := strings.ReplaceAll(abs, "tests/", "")

	// Initialize the map to hold the variables
	vars := map[string]interface{}{
		"cluster_prefix":        hpcClusterPrefix,
		"bastion_ssh_keys":      utils.SplitAndTrim(envVars.SSHKey, ","),
		"compute_ssh_keys":      utils.SplitAndTrim(envVars.SSHKey, ","),
		"zones":                 utils.SplitAndTrim(envVars.Zone, ","),
		"remote_allowed_ips":    utils.SplitAndTrim(envVars.RemoteAllowedIPs, ","),
		"cluster_name":          envVars.ClusterName,
		"solution":              envVars.Solution,
		"scc_enable":            false,
		"enable_dedicated_host": true,
		"worker_node_instance_type": []map[string]interface{}{ // Invalid data
			{
				"count":         1,
				"instance_type": "cx2-2x4",
			},
			{
				"count":         1,
				"instance_type": "bx2-2x8",
			},
		},
		"observability_monitoring_enable": false,
		"enable_cos_integration":          false,
		"enable_vpc_flow_logs":            false,
		"key_management":                  "null",
	}

	// You can add conditional logic here to modify the map, for example:
	if envVars.Solution == "HPC" {
		// specific to HPC
		vars["reservation_id"] = envVars.ReservationID
	}

	// Define Terraform options
	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: terrPath,
		Vars:         vars,
	})

	// Perform Terraform upgrade only once
	UpgradeTerraformOnce(t, terraformOptions)

	// Apply the Terraform configuration
	_, err = terraform.InitAndPlanE(t, terraformOptions)

	// Check if an error occurred during apply
	assert.Error(t, err, "Expected an error during plan")

	if err != nil {
		errMsg := err.Error()
		// Check if the error message contains specific keywords
		containsWorkerNodeType := utils.VerifyDataContains(t, errMsg, "is list of object with 2 elements", testLogger)
		containsDedicatedHost := utils.VerifyDataContains(t, errMsg, "'enable_dedicated_host' is true, only one profile should be specified", testLogger)

		result := containsWorkerNodeType && containsDedicatedHost
		assert.True(t, result)

		if result {
			testLogger.PASS(t, "Validation succeeded for invalid worker_node_instance_type object elements.")
		} else {
			testLogger.FAIL(t, fmt.Sprintf("Validation failed: expected error conditions not met. Actual error: %s", errMsg))
		}
	} else {
		// Log an error if the expected error did not occur
		t.Error("Expected error did not occur")
		testLogger.FAIL(t, "Expected validation error did not occur for Invalid Dedicated-Host instance profile.")

	}

}

// TestRunInvalidMinWorkerNodeCountGreaterThanMax cluster creation with an invalid worker node count.
func TestRunInvalidMinWorkerNodeCountGreaterThanMax(t *testing.T) {
	// Parallelize the test to run concurrently with others
	t.Parallel()

	// Set up the test suite and prepare the testing environment
	setupTestSuite(t)

	// Log the initiation of the cluster creation process
	testLogger.Info(t, "Cluster creation process initiated for "+t.Name())

	// Generate a random prefix for the cluster to ensure uniqueness
	hpcClusterPrefix := utils.GenerateTimestampedClusterPrefix(utils.GenerateRandomString())

	// Retrieve necessary environment variables for the test
	envVars := GetEnvVars()

	// You can add conditional logic here to modify the map, for example:
	if envVars.Solution == "lsf" {

		// Get the absolute path of solutions/hpc
		abs, err := filepath.Abs("solutions/hpc")
		require.NoError(t, err, "Unable to get absolute path")

		terrPath := strings.ReplaceAll(abs, "tests/", "")

		// Initialize the map to hold the variables
		vars := map[string]interface{}{
			"cluster_prefix":        hpcClusterPrefix,
			"bastion_ssh_keys":      utils.SplitAndTrim(envVars.SSHKey, ","),
			"compute_ssh_keys":      utils.SplitAndTrim(envVars.SSHKey, ","),
			"zones":                 utils.SplitAndTrim(envVars.Zone, ","),
			"remote_allowed_ips":    utils.SplitAndTrim(envVars.RemoteAllowedIPs, ","),
			"cluster_name":          envVars.ClusterName,
			"worker_node_max_count": 2, //invalid
			"worker_node_instance_type": []map[string]interface{}{ // Invalid data
				{
					"count":         2,
					"instance_type": "bx2-2x8",
				},
				{
					"count":         1,
					"instance_type": "cx2-2x4",
				},
			},
			"solution":                        envVars.Solution,
			"scc_enable":                      false,
			"observability_monitoring_enable": false,
			"enable_cos_integration":          false,
			"enable_vpc_flow_logs":            false,
			"key_management":                  "null",
		}

		// Define Terraform options
		terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
			TerraformDir: terrPath,
			Vars:         vars,
		})

		// Perform Terraform upgrade only once
		UpgradeTerraformOnce(t, terraformOptions)

		// Apply the Terraform configuration
		_, err = terraform.InitAndPlanE(t, terraformOptions)

		// Check if an error occurred during plan
		assert.Error(t, err, "Expected an error during plan")

		if err != nil {

			// Check if the error message contains specific keywords indicating LDAP server IP issues
			result := utils.VerifyDataContains(t, err.Error(), "If the solution is set as lsf, the worker min count cannot be greater than worker max count.", testLogger)
			assert.True(t, result)
			if result {
				testLogger.PASS(t, "Validation succeeded for the worker node count")
			} else {
				testLogger.FAIL(t, "Validation failed for the worker node count")
			}
		} else {
			// Log an error if the expected error did not occur
			t.Error("Expected validation error did not occur.")
			testLogger.FAIL(t, "Expected validation error did not occur for Invalid worker node count")
		}
		// Cleanup resources
		defer terraform.Destroy(t, terraformOptions)
	}
	testLogger.Info(t, "TestRunInvalidMinWorkerNodeCountGreaterThanMax will execute If the solution is set as lsf")
}

// ############################## Existing Environment Test Cases ###############################
// TestRunExistingPACEnvironment test the validation of an existing PAC environment configuration.
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
	lsf.ValidateClusterConfigWithAPPCenterOnExistingEnvironment(
		t, config.ComputeSshKeysList, config.BastionIP, config.LoginNodeIP, config.ClusterName, config.ReservationID,
		config.ClusterPrefixName, config.ResourceGroup, config.KeyManagement,
		config.Zones, config.DnsDomainName, config.ManagementNodeIPList,
		config.IsHyperthreadingEnabled, testLogger)
}

// TestRunExistingPACAndLDAPEnvironment test the validation of an existing PAC and LDAP environment configuration.
func TestRunExistingPACAndLDAPEnvironment(t *testing.T) {
	// Parallelize the test to run concurrently with others
	t.Parallel()

	// Setup the test suite environment
	setupTestSuite(t)

	// Log the initiation of the cluster creation process
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
	lsf.ValidateClusterConfigWithAPPCenterAndLDAPOnExistingEnvironment(
		t, config.ComputeSshKeysList, config.BastionIP, config.LoginNodeIP, config.ClusterName, config.ReservationID,
		config.ClusterPrefixName, config.ResourceGroup, config.KeyManagement, config.Zones, config.DnsDomainName,
		config.ManagementNodeIPList, config.IsHyperthreadingEnabled, config.LdapServerIP, config.LdapDomain,
		config.LdapAdminPassword, config.LdapUserName, config.LdapUserPassword, testLogger)

}
