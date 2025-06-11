package tests

import (
	"fmt"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/stretchr/testify/require"

	lsf "github.com/terraform-ibm-modules/terraform-ibm-hpc/lsf"
	utils "github.com/terraform-ibm-modules/terraform-ibm-hpc/utilities"
)

// Constants for better organization
const (
	createVpcTerraformDir = "examples/create_vpc/" // Brand new VPC
)

// TestRunBasic validates the basic cluster configuration requirements.
// The test ensures proper resource isolation through random prefix generation
// and relies on ValidateBasicClusterConfiguration for resource cleanup.
//
// Prerequisites:
// - Valid environment configuration
// - Proper test suite initialization
// - Required permissions for resource operations
func TestRunBasic(t *testing.T) {
	t.Parallel()

	// Initialization and Setup
	setupTestSuite(t)
	require.NotNil(t, testLogger, "Test logger must be initialized")
	testLogger.Info(t, fmt.Sprintf("Test %s initiated", t.Name()))

	// Test Configuration
	envVars, err := GetEnvVars()
	require.NoError(t, err, "Failed to load environment configuration")

	options, err := setupOptions(
		t,
		utils.GenerateRandomString(), // Unique cluster prefix
		terraformDir,
		envVars.DefaultExistingResourceGroup,
	)
	require.NoError(t, err, "Failed to initialize test options")

	// Resource Cleanup Configuration
	options.SkipTestTearDown = true
	defer options.TestTearDown()

	// Cluster Deployment
	deploymentStart := time.Now()
	testLogger.Info(t, "Starting basic cluster deployment")

	clusterCreationErr := lsf.VerifyClusterCreationAndConsistency(t, options, testLogger)
	require.NoError(t, clusterCreationErr, "Cluster creation validation failed")

	testLogger.Info(t, fmt.Sprintf("Cluster deployment completed (duration: %v)", time.Since(deploymentStart)))

	// Post-deployment Validation
	validationStart := time.Now()
	lsf.ValidateClusterConfiguration(t, options, testLogger)
	testLogger.Info(t, fmt.Sprintf("Validation completed (duration: %v)", time.Since(validationStart)))

	// Test Result Evaluation
	if t.Failed() {
		testLogger.Error(t, fmt.Sprintf("Test %s failed — inspect validation logs for details", t.Name()))
	} else {
		testLogger.PASS(t, fmt.Sprintf("Test %s completed successfully", t.Name()))
	}
}

// TestRunCustomRGAsNull validates cluster creation with null resource group value.
// Verifies proper handling of empty resource group specification and ensures
// resources are created in the expected default location.
//
// Prerequisites:
// - Valid environment configuration
// - Proper test suite initialization
// - Permissions to create resources in default resource group
func TestRunCustomRGAsNull(t *testing.T) {
	t.Parallel()

	// Initialization and Setup
	setupTestSuite(t)
	require.NotNil(t, testLogger, "Test logger must be initialized")
	testLogger.Info(t, fmt.Sprintf("Test %s initiated", t.Name()))

	// Test Configuration
	options, err := setupOptions(
		t,
		utils.GenerateRandomString(), // Unique cluster prefix
		terraformDir,
		LSF_CUSTOM_EXISTING_RESOURCE_GROUP_VALUE_AS_NULL,
	)
	require.NoError(t, err, "Failed to initialize test options")

	// Resource Cleanup Configuration
	options.SkipTestTearDown = true
	defer options.TestTearDown()

	// Cluster Deployment
	deploymentStart := time.Now()
	testLogger.Info(t, "Starting cluster deployment with null resource group")

	clusterCreationErr := lsf.VerifyClusterCreationAndConsistency(t, options, testLogger)
	require.NoError(t, clusterCreationErr, "Cluster creation validation failed")

	testLogger.Info(t, fmt.Sprintf("Cluster deployment completed (duration: %v)", time.Since(deploymentStart)))

	// Post-deployment Validation
	validationStart := time.Now()

	lsf.ValidateBasicClusterConfiguration(t, options, testLogger)

	testLogger.Info(t, fmt.Sprintf("Validation completed (duration: %v)", time.Since(validationStart)))

	// Test Result Evaluation
	if t.Failed() {
		testLogger.Error(t, fmt.Sprintf("Test %s failed — inspect validation logs for details", t.Name()))
	} else {
		testLogger.PASS(t, fmt.Sprintf("Test %s completed successfully", t.Name()))
	}
}

// TestRunCustomRGAsNonDefault validates cluster creation with non-default resource group.
// Ensures proper resource creation in specified resource group and verifies
// all components are correctly provisioned in the custom location.
//
// Prerequisites:
// - Pre-existing non-default resource group
// - Valid environment configuration
// - Proper permissions on target resource group
func TestRunCustomRGAsNonDefault(t *testing.T) {
	t.Parallel()

	// Initialization and Setup
	setupTestSuite(t)
	require.NotNil(t, testLogger, "Test logger must be initialized")
	testLogger.Info(t, fmt.Sprintf("Test %s initiated", t.Name()))

	// Environment Configuration
	envVars, err := GetEnvVars()
	require.NoError(t, err, "Failed to load environment configuration")

	// Test Configuration
	options, err := setupOptions(
		t,
		utils.GenerateRandomString(), // Unique cluster prefix
		terraformDir,
		envVars.NonDefaultExistingResourceGroup,
	)
	require.NoError(t, err, "Failed to initialize test options")

	// Resource Cleanup Configuration
	options.SkipTestTearDown = true
	defer options.TestTearDown()

	// Cluster Deployment
	deploymentStart := time.Now()
	testLogger.Info(t, "Starting cluster deployment with non-default resource group")

	clusterCreationErr := lsf.VerifyClusterCreationAndConsistency(t, options, testLogger)
	require.NoError(t, clusterCreationErr, "Cluster creation validation failed")

	testLogger.Info(t, fmt.Sprintf("Cluster deployment completed (duration: %v)", time.Since(deploymentStart)))

	// Post-deployment Validation
	validationStart := time.Now()

	lsf.ValidateBasicClusterConfiguration(t, options, testLogger)

	testLogger.Info(t, fmt.Sprintf("Validation completed (duration: %v)", time.Since(validationStart)))

	// Test Result Evaluation
	if t.Failed() {
		testLogger.Error(t, fmt.Sprintf("Test %s failed — inspect validation logs for details", t.Name()))
	} else {
		testLogger.PASS(t, fmt.Sprintf("Test %s completed successfully", t.Name()))
	}
}

// TestRunAppCenter validates cluster creation with Application Center component.
// Verifies proper deployment and configuration of Application Center resources
// including GUI password handling and service activation.
//
// Prerequisites:
// - Valid environment configuration
// - Proper test suite initialization
// - Application Center enabled in environment vars
func TestRunAppCenter(t *testing.T) {
	t.Parallel()

	// Initialization and Setup
	setupTestSuite(t)
	require.NotNil(t, testLogger, "Test logger must be initialized")
	testLogger.Info(t, fmt.Sprintf("Test %s initiated", t.Name()))

	// Environment Configuration
	envVars, err := GetEnvVars()
	require.NoError(t, err, "Failed to load environment configuration")

	// Test Configuration
	options, err := setupOptions(
		t,
		utils.GenerateRandomString(), // Unique cluster prefix
		terraformDir,
		envVars.DefaultExistingResourceGroup,
	)
	require.NoError(t, err, "Failed to initialize test options")

	// Application Center Specific Configuration
	// options.TerraformVars["enable_app_center"] = strings.ToLower(envVars.EnableAppCenter)
	// options.TerraformVars["app_center_gui_pwd"] = envVars.AppCenterGuiPassword // pragma: allowlist secret

	// Resource Cleanup Configuration
	options.SkipTestTearDown = true
	defer options.TestTearDown()

	// Cluster Deployment
	deploymentStart := time.Now()
	testLogger.Info(t, "Starting Application Center cluster deployment")

	clusterCreationErr := lsf.VerifyClusterCreationAndConsistency(t, options, testLogger)
	require.NoError(t, clusterCreationErr, "Cluster creation validation failed")

	testLogger.Info(t, fmt.Sprintf("Cluster deployment completed (duration: %v)", time.Since(deploymentStart)))

	// Post-deployment Validation
	validationStart := time.Now()

	lsf.ValidateClusterConfigurationWithAPPCenter(t, options, testLogger)

	testLogger.Info(t, fmt.Sprintf("Validation completed (duration: %v)", time.Since(validationStart)))

	// Test Result Evaluation
	if t.Failed() {
		testLogger.Error(t, fmt.Sprintf("Test %s failed — inspect validation logs for details", t.Name()))
	} else {
		testLogger.PASS(t, fmt.Sprintf("Test %s completed successfully", t.Name()))
	}
}

// TestRunSCCEnabled validates cluster creation with SCC (Spectrum Computing Console) integration.
// Verifies proper SCC configuration including event notification and location settings.
//
// Prerequisites:
// - SCC enabled in environment configuration
// - Valid non-default resource group
// - Proper test suite initialization
func TestRunSCCEnabled(t *testing.T) {

	t.Parallel()

	// Initialization and Setup
	setupTestSuite(t)
	require.NotNil(t, testLogger, "Test logger must be initialized")
	testLogger.Info(t, fmt.Sprintf("Test %s initiated", t.Name()))

	// Test Configuration
	envVars, err := GetEnvVars()
	require.NoError(t, err, "Failed to load environment configuration")

	// Skip the test if SCC is disabled
	if strings.ToLower(envVars.SccEnabled) == "false" {
		testLogger.Warn(t, fmt.Sprintf("Skipping %s - SCC disabled in configuration", t.Name()))
		return
	}

	options, err := setupOptions(
		t,
		utils.GenerateRandomString(), // Unique cluster prefix
		terraformDir,
		envVars.DefaultExistingResourceGroup,
	)
	require.NoError(t, err, "Failed to initialize test options")

	// SCC Specific Configuration
	options.TerraformVars["scc_enable"] = envVars.SccEnabled
	options.TerraformVars["scc_event_notification_plan"] = envVars.SccEventNotificationPlan
	options.TerraformVars["scc_location"] = envVars.SccLocation

	// Resource Cleanup Configuration
	options.SkipTestTearDown = true
	defer options.TestTearDown()

	// Cluster Deployment
	deploymentStart := time.Now()
	testLogger.Info(t, "Starting SCC configuration cluster deployment")

	clusterCreationErr := lsf.VerifyClusterCreationAndConsistency(t, options, testLogger)
	require.NoError(t, clusterCreationErr, "Cluster creation validation failed")
	testLogger.Info(t, fmt.Sprintf("Cluster deployment completed (duration: %v)", time.Since(deploymentStart)))

	// Post-deployment Validation
	validationStart := time.Now()
	lsf.ValidateBasicClusterConfigurationWithSCC(t, options, testLogger)
	testLogger.Info(t, fmt.Sprintf("Validation completed (duration: %v)", time.Since(validationStart)))

	// Test Result Evaluation
	if t.Failed() {
		testLogger.Error(t, fmt.Sprintf("Test %s failed — inspect validation logs for details", t.Name()))
	} else {
		testLogger.PASS(t, fmt.Sprintf("Test %s completed successfully", t.Name()))
	}
}

