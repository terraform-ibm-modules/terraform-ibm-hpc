package tests

import (
	"fmt"
	"testing"
	"time"

	"github.com/stretchr/testify/require"
	"github.com/terraform-ibm-modules/ibmcloud-terratest-wrapper/testhelper"
)

// VerifyClusterCreationAndConsistency validates successful cluster creation and operational
// consistency. It:
//  1. Executes a consistency test via RunTestConsistency()
//  2. Verifies non-nil output
//  3. Provides detailed, traceable errors on failure
//
// Returns nil on success, or an error with context on failure.
// All outcomes are logged through the provided logger.
func VerifyClusterCreationAndConsistency(t *testing.T, options *testhelper.TestOptions, logger *AggregatedLogger) error {
	const op = "cluster creation and consistency check"

	// Create a local copy of the test name to prevent race conditions
	testName := t.Name()

	// Execute the consistency test - ensure RunTestConsistency() is thread-safe
	output, err := options.RunTestConsistency()

	if err != nil {
		// Thread-safe logging
		logger.Error(t, fmt.Sprintf("%s failed for test %s: %v", op, testName, err))
		return fmt.Errorf("%s failed for test %s: %w", op, testName, err)
	}

	// Check output with thread-safe nil check
	if output == nil {
		msg := fmt.Sprintf("%s failed for test %s: nil consistency output", op, testName)
		// Thread-safe logging
		logger.Error(t, msg)
		return fmt.Errorf("%s: %s", op, msg)
	}

	// Thread-safe success logging
	logger.Info(t, fmt.Sprintf("%s: %s passed", testName, op))
	return nil
}

// VerifyClusterCreation checks cluster creation and operational consistency.
// It runs options.RunTest and ensures the output is not nil.
// Logs results and returns an error if validation fails.
func VerifyClusterCreation(t *testing.T, options *testhelper.TestOptions, logger *AggregatedLogger) error {
	const op = "cluster creation and consistency check"

	// Create a local copy of the test name to prevent race conditions
	testName := t.Name()

	// Execute the consistency test - ensure RunTest is thread-safe
	output, err := options.RunTest()
	if err != nil {
		// Thread-safe logging
		logger.Error(t, fmt.Sprintf("%s failed for test %s: %v", op, testName, err))
		return fmt.Errorf("%s failed for test %s: %w", op, testName, err)
	}

	// Check output with thread-safe nil check
	if output == "" {
		msg := fmt.Sprintf("%s failed for test %s: no output from cluster validation test", op, testName)
		logger.Error(t, msg)
		return fmt.Errorf("%s: %s", op, msg)
	}

	// Thread-safe success logging
	logger.Info(t, fmt.Sprintf("%s: %s passed", testName, op))
	return nil
}

// DeployCluster runs the deployment subtest and aborts the parent if it fails.
// t.Parallel() is intentionally omitted to ensure sequential execution.
func DeployCluster(t *testing.T, options *testhelper.TestOptions, logger *AggregatedLogger) {
	t.Helper()

	t.Run("DeployCluster", func(t *testing.T) {
		t.Helper()
		deploymentStart := time.Now()
		logger.Info(t, fmt.Sprintf("[START] Cluster deployment for test: %s", t.Name()))

		err := VerifyClusterCreationAndConsistency(t, options, logger)
		if err != nil {
			logger.FAIL(t, fmt.Sprintf("Cluster deployment failed after %v: %v", time.Since(deploymentStart), err))
			require.NoError(t, err, "Cluster creation and consistency check failed")
		}

		logger.Info(t, fmt.Sprintf("[END] Cluster deployment completed successfully (duration: %v)", time.Since(deploymentStart)))
	})

	require.False(t, t.Failed(), "DeployCluster failed — aborting parent test, skipping ValidateCluster")
}

// RunValidateCluster wraps the validation step in a named subtest with consistent
// start/end logging. The caller provides the specific validation function to execute.
func RunValidateCluster(t *testing.T, logger *AggregatedLogger, validate func(t *testing.T)) {
	t.Helper()
	t.Run("ValidateCluster", func(t *testing.T) {
		t.Helper()
		validationStart := time.Now()
		logger.Info(t, fmt.Sprintf("[START] Cluster validation for test: %s", t.Name()))
		validate(t)
		logger.Info(t, fmt.Sprintf("[END] Cluster validation completed successfully (duration: %v)", time.Since(validationStart)))
	})
}

func RunPhase(t *testing.T, phase string, fn func() error, logger *AggregatedLogger) {
	logger.Info(t, fmt.Sprintf("[START] %s", phase))

	if err := fn(); err != nil {
		logger.Error(t, fmt.Sprintf("%s failed: %v", phase, err))
		t.FailNow()
	}

	logger.Info(t, fmt.Sprintf("[END] %s completed successfully", phase))
}

// SetupTeardown returns a teardown function that must be deferred immediately.
//
// On the normal path, the returned function runs options.TestTearDown() followed
// by RunCleanupAfterTeardown(). If the test body panics, it recovers, skips
// terraform destroy (the stack may be inconsistent), and runs only orphan
// cleanup.
//
// SetupTeardown requires options.SkipTestTearDown to already be true; it does
// not set this flag. Otherwise, Terratest's automatic teardown may run as well:
//
//	options.SkipTestTearDown = true
//	defer utils.SetupTeardown(t, options, logger)()
//
// If SkipTestTearDown is false, the test is marked failed with t.Fail() instead
// of t.Fatal()/t.FailNow(). Since SetupTeardown is evaluated before the defer
// is registered, Goexit would prevent the returned cleanup function from being
// deferred, potentially leaving resources behind.
func SetupTeardown(t *testing.T, options *testhelper.TestOptions, logger *AggregatedLogger) func() {
	t.Helper()

	if !options.SkipTestTearDown {
		logger.FAIL(t, "options.SkipTestTearDown was not set to true before calling SetupTeardown — "+
			"terratest's automatic teardown may run in addition to this cleanup")
		t.Fail()
	}

	return func() {
		if r := recover(); r != nil {
			logger.Error(t, fmt.Sprintf("Panic during test: %v", r))
			logger.Info(t, "Skipping terraform destroy after panic — running orphan cleanup only...")
			// Skip destroying resources (state might be broken)
			// Just clean up any orphaned resources
			RunCleanupAfterTeardown(t, options, logger)
			t.Errorf("test panicked: %v", r)
			return
		}

		// Registered before TestTearDown() runs, so cleanup still fires
		// even if TestTearDown() itself panics.
		defer func() {
			if r := recover(); r != nil {
				logger.Error(t, fmt.Sprintf("Panic during terraform destroy: %v", r))
				t.Errorf("terraform destroy panicked: %v", r)
			}
			RunCleanupAfterTeardown(t, options, logger) // Double-check nothing remains // Always runs!
		}()

		logger.Info(t, "Initiating final resource teardown...")
		options.TestTearDown() // Destroy terraform resources
		logger.Info(t, "Resource teardown completed")
	}
}
