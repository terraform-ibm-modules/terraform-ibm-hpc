package tests

import (
	"fmt"
	"strings"
	"testing"
	"time"

	"github.com/stretchr/testify/require"
	"github.com/terraform-ibm-modules/ibmcloud-terratest-wrapper/testhelper"
	lsf "github.com/terraform-ibm-modules/terraform-ibm-hpc/lsf"
	utils "github.com/terraform-ibm-modules/terraform-ibm-hpc/utilities"
)

// TestRunSCCWPAndCSPMEnabledClusterValidation tests basic cluster validation with SCCWP and CSPM enabled.
func TestRunSCCWPAndCSPMEnabledClusterValidation(t *testing.T) {
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

	// Skip if SCCWP is disabled — t.Skip marks the test as skipped (not failed)
	// so CI pipelines correctly distinguish skipped from failed.
	if strings.ToLower(envVars.EnableSccwp) == "false" {
		testLogger.Warn(t, fmt.Sprintf("Skipping %s — SCCWP disabled in configuration", t.Name()))
		t.Skip("SCCWP disabled in environment configuration")
	}

	options, err := setupOptions(t, clusterNamePrefix, terraformDir, envVars.DefaultExistingResourceGroup)
	require.NoError(t, err, "Failed to initialize test options")
	testLogger.Info(t, "Test options initialized successfully")

	// Override default zones with observability-specific region (default_region=false).
	applyRegionOverrides(t, envVars, options, "observability")
	testLogger.Info(t, "Region overrides applied for observability cluster configuration")

	options.TerraformVars["management_instances"] = []map[string]interface{}{
		{
			"profile": "bx2-4x16",
			"count":   1,
			"image":   envVars.ManagementInstancesImage,
		},
	}
	options.TerraformVars["enable_sccwp"] = envVars.EnableSccwp
	options.TerraformVars["enable_cspm"] = envVars.EnableCspm
	options.TerraformVars["sccwp_service_plan"] = envVars.SccwpServicePlan
	options.TerraformVars["app_config_plan"] = envVars.AppConfigPlan
	testLogger.Info(t, "SCCWP and CSPM Terraform variables configured")

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

		lsf.ValidateBasicClusterConfigurationWithSCCWPAndCSPM(t, options, testLogger)

		testLogger.Info(t, fmt.Sprintf("[END] Cluster validation completed successfully (duration: %v)", time.Since(validationStart)))
	})
}

// TestRunCosAndVpcFlowLogs validates cluster creation with COS integration and VPC flow logs enabled.
// Verifies proper configuration of both features and their integration with the cluster.
//
// Prerequisites:
//   - Valid environment configuration
//   - Proper test suite initialization
//   - Permissions to enable COS and VPC flow logs
func TestRunCosAndVpcFlowLogs(t *testing.T) {
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

	// Override default zones with observability-specific region (default_region=false).
	applyRegionOverrides(t, envVars, options, "observability")
	testLogger.Info(t, "Region overrides applied for observability cluster configuration")

	options.TerraformVars["enable_cos_integration"] = true
	options.TerraformVars["enable_vpc_flow_logs"] = true
	testLogger.Info(t, "COS integration and VPC flow logs enabled")

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

		lsf.ValidateBasicClusterConfigurationWithVPCFlowLogsAndCos(t, options, testLogger)

		testLogger.Info(t, fmt.Sprintf("[END] Cluster validation completed successfully (duration: %v)", time.Since(validationStart)))
	})
}

// TestRunLSFLogs validates proper configuration of LSF management logs.
// Verifies log directory structure, symbolic links, and log collection.
//
// Prerequisites:
//   - Valid environment configuration
//   - Cluster with at least two management nodes
//   - Proper test suite initialization
func TestRunLSFLogs(t *testing.T) {
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

	// Override default zones with observability-specific region (default_region=false).
	applyRegionOverrides(t, envVars, options, "observability")
	testLogger.Info(t, "Region overrides applied for observability cluster configuration")

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

		lsf.ValidateBasicClusterConfigurationLSFLogs(t, options, testLogger)

		testLogger.Info(t, fmt.Sprintf("[END] Cluster validation completed successfully (duration: %v)", time.Since(validationStart)))
	})
}