// TestRunPacHa validates cluster creation with Application Center in high-availability mode.
// Ensures proper certificate handling and HA configuration for Application Center.
//
// Prerequisites:
// - APP_CENTER_EXISTING_CERTIFICATE_INSTANCE environment variable
// - Valid environment configuration
// - High availability enabled in configuration
func TestRunPacHa(t *testing.T) {
	t.Parallel()

	// Initialization and Setup
	setupTestSuite(t)
	require.NotNil(t, testLogger, "Test logger must be initialized")
	testLogger.Info(t, fmt.Sprintf("Test %s initiated", t.Name()))

	// Certificate Configuration
	existingCertInstance, ok := os.LookupEnv("APP_CENTER_EXISTING_CERTIFICATE_INSTANCE")
	require.True(t, ok, "Must set APP_CENTER_EXISTING_CERTIFICATE_INSTANCE environment variable")

	// Environment Configuration
	envVars, err := GetEnvVars()
	require.NoError(t, err, "Failed to load environment configuration")

	// Test Configuration
	options, err := setupOptions(
		t,
		utils.GenerateRandomString(), // Unique cluster prefix
		terraformDir,
		envVars.DefaultExistingResourceGroup,
	)
	require.NoError(t, err, "Failed to initialize test options")

	// Application Center HA Configuration
	options.TerraformVars["management_node_count"] = 3
	options.TerraformVars["enable_app_center"] = strings.ToLower(envVars.EnableAppCenter)
	options.TerraformVars["app_center_gui_pwd"] = envVars.AppCenterGuiPassword // pragma: allowlist secret
	options.TerraformVars["app_center_high_availability"] = true               // pragma: allowlist secret
	options.TerraformVars["app_center_existing_certificate_instance"] = existingCertInstance

	// Resource Cleanup Configuration
	options.SkipTestTearDown = true
	defer options.TestTearDown()

	// Cluster Deployment
	deploymentStart := time.Now()
	testLogger.Info(t, "Starting Application Center HA cluster deployment")

	clusterCreationErr := lsf.VerifyClusterCreationAndConsistency(t, options, testLogger)
	require.NoError(t, clusterCreationErr, "Cluster creation validation failed")

	testLogger.Info(t, fmt.Sprintf("Cluster deployment completed (duration: %v)", time.Since(deploymentStart)))

	// Post-deployment Validation
	validationStart := time.Now()
	lsf.ValidateClusterConfigurationWithPACHA(t, options, testLogger)

	testLogger.Info(t, fmt.Sprintf("Validation completed (duration: %v)", time.Since(validationStart)))

	// Test Result Evaluation
	if t.Failed() {
		testLogger.Error(t, fmt.Sprintf("Test %s failed — inspect validation logs for details", t.Name()))
	} else {
		testLogger.PASS(t, fmt.Sprintf("Test %s completed successfully", t.Name()))
	}
}

// TestRunNoKMSAndHTOff validates cluster creation without KMS and with hyperthreading disabled.
// Verifies proper cluster operation with these specific configurations.
//
// Prerequisites:
// - Valid environment configuration
// - Proper test suite initialization
// - Permissions to create resources without KMS
func TestRunNoKMSAndHTOff(t *testing.T) {
	t.Parallel()

	// Initialization and Setup
	setupTestSuite(t)
	require.NotNil(t, testLogger, "Test logger must be initialized")
	testLogger.Info(t, fmt.Sprintf("Test %s initiated", t.Name()))

	// Environment Configuration
	envVars, err := GetEnvVars()
	require.NoError(t, err, "Failed to load environment configuration")

	// Test Configuration
	options, err := setupOptions(
		t,
		utils.GenerateRandomString(), // Unique cluster prefix
		terraformDir,
		envVars.DefaultExistingResourceGroup,
	)
	require.NoError(t, err, "Failed to initialize test options")

	// Special Configuration
	options.TerraformVars["enable_cos_integration"] = false
	options.TerraformVars["enable_vpc_flow_logs"] = false
	options.TerraformVars["key_management"] = "null"
	options.TerraformVars["enable_hyperthreading"] = strings.ToLower("false")

	// Resource Cleanup Configuration
	options.SkipTestTearDown = true
	defer options.TestTearDown()

	// Cluster Deployment
	deploymentStart := time.Now()
	testLogger.Info(t, "Starting no-KMS/HT-off cluster deployment")

	clusterCreationErr := lsf.VerifyClusterCreationAndConsistency(t, options, testLogger)
	require.NoError(t, clusterCreationErr, "Cluster creation validation failed")

	testLogger.Info(t, fmt.Sprintf("Cluster deployment completed (duration: %v)", time.Since(deploymentStart)))

	// Post-deployment Validation
	validationStart := time.Now()
	lsf.ValidateBasicClusterConfiguration(t, options, testLogger)

	testLogger.Info(t, fmt.Sprintf("Validation completed (duration: %v)", time.Since(validationStart)))

	// Test Result Evaluation
	if t.Failed() {
		testLogger.Error(t, fmt.Sprintf("Test %s failed — inspect validation logs for details", t.Name()))
	} else {
		testLogger.PASS(t, fmt.Sprintf("Test %s completed successfully", t.Name()))
	}
}

// TestRunLSFClusterCreationWithZeroWorkerNodes validates cluster creation with zero worker nodes.
// Verifies proper handling of empty static compute profile and dynamic scaling configuration.
//
// Prerequisites:
// - Valid environment configuration
// - Proper test suite initialization
// - Permissions to create cluster with dynamic scaling
func TestRunLSFClusterCreationWithZeroWorkerNodes(t *testing.T) {
	t.Parallel()

	// Initialization and Setup
	setupTestSuite(t)
	require.NotNil(t, testLogger, "Test logger must be initialized")
	testLogger.Info(t, fmt.Sprintf("Test %s initiated", t.Name()))

	// Environment Configuration
	envVars, err := GetEnvVars()
	require.NoError(t, err, "Must load valid environment configuration")

	// Test Configuration
	options, err := setupOptions(
		t,
		utils.GenerateRandomString(), // Unique cluster prefix
		terraformDir,
		envVars.DefaultExistingResourceGroup,
	)
	require.NoError(t, err, "Must initialize valid test options")

	// Cluster Profile Configuration
	options.TerraformVars = map[string]interface{}{
		"static_compute_instances": []map[string]interface{}{
			{
				"profile":    "cx2-2x4",
				"count":      0,
				"image":      "ibm-redhat-8-10-minimal-amd64-2",
				"filesystem": "/gpfs/fs1",
			},
		},
		"dynamic_compute_instances": []map[string]interface{}{
			{
				"profile": "cx2-2x4",
				"count":   1024,
				"image":   "ibm-redhat-8-10-minimal-amd64-2",
			},
		},
	}

	// Resource Cleanup Configuration
	options.SkipTestTearDown = true
	defer options.TestTearDown()

	// Cluster Deployment
	deploymentStart := time.Now()
	testLogger.Info(t, "Starting zero-worker-node cluster deployment")

	clusterCreationErr := lsf.VerifyClusterCreationAndConsistency(t, options, testLogger)
	require.NoError(t, clusterCreationErr, "Cluster creation validation failed")

	testLogger.Info(t, fmt.Sprintf("Cluster deployment completed (duration: %v)", time.Since(deploymentStart)))

	// Post-deployment Validation
	validationStart := time.Now()
	lsf.ValidateBasicClusterConfigurationWithDynamicProfile(t, options, testLogger)

	testLogger.Info(t, fmt.Sprintf("Validation completed (duration: %v)", time.Since(validationStart)))

	// Test Result Evaluation
	if t.Failed() {
		testLogger.Error(t, fmt.Sprintf("Test %s failed - inspect validation logs for details", t.Name()))
	} else {
		testLogger.PASS(t, fmt.Sprintf("Test %s completed successfully", t.Name()))
	}
}

// TestRunInUsEastRegion validates cluster creation in US East region with b* profile.
// Verifies proper zone configuration and resource deployment in the specified region.
//
// Prerequisites:
// - Valid US East zone configuration
// - Proper test suite initialization
// - Permissions to create resources in US East region
func TestRunInUsEastRegion(t *testing.T) {
	t.Parallel()

	// Initialization and Setup
	setupTestSuite(t)
	require.NotNil(t, testLogger, "Test logger must be initialized")
	testLogger.Info(t, fmt.Sprintf("Test %s initiated", t.Name()))

	// Environment Configuration
	envVars, err := GetEnvVars()
	require.NoError(t, err, "Must load valid environment configuration")

	usEastZone := utils.SplitAndTrim(envVars.USEastZone, ",")
	require.NotEmpty(t, usEastZone, "Must provide valid US East zone configuration")
	testLogger.DEBUG(t, fmt.Sprintf("Using US East zones: %v", usEastZone))

	// Test Configuration
	options, err := setupOptions(
		t,
		utils.GenerateRandomString(), // Unique cluster prefix
		terraformDir,
		envVars.DefaultExistingResourceGroup,
	)
	require.NoError(t, err, "Must initialize valid test options")

	// Region-Specific Configuration
	options.TerraformVars["zones"] = usEastZone

	// Resource Cleanup Configuration
	options.SkipTestTearDown = true
	defer options.TestTearDown()

	// Cluster Deployment
	deploymentStart := time.Now()
	testLogger.Info(t, "Starting US East region cluster deployment")

	clusterCreationErr := lsf.VerifyClusterCreationAndConsistency(t, options, testLogger)
	require.NoError(t, clusterCreationErr, "Cluster creation validation failed")

	testLogger.Info(t, fmt.Sprintf("Cluster deployment completed (duration: %v)", time.Since(deploymentStart)))

	// Post-deployment Validation
	validationStart := time.Now()
	lsf.ValidateBasicClusterConfiguration(t, options, testLogger)

	testLogger.Info(t, fmt.Sprintf("Validation completed (duration: %v)", time.Since(validationStart)))

	// Test Result Evaluation
	if t.Failed() {
		testLogger.Error(t, fmt.Sprintf("Test %s failed - inspect validation logs for details", t.Name()))
	} else {
		testLogger.PASS(t, fmt.Sprintf("Test %s completed successfully", t.Name()))
	}
}

