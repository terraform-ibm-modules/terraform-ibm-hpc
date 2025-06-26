package tests

import (
	"encoding/json"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/stretchr/testify/require"

	"github.com/terraform-ibm-modules/ibmcloud-terratest-wrapper/testhelper"
	deploy "github.com/terraform-ibm-modules/terraform-ibm-hpc/deployment"
	lsf "github.com/terraform-ibm-modules/terraform-ibm-hpc/lsf"
	utils "github.com/terraform-ibm-modules/terraform-ibm-hpc/utilities"
)

// Constants for better organization
const (
	createVpcTerraformDir = "examples/create_vpc/" // Brand new VPC
)

// TestMain is the entry point for all tests
func TestMain(m *testing.M) {

	// Load LSF version configuration
	productFileName, err := GetLSFVersionConfig()
	if err != nil {
		log.Fatalf("❌ Failed to get LSF version config: %v", err)
	}

	// Load and validate configuration
	configFilePath, err := filepath.Abs("../data/" + productFileName)
	if err != nil {
		log.Fatalf("❌ Failed to resolve config path: %v", err)
	}

	if _, err := os.Stat(configFilePath); err != nil {
		log.Fatalf("❌ Config file not accessible: %v", err)
	}

	if _, err := deploy.GetConfigFromYAML(configFilePath); err != nil {
		log.Fatalf("❌ Config load failed: %v", err)
	}
	log.Printf("✅ Configuration loaded successfully from %s", filepath.Base(configFilePath))

	// Execute tests
	exitCode := m.Run()

	// Generate HTML report if JSON log exists
	if jsonFileName, ok := os.LookupEnv("LOG_FILE_NAME"); ok {
		if _, err := os.Stat(jsonFileName); err == nil {
			results, err := utils.ParseJSONFile(jsonFileName)
			if err != nil {
				log.Printf("Failed to parse JSON results: %v", err)
			} else if err := utils.GenerateHTMLReport(results); err != nil {
				log.Printf("Failed to generate HTML report: %v", err)
			}
		}
	}

	os.Exit(exitCode)
}

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

	// Generate Unique Cluster Prefix
	clusterNamePrefix := utils.GenerateTimestampedClusterPrefix(utils.GenerateRandomString())
	testLogger.Info(t, fmt.Sprintf("Generated cluster prefix: %s", clusterNamePrefix))

	// Test Configuration
	envVars, err := GetEnvVars()
	require.NoError(t, err, "Failed to load environment configuration")

	options, err := setupOptions(t, clusterNamePrefix, terraformDir, envVars.DefaultExistingResourceGroup)

	require.NoError(t, err, "Failed to initialize test options")

	// Resource Cleanup Configuration
	options.SkipTestTearDown = true
	defer options.TestTearDown()

	// Cluster Deployment
	deploymentStart := time.Now()
	testLogger.Info(t, fmt.Sprintf("Starting cluster deployment for test: %s", t.Name()))

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

	// Generate Unique Cluster Prefix
	clusterNamePrefix := utils.GenerateTimestampedClusterPrefix(utils.GenerateRandomString())
	testLogger.Info(t, fmt.Sprintf("Generated cluster prefix: %s", clusterNamePrefix))

	// Test Configuration
	options, err := setupOptions(t, clusterNamePrefix, terraformDir, LSF_CUSTOM_EXISTING_RESOURCE_GROUP_VALUE_AS_NULL)
	require.NoError(t, err, "Failed to initialize test options")

	// Resource Cleanup Configuration
	options.SkipTestTearDown = true
	defer options.TestTearDown()

	// Cluster Deployment
	deploymentStart := time.Now()
	testLogger.Info(t, fmt.Sprintf("Starting cluster deployment for test: %s", t.Name()))

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

	// Generate Unique Cluster Prefix
	clusterNamePrefix := utils.GenerateTimestampedClusterPrefix(utils.GenerateRandomString())
	testLogger.Info(t, fmt.Sprintf("Generated cluster prefix: %s", clusterNamePrefix))

	// Environment Configuration
	envVars, err := GetEnvVars()
	require.NoError(t, err, "Failed to load environment configuration")

	// Test Configuration
	options, err := setupOptions(t, clusterNamePrefix, terraformDir, envVars.NonDefaultExistingResourceGroup)
	require.NoError(t, err, "Failed to initialize test options")

	// Resource Cleanup Configuration
	options.SkipTestTearDown = true
	defer options.TestTearDown()

	// Cluster Deployment
	deploymentStart := time.Now()
	testLogger.Info(t, fmt.Sprintf("Starting cluster deployment for test: %s", t.Name()))

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

	// Generate Unique Cluster Prefix
	clusterNamePrefix := utils.GenerateTimestampedClusterPrefix(utils.GenerateRandomString())
	testLogger.Info(t, fmt.Sprintf("Generated cluster prefix: %s", clusterNamePrefix))

	// Test Configuration
	envVars, err := GetEnvVars()
	require.NoError(t, err, "Failed to load environment configuration")

	// Skip the test if SCC is disabled
	if strings.ToLower(envVars.SccEnabled) == "false" {
		testLogger.Warn(t, fmt.Sprintf("Skipping %s - SCC disabled in configuration", t.Name()))
		return
	}

	options, err := setupOptions(t, clusterNamePrefix, terraformDir, envVars.DefaultExistingResourceGroup)
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
	testLogger.Info(t, fmt.Sprintf("Starting cluster deployment for test: %s", t.Name()))

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

	// Generate Unique Cluster Prefix
	clusterNamePrefix := utils.GenerateTimestampedClusterPrefix(utils.GenerateRandomString())
	testLogger.Info(t, fmt.Sprintf("Generated cluster prefix: %s", clusterNamePrefix))

	// Environment Configuration
	envVars, err := GetEnvVars()
	require.NoError(t, err, "Failed to load environment configuration")

	// Test Configuration
	options, err := setupOptions(t, clusterNamePrefix, terraformDir, envVars.DefaultExistingResourceGroup)
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
	testLogger.Info(t, fmt.Sprintf("Starting cluster deployment for test: %s", t.Name()))

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

