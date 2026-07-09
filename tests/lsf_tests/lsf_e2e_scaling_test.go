package tests

import (
	"fmt"
	"testing"
	"time"

	"github.com/stretchr/testify/require"
	lsf "github.com/terraform-ibm-modules/terraform-ibm-hpc/lsf"
	utils "github.com/terraform-ibm-modules/terraform-ibm-hpc/utilities"
)

// TestReapply validates that a cluster can be re-applied with no input changes
// and remains in a consistent state after the second apply.
func TestReapply(t *testing.T) {
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

	options, err := setupOptions(t, clusterNamePrefix, terraformDir, LSF_CUSTOM_EXISTING_RESOURCE_GROUP_VALUE_AS_NULL)
	utils.NoError(t, err, "Failed to initialize test options", testLogger)
	testLogger.Info(t, "Test options initialized successfully")

	// Override default zones with scaling-specific region (default_region=false).
	applyRegionOverrides(t, envVars, options, "scaling")
	testLogger.Info(t, "Region overrides applied for scaling cluster configuration")

	// ── 3. Teardown ──────────────────────────────────────────────────────────
	// SkipTestTearDown + DisableTempWorkingDir allow a single automation-controlled
	// working directory to be reused across multiple RunTest phases.
	options.SkipTestTearDown = true
	options.DisableTempWorkingDir = true

	preparedTerraformDir := utils.PrepareTerraformWorkingDir(
		t,
		clusterNamePrefix,
		options.TerraformDir,
		options.IsUpgradeTest,
	)
	options.TerraformDir = preparedTerraformDir

	defer func() {
		testLogger.Info(t, "Initiating final resource teardown...")
		options.TestTearDown()
		testLogger.Info(t, "Resource teardown completed")
	}()

	runPhase := func(phase string, fn func() error) {
		testLogger.Info(t, fmt.Sprintf("[START] %s", phase))
		if err := fn(); err != nil {
			testLogger.Error(t, fmt.Sprintf("%s failed: %v", phase, err))
			t.FailNow()
		}
		testLogger.Info(t, fmt.Sprintf("[END] %s completed successfully", phase))
	}

	// ── 4. Phase 1: Initial Deployment ───────────────────────────────────────
	phase1Start := time.Now()
	runPhase("Phase 1: Initial deployment", func() error {
		_, err := options.RunTest()
		return err
	})
	testLogger.Info(t, fmt.Sprintf("Phase 1 duration: %v", time.Since(phase1Start)))

	// ── 5. Phase 2: Re-apply (no input changes) ───────────────────────────────
	phase2Start := time.Now()
	runPhase("Phase 2: Re-apply (no input changes)", func() error {
		_, err := options.RunTest()
		return err
	})
	testLogger.Info(t, fmt.Sprintf("Phase 2 duration: %v", time.Since(phase2Start)))

	// ── 6. Validation ────────────────────────────────────────────────────────
	utils.RunValidateCluster(t, testLogger, func(t *testing.T) {
		lsf.ValidateBasicClusterConfiguration(t, options, testLogger)
	})
}