// TestRunInEuDeRegion validates cluster creation in Frankfurt region with c* profile.
// Verifies proper zone configuration and resource deployment in the specified region.
//
// Prerequisites:
// - Valid EU-DE zone configuration
// - Proper test suite initialization
// - Permissions to create resources in EU-DE region
func TestRunInEuDeRegion(t *testing.T) {
	t.Parallel()

	// Initialization and Setup
	setupTestSuite(t)
	require.NotNil(t, testLogger, "Test logger must be initialized")
	testLogger.Info(t, fmt.Sprintf("Test %s initiated", t.Name()))

	// Environment Configuration
	envVars, err := GetEnvVars()
	require.NoError(t, err, "Must load valid environment configuration")

	euDeZone := utils.SplitAndTrim(envVars.EUDEZone, ",")
	require.NotEmpty(t, euDeZone, "Must provide valid Frankfurt zone configuration")
	testLogger.DEBUG(t, fmt.Sprintf("Using Frankfurt zones: %v", euDeZone))

	// Test Configuration
	options, err := setupOptions(
		t,
		utils.GenerateRandomString(), // Unique cluster prefix
		terraformDir,
		envVars.DefaultExistingResourceGroup,
	)
	require.NoError(t, err, "Must initialize valid test options")

	// Region-Specific Configuration
	options.TerraformVars["zones"] = euDeZone

	// Resource Cleanup Configuration
	options.SkipTestTearDown = true
	defer options.TestTearDown()

	// Cluster Deployment
	deploymentStart := time.Now()
	testLogger.Info(t, "Starting EU-DE region cluster deployment")

	clusterCreationErr := lsf.VerifyClusterCreationAndConsistency(t, options, testLogger)
	require.NoError(t, clusterCreationErr, "Cluster creation validation failed")

	testLogger.Info(t, fmt.Sprintf("Cluster deployment completed (duration: %v)", time.Since(deploymentStart)))

	// Post-deployment Validation
	validationStart := time.Now()
	lsf.ValidateBasicClusterConfiguration(t, options, testLogger)

	testLogger.Info(t, fmt.Sprintf("Validation completed (duration: %v)", time.Since(validationStart)))

	// Test Result Evaluation
	if t.Failed() {
		testLogger.Error(t, fmt.Sprintf("Test %s failed - inspect validation logs for details", t.Name()))
	} else {
		testLogger.PASS(t, fmt.Sprintf("Test %s completed successfully", t.Name()))
	}
}

// TestRunInUSSouthRegion validates cluster creation in US South region with m* profile.
// Verifies proper zone configuration and resource deployment in the specified region.
//
// Prerequisites:
// - Valid US South zone configuration
// - Proper test suite initialization
// - Permissions to create resources in US South regionfunc TestRunInUSSouthRegion(t *testing.T) {
func TestRunInUSSouthRegion(t *testing.T) {
	t.Parallel()

	// Initialization and Setup
	setupTestSuite(t)
	require.NotNil(t, testLogger, "Test logger must be initialized")
	testLogger.Info(t, fmt.Sprintf("Test %s initiated", t.Name()))

	// Environment Configuration
	envVars, err := GetEnvVars()
	require.NoError(t, err, "Must load valid environment configuration")

	usSouthZone := utils.SplitAndTrim(envVars.USSouthZone, ",")
	require.NotEmpty(t, usSouthZone, "Must provide valid US South zone configuration")
	testLogger.DEBUG(t, fmt.Sprintf("Using US South zones: %v", usSouthZone))

	// Test Configuration
	options, err := setupOptions(
		t,
		utils.GenerateRandomString(), // Unique cluster prefix
		terraformDir,
		envVars.DefaultExistingResourceGroup,
	)
	require.NoError(t, err, "Must initialize valid test options")

	// Region-Specific Configuration
	options.TerraformVars["zones"] = usSouthZone

	// Resource Cleanup Configuration
	options.SkipTestTearDown = true
	defer options.TestTearDown()

	// Cluster Deployment
	deploymentStart := time.Now()
	testLogger.Info(t, "Starting US South region cluster deployment")

	clusterCreationErr := lsf.VerifyClusterCreationAndConsistency(t, options, testLogger)
	require.NoError(t, clusterCreationErr, "Cluster creation validation failed")

	testLogger.Info(t, fmt.Sprintf("Cluster deployment completed (duration: %v)", time.Since(deploymentStart)))

	// Post-deployment Validation
	validationStart := time.Now()
	lsf.ValidateBasicClusterConfiguration(t, options, testLogger)

	testLogger.Info(t, fmt.Sprintf("Validation completed (duration: %v)", time.Since(validationStart)))

	// Test Result Evaluation
	if t.Failed() {
		testLogger.Error(t, fmt.Sprintf("Test %s failed - inspect validation logs", t.Name()))
	} else {
		testLogger.PASS(t, fmt.Sprintf("Test %s completed successfully", t.Name()))
	}
}

// TestRunInJPTokyoRegion validates cluster creation in Japan Tokyo region with m* profile.
// Verifies proper zone configuration and resource deployment in the specified region.
//
// Prerequisites:
// - Valid Japan Tokyo zone configuration
// - Proper test suite initialization
// - Permissions to create resources in Japan Tokyo region
func TestRunInJPTokyoRegion(t *testing.T) {
	t.Parallel()

	// Initialization and Setup
	setupTestSuite(t)
	require.NotNil(t, testLogger, "Test logger must be initialized")
	testLogger.Info(t, fmt.Sprintf("Test %s initiated", t.Name()))

	// Environment Configuration
	envVars, err := GetEnvVars()
	require.NoError(t, err, "Must load valid environment configuration")

	jpTokyoZone := utils.SplitAndTrim(envVars.JPTokZone, ",")
	require.NotEmpty(t, jpTokyoZone, "Must provide valid Japan Tokyo zone configuration")
	testLogger.DEBUG(t, fmt.Sprintf("Using Japan Tokyo zones: %v", jpTokyoZone))

	// Test Configuration
	options, err := setupOptions(
		t,
		utils.GenerateRandomString(), // Unique cluster prefix
		terraformDir,
		envVars.DefaultExistingResourceGroup,
	)
	require.NoError(t, err, "Must initialize valid test options")

	// Region-Specific Configuration
	options.TerraformVars["zones"] = jpTokyoZone

	// Resource Cleanup Configuration
	options.SkipTestTearDown = true
	defer options.TestTearDown()

	// Cluster Deployment
	deploymentStart := time.Now()
	testLogger.Info(t, "Starting Japan Tokyo region cluster deployment")

	clusterCreationErr := lsf.VerifyClusterCreationAndConsistency(t, options, testLogger)
	require.NoError(t, clusterCreationErr, "Cluster creation validation failed")

	testLogger.Info(t, fmt.Sprintf("Cluster deployment completed (duration: %v)", time.Since(deploymentStart)))

	// Post-deployment Validation
	validationStart := time.Now()
	lsf.ValidateBasicClusterConfiguration(t, options, testLogger)

	testLogger.Info(t, fmt.Sprintf("Validation completed (duration: %v)", time.Since(validationStart)))

	// Test Result Evaluation
	if t.Failed() {
		testLogger.Error(t, fmt.Sprintf("Test %s failed - inspect validation logs", t.Name()))
	} else {
		testLogger.PASS(t, fmt.Sprintf("Test %s completed successfully", t.Name()))
	}
}

// TestRunLDAP validates cluster creation with LDAP authentication enabled.
// Verifies proper LDAP configuration and user authentication functionality.
//
// Prerequisites:
// - LDAP enabled in environment configuration
// - Valid LDAP credentials (admin password, username, user password)
// - Proper test suite initialization
func TestRunLDAP(t *testing.T) {
	t.Parallel()

	// Initialization and Setup
	setupTestSuite(t)
	require.NotNil(t, testLogger, "Test logger must be initialized")
	testLogger.Info(t, fmt.Sprintf("Test %s initiated", t.Name()))

	// Load Environment Configuration
	envVars, err := GetEnvVars()
	require.NoError(t, err, "Must load valid environment configuration")

	// Validate LDAP Configuration
	require.Equal(t, "true", strings.ToLower(envVars.EnableLdap), "LDAP must be enabled for this test")
	require.NotEmpty(t, envVars.LdapAdminPassword, "LDAP admin password must be provided")
	require.NotEmpty(t, envVars.LdapUserName, "LDAP username must be provided")
	require.NotEmpty(t, envVars.LdapUserPassword, "LDAP user password must be provided")

	// Prepare Cluster Options
	clusterPrefix := utils.GenerateRandomString()
	testLogger.Info(t, fmt.Sprintf("Generated cluster prefix: %s", clusterPrefix))

	options, err := setupOptions(
		t,
		clusterPrefix,
		terraformDir,
		envVars.DefaultExistingResourceGroup,
	)
	require.NoError(t, err, "Must initialize valid test options")

	// Set LDAP Terraform Variables
	options.TerraformVars["enable_ldap"] = strings.ToLower(envVars.EnableLdap)
	options.TerraformVars["ldap_basedns"] = envVars.LdapAdminPassword        // pragma: allowlist secret
	options.TerraformVars["ldap_admin_password"] = envVars.LdapAdminPassword // pragma: allowlist secret
	options.TerraformVars["ldap_user_name"] = envVars.LdapUserName
	options.TerraformVars["ldap_user_password"] = envVars.LdapUserPassword // pragma: allowlist secret

	// Configure Resource Cleanup
	options.SkipTestTearDown = true
	defer options.TestTearDown()

	// Cluster Deployment
	deploymentStart := time.Now()
	testLogger.Info(t, "Starting LDAP cluster deployment")

	clusterCreationErr := lsf.VerifyClusterCreationAndConsistency(t, options, testLogger)
	require.NoError(t, clusterCreationErr, "Cluster creation validation failed")

	testLogger.Info(t, fmt.Sprintf("Cluster deployment completed (duration: %v)", time.Since(deploymentStart)))

	// Post-deployment Validation
	validationStart := time.Now()
	lsf.ValidateLDAPClusterConfiguration(t, options, testLogger)
	testLogger.Info(t, fmt.Sprintf("Validation completed (duration: %v)", time.Since(validationStart)))

	// Final Result Evaluation
	if t.Failed() {
		testLogger.Error(t, fmt.Sprintf("Test %s failed - inspect validation logs", t.Name()))
	} else {
		testLogger.PASS(t, fmt.Sprintf("Test %s completed successfully", t.Name()))
	}
}