// TestObservabilityAllFeaturesDisabled verifies cluster creation when all observability features
// (logs, monitoring, Atracker) are disabled. It ensures that the cluster functions correctly
// without any observability configurations.
//
// Prerequisites:
//   - Valid environment setup
//   - No dependency on observability services
func TestObservabilityAllFeaturesDisabled(t *testing.T) {
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

	// Override default zones with observability-specific region (default_region=false).
	applyRegionOverrides(t, envVars, options, "observability")
	testLogger.Info(t, "Region overrides applied for observability cluster configuration")

	// All observability features explicitly disabled.
	options.TerraformVars["observability_enable_platform_logs"] = false
	options.TerraformVars["observability_logs_enable_for_management"] = false
	options.TerraformVars["observability_logs_enable_for_compute"] = false
	options.TerraformVars["observability_monitoring_enable"] = false
	options.TerraformVars["observability_monitoring_on_compute_nodes_enable"] = false
	options.TerraformVars["observability_monitoring_plan"] = "graduated-tier"
	options.TerraformVars["observability_atracker_enable"] = false
	options.TerraformVars["observability_atracker_target_type"] = "cos"
	testLogger.Info(t, "All observability features disabled")

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

		lsf.ValidateBasicObservabilityClusterConfiguration(t, options, testLogger)

		testLogger.Info(t, fmt.Sprintf("[END] Cluster validation completed successfully (duration: %v)", time.Since(validationStart)))
	})
}

// TestObservabilityLogsEnabledForManagementAndCompute validates cluster creation with
// observability logs enabled for both management and compute nodes.
//
// Prerequisites:
//   - Valid environment setup
//   - Permissions to enable log services
func TestObservabilityLogsEnabledForManagementAndCompute(t *testing.T) {
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

	// Override default zones with observability-specific region (default_region=false).
	applyRegionOverrides(t, envVars, options, "observability")
	testLogger.Info(t, "Region overrides applied for observability cluster configuration")

	// Enable logs for management and compute; disable other observability features.
	options.TerraformVars["observability_logs_enable_for_management"] = true
	options.TerraformVars["observability_logs_enable_for_compute"] = true
	options.TerraformVars["observability_enable_platform_logs"] = false
	options.TerraformVars["observability_monitoring_enable"] = false
	options.TerraformVars["observability_monitoring_on_compute_nodes_enable"] = false
	options.TerraformVars["observability_monitoring_plan"] = "graduated-tier"
	options.TerraformVars["observability_atracker_enable"] = false
	options.TerraformVars["observability_atracker_target_type"] = "cos"
	testLogger.Info(t, "Observability logs enabled for management and compute nodes")

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

		lsf.ValidateBasicClusterConfigurationWithCloudLogs(t, options, testLogger)

		testLogger.Info(t, fmt.Sprintf("[END] Cluster validation completed successfully (duration: %v)", time.Since(validationStart)))
	})
}

// TestObservabilityMonitoringEnabledForManagementAndCompute validates cluster creation with
// observability monitoring enabled for both management and compute nodes.
//
// Prerequisites:
//   - Valid environment setup
//   - Permissions to enable monitoring features
func TestObservabilityMonitoringEnabledForManagementAndCompute(t *testing.T) {
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

	// Override default zones with observability-specific region (default_region=false).
	applyRegionOverrides(t, envVars, options, "observability")
	testLogger.Info(t, "Region overrides applied for observability cluster configuration")

	// Enable monitoring for management and compute; disable logs and Atracker.
	options.TerraformVars["observability_logs_enable_for_management"] = false
	options.TerraformVars["observability_logs_enable_for_compute"] = false
	options.TerraformVars["observability_enable_platform_logs"] = false
	options.TerraformVars["observability_monitoring_enable"] = true
	options.TerraformVars["observability_monitoring_on_compute_nodes_enable"] = true
	options.TerraformVars["observability_monitoring_plan"] = "graduated-tier"
	options.TerraformVars["observability_atracker_enable"] = false
	options.TerraformVars["observability_atracker_target_type"] = "cloudlogs"
	testLogger.Info(t, "Observability monitoring enabled for management and compute nodes")

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

		lsf.ValidateBasicClusterConfigurationWithCloudMonitoring(t, options, testLogger)

		testLogger.Info(t, fmt.Sprintf("[END] Cluster validation completed successfully (duration: %v)", time.Since(validationStart)))
	})
}