// TestNodeScaleUp validates that a cluster can scale up management and compute
// nodes after the initial deployment and remains consistent post-scale.
func TestNodeScaleUp(t *testing.T) {
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

	options, err := setupOptions(t, clusterNamePrefix, terraformDir, LSF_CUSTOM_EXISTING_RESOURCE_GROUP_VALUE_AS_NULL)
	utils.NoError(t, err, "Failed to initialize test options", testLogger)
	testLogger.Info(t, "Test options initialized successfully")

	// Override default zones with scaling-specific region (default_region=false).
	applyRegionOverrides(t, envVars, options, "scaling")
	testLogger.Info(t, "Region overrides applied for scaling cluster configuration")

	// ── 3. Teardown ──────────────────────────────────────────────────────────
	options.SkipTestTearDown = true
	options.DisableTempWorkingDir = true

	preparedTerraformDir := utils.PrepareTerraformWorkingDir(
		t,
		clusterNamePrefix,
		options.TerraformDir,
		options.IsUpgradeTest,
	)
	options.TerraformDir = preparedTerraformDir

	defer func() {
		testLogger.Info(t, "Initiating final resource teardown...")
		options.TestTearDown()
		testLogger.Info(t, "Resource teardown completed")
	}()

	runPhase := func(phase string, fn func() error) {
		testLogger.Info(t, fmt.Sprintf("[START] %s", phase))
		if err := fn(); err != nil {
			testLogger.Error(t, fmt.Sprintf("%s failed: %v", phase, err))
			t.FailNow()
		}
		testLogger.Info(t, fmt.Sprintf("[END] %s completed successfully", phase))
	}

	// ── 4. Phase 1: Initial Deployment ───────────────────────────────────────
	phase1Start := time.Now()
	runPhase("Phase 1: Initial deployment", func() error {
		_, err := options.RunTest()
		return err
	})
	testLogger.Info(t, fmt.Sprintf("Phase 1 duration: %v", time.Since(phase1Start)))

	// ── 5. Phase 2: Scale-Up ─────────────────────────────────────────────────
	utils.UpdateInstanceCount(t, options.TerraformOptions.Vars, "management_instances", 2)
	utils.UpdateInstanceCount(t, options.TerraformOptions.Vars, "static_compute_instances", 2)
	testLogger.Info(t, fmt.Sprintf("management_instances=%v", options.TerraformOptions.Vars["management_instances"]))
	testLogger.Info(t, fmt.Sprintf("static_compute_instances=%v", options.TerraformOptions.Vars["static_compute_instances"]))

	phase2Start := time.Now()
	runPhase("Phase 2: Scale-up", func() error {
		_, err := options.RunTest()
		return err
	})
	testLogger.Info(t, fmt.Sprintf("Phase 2 duration: %v", time.Since(phase2Start)))

	// ── 6. Validation ────────────────────────────────────────────────────────
	utils.RunValidateCluster(t, testLogger, func(t *testing.T) {
		lsf.ValidateBasicClusterConfiguration(t, options, testLogger)
	})
}

// TestNodeScaleDown validates that a cluster initially deployed with higher
// instance counts can scale down and remains consistent post-scale.
func TestNodeScaleDown(t *testing.T) {
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

	options, err := setupOptions(t, clusterNamePrefix, terraformDir, LSF_CUSTOM_EXISTING_RESOURCE_GROUP_VALUE_AS_NULL)
	utils.NoError(t, err, "Failed to initialize test options", testLogger)
	testLogger.Info(t, "Test options initialized successfully")

	// Override default zones with scaling-specific region (default_region=false).
	applyRegionOverrides(t, envVars, options, "scaling")
	testLogger.Info(t, "Region overrides applied for scaling cluster configuration")

	// ── 3. Teardown ──────────────────────────────────────────────────────────
	options.SkipTestTearDown = true
	options.DisableTempWorkingDir = true

	preparedTerraformDir := utils.PrepareTerraformWorkingDir(
		t,
		clusterNamePrefix,
		options.TerraformDir,
		options.IsUpgradeTest,
	)
	options.TerraformDir = preparedTerraformDir

	defer func() {
		testLogger.Info(t, "Initiating final resource teardown...")
		options.TestTearDown()
		testLogger.Info(t, "Resource teardown completed")
	}()

	runPhase := func(phase string, fn func() error) {
		testLogger.Info(t, fmt.Sprintf("[START] %s", phase))
		if err := fn(); err != nil {
			testLogger.Error(t, fmt.Sprintf("%s failed: %v", phase, err))
			t.FailNow()
		}
		testLogger.Info(t, fmt.Sprintf("[END] %s completed successfully", phase))
	}

	// ── 4. Phase 1: Initial Deployment (scaled-up baseline) ──────────────────
	// Deploy with higher counts so Phase 2 can scale down from them.
	utils.UpdateInstanceCount(t, options.TerraformVars, "management_instances", 2)
	utils.UpdateInstanceCount(t, options.TerraformVars, "static_compute_instances", 2)
	testLogger.Info(t, fmt.Sprintf("management_instances=%v", options.TerraformVars["management_instances"]))
	testLogger.Info(t, fmt.Sprintf("static_compute_instances=%v", options.TerraformVars["static_compute_instances"]))

	phase1Start := time.Now()
	runPhase("Phase 1: Initial deployment (scaled-up baseline)", func() error {
		_, err := options.RunTest()
		return err
	})
	testLogger.Info(t, fmt.Sprintf("Phase 1 duration: %v", time.Since(phase1Start)))

	// ── 5. Phase 2: Scale-Down ───────────────────────────────────────────────
	utils.UpdateInstanceCount(t, options.TerraformOptions.Vars, "management_instances", -1)
	utils.UpdateInstanceCount(t, options.TerraformOptions.Vars, "static_compute_instances", -1)
	testLogger.Info(t, fmt.Sprintf("management_instances=%v", options.TerraformOptions.Vars["management_instances"]))
	testLogger.Info(t, fmt.Sprintf("static_compute_instances=%v", options.TerraformOptions.Vars["static_compute_instances"]))

	phase2Start := time.Now()
	runPhase("Phase 2: Scale-down", func() error {
		_, err := options.RunTest()
		return err
	})
	testLogger.Info(t, fmt.Sprintf("Phase 2 duration: %v", time.Since(phase2Start)))

	// ── 6. Validation ────────────────────────────────────────────────────────
	utils.RunValidateCluster(t, testLogger, func(t *testing.T) {
		lsf.ValidateBasicClusterConfiguration(t, options, testLogger)
	})
}