// TestRunUsingExistingKMS validates cluster creation with existing Key Protect service instance.
// Verifies proper KMS integration and encryption functionality.
//
// Prerequisites:
// - Valid IBM Cloud API key
// - Permissions to create/delete KMS instances
// - Proper test suite initialization
func TestRunUsingExistingKMSInstanceAndExistingKey(t *testing.T) {
	t.Parallel()

	// Initialization
	setupTestSuite(t)
	require.NotNil(t, testLogger, "Test logger must be initialized")
	testLogger.Info(t, fmt.Sprintf("Test %s initiated", t.Name()))

	// Generate Unique Cluster Prefix
	clusterNamePrefix := utils.GenerateTimestampedClusterPrefix(utils.GenerateRandomString())
	testLogger.Info(t, fmt.Sprintf("Generated cluster prefix: %s", clusterNamePrefix))

	// Load Environment Configuration
	envVars, err := GetEnvVars()
	require.NoError(t, err, "Must load valid environment configuration")

	// KMS Setup
	const (
		keyManagementType = "key_protect"
		kmsKeyName        = KMS_KEY_NAME
	)

	kmsInstanceName := "cicd-" + utils.GenerateRandomString()
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
	options, err := setupOptions(t, clusterNamePrefix, terraformDir, envVars.DefaultExistingResourceGroup)
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
	testLogger.Info(t, fmt.Sprintf("Starting cluster deployment for test: %s", t.Name()))

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

// TestRunUsingExistingKMSInstanceAndWithoutKey validates cluster creation with existing KMS instance but no key.
// Verifies proper handling of KMS instance without specified key.
//
// Prerequisites:
// - Valid IBM Cloud API key
// - Permissions to create/delete KMS instances
// - Proper test suite initialization
func TestRunUsingExistingKMSInstanceAndWithoutKey(t *testing.T) {
	t.Parallel()

	// Initialization
	setupTestSuite(t)
	require.NotNil(t, testLogger, "Test logger must be initialized")
	testLogger.Info(t, fmt.Sprintf("Test %s initiated", t.Name()))

	// Generate Unique Cluster Prefix
	clusterNamePrefix := utils.GenerateTimestampedClusterPrefix(utils.GenerateRandomString())
	testLogger.Info(t, fmt.Sprintf("Generated cluster prefix: %s", clusterNamePrefix))

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
		clusterNamePrefix, // Generate Unique Cluster Prefix
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
	testLogger.Info(t, fmt.Sprintf("Starting cluster deployment for test: %s", t.Name()))

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

// TestRunWithExistingKMSInstanceAndKeyWithAuthorizationPolicy validates that a cluster can be
// deployed using an existing KMS instance and key, assuming that the IAM authorization
// policy is already in place between the KMS instance and the VPC file share.
//
// Prerequisites:
// - Valid IBM Cloud API key
// - IAM authorization policy already enabled for the KMS instance and VPC file share
// - Proper test suite initialization
func TestRunWithExistingKMSInstanceAndKeyWithAuthorizationPolicy(t *testing.T) {
	t.Parallel()

	// Initialization
	setupTestSuite(t)
	require.NotNil(t, testLogger, "Test logger must be initialized")
	testLogger.Info(t, fmt.Sprintf("Test %s initiated", t.Name()))

	// Generate Unique Cluster Prefix
	clusterNamePrefix := utils.GenerateTimestampedClusterPrefix(utils.GenerateRandomString())
	testLogger.Info(t, fmt.Sprintf("Generated cluster prefix: %s", clusterNamePrefix))

	// Load Environment Variables
	envVars, err := GetEnvVars()
	require.NoError(t, err, "Must load valid environment configuration")

	// API Key Validation
	apiKey := os.Getenv("TF_VAR_ibmcloud_api_key")
	require.NotEmpty(t, apiKey, "IBM Cloud API key must be set")

	// Test Options Configuration
	options, err := setupOptions(t, clusterNamePrefix, terraformDir, envVars.DefaultExistingResourceGroup)
	require.NoError(t, err, "Must initialize valid test options")

	// Set KMS-related variables
	options.TerraformVars["key_management"] = "key_protect"
	options.TerraformVars["kms_instance_name"] = envVars.KMSInstanceName
	options.TerraformVars["kms_key_name"] = envVars.KMSKeyName
	options.TerraformVars["skip_iam_share_authorization_policy"] = true
	options.TerraformVars["skip_iam_block_storage_authorization_policy"] = true

	// Cluster Teardown Configuration
	options.SkipTestTearDown = true
	defer options.TestTearDown()

	// Cluster Deployment
	deploymentStart := time.Now()
	testLogger.Info(t, fmt.Sprintf("Starting cluster deployment for test: %s", t.Name()))

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

	// Generate Unique Cluster Prefix
	clusterNamePrefix := utils.GenerateTimestampedClusterPrefix(utils.GenerateRandomString())
	testLogger.Info(t, fmt.Sprintf("Generated cluster prefix: %s", clusterNamePrefix))

	// Environment Configuration
	envVars, err := GetEnvVars()
	require.NoError(t, err, "Must load valid environment configuration")

	// Test Configuration
	options, err := setupOptions(
		t,
		clusterNamePrefix, // Generate Unique Cluster Prefix
		terraformDir,
		envVars.DefaultExistingResourceGroup,
	)
	require.NoError(t, err, "Must initialize valid test options")

	// Cluster Profile Configuration
	options.TerraformVars["static_compute_instances"] = []map[string]interface{}{
		{
			"profile": "bx2d-4x16",
			"count":   0,
			"image":   envVars.StaticComputeInstancesImage,
		},
	}

	options.TerraformVars["dynamic_compute_instances"] = []map[string]interface{}{
		{
			"profile": "cx2-2x4",
			"count":   1024,
			"image":   envVars.DynamicComputeInstancesImage,
		},
	}

	// Resource Cleanup Configuration
	options.SkipTestTearDown = true
	defer options.TestTearDown()

	// Cluster Deployment
	deploymentStart := time.Now()
	testLogger.Info(t, fmt.Sprintf("Starting cluster deployment for test: %s", t.Name()))

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

	// Generate Unique Cluster Prefix
	clusterNamePrefix := utils.GenerateTimestampedClusterPrefix(utils.GenerateRandomString())
	testLogger.Info(t, fmt.Sprintf("Generated cluster prefix: %s", clusterNamePrefix))

	// Load Environment Configuration
	envVars, err := GetEnvVars()
	require.NoError(t, err, "Must load valid environment configuration")

	// Validate LDAP Configuration
	require.Equal(t, "true", strings.ToLower(envVars.EnableLdap), "LDAP must be enabled for this test")
	require.NotEmpty(t, envVars.LdapAdminPassword, "LDAP admin password must be provided") // pragma: allowlist secret
	require.NotEmpty(t, envVars.LdapUserName, "LDAP username must be provided")
	require.NotEmpty(t, envVars.LdapUserPassword, "LDAP user password must be provided") // pragma: allowlist secret

	options, err := setupOptions(t, clusterNamePrefix, terraformDir, envVars.DefaultExistingResourceGroup)
	require.NoError(t, err, "Must initialize valid test options")

	// Set LDAP Terraform Variables
	options.TerraformVars["enable_ldap"] = strings.ToLower(envVars.EnableLdap)
	options.TerraformVars["ldap_basedns"] = envVars.LdapBaseDns
	options.TerraformVars["ldap_admin_password"] = envVars.LdapAdminPassword // pragma: allowlist secret
	options.TerraformVars["ldap_user_name"] = envVars.LdapUserName
	options.TerraformVars["ldap_user_password"] = envVars.LdapUserPassword // pragma: allowlist secret

	// Configure Resource Cleanup
	options.SkipTestTearDown = true
	defer options.TestTearDown()

	// Cluster Deployment
	deploymentStart := time.Now()
	testLogger.Info(t, fmt.Sprintf("Starting cluster deployment for test: %s", t.Name()))

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

	// Generate Unique Cluster Prefix
	clusterNamePrefix := utils.GenerateTimestampedClusterPrefix(utils.GenerateRandomString())
	testLogger.Info(t, fmt.Sprintf("Generated cluster prefix: %s", clusterNamePrefix))

	// Environment Configuration
	envVars, err := GetEnvVars()
	require.NoError(t, err, "Must load valid environment configuration")

	// LDAP Validation
	require.Equal(t, "true", strings.ToLower(envVars.EnableLdap), "LDAP must be enabled for this test")
	require.NotEmpty(t, envVars.LdapAdminPassword, "LDAP admin password must be provided") // pragma: allowlist secret
	require.NotEmpty(t, envVars.LdapUserName, "LDAP username must be provided")
	require.NotEmpty(t, envVars.LdapUserPassword, "LDAP user password must be provided") // pragma: allowlist secret

	// First Cluster Configuration

	options1, err := setupOptions(t, clusterNamePrefix, terraformDir, envVars.DefaultExistingResourceGroup)
	require.NoError(t, err, "Must initialize valid test options for first cluster")

	// First Cluster LDAP Configuration

	options1.TerraformVars["enable_ldap"] = strings.ToLower(envVars.EnableLdap)
	options1.TerraformVars["ldap_basedns"] = envVars.LdapBaseDns
	options1.TerraformVars["ldap_admin_password"] = envVars.LdapAdminPassword // pragma: allowlist secret
	options1.TerraformVars["ldap_user_name"] = envVars.LdapUserName
	options1.TerraformVars["ldap_user_password"] = envVars.LdapUserPassword // pragma: allowlist secret
	//options1.TerraformVars["key_management"] = "null"

	// First Cluster Cleanup
	options1.SkipTestTearDown = true
	defer options1.TestTearDown()

	// First Cluster Validation
	output, err := options1.RunTest()
	require.NoError(t, err, "First cluster validation failed")
	require.NotNil(t, output, "First cluster validation returned nil output")

	// Retrieve custom resolver ID
	customResolverID, err := utils.GetCustomResolverID(t, os.Getenv("TF_VAR_ibmcloud_api_key"), utils.GetRegion(envVars.Zones), envVars.DefaultExistingResourceGroup, clusterNamePrefix, testLogger)
	require.NoError(t, err, "Error retrieving custom resolver ID: %v", err)

	// Retrieve LDAP IP and Bastion IP
	ldapIP, err := utils.GetLdapIP(t, options1, testLogger)
	require.NoError(t, err, "Error retrieving LDAP IP address: %v", err)

	ldapServerBastionIP, err := utils.GetBastionIP(t, options1, testLogger)
	require.NoError(t, err, "Error retrieving LDAP server bastion IP address: %v", err)

	serverCertErr := utils.RetrieveAndUpdateSecurityGroup(t, os.Getenv("TF_VAR_ibmcloud_api_key"), utils.GetRegion(envVars.Zones), envVars.DefaultExistingResourceGroup, clusterNamePrefix, "10.241.0.0/18", "389", "389", testLogger)
	require.NoError(t, serverCertErr, "Failed to retrieve LDAP server certificate via SSH")

	// Second Cluster Configuration
	hpcClusterPrefix2 := utils.GenerateTimestampedClusterPrefix(utils.GenerateRandomString())
	testLogger.Info(t, fmt.Sprintf("Generated cluster prefix : %s", hpcClusterPrefix2))

	options2, err := setupOptions(t, hpcClusterPrefix2, terraformDir, envVars.DefaultExistingResourceGroup)
	require.NoError(t, err, "Error setting up test options for the second cluster: %v", err)

	// LDAP Certificate Retrieval
	ldapServerCert, serverCertErr := lsf.GetLDAPServerCert(lsf.LSF_PUBLIC_HOST_NAME, ldapServerBastionIP, lsf.LSF_LDAP_HOST_NAME, ldapIP)
	require.NoError(t, serverCertErr, "Must retrieve LDAP server certificate")
	testLogger.Info(t, fmt.Sprintf("LDAP server certificate : %s ", strings.TrimSpace(ldapServerCert)))

	// Second Cluster LDAP Configuration
	options2.TerraformVars["vpc_name"] = options1.TerraformVars["cluster_prefix"].(string) + "-lsf"
	options2.TerraformVars["vpc_cluster_private_subnets_cidr_blocks"] = CLUSTER_TWO_VPC_CLUSTER_PRIVATE_SUBNETS_CIDR_BLOCKS
	options2.TerraformVars["vpc_cluster_login_private_subnets_cidr_blocks"] = CLUSTER_TWO_VPC_CLUSTER_LOGIN_PRIVATE_SUBNETS_CIDR_BLOCKS
	dnsMap := map[string]string{
		"compute": "comp2.com",
	}
	dnsJSON, err := json.Marshal(dnsMap)
	require.NoError(t, err, "Must convert  to JSON string")

	options2.TerraformVars["dns_domain_name"] = string(dnsJSON)
	options2.TerraformVars["dns_custom_resolver_id"] = customResolverID
	options2.TerraformVars["enable_ldap"] = strings.ToLower(envVars.EnableLdap)
	options2.TerraformVars["ldap_basedns"] = envVars.LdapBaseDns
	options2.TerraformVars["ldap_server"] = ldapIP
	options2.TerraformVars["ldap_server_cert"] = strings.TrimSpace(ldapServerCert)

	// Second Cluster Cleanup
	options2.SkipTestTearDown = true
	defer options2.TestTearDown()

	// Cluster Deployment
	deploymentStart := time.Now()
	testLogger.Info(t, fmt.Sprintf("Starting cluster deployment for test: %s", t.Name()))

	clusterCreationErr := lsf.VerifyClusterCreationAndConsistency(t, options2, testLogger)
	require.NoError(t, clusterCreationErr, "Cluster creation validation failed")

	testLogger.Info(t, fmt.Sprintf("Cluster deployment completed (duration: %v)", time.Since(deploymentStart)))

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

	// Generate Unique Cluster Prefix
	clusterNamePrefix := utils.GenerateTimestampedClusterPrefix(utils.GenerateRandomString())
	testLogger.Info(t, fmt.Sprintf("Generated cluster prefix: %s", clusterNamePrefix))

	// Load Environment Configuration
	envVars, err := GetEnvVars()
	require.NoError(t, err, "Must load valid environment configuration")

	// Setup Test Options
	options, err := setupOptions(t, clusterNamePrefix, terraformDir, envVars.DefaultExistingResourceGroup)
	require.NoError(t, err, "Must initialize valid test options")

	// Terraform Input Variables
	options.TerraformVars["enable_cos_integration"] = true
	options.TerraformVars["enable_vpc_flow_logs"] = true

	// Skip resource teardown to retain cluster for debugging if needed
	options.SkipTestTearDown = true
	defer options.TestTearDown()

	// Cluster Deployment
	deploymentStart := time.Now()
	testLogger.Info(t, fmt.Sprintf("Starting cluster deployment for test: %s", t.Name()))

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

	// Generate Unique Cluster Prefix
	clusterNamePrefix := utils.GenerateTimestampedClusterPrefix(utils.GenerateRandomString())
	testLogger.Info(t, fmt.Sprintf("Generated cluster prefix: %s", clusterNamePrefix))

	// Load Environment Configuration
	envVars, err := GetEnvVars()
	require.NoError(t, err, "Must load valid environment configuration")

	// Setup Test Options
	options, err := setupOptions(t, clusterNamePrefix, terraformDir, envVars.DefaultExistingResourceGroup)
	require.NoError(t, err, "Must initialize valid test options")

	// Skip resource teardown to allow for post-run inspection
	options.SkipTestTearDown = true
	defer options.TestTearDown()

	// Cluster Deployment
	deploymentStart := time.Now()
	testLogger.Info(t, fmt.Sprintf("Starting cluster deployment for test: %s", t.Name()))

	clusterCreationErr := lsf.VerifyClusterCreationAndConsistency(t, options, testLogger)
	require.NoError(t, clusterCreationErr, "Cluster creation validation failed")
	testLogger.Info(t, fmt.Sprintf("Cluster deployment completed (duration: %v)", time.Since(deploymentStart)))

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

	// Generate Unique Cluster Prefix
	clusterNamePrefix := utils.GenerateTimestampedClusterPrefix(utils.GenerateRandomString())
	testLogger.Info(t, fmt.Sprintf("Generated cluster prefix: %s", clusterNamePrefix))

	// Load Environment Configuration
	envVars, err := GetEnvVars()
	require.NoError(t, err, "Must load valid environment configuration")

	// Setup Test Options
	options, err := setupOptions(t, clusterNamePrefix, terraformDir, envVars.DefaultExistingResourceGroup)
	require.NoError(t, err, "Must initialize valid test options")

	// Dedicated Host and Compute Configuration

	options.TerraformVars["enable_dedicated_host"] = true
	options.TerraformVars["static_compute_instances"] = []map[string]interface{}{
		{
			"profile": "bx2-2x8",
			"count":   1,
			"image":   envVars.StaticComputeInstancesImage,
		},
	}
	options.TerraformVars["dynamic_compute_instances"] = []map[string]interface{}{
		{
			"profile": "cx2-2x4",
			"count":   1024,
			"image":   envVars.DynamicComputeInstancesImage,
		},
	}

	// Skip resource teardown for inspection
	options.SkipTestTearDown = true
	defer options.TestTearDown()

	// Cluster Deployment
	deploymentStart := time.Now()
	testLogger.Info(t, fmt.Sprintf("Starting cluster deployment for test: %s", t.Name()))

	clusterCreationErr := lsf.VerifyClusterCreationAndConsistency(t, options, testLogger)
	require.NoError(t, clusterCreationErr, "Cluster creation validation failed")

	testLogger.Info(t, fmt.Sprintf("Cluster deployment completed (duration: %v)", time.Since(deploymentStart)))

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

// TestObservabilityAllFeaturesDisabled verifies cluster creation when all observability features
// (logs, monitoring, Atracker) are disabled. It ensures that the cluster functions correctly
// without any observability configurations.
//
// Prerequisites:
// - Valid environment setup
// - No dependency on observability services
func TestObservabilityAllFeaturesDisabled(t *testing.T) {
	t.Parallel()

	setupTestSuite(t)
	require.NotNil(t, testLogger, "Test logger must be initialized")
	testLogger.Info(t, fmt.Sprintf("Test %s initiated", t.Name()))

	clusterNamePrefix := utils.GenerateTimestampedClusterPrefix(utils.GenerateRandomString())
	testLogger.Info(t, fmt.Sprintf("Generated cluster prefix: %s", clusterNamePrefix))

	envVars, err := GetEnvVars()
	require.NoError(t, err, "Must load valid environment configuration")

	options, err := setupOptions(t, clusterNamePrefix, terraformDir, envVars.DefaultExistingResourceGroup)
	require.NoError(t, err, "Must initialize valid test options")

	// Disable all observability features
	options.TerraformVars["observability_enable_platform_logs"] = false
	options.TerraformVars["observability_logs_enable_for_management"] = false
	options.TerraformVars["observability_logs_enable_for_compute"] = false
	options.TerraformVars["observability_monitoring_enable"] = false
	options.TerraformVars["observability_monitoring_on_compute_nodes_enable"] = false
	options.TerraformVars["observability_monitoring_plan"] = "graduated-tier"
	options.TerraformVars["observability_atracker_enable"] = false
	options.TerraformVars["observability_atracker_target_type"] = "cos"

	options.SkipTestTearDown = true
	defer options.TestTearDown()

	// Cluster Deployment
	deploymentStart := time.Now()
	testLogger.Info(t, fmt.Sprintf("Starting cluster deployment for test: %s", t.Name()))

	err = lsf.VerifyClusterCreationAndConsistency(t, options, testLogger)
	require.NoError(t, err, "Cluster creation validation failed")

	testLogger.Info(t, fmt.Sprintf("Cluster deployment completed (duration: %v)", time.Since(deploymentStart)))

	// Post-deployment Validation
	validationStart := time.Now()
	lsf.ValidateBasicObservabilityClusterConfiguration(t, options, testLogger)
	testLogger.Info(t, fmt.Sprintf("Validation completed in %v", time.Since(validationStart)))

	// Test Outcome Evaluation
	if t.Failed() {
		testLogger.Error(t, fmt.Sprintf("Test %s failed - inspect logs", t.Name()))
	} else {
		testLogger.PASS(t, fmt.Sprintf("Test %s passed", t.Name()))
	}
}

// TestObservabilityLogsEnabledForManagementAndCompute validates cluster creation with
// observability logs enabled for both management and compute nodes.
//
// Prerequisites:
// - Valid environment setup
// - Permissions to enable log services
func TestObservabilityLogsEnabledForManagementAndCompute(t *testing.T) {
	t.Parallel()

	setupTestSuite(t)
	require.NotNil(t, testLogger, "Test logger must be initialized")
	testLogger.Info(t, fmt.Sprintf("Test %s initiated", t.Name()))

	clusterNamePrefix := utils.GenerateTimestampedClusterPrefix(utils.GenerateRandomString())
	testLogger.Info(t, fmt.Sprintf("Generated cluster prefix: %s", clusterNamePrefix))

	envVars, err := GetEnvVars()
	require.NoError(t, err, "Must load valid environment configuration")

	options, err := setupOptions(t, clusterNamePrefix, terraformDir, envVars.DefaultExistingResourceGroup)
	require.NoError(t, err, "Must initialize valid test options")

	// Enable logs for management and compute; disable other observability features
	options.TerraformVars["observability_logs_enable_for_management"] = true
	options.TerraformVars["observability_logs_enable_for_compute"] = true
	options.TerraformVars["observability_enable_platform_logs"] = false
	options.TerraformVars["observability_monitoring_enable"] = false
	options.TerraformVars["observability_monitoring_on_compute_nodes_enable"] = false
	options.TerraformVars["observability_monitoring_plan"] = "graduated-tier"
	options.TerraformVars["observability_atracker_enable"] = false
	options.TerraformVars["observability_atracker_target_type"] = "cos"

	options.SkipTestTearDown = true
	defer options.TestTearDown()

	// Cluster Deployment
	deploymentStart := time.Now()
	testLogger.Info(t, fmt.Sprintf("Starting cluster deployment for test: %s", t.Name()))

	err = lsf.VerifyClusterCreationAndConsistency(t, options, testLogger)
	require.NoError(t, err, "Cluster creation validation failed")

	testLogger.Info(t, fmt.Sprintf("Cluster deployment completed (duration: %v)", time.Since(deploymentStart)))

	// Post-deployment Validation
	validationStart := time.Now()
	lsf.ValidateBasicClusterConfigurationWithCloudLogs(t, options, testLogger)
	testLogger.Info(t, fmt.Sprintf("Validation completed in %v", time.Since(validationStart)))

	// Test Outcome Evaluation
	if t.Failed() {
		testLogger.Error(t, fmt.Sprintf("Test %s failed - inspect logs", t.Name()))
	} else {
		testLogger.PASS(t, fmt.Sprintf("Test %s passed", t.Name()))
	}
}

// TestObservabilityMonitoringEnabledForManagementAndCompute validates cluster creation with
// observability monitoring enabled for both management and compute nodes.
//
// Prerequisites:
// - Valid environment setup
// - Permissions to enable monitoring features
func TestObservabilityMonitoringEnabledForManagementAndCompute(t *testing.T) {
	t.Parallel()

	setupTestSuite(t)
	require.NotNil(t, testLogger, "Test logger must be initialized")
	testLogger.Info(t, fmt.Sprintf("Test %s initiated", t.Name()))

	clusterNamePrefix := utils.GenerateTimestampedClusterPrefix(utils.GenerateRandomString())
	testLogger.Info(t, fmt.Sprintf("Generated cluster prefix: %s", clusterNamePrefix))

	envVars, err := GetEnvVars()
	require.NoError(t, err, "Must load valid environment configuration")

	options, err := setupOptions(t, clusterNamePrefix, terraformDir, envVars.DefaultExistingResourceGroup)
	require.NoError(t, err, "Must initialize valid test options")

	// Enable monitoring; disable logs and Atracker
	options.TerraformVars["observability_logs_enable_for_management"] = false
	options.TerraformVars["observability_logs_enable_for_compute"] = false
	options.TerraformVars["observability_enable_platform_logs"] = false
	options.TerraformVars["observability_monitoring_enable"] = true
	options.TerraformVars["observability_monitoring_on_compute_nodes_enable"] = true
	options.TerraformVars["observability_monitoring_plan"] = "graduated-tier"
	options.TerraformVars["observability_atracker_enable"] = false
	options.TerraformVars["observability_atracker_target_type"] = "cloudlogs"

	options.SkipTestTearDown = true
	defer options.TestTearDown()

	// Cluster Deployment
	deploymentStart := time.Now()
	testLogger.Info(t, fmt.Sprintf("Starting cluster deployment for test: %s", t.Name()))

	err = lsf.VerifyClusterCreationAndConsistency(t, options, testLogger)
	require.NoError(t, err, "Cluster creation validation failed")

	testLogger.Info(t, fmt.Sprintf("Cluster deployment completed (duration: %v)", time.Since(deploymentStart)))

	// Post-deployment Validation
	validationStart := time.Now()
	lsf.ValidateBasicClusterConfigurationWithCloudMonitoring(t, options, testLogger)
	testLogger.Info(t, fmt.Sprintf("Validation completed in %v", time.Since(validationStart)))

	// Test Outcome Evaluation
	if t.Failed() {
		testLogger.Error(t, fmt.Sprintf("Test %s failed - inspect logs", t.Name()))
	} else {
		testLogger.PASS(t, fmt.Sprintf("Test %s passed", t.Name()))
	}
}

// TestObservabilityAtrackerLoggingMonitoring provisions LSF clusters with full observability configurations,
// including logging, monitoring, and Atracker integration, to verify end-to-end behavior across different targets.
//
// Scenarios covered:
// - Logging and monitoring enabled, Atracker targeting COS
// - Logging and monitoring enabled, Atracker targeting Cloud Logs
//
// Each test validates cluster creation and configuration integrity under the given observability setup.
// Note: Due to Atracker's 1-target-per-region limit, COS and Cloud Logs scenarios are executed sequentially.

func TestObservabilityAtrackerLoggingMonitoring(t *testing.T) {
	t.Parallel()

	setupTestSuite(t)
	require.NotNil(t, testLogger, "Test logger must be initialized")

	envVars, err := GetEnvVars()
	require.NoError(t, err, "Must load valid environment configuration")

	scenarios := []struct {
		name                string
		logsForManagement   bool
		logsForCompute      bool
		platformLogs        bool
		monitoring          bool
		monitoringOnCompute bool
		atrackerTargetType  string
		validationFunc      func(t *testing.T, options *testhelper.TestOptions, testLogger *utils.AggregatedLogger)
	}{

		{
			name:                "Logs_Monitoring_Atracker_COS",
			logsForManagement:   true,
			logsForCompute:      true,
			platformLogs:        false,
			monitoring:          true,
			monitoringOnCompute: true,
			atrackerTargetType:  "cos",
			validationFunc:      lsf.ValidateBasicObservabilityClusterConfiguration,
		},
		{
			name:                "Logs_Monitoring_Atracker_CloudLogs",
			logsForManagement:   true,
			logsForCompute:      true,
			platformLogs:        true,
			monitoring:          true,
			monitoringOnCompute: true,
			atrackerTargetType:  "cloudlogs",
			validationFunc:      lsf.ValidateBasicObservabilityClusterConfiguration,
		},
	}

	for _, sc := range scenarios {
		scenario := sc // capture range variable

		t.Run(scenario.name, func(t *testing.T) {

			testLogger.Info(t, fmt.Sprintf("Scenario %s started", scenario.name))

			clusterNamePrefix := utils.GenerateTimestampedClusterPrefix(utils.GenerateRandomString())
			testLogger.Info(t, fmt.Sprintf("Generated cluster prefix: %s", clusterNamePrefix))

			options, err := setupOptions(t, clusterNamePrefix, terraformDir, envVars.DefaultExistingResourceGroup)
			require.NoError(t, err, "Must initialize valid test options")

			options.TerraformVars["observability_enable_platform_logs"] = scenario.platformLogs
			options.TerraformVars["observability_logs_enable_for_management"] = scenario.logsForManagement
			options.TerraformVars["observability_logs_enable_for_compute"] = scenario.logsForCompute
			options.TerraformVars["observability_monitoring_enable"] = scenario.monitoring
			options.TerraformVars["observability_monitoring_on_compute_nodes_enable"] = scenario.monitoringOnCompute
			options.TerraformVars["observability_monitoring_plan"] = "graduated-tier"
			options.TerraformVars["observability_atracker_enable"] = true
			options.TerraformVars["observability_atracker_target_type"] = scenario.atrackerTargetType
			options.TerraformVars["zones"] = utils.SplitAndTrim(envVars.AttrackerTestZone, ",")
			options.SkipTestTearDown = true
			defer options.TestTearDown()

			testLogger.Info(t, fmt.Sprintf("Deploying cluster for: %s", scenario.name))
			err = lsf.VerifyClusterCreationAndConsistency(t, options, testLogger)
			require.NoError(t, err, "Cluster creation failed")

			testLogger.Info(t, "Starting validation...")
			scenario.validationFunc(t, options, testLogger)

			if t.Failed() {
				testLogger.Error(t, fmt.Sprintf("Scenario %s failed", scenario.name))
			} else {
				testLogger.PASS(t, fmt.Sprintf("Scenario %s passed", scenario.name))
			}
		})
	}
}

// TestObservabilityAtrackerCosAndCloudLogs provisions LSF clusters with different Atracker targets
// (COS and Cloud Logs) and validates basic observability integration.
//
// Each scenario disables logging and monitoring features while testing Atracker routing separately.
// This ensures that Atracker configurations function correctly, even when other observability
// options are turned off.
//
// Scenarios:
// - Atracker targeting COS
// - Atracker targeting Cloud Logs
//
// Note: Atracker route target capacity is limited to 1 per region. These test cases are run in parallel
// to validate coexistence across configurations within that constraint.

func TestObservabilityAtrackerWithCosAndCloudLogs(t *testing.T) {
	t.Parallel()

	setupTestSuite(t)
	require.NotNil(t, testLogger, "Test logger must be initialized")

	envVars, err := GetEnvVars()
	require.NoError(t, err, "Must load valid environment configuration")

	scenarios := []struct {
		name                string
		logsForManagement   bool
		logsForCompute      bool
		platformLogs        bool
		monitoring          bool
		monitoringOnCompute bool
		atrackerTargetType  string
		validationFunc      func(t *testing.T, options *testhelper.TestOptions, testLogger *utils.AggregatedLogger)
	}{
		{
			name:                "Atracker_COS_Only",
			logsForManagement:   false,
			logsForCompute:      false,
			platformLogs:        false,
			monitoring:          false,
			monitoringOnCompute: false,
			atrackerTargetType:  "cos",
			validationFunc:      lsf.ValidateBasicClusterConfigurationWithCloudAtracker,
		},
		{
			name:                "Atracker_CloudLogs_Only",
			logsForManagement:   false,
			logsForCompute:      false,
			platformLogs:        false,
			monitoring:          false,
			monitoringOnCompute: false,
			atrackerTargetType:  "cloudlogs",
			validationFunc:      lsf.ValidateBasicClusterConfigurationWithCloudAtracker,
		},
	}

	for _, sc := range scenarios {
		scenario := sc // capture range variable

		t.Run(scenario.name, func(t *testing.T) {
			t.Parallel()
			testLogger.Info(t, fmt.Sprintf("Scenario %s started", scenario.name))

			clusterNamePrefix := utils.GenerateTimestampedClusterPrefix(utils.GenerateRandomString())
			testLogger.Info(t, fmt.Sprintf("Generated cluster prefix: %s", clusterNamePrefix))

			options, err := setupOptions(t, clusterNamePrefix, terraformDir, envVars.DefaultExistingResourceGroup)
			require.NoError(t, err, "Must initialize valid test options")

			options.TerraformVars["observability_enable_platform_logs"] = scenario.platformLogs
			options.TerraformVars["observability_logs_enable_for_management"] = scenario.logsForManagement
			options.TerraformVars["observability_logs_enable_for_compute"] = scenario.logsForCompute
			options.TerraformVars["observability_monitoring_enable"] = scenario.monitoring
			options.TerraformVars["observability_monitoring_on_compute_nodes_enable"] = scenario.monitoringOnCompute
			options.TerraformVars["observability_monitoring_plan"] = "graduated-tier"
			options.TerraformVars["observability_atracker_enable"] = true
			options.TerraformVars["observability_atracker_target_type"] = scenario.atrackerTargetType
			options.TerraformVars["zones"] = utils.SplitAndTrim(envVars.AttrackerTestZone, ",")
			options.SkipTestTearDown = true
			defer options.TestTearDown()

			testLogger.Info(t, fmt.Sprintf("Deploying cluster for: %s", scenario.name))
			err = lsf.VerifyClusterCreationAndConsistency(t, options, testLogger)
			require.NoError(t, err, "Cluster creation failed")

			testLogger.Info(t, "Starting validation...")
			scenario.validationFunc(t, options, testLogger)

			if t.Failed() {
				testLogger.Error(t, fmt.Sprintf("Scenario %s failed", scenario.name))
			} else {
				testLogger.PASS(t, fmt.Sprintf("Scenario %s passed", scenario.name))
			}
		})
	}
}

// ******************** Region Specific Test *****************

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

	// Generate Unique Cluster Prefix
	clusterNamePrefix := utils.GenerateTimestampedClusterPrefix(utils.GenerateRandomString())
	testLogger.Info(t, fmt.Sprintf("Generated cluster prefix: %s", clusterNamePrefix))

	// Environment Configuration
	envVars, err := GetEnvVars()
	require.NoError(t, err, "Must load valid environment configuration")

	usEastZone := utils.SplitAndTrim(envVars.USEastZone, ",")
	require.NotEmpty(t, usEastZone, "Must provide valid US East zone configuration")
	testLogger.DEBUG(t, fmt.Sprintf("Using US East zones: %v", usEastZone))

	// Test Configuration
	options, err := setupOptions(
		t,
		clusterNamePrefix, // Generate Unique Cluster Prefix
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
	testLogger.Info(t, fmt.Sprintf("Starting cluster deployment for test: %s", t.Name()))

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

	// Generate Unique Cluster Prefix
	clusterNamePrefix := utils.GenerateTimestampedClusterPrefix(utils.GenerateRandomString())
	testLogger.Info(t, fmt.Sprintf("Generated cluster prefix: %s", clusterNamePrefix))

	// Environment Configuration
	envVars, err := GetEnvVars()
	require.NoError(t, err, "Must load valid environment configuration")

	euDeZone := utils.SplitAndTrim(envVars.EUDEZone, ",")
	require.NotEmpty(t, euDeZone, "Must provide valid Frankfurt zone configuration")
	testLogger.DEBUG(t, fmt.Sprintf("Using Frankfurt zones: %v", euDeZone))

	// Test Configuration
	options, err := setupOptions(
		t,
		clusterNamePrefix, // Generate Unique Cluster Prefix
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
	testLogger.Info(t, fmt.Sprintf("Starting cluster deployment for test: %s", t.Name()))

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

	// Generate Unique Cluster Prefix
	clusterNamePrefix := utils.GenerateTimestampedClusterPrefix(utils.GenerateRandomString())
	testLogger.Info(t, fmt.Sprintf("Generated cluster prefix: %s", clusterNamePrefix))

	// Environment Configuration
	envVars, err := GetEnvVars()
	require.NoError(t, err, "Must load valid environment configuration")

	usSouthZone := utils.SplitAndTrim(envVars.USSouthZone, ",")
	require.NotEmpty(t, usSouthZone, "Must provide valid US South zone configuration")
	testLogger.DEBUG(t, fmt.Sprintf("Using US South zones: %v", usSouthZone))

	// Test Configuration
	options, err := setupOptions(
		t,
		clusterNamePrefix, // Generate Unique Cluster Prefix
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
	testLogger.Info(t, fmt.Sprintf("Starting cluster deployment for test: %s", t.Name()))

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

	// Generate Unique Cluster Prefix
	clusterNamePrefix := utils.GenerateTimestampedClusterPrefix(utils.GenerateRandomString())
	testLogger.Info(t, fmt.Sprintf("Generated cluster prefix: %s", clusterNamePrefix))

	// Environment Configuration
	envVars, err := GetEnvVars()
	require.NoError(t, err, "Must load valid environment configuration")

	jpTokyoZone := utils.SplitAndTrim(envVars.JPTokZone, ",")
	require.NotEmpty(t, jpTokyoZone, "Must provide valid Japan Tokyo zone configuration")
	testLogger.DEBUG(t, fmt.Sprintf("Using Japan Tokyo zones: %v", jpTokyoZone))

	// Test Configuration
	options, err := setupOptions(
		t,
		clusterNamePrefix, // Generate Unique Cluster Prefix
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
	testLogger.Info(t, fmt.Sprintf("Starting cluster deployment for test: %s", t.Name()))

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

// TestRunCIDRsAsNonDefault validates that a cluster can be deployed using non-default
// VPC and subnet CIDR blocks, ensuring isolation and custom networking flexibility.
func TestRunCIDRsAsNonDefault(t *testing.T) {
	t.Parallel()

	// Initialization and Setup
	setupTestSuite(t)
	require.NotNil(t, testLogger, "Test logger must be initialized")
	testLogger.Info(t, fmt.Sprintf("Test %s initiated", t.Name()))

	// Generate Unique Cluster Prefix
	clusterNamePrefix := utils.GenerateTimestampedClusterPrefix(utils.GenerateRandomString())
	testLogger.Info(t, fmt.Sprintf("Generated cluster prefix: %s", clusterNamePrefix))

	// Load Environment Configuration
	envVars, err := GetEnvVars()
	require.NoError(t, err, "Failed to load environment configuration")

	// Set Up Test Options
	options, err := setupOptions(t, clusterNamePrefix, terraformDir, envVars.DefaultExistingResourceGroup)
	require.NoError(t, err, "Failed to initialize test options")

	// Override CIDR blocks with custom values
	options.TerraformVars["vpc_cidr"] = "10.243.0.0/18"
	options.TerraformVars["vpc_cluster_private_subnets_cidr_blocks"] = "10.243.0.0/20"
	options.TerraformVars["vpc_cluster_login_private_subnets_cidr_blocks"] = "10.243.16.0/28"

	// Resource Cleanup Configuration
	options.SkipTestTearDown = true
	defer options.TestTearDown()

	// Cluster Deployment
	deploymentStart := time.Now()
	testLogger.Info(t, fmt.Sprintf("Starting cluster deployment for test: %s", t.Name()))

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

	// Generate Unique Cluster Prefix
	clusterNamePrefix := utils.GenerateTimestampedClusterPrefix(utils.GenerateRandomString())
	testLogger.Info(t, fmt.Sprintf("Generated cluster prefix: %s", clusterNamePrefix))

	// Test Configuration
	envVars, err := GetEnvVars()
	require.NoError(t, err, "Failed to load environment configuration")

	options, err := setupOptions(t, clusterNamePrefix, terraformDir, envVars.DefaultExistingResourceGroup)

	require.NoError(t, err, "Failed to initialize test options")

	// Resource Cleanup Configuration
	options.SkipTestTearDown = true
	defer options.TestTearDown()

	// Cluster Deployment
	deploymentStart := time.Now()
	testLogger.Info(t, fmt.Sprintf("Starting cluster deployment for test: %s", t.Name()))

	clusterCreationErr := lsf.VerifyClusterCreationAndConsistency(t, options, testLogger)
	require.NoError(t, clusterCreationErr, "Cluster creation validation failed")

	testLogger.Info(t, fmt.Sprintf("Cluster deployment completed (duration: %v)", time.Since(deploymentStart)))

	// Post-deployment Validation
	validationStart := time.Now()
	lsf.ValidateClusterConfigurationWithMultipleKeys(t, options, testLogger)
	testLogger.Info(t, fmt.Sprintf("Validation completed (duration: %v)", time.Since(validationStart)))

	// Test Result Evaluation
	if t.Failed() {
		testLogger.Error(t, fmt.Sprintf("Test %s failed — inspect validation logs for details", t.Name()))
	} else {
		testLogger.PASS(t, fmt.Sprintf("Test %s completed successfully", t.Name()))
	}
}

// TestRunMultiProfileStaticAndDynamic validates cluster deployment with multiple static and dynamic
// compute instance profiles to ensure mixed provisioning works as expected.
func TestRunMultiProfileStaticAndDynamic(t *testing.T) {
	t.Parallel()

	// Initialization and Setup
	setupTestSuite(t)
	require.NotNil(t, testLogger, "Test logger must be initialized")
	testLogger.Info(t, fmt.Sprintf("Test %s initiated", t.Name()))

	// Generate Unique Cluster Prefix
	clusterNamePrefix := utils.GenerateTimestampedClusterPrefix(utils.GenerateRandomString())
	testLogger.Info(t, fmt.Sprintf("Generated cluster prefix: %s", clusterNamePrefix))

	// Test Configuration
	envVars, err := GetEnvVars()
	require.NoError(t, err, "Failed to load environment configuration")

	options, err := setupOptions(t, clusterNamePrefix, terraformDir, envVars.DefaultExistingResourceGroup)
	require.NoError(t, err, "Failed to initialize test options")

	// Define multiple management instances
	options.TerraformVars["management_instances"] = []map[string]interface{}{

		{
			"profile": "bx2d-16x64",
			"count":   1,
			"image":   envVars.ManagementInstancesImage,
		},
		{
			"profile": "bx2-2x8",
			"count":   1,
			"image":   envVars.ManagementInstancesImage,
		},
	}

	// Define multiple static compute instances
	options.TerraformVars["static_compute_instances"] = []map[string]interface{}{
		{
			"profile": "bx2d-4x16",
			"count":   1,
			"image":   envVars.StaticComputeInstancesImage,
		},
		{
			"profile": "bx2-2x8",
			"count":   2,
			"image":   envVars.StaticComputeInstancesImage,
		},
	}

	// Define multiple dynamic compute instances
	options.TerraformVars["dynamic_compute_instances"] = []map[string]interface{}{
		{
			"profile": "cx2-2x4",
			"count":   10,
			"image":   envVars.DynamicComputeInstancesImage,
		},
	}

	// Resource Cleanup Configuration
	options.SkipTestTearDown = true
	defer options.TestTearDown()

	// Cluster Deployment
	deploymentStart := time.Now()
	testLogger.Info(t, fmt.Sprintf("Starting cluster deployment for test: %s", t.Name()))

	clusterCreationErr := lsf.VerifyClusterCreationAndConsistency(t, options, testLogger)
	require.NoError(t, clusterCreationErr, "Cluster creation validation failed")

	testLogger.Info(t, fmt.Sprintf("Cluster deployment completed (duration: %v)", time.Since(deploymentStart)))

	// Post-deployment Validation
	validationStart := time.Now()
	lsf.ValidateBasicClusterConfigurationForMultiProfileStaticAndDynamic(t, options, testLogger)
	testLogger.Info(t, fmt.Sprintf("Validation completed (duration: %v)", time.Since(validationStart)))

	// Test Result Evaluation
	if t.Failed() {
		testLogger.Error(t, fmt.Sprintf("Test %s failed — inspect validation logs for details", t.Name()))
	} else {
		testLogger.PASS(t, fmt.Sprintf("Test %s completed successfully", t.Name()))
	}
}

// ******************* Existing VPC ***************************

// TestRunCreateClusterWithExistingVPC as brand new
func TestRunCreateClusterWithExistingVPC(t *testing.T) {
	// Parallelize the test to run concurrently with others
	t.Parallel()

	// Set up the test suite and prepare the testing environment
	setupTestSuite(t)

	testLogger.Info(t, "Brand new VPC creation initiated for "+t.Name())

	// Generate Unique Cluster Prefix
	clusterNamePrefix := utils.GenerateTimestampedClusterPrefix(utils.GenerateRandomString())
	testLogger.Info(t, fmt.Sprintf("Generated cluster prefix: %s", clusterNamePrefix))

	// Get and validate environment variables
	envVars, err := GetEnvVars()
	require.NoError(t, err, "Failed to get environment variables")

	// Set up the test options with the relevant parameters, including environment variables and resource group, set up test environment
	options, err := setupOptionsVPC(t, clusterNamePrefix, createVpcTerraformDir, envVars.DefaultExistingResourceGroup)
	require.NoError(t, err, "Error setting up test options: %v", err)

	// Skip test teardown for further inspection
	options.SkipTestTearDown = true
	defer options.TestTearDown()

	// Cluster Deployment
	deploymentStart := time.Now()
	testLogger.Info(t, fmt.Sprintf("Starting cluster deployment for test: %s", t.Name()))
	output, err := options.RunTest()
	require.NoError(t, err, "Error running consistency test: %v", err)
	require.NotNil(t, output, "Expected non-nil output, but got nil")
	testLogger.Info(t, fmt.Sprintf("Cluster deployment completed (duration: %v)", time.Since(deploymentStart)))

	outputs := (options.LastTestTerraformOutputs)
	vpcName := outputs["vpc_name"].(string)

	bastionsubnetId, computesubnetIds := utils.GetSubnetIds(outputs)

	RunCreateClusterWithExistingVpcCIDRs(t, vpcName)
	RunCreateClusterWithExistingVpcSubnetsNoDns(t, vpcName, bastionsubnetId, computesubnetIds)

	// Test Result Evaluation
	if t.Failed() {
		testLogger.Error(t, fmt.Sprintf("Test %s failed - inspect validation logs", t.Name()))
	} else {
		testLogger.PASS(t, fmt.Sprintf("Test %s completed successfully", t.Name()))
	}
}

// RunCreateClusterWithExistingVpcCIDRs with Cidr blocks
func RunCreateClusterWithExistingVpcCIDRs(t *testing.T, vpcName string) {

	// Set up the test suite and prepare the testing environment
	setupTestSuite(t)

	// Log the initiation of the cluster creation process
	testLogger.Info(t, "Cluster creation process initiated for "+t.Name())

	// Generate Unique Cluster Prefix
	clusterNamePrefix := utils.GenerateTimestampedClusterPrefix(utils.GenerateRandomString())
	testLogger.Info(t, fmt.Sprintf("Generated cluster prefix: %s", clusterNamePrefix))

	// Static values for CIDR other than default CIDR
	vpcClusterPrivateSubnetsCidrBlocks := "10.241.32.0/24"
	vpcClusterLoginPrivateSubnetsCidrBlocks := "10.241.16.32/28"

	// Get and validate environment variables
	envVars, err := GetEnvVars()
	require.NoError(t, err, "Failed to get environment variables")

	// Set up the test options with the relevant parameters, including environment variables and resource group
	options, err := setupOptions(t, clusterNamePrefix, terraformDir, envVars.DefaultExistingResourceGroup)
	options.TerraformVars["vpc_name"] = vpcName
	options.TerraformVars["vpc_cluster_private_subnets_cidr_blocks"] = vpcClusterPrivateSubnetsCidrBlocks
	options.TerraformVars["vpc_cluster_login_private_subnets_cidr_blocks"] = vpcClusterLoginPrivateSubnetsCidrBlocks
	require.NoError(t, err, "Error setting up test options: %v", err)

	// Skip test teardown for further inspection
	options.SkipTestTearDown = true
	defer options.TestTearDown()

	// Cluster Deployment
	deploymentStart := time.Now()
	testLogger.Info(t, fmt.Sprintf("Starting cluster deployment for test: %s", t.Name()))

	clusterCreationErr := lsf.VerifyClusterCreationAndConsistency(t, options, testLogger)
	require.NoError(t, clusterCreationErr, "Cluster creation validation failed")
	testLogger.Info(t, fmt.Sprintf("Cluster deployment completed (duration: %v)", time.Since(deploymentStart)))

	lsf.ValidateClusterConfiguration(t, options, testLogger)

	testLogger.Info(t, fmt.Sprintf("Finished execution: %s", t.Name()))
}

// RunCreateClusterWithExistingVpcSubnetsNoDns with compute and login subnet id. Both custom_resolver and dns_instace null
func RunCreateClusterWithExistingVpcSubnetsNoDns(t *testing.T, vpcName string, bastionsubnetId string, computesubnetIds string) {

	// Set up the test suite and prepare the testing environment
	setupTestSuite(t)

	// Log the initiation of the cluster creation process
	testLogger.Info(t, "Cluster creation process initiated for "+t.Name())

	// Generate Unique Cluster Prefix
	clusterNamePrefix := utils.GenerateTimestampedClusterPrefix(utils.GenerateRandomString())
	testLogger.Info(t, fmt.Sprintf("Generated cluster prefix: %s", clusterNamePrefix))

	// Get and validate environment variables
	envVars, err := GetEnvVars()
	require.NoError(t, err, "Failed to get environment variables")

	// Set up the test options with the relevant parameters, including environment variables and resource group
	options, err := setupOptions(t, clusterNamePrefix, terraformDir, envVars.DefaultExistingResourceGroup)
	options.TerraformVars["vpc_name"] = vpcName
	options.TerraformVars["login_subnet_id"] = bastionsubnetId
	options.TerraformVars["cluster_subnet_id"] = computesubnetIds
	require.NoError(t, err, "Error setting up test options: %v", err)

	// Skip test teardown for further inspection
	options.SkipTestTearDown = true
	defer options.TestTearDown()

	// Cluster Deployment
	deploymentStart := time.Now()
	testLogger.Info(t, fmt.Sprintf("Starting cluster deployment for test: %s", t.Name()))

	clusterCreationErr := lsf.VerifyClusterCreationAndConsistency(t, options, testLogger)
	require.NoError(t, clusterCreationErr, "Cluster creation validation failed")
	testLogger.Info(t, fmt.Sprintf("Cluster deployment completed (duration: %v)", time.Since(deploymentStart)))

	lsf.ValidateClusterConfiguration(t, options, testLogger)
	testLogger.Info(t, fmt.Sprintf("Finished execution: %s", t.Name()))
}

// TestRunCreateVpcWithCustomDns brand new VPC with DNS
func TestRunCreateVpcWithCustomDns(t *testing.T) {
	// Parallelize the test to run concurrently with others
	t.Parallel()

	// Set up the test suite and prepare the testing environment
	setupTestSuite(t)

	// Log the initiation of the cluster creation process
	testLogger.Info(t, "Cluster creation process initiated for "+t.Name())

	// Generate Unique Cluster Prefix
	clusterNamePrefix := utils.GenerateTimestampedClusterPrefix(utils.GenerateRandomString())
	testLogger.Info(t, fmt.Sprintf("Generated cluster prefix: %s", clusterNamePrefix))

	// Get and validate environment variables
	envVars, err := GetEnvVars()
	require.NoError(t, err, "Failed to get environment variables")

	// Set up the test options with the relevant parameters, including environment variables and resource group, set up test environment
	options, err := setupOptionsVPC(t, clusterNamePrefix, createVpcTerraformDir, envVars.DefaultExistingResourceGroup)
	options.TerraformVars["enable_hub"] = true
	options.TerraformVars["dns_zone_name"] = "lsf.com"

	require.NoError(t, err, "Error setting up test options: %v", err)

	// Skip test teardown for further inspection
	options.SkipTestTearDown = true
	defer options.TestTearDown()

	// Cluster Deployment
	deploymentStart := time.Now()
	testLogger.Info(t, fmt.Sprintf("Starting cluster deployment for test: %s", t.Name()))
	output, err := options.RunTest()
	require.NoError(t, err, "Error running consistency test: %v", err)
	require.NotNil(t, output, "Expected non-nil output, but got nil")
	testLogger.Info(t, fmt.Sprintf("Cluster deployment completed (duration: %v)", time.Since(deploymentStart)))

	outputs := (options.LastTestTerraformOutputs)
	vpcName := outputs["vpc_name"].(string)
	instanceId, customResolverId := utils.GetDnsCustomResolverIds(outputs)
	bastionsubnetId, computesubnetIds := utils.GetSubnetIds(outputs)

	RunCreateClusterWithDnsAndResolver(t, vpcName, bastionsubnetId, computesubnetIds, instanceId, customResolverId)
	RunCreateClusterWithOnlyResolver(t, vpcName, bastionsubnetId, computesubnetIds, customResolverId)

	// Test Result Evaluation
	if t.Failed() {
		testLogger.Error(t, fmt.Sprintf("Test %s failed - inspect validation logs", t.Name()))
	} else {
		testLogger.PASS(t, fmt.Sprintf("Test %s completed successfully", t.Name()))
	}
}

// RunCreateClusterWithDnsAndResolver with existing custom_resolver_id and dns_instance_id
func RunCreateClusterWithDnsAndResolver(t *testing.T, vpcName string, bastionsubnetId string, computesubnetIds string, instanceId string, customResolverId string) {

	// Set up the test suite and prepare the testing environment
	setupTestSuite(t)

	// Log the initiation of the cluster creation process
	testLogger.Info(t, "Cluster creation process initiated for "+t.Name())

	// Generate Unique Cluster Prefix
	clusterNamePrefix := utils.GenerateTimestampedClusterPrefix(utils.GenerateRandomString())
	testLogger.Info(t, fmt.Sprintf("Generated cluster prefix: %s", clusterNamePrefix))

	// Get and validate environment variables
	envVars, err := GetEnvVars()
	require.NoError(t, err, "Failed to get environment variables")

	// Set up the test options with the relevant parameters, including environment variables and resource group
	options, err := setupOptions(t, clusterNamePrefix, terraformDir, envVars.DefaultExistingResourceGroup)
	options.TerraformVars["vpc_name"] = vpcName
	options.TerraformVars["login_subnet_id"] = bastionsubnetId
	options.TerraformVars["cluster_subnet_id"] = computesubnetIds
	options.TerraformVars["dns_instance_id"] = instanceId
	options.TerraformVars["dns_custom_resolver_id"] = customResolverId

	require.NoError(t, err, "Error setting up test options: %v", err)

	// Skip test teardown for further inspection
	options.SkipTestTearDown = true
	defer options.TestTearDown()

	// Cluster Deployment
	deploymentStart := time.Now()
	testLogger.Info(t, fmt.Sprintf("Starting cluster deployment for test: %s", t.Name()))

	clusterCreationErr := lsf.VerifyClusterCreationAndConsistency(t, options, testLogger)
	require.NoError(t, clusterCreationErr, "Cluster creation validation failed")
	testLogger.Info(t, fmt.Sprintf("Cluster deployment completed (duration: %v)", time.Since(deploymentStart)))

	lsf.ValidateClusterConfiguration(t, options, testLogger)
	testLogger.Info(t, fmt.Sprintf("Finished execution: %s", t.Name()))

}

// RunCreateClusterWithOnlyResolver with existing custom_resolver_id and new dns_instance_id
func RunCreateClusterWithOnlyResolver(t *testing.T, vpcName string, bastionsubnetId string, computesubnetIds string, customResolverId string) {

	// Set up the test suite and prepare the testing environment
	setupTestSuite(t)

	// Log the initiation of the cluster creation process
	testLogger.Info(t, "Cluster creation process initiated for "+t.Name())

	// Generate Unique Cluster Prefix
	clusterNamePrefix := utils.GenerateTimestampedClusterPrefix(utils.GenerateRandomString())
	testLogger.Info(t, fmt.Sprintf("Generated cluster prefix: %s", clusterNamePrefix))

	// Get and validate environment variables
	envVars, err := GetEnvVars()
	require.NoError(t, err, "Failed to get environment variables")

	// Set up the test options with the relevant parameters, including environment variables and resource group
	options, err := setupOptions(t, clusterNamePrefix, terraformDir, envVars.DefaultExistingResourceGroup)
	options.TerraformVars["vpc_name"] = vpcName
	options.TerraformVars["login_subnet_id"] = bastionsubnetId
	options.TerraformVars["cluster_subnet_id"] = computesubnetIds
	options.TerraformVars["dns_custom_resolver_id"] = customResolverId

	require.NoError(t, err, "Error setting up test options: %v", err)

	// Skip test teardown for further inspection
	options.SkipTestTearDown = true
	defer options.TestTearDown()

	// Cluster Deployment
	deploymentStart := time.Now()
	testLogger.Info(t, fmt.Sprintf("Starting cluster deployment for test: %s", t.Name()))

	clusterCreationErr := lsf.VerifyClusterCreationAndConsistency(t, options, testLogger)
	require.NoError(t, clusterCreationErr, "Cluster creation validation failed")
	testLogger.Info(t, fmt.Sprintf("Cluster deployment completed (duration: %v)", time.Since(deploymentStart)))

	lsf.ValidateClusterConfiguration(t, options, testLogger)
	testLogger.Info(t, fmt.Sprintf("Finished execution: %s", t.Name()))
}

// TestRunCreateVpcWithCustomDnsOnlyDNS creates a new VPC and uses custom DNS (DNS-only scenario)
func TestRunCreateVpcWithCustomDnsOnlyDNS(t *testing.T) {
	// Parallelize the test to run concurrently with others
	t.Parallel()

	// Set up the test suite and prepare the testing environment
	setupTestSuite(t)

	// Log the initiation of the cluster creation process
	testLogger.Info(t, "Cluster creation process initiated for "+t.Name())

	// Generate Unique Cluster Prefix
	clusterNamePrefix := utils.GenerateTimestampedClusterPrefix(utils.GenerateRandomString())
	testLogger.Info(t, fmt.Sprintf("Generated cluster prefix: %s", clusterNamePrefix))

	// Get and validate environment variables
	envVars, err := GetEnvVars()
	require.NoError(t, err, "Failed to get environment variables")

	// Set up the test options with the relevant parameters, including environment variables and resource group, set up test environment
	options, err := setupOptionsVPC(t, clusterNamePrefix, createVpcTerraformDir, envVars.DefaultExistingResourceGroup)
	options.TerraformVars["enable_hub"] = true
	options.TerraformVars["dns_zone_name"] = "lsf.com"

	require.NoError(t, err, "Error setting up test options: %v", err)

	// Skip test teardown for further inspection
	options.SkipTestTearDown = true
	defer options.TestTearDown()

	// Cluster Deployment
	deploymentStart := time.Now()
	testLogger.Info(t, fmt.Sprintf("Starting cluster deployment for test: %s", t.Name()))
	output, err := options.RunTest()
	require.NoError(t, err, "Error running consistency test: %v", err)
	require.NotNil(t, output, "Expected non-nil output, but got nil")
	testLogger.Info(t, fmt.Sprintf("Cluster deployment completed (duration: %v)", time.Since(deploymentStart)))

	outputs := (options.LastTestTerraformOutputs)
	instanceId, _ := utils.GetDnsCustomResolverIds(outputs)

	RunCreateClusterWithOnlyDns(t, instanceId)

	// Test Result Evaluation
	if t.Failed() {
		testLogger.Error(t, fmt.Sprintf("Test %s failed - inspect validation logs", t.Name()))
	} else {
		testLogger.PASS(t, fmt.Sprintf("Test %s completed successfully", t.Name()))
	}
}

// RunCreateClusterWithOnlyDns creates a cluster using existing DNS instance (custom_resolver_id = null)
func RunCreateClusterWithOnlyDns(t *testing.T, instanceId string) {

	// Set up the test suite and prepare the testing environment
	setupTestSuite(t)

	// Log the initiation of the cluster creation process
	testLogger.Info(t, "Cluster creation process initiated for "+t.Name())

	// Generate Unique Cluster Prefix
	clusterNamePrefix := utils.GenerateTimestampedClusterPrefix(utils.GenerateRandomString())
	testLogger.Info(t, fmt.Sprintf("Generated cluster prefix: %s", clusterNamePrefix))

	// Get and validate environment variables
	envVars, err := GetEnvVars()
	require.NoError(t, err, "Failed to get environment variables")

	// Set up the test options with the relevant parameters, including environment variables and resource group
	options, err := setupOptions(t, clusterNamePrefix, terraformDir, envVars.DefaultExistingResourceGroup)
	options.TerraformVars["dns_instance_id"] = instanceId

	require.NoError(t, err, "Error setting up test options: %v", err)

	// Skip test teardown for further inspection
	options.SkipTestTearDown = true
	defer options.TestTearDown()

	// Cluster Deployment
	deploymentStart := time.Now()
	testLogger.Info(t, fmt.Sprintf("Starting cluster deployment for test: %s", t.Name()))

	clusterCreationErr := lsf.VerifyClusterCreationAndConsistency(t, options, testLogger)
	require.NoError(t, clusterCreationErr, "Cluster creation validation failed")
	testLogger.Info(t, fmt.Sprintf("Cluster deployment completed (duration: %v)", time.Since(deploymentStart)))

	lsf.ValidateClusterConfiguration(t, options, testLogger)
	testLogger.Info(t, fmt.Sprintf("Finished execution: %s", t.Name()))
}

// ******************* Existing VPC ***************************
