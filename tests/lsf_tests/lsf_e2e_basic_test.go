package tests

import (
	"fmt"
	"testing"
	"time"

	"github.com/stretchr/testify/require"
	lsf "github.com/terraform-ibm-modules/terraform-ibm-hpc/lsf"
	utils "github.com/terraform-ibm-modules/terraform-ibm-hpc/utilities"
)

// ── Shared helper ─────────────────────────────────────────────────────────────

// logResult emits a final PASS or ERROR summary line for the parent test.
// Always call it via defer so it runs even when require stops the test early.
func logResult(t *testing.T) {
	t.Helper()
	if t.Failed() {
		testLogger.Error(t, fmt.Sprintf("Test %s failed — inspect validation logs for details", t.Name()))
	} else {
		testLogger.PASS(t, fmt.Sprintf("Test %s completed successfully", t.Name()))
	}
}

// ── Basic cluster tests ───────────────────────────────────────────────────────

// TestRunBasic validates the basic cluster configuration requirements.
// The test ensures proper resource isolation through random prefix generation
// and relies on ValidateBasicClusterConfiguration for resource cleanup.
//
// Prerequisites:
//   - Valid environment configuration
//   - Proper test suite initialization
//   - Required permissions for resource operations
func TestRunBasic(t *testing.T) {
	t.Parallel()

	// Initialization and Setup
	setupTestSuite(t)
	require.NotNil(t, testLogger, "Test logger must be initialized")
	defer logResult(t)
	testLogger.Info(t, fmt.Sprintf("Test %s initiated", t.Name()))

	// Generate Unique Cluster Prefix
	clusterNamePrefix := utils.GenerateTimestampedClusterPrefix(utils.GenerateRandomString())
	testLogger.Info(t, fmt.Sprintf("Generated cluster prefix: %s", clusterNamePrefix))

	// Test Configuration
	envVars, err := GetEnvVars()
	require.NoError(t, err, "Failed to load environment configuration")

	options, err := setupOptions(t, clusterNamePrefix, terraformDir, envVars.DefaultExistingResourceGroup)
	require.NoError(t, err, "Failed to initialize test options")

	// Override default zones with basic-specific region since default_region=false
	applyRegionOverrides(t, envVars, options, "basic")

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
		lsf.ValidateClusterConfiguration(t, options, testLogger)
		testLogger.Info(t, fmt.Sprintf("Validation completed (duration: %v)", time.Since(validationStart)))
	})
}

