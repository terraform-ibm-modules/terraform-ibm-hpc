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

	// Skip the test if SCC is disabled
	if strings.ToLower(envVars.SccWPEnabled) == "false" {
		testLogger.Warn(t, fmt.Sprintf("Skipping %s - SCCWP disabled in configuration", t.Name()))
		return
	}

	options, err := setupOptions(t, clusterNamePrefix, terraformDir, envVars.DefaultExistingResourceGroup)
	require.NoError(t, err, "Failed to initialize test options")

	// Override default zones with observability-specific region since default_region=false
	applyRegionOverrides(t, envVars, options, "observability")

	// Define multiple management instances
	options.TerraformVars["management_instances"] = []map[string]interface{}{

		{
			"profile": "bx2-4x16",
			"count":   1,
			"image":   envVars.ManagementInstancesImage,
		},
	}

	// SCCWP Specific Configuration
	options.TerraformVars["enable_sccwp"] = envVars.SccWPEnabled
	options.TerraformVars["enable_cspm"] = envVars.CspmEnabled
	options.TerraformVars["sccwp_service_plan"] = envVars.SccwpServicePlan
	options.TerraformVars["app_config_plan"] = envVars.AppConfigPlan

	// Resource Cleanup Configuration
	options.SkipTestTearDown = true
	defer func() {
		testLogger.Info(t, "Final cleanup: destroying resources")
		options.TestTearDown()
	}()

	// Deploy Cluster Subtest
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

	// Post-deployment Validation Subtest
	t.Run("ValidateCluster", func(t *testing.T) {
		validationStart := time.Now()
		lsf.ValidateBasicClusterConfigurationWithSCCWPAndCSPM(t, options, testLogger)
		testLogger.Info(t, fmt.Sprintf("Validation completed (duration: %v)", time.Since(validationStart)))
	})
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
	defer logResult(t)
	testLogger.Info(t, fmt.Sprintf("Test %s initiated", t.Name()))

	// Generate Unique Cluster Prefix
	clusterNamePrefix := utils.GenerateTimestampedClusterPrefix(utils.GenerateRandomString())
	testLogger.Info(t, fmt.Sprintf("Generated cluster prefix: %s", clusterNamePrefix))

	// Load Environment Configuration
	envVars, err := GetEnvVars()
	require.NoError(t, err, "failed to load environment configuration")

	// Setup Test Options
	options, err := setupOptions(t, clusterNamePrefix, terraformDir, envVars.DefaultExistingResourceGroup)
	require.NoError(t, err, "Failed to initialize test options")

	// Override default zones with observability-specific region since default_region=false
	applyRegionOverrides(t, envVars, options, "observability")

	// Terraform Input Variables
	options.TerraformVars["enable_cos_integration"] = true
	options.TerraformVars["enable_vpc_flow_logs"] = true

	// Resource Cleanup Configuration
	options.SkipTestTearDown = true
	defer func() {
		testLogger.Info(t, "Final cleanup: destroying resources")
		options.TestTearDown()
	}()

	// Deploy Cluster Subtest
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

	// Post-deployment Validation Subtest
	t.Run("ValidateCluster", func(t *testing.T) {
		validationStart := time.Now()
		lsf.ValidateBasicClusterConfigurationWithVPCFlowLogsAndCos(t, options, testLogger)
		testLogger.Info(t, fmt.Sprintf("Cluster validation completed in %v", time.Since(validationStart)))
	})

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
	defer logResult(t)
	testLogger.Info(t, fmt.Sprintf("Test %s initiated", t.Name()))

	// Generate Unique Cluster Prefix
	clusterNamePrefix := utils.GenerateTimestampedClusterPrefix(utils.GenerateRandomString())
	testLogger.Info(t, fmt.Sprintf("Generated cluster prefix: %s", clusterNamePrefix))

	// Load Environment Configuration
	envVars, err := GetEnvVars()
	require.NoError(t, err, "failed to load environment configuration")

	// Setup Test Options
	options, err := setupOptions(t, clusterNamePrefix, terraformDir, envVars.DefaultExistingResourceGroup)
	require.NoError(t, err, "Failed to initialize test options")

	// Override default zones with observability-specific region since default_region=false
	applyRegionOverrides(t, envVars, options, "observability")

	// Resource Cleanup Configuration
	options.SkipTestTearDown = true
	defer func() {
		testLogger.Info(t, "Final cleanup: destroying resources")
		options.TestTearDown()
	}()

	// Deploy Cluster Subtest
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

	// Post-deployment Validation Subtest
	t.Run("ValidateCluster", func(t *testing.T) {
		validationStart := time.Now()
		lsf.ValidateBasicClusterConfigurationLSFLogs(t, options, testLogger)
		testLogger.Info(t, fmt.Sprintf("Cluster validation completed in %v", time.Since(validationStart)))
	})

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
	defer logResult(t)
	testLogger.Info(t, fmt.Sprintf("Test %s initiated", t.Name()))

	clusterNamePrefix := utils.GenerateTimestampedClusterPrefix(utils.GenerateRandomString())
	testLogger.Info(t, fmt.Sprintf("Generated cluster prefix: %s", clusterNamePrefix))

	envVars, err := GetEnvVars()
	require.NoError(t, err, "failed to load environment configuration")

	options, err := setupOptions(t, clusterNamePrefix, terraformDir, envVars.DefaultExistingResourceGroup)
	require.NoError(t, err, "Failed to initialize test options")

	// Override default zones with observability-specific region since default_region=false
	applyRegionOverrides(t, envVars, options, "observability")

	// Disable all observability features
	options.TerraformVars["observability_enable_platform_logs"] = false
	options.TerraformVars["observability_logs_enable_for_management"] = false
	options.TerraformVars["observability_logs_enable_for_compute"] = false
	options.TerraformVars["observability_monitoring_enable"] = false
	options.TerraformVars["observability_monitoring_on_compute_nodes_enable"] = false
	options.TerraformVars["observability_monitoring_plan"] = "graduated-tier"
	options.TerraformVars["observability_atracker_enable"] = false
	options.TerraformVars["observability_atracker_target_type"] = "cos"

	// Resource Cleanup Configuration
	options.SkipTestTearDown = true
	defer func() {
		testLogger.Info(t, "Final cleanup: destroying resources")
		options.TestTearDown()
	}()

	// Deploy Cluster Subtest
	// DeployCluster and ValidateCluster subtests are intentionally sequential.
	// Neither calls t.Parallel(), so t.Run blocks until each subtest completes
	// before the parent resumes. Do not add t.Parallel() to either subtest.
	t.Run("DeployCluster", func(t *testing.T) {
		deploymentStart := time.Now()
		testLogger.Info(t, fmt.Sprintf("Starting cluster deployment for test: %s", t.Name()))

		err = lsf.VerifyClusterCreationAndConsistency(t, options, testLogger)
		require.NoError(t, err, "Cluster creation validation failed")

		testLogger.Info(t, fmt.Sprintf("Cluster deployment completed (duration: %v)", time.Since(deploymentStart)))
	})

	// Abort the parent test immediately if DeployCluster failed.
	// Using require.False ensures the overall test is marked as FAILED (not skipped),
	// so CI pipelines correctly surface deployment failures.
	require.False(t, t.Failed(), "DeployCluster failed — aborting test, skipping ValidateCluster")

	// Post-deployment Validation Subtest
	t.Run("ValidateCluster", func(t *testing.T) {
		validationStart := time.Now()
		lsf.ValidateBasicObservabilityClusterConfiguration(t, options, testLogger)
		testLogger.Info(t, fmt.Sprintf("Validation completed in %v", time.Since(validationStart)))
	})

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
	defer logResult(t)
	testLogger.Info(t, fmt.Sprintf("Test %s initiated", t.Name()))

	clusterNamePrefix := utils.GenerateTimestampedClusterPrefix(utils.GenerateRandomString())
	testLogger.Info(t, fmt.Sprintf("Generated cluster prefix: %s", clusterNamePrefix))

	envVars, err := GetEnvVars()
	require.NoError(t, err, "failed to load environment configuration")

	options, err := setupOptions(t, clusterNamePrefix, terraformDir, envVars.DefaultExistingResourceGroup)
	require.NoError(t, err, "Failed to initialize test options")

	// Override default zones with observability-specific region since default_region=false
	applyRegionOverrides(t, envVars, options, "observability")

	// Enable logs for management and compute; disable other observability features
	options.TerraformVars["observability_logs_enable_for_management"] = true
	options.TerraformVars["observability_logs_enable_for_compute"] = true
	options.TerraformVars["observability_enable_platform_logs"] = false
	options.TerraformVars["observability_monitoring_enable"] = false
	options.TerraformVars["observability_monitoring_on_compute_nodes_enable"] = false
	options.TerraformVars["observability_monitoring_plan"] = "graduated-tier"
	options.TerraformVars["observability_atracker_enable"] = false
	options.TerraformVars["observability_atracker_target_type"] = "cos"

	// Resource Cleanup Configuration
	options.SkipTestTearDown = true
	defer func() {
		testLogger.Info(t, "Final cleanup: destroying resources")
		options.TestTearDown()
	}()

	// Deploy Cluster Subtest
	// DeployCluster and ValidateCluster subtests are intentionally sequential.
	// Neither calls t.Parallel(), so t.Run blocks until each subtest completes
	// before the parent resumes. Do not add t.Parallel() to either subtest.
	t.Run("DeployCluster", func(t *testing.T) {
		deploymentStart := time.Now()
		testLogger.Info(t, fmt.Sprintf("Starting cluster deployment for test: %s", t.Name()))

		err = lsf.VerifyClusterCreationAndConsistency(t, options, testLogger)
		require.NoError(t, err, "Cluster creation validation failed")

		testLogger.Info(t, fmt.Sprintf("Cluster deployment completed (duration: %v)", time.Since(deploymentStart)))
	})

	// Abort the parent test immediately if DeployCluster failed.
	// Using require.False ensures the overall test is marked as FAILED (not skipped),
	// so CI pipelines correctly surface deployment failures.
	require.False(t, t.Failed(), "DeployCluster failed — aborting test, skipping ValidateCluster")

	// Post-deployment Validation Subtest
	t.Run("ValidateCluster", func(t *testing.T) {
		validationStart := time.Now()
		lsf.ValidateBasicClusterConfigurationWithCloudLogs(t, options, testLogger)
		testLogger.Info(t, fmt.Sprintf("Validation completed in %v", time.Since(validationStart)))
	})

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
	defer logResult(t)
	testLogger.Info(t, fmt.Sprintf("Test %s initiated", t.Name()))

	clusterNamePrefix := utils.GenerateTimestampedClusterPrefix(utils.GenerateRandomString())
	testLogger.Info(t, fmt.Sprintf("Generated cluster prefix: %s", clusterNamePrefix))

	envVars, err := GetEnvVars()
	require.NoError(t, err, "failed to load environment configuration")

	options, err := setupOptions(t, clusterNamePrefix, terraformDir, envVars.DefaultExistingResourceGroup)
	require.NoError(t, err, "Failed to initialize test options")

	// Override default zones with observability-specific region since default_region=false
	applyRegionOverrides(t, envVars, options, "observability")

	// Enable monitoring; disable logs and Atracker
	options.TerraformVars["observability_logs_enable_for_management"] = false
	options.TerraformVars["observability_logs_enable_for_compute"] = false
	options.TerraformVars["observability_enable_platform_logs"] = false
	options.TerraformVars["observability_monitoring_enable"] = true
	options.TerraformVars["observability_monitoring_on_compute_nodes_enable"] = true
	options.TerraformVars["observability_monitoring_plan"] = "graduated-tier"
	options.TerraformVars["observability_atracker_enable"] = false
	options.TerraformVars["observability_atracker_target_type"] = "cloudlogs"

	// Resource Cleanup Configuration
	options.SkipTestTearDown = true
	defer func() {
		testLogger.Info(t, "Final cleanup: destroying resources")
		options.TestTearDown()
	}()

	// Deploy Cluster Subtest
	// DeployCluster and ValidateCluster subtests are intentionally sequential.
	// Neither calls t.Parallel(), so t.Run blocks until each subtest completes
	// before the parent resumes. Do not add t.Parallel() to either subtest.
	t.Run("DeployCluster", func(t *testing.T) {
		deploymentStart := time.Now()
		testLogger.Info(t, fmt.Sprintf("Starting cluster deployment for test: %s", t.Name()))

		err = lsf.VerifyClusterCreationAndConsistency(t, options, testLogger)
		require.NoError(t, err, "Cluster creation validation failed")

		testLogger.Info(t, fmt.Sprintf("Cluster deployment completed (duration: %v)", time.Since(deploymentStart)))
	})

	// Abort the parent test immediately if DeployCluster failed.
	// Using require.False ensures the overall test is marked as FAILED (not skipped),
	// so CI pipelines correctly surface deployment failures.
	require.False(t, t.Failed(), "DeployCluster failed — aborting test, skipping ValidateCluster")

	// Post-deployment Validation Subtest
	t.Run("ValidateCluster", func(t *testing.T) {
		validationStart := time.Now()
		lsf.ValidateBasicClusterConfigurationWithCloudMonitoring(t, options, testLogger)
		testLogger.Info(t, fmt.Sprintf("Validation completed in %v", time.Since(validationStart)))
	})

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
	require.NoError(t, err, "failed to load environment configuration")

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
			require.NoError(t, err, "Failed to initialize test options")

			// Override default zones with observability-specific region since default_region=false
			applyRegionOverrides(t, envVars, options, "observability")

			options.TerraformVars["observability_enable_platform_logs"] = scenario.platformLogs
			options.TerraformVars["observability_logs_enable_for_management"] = scenario.logsForManagement
			options.TerraformVars["observability_logs_enable_for_compute"] = scenario.logsForCompute
			options.TerraformVars["observability_monitoring_enable"] = scenario.monitoring
			options.TerraformVars["observability_monitoring_on_compute_nodes_enable"] = scenario.monitoringOnCompute
			options.TerraformVars["observability_monitoring_plan"] = "graduated-tier"
			options.TerraformVars["observability_atracker_enable"] = true
			options.TerraformVars["observability_atracker_target_type"] = scenario.atrackerTargetType
			options.TerraformVars["zones"] = utils.SplitAndTrim(envVars.AttrackerTestZone, ",")

			// Resource Cleanup Configuration
			options.SkipTestTearDown = true
			defer func() {
				testLogger.Info(t, "Final cleanup: destroying resources")
				options.TestTearDown()
			}()

			// Deploy Cluster Subtest
			// DeployCluster and ValidateCluster subtests are intentionally sequential.
			// Neither calls t.Parallel(), so t.Run blocks until each subtest completes
			// before the parent resumes. Do not add t.Parallel() to either subtest.
			t.Run("DeployCluster", func(t *testing.T) {
				testLogger.Info(t, fmt.Sprintf("Deploying cluster for: %s", scenario.name))
				err = lsf.VerifyClusterCreationAndConsistency(t, options, testLogger)
				require.NoError(t, err, "Cluster creation failed")
			})

			// Abort the parent test immediately if DeployCluster failed.
			// Using require.False ensures the overall test is marked as FAILED (not skipped),
			// so CI pipelines correctly surface deployment failures.
			require.False(t, t.Failed(), "DeployCluster failed — aborting test, skipping ValidateCluster")

			// Validate Cluster Subtest
			t.Run("ValidateCluster", func(t *testing.T) {
				testLogger.Info(t, "Starting validation...")
				scenario.validationFunc(t, options, testLogger)
			})

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
	require.NoError(t, err, "failed to load environment configuration")

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
			require.NoError(t, err, "Failed to initialize test options")

			// Override default zones with observability-specific region since default_region=false
			applyRegionOverrides(t, envVars, options, "observability")

			options.TerraformVars["observability_enable_platform_logs"] = scenario.platformLogs
			options.TerraformVars["observability_logs_enable_for_management"] = scenario.logsForManagement
			options.TerraformVars["observability_logs_enable_for_compute"] = scenario.logsForCompute
			options.TerraformVars["observability_monitoring_enable"] = scenario.monitoring
			options.TerraformVars["observability_monitoring_on_compute_nodes_enable"] = scenario.monitoringOnCompute
			options.TerraformVars["observability_monitoring_plan"] = "graduated-tier"
			options.TerraformVars["observability_atracker_enable"] = true
			options.TerraformVars["observability_atracker_target_type"] = scenario.atrackerTargetType
			options.TerraformVars["zones"] = utils.SplitAndTrim(envVars.AttrackerTestZone, ",")

			// Resource Cleanup Configuration
			options.SkipTestTearDown = true
			defer func() {
				testLogger.Info(t, "Final cleanup: destroying resources")
				options.TestTearDown()
			}()

			// Deploy Cluster Subtest
			// DeployCluster and ValidateCluster subtests are intentionally sequential.
			// Neither calls t.Parallel(), so t.Run blocks until each subtest completes
			// before the parent resumes. Do not add t.Parallel() to either subtest.
			t.Run("DeployCluster", func(t *testing.T) {
				testLogger.Info(t, fmt.Sprintf("Deploying cluster for: %s", scenario.name))
				err = lsf.VerifyClusterCreationAndConsistency(t, options, testLogger)
				require.NoError(t, err, "Cluster creation failed")
			})

			// Abort the parent test immediately if DeployCluster failed.
			// Using require.False ensures the overall test is marked as FAILED (not skipped),
			// so CI pipelines correctly surface deployment failures.
			require.False(t, t.Failed(), "DeployCluster failed — aborting test, skipping ValidateCluster")

			// Validate Cluster Subtest
			t.Run("ValidateCluster", func(t *testing.T) {
				testLogger.Info(t, "Starting validation...")
				scenario.validationFunc(t, options, testLogger)
			})

			if t.Failed() {
				testLogger.Error(t, fmt.Sprintf("Scenario %s failed", scenario.name))
			} else {
				testLogger.PASS(t, fmt.Sprintf("Scenario %s passed", scenario.name))
			}
		})
	}
}