// TestObservabilityAtrackerLoggingMonitoring provisions LSF clusters with full observability
// configurations, including logging, monitoring, and Atracker integration, to verify
// end-to-end behaviour across different targets.
//
// Scenarios covered:
//   - Logging and monitoring enabled, Atracker targeting COS
//   - Logging and monitoring enabled, Atracker targeting Cloud Logs
//
// Note: Due to Atracker's 1-target-per-region limit, COS and Cloud Logs scenarios are
// executed sequentially.
func TestObservabilityAtrackerLoggingMonitoring(t *testing.T) {
	t.Helper()
	t.Parallel()

	// ── 1. Initialization ────────────────────────────────────────────────────
	setupTestSuite(t)
	require.NotNil(t, testLogger, "Test logger must be initialized before use")
	testLogger.Info(t, fmt.Sprintf("[START] Test %s initiated", t.Name()))

	// ── 2. Configuration ─────────────────────────────────────────────────────
	envVars, err := GetEnvVars()
	require.NoError(t, err, "Failed to load environment configuration")
	testLogger.Info(t, "Environment variables loaded successfully")

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

	// ── 3. Scenario Execution ─────────────────────────────────────────────────
	// Scenarios are intentionally sequential — Atracker supports only one target
	// per region. Do NOT add t.Parallel() to this loop.
	for _, sc := range scenarios {
		scenario := sc // capture range variable

		t.Run(scenario.name, func(t *testing.T) {
			t.Helper()
			defer logResult(t)
			testLogger.Info(t, fmt.Sprintf("[START] Scenario %s initiated", scenario.name))

			clusterNamePrefix := utils.GenerateTimestampedClusterPrefix(utils.GenerateRandomString())
			testLogger.Info(t, fmt.Sprintf("Generated cluster name prefix: %s", clusterNamePrefix))

			options, err := setupOptions(t, clusterNamePrefix, terraformDir, envVars.DefaultExistingResourceGroup)
			require.NoError(t, err, "Failed to initialize test options")
			testLogger.Info(t, "Test options initialized successfully")

			// Override default zones with observability-specific region (default_region=false).
			applyRegionOverrides(t, envVars, options, "observability")
			testLogger.Info(t, "Region overrides applied for observability cluster configuration")

			options.TerraformVars["observability_enable_platform_logs"] = scenario.platformLogs
			options.TerraformVars["observability_logs_enable_for_management"] = scenario.logsForManagement
			options.TerraformVars["observability_logs_enable_for_compute"] = scenario.logsForCompute
			options.TerraformVars["observability_monitoring_enable"] = scenario.monitoring
			options.TerraformVars["observability_monitoring_on_compute_nodes_enable"] = scenario.monitoringOnCompute
			options.TerraformVars["observability_monitoring_plan"] = "graduated-tier"
			options.TerraformVars["observability_atracker_enable"] = true
			options.TerraformVars["observability_atracker_target_type"] = scenario.atrackerTargetType
			options.TerraformVars["zones"] = utils.SplitAndTrim(envVars.AttrackerTestZone, ",")
			testLogger.Info(t, fmt.Sprintf("Observability Terraform variables configured (Atracker target: %s)", scenario.atrackerTargetType))

			// Teardown for this scenario.
			options.SkipTestTearDown = true
			defer func() {
				testLogger.Info(t, fmt.Sprintf("Initiating resource teardown for scenario: %s", scenario.name))
				options.TestTearDown()
				testLogger.Info(t, fmt.Sprintf("Resource teardown completed for scenario: %s", scenario.name))
			}()

			// Deploy cluster for this scenario.
			// DeployCluster and ValidateCluster subtests run sequentially by design.
			// Neither calls t.Parallel(), so each t.Run blocks until the subtest
			// completes before the parent resumes.
			t.Run("DeployCluster", func(t *testing.T) {
				t.Helper()
				deploymentStart := time.Now()
				testLogger.Info(t, fmt.Sprintf("[START] Cluster deployment for scenario: %s", scenario.name))

				err := lsf.VerifyClusterCreationAndConsistency(t, options, testLogger)
				if err != nil {
					testLogger.FAIL(t, fmt.Sprintf("Cluster deployment failed after %v: %v", time.Since(deploymentStart), err))
					require.NoError(t, err, "Cluster creation and consistency check failed")
				}

				testLogger.Info(t, fmt.Sprintf("[END] Cluster deployment completed successfully (duration: %v)", time.Since(deploymentStart)))
			})

			require.False(t, t.Failed(), "DeployCluster failed — aborting scenario, skipping ValidateCluster")

			t.Run("ValidateCluster", func(t *testing.T) {
				t.Helper()
				validationStart := time.Now()
				testLogger.Info(t, fmt.Sprintf("[START] Cluster validation for scenario: %s", scenario.name))

				scenario.validationFunc(t, options, testLogger)

				testLogger.Info(t, fmt.Sprintf("[END] Cluster validation completed successfully (duration: %v)", time.Since(validationStart)))
			})
		})
	}
}

