package tests

import (
	"fmt"
	"os"
	"testing"

	"github.com/stretchr/testify/require"
	lsf "github.com/terraform-ibm-modules/terraform-ibm-hpc/lsf"
	utils "github.com/terraform-ibm-modules/terraform-ibm-hpc/utilities"
)

// TestKMSInstanceWithExistingKey validates cluster creation with an
// existing Key Protect service instance and a pre-created KMS key.
// Verifies proper KMS integration and encryption functionality.
//
// Prerequisites:
//   - Valid IBM Cloud API key
//   - Permissions to create/delete KMS instances
//   - Proper test suite initialization
func TestKMSInstanceWithExistingKey(t *testing.T) {
	t.Helper()
	t.Parallel()

	// ── 1. Initialization ────────────────────────────────────────────────────
	setupTestSuite(t)
	require.NotNil(t, testLogger, "Test logger must be initialized before use")
	defer logResult(t)
	testLogger.Info(t, fmt.Sprintf("[START] Test %s initiated", t.Name()))

	// ── 2. Configuration ─────────────────────────────────────────────────────
	clusterNamePrefix := utils.GenerateTimestampedClusterPrefix(utils.GenerateRandomString())
	testLogger.Info(t, fmt.Sprintf("Generated cluster name prefix: %s", clusterNamePrefix))

	envVars, err := GetEnvVars()
	utils.NoError(t, err, "Failed to load environment configuration", testLogger)
	testLogger.Info(t, "Environment variables loaded successfully")

	apiKey := os.Getenv("TF_VAR_ibmcloud_api_key")
	require.NotEmpty(t, apiKey, "IBM Cloud API key must be set")

	region := utils.GetRegion(envVars.Zones)
	kmsInstanceName := "cicd-" + utils.GenerateRandomString()
	testLogger.Info(t, fmt.Sprintf("Creating KMS instance: %s in region: %s", kmsInstanceName, region))

	err = lsf.CreateServiceInstanceAndKmsKey(
		t,
		apiKey,
		region,
		envVars.DefaultExistingResourceGroup,
		kmsInstanceName,
		KMS_KEY_NAME,
		testLogger,
	)
	utils.NoError(t, err, "Failed to create KMS service instance and key", testLogger)
	testLogger.Info(t, fmt.Sprintf("KMS instance and key created successfully: %s", kmsInstanceName))

	// Defer KMS instance deletion independently of cluster teardown so the
	// KMS resource is always cleaned up even if cluster teardown fails.
	defer func() {
		testLogger.Info(t, fmt.Sprintf("Initiating KMS instance deletion: %s", kmsInstanceName))
		lsf.DeleteServiceInstanceAndAssociatedKeys(
			t,
			apiKey,
			region,
			envVars.DefaultExistingResourceGroup,
			kmsInstanceName,
			testLogger,
		)
		testLogger.Info(t, fmt.Sprintf("KMS instance deletion completed: %s", kmsInstanceName))
	}()

	options, err := setupOptions(t, clusterNamePrefix, terraformDir, envVars.DefaultExistingResourceGroup)
	utils.NoError(t, err, "Failed to initialize test options", testLogger)
	testLogger.Info(t, "Test options initialized successfully")

	// Override default zones with kms-specific region (default_region=false).
	applyRegionOverrides(t, envVars, options, "kms")
	testLogger.Info(t, "Region overrides applied for KMS cluster configuration")

	options.TerraformVars["key_management"] = "key_protect"
	options.TerraformVars["kms_instance_name"] = kmsInstanceName
	options.TerraformVars["kms_key_name"] = KMS_KEY_NAME
	testLogger.Info(t, "KMS Terraform variables configured")

	// ── 3. Teardown ──────────────────────────────────────────────────────────
	// SkipTestTearDown defers destruction to the explicit defer below, giving
	// us control over logging and sequencing around teardown.
	options.SkipTestTearDown = true
	defer func() {
		testLogger.Info(t, "Initiating final resource teardown...")
		options.TestTearDown()
		testLogger.Info(t, "Resource teardown completed")
	}()

	// ── 4. Deployment ────────────────────────────────────────────────────────
	utils.DeployCluster(t, options, testLogger)

	// ── 5. Validation ────────────────────────────────────────────────────────
	utils.RunValidateCluster(t, testLogger, func(t *testing.T) {
		lsf.ValidateBasicClusterConfiguration(t, options, testLogger)
	})
}

