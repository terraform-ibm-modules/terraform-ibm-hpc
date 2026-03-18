package tests

import (
	"fmt"
	"os"
	"testing"
	"time"

	"github.com/stretchr/testify/require"
	lsf "github.com/terraform-ibm-modules/terraform-ibm-hpc/lsf"
	utils "github.com/terraform-ibm-modules/terraform-ibm-hpc/utilities"
)

// TestRunUsingExistingKMSInstanceAndExistingKey validates cluster creation with an
// existing Key Protect service instance and a pre-created KMS key.
// Verifies proper KMS integration and encryption functionality.
//
// Prerequisites:
//   - Valid IBM Cloud API key
//   - Permissions to create/delete KMS instances
//   - Proper test suite initialization
func TestRunUsingExistingKMSInstanceAndExistingKey(t *testing.T) {
	t.Parallel()

	// Initialization and Setup
	setupTestSuite(t)
	require.NotNil(t, testLogger, "Test logger must be initialized")
	defer logResult(t)
	testLogger.Info(t, fmt.Sprintf("Test %s initiated", t.Name()))

	// Generate Unique Cluster Prefix
	clusterNamePrefix := utils.GenerateTimestampedClusterPrefix(utils.GenerateRandomString())
	testLogger.Info(t, fmt.Sprintf("Generated cluster prefix: %s", clusterNamePrefix))

	// Load Environment Configuration
	envVars, err := GetEnvVars()
	require.NoError(t, err, "Failed to load environment configuration")

	// KMS Setup
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
		KMS_KEY_NAME,
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
	require.NoError(t, err, "Failed to initialize test options")

	// Override default zones with kms-specific region since default_region=false
	applyRegionOverrides(t, envVars, options, "kms")

	// Set KMS Terraform Variables
	options.TerraformVars["key_management"] = "key_protect"
	options.TerraformVars["kms_instance_name"] = kmsInstanceName
	options.TerraformVars["kms_key_name"] = KMS_KEY_NAME

	// Resource Cleanup Configuration
	options.SkipTestTearDown = true
	defer func() {
		testLogger.Info(t, "Final cleanup: destroying resources")
		options.TestTearDown()
	}()

	// Deploy Cluster
	// DeployCluster and ValidateCluster subtests are intentionally sequential.
	// Neither calls t.Parallel(), so t.Run blocks until each subtest completes
	// before the parent resumes. Do not add t.Parallel() to either subtest.
	t.Run("DeployCluster", func(t *testing.T) {
		deploymentStart := time.Now()
		testLogger.Info(t, fmt.Sprintf("Starting cluster deployment for test: %s", t.Name()))

		clusterCreationErr := lsf.VerifyClusterCreationAndConsistency(t, options, testLogger)
		if clusterCreationErr != nil {
			testLogger.Error(t, fmt.Sprintf("Cluster deployment failed after %v: %v", time.Since(deploymentStart), clusterCreationErr))
			require.NoError(t, clusterCreationErr, "Cluster creation failed")
		}
		testLogger.Info(t, fmt.Sprintf("Cluster deployment completed successfully (duration: %v)", time.Since(deploymentStart)))
	})

	// Abort the parent test immediately if DeployCluster failed.
	// Using require.False ensures the overall test is marked as FAILED (not skipped),
	// so CI pipelines correctly surface deployment failures.
	require.False(t, t.Failed(), "DeployCluster failed — aborting test, skipping ValidateCluster")

	// Post-deployment Validation
	t.Run("ValidateCluster", func(t *testing.T) {
		validationStart := time.Now()
		lsf.ValidateBasicClusterConfiguration(t, options, testLogger)
		testLogger.Info(t, fmt.Sprintf("Validation completed (duration: %v)", time.Since(validationStart)))
	})
}

// TestRunUsingExistingKMSInstanceAndWithoutKey validates cluster creation with an
// existing KMS instance but no pre-specified key.
// Verifies proper handling of KMS instance without a specified key.
//
// Prerequisites:
//   - Valid IBM Cloud API key
//   - Permissions to create/delete KMS instances
//   - Proper test suite initialization
func TestRunUsingExistingKMSInstanceAndWithoutKey(t *testing.T) {
	t.Parallel()

	// Initialization and Setup
	setupTestSuite(t)
	require.NotNil(t, testLogger, "Test logger must be initialized")
	defer logResult(t)
	testLogger.Info(t, fmt.Sprintf("Test %s initiated", t.Name()))

	// Generate Unique Cluster Prefix
	clusterNamePrefix := utils.GenerateTimestampedClusterPrefix(utils.GenerateRandomString())
	testLogger.Info(t, fmt.Sprintf("Generated cluster prefix: %s", clusterNamePrefix))

	// Load Environment Configuration
	envVars, err := GetEnvVars()
	require.NoError(t, err, "Failed to load environment configuration")

	// KMS Setup
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
		KMS_KEY_NAME,
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

	// Test Options Configuration
	options, err := setupOptions(t, clusterNamePrefix, terraformDir, envVars.DefaultExistingResourceGroup)
	require.NoError(t, err, "Failed to initialize test options")

	// Override default zones with kms-specific region since default_region=false
	applyRegionOverrides(t, envVars, options, "kms")

	// Set KMS Terraform Variables (no key specified)
	options.TerraformVars["key_management"] = "key_protect"
	options.TerraformVars["kms_instance_name"] = kmsInstanceName

	// Resource Cleanup Configuration
	options.SkipTestTearDown = true
	defer func() {
		testLogger.Info(t, "Final cleanup: destroying resources")
		options.TestTearDown()
	}()

	// Deploy Cluster
	// DeployCluster and ValidateCluster subtests are intentionally sequential.
	// Neither calls t.Parallel(), so t.Run blocks until each subtest completes
	// before the parent resumes. Do not add t.Parallel() to either subtest.
	t.Run("DeployCluster", func(t *testing.T) {
		deploymentStart := time.Now()
		testLogger.Info(t, fmt.Sprintf("Starting cluster deployment for test: %s", t.Name()))

		clusterCreationErr := lsf.VerifyClusterCreationAndConsistency(t, options, testLogger)
		if clusterCreationErr != nil {
			testLogger.Error(t, fmt.Sprintf("Cluster deployment failed after %v: %v", time.Since(deploymentStart), clusterCreationErr))
			require.NoError(t, clusterCreationErr, "Cluster creation failed")
		}
		testLogger.Info(t, fmt.Sprintf("Cluster deployment completed successfully (duration: %v)", time.Since(deploymentStart)))
	})

	// Abort the parent test immediately if DeployCluster failed.
	// Using require.False ensures the overall test is marked as FAILED (not skipped),
	// so CI pipelines correctly surface deployment failures.
	require.False(t, t.Failed(), "DeployCluster failed — aborting test, skipping ValidateCluster")

	// Post-deployment Validation
	t.Run("ValidateCluster", func(t *testing.T) {
		validationStart := time.Now()
		lsf.ValidateBasicClusterConfiguration(t, options, testLogger)
		testLogger.Info(t, fmt.Sprintf("Validation completed (duration: %v)", time.Since(validationStart)))
	})
}