// TestRunDefaultWithWebServiceAsFalse validates the basic cluster configuration
// with web service and app center disabled.
//
// Prerequisites:
//   - Valid environment configuration
//   - Proper test suite initialization
//   - Required permissions for resource operations
func TestRunDefaultWithWebServiceAsFalse(t *testing.T) {
	t.Parallel()

	// Initialization and Setup
	setupTestSuite(t)
	require.NotNil(t, testLogger, "Test logger must be initialized")
	defer logResult(t)
	testLogger.Info(t, fmt.Sprintf("Test %s initiated", t.Name()))

	// Generate Unique Cluster Prefix
	clusterNamePrefix := utils.GenerateTimestampedClusterPrefix(utils.GenerateRandomString())
	testLogger.Info(t, fmt.Sprintf("Generated cluster prefix: %s", clusterNamePrefix))

	// Test Configuration
	envVars, err := GetEnvVars()
	require.NoError(t, err, "Failed to load environment configuration")

	options, err := setupOptions(t, clusterNamePrefix, terraformDir, envVars.DefaultExistingResourceGroup)
	require.NoError(t, err, "Failed to initialize test options")

	// Override default zones with basic-specific region since default_region=false
	applyRegionOverrides(t, envVars, options, "basic")

	options.TerraformVars["enable_webservice"] = false
	options.TerraformVars["enable_appcenter"] = false
	options.TerraformVars["webservice_appcenter_password"] = ""

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

// TestRunCustomRGA validates cluster creation with a null resource group value.
// Verifies proper handling of empty resource group specification and ensures
// resources are created in the expected default location.
//
// Prerequisites:
//   - Valid environment configuration
//   - Proper test suite initialization
//   - Permissions to create resources in default resource group
func TestRunCustomRGA(t *testing.T) {
	t.Parallel()

	// Initialization and Setup
	setupTestSuite(t)
	require.NotNil(t, testLogger, "Test logger must be initialized")
	defer logResult(t)
	testLogger.Info(t, fmt.Sprintf("Test %s initiated", t.Name()))

	// Generate Unique Cluster Prefix
	clusterNamePrefix := utils.GenerateTimestampedClusterPrefix(utils.GenerateRandomString())
	testLogger.Info(t, fmt.Sprintf("Generated cluster prefix: %s", clusterNamePrefix))

	// Test Configuration
	envVars, err := GetEnvVars()
	require.NoError(t, err, "Failed to load environment configuration")

	options, err := setupOptions(t, clusterNamePrefix, terraformDir, LSF_CUSTOM_EXISTING_RESOURCE_GROUP_VALUE_AS_NULL)
	require.NoError(t, err, "Failed to initialize test options")

	// Override default zones with basic-specific region since default_region=false
	applyRegionOverrides(t, envVars, options, "basic")

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

// TestRunCustomRGAsNonDefault validates cluster creation with a non-default resource group.
// Ensures proper resource creation in the specified resource group and verifies
// all components are correctly provisioned in the custom location.
//
// Prerequisites:
//   - Pre-existing non-default resource group
//   - Valid environment configuration
//   - Proper permissions on target resource group
func TestRunCustomRGAsNonDefault(t *testing.T) {
	t.Parallel()

	// Initialization and Setup
	setupTestSuite(t)
	require.NotNil(t, testLogger, "Test logger must be initialized")
	defer logResult(t)
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

	// Override default zones with basic-specific region since default_region=false
	applyRegionOverrides(t, envVars, options, "basic")

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

// TestRunLSFClusterCreationWithZeroWorkerNodes validates cluster creation with zero
// static worker nodes and dynamic scaling enabled.
//
// Prerequisites:
//   - Valid environment configuration
//   - Proper test suite initialization
//   - Permissions to create cluster with dynamic scaling
func TestRunLSFClusterCreationWithZeroWorkerNodes(t *testing.T) {
	t.Parallel()

	// Initialization and Setup
	setupTestSuite(t)
	require.NotNil(t, testLogger, "Test logger must be initialized")
	defer logResult(t)
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

// TestRunDedicatedHost validates cluster creation with dedicated hosts.
// Verifies proper provisioning and configuration of dedicated host resources.
//
// Prerequisites:
//   - Valid environment configuration
//   - Proper test suite initialization
//   - Permissions to create dedicated hosts
func TestRunDedicatedHost(t *testing.T) {
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

	// Setup Test Options
	options, err := setupOptions(t, clusterNamePrefix, terraformDir, envVars.DefaultExistingResourceGroup)
	require.NoError(t, err, "Failed to initialize test options")

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
		lsf.ValidateBasicClusterConfigurationWithDedicatedHost(t, options, true, testLogger)
		testLogger.Info(t, fmt.Sprintf("Validation completed (duration: %v)", time.Since(validationStart)))
	})
}

// TestRunCIDRsAsNonDefault validates that a cluster can be deployed using non-default
// VPC and subnet CIDR blocks, ensuring isolation and custom networking flexibility.
//
// Prerequisites:
//   - Valid environment configuration
//   - Proper test suite initialization
//   - Required permissions for resource operations
func TestRunCIDRsAsNonDefault(t *testing.T) {
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

	// Set Up Test Options
	options, err := setupOptions(t, clusterNamePrefix, terraformDir, envVars.DefaultExistingResourceGroup)
	require.NoError(t, err, "Failed to initialize test options")

	// Override default zones with basic-specific region since default_region=false
	applyRegionOverrides(t, envVars, options, "basic")

	// Override CIDR blocks with custom values
	options.TerraformVars["vpc_cidr"] = "10.243.0.0/18"
	options.TerraformVars["vpc_cluster_private_subnets_cidr_blocks"] = "10.243.0.0/20"
	options.TerraformVars["vpc_cluster_login_private_subnets_cidr_blocks"] = "10.243.16.0/28"

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

// TestRunMultipleSSHKeys validates cluster creation with multiple SSH keys configured.
// Verifies proper handling and authentication with multiple SSH keys.
//
// Prerequisites:
//   - Valid environment configuration
//   - Proper test suite initialization
//   - Multiple SSH keys configured in environment
func TestRunMultipleSSHKeys(t *testing.T) {
	t.Parallel()

	// Initialization and Setup
	setupTestSuite(t)
	require.NotNil(t, testLogger, "Test logger must be initialized")
	defer logResult(t)
	testLogger.Info(t, fmt.Sprintf("Test %s initiated", t.Name()))

	// Generate Unique Cluster Prefix
	clusterNamePrefix := utils.GenerateTimestampedClusterPrefix(utils.GenerateRandomString())
	testLogger.Info(t, fmt.Sprintf("Generated cluster prefix: %s", clusterNamePrefix))

	// Test Configuration
	envVars, err := GetEnvVars()
	require.NoError(t, err, "Failed to load environment configuration")

	options, err := setupOptions(t, clusterNamePrefix, terraformDir, envVars.DefaultExistingResourceGroup)
	require.NoError(t, err, "Failed to initialize test options")

	// Override default zones with basic-specific region since default_region=false
	applyRegionOverrides(t, envVars, options, "basic")

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
		lsf.ValidateClusterConfigurationWithMultipleKeys(t, options, testLogger)
		testLogger.Info(t, fmt.Sprintf("Validation completed (duration: %v)", time.Since(validationStart)))
	})
}

// TestRunMultiProfileStaticAndDynamic validates cluster deployment with multiple static
// and dynamic compute instance profiles to ensure mixed provisioning works as expected.
//
// Prerequisites:
//   - Valid environment configuration
//   - Proper test suite initialization
//   - Required permissions for resource operations
func TestRunMultiProfileStaticAndDynamic(t *testing.T) {
	t.Parallel()

	// Initialization and Setup
	setupTestSuite(t)
	require.NotNil(t, testLogger, "Test logger must be initialized")
	defer logResult(t)
	testLogger.Info(t, fmt.Sprintf("Test %s initiated", t.Name()))

	// Generate Unique Cluster Prefix
	clusterNamePrefix := utils.GenerateTimestampedClusterPrefix(utils.GenerateRandomString())
	testLogger.Info(t, fmt.Sprintf("Generated cluster prefix: %s", clusterNamePrefix))

	// Test Configuration
	envVars, err := GetEnvVars()
	require.NoError(t, err, "Failed to load environment configuration")

	options, err := setupOptions(t, clusterNamePrefix, terraformDir, envVars.DefaultExistingResourceGroup)
	require.NoError(t, err, "Failed to initialize test options")

	// Override default zones with basic-specific region since default_region=false
	applyRegionOverrides(t, envVars, options, "basic")

	// Define multiple management instances
	options.TerraformVars["management_instances"] = []map[string]interface{}{
		{
			"profile": "bx2d-4x16",
			"count":   1,
			"image":   envVars.ManagementInstancesImage,
		},
		{
			"profile": "bx2-4x16",
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
		lsf.ValidateBasicClusterConfigurationForMultiProfileStaticAndDynamic(t, options, testLogger)
		testLogger.Info(t, fmt.Sprintf("Validation completed (duration: %v)", time.Since(validationStart)))
	})
}

// TestRunNoKMSAndHTOff validates cluster creation without KMS and with hyperthreading
// disabled. Verifies proper cluster operation with these specific configurations.
//
// Prerequisites:
//   - Valid environment configuration
//   - Proper test suite initialization
//   - Permissions to create resources without KMS
func TestRunNoKMSAndHTOff(t *testing.T) {
	t.Parallel()

	// Initialization and Setup
	setupTestSuite(t)
	require.NotNil(t, testLogger, "Test logger must be initialized")
	defer logResult(t)
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

	// Override default zones with basic-specific region since default_region=false
	applyRegionOverrides(t, envVars, options, "basic")

	// Special Configuration
	options.TerraformVars["enable_cos_integration"] = false
	options.TerraformVars["enable_vpc_flow_logs"] = false
	options.TerraformVars["key_management"] = "null"
	// FIX: was strings.ToLower("false") — a no-op on an already-lowercase literal
	// that also passed a string where Terraform expects a boolean.
	options.TerraformVars["enable_hyperthreading"] = false

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

// ── Region-specific tests ─────────────────────────────────────────────────────
//
// Region tests set options.TerraformVars["zones"] directly from the environment
// variable for each target region instead of calling applyRegionOverrides, because
// they intentionally target a specific zone rather than the default basic region.

// TestRunInUSEastRegion validates cluster creation in the US East region.
//
// Prerequisites:
//   - Valid US East zone configuration in environment (USEastZone)
//   - Proper test suite initialization
//   - Permissions to create resources in US East region
func TestRunInUSEastRegion(t *testing.T) {
	t.Parallel()

	// Initialization and Setup
	setupTestSuite(t)
	require.NotNil(t, testLogger, "Test logger must be initialized")
	defer logResult(t)
	testLogger.Info(t, fmt.Sprintf("Test %s initiated", t.Name()))

	// Generate Unique Cluster Prefix
	clusterNamePrefix := utils.GenerateTimestampedClusterPrefix(utils.GenerateRandomString())
	testLogger.Info(t, fmt.Sprintf("Generated cluster prefix: %s", clusterNamePrefix))

	// Environment Configuration
	envVars, err := GetEnvVars()
	require.NoError(t, err, "Failed to load environment configuration")

	usEastZone := utils.SplitAndTrim(envVars.USEastZone, ",")
	require.NotEmpty(t, usEastZone, "Must provide valid US East zone configuration")
	testLogger.DEBUG(t, fmt.Sprintf("Using US East zones: %v", usEastZone))

	// Test Configuration
	options, err := setupOptions(t, clusterNamePrefix, terraformDir, envVars.DefaultExistingResourceGroup)
	require.NoError(t, err, "Failed to initialize test options")

	// Region-Specific Configuration
	options.TerraformVars["zones"] = usEastZone

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

// TestRunInEUDeRegion validates cluster creation in the Frankfurt (EU-DE) region.
//
// Prerequisites:
//   - Valid EU-DE zone configuration in environment (EUDEZone)
//   - Proper test suite initialization
//   - Permissions to create resources in EU-DE region
func TestRunInEUDeRegion(t *testing.T) {
	t.Parallel()

	// Initialization and Setup
	setupTestSuite(t)
	require.NotNil(t, testLogger, "Test logger must be initialized")
	defer logResult(t)
	testLogger.Info(t, fmt.Sprintf("Test %s initiated", t.Name()))

	// Generate Unique Cluster Prefix
	clusterNamePrefix := utils.GenerateTimestampedClusterPrefix(utils.GenerateRandomString())
	testLogger.Info(t, fmt.Sprintf("Generated cluster prefix: %s", clusterNamePrefix))

	// Environment Configuration
	envVars, err := GetEnvVars()
	require.NoError(t, err, "Failed to load environment configuration")

	euDeZone := utils.SplitAndTrim(envVars.EUDEZone, ",")
	require.NotEmpty(t, euDeZone, "Must provide valid Frankfurt zone configuration")
	testLogger.DEBUG(t, fmt.Sprintf("Using Frankfurt zones: %v", euDeZone))

	// Test Configuration
	options, err := setupOptions(t, clusterNamePrefix, terraformDir, envVars.DefaultExistingResourceGroup)
	require.NoError(t, err, "Failed to initialize test options")

	// Region-Specific Configuration
	options.TerraformVars["zones"] = euDeZone

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

// TestRunInUSSouthRegion validates cluster creation in the US South region.
//
// Prerequisites:
//   - Valid US South zone configuration in environment (USSouthZone)
//   - Proper test suite initialization
//   - Permissions to create resources in US South region
func TestRunInUSSouthRegion(t *testing.T) {
	t.Parallel()

	// Initialization and Setup
	setupTestSuite(t)
	require.NotNil(t, testLogger, "Test logger must be initialized")
	defer logResult(t)
	testLogger.Info(t, fmt.Sprintf("Test %s initiated", t.Name()))

	// Generate Unique Cluster Prefix
	clusterNamePrefix := utils.GenerateTimestampedClusterPrefix(utils.GenerateRandomString())
	testLogger.Info(t, fmt.Sprintf("Generated cluster prefix: %s", clusterNamePrefix))

	// Environment Configuration
	envVars, err := GetEnvVars()
	require.NoError(t, err, "Failed to load environment configuration")

	usSouthZone := utils.SplitAndTrim(envVars.USSouthZone, ",")
	require.NotEmpty(t, usSouthZone, "Must provide valid US South zone configuration")
	testLogger.DEBUG(t, fmt.Sprintf("Using US South zones: %v", usSouthZone))

	// Test Configuration
	options, err := setupOptions(t, clusterNamePrefix, terraformDir, envVars.DefaultExistingResourceGroup)
	require.NoError(t, err, "Failed to initialize test options")

	// Region-Specific Configuration
	options.TerraformVars["zones"] = usSouthZone

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

// TestRunInJPTokRegion validates cluster creation in the Japan Tokyo region.
//
// Prerequisites:
//   - Valid Japan Tokyo zone configuration in environment (JPTokZone)
//   - Proper test suite initialization
//   - Permissions to create resources in Japan Tokyo region
func TestRunInJPTokRegion(t *testing.T) {
	t.Parallel()

	// Initialization and Setup
	setupTestSuite(t)
	require.NotNil(t, testLogger, "Test logger must be initialized")
	defer logResult(t)
	testLogger.Info(t, fmt.Sprintf("Test %s initiated", t.Name()))

	// Generate Unique Cluster Prefix
	clusterNamePrefix := utils.GenerateTimestampedClusterPrefix(utils.GenerateRandomString())
	testLogger.Info(t, fmt.Sprintf("Generated cluster prefix: %s", clusterNamePrefix))

	// Environment Configuration
	envVars, err := GetEnvVars()
	require.NoError(t, err, "Failed to load environment configuration")

	jpTokyoZone := utils.SplitAndTrim(envVars.JPTokZone, ",")
	require.NotEmpty(t, jpTokyoZone, "Must provide valid Japan Tokyo zone configuration")
	testLogger.DEBUG(t, fmt.Sprintf("Using Japan Tokyo zones: %v", jpTokyoZone))

	// Test Configuration
	options, err := setupOptions(t, clusterNamePrefix, terraformDir, envVars.DefaultExistingResourceGroup)
	require.NoError(t, err, "Failed to initialize test options")

	// Region-Specific Configuration
	options.TerraformVars["zones"] = jpTokyoZone

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