// TestRunUsingExistingKMS validates cluster creation with existing Key Protect service instance.
// Verifies proper KMS integration and encryption functionality.
//
// Prerequisites:
// - Valid IBM Cloud API key
// - Permissions to create/delete KMS instances
// - Proper test suite initialization
func TestRunUsingExistingKMS(t *testing.T) {
	t.Parallel()

	// Initialization
	setupTestSuite(t)
	require.NotNil(t, testLogger, "Test logger must be initialized")
	testLogger.Info(t, fmt.Sprintf("Test %s initiated", t.Name()))

	// Load Environment Configuration
	envVars, err := GetEnvVars()
	require.NoError(t, err, "Must load valid environment configuration")

	// KMS Setup
	const (
		keyManagementType = "key_protect"
		kmsKeyName        = KMS_KEY_NAME
	)

	kmsInstanceName := "cicd-" + utils.GenerateRandomString()
	clusterPrefix := utils.GenerateRandomString()
	apiKey := os.Getenv("TF_VAR_ibmcloud_api_key")
	require.NotEmpty(t, apiKey, "IBM Cloud API key must be set")

	region := utils.GetRegion(envVars.Zones)
	testLogger.Info(t, fmt.Sprintf("Creating KMS instance: %s in region: %s", kmsInstanceName, region))

	err = lsf.CreateServiceInstanceAndKmsKey(
		t,
		apiKey,
		region,
		envVars.DefaultExistingResourceGroup,
		kmsInstanceName,
		kmsKeyName,
		testLogger,
	)
	require.NoError(t, err, "Must create KMS service instance and key")

	// Cleanup KMS instance after test
	defer func() {
		testLogger.Info(t, fmt.Sprintf("Deleting KMS instance: %s", kmsInstanceName))
		lsf.DeleteServiceInstanceAndAssociatedKeys(
			t,
			apiKey,
			region,
			envVars.DefaultExistingResourceGroup,
			kmsInstanceName,
			testLogger,
		)
	}()

	// Prepare Test Options
	testLogger.Info(t, fmt.Sprintf("Generated cluster prefix: %s", clusterPrefix))
	options, err := setupOptions(
		t,
		clusterPrefix,
		terraformDir,
		envVars.DefaultExistingResourceGroup,
	)
	require.NoError(t, err, "Must initialize valid test options")

	// Set KMS Terraform Variables
	options.TerraformVars["key_management"] = keyManagementType
	options.TerraformVars["kms_instance_name"] = kmsInstanceName
	options.TerraformVars["kms_key_name"] = kmsKeyName

	// Cluster Teardown Configuration
	options.SkipTestTearDown = true
	defer options.TestTearDown()

	// Cluster Deployment
	deploymentStart := time.Now()
	testLogger.Info(t, "Starting KMS integration cluster deployment")

	clusterCreationErr := lsf.VerifyClusterCreationAndConsistency(t, options, testLogger)
	require.NoError(t, clusterCreationErr, "Cluster creation validation failed")

	testLogger.Info(t, fmt.Sprintf("Cluster deployment completed (duration: %v)", time.Since(deploymentStart)))

	// Post-deployment Validation
	validationStart := time.Now()
	lsf.ValidateBasicClusterConfiguration(t, options, testLogger)
	testLogger.Info(t, fmt.Sprintf("Validation completed (duration: %v)", time.Since(validationStart)))

	// Final Result
	if t.Failed() {
		testLogger.Error(t, fmt.Sprintf("Test %s failed - inspect validation logs", t.Name()))
	} else {
		testLogger.PASS(t, fmt.Sprintf("Test %s completed successfully", t.Name()))
	}
}

// TestRunUsingExistingKMSInstanceIDAndWithoutKey validates cluster creation with existing KMS instance but no key.
// Verifies proper handling of KMS instance without specified key.
//
// Prerequisites:
// - Valid IBM Cloud API key
// - Permissions to create/delete KMS instances
// - Proper test suite initialization
func TestRunUsingExistingKMSInstanceIDAndWithoutKey(t *testing.T) {
	t.Parallel()

	// Initialization
	setupTestSuite(t)
	require.NotNil(t, testLogger, "Test logger must be initialized")
	testLogger.Info(t, fmt.Sprintf("Test %s initiated", t.Name()))

	// Load Environment Variables
	envVars, err := GetEnvVars()
	require.NoError(t, err, "Must load valid environment configuration")

	// KMS Setup
	kmsInstanceName := "cicd-" + utils.GenerateRandomString()
	apiKey := os.Getenv("TF_VAR_ibmcloud_api_key")
	require.NotEmpty(t, apiKey, "IBM Cloud API key must be set")

	region := utils.GetRegion(envVars.Zones)

	testLogger.Info(t, fmt.Sprintf("Creating KMS instance: %s", kmsInstanceName))
	err = lsf.CreateServiceInstanceAndKmsKey(
		t,
		apiKey,
		region,
		envVars.DefaultExistingResourceGroup,
		kmsInstanceName,
		KMS_KEY_NAME,
		testLogger,
	)
	require.NoError(t, err, "Must create KMS service instance and key")

	// Ensure cleanup of KMS instance and keys
	defer func() {
		testLogger.Info(t, fmt.Sprintf("Deleting KMS instance: %s", kmsInstanceName))
		lsf.DeleteServiceInstanceAndAssociatedKeys(
			t,
			apiKey,
			region,
			envVars.DefaultExistingResourceGroup,
			kmsInstanceName,
			testLogger,
		)
	}()

	// Test Options Configuration
	options, err := setupOptions(
		t,
		utils.GenerateRandomString(), // Unique cluster prefix
		terraformDir,
		envVars.DefaultExistingResourceGroup,
	)
	require.NoError(t, err, "Must initialize valid test options")

	// KMS Variables (no key)
	options.TerraformVars["key_management"] = "key_protect"
	options.TerraformVars["kms_instance_name"] = kmsInstanceName

	// Cluster Teardown Configuration
	options.SkipTestTearDown = true
	defer options.TestTearDown()

	// Cluster Deployment
	deploymentStart := time.Now()
	testLogger.Info(t, "Starting KMS integration cluster deployment (without key)")

	clusterCreationErr := lsf.VerifyClusterCreationAndConsistency(t, options, testLogger)
	require.NoError(t, clusterCreationErr, "Cluster creation validation failed")

	testLogger.Info(t, fmt.Sprintf("Cluster deployment completed (duration: %v)", time.Since(deploymentStart)))

	// Post-deployment Validation
	validationStart := time.Now()
	lsf.ValidateBasicClusterConfiguration(t, options, testLogger)
	testLogger.Info(t, fmt.Sprintf("Validation completed (duration: %v)", time.Since(validationStart)))

	// Test Result
	if t.Failed() {
		testLogger.Error(t, fmt.Sprintf("Test %s failed - inspect validation logs", t.Name()))
	} else {
		testLogger.PASS(t, fmt.Sprintf("Test %s completed successfully", t.Name()))
	}
}

// TestRunLDAPAndPac validates cluster creation with both LDAP and Application Center enabled.
// Verifies proper integration of both features in the cluster configuration.
//
// Prerequisites:
// - Both LDAP and Application Center enabled in configuration
// - Valid credentials for both services
// - Proper test suite initialization
func TestRunLDAPAndPac(t *testing.T) {
	t.Parallel()

	const enabledFlag = "true"

	// Initialization
	setupTestSuite(t)
	require.NotNil(t, testLogger, "Test logger must be initialized")
	testLogger.Info(t, fmt.Sprintf("Test %s initiated", t.Name()))

	// Load Environment Variables
	envVars, err := GetEnvVars()
	require.NoError(t, err, "Must load valid environment configuration")

	// Pre-check flags (lowercased comparison)
	enableLDAP := strings.ToLower(envVars.EnableLdap) == enabledFlag
	enablePAC := strings.ToLower(envVars.EnableAppCenter) == enabledFlag

	// Validate feature flags
	require.True(t, enableLDAP, "LDAP must be enabled for this test")
	require.True(t, enablePAC, "Application Center must be enabled for this test")

	// Required Credentials Validation
	require.NotEmpty(t, envVars.LdapAdminPassword, "LDAP admin password must be provided")
	require.NotEmpty(t, envVars.LdapUserName, "LDAP username must be provided")
	require.NotEmpty(t, envVars.LdapUserPassword, "LDAP user password must be provided")
	require.NotEmpty(t, envVars.AppCenterGuiPassword, "Application Center GUI password must be provided")

	// Unique Cluster Prefix
	clusterPrefix := utils.GenerateRandomString()
	testLogger.Info(t, fmt.Sprintf("Generated cluster prefix: %s", clusterPrefix))

	// Test Options Setup
	options, err := setupOptions(
		t,
		clusterPrefix,
		terraformDir,
		envVars.DefaultExistingResourceGroup,
	)
	require.NoError(t, err, "Must initialize valid test options")

	// Terraform Variables Configuration
	options.TerraformVars["enable_app_center"] = strings.ToLower(envVars.EnableAppCenter)
	options.TerraformVars["app_center_gui_pwd"] = envVars.AppCenterGuiPassword //pragma: allowlist secret
	options.TerraformVars["enable_ldap"] = strings.ToLower(envVars.EnableLdap)
	options.TerraformVars["ldap_basedns"] = envVars.LdapBaseDns
	options.TerraformVars["ldap_admin_password"] = envVars.LdapAdminPassword //pragma: allowlist secret
	options.TerraformVars["ldap_user_name"] = envVars.LdapUserName
	options.TerraformVars["ldap_user_password"] = envVars.LdapUserPassword //pragma: allowlist secret

	// Defer Cluster Cleanup
	options.SkipTestTearDown = true
	defer options.TestTearDown()

	// Cluster Deployment
	deploymentStart := time.Now()
	testLogger.Info(t, "Starting cluster deployment with LDAP and Application Center enabled")

	clusterCreationErr := lsf.VerifyClusterCreationAndConsistency(t, options, testLogger)
	require.NoError(t, clusterCreationErr, "Cluster creation validation failed")

	testLogger.Info(t, fmt.Sprintf("Cluster deployment completed in %v", time.Since(deploymentStart)))

	// Post-deployment Validation
	validationStart := time.Now()
	lsf.ValidatePACANDLDAPClusterConfiguration(t, options, testLogger)
	testLogger.Info(t, fmt.Sprintf("Cluster validation completed in %v", time.Since(validationStart)))

	// Test Outcome
	if t.Failed() {
		testLogger.Error(t, fmt.Sprintf("Test %s failed - check logs for details", t.Name()))
	} else {
		testLogger.PASS(t, fmt.Sprintf("Test %s completed successfully", t.Name()))
	}
}