// TestNodeScaleUpAndDown validates a full scale-up then scale-down lifecycle:
// deploy at baseline, scale up, then scale back down.
func TestNodeScaleUpAndDown(t *testing.T) {
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

	options, err := setupOptions(t, clusterNamePrefix, terraformDir, LSF_CUSTOM_EXISTING_RESOURCE_GROUP_VALUE_AS_NULL)
	utils.NoError(t, err, "Failed to initialize test options", testLogger)
	testLogger.Info(t, "Test options initialized successfully")

	// Override default zones with scaling-specific region (default_region=false).
	applyRegionOverrides(t, envVars, options, "scaling")
	testLogger.Info(t, "Region overrides applied for scaling cluster configuration")

	// ── 3. Teardown ──────────────────────────────────────────────────────────
	options.SkipTestTearDown = true
	options.DisableTempWorkingDir = true

	preparedTerraformDir := utils.PrepareTerraformWorkingDir(
		t,
		clusterNamePrefix,
		options.TerraformDir,
		options.IsUpgradeTest,
	)
	options.TerraformDir = preparedTerraformDir

	defer func() {
		testLogger.Info(t, "Initiating final resource teardown...")
		options.TestTearDown()
		testLogger.Info(t, "Resource teardown completed")
	}()

	runPhase := func(phase string, fn func() error) {
		testLogger.Info(t, fmt.Sprintf("[START] %s", phase))
		if err := fn(); err != nil {
			testLogger.Error(t, fmt.Sprintf("%s failed: %v", phase, err))
			t.FailNow()
		}
		testLogger.Info(t, fmt.Sprintf("[END] %s completed successfully", phase))
	}

	// ── 4. Phase 1: Initial Deployment ───────────────────────────────────────
	phase1Start := time.Now()
	runPhase("Phase 1: Initial deployment", func() error {
		_, err := options.RunTest()
		return err
	})
	testLogger.Info(t, fmt.Sprintf("Phase 1 duration: %v", time.Since(phase1Start)))

	// ── 5. Phase 2: Scale-Up ─────────────────────────────────────────────────
	utils.UpdateInstanceCount(t, options.TerraformOptions.Vars, "management_instances", 2)
	utils.UpdateInstanceCount(t, options.TerraformOptions.Vars, "static_compute_instances", 2)
	testLogger.Info(t, fmt.Sprintf("management_instances=%v", options.TerraformOptions.Vars["management_instances"]))
	testLogger.Info(t, fmt.Sprintf("static_compute_instances=%v", options.TerraformOptions.Vars["static_compute_instances"]))

	phase2Start := time.Now()
	runPhase("Phase 2: Scale-up", func() error {
		_, err := options.RunTest()
		return err
	})
	testLogger.Info(t, fmt.Sprintf("Phase 2 duration: %v", time.Since(phase2Start)))

	// ── 6. Phase 3: Scale-Down ───────────────────────────────────────────────
	utils.UpdateInstanceCount(t, options.TerraformOptions.Vars, "management_instances", -1)
	utils.UpdateInstanceCount(t, options.TerraformOptions.Vars, "static_compute_instances", -1)
	testLogger.Info(t, fmt.Sprintf("management_instances=%v", options.TerraformOptions.Vars["management_instances"]))
	testLogger.Info(t, fmt.Sprintf("static_compute_instances=%v", options.TerraformOptions.Vars["static_compute_instances"]))

	phase3Start := time.Now()
	runPhase("Phase 3: Scale-down", func() error {
		_, err := options.RunTest()
		return err
	})
	testLogger.Info(t, fmt.Sprintf("Phase 3 duration: %v", time.Since(phase3Start)))

	// ── 7. Validation ────────────────────────────────────────────────────────
	utils.RunValidateCluster(t, testLogger, func(t *testing.T) {
		lsf.ValidateBasicClusterConfiguration(t, options, testLogger)
	})
}