// TestRunWithExistingKMSInstanceAndKeyWithAuthorizationPolicy validates that a cluster
// can be deployed using an existing KMS instance and key, assuming that the IAM
// authorization policy is already in place between the KMS instance and the VPC file share.
//
// Prerequisites:
//   - Valid IBM Cloud API key
//   - IAM authorization policy already enabled for the KMS instance and VPC file share
//   - Proper test suite initialization
func TestRunWithExistingKMSInstanceAndKeyWithAuthorizationPolicy(t *testing.T) {
	t.Parallel()

	// Initialization and Setup
	setupTestSuite(t)
	require.NotNil(t, testLogger, "Test logger must be initialized")
	defer logResult(t)
	testLogger.Info(t, fmt.Sprintf("Test %s initiated", t.Name()))

	// Generate Unique Cluster Prefix
	clusterNamePrefix := utils.GenerateTimestampedClusterPrefix(utils.GenerateRandomString())
	testLogger.Info(t, fmt.Sprintf("Generated cluster prefix: %s", clusterNamePrefix))

	// Load Environment Configuration
	envVars, err := GetEnvVars()
	require.NoError(t, err, "Failed to load environment configuration")

	// API Key Validation
	apiKey := os.Getenv("TF_VAR_ibmcloud_api_key")
	require.NotEmpty(t, apiKey, "IBM Cloud API key must be set")

	// Test Options Configuration
	options, err := setupOptions(t, clusterNamePrefix, terraformDir, envVars.DefaultExistingResourceGroup)
	require.NoError(t, err, "Failed to initialize test options")

	// Override default zones with kms-specific region since default_region=false
	applyRegionOverrides(t, envVars, options, "kms")

	// Set KMS Terraform Variables
	options.TerraformVars["key_management"] = "key_protect"
	options.TerraformVars["kms_instance_name"] = envVars.KMSInstanceName
	options.TerraformVars["kms_key_name"] = envVars.KMSKeyName
	options.TerraformVars["skip_iam_share_authorization_policy"] = true
	options.TerraformVars["skip_iam_block_storage_authorization_policy"] = true

	// Resource Cleanup Configuration
	options.SkipTestTearDown = true
	defer func() {
		testLogger.Info(t, "Final cleanup: destroying resources")
		options.TestTearDown()
	}()

	// Deploy Cluster
	// DeployCluster and ValidateCluster subtests are intentionally sequential.
	// Neither calls t.Parallel(), so t.Run blocks until each subtest completes
	// before the parent resumes. Do not add t.Parallel() to either subtest.
	t.Run("DeployCluster", func(t *testing.T) {
		deploymentStart := time.Now()
		testLogger.Info(t, fmt.Sprintf("Starting cluster deployment for test: %s", t.Name()))

		clusterCreationErr := lsf.VerifyClusterCreationAndConsistency(t, options, testLogger)
		if clusterCreationErr != nil {
			testLogger.Error(t, fmt.Sprintf("Cluster deployment failed after %v: %v", time.Since(deploymentStart), clusterCreationErr))
			require.NoError(t, clusterCreationErr, "Cluster creation failed")
		}
		testLogger.Info(t, fmt.Sprintf("Cluster deployment completed successfully (duration: %v)", time.Since(deploymentStart)))
	})

	// Abort the parent test immediately if DeployCluster failed.
	// Using require.False ensures the overall test is marked as FAILED (not skipped),
	// so CI pipelines correctly surface deployment failures.
	require.False(t, t.Failed(), "DeployCluster failed — aborting test, skipping ValidateCluster")

	// Post-deployment Validation
	t.Run("ValidateCluster", func(t *testing.T) {
		validationStart := time.Now()
		lsf.ValidateBasicClusterConfiguration(t, options, testLogger)
		testLogger.Info(t, fmt.Sprintf("Validation completed (duration: %v)", time.Since(validationStart)))
	})
}