// TestRunCosAndVpcFlowLogs validates cluster creation with COS integration and VPC flow logs enabled.
// Verifies proper configuration of both features and their integration with the cluster.
//
// Prerequisites:
// - Valid environment configuration
// - Proper test suite initialization
// - Permissions to enable COS and VPC flow logs
func TestRunCosAndVpcFlowLogs(t *testing.T) {
	t.Parallel()

	// Initialization and Setup
	setupTestSuite(t)
	require.NotNil(t, testLogger, "Test logger must be initialized")
	testLogger.Info(t, fmt.Sprintf("Test %s initiated", t.Name()))

	// Load Environment Configuration
	envVars, err := GetEnvVars()
	require.NoError(t, err, "Must load valid environment configuration")

	// Unique Cluster Prefix
	clusterPrefix := utils.GenerateRandomString()
	testLogger.Info(t, fmt.Sprintf("Generated cluster prefix: %s", clusterPrefix))

	// Setup Test Options
	options, err := setupOptions(
		t,
		clusterPrefix,
		terraformDir,
		envVars.DefaultExistingResourceGroup,
	)
	require.NoError(t, err, "Must initialize valid test options")

	// Terraform Input Variables
	options.TerraformVars["enable_cos_integration"] = true
	options.TerraformVars["enable_vpc_flow_logs"] = true

	// Skip resource teardown to retain cluster for debugging if needed
	options.SkipTestTearDown = true
	defer options.TestTearDown()

	// Cluster Deployment
	deploymentStart := time.Now()
	testLogger.Info(t, "Starting cluster deployment with COS and VPC Flow Logs enabled")

	clusterCreationErr := lsf.VerifyClusterCreationAndConsistency(t, options, testLogger)
	require.NoError(t, clusterCreationErr, "Cluster creation validation failed")

	testLogger.Info(t, fmt.Sprintf("Cluster deployment completed in %v", time.Since(deploymentStart)))

	// Post-deployment Validation
	validationStart := time.Now()
	lsf.ValidateBasicClusterConfigurationWithVPCFlowLogsAndCos(t, options, testLogger)
	testLogger.Info(t, fmt.Sprintf("Cluster validation completed in %v", time.Since(validationStart)))

	// Test Result Evaluation
	if t.Failed() {
		testLogger.Error(t, fmt.Sprintf("Test %s failed - inspect validation logs", t.Name()))
	} else {
		testLogger.PASS(t, fmt.Sprintf("Test %s completed successfully", t.Name()))
	}
}

// TestRunMultipleSSHKeys validates cluster creation with multiple SSH keys configured.
// Verifies proper handling and authentication with multiple SSH keys.
//
// Prerequisites:
// - Valid environment configuration
// - Proper test suite initialization
// - Multiple SSH keys configured in environment
func TestRunMultipleSSHKeys(t *testing.T) {
	t.Parallel()

	// Initialization and Setup
	setupTestSuite(t)
	require.NotNil(t, testLogger, "Test logger must be initialized")
	testLogger.Info(t, fmt.Sprintf("Test %s initiated", t.Name()))

	// Environment Configuration
	envVars, err := GetEnvVars()
	require.NoError(t, err, "Must load valid environment configuration")

	// Test Configuration
	options, err := setupOptions(
		t,
		utils.GenerateRandomString(), // Unique cluster prefix
		terraformDir,
		envVars.DefaultExistingResourceGroup,
	)
	require.NoError(t, err, "Must initialize valid test options")

	// Resource Cleanup Configuration
	options.SkipTestTearDown = true
	defer options.TestTearDown()

	// Post-deployment Validation
	validationStart := time.Now()
	testLogger.Info(t, "Starting multiple SSH keys cluster deployment")

	lsf.ValidateClusterConfigurationWithMultipleKeys(t, options, testLogger)

	testLogger.Info(t, fmt.Sprintf("Validation completed (duration: %v)", time.Since(validationStart)))

	// Test Result Evaluation
	if t.Failed() {
		testLogger.Error(t, fmt.Sprintf("Test %s failed - inspect validation logs", t.Name()))
	} else {
		testLogger.PASS(t, fmt.Sprintf("Test %s completed successfully", t.Name()))
	}
}

// TestRunExistingLDAP validates cluster creation with existing LDAP integration.
// Verifies proper configuration of LDAP authentication with an existing LDAP server.
//
// Prerequisites:
// - LDAP enabled in environment configuration
// - Valid LDAP credentials
// - Existing LDAP server configuration
// - Proper test suite initialization
func TestRunExistingLDAP(t *testing.T) {
	t.Parallel()

	// Initialization and Setup
	setupTestSuite(t)
	require.NotNil(t, testLogger, "Test logger must be initialized")
	testLogger.Info(t, fmt.Sprintf("Test %s initiated", t.Name()))

	// Environment Configuration
	envVars, err := GetEnvVars()
	require.NoError(t, err, "Must load valid environment configuration")

	// LDAP Validation
	require.Equal(t, "true", strings.ToLower(envVars.EnableLdap), "LDAP must be enabled for this test")
	require.NotEmpty(t, envVars.LdapAdminPassword, "LDAP admin password must be provided")
	require.NotEmpty(t, envVars.LdapUserName, "LDAP username must be provided")
	require.NotEmpty(t, envVars.LdapUserPassword, "LDAP user password must be provided")

	// First Cluster Configuration
	hpcClusterPrefix := utils.GenerateRandomString()
	options1, err := setupOptions(t, hpcClusterPrefix, terraformDir, envVars.DefaultExistingResourceGroup)
	require.NoError(t, err, "Must initialize valid test options for first cluster")

	// First Cluster LDAP Configuration
	options1.TerraformVars = map[string]interface{}{
		"management_node_count":  1,
		"enable_ldap":            strings.ToLower(envVars.EnableLdap),
		"ldap_basedns":           envVars.LdapBaseDns,
		"ldap_admin_password":    envVars.LdapAdminPassword, // pragma: allowlist secret
		"ldap_user_name":         envVars.LdapUserName,
		"ldap_user_password":     envVars.LdapUserPassword, // pragma: allowlist secret
		"key_management":         "null",
		"enable_cos_integration": false,
		"enable_vpc_flow_logs":   false,
	}

	// First Cluster Cleanup
	options1.SkipTestTearDown = true
	defer options1.TestTearDown()

	// First Cluster Validation
	output, err := options1.RunTest()
	require.NoError(t, err, "First cluster validation failed")
	require.NotNil(t, output, "First cluster validation returned nil output")

	// LDAP Server Configuration
	customResolverID, err := utils.GetCustomResolverID(t, os.Getenv("TF_VAR_ibmcloud_api_key"), utils.GetRegion(envVars.Zones), envVars.DefaultExistingResourceGroup, hpcClusterPrefix, testLogger)
	require.NoError(t, err, "Must retrieve custom resolver ID")

	ldapIP, err := utils.GetLdapIP(t, options1, testLogger)
	require.NoError(t, err, "Must retrieve LDAP IP address")

	ldapServerBastionIP, err := utils.GetBastionIP(t, options1, testLogger)
	require.NoError(t, err, "Must retrieve LDAP server bastion IP")

	err = utils.RetrieveAndUpdateSecurityGroup(t, os.Getenv("TF_VAR_ibmcloud_api_key"), utils.GetRegion(envVars.Zones), envVars.DefaultExistingResourceGroup, hpcClusterPrefix, "10.241.0.0/18", "389", "389", testLogger)
	require.NoError(t, err, "Must update security group")

	// Second Cluster Configuration
	hpcClusterPrefix2 := utils.GenerateRandomString()
	options2, err := setupOptions(t, hpcClusterPrefix2, terraformDir, envVars.DefaultExistingResourceGroup)
	require.NoError(t, err, "Must initialize valid test options for second cluster")

	// LDAP Certificate Retrieval
	ldapServerCert, serverCertErr := lsf.GetLDAPServerCert(lsf.LSF_PUBLIC_HOST_NAME, ldapServerBastionIP, lsf.LSF_LDAP_HOST_NAME, ldapIP)
	require.NoError(t, serverCertErr, "Must retrieve LDAP server certificate")

	// Second Cluster LDAP Configuration
	options2.TerraformVars = map[string]interface{}{
		"vpc_name": options1.TerraformVars["cluster_prefix"].(string) + "-lsf-vpc",
		"vpc_cluster_private_subnets_cidr_blocks":       []string{CLUSTER_TWO_VPC_CLUSTER_PRIVATE_SUBNETS_CIDR_BLOCKS},
		"vpc_cluster_login_private_subnets_cidr_blocks": []string{CLUSTER_TWO_VPC_CLUSTER_LOGIN_PRIVATE_SUBNETS_CIDR_BLOCKS},
		"management_node_count":                         2,
		"dns_domain_name":                               map[string]string{"compute": CLUSTER_TWO_DNS_DOMAIN_NAME},
		"dns_custom_resolver_id":                        customResolverID,
		"enable_ldap":                                   strings.ToLower(envVars.EnableLdap),
		"ldap_basedns":                                  envVars.LdapBaseDns,
		"ldap_server":                                   ldapIP,
		"ldap_server_cert":                              strings.TrimSpace(ldapServerCert),
	}

	// Second Cluster Cleanup
	options2.SkipTestTearDown = true
	defer options2.TestTearDown()

	// Second Cluster Validation
	validationStart := time.Now()
	testLogger.Info(t, "Starting existing LDAP validation for second cluster")

	lsf.ValidateExistingLDAPClusterConfig(t, ldapServerBastionIP, ldapIP, envVars.LdapBaseDns, envVars.LdapAdminPassword, envVars.LdapUserName, envVars.LdapUserPassword, options2, testLogger)

	testLogger.Info(t, fmt.Sprintf("Validation completed (duration: %v)", time.Since(validationStart)))

	// Test Result Evaluation
	if t.Failed() {
		testLogger.Error(t, fmt.Sprintf("Test %s failed - inspect validation logs", t.Name()))
	} else {
		testLogger.PASS(t, fmt.Sprintf("Test %s completed successfully", t.Name()))
	}
}