// TestKMSInstanceWithoutKey validates cluster creation with an
// existing KMS instance but no pre-specified key.
// Verifies proper handling of KMS instance without a specified key.
//
// Prerequisites:
//   - Valid IBM Cloud API key
//   - Permissions to create/delete KMS instances
//   - Proper test suite initialization
func TestKMSInstanceWithoutKey(t *testing.T) {
	t.Helper()
	t.Parallel()

	// ── 1. Initialization ────────────────────────────────────────────────────
	setupTestSuite(t)
	require.NotNil(t, testLogger, "Test logger must be initialized before use")
	defer logResult(t)
	testLogger.Info(t, fmt.Sprintf("[START] Test %s initiated", t.Name()))

	// ── 2. Configuration ─────────────────────────────────────────────────────
	clusterNamePrefix := utils.GenerateTimestampedClusterPrefix(utils.GenerateRandomString())
	testLogger.Info(t, fmt.Sprintf("Generated cluster name prefix: %s", clusterNamePrefix))

	envVars, err := GetEnvVars()
	utils.NoError(t, err, "Failed to load environment configuration", testLogger)
	testLogger.Info(t, "Environment variables loaded successfully")

	apiKey := os.Getenv("TF_VAR_ibmcloud_api_key")
	require.NotEmpty(t, apiKey, "IBM Cloud API key must be set")

	region := utils.GetRegion(envVars.Zones)
	kmsInstanceName := "cicd-" + utils.GenerateRandomString()
	testLogger.Info(t, fmt.Sprintf("Creating KMS instance: %s in region: %s", kmsInstanceName, region))

	err = lsf.CreateServiceInstanceAndKmsKey(
		t,
		apiKey,
		region,
		envVars.DefaultExistingResourceGroup,
		kmsInstanceName,
		KMS_KEY_NAME,
		testLogger,
	)
	utils.NoError(t, err, "Failed to create KMS service instance and key", testLogger)
	testLogger.Info(t, fmt.Sprintf("KMS instance and key created successfully: %s", kmsInstanceName))

	// Defer KMS instance deletion independently of cluster teardown so the
	// KMS resource is always cleaned up even if cluster teardown fails.
	defer func() {
		testLogger.Info(t, fmt.Sprintf("Initiating KMS instance deletion: %s", kmsInstanceName))
		lsf.DeleteServiceInstanceAndAssociatedKeys(
			t,
			apiKey,
			region,
			envVars.DefaultExistingResourceGroup,
			kmsInstanceName,
			testLogger,
		)
		testLogger.Info(t, fmt.Sprintf("KMS instance deletion completed: %s", kmsInstanceName))
	}()

	options, err := setupOptions(t, clusterNamePrefix, terraformDir, envVars.DefaultExistingResourceGroup)
	utils.NoError(t, err, "Failed to initialize test options", testLogger)
	testLogger.Info(t, "Test options initialized successfully")

	// Override default zones with kms-specific region (default_region=false).
	applyRegionOverrides(t, envVars, options, "kms")
	testLogger.Info(t, "Region overrides applied for KMS cluster configuration")

	// kms_key_name intentionally omitted — verifies cluster handles no pre-specified key.
	options.TerraformVars["key_management"] = "key_protect"
	options.TerraformVars["kms_instance_name"] = kmsInstanceName
	testLogger.Info(t, "KMS Terraform variables configured (no key specified)")

	// ── 3. Teardown ──────────────────────────────────────────────────────────
	options.SkipTestTearDown = true
	defer func() {
		testLogger.Info(t, "Initiating final resource teardown...")
		options.TestTearDown()
		testLogger.Info(t, "Resource teardown completed")
	}()

	// ── 4. Deployment ────────────────────────────────────────────────────────
	utils.DeployCluster(t, options, testLogger)

	// ── 5. Validation ────────────────────────────────────────────────────────
	utils.RunValidateCluster(t, testLogger, func(t *testing.T) {
		lsf.ValidateBasicClusterConfiguration(t, options, testLogger)
	})
}

