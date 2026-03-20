package tests

import (
	"fmt"
	"testing"
	"time"

	"github.com/stretchr/testify/require"
	lsf "github.com/terraform-ibm-modules/terraform-ibm-hpc/lsf"
	utils "github.com/terraform-ibm-modules/terraform-ibm-hpc/utilities"
)

// logResult emits a final PASS or FAIL summary line for the parent test.
// Always call it via defer so it runs even when require stops the test early.
func logResult(t *testing.T) {
	t.Helper()
	if t.Failed() {
		testLogger.FAIL(t, fmt.Sprintf("Test %s failed — inspect validation logs for details", t.Name()))
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
	require.NoError(t, err, "Failed to load environment configuration")
	testLogger.Info(t, "Environment variables loaded successfully")

	options, err := setupOptions(t, clusterNamePrefix, terraformDir, envVars.DefaultExistingResourceGroup)
	require.NoError(t, err, "Failed to initialize test options")
	testLogger.Info(t, "Test options initialized successfully")

	// Override default zones with basic-specific region (default_region=false).
	applyRegionOverrides(t, envVars, options, "basic")
	testLogger.Info(t, "Region overrides applied for basic cluster configuration")

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
	// DeployCluster and ValidateCluster subtests run sequentially by design.
	// Neither calls t.Parallel(), so each t.Run blocks until the subtest
	// completes before the parent resumes.
	t.Run("DeployCluster", func(t *testing.T) {
		t.Helper()
		deploymentStart := time.Now()
		testLogger.Info(t, fmt.Sprintf("[START] Cluster deployment for test: %s", t.Name()))

		err := lsf.VerifyClusterCreationAndConsistency(t, options, testLogger)
		if err != nil {
			testLogger.FAIL(t, fmt.Sprintf("Cluster deployment failed after %v: %v", time.Since(deploymentStart), err))
			require.NoError(t, err, "Cluster creation and consistency check failed")
		}

		testLogger.Info(t, fmt.Sprintf("[END] Cluster deployment completed successfully (duration: %v)", time.Since(deploymentStart)))
	})

	// Abort immediately if deployment failed.
	// require.False ensures the test is marked FAILED (not skipped), so CI
	// pipelines correctly surface deployment failures before validation runs.
	require.False(t, t.Failed(), "DeployCluster failed — aborting parent test, skipping ValidateCluster")

	// ── 5. Validation ────────────────────────────────────────────────────────
	t.Run("ValidateCluster", func(t *testing.T) {
		t.Helper()
		validationStart := time.Now()
		testLogger.Info(t, fmt.Sprintf("[START] Cluster validation for test: %s", t.Name()))

		lsf.ValidateClusterConfiguration(t, options, testLogger)

		testLogger.Info(t, fmt.Sprintf("[END] Cluster validation completed successfully (duration: %v)", time.Since(validationStart)))
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
	require.NoError(t, err, "Failed to load environment configuration")
	testLogger.Info(t, "Environment variables loaded successfully")

	options, err := setupOptions(t, clusterNamePrefix, terraformDir, envVars.DefaultExistingResourceGroup)
	require.NoError(t, err, "Failed to initialize test options")
	testLogger.Info(t, "Test options initialized successfully")

	// Override default zones with basic-specific region (default_region=false).
	applyRegionOverrides(t, envVars, options, "basic")
	testLogger.Info(t, "Region overrides applied for basic cluster configuration")

	options.TerraformVars["enable_webservice"] = false
	options.TerraformVars["enable_appcenter"] = false
	options.TerraformVars["webservice_appcenter_password"] = ""
	testLogger.Info(t, "Web service and app center disabled for this test")

	// ── 3. Teardown ──────────────────────────────────────────────────────────
	options.SkipTestTearDown = true
	defer func() {
		testLogger.Info(t, "Initiating final resource teardown...")
		options.TestTearDown()
		testLogger.Info(t, "Resource teardown completed")
	}()

	// ── 4. Deployment ────────────────────────────────────────────────────────
	// DeployCluster and ValidateCluster subtests run sequentially by design.
	// Neither calls t.Parallel(), so each t.Run blocks until the subtest
	// completes before the parent resumes.
	t.Run("DeployCluster", func(t *testing.T) {
		t.Helper()
		deploymentStart := time.Now()
		testLogger.Info(t, fmt.Sprintf("[START] Cluster deployment for test: %s", t.Name()))

		err := lsf.VerifyClusterCreationAndConsistency(t, options, testLogger)
		if err != nil {
			testLogger.FAIL(t, fmt.Sprintf("Cluster deployment failed after %v: %v", time.Since(deploymentStart), err))
			require.NoError(t, err, "Cluster creation and consistency check failed")
		}

		testLogger.Info(t, fmt.Sprintf("[END] Cluster deployment completed successfully (duration: %v)", time.Since(deploymentStart)))
	})

	require.False(t, t.Failed(), "DeployCluster failed — aborting parent test, skipping ValidateCluster")

	// ── 5. Validation ────────────────────────────────────────────────────────
	t.Run("ValidateCluster", func(t *testing.T) {
		t.Helper()
		validationStart := time.Now()
		testLogger.Info(t, fmt.Sprintf("[START] Cluster validation for test: %s", t.Name()))

		lsf.ValidateBasicClusterConfiguration(t, options, testLogger)

		testLogger.Info(t, fmt.Sprintf("[END] Cluster validation completed successfully (duration: %v)", time.Since(validationStart)))
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
	require.NoError(t, err, "Failed to load environment configuration")
	testLogger.Info(t, "Environment variables loaded successfully")

	options, err := setupOptions(t, clusterNamePrefix, terraformDir, LSF_CUSTOM_EXISTING_RESOURCE_GROUP_VALUE_AS_NULL)
	require.NoError(t, err, "Failed to initialize test options")
	testLogger.Info(t, "Test options initialized successfully")

	// Override default zones with basic-specific region (default_region=false).
	applyRegionOverrides(t, envVars, options, "basic")
	testLogger.Info(t, "Region overrides applied for basic cluster configuration")

	// ── 3. Teardown ──────────────────────────────────────────────────────────
	options.SkipTestTearDown = true
	defer func() {
		testLogger.Info(t, "Initiating final resource teardown...")
		options.TestTearDown()
		testLogger.Info(t, "Resource teardown completed")
	}()

	// ── 4. Deployment ────────────────────────────────────────────────────────
	// DeployCluster and ValidateCluster subtests run sequentially by design.
	// Neither calls t.Parallel(), so each t.Run blocks until the subtest
	// completes before the parent resumes.
	t.Run("DeployCluster", func(t *testing.T) {
		t.Helper()
		deploymentStart := time.Now()
		testLogger.Info(t, fmt.Sprintf("[START] Cluster deployment for test: %s", t.Name()))

		err := lsf.VerifyClusterCreationAndConsistency(t, options, testLogger)
		if err != nil {
			testLogger.FAIL(t, fmt.Sprintf("Cluster deployment failed after %v: %v", time.Since(deploymentStart), err))
			require.NoError(t, err, "Cluster creation and consistency check failed")
		}

		testLogger.Info(t, fmt.Sprintf("[END] Cluster deployment completed successfully (duration: %v)", time.Since(deploymentStart)))
	})

	require.False(t, t.Failed(), "DeployCluster failed — aborting parent test, skipping ValidateCluster")

	// ── 5. Validation ────────────────────────────────────────────────────────
	t.Run("ValidateCluster", func(t *testing.T) {
		t.Helper()
		validationStart := time.Now()
		testLogger.Info(t, fmt.Sprintf("[START] Cluster validation for test: %s", t.Name()))

		lsf.ValidateBasicClusterConfiguration(t, options, testLogger)

		testLogger.Info(t, fmt.Sprintf("[END] Cluster validation completed successfully (duration: %v)", time.Since(validationStart)))
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
	require.NoError(t, err, "Failed to load environment configuration")
	testLogger.Info(t, "Environment variables loaded successfully")

	options, err := setupOptions(t, clusterNamePrefix, terraformDir, envVars.NonDefaultExistingResourceGroup)
	require.NoError(t, err, "Failed to initialize test options")
	testLogger.Info(t, "Test options initialized successfully")

	// Override default zones with basic-specific region (default_region=false).
	applyRegionOverrides(t, envVars, options, "basic")
	testLogger.Info(t, "Region overrides applied for basic cluster configuration")

	// ── 3. Teardown ──────────────────────────────────────────────────────────
	options.SkipTestTearDown = true
	defer func() {
		testLogger.Info(t, "Initiating final resource teardown...")
		options.TestTearDown()
		testLogger.Info(t, "Resource teardown completed")
	}()

	// ── 4. Deployment ────────────────────────────────────────────────────────
	// DeployCluster and ValidateCluster subtests run sequentially by design.
	// Neither calls t.Parallel(), so each t.Run blocks until the subtest
	// completes before the parent resumes.
	t.Run("DeployCluster", func(t *testing.T) {
		t.Helper()
		deploymentStart := time.Now()
		testLogger.Info(t, fmt.Sprintf("[START] Cluster deployment for test: %s", t.Name()))

		err := lsf.VerifyClusterCreationAndConsistency(t, options, testLogger)
		if err != nil {
			testLogger.FAIL(t, fmt.Sprintf("Cluster deployment failed after %v: %v", time.Since(deploymentStart), err))
			require.NoError(t, err, "Cluster creation and consistency check failed")
		}

		testLogger.Info(t, fmt.Sprintf("[END] Cluster deployment completed successfully (duration: %v)", time.Since(deploymentStart)))
	})

	require.False(t, t.Failed(), "DeployCluster failed — aborting parent test, skipping ValidateCluster")

	// ── 5. Validation ────────────────────────────────────────────────────────
	t.Run("ValidateCluster", func(t *testing.T) {
		t.Helper()
		validationStart := time.Now()
		testLogger.Info(t, fmt.Sprintf("[START] Cluster validation for test: %s", t.Name()))

		lsf.ValidateBasicClusterConfiguration(t, options, testLogger)

		testLogger.Info(t, fmt.Sprintf("[END] Cluster validation completed successfully (duration: %v)", time.Since(validationStart)))
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
	require.NoError(t, err, "Failed to load environment configuration")
	testLogger.Info(t, "Environment variables loaded successfully")

	options, err := setupOptions(t, clusterNamePrefix, terraformDir, envVars.DefaultExistingResourceGroup)
	require.NoError(t, err, "Failed to initialize test options")
	testLogger.Info(t, "Test options initialized successfully")

	// Cluster profile: zero static workers, dynamic scaling enabled.
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
	testLogger.Info(t, "Cluster profile configured: zero static workers, dynamic scaling enabled")

	// ── 3. Teardown ──────────────────────────────────────────────────────────
	options.SkipTestTearDown = true
	defer func() {
		testLogger.Info(t, "Initiating final resource teardown...")
		options.TestTearDown()
		testLogger.Info(t, "Resource teardown completed")
	}()

	// ── 4. Deployment ────────────────────────────────────────────────────────
	// DeployCluster and ValidateCluster subtests run sequentially by design.
	// Neither calls t.Parallel(), so each t.Run blocks until the subtest
	// completes before the parent resumes.
	t.Run("DeployCluster", func(t *testing.T) {
		t.Helper()
		deploymentStart := time.Now()
		testLogger.Info(t, fmt.Sprintf("[START] Cluster deployment for test: %s", t.Name()))

		err := lsf.VerifyClusterCreationAndConsistency(t, options, testLogger)
		if err != nil {
			testLogger.FAIL(t, fmt.Sprintf("Cluster deployment failed after %v: %v", time.Since(deploymentStart), err))
			require.NoError(t, err, "Cluster creation and consistency check failed")
		}

		testLogger.Info(t, fmt.Sprintf("[END] Cluster deployment completed successfully (duration: %v)", time.Since(deploymentStart)))
	})

	require.False(t, t.Failed(), "DeployCluster failed — aborting parent test, skipping ValidateCluster")

	// ── 5. Validation ────────────────────────────────────────────────────────
	t.Run("ValidateCluster", func(t *testing.T) {
		t.Helper()
		validationStart := time.Now()
		testLogger.Info(t, fmt.Sprintf("[START] Cluster validation for test: %s", t.Name()))

		lsf.ValidateBasicClusterConfiguration(t, options, testLogger)

		testLogger.Info(t, fmt.Sprintf("[END] Cluster validation completed successfully (duration: %v)", time.Since(validationStart)))
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
	require.NoError(t, err, "Failed to load environment configuration")
	testLogger.Info(t, "Environment variables loaded successfully")

	options, err := setupOptions(t, clusterNamePrefix, terraformDir, envVars.DefaultExistingResourceGroup)
	require.NoError(t, err, "Failed to initialize test options")
	testLogger.Info(t, "Test options initialized successfully")

	// Dedicated host and compute profile configuration.
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
	testLogger.Info(t, "Dedicated host and compute profiles configured")

	// ── 3. Teardown ──────────────────────────────────────────────────────────
	options.SkipTestTearDown = true
	defer func() {
		testLogger.Info(t, "Initiating final resource teardown...")
		options.TestTearDown()
		testLogger.Info(t, "Resource teardown completed")
	}()

	// ── 4. Deployment ────────────────────────────────────────────────────────
	// DeployCluster and ValidateCluster subtests run sequentially by design.
	// Neither calls t.Parallel(), so each t.Run blocks until the subtest
	// completes before the parent resumes.
	t.Run("DeployCluster", func(t *testing.T) {
		t.Helper()
		deploymentStart := time.Now()
		testLogger.Info(t, fmt.Sprintf("[START] Cluster deployment for test: %s", t.Name()))

		err := lsf.VerifyClusterCreationAndConsistency(t, options, testLogger)
		if err != nil {
			testLogger.FAIL(t, fmt.Sprintf("Cluster deployment failed after %v: %v", time.Since(deploymentStart), err))
			require.NoError(t, err, "Cluster creation and consistency check failed")
		}

		testLogger.Info(t, fmt.Sprintf("[END] Cluster deployment completed successfully (duration: %v)", time.Since(deploymentStart)))
	})

	require.False(t, t.Failed(), "DeployCluster failed — aborting parent test, skipping ValidateCluster")

	// ── 5. Validation ────────────────────────────────────────────────────────
	t.Run("ValidateCluster", func(t *testing.T) {
		t.Helper()
		validationStart := time.Now()
		testLogger.Info(t, fmt.Sprintf("[START] Cluster validation for test: %s", t.Name()))

		lsf.ValidateBasicClusterConfigurationWithDedicatedHost(t, options, true, testLogger)

		testLogger.Info(t, fmt.Sprintf("[END] Cluster validation completed successfully (duration: %v)", time.Since(validationStart)))
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
	require.NoError(t, err, "Failed to load environment configuration")
	testLogger.Info(t, "Environment variables loaded successfully")

	options, err := setupOptions(t, clusterNamePrefix, terraformDir, envVars.DefaultExistingResourceGroup)
	require.NoError(t, err, "Failed to initialize test options")
	testLogger.Info(t, "Test options initialized successfully")

	// Override default zones with basic-specific region (default_region=false).
	applyRegionOverrides(t, envVars, options, "basic")
	testLogger.Info(t, "Region overrides applied for basic cluster configuration")

	// Override CIDR blocks with custom non-default values.
	options.TerraformVars["vpc_cidr"] = "10.243.0.0/18"
	options.TerraformVars["vpc_cluster_private_subnets_cidr_blocks"] = "10.243.0.0/20"
	options.TerraformVars["vpc_cluster_login_private_subnets_cidr_blocks"] = "10.243.16.0/28"
	testLogger.Info(t, "Custom CIDR blocks applied for VPC and subnets")

	// ── 3. Teardown ──────────────────────────────────────────────────────────
	options.SkipTestTearDown = true
	defer func() {
		testLogger.Info(t, "Initiating final resource teardown...")
		options.TestTearDown()
		testLogger.Info(t, "Resource teardown completed")
	}()

	// ── 4. Deployment ────────────────────────────────────────────────────────
	// DeployCluster and ValidateCluster subtests run sequentially by design.
	// Neither calls t.Parallel(), so each t.Run blocks until the subtest
	// completes before the parent resumes.
	t.Run("DeployCluster", func(t *testing.T) {
		t.Helper()
		deploymentStart := time.Now()
		testLogger.Info(t, fmt.Sprintf("[START] Cluster deployment for test: %s", t.Name()))

		err := lsf.VerifyClusterCreationAndConsistency(t, options, testLogger)
		if err != nil {
			testLogger.FAIL(t, fmt.Sprintf("Cluster deployment failed after %v: %v", time.Since(deploymentStart), err))
			require.NoError(t, err, "Cluster creation and consistency check failed")
		}

		testLogger.Info(t, fmt.Sprintf("[END] Cluster deployment completed successfully (duration: %v)", time.Since(deploymentStart)))
	})

	require.False(t, t.Failed(), "DeployCluster failed — aborting parent test, skipping ValidateCluster")

	// ── 5. Validation ────────────────────────────────────────────────────────
	t.Run("ValidateCluster", func(t *testing.T) {
		t.Helper()
		validationStart := time.Now()
		testLogger.Info(t, fmt.Sprintf("[START] Cluster validation for test: %s", t.Name()))

		lsf.ValidateBasicClusterConfiguration(t, options, testLogger)

		testLogger.Info(t, fmt.Sprintf("[END] Cluster validation completed successfully (duration: %v)", time.Since(validationStart)))
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
	require.NoError(t, err, "Failed to load environment configuration")
	testLogger.Info(t, "Environment variables loaded successfully")

	options, err := setupOptions(t, clusterNamePrefix, terraformDir, envVars.DefaultExistingResourceGroup)
	require.NoError(t, err, "Failed to initialize test options")
	testLogger.Info(t, "Test options initialized successfully")

	// Override default zones with basic-specific region (default_region=false).
	applyRegionOverrides(t, envVars, options, "basic")
	testLogger.Info(t, "Region overrides applied for basic cluster configuration")

	// ── 3. Teardown ──────────────────────────────────────────────────────────
	options.SkipTestTearDown = true
	defer func() {
		testLogger.Info(t, "Initiating final resource teardown...")
		options.TestTearDown()
		testLogger.Info(t, "Resource teardown completed")
	}()

	// ── 4. Deployment ────────────────────────────────────────────────────────
	// DeployCluster and ValidateCluster subtests run sequentially by design.
	// Neither calls t.Parallel(), so each t.Run blocks until the subtest
	// completes before the parent resumes.
	t.Run("DeployCluster", func(t *testing.T) {
		t.Helper()
		deploymentStart := time.Now()
		testLogger.Info(t, fmt.Sprintf("[START] Cluster deployment for test: %s", t.Name()))

		err := lsf.VerifyClusterCreationAndConsistency(t, options, testLogger)
		if err != nil {
			testLogger.FAIL(t, fmt.Sprintf("Cluster deployment failed after %v: %v", time.Since(deploymentStart), err))
			require.NoError(t, err, "Cluster creation and consistency check failed")
		}

		testLogger.Info(t, fmt.Sprintf("[END] Cluster deployment completed successfully (duration: %v)", time.Since(deploymentStart)))
	})

	require.False(t, t.Failed(), "DeployCluster failed — aborting parent test, skipping ValidateCluster")

	// ── 5. Validation ────────────────────────────────────────────────────────
	t.Run("ValidateCluster", func(t *testing.T) {
		t.Helper()
		validationStart := time.Now()
		testLogger.Info(t, fmt.Sprintf("[START] Cluster validation for test: %s", t.Name()))

		lsf.ValidateClusterConfigurationWithMultipleKeys(t, options, testLogger)

		testLogger.Info(t, fmt.Sprintf("[END] Cluster validation completed successfully (duration: %v)", time.Since(validationStart)))
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
	require.NoError(t, err, "Failed to load environment configuration")
	testLogger.Info(t, "Environment variables loaded successfully")

	options, err := setupOptions(t, clusterNamePrefix, terraformDir, envVars.DefaultExistingResourceGroup)
	require.NoError(t, err, "Failed to initialize test options")
	testLogger.Info(t, "Test options initialized successfully")

	// Override default zones with basic-specific region (default_region=false).
	applyRegionOverrides(t, envVars, options, "basic")
	testLogger.Info(t, "Region overrides applied for basic cluster configuration")

	// Multi-profile compute configuration.
	options.TerraformVars["management_instances"] = []map[string]interface{}{
		{"profile": "bx2d-4x16", "count": 1, "image": envVars.ManagementInstancesImage},
		{"profile": "bx2-4x16", "count": 1, "image": envVars.ManagementInstancesImage},
	}
	options.TerraformVars["static_compute_instances"] = []map[string]interface{}{
		{"profile": "bx2d-4x16", "count": 1, "image": envVars.StaticComputeInstancesImage},
		{"profile": "bx2-2x8", "count": 2, "image": envVars.StaticComputeInstancesImage},
	}
	options.TerraformVars["dynamic_compute_instances"] = []map[string]interface{}{
		{"profile": "cx2-2x4", "count": 10, "image": envVars.DynamicComputeInstancesImage},
	}
	testLogger.Info(t, "Multi-profile management, static, and dynamic compute instances configured")

	// ── 3. Teardown ──────────────────────────────────────────────────────────
	options.SkipTestTearDown = true
	defer func() {
		testLogger.Info(t, "Initiating final resource teardown...")
		options.TestTearDown()
		testLogger.Info(t, "Resource teardown completed")
	}()

	// ── 4. Deployment ────────────────────────────────────────────────────────
	// DeployCluster and ValidateCluster subtests run sequentially by design.
	// Neither calls t.Parallel(), so each t.Run blocks until the subtest
	// completes before the parent resumes.
	t.Run("DeployCluster", func(t *testing.T) {
		t.Helper()
		deploymentStart := time.Now()
		testLogger.Info(t, fmt.Sprintf("[START] Cluster deployment for test: %s", t.Name()))

		err := lsf.VerifyClusterCreationAndConsistency(t, options, testLogger)
		if err != nil {
			testLogger.FAIL(t, fmt.Sprintf("Cluster deployment failed after %v: %v", time.Since(deploymentStart), err))
			require.NoError(t, err, "Cluster creation and consistency check failed")
		}

		testLogger.Info(t, fmt.Sprintf("[END] Cluster deployment completed successfully (duration: %v)", time.Since(deploymentStart)))
	})

	require.False(t, t.Failed(), "DeployCluster failed — aborting parent test, skipping ValidateCluster")

	// ── 5. Validation ────────────────────────────────────────────────────────
	t.Run("ValidateCluster", func(t *testing.T) {
		t.Helper()
		validationStart := time.Now()
		testLogger.Info(t, fmt.Sprintf("[START] Cluster validation for test: %s", t.Name()))

		lsf.ValidateBasicClusterConfigurationForMultiProfileStaticAndDynamic(t, options, testLogger)

		testLogger.Info(t, fmt.Sprintf("[END] Cluster validation completed successfully (duration: %v)", time.Since(validationStart)))
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
	require.NoError(t, err, "Failed to load environment configuration")
	testLogger.Info(t, "Environment variables loaded successfully")

	options, err := setupOptions(t, clusterNamePrefix, terraformDir, envVars.DefaultExistingResourceGroup)
	require.NoError(t, err, "Failed to initialize test options")
	testLogger.Info(t, "Test options initialized successfully")

	// Override default zones with basic-specific region (default_region=false).
	applyRegionOverrides(t, envVars, options, "basic")
	testLogger.Info(t, "Region overrides applied for basic cluster configuration")

	// Disable KMS, VPC flow logs, COS integration, and hyperthreading.
	options.TerraformVars["enable_cos_integration"] = false
	options.TerraformVars["enable_vpc_flow_logs"] = false
	options.TerraformVars["key_management"] = "null"
	options.TerraformVars["enable_hyperthreading"] = false
	testLogger.Info(t, "KMS, VPC flow logs, COS integration, and hyperthreading disabled")

	// ── 3. Teardown ──────────────────────────────────────────────────────────
	options.SkipTestTearDown = true
	defer func() {
		testLogger.Info(t, "Initiating final resource teardown...")
		options.TestTearDown()
		testLogger.Info(t, "Resource teardown completed")
	}()

	// ── 4. Deployment ────────────────────────────────────────────────────────
	// DeployCluster and ValidateCluster subtests run sequentially by design.
	// Neither calls t.Parallel(), so each t.Run blocks until the subtest
	// completes before the parent resumes.
	t.Run("DeployCluster", func(t *testing.T) {
		t.Helper()
		deploymentStart := time.Now()
		testLogger.Info(t, fmt.Sprintf("[START] Cluster deployment for test: %s", t.Name()))

		err := lsf.VerifyClusterCreationAndConsistency(t, options, testLogger)
		if err != nil {
			testLogger.FAIL(t, fmt.Sprintf("Cluster deployment failed after %v: %v", time.Since(deploymentStart), err))
			require.NoError(t, err, "Cluster creation and consistency check failed")
		}

		testLogger.Info(t, fmt.Sprintf("[END] Cluster deployment completed successfully (duration: %v)", time.Since(deploymentStart)))
	})

	require.False(t, t.Failed(), "DeployCluster failed — aborting parent test, skipping ValidateCluster")

	// ── 5. Validation ────────────────────────────────────────────────────────
	t.Run("ValidateCluster", func(t *testing.T) {
		t.Helper()
		validationStart := time.Now()
		testLogger.Info(t, fmt.Sprintf("[START] Cluster validation for test: %s", t.Name()))

		lsf.ValidateBasicClusterConfiguration(t, options, testLogger)

		testLogger.Info(t, fmt.Sprintf("[END] Cluster validation completed successfully (duration: %v)", time.Since(validationStart)))
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
	require.NoError(t, err, "Failed to load environment configuration")
	testLogger.Info(t, "Environment variables loaded successfully")

	usEastZone := utils.SplitAndTrim(envVars.USEastZone, ",")
	require.NotEmpty(t, usEastZone, "Must provide valid US East zone configuration")
	testLogger.DEBUG(t, fmt.Sprintf("Using US East zones: %v", usEastZone))

	options, err := setupOptions(t, clusterNamePrefix, terraformDir, envVars.DefaultExistingResourceGroup)
	require.NoError(t, err, "Failed to initialize test options")
	testLogger.Info(t, "Test options initialized successfully")

	options.TerraformVars["zones"] = usEastZone
	testLogger.Info(t, fmt.Sprintf("Region configured: US East zones %v", usEastZone))

	// ── 3. Teardown ──────────────────────────────────────────────────────────
	options.SkipTestTearDown = true
	defer func() {
		testLogger.Info(t, "Initiating final resource teardown...")
		options.TestTearDown()
		testLogger.Info(t, "Resource teardown completed")
	}()

	// ── 4. Deployment ────────────────────────────────────────────────────────
	// DeployCluster and ValidateCluster subtests run sequentially by design.
	// Neither calls t.Parallel(), so each t.Run blocks until the subtest
	// completes before the parent resumes.
	t.Run("DeployCluster", func(t *testing.T) {
		t.Helper()
		deploymentStart := time.Now()
		testLogger.Info(t, fmt.Sprintf("[START] Cluster deployment for test: %s", t.Name()))

		err := lsf.VerifyClusterCreationAndConsistency(t, options, testLogger)
		if err != nil {
			testLogger.FAIL(t, fmt.Sprintf("Cluster deployment failed after %v: %v", time.Since(deploymentStart), err))
			require.NoError(t, err, "Cluster creation and consistency check failed")
		}

		testLogger.Info(t, fmt.Sprintf("[END] Cluster deployment completed successfully (duration: %v)", time.Since(deploymentStart)))
	})

	require.False(t, t.Failed(), "DeployCluster failed — aborting parent test, skipping ValidateCluster")

	// ── 5. Validation ────────────────────────────────────────────────────────
	t.Run("ValidateCluster", func(t *testing.T) {
		t.Helper()
		validationStart := time.Now()
		testLogger.Info(t, fmt.Sprintf("[START] Cluster validation for test: %s", t.Name()))

		lsf.ValidateBasicClusterConfiguration(t, options, testLogger)

		testLogger.Info(t, fmt.Sprintf("[END] Cluster validation completed successfully (duration: %v)", time.Since(validationStart)))
	})
}

// TestRunInEUDeRegion validates cluster creation in the Frankfurt (EU-DE) region.
//
// Prerequisites:
//   - Valid EU-DE zone configuration in environment (EUDEZone)
//   - Proper test suite initialization
//   - Permissions to create resources in EU-DE region
func TestRunInEUDeRegion(t *testing.T) {
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
	require.NoError(t, err, "Failed to load environment configuration")
	testLogger.Info(t, "Environment variables loaded successfully")

	euDeZone := utils.SplitAndTrim(envVars.EUDEZone, ",")
	require.NotEmpty(t, euDeZone, "Must provide valid Frankfurt zone configuration")
	testLogger.DEBUG(t, fmt.Sprintf("Using Frankfurt zones: %v", euDeZone))

	options, err := setupOptions(t, clusterNamePrefix, terraformDir, envVars.DefaultExistingResourceGroup)
	require.NoError(t, err, "Failed to initialize test options")
	testLogger.Info(t, "Test options initialized successfully")

	options.TerraformVars["zones"] = euDeZone
	testLogger.Info(t, fmt.Sprintf("Region configured: Frankfurt zones %v", euDeZone))

	// ── 3. Teardown ──────────────────────────────────────────────────────────
	options.SkipTestTearDown = true
	defer func() {
		testLogger.Info(t, "Initiating final resource teardown...")
		options.TestTearDown()
		testLogger.Info(t, "Resource teardown completed")
	}()

	// ── 4. Deployment ────────────────────────────────────────────────────────
	// DeployCluster and ValidateCluster subtests run sequentially by design.
	// Neither calls t.Parallel(), so each t.Run blocks until the subtest
	// completes before the parent resumes.
	t.Run("DeployCluster", func(t *testing.T) {
		t.Helper()
		deploymentStart := time.Now()
		testLogger.Info(t, fmt.Sprintf("[START] Cluster deployment for test: %s", t.Name()))

		err := lsf.VerifyClusterCreationAndConsistency(t, options, testLogger)
		if err != nil {
			testLogger.FAIL(t, fmt.Sprintf("Cluster deployment failed after %v: %v", time.Since(deploymentStart), err))
			require.NoError(t, err, "Cluster creation and consistency check failed")
		}

		testLogger.Info(t, fmt.Sprintf("[END] Cluster deployment completed successfully (duration: %v)", time.Since(deploymentStart)))
	})

	require.False(t, t.Failed(), "DeployCluster failed — aborting parent test, skipping ValidateCluster")

	// ── 5. Validation ────────────────────────────────────────────────────────
	t.Run("ValidateCluster", func(t *testing.T) {
		t.Helper()
		validationStart := time.Now()
		testLogger.Info(t, fmt.Sprintf("[START] Cluster validation for test: %s", t.Name()))

		lsf.ValidateBasicClusterConfiguration(t, options, testLogger)

		testLogger.Info(t, fmt.Sprintf("[END] Cluster validation completed successfully (duration: %v)", time.Since(validationStart)))
	})
}

// TestRunInUSSouthRegion validates cluster creation in the US South region.
//
// Prerequisites:
//   - Valid US South zone configuration in environment (USSouthZone)
//   - Proper test suite initialization
//   - Permissions to create resources in US South region
func TestRunInUSSouthRegion(t *testing.T) {
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
	require.NoError(t, err, "Failed to load environment configuration")
	testLogger.Info(t, "Environment variables loaded successfully")

	usSouthZone := utils.SplitAndTrim(envVars.USSouthZone, ",")
	require.NotEmpty(t, usSouthZone, "Must provide valid US South zone configuration")
	testLogger.DEBUG(t, fmt.Sprintf("Using US South zones: %v", usSouthZone))

	options, err := setupOptions(t, clusterNamePrefix, terraformDir, envVars.DefaultExistingResourceGroup)
	require.NoError(t, err, "Failed to initialize test options")
	testLogger.Info(t, "Test options initialized successfully")

	options.TerraformVars["zones"] = usSouthZone
	testLogger.Info(t, fmt.Sprintf("Region configured: US South zones %v", usSouthZone))

	// ── 3. Teardown ──────────────────────────────────────────────────────────
	options.SkipTestTearDown = true
	defer func() {
		testLogger.Info(t, "Initiating final resource teardown...")
		options.TestTearDown()
		testLogger.Info(t, "Resource teardown completed")
	}()

	// ── 4. Deployment ────────────────────────────────────────────────────────
	// DeployCluster and ValidateCluster subtests run sequentially by design.
	// Neither calls t.Parallel(), so each t.Run blocks until the subtest
	// completes before the parent resumes.
	t.Run("DeployCluster", func(t *testing.T) {
		t.Helper()
		deploymentStart := time.Now()
		testLogger.Info(t, fmt.Sprintf("[START] Cluster deployment for test: %s", t.Name()))

		err := lsf.VerifyClusterCreationAndConsistency(t, options, testLogger)
		if err != nil {
			testLogger.FAIL(t, fmt.Sprintf("Cluster deployment failed after %v: %v", time.Since(deploymentStart), err))
			require.NoError(t, err, "Cluster creation and consistency check failed")
		}

		testLogger.Info(t, fmt.Sprintf("[END] Cluster deployment completed successfully (duration: %v)", time.Since(deploymentStart)))
	})

	require.False(t, t.Failed(), "DeployCluster failed — aborting parent test, skipping ValidateCluster")

	// ── 5. Validation ────────────────────────────────────────────────────────
	t.Run("ValidateCluster", func(t *testing.T) {
		t.Helper()
		validationStart := time.Now()
		testLogger.Info(t, fmt.Sprintf("[START] Cluster validation for test: %s", t.Name()))

		lsf.ValidateBasicClusterConfiguration(t, options, testLogger)

		testLogger.Info(t, fmt.Sprintf("[END] Cluster validation completed successfully (duration: %v)", time.Since(validationStart)))
	})
}

// TestRunInJPTokRegion validates cluster creation in the Japan Tokyo region.
//
// Prerequisites:
//   - Valid Japan Tokyo zone configuration in environment (JPTokZone)
//   - Proper test suite initialization
//   - Permissions to create resources in Japan Tokyo region
func TestRunInJPTokRegion(t *testing.T) {
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
	require.NoError(t, err, "Failed to load environment configuration")
	testLogger.Info(t, "Environment variables loaded successfully")

	jpTokyoZone := utils.SplitAndTrim(envVars.JPTokZone, ",")
	require.NotEmpty(t, jpTokyoZone, "Must provide valid Japan Tokyo zone configuration")
	testLogger.DEBUG(t, fmt.Sprintf("Using Japan Tokyo zones: %v", jpTokyoZone))

	options, err := setupOptions(t, clusterNamePrefix, terraformDir, envVars.DefaultExistingResourceGroup)
	require.NoError(t, err, "Failed to initialize test options")
	testLogger.Info(t, "Test options initialized successfully")

	options.TerraformVars["zones"] = jpTokyoZone
	testLogger.Info(t, fmt.Sprintf("Region configured: Japan Tokyo zones %v", jpTokyoZone))

	// ── 3. Teardown ──────────────────────────────────────────────────────────
	options.SkipTestTearDown = true
	defer func() {
		testLogger.Info(t, "Initiating final resource teardown...")
		options.TestTearDown()
		testLogger.Info(t, "Resource teardown completed")
	}()

	// ── 4. Deployment ────────────────────────────────────────────────────────
	// DeployCluster and ValidateCluster subtests run sequentially by design.
	// Neither calls t.Parallel(), so each t.Run blocks until the subtest
	// completes before the parent resumes.
	t.Run("DeployCluster", func(t *testing.T) {
		t.Helper()
		deploymentStart := time.Now()
		testLogger.Info(t, fmt.Sprintf("[START] Cluster deployment for test: %s", t.Name()))

		err := lsf.VerifyClusterCreationAndConsistency(t, options, testLogger)
		if err != nil {
			testLogger.FAIL(t, fmt.Sprintf("Cluster deployment failed after %v: %v", time.Since(deploymentStart), err))
			require.NoError(t, err, "Cluster creation and consistency check failed")
		}

		testLogger.Info(t, fmt.Sprintf("[END] Cluster deployment completed successfully (duration: %v)", time.Since(deploymentStart)))
	})

	require.False(t, t.Failed(), "DeployCluster failed — aborting parent test, skipping ValidateCluster")

	// ── 5. Validation ────────────────────────────────────────────────────────
	t.Run("ValidateCluster", func(t *testing.T) {
		t.Helper()
		validationStart := time.Now()
		testLogger.Info(t, fmt.Sprintf("[START] Cluster validation for test: %s", t.Name()))

		lsf.ValidateBasicClusterConfiguration(t, options, testLogger)

		testLogger.Info(t, fmt.Sprintf("[END] Cluster validation completed successfully (duration: %v)", time.Since(validationStart)))
	})
}