// TestRunLSFLogs validates proper configuration of LSF management logs.
// Verifies log directory structure, symbolic links, and log collection.
//
// Prerequisites:
// - Valid environment configuration
// - Cluster with at least two management nodes
// - Proper test suite initialization
func TestRunLSFLogs(t *testing.T) {
	t.Parallel()

	// Initialization and Setup
	setupTestSuite(t)
	require.NotNil(t, testLogger, "Test logger must be initialized")
	testLogger.Info(t, fmt.Sprintf("Test %s initiated", t.Name()))

	// Load Environment Configuration
	envVars, err := GetEnvVars()
	require.NoError(t, err, "Must load valid environment configuration")

	// Unique Cluster Prefix
	clusterPrefix := utils.GenerateRandomString()
	testLogger.Info(t, fmt.Sprintf("Generated cluster prefix: %s", clusterPrefix))

	// Setup Test Options
	options, err := setupOptions(
		t,
		clusterPrefix,
		terraformDir,
		envVars.DefaultExistingResourceGroup,
	)
	require.NoError(t, err, "Must initialize valid test options")

	// Skip resource teardown to allow for post-run inspection
	options.SkipTestTearDown = true
	defer options.TestTearDown()

	// Cluster Deployment
	deploymentStart := time.Now()
	testLogger.Info(t, "Starting LSF logs cluster deployment")

	clusterCreationErr := lsf.VerifyClusterCreationAndConsistency(t, options, testLogger)
	require.NoError(t, clusterCreationErr, "Cluster creation validation failed")

	testLogger.Info(t, fmt.Sprintf("Cluster deployment completed in %v", time.Since(deploymentStart)))

	// Post-deployment Validation
	validationStart := time.Now()
	lsf.ValidateBasicClusterConfigurationLSFLogs(t, options, testLogger)
	testLogger.Info(t, fmt.Sprintf("Cluster validation completed in %v", time.Since(validationStart)))

	// Test Result Evaluation
	if t.Failed() {
		testLogger.Error(t, fmt.Sprintf("Test %s failed - inspect validation logs", t.Name()))
	} else {
		testLogger.PASS(t, fmt.Sprintf("Test %s completed successfully", t.Name()))
	}
}

// TestRunDedicatedHost validates cluster creation with dedicated hosts.
// Verifies proper provisioning and configuration of dedicated host resources.
//
// Prerequisites:
// - Valid environment configuration
// - Proper test suite initialization
// - Permissions to create dedicated hosts
func TestRunDedicatedHost(t *testing.T) {
	t.Parallel()

	// Initialization and Setup
	setupTestSuite(t)
	require.NotNil(t, testLogger, "Test logger must be initialized")
	testLogger.Info(t, fmt.Sprintf("Test %s initiated", t.Name()))

	// Load Environment Configuration
	envVars, err := GetEnvVars()
	require.NoError(t, err, "Must load valid environment configuration")

	// Unique Cluster Prefix
	clusterPrefix := utils.GenerateRandomString()
	testLogger.Info(t, fmt.Sprintf("Generated cluster prefix: %s", clusterPrefix))

	// Setup Test Options
	options, err := setupOptions(
		t,
		clusterPrefix,
		terraformDir,
		envVars.DefaultExistingResourceGroup,
	)
	require.NoError(t, err, "Must initialize valid test options")

	// Dedicated Host and Compute Configuration
	options.TerraformVars = map[string]interface{}{
		"enable_dedicated_host": true,
		"static_compute_instances": []map[string]interface{}{
			{
				"profile":    "cx2-2x4",
				"count":      0,
				"image":      "ibm-redhat-8-10-minimal-amd64-2",
				"filesystem": "/gpfs/fs1",
			},
		},
		"dynamic_compute_instances": []map[string]interface{}{
			{
				"profile": "cx2-2x4",
				"count":   1024,
				"image":   "ibm-redhat-8-10-minimal-amd64-2",
			},
		},
	}

	// Skip resource teardown for inspection
	options.SkipTestTearDown = true
	defer options.TestTearDown()

	// Cluster Deployment
	deploymentStart := time.Now()
	testLogger.Info(t, "Starting dedicated host cluster deployment")

	clusterCreationErr := lsf.VerifyClusterCreationAndConsistency(t, options, testLogger)
	require.NoError(t, clusterCreationErr, "Cluster creation validation failed")

	testLogger.Info(t, fmt.Sprintf("Cluster deployment completed in %v", time.Since(deploymentStart)))

	// Post-deployment Validation
	validationStart := time.Now()
	lsf.ValidateBasicClusterConfigurationWithDedicatedHost(t, options, true, testLogger)
	testLogger.Info(t, fmt.Sprintf("Cluster validation completed in %v", time.Since(validationStart)))

	// Test Outcome Evaluation
	if t.Failed() {
		testLogger.Error(t, fmt.Sprintf("Test %s failed - inspect validation logs", t.Name()))
	} else {
		testLogger.PASS(t, fmt.Sprintf("Test %s completed successfully", t.Name()))
	}
}

// TestRunObservabilityCloudLogsManagementAndComputeEnabled validates cluster creation with
// observability logs enabled for both management and compute nodes.
//
// Prerequisites:
// - Valid environment configuration
// - Proper test suite initialization
// - Permissions to enable observability features
func TestRunObservabilityCloudLogsManagementAndComputeEnabled(t *testing.T) {
	t.Parallel()

	// Initialization and Setup
	setupTestSuite(t)
	require.NotNil(t, testLogger, "Test logger must be initialized")
	testLogger.Info(t, fmt.Sprintf("Test %s initiated", t.Name()))

	// Load Environment Configuration
	envVars, err := GetEnvVars()
	require.NoError(t, err, "Must load valid environment configuration")

	// Unique Cluster Prefix
	clusterPrefix := utils.GenerateRandomString()
	testLogger.Info(t, fmt.Sprintf("Generated cluster prefix: %s", clusterPrefix))

	// Setup Test Options
	options, err := setupOptions(
		t,
		clusterPrefix,
		terraformDir,
		envVars.DefaultExistingResourceGroup,
	)
	require.NoError(t, err, "Must initialize valid test options")

	// Observability Configuration
	// Configure the observability settings for management and compute logs, with platform logs and monitoring disabled
	options.TerraformVars["observability_logs_enable_for_management"] = true // management logs enabled
	options.TerraformVars["observability_logs_enable_for_compute"] = true    // compute logs enabled
	options.TerraformVars["observability_enable_platform_logs"] = false      // platform logs disabled
	options.TerraformVars["observability_monitoring_enable"] = false         // Monitoring disabled

	// Skip resource teardown for inspection
	options.SkipTestTearDown = true
	defer options.TestTearDown()

	// Cluster Deployment
	deploymentStart := time.Now()
	testLogger.Info(t, "Starting observability logs validation (management + compute)")

	clusterCreationErr := lsf.VerifyClusterCreationAndConsistency(t, options, testLogger)
	require.NoError(t, clusterCreationErr, "Cluster creation validation failed")

	testLogger.Info(t, fmt.Sprintf("Cluster deployment completed in %v", time.Since(deploymentStart)))

	// Post-deployment Validation
	validationStart := time.Now()
	lsf.ValidateBasicClusterConfigurationWithCloudLogs(t, options, testLogger)
	testLogger.Info(t, fmt.Sprintf("Validation completed in %v", time.Since(validationStart)))

	// Test Result Evaluation
	if t.Failed() {
		testLogger.Error(t, fmt.Sprintf("Test %s failed - inspect validation logs", t.Name()))
	} else {
		testLogger.PASS(t, fmt.Sprintf("Test %s completed successfully", t.Name()))
	}
}

// TestRunObservabilityCloudLogsManagementEnabled validates cluster creation with
// observability logs enabled only for management nodes.
//
// Prerequisites:
// - Valid environment configuration
// - Proper test suite initialization
// - Permissions to enable observability features
func TestRunObservabilityCloudLogsManagementEnabled(t *testing.T) {
	t.Parallel()

	// Initialization and Setup
	setupTestSuite(t)
	require.NotNil(t, testLogger, "Test logger must be initialized")
	testLogger.Info(t, fmt.Sprintf("Test %s initiated", t.Name()))

	// Load Environment Configuration
	envVars, err := GetEnvVars()
	require.NoError(t, err, "Must load valid environment configuration")

	// Unique Cluster Prefix
	clusterPrefix := utils.GenerateRandomString()
	testLogger.Info(t, fmt.Sprintf("Generated cluster prefix: %s", clusterPrefix))

	// Setup Test Options
	options, err := setupOptions(
		t,
		clusterPrefix,
		terraformDir,
		envVars.DefaultExistingResourceGroup,
	)
	require.NoError(t, err, "Must initialize valid test options")

	// Check for existing platform logs
	platformLogsExist, err := lsf.CheckPlatformLogsPresent(
		t,
		os.Getenv("TF_VAR_ibmcloud_api_key"),
		utils.GetRegion(envVars.Zones),
		envVars.DefaultExistingResourceGroup,
		testLogger,
	)
	require.NoError(t, err, "Must check platform logs status")
	testLogger.DEBUG(t, fmt.Sprintf("Platform logs exist: %v", platformLogsExist))

	// Observability Configuration
	options.TerraformVars["observability_logs_enable_for_management"] = true // management logs enabled
	options.TerraformVars["observability_logs_enable_for_compute"] = false   // compute logs disabled
	options.TerraformVars["observability_monitoring_enable"] = false         // Monitoring disabled
	//options.TerraformVars["observability_enable_platform_logs"]=!platformLogsExist,

	// Skip resource teardown for inspection
	options.SkipTestTearDown = true
	defer options.TestTearDown()

	// Cluster Deployment
	deploymentStart := time.Now()
	testLogger.Info(t, "Starting observability logs validation (management only)")

	clusterCreationErr := lsf.VerifyClusterCreationAndConsistency(t, options, testLogger)
	require.NoError(t, clusterCreationErr, "Cluster creation validation failed")
	testLogger.Info(t, fmt.Sprintf("Cluster deployment completed in %v", time.Since(deploymentStart)))

	// Post-deployment Validation
	validationStart := time.Now()
	lsf.ValidateBasicClusterConfigurationWithCloudLogs(t, options, testLogger)
	testLogger.Info(t, fmt.Sprintf("Validation completed in %v", time.Since(validationStart)))

	// Test Result Evaluation
	if t.Failed() {
		testLogger.Error(t, fmt.Sprintf("Test %s failed - inspect validation logs", t.Name()))
	} else {
		testLogger.PASS(t, fmt.Sprintf("Test %s completed successfully", t.Name()))
	}
}

// TestRunObservabilityCloudLogsManagementAndComputeDisabled validates cluster creation with
// observability logs disabled for both management and compute nodes.
//
// Prerequisites:
// - Valid environment configuration
// - Proper test suite initialization