// TestExistingKMSInstanceAndKeyWithAuthorizationPolicy validates that a cluster
// can be deployed using an existing KMS instance and key, assuming that the IAM
// authorization policy is already in place between the KMS instance and the VPC file share.
//
// Prerequisites:
//   - Valid IBM Cloud API key
//   - IAM authorization policy already enabled for the KMS instance and VPC file share
//   - Proper test suite initialization
func TestExistingKMSInstanceAndKeyWithAuthorizationPolicy(t *testing.T) {
	t.Helper()
	t.Parallel()

	// ── 1. Initialization ────────────────────────────────────────────────────
	setupTestSuite(t)
	require.NotNil(t, testLogger, "Test logger must be initialized before use")
	defer logResult(t)
	testLogger.Info(t, fmt.Sprintf("[START] Test %s initiated", t.Name()))

	// ── 2. Configuration ─────────────────────────────────────────────────────
	clusterNamePrefix := utils.GenerateTimestampedClusterPrefix(utils.GenerateRandomString())
	testLogger.Info(t, fmt.Sprintf("Generated cluster name prefix: %s", clusterNamePrefix))

	envVars, err := GetEnvVars()
	utils.NoError(t, err, "Failed to load environment configuration", testLogger)
	testLogger.Info(t, "Environment variables loaded successfully")

	apiKey := os.Getenv("TF_VAR_ibmcloud_api_key")
	require.NotEmpty(t, apiKey, "IBM Cloud API key must be set")
	testLogger.Info(t, "IBM Cloud API key validated")

	options, err := setupOptions(t, clusterNamePrefix, terraformDir, envVars.DefaultExistingResourceGroup)
	utils.NoError(t, err, "Failed to initialize test options", testLogger)
	testLogger.Info(t, "Test options initialized successfully")

	// Override default zones with kms-specific region (default_region=false).
	applyRegionOverrides(t, envVars, options, "kms")
	testLogger.Info(t, "Region overrides applied for KMS cluster configuration")

	// IAM authorization policies are pre-existing — skip creation to avoid conflicts.
	options.TerraformVars["key_management"] = "key_protect"
	options.TerraformVars["kms_instance_name"] = envVars.KMSInstanceName
	options.TerraformVars["kms_key_name"] = envVars.KMSKeyName
	options.TerraformVars["skip_iam_share_authorization_policy"] = true
	options.TerraformVars["skip_iam_block_storage_authorization_policy"] = true
	testLogger.Info(t, "KMS Terraform variables configured with pre-existing IAM authorization policies")

	// ── 3. Teardown ──────────────────────────────────────────────────────────
	options.SkipTestTearDown = true
	defer func() {
		testLogger.Info(t, "Initiating final resource teardown...")
		options.TestTearDown()
		testLogger.Info(t, "Resource teardown completed")
	}()

	// ── 4. Deployment ────────────────────────────────────────────────────────
	utils.DeployCluster(t, options, testLogger)

	// ── 5. Validation ────────────────────────────────────────────────────────
	utils.RunValidateCluster(t, testLogger, func(t *testing.T) {
		lsf.ValidateBasicClusterConfiguration(t, options, testLogger)
	})
}
