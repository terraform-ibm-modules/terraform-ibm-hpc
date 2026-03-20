package tests

import (
	"fmt"
	"testing"
	"time"

	"github.com/stretchr/testify/require"
	lsf "github.com/terraform-ibm-modules/terraform-ibm-hpc/lsf"
	utils "github.com/terraform-ibm-modules/terraform-ibm-hpc/utilities"
)

func TestRunLsfReapply(t *testing.T) {
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

	// Load Environment Configuration
	envVars, err := GetEnvVars()
	require.NoError(t, err, "failed to load environment configuration")

	// Override default zones with scaling-specific region since default_region=false
	applyRegionOverrides(t, envVars, options, "scaling")

	// Resource Cleanup Configuration
	options.SkipTestTearDown = true
	options.DisableTempWorkingDir = true

	// Create automation-controlled working directory ONCE
	preparedTerraformDir := utils.PrepareTerraformWorkingDir(
		t,
		clusterNamePrefix,
		options.TerraformDir,
		options.IsUpgradeTest,
	)
	options.TerraformDir = preparedTerraformDir

	defer func() {
		testLogger.Info(t, "Final cleanup: destroying resources")
		options.TestTearDown()
	}()

	runPhase := func(phase string, fn func() error) {
		testLogger.Info(t, phase)
		if err := fn(); err != nil {
			testLogger.Error(t, fmt.Sprintf("%s failed: %v", phase, err))
			t.FailNow() // exit test
		}
	}

	// ─────────────────────────────
	// Phase 1: Initial Deployment
	// ─────────────────────────────
	deploymentStart := time.Now()
	testLogger.Info(t, fmt.Sprintf("Phase 1: Starting cluster deployment for test: %s", t.Name()))
	runPhase("Phase 1: Initial deployment", func() error {
		_, err := options.RunTest()
		return err
	})

	testLogger.Info(t, fmt.Sprintf("Cluster deployment completed (duration: %v)", time.Since(deploymentStart)))

	// ─────────────────────────────
	// Phase 2: re-apply Deployment
	// ─────────────────────────────
	deploymentStart2 := time.Now()
	testLogger.Info(t, fmt.Sprintf("Phase 2: Starting cluster re-deployment for test: %s", t.Name()))
	runPhase("Phase 2: Re-apply (no input changes)", func() error {
		_, err := options.RunTest()
		return err
	})

	testLogger.Info(t, fmt.Sprintf("Phase 2: Cluster re-deployment completed (duration: %v)", time.Since(deploymentStart2)))

	// Post-deployment Validation

	lsf.ValidateBasicClusterConfiguration(t, options, testLogger)

}

func TestRunLsfNodeScaleUp(t *testing.T) {
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

	// Load Environment Configuration
	envVars, err := GetEnvVars()
	require.NoError(t, err, "failed to load environment configuration")

	// Override default zones with scaling-specific region since default_region=false
	applyRegionOverrides(t, envVars, options, "scaling")

	// Resource Cleanup Configuration
	options.SkipTestTearDown = true
	options.DisableTempWorkingDir = true

	// Create automation-controlled working directory ONCE
	preparedTerraformDir := utils.PrepareTerraformWorkingDir(
		t,
		clusterNamePrefix,
		options.TerraformDir,
		options.IsUpgradeTest,
	)
	options.TerraformDir = preparedTerraformDir

	defer func() {
		testLogger.Info(t, "Final cleanup: destroying resources")
		options.TestTearDown()
	}()

	runPhase := func(phase string, fn func() error) {
		testLogger.Info(t, phase)
		if err := fn(); err != nil {
			testLogger.Error(t, fmt.Sprintf("%s failed: %v", phase, err))
			t.FailNow() // exit test
		}
	}

	// ─────────────────────────────
	// Phase 1: Initial Deployment
	// ─────────────────────────────
	deploymentStart := time.Now()
	testLogger.Info(t, fmt.Sprintf("Phase 1: Starting cluster deployment for test: %s", t.Name()))
	runPhase("Phase 1: Initial deployment", func() error {
		_, err := options.RunTest()
		return err
	})

	testLogger.Info(t, fmt.Sprintf("Cluster deployment completed (duration: %v)", time.Since(deploymentStart)))

	// ─────────────────────────────
	// Phase 2: Scale-Up Deployment
	// ─────────────────────────────
	utils.UpdateInstanceCount(t, options.TerraformOptions.Vars, "management_instances", 2)
	utils.UpdateInstanceCount(t, options.TerraformOptions.Vars, "static_compute_instances", 2)
	testLogger.Info(t, fmt.Sprintf("management_instances=%v", options.TerraformOptions.Vars["management_instances"]))
	testLogger.Info(t, fmt.Sprintf("static_compute_instances=%v", options.TerraformOptions.Vars["static_compute_instances"]))
	deploymentStart2 := time.Now()
	testLogger.Info(t, fmt.Sprintf("Phase 2: Starting cluster re-deployment for test: %s", t.Name()))
	runPhase("Phase 2: Scale-up", func() error {
		_, err := options.RunTest()
		return err
	})

	testLogger.Info(t, fmt.Sprintf("Phase 2: Cluster re-deployment completed (duration: %v)", time.Since(deploymentStart2)))

	// Post-deployment Validation
	lsf.ValidateBasicClusterConfiguration(t, options, testLogger)

}