func TestRunObservabilityCloudLogsManagementAndComputeDisabled(t *testing.T) {
	t.Parallel()

	// Initialization and Setup
	setupTestSuite(t)
	require.NotNil(t, testLogger, "Test logger must be initialized")
	testLogger.Info(t, fmt.Sprintf("Test %s initiated", t.Name()))

	// Load Environment Configuration
	envVars, err := GetEnvVars()
	require.NoError(t, err, "Must load valid environment configuration")

	// Unique Cluster Prefix
	clusterPrefix := utils.GenerateRandomString()
	testLogger.Info(t, fmt.Sprintf("Generated cluster prefix: %s", clusterPrefix))

	// Setup Test Options
	options, err := setupOptions(
		t,
		clusterPrefix,
		terraformDir,
		envVars.DefaultExistingResourceGroup,
	)
	require.NoError(t, err, "Must initialize valid test options")

	// Observability Configuration - Fully Disabled
	// Configure observability settings:
	options.TerraformVars["observability_logs_enable_for_management"] = false // Management logs disabled
	options.TerraformVars["observability_logs_enable_for_compute"] = false    // Compute logs disabled
	options.TerraformVars["observability_monitoring_enable"] = false          // Monitoring disabled
	options.TerraformVars["observability_enable_platform_logs"] = false       // Platform logs disabled

	// Skip resource teardown for debugging/inspection
	options.SkipTestTearDown = true
	defer options.TestTearDown()

	// Cluster Deployment
	deploymentStart := time.Now()
	testLogger.Info(t, "Starting observability logs validation (fully disabled)")

	clusterCreationErr := lsf.VerifyClusterCreationAndConsistency(t, options, testLogger)
	require.NoError(t, clusterCreationErr, "Cluster creation validation failed")
	testLogger.Info(t, fmt.Sprintf("Cluster deployment completed in %v", time.Since(deploymentStart)))

	// Post-deployment Validation
	validationStart := time.Now()
	lsf.ValidateBasicClusterConfigurationWithCloudLogs(t, options, testLogger)
	testLogger.Info(t, fmt.Sprintf("Validation completed in %v", time.Since(validationStart)))

	// Test Result Evaluation
	if t.Failed() {
		testLogger.Error(t, fmt.Sprintf("Test %s failed - inspect validation logs", t.Name()))
	} else {
		testLogger.PASS(t, fmt.Sprintf("Test %s completed successfully", t.Name()))
	}
}

// TestRunObservabilityMonitoringForManagementAndComputeEnabled validates cluster creation with
// observability monitoring enabled for both management and compute nodes.
//
// Prerequisites:
// - Valid environment configuration
// - Proper test suite initialization
// - Permissions to enable monitoring features
func TestRunObservabilityMonitoringForManagementAndComputeEnabled(t *testing.T) {
	t.Parallel()

	// Initialization and Setup
	setupTestSuite(t)
	require.NotNil(t, testLogger, "Test logger must be initialized")
	testLogger.Info(t, fmt.Sprintf("Test %s initiated", t.Name()))

	// Environment Configuration
	envVars, err := GetEnvVars()
	require.NoError(t, err, "Must load valid environment configuration")

	// Unique Cluster Prefix
	clusterPrefix := utils.GenerateRandomString()
	testLogger.Info(t, fmt.Sprintf("Generated cluster prefix: %s", clusterPrefix))

	// Setup Test Options
	options, err := setupOptions(
		t,
		clusterPrefix,
		terraformDir,
		envVars.DefaultExistingResourceGroup,
	)
	require.NoError(t, err, "Must initialize valid test options")

	// Monitoring Configuration
	// Configure the observability settings for management and compute logs,
	options.TerraformVars["observability_logs_enable_for_management"] = false        // Disable management logs
	options.TerraformVars["observability_monitoring_enable"] = true                  // Enable monitoring
	options.TerraformVars["observability_monitoring_on_compute_nodes_enable"] = true // Enable compute node monitoring
	options.TerraformVars["observability_monitoring_plan"] = "graduated-tier"

	// Skip resource teardown for debugging/inspection
	options.SkipTestTearDown = true
	defer options.TestTearDown()

	// Cluster Deployment
	deploymentStart := time.Now()
	testLogger.Info(t, "Starting observability monitoring validation (management+compute)")

	clusterCreationErr := lsf.VerifyClusterCreationAndConsistency(t, options, testLogger)
	require.NoError(t, clusterCreationErr, "Cluster creation validation failed")
	testLogger.Info(t, fmt.Sprintf("Cluster deployment completed in %v", time.Since(deploymentStart)))

	// Post-deployment Validation
	validationStart := time.Now()
	lsf.ValidateBasicClusterConfigurationWithCloudMonitoring(t, options, testLogger)
	testLogger.Info(t, fmt.Sprintf("Validation completed in %v", time.Since(validationStart)))

	// Test Result Evaluation
	if t.Failed() {
		testLogger.Error(t, fmt.Sprintf("Test %s failed - inspect validation logs", t.Name()))
	} else {
		testLogger.PASS(t, fmt.Sprintf("Test %s completed successfully", t.Name()))
	}
}

// TestRunObservabilityMonitoringForManagementEnabledAndComputeDisabled validates cluster creation with
// observability monitoring enabled only for management nodes.
//
// Prerequisites:
// - Valid environment configuration
// - Proper test suite initialization
// - Permissions to enable monitoring features
func TestRunObservabilityMonitoringForManagementEnabledAndComputeDisabled(t *testing.T) {
	t.Parallel()

	// Initialization and Setup
	setupTestSuite(t)
	require.NotNil(t, testLogger, "Test logger must be initialized")
	testLogger.Info(t, fmt.Sprintf("Test %s initiated", t.Name()))

	// Environment Configuration
	envVars, err := GetEnvVars()
	require.NoError(t, err, "Must load valid environment configuration")

	// Generate Unique Cluster Prefix
	clusterPrefix := utils.GenerateRandomString()
	testLogger.Info(t, fmt.Sprintf("Generated cluster prefix: %s", clusterPrefix))

	// Setup Test Options
	options, err := setupOptions(
		t,
		clusterPrefix,
		terraformDir,
		envVars.DefaultExistingResourceGroup,
	)
	require.NoError(t, err, "Must initialize valid test options")

	// Monitoring Configuration
	// Configure the observability settings for management and compute logs,
	options.TerraformVars["observability_logs_enable_for_management"] = false         // Disable management logs
	options.TerraformVars["observability_monitoring_enable"] = true                   // Enable monitoring
	options.TerraformVars["observability_monitoring_on_compute_nodes_enable"] = false // Disable compute node monitoring
	options.TerraformVars["observability_monitoring_plan"] = "graduated-tier"

	// Skip resource teardown for inspection
	options.SkipTestTearDown = true
	defer options.TestTearDown()

	// Cluster Deployment
	deploymentStart := time.Now()
	testLogger.Info(t, "Starting observability monitoring validation (management enabled, compute disabled)")

	clusterCreationErr := lsf.VerifyClusterCreationAndConsistency(t, options, testLogger)
	require.NoError(t, clusterCreationErr, "Cluster creation validation failed")
	testLogger.Info(t, fmt.Sprintf("Cluster deployment completed in %v", time.Since(deploymentStart)))

	// Post-deployment Validation
	validationStart := time.Now()
	lsf.ValidateBasicClusterConfigurationWithCloudMonitoring(t, options, testLogger)
	testLogger.Info(t, fmt.Sprintf("Validation completed in %v", time.Since(validationStart)))

	// Test Result Evaluation
	if t.Failed() {
		testLogger.Error(t, fmt.Sprintf("Test %s failed - inspect validation logs", t.Name()))
	} else {
		testLogger.PASS(t, fmt.Sprintf("Test %s completed successfully", t.Name()))
	}
}

// TestRunObservabilityMonitoringForManagementAndComputeDisabled validates cluster creation with
// observability monitoring disabled for both management and compute nodes.
//
// Prerequisites:
// - Valid environment configuration
// - Proper test suite initialization
func TestRunObservabilityMonitoringForManagementAndComputeDisabled(t *testing.T) {
	t.Parallel()

	// Initialization and Setup
	setupTestSuite(t)
	require.NotNil(t, testLogger, "Test logger must be initialized")
	testLogger.Info(t, fmt.Sprintf("Test %s initiated", t.Name()))

	// Environment Configuration
	envVars, err := GetEnvVars()
	require.NoError(t, err, "Must load valid environment configuration")

	// Generate Unique Cluster Prefix
	clusterPrefix := utils.GenerateRandomString()
	testLogger.Info(t, fmt.Sprintf("Generated cluster prefix: %s", clusterPrefix))

	// Setup Test Options
	options, err := setupOptions(
		t,
		clusterPrefix,
		terraformDir,
		envVars.DefaultExistingResourceGroup,
	)
	require.NoError(t, err, "Must initialize valid test options")

	// Monitoring Configuration
	// Configure the observability settings for management and compute logs,
	options.TerraformVars["observability_logs_enable_for_management"] = false         // Disable management logs
	options.TerraformVars["observability_monitoring_enable"] = true                   // Enable monitoring
	options.TerraformVars["observability_monitoring_on_compute_nodes_enable"] = false // Disable monitoring on compute nodes
	options.TerraformVars["observability_monitoring_plan"] = "graduated-tier"

	// Skip resource teardown for inspection
	options.SkipTestTearDown = true
	defer options.TestTearDown()

	// Cluster Deployment
	deploymentStart := time.Now()
	testLogger.Info(t, "Starting observability monitoring validation (management and compute disabled)")

	clusterCreationErr := lsf.VerifyClusterCreationAndConsistency(t, options, testLogger)
	require.NoError(t, clusterCreationErr, "Cluster creation validation failed")
	testLogger.Info(t, fmt.Sprintf("Cluster deployment completed in %v", time.Since(deploymentStart)))

	// Post-deployment Validation
	validationStart := time.Now()
	lsf.ValidateBasicClusterConfigurationWithCloudMonitoring(t, options, testLogger)
	testLogger.Info(t, fmt.Sprintf("Validation completed in %v", time.Since(validationStart)))

	// Test Result Evaluation
	if t.Failed() {
		testLogger.Error(t, fmt.Sprintf("Test %s failed - inspect validation logs", t.Name()))
	} else {
		testLogger.PASS(t, fmt.Sprintf("Test %s completed successfully", t.Name()))
	}
}

