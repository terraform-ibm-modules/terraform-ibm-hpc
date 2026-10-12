package tests

import (
	"encoding/json"
	"fmt"
	"testing"
	"time"

	"github.com/stretchr/testify/require"
	lsf "github.com/terraform-ibm-modules/terraform-ibm-hpc/lsf"
	utils "github.com/terraform-ibm-modules/terraform-ibm-hpc/utilities"
)

// TestBMStaticWorkerNodesWithScaleUp validates cluster creation with Baremetal server profiles for compute nodes and enable_baremetal=true.

// - Deploys the cluster with Baremetal Servers (bx2d-metal-96x384) as compute nodes
// - Hyperthreading is set to true
// - Performs consistency checks during cluster creation
// - Validates basic cluster configuration with Baremetal server as compute nodes
// - Scale Up of compute nodes by 1 is performed
// - Validates basic cluster configuration after scale up
func TestBMStaticWorkerNodesWithScaleUp(t *testing.T) {
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

	options, err := setupOptions(t, clusterNamePrefix, terraformDir, envVars.DefaultExistingResourceGroup)
	utils.NoError(t, err, "Failed to initialize test options", testLogger)
	testLogger.Info(t, "Test options initialized successfully")

	usSouthZone := utils.SplitAndTrim(envVars.USSouthZone, ",")
	require.NotEmpty(t, usSouthZone, "Must provide valid Dallas zone configuration")
	testLogger.DEBUG(t, fmt.Sprintf("Using Dallas zones: %v", usSouthZone))
	options.TerraformVars["zones"] = usSouthZone
	testLogger.Info(t, fmt.Sprintf("Region configured: Dallas zones %v", usSouthZone))

	// Cluster profile: one static baremetal worker.
	instances := []map[string]interface{}{
		{
			"profile": "bx2d-metal-96x384",
			"count":   1,
			"image":   envVars.StaticComputeInstancesImage,
		},
	}

	jsonBytes, err := json.Marshal(instances)
	require.NoError(t, err, "Failed to marshal instances")

	options.TerraformVars["static_compute_instances"] = string(jsonBytes)

	options.TerraformVars["enable_baremetal"] = true
	options.TerraformVars["enable_hyperthreading"] = "true"
	testLogger.Info(t, "Cluster profile configured: cluster with BM as static compute nodes")

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

	defer utils.SetupTeardown(t, options, testLogger)()

	// ── 4. Phase 1: Initial Deployment ──────────────────────────────────────

	phase1Start := time.Now()
	utils.RunPhase(
		t,
		"Phase 1: Initial deployment",
		func() error {
			_, err := options.RunTest()
			return err
		},
		testLogger,
	)
	testLogger.Info(t, fmt.Sprintf("Phase 1 duration: %v", time.Since(phase1Start)))

	// ── 5. Validation ────────────────────────────────────────────────────────
	utils.RunValidateCluster(t, testLogger, func(t *testing.T) {
		lsf.ValidateBasicClusterConfigurationForComputeAsBM(t, options, testLogger)
	})

	// ── 6. Phase 2: Scale-Up ───────────────────────────────────────

	utils.UpdateInstanceCount(t, options.TerraformOptions.Vars, "static_compute_instances", 1)
	testLogger.Info(t, fmt.Sprintf("static_compute_instances=%v", options.TerraformOptions.Vars["static_compute_instances"]))

	phase2Start := time.Now()
	utils.RunPhase(
		t,
		"Phase 2: Scale Up",
		func() error {
			_, err := options.RunTest()
			return err
		},
		testLogger,
	)
	testLogger.Info(t, fmt.Sprintf("Phase 2 duration: %v", time.Since(phase2Start)))

	// ── 7. Validation ────────────────────────────────────────────────────────
	utils.RunValidateCluster(t, testLogger, func(t *testing.T) {
		lsf.ValidateBasicClusterConfigurationForComputeAsBM(t, options, testLogger)
	})

}

// TestBMStaticWorkerNodesWithScaleDown validates cluster creation with Baremetal server profiles for compute nodes and enable_baremetal=true.

// - Deploys the cluster with Baremetal Servers (bx2d-metal-96x384) as compute nodes
// - Hyperthreading is by default false
// - Performs consistency checks during cluster creation
// - Validates basic cluster configuration with Baremetal server as compute nodes
// - Scale Down of compute nodes by 1 is performed
// - Validates basic cluster configuration after scale down
func TestBMStaticWorkerNodesWithScaleDown(t *testing.T) {
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

	options, err := setupOptions(t, clusterNamePrefix, terraformDir, envVars.DefaultExistingResourceGroup)
	utils.NoError(t, err, "Failed to initialize test options", testLogger)
	testLogger.Info(t, "Test options initialized successfully")

	usSouthZone := utils.SplitAndTrim(envVars.USSouthZone, ",")
	require.NotEmpty(t, usSouthZone, "Must provide valid Dallas zone configuration")
	testLogger.DEBUG(t, fmt.Sprintf("Using Dallas zones: %v", usSouthZone))
	options.TerraformVars["zones"] = usSouthZone
	testLogger.Info(t, fmt.Sprintf("Region configured: Dallas zones %v", usSouthZone))

	// Cluster profile: one static baremetal worker.
	instances := []map[string]interface{}{
		{
			"profile": "bx2d-metal-96x384",
			"count":   1,
			"image":   envVars.StaticComputeInstancesImage,
		},
	}

	jsonBytes, err := json.Marshal(instances)
	require.NoError(t, err, "Failed to marshal instances")

	options.TerraformVars["static_compute_instances"] = string(jsonBytes)

	options.TerraformVars["enable_baremetal"] = true
	testLogger.Info(t, "Cluster profile configured: cluster with BM as static compute nodes")

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

	defer utils.SetupTeardown(t, options, testLogger)()

	// ── 4. Phase 1: Initial Deployment ──────────────────────────────────────
	phase1Start := time.Now()
	utils.RunPhase(
		t,
		"Phase 1: Initial deployment",
		func() error {
			_, err := options.RunTest()
			return err
		},
		testLogger,
	)
	testLogger.Info(t, fmt.Sprintf("Phase 1 duration: %v", time.Since(phase1Start)))

	// ── 5. Validation ────────────────────────────────────────────────────────
	utils.RunValidateCluster(t, testLogger, func(t *testing.T) {
		lsf.ValidateBasicClusterConfigurationForComputeAsBM(t, options, testLogger)
	})

	// ── 6. Phase 2: Scale-Down ───────────────────────────────────────
	utils.UpdateInstanceCount(t, options.TerraformOptions.Vars, "static_compute_instances", -1)
	testLogger.Info(t, fmt.Sprintf("static_compute_instances=%v", options.TerraformOptions.Vars["static_compute_instances"]))

	phase2Start := time.Now()
	utils.RunPhase(
		t,
		"Phase 2: Scale Down",
		func() error {
			_, err := options.RunTest()
			return err
		},
		testLogger,
	)
	testLogger.Info(t, fmt.Sprintf("Phase 2 duration: %v", time.Since(phase2Start)))

	// ── 7. Validation ────────────────────────────────────────────────────────
	utils.RunValidateCluster(t, testLogger, func(t *testing.T) {
		lsf.ValidateBasicClusterConfigurationForComputeAsBM(t, options, testLogger)
	})

}