func TestRunLsfNodeScaleDown(t *testing.T) {
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

	// Load Environment Configuration
	envVars, err := GetEnvVars()
	require.NoError(t, err, "failed to load environment configuration")

	// Override default zones with scaling-specific region since default_region=false
	applyRegionOverrides(t, envVars, options, "scaling")

	// Resource Cleanup Configuration
	options.SkipTestTearDown = true
	options.DisableTempWorkingDir = true

	// Create automation-controlled working directory ONCE
	preparedTerraformDir := utils.PrepareTerraformWorkingDir(
		t,
		clusterNamePrefix,
		options.TerraformDir,
		options.IsUpgradeTest,
	)
	options.TerraformDir = preparedTerraformDir

	defer func() {
		testLogger.Info(t, "Final cleanup: destroying resources")
		options.TestTearDown()
	}()

	runPhase := func(phase string, fn func() error) {
		testLogger.Info(t, phase)
		if err := fn(); err != nil {
			testLogger.Error(t, fmt.Sprintf("%s failed: %v", phase, err))
			t.FailNow() // exit test
		}
	}

	utils.UpdateInstanceCount(t, options.TerraformVars, "management_instances", 2)
	utils.UpdateInstanceCount(t, options.TerraformVars, "static_compute_instances", 2)
	testLogger.Info(t, fmt.Sprintf("management_instances=%v", options.TerraformVars["management_instances"]))
	testLogger.Info(t, fmt.Sprintf("static_compute_instances=%v", options.TerraformVars["static_compute_instances"]))

	// ─────────────────────────────
	// Phase 1: Initial Deployment
	// ─────────────────────────────
	deploymentStart := time.Now()
	testLogger.Info(t, fmt.Sprintf("Phase 1: Starting cluster deployment for test: %s", t.Name()))
	runPhase("Phase 1: Initial deployment", func() error {
		_, err := options.RunTest()
		return err
	})

	testLogger.Info(t, fmt.Sprintf("Cluster deployment completed (duration: %v)", time.Since(deploymentStart)))

	// ─────────────────────────────
	// Phase 2: Scale-down Deployment
	// ─────────────────────────────
	utils.UpdateInstanceCount(t, options.TerraformOptions.Vars, "management_instances", -1)
	utils.UpdateInstanceCount(t, options.TerraformOptions.Vars, "static_compute_instances", -1)
	testLogger.Info(t, fmt.Sprintf("management_instances=%v", options.TerraformOptions.Vars["management_instances"]))
	testLogger.Info(t, fmt.Sprintf("static_compute_instances=%v", options.TerraformOptions.Vars["static_compute_instances"]))
	deploymentStart2 := time.Now()
	testLogger.Info(t, fmt.Sprintf("Phase 2: Starting cluster re-deployment for test: %s", t.Name()))
	runPhase("Phase 2: Scale-down", func() error {
		_, err := options.RunTest()
		return err
	})

	testLogger.Info(t, fmt.Sprintf("Phase 2: Cluster re-deployment completed (duration: %v)", time.Since(deploymentStart2)))

	// Post-deployment Validation
	lsf.ValidateBasicClusterConfiguration(t, options, testLogger)
}