// TestRunObservabilityAtrackerEnabledAndTargetTypeAsCloudlogs validates cluster creation with
// Atracker enabled and target type set to Cloud Logs.
//
// Prerequisites:
// - Valid environment configuration
// - Proper test suite initialization
// - Permissions to enable Atracker
func TestRunObservabilityAtrackerEnabledAndTargetTypeAsCloudlogs(t *testing.T) {
	t.Parallel()

	// Initialization and Setup
	setupTestSuite(t)
	require.NotNil(t, testLogger, "Test logger must be initialized")
	testLogger.Info(t, fmt.Sprintf("Test %s initiated", t.Name()))

	// Environment Configuration
	envVars, err := GetEnvVars()
	require.NoError(t, err, "Must load valid environment configuration")

	// Test Configuration
	clusterPrefix := utils.GenerateRandomString()
	testLogger.Info(t, fmt.Sprintf("Generated cluster prefix: %s", clusterPrefix))

	options, err := setupOptions(
		t,
		clusterPrefix, // Unique cluster prefix
		terraformDir,
		envVars.DefaultExistingResourceGroup,
	)
	require.NoError(t, err, "Must initialize valid test options")

	// Atracker Configuration (Cloudlogs target)
	// Set observability configurations for logs and monitoring
	options.TerraformVars["observability_logs_enable_for_management"] = false         // Disable management logs
	options.TerraformVars["observability_monitoring_enable"] = false                  // Disable monitoring
	options.TerraformVars["observability_monitoring_on_compute_nodes_enable"] = false // Disable monitoring on compute nodes
	options.TerraformVars["observability_atracker_enable"] = true                     // Enable Atracker
	options.TerraformVars["observability_atracker_target_type"] = "cloudlogs"         // Set target type as cloudlogs

	// Resource Cleanup Configuration
	options.SkipTestTearDown = true
	defer options.TestTearDown()

	// Cluster Deployment
	deploymentStart := time.Now()
	testLogger.Info(t, "Starting Atracker validation (cloudlogs target)")

	clusterCreationErr := lsf.VerifyClusterCreationAndConsistency(t, options, testLogger)
	require.NoError(t, clusterCreationErr, "Cluster creation validation failed")
	testLogger.Info(t, fmt.Sprintf("Cluster deployment completed in %v", time.Since(deploymentStart)))

	// Post-deployment Validation
	validationStart := time.Now()
	lsf.ValidateBasicClusterConfigurationWithCloudAtracker(t, options, testLogger)
	testLogger.Info(t, fmt.Sprintf("Validation completed in %v", time.Since(validationStart)))

	// Test Result Evaluation
	if t.Failed() {
		testLogger.Error(t, fmt.Sprintf("Test %s failed - inspect validation logs", t.Name()))
	} else {
		testLogger.PASS(t, fmt.Sprintf("Test %s completed successfully", t.Name()))
	}
}

// TestRunObservabilityAtrackerEnabledAndTargetTypeAsCos validates cluster creation with
// Atracker enabled and target type set to COS.
//
// Prerequisites:
// - Valid environment configuration
// - Proper test suite initialization
// - Permissions to enable Atracker
func TestRunObservabilityAtrackerEnabledAndTargetTypeAsCos(t *testing.T) {
	t.Parallel()

	// Initialization and Setup
	setupTestSuite(t)
	require.NotNil(t, testLogger, "Test logger must be initialized")
	testLogger.Info(t, fmt.Sprintf("Test %s initiated", t.Name()))

	// Environment Configuration
	envVars, err := GetEnvVars()
	require.NoError(t, err, "Must load valid environment configuration")

	// Test Configuration
	clusterPrefix := utils.GenerateRandomString()
	testLogger.Info(t, fmt.Sprintf("Generated cluster prefix: %s", clusterPrefix))

	options, err := setupOptions(
		t,
		clusterPrefix, // Unique cluster prefix
		terraformDir,
		envVars.DefaultExistingResourceGroup,
	)
	require.NoError(t, err, "Must initialize valid test options")

	// Atracker Configuration (COS target)
	options.TerraformVars["observability_logs_enable_for_management"] = false         // Disable management logs
	options.TerraformVars["observability_monitoring_enable"] = false                  // Disable monitoring
	options.TerraformVars["observability_monitoring_on_compute_nodes_enable"] = false // Disable monitoring on compute nodes
	options.TerraformVars["observability_atracker_enable"] = true                     // Enable Atracker
	options.TerraformVars["observability_atracker_target_type"] = "cos"               // Set target type to COS (Cloud Object Storage)

	// Resource Cleanup Configuration
	options.SkipTestTearDown = true
	defer options.TestTearDown()

	// Cluster Deployment
	deploymentStart := time.Now()
	testLogger.Info(t, "Starting Atracker validation (COS target)")

	clusterCreationErr := lsf.VerifyClusterCreationAndConsistency(t, options, testLogger)
	require.NoError(t, clusterCreationErr, "Cluster creation validation failed")
	testLogger.Info(t, fmt.Sprintf("Cluster deployment completed in %v", time.Since(deploymentStart)))

	// Post-deployment Validation
	validationStart := time.Now()
	lsf.ValidateBasicClusterConfigurationWithCloudAtracker(t, options, testLogger)
	testLogger.Info(t, fmt.Sprintf("Validation completed in %v", time.Since(validationStart)))

	// Test Result Evaluation
	if t.Failed() {
		testLogger.Error(t, fmt.Sprintf("Test %s failed - inspect validation logs", t.Name()))
	} else {
		testLogger.PASS(t, fmt.Sprintf("Test %s completed successfully", t.Name()))
	}
}

// TestRunObservabilityAtrackerDisabledAndTargetTypeAsCos validates cluster creation with
// Atracker disabled and target type set to COS.
//
// Prerequisites:
// - Valid environment configuration
// - Proper test suite initialization
func TestRunObservabilityAtrackerDisabledAndTargetTypeAsCos(t *testing.T) {
	t.Parallel()

	// Initialization and Setup
	setupTestSuite(t)
	require.NotNil(t, testLogger, "Test logger must be initialized")
	testLogger.Info(t, fmt.Sprintf("Test %s initiated", t.Name()))

	// Environment Configuration
	envVars, err := GetEnvVars()
	require.NoError(t, err, "Must load valid environment configuration")

	// Test Configuration
	clusterPrefix := utils.GenerateRandomString()
	testLogger.Info(t, fmt.Sprintf("Generated cluster prefix: %s", clusterPrefix))

	options, err := setupOptions(
		t,
		clusterPrefix, // Unique cluster prefix
		terraformDir,
		envVars.DefaultExistingResourceGroup,
	)
	require.NoError(t, err, "Must initialize valid test options")

	// Atracker Configuration (Disabled, with COS target)
	options.TerraformVars["observability_logs_enable_for_management"] = false         // Disable management logs
	options.TerraformVars["observability_monitoring_enable"] = false                  // Disable monitoring
	options.TerraformVars["observability_monitoring_on_compute_nodes_enable"] = false // Disable monitoring on compute nodes
	options.TerraformVars["observability_atracker_enable"] = false                    // Disable Atracker
	options.TerraformVars["observability_atracker_target_type"] = "cos"               // Set target type to COS (Cloud Object Storage)

	// Resource Cleanup Configuration
	options.SkipTestTearDown = true
	defer options.TestTearDown()

	// Cluster Deployment
	deploymentStart := time.Now()
	testLogger.Info(t, "Starting Atracker validation (disabled, COS target)")

	clusterCreationErr := lsf.VerifyClusterCreationAndConsistency(t, options, testLogger)
	require.NoError(t, clusterCreationErr, "Cluster creation validation failed")
	testLogger.Info(t, fmt.Sprintf("Cluster deployment completed in %v", time.Since(deploymentStart)))

	// Post-deployment Validation
	validationStart := time.Now()
	lsf.ValidateBasicClusterConfigurationWithCloudAtracker(t, options, testLogger)
	testLogger.Info(t, fmt.Sprintf("Validation completed in %v", time.Since(validationStart)))

	// Test Result Evaluation
	if t.Failed() {
		testLogger.Error(t, fmt.Sprintf("Test %s failed - inspect validation logs", t.Name()))
	} else {
		testLogger.PASS(t, fmt.Sprintf("Test %s completed successfully", t.Name()))
	}
}

// ******************* Existing VPC ***************************

// TestRunCreateVpc as brand new
func TestRunCreateVpc(t *testing.T) {
	// Parallelize the test to run concurrently with others
	t.Parallel()

	// Set up the test suite and prepare the testing environment
	setupTestSuite(t)

	testLogger.Info(t, "Brand new VPC creation initiated for "+t.Name())

	// Define the HPC cluster prefix
	hpcClusterPrefix := utils.GenerateRandomString()

	// Get and validate environment variables
	envVars, err := GetEnvVars()
	require.NoError(t, err, "Failed to get environment variables")

	// Set up the test options with the relevant parameters, including environment variables and resource group, set up test environment
	options, err := setupOptionsVPC(t, hpcClusterPrefix, createVpcTerraformDir, envVars.DefaultExistingResourceGroup)
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

	// Get and validate environment variables
	envVars, err := GetEnvVars()
	require.NoError(t, err, "Failed to get environment variables")

	// Set up the test options with the relevant parameters, including environment variables and resource group
	options, err := setupOptions(t, hpcClusterPrefix, terraformDir, envVars.DefaultExistingResourceGroup)
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

	// Get and validate environment variables
	envVars, err := GetEnvVars()
	require.NoError(t, err, "Failed to get environment variables")

	// Set up the test options with the relevant parameters, including environment variables and resource group
	options, err := setupOptions(t, hpcClusterPrefix, terraformDir, envVars.DefaultExistingResourceGroup)
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

	// Get and validate environment variables
	envVars, err := GetEnvVars()
	require.NoError(t, err, "Failed to get environment variables")

	// Set up the test options with the relevant parameters, including environment variables and resource group, set up test environment
	options, err := setupOptionsVPC(t, hpcClusterPrefix, createVpcTerraformDir, envVars.DefaultExistingResourceGroup)
	options.TerraformVars["enable_hub"] = true
	options.TerraformVars["dns_zone_name"] = "lsf.com"

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

	// Get and validate environment variables
	envVars, err := GetEnvVars()
	require.NoError(t, err, "Failed to get environment variables")

	// Set up the test options with the relevant parameters, including environment variables and resource group
	options, err := setupOptions(t, hpcClusterPrefix, terraformDir, envVars.DefaultExistingResourceGroup)
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

	// Get and validate environment variables
	envVars, err := GetEnvVars()
	require.NoError(t, err, "Failed to get environment variables")

	// Set up the test options with the relevant parameters, including environment variables and resource group
	options, err := setupOptions(t, hpcClusterPrefix, terraformDir, envVars.DefaultExistingResourceGroup)
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

	// Get and validate environment variables
	envVars, err := GetEnvVars()
	require.NoError(t, err, "Failed to get environment variables")

	// Set up the test options with the relevant parameters, including environment variables and resource group
	options, err := setupOptions(t, hpcClusterPrefix, terraformDir, envVars.DefaultExistingResourceGroup)
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

	// Get and validate environment variables
	envVars, err := GetEnvVars()
	require.NoError(t, err, "Failed to get environment variables")

	// Set up the test options with the relevant parameters, including environment variables and resource group
	options, err := setupOptions(t, hpcClusterPrefix, terraformDir, envVars.DefaultExistingResourceGroup)
	require.NoError(t, err, "Error setting up test options: %v", err)

	options.TerraformVars["vpc_cidr"] = "10.243.0.0/18"
	options.TerraformVars["vpc_cluster_private_subnets_cidr_blocks"] = []string{"10.243.0.0/20"}
	options.TerraformVars["vpc_cluster_login_private_subnets_cidr_blocks"] = []string{"10.243.16.0/28"}

	options.SkipTestTearDown = true
	defer options.TestTearDown()

	lsf.ValidateBasicClusterConfiguration(t, options, testLogger)
}