// TestObservabilityAtrackerWithCosAndCloudLogs provisions LSF clusters with different Atracker
// targets (COS and Cloud Logs) and validates basic observability integration.
//
// Each scenario disables logging and monitoring features while testing Atracker routing
// separately. This ensures that Atracker configurations function correctly, even when other
// observability options are turned off.
//
// Scenarios:
//   - Atracker targeting COS
//   - Atracker targeting Cloud Logs
//
// Note: Scenarios run in parallel — each targets a different region zone, so the
// 1-target-per-region Atracker limit is not violated.
func TestObservabilityAtrackerWithCosAndCloudLogs(t *testing.T) {
	t.Helper()
	t.Parallel()

	// ── 1. Initialization ────────────────────────────────────────────────────
	setupTestSuite(t)
	require.NotNil(t, testLogger, "Test logger must be initialized before use")
	testLogger.Info(t, fmt.Sprintf("[START] Test %s initiated", t.Name()))

	// ── 2. Configuration ─────────────────────────────────────────────────────
	envVars, err := GetEnvVars()
	require.NoError(t, err, "Failed to load environment configuration")
	testLogger.Info(t, "Environment variables loaded successfully")

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

	// ── 3. Scenario Execution ─────────────────────────────────────────────────
	for _, sc := range scenarios {
		scenario := sc // capture range variable

		t.Run(scenario.name, func(t *testing.T) {
			t.Helper()
			t.Parallel()
			defer logResult(t)
			testLogger.Info(t, fmt.Sprintf("[START] Scenario %s initiated", scenario.name))

			clusterNamePrefix := utils.GenerateTimestampedClusterPrefix(utils.GenerateRandomString())
			testLogger.Info(t, fmt.Sprintf("Generated cluster name prefix: %s", clusterNamePrefix))

			options, err := setupOptions(t, clusterNamePrefix, terraformDir, envVars.DefaultExistingResourceGroup)
			require.NoError(t, err, "Failed to initialize test options")
			testLogger.Info(t, "Test options initialized successfully")

			// Override default zones with observability-specific region (default_region=false).
			applyRegionOverrides(t, envVars, options, "observability")
			testLogger.Info(t, "Region overrides applied for observability cluster configuration")

			options.TerraformVars["observability_enable_platform_logs"] = scenario.platformLogs
			options.TerraformVars["observability_logs_enable_for_management"] = scenario.logsForManagement
			options.TerraformVars["observability_logs_enable_for_compute"] = scenario.logsForCompute
			options.TerraformVars["observability_monitoring_enable"] = scenario.monitoring
			options.TerraformVars["observability_monitoring_on_compute_nodes_enable"] = scenario.monitoringOnCompute
			options.TerraformVars["observability_monitoring_plan"] = "graduated-tier"
			options.TerraformVars["observability_atracker_enable"] = true
			options.TerraformVars["observability_atracker_target_type"] = scenario.atrackerTargetType
			options.TerraformVars["zones"] = utils.SplitAndTrim(envVars.AttrackerTestZone, ",")
			testLogger.Info(t, fmt.Sprintf("Observability Terraform variables configured (Atracker target: %s)", scenario.atrackerTargetType))

			// Teardown for this scenario.
			options.SkipTestTearDown = true
			defer func() {
				testLogger.Info(t, fmt.Sprintf("Initiating resource teardown for scenario: %s", scenario.name))
				options.TestTearDown()
				testLogger.Info(t, fmt.Sprintf("Resource teardown completed for scenario: %s", scenario.name))
			}()

			// Deploy cluster for this scenario.
			// DeployCluster and ValidateCluster subtests run sequentially by design.
			// Neither calls t.Parallel(), so each t.Run blocks until the subtest
			// completes before the parent resumes.
			t.Run("DeployCluster", func(t *testing.T) {
				t.Helper()
				deploymentStart := time.Now()
				testLogger.Info(t, fmt.Sprintf("[START] Cluster deployment for scenario: %s", scenario.name))

				err := lsf.VerifyClusterCreationAndConsistency(t, options, testLogger)
				if err != nil {
					testLogger.FAIL(t, fmt.Sprintf("Cluster deployment failed after %v: %v", time.Since(deploymentStart), err))
					require.NoError(t, err, "Cluster creation and consistency check failed")
				}

				testLogger.Info(t, fmt.Sprintf("[END] Cluster deployment completed successfully (duration: %v)", time.Since(deploymentStart)))
			})

			require.False(t, t.Failed(), "DeployCluster failed — aborting scenario, skipping ValidateCluster")

			t.Run("ValidateCluster", func(t *testing.T) {
				t.Helper()
				validationStart := time.Now()
				testLogger.Info(t, fmt.Sprintf("[START] Cluster validation for scenario: %s", scenario.name))

				scenario.validationFunc(t, options, testLogger)

				testLogger.Info(t, fmt.Sprintf("[END] Cluster validation completed successfully (duration: %v)", time.Since(validationStart)))
			})
		})
	}
}