func TestRunLsfNodeScaleReapply(t *testing.T) {
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

	// Load Environment Configuration
	envVars, err := GetEnvVars()
	require.NoError(t, err, "failed to load environment configuration")

	// Override default zones with scaling-specific region since default_region=false
	applyRegionOverrides(t, envVars, options, "scaling")

	// Resource Cleanup Configuration
	options.SkipTestTearDown = true
	options.DisableTempWorkingDir = true

	// Create automation-controlled working directory ONCE
	preparedTerraformDir := utils.PrepareTerraformWorkingDir(
		t,
		clusterNamePrefix,
		options.TerraformDir,
		options.IsUpgradeTest,
	)
	options.TerraformDir = preparedTerraformDir

	defer func() {
		testLogger.Info(t, "Final cleanup: destroying resources")
		options.TestTearDown()
	}()

	runPhase := func(phase string, fn func() error) {
		testLogger.Info(t, phase)
		if err := fn(); err != nil {
			testLogger.Error(t, fmt.Sprintf("%s failed: %v", phase, err))
			t.FailNow() // exit test
		}
	}

	// ─────────────────────────────
	// Phase 1: Initial Deployment
	// ─────────────────────────────
	deploymentStart := time.Now()
	testLogger.Info(t, fmt.Sprintf("Phase 1: Starting cluster deployment for test: %s", t.Name()))
	runPhase("Phase 1: Initial deployment", func() error {
		_, err := options.RunTest()
		return err
	})

	testLogger.Info(t, fmt.Sprintf("Cluster deployment completed (duration: %v)", time.Since(deploymentStart)))

	// ─────────────────────────────
	// Phase 2: Scale-Up Deployment
	// ─────────────────────────────
	utils.UpdateInstanceCount(t, options.TerraformOptions.Vars, "management_instances", 2)
	utils.UpdateInstanceCount(t, options.TerraformOptions.Vars, "static_compute_instances", 2)
	testLogger.Info(t, fmt.Sprintf("management_instances=%v", options.TerraformOptions.Vars["management_instances"]))
	testLogger.Info(t, fmt.Sprintf("static_compute_instances=%v", options.TerraformOptions.Vars["static_compute_instances"]))
	deploymentStart2 := time.Now()
	testLogger.Info(t, fmt.Sprintf("Phase 2: Starting cluster re-deployment for test: %s", t.Name()))
	runPhase("Phase 2: Scale-up", func() error {
		_, err := options.RunTest()
		return err
	})

	testLogger.Info(t, fmt.Sprintf("Phase 2: Cluster re-deployment completed (duration: %v)", time.Since(deploymentStart2)))

	// ─────────────────────────────
	// Phase 3: Scale-Down Deployment
	// ─────────────────────────────
	utils.UpdateInstanceCount(t, options.TerraformOptions.Vars, "management_instances", -1)
	utils.UpdateInstanceCount(t, options.TerraformOptions.Vars, "static_compute_instances", -1)
	testLogger.Info(t, fmt.Sprintf("management_instances=%v", options.TerraformOptions.Vars["management_instances"]))
	testLogger.Info(t, fmt.Sprintf("static_compute_instances=%v", options.TerraformOptions.Vars["static_compute_instances"]))
	deploymentStart3 := time.Now()
	testLogger.Info(t, fmt.Sprintf("Phase 3: Starting cluster re-deployment for test: %s", t.Name()))
	runPhase("Phase 3: Scale-Down", func() error {
		_, err := options.RunTest()
		return err
	})

	testLogger.Info(t, fmt.Sprintf("Phase 3: Cluster re-deployment completed (duration: %v)", time.Since(deploymentStart3)))

}
