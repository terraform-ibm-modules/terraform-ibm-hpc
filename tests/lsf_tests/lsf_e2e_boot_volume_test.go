package tests

import (
	"fmt"
	"testing"
	"time"

	"github.com/stretchr/testify/require"
	lsf "github.com/terraform-ibm-modules/terraform-ibm-hpc/lsf"
	utils "github.com/terraform-ibm-modules/terraform-ibm-hpc/utilities"
)

func TestBootVolume(t *testing.T) {
	t.Helper()
	t.Parallel()

	// =========================================================================
	// Test Setup
	// =========================================================================
	setupTestSuite(t)
	require.NotNil(t, testLogger, "Test logger must be initialized before use")
	defer logResult(t)
	testLogger.Info(t, fmt.Sprintf("[START] Test %s initiated", t.Name()))

	// =========================================================================
	// Test Configuration
	// =========================================================================
	clusterNamePrefix := utils.GenerateTimestampedClusterPrefix(utils.GenerateRandomString())
	testLogger.Info(t, fmt.Sprintf("Generated cluster name prefix: %s", clusterNamePrefix))

	envVars, err := GetEnvVars()
	utils.NoError(t, err, "Failed to load environment configuration", testLogger)
	testLogger.Info(t, "Environment variables loaded successfully")

	options, err := setupOptions(t, clusterNamePrefix, terraformDir, envVars.NonDefaultExistingResourceGroup)
	utils.NoError(t, err, "Failed to initialize test options", testLogger)
	testLogger.Info(t, "Test options initialized successfully")

	// =========================================================================
	// Test Teardown
	// =========================================================================
	options.SkipTestTearDown = true
	options.DisableTempWorkingDir = true

	preparedTerraformDir := utils.PrepareTerraformWorkingDir(
		t,
		clusterNamePrefix,
		options.TerraformDir,
		options.IsUpgradeTest,
	)
	options.TerraformDir = preparedTerraformDir

	for _, key := range []string{
		"login_instance",
		"management_instances",
		"static_compute_instances",
		"dynamic_compute_instances",
	} {
		testLogger.Info(
			t,
			fmt.Sprintf(
				"BEFORE %s type=%T value=%#v",
				key,
				options.TerraformVars[key],
				options.TerraformVars[key],
			),
		)
	}
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
	err = utils.UpdateBootVolume(options.TerraformVars, false)
	require.NoError(t, err)

	// Log the initial boot volume configuration before making any changes.
	for _, key := range []string{
		"login_instance",
		"management_instances",
		"static_compute_instances",
		"dynamic_compute_instances",
	} {
		testLogger.Info(
			t,
			fmt.Sprintf(
				"PHASE 1, AFTER %s type=%T value=%#v",
				key,
				options.TerraformVars[key],
				options.TerraformVars[key],
			),
		)
	}
	// =========================================================================
	// Phase 1 - Initial Cluster Deployment
	// =========================================================================
	// Configure the cluster with the baseline boot volume sizes and deploy it.
	phase1Start := time.Now()
	runPhase("Phase 1: Initial deployment", func() error {
		_, err := options.RunTest()
		return err
	})
	testLogger.Info(t, fmt.Sprintf("Phase 1 duration: %v", time.Since(phase1Start)))

	utils.RunValidateCluster(t, testLogger, func(t *testing.T) {
		lsf.ValidateBootVolumeClusterConfiguration(t, options, testLogger, 150, 200, 300, 150)
	})

	// =========================================================================
	// Phase 2 - Boot Volume Resize
	// =========================================================================
	// Update the Terraform configuration with larger boot volume sizes and
	// re-apply the deployment. This validates that boot volume expansion works
	// correctly on an existing cluster.
	err = utils.UpdateBootVolume(options.TerraformOptions.Vars, true)
	require.NoError(t, err)

	// Log the updated Terraform variables before the second deployment.
	for _, key := range []string{
		"login_instance",
		"management_instances",
		"static_compute_instances",
		"dynamic_compute_instances",
	} {
		testLogger.Info(
			t,
			fmt.Sprintf(
				"PHASE 2, AFTER %s type=%T value=%#v",
				key,
				options.TerraformOptions.Vars[key],
				options.TerraformOptions.Vars[key],
			),
		)
	}

	// Re-apply Terraform so the updated boot volume sizes are propagated to
	// the existing cluster.
	phase2Start := time.Now()
	runPhase("Phase 2: Disk Grow", func() error {
		_, err := options.RunTest()
		return err
	})
	testLogger.Info(t, fmt.Sprintf("Phase 2 duration: %v", time.Since(phase2Start)))

	// =========================================================================
	// Final Validation
	// =========================================================================
	// Confirm that every node now reports the resized boot volume, proving that
	// the update was successfully applied without recreating the cluster.
	utils.RunValidateCluster(t, testLogger, func(t *testing.T) {
		lsf.ValidateBootVolumeClusterConfiguration(t, options, testLogger, 250, 300, 400, 250)
	})
}
