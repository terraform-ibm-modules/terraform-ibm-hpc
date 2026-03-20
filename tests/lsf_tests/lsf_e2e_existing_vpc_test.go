package tests

import (
	"fmt"
	"testing"
	"time"

	"github.com/stretchr/testify/require"
	lsf "github.com/terraform-ibm-modules/terraform-ibm-hpc/lsf"
	utils "github.com/terraform-ibm-modules/terraform-ibm-hpc/utilities"
)

// ── Existing VPC tests ────────────────────────────────────────────────────────

// TestRunCreateClusterWithExistingVPC validates cluster creation using a brand new VPC,
// then runs two sequential subtests to verify cluster creation with custom CIDRs and
// with existing subnets but no DNS.
//
// Prerequisites:
//   - Valid environment configuration
//   - Proper test suite initialization
//   - Required permissions for VPC and resource operations
func TestRunCreateClusterWithExistingVPC(t *testing.T) {
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

	options, err := setupOptionsVPC(t, clusterNamePrefix, createVpcTerraformDir, envVars.DefaultExistingResourceGroup)
	require.NoError(t, err, "Failed to initialize VPC test options")
	testLogger.Info(t, "VPC test options initialized successfully")

	// Override default zones with existingvpc-specific region (default_region=false).
	applyRegionOverrides(t, envVars, options, "existingvpc")
	testLogger.Info(t, "Region overrides applied for existingvpc cluster configuration")

	// ── 3. Teardown ──────────────────────────────────────────────────────────
	// SkipTestTearDown defers destruction to the explicit defer below, giving
	// us control over logging and sequencing around teardown.
	options.SkipTestTearDown = true
	defer func() {
		testLogger.Info(t, "Initiating final resource teardown...")
		options.TestTearDown()
		testLogger.Info(t, "Resource teardown completed")
	}()

	// ── 4. VPC Deployment ────────────────────────────────────────────────────
	deploymentStart := time.Now()
	testLogger.Info(t, fmt.Sprintf("[START] VPC deployment for test: %s", t.Name()))

	output, err := options.RunTest()
	if err != nil {
		testLogger.FAIL(t, fmt.Sprintf("VPC deployment failed after %v: %v", time.Since(deploymentStart), err))
	}
	require.NoError(t, err, "VPC deployment failed")
	require.NotNil(t, output, "VPC deployment returned nil output")
	testLogger.Info(t, fmt.Sprintf("[END] VPC deployment completed successfully (duration: %v)", time.Since(deploymentStart)))

	// Extract VPC outputs for use in subtests.
	outputs := options.LastTestTerraformOutputs
	vpcName := outputs["vpc_name"].(string)
	testLogger.Info(t, fmt.Sprintf("VPC name retrieved from outputs: %s", vpcName))

	bastionSubnetID, computeSubnetIDs := utils.GetSubnetIds(outputs)
	testLogger.Info(t, "Subnet IDs retrieved from VPC outputs")

	// ── 5. Subtests ──────────────────────────────────────────────────────────
	// RunCreateClusterWithExistingVpcCIDRs and RunCreateClusterWithExistingVpcSubnetsNoDns
	// run sequentially by design — both depend on the VPC created above.
	// Do NOT add t.Parallel() to either subtest.
	t.Run("RunCreateClusterWithExistingVpcCIDRs", func(t *testing.T) {
		RunCreateClusterWithExistingVpcCIDRs(t, vpcName)
	})

	t.Run("RunCreateClusterWithExistingVpcSubnetsNoDns", func(t *testing.T) {
		RunCreateClusterWithExistingVpcSubnetsNoDns(t, vpcName, bastionSubnetID, computeSubnetIDs)
	})
}

// RunCreateClusterWithExistingVpcCIDRs validates cluster creation inside an existing VPC
// using custom CIDR blocks instead of the defaults.
func RunCreateClusterWithExistingVpcCIDRs(t *testing.T, vpcName string) {
	t.Helper()

	// ── 1. Initialization ────────────────────────────────────────────────────
	setupTestSuite(t)
	require.NotNil(t, testLogger, "Test logger must be initialized before use")
	defer logResult(t)
	testLogger.Info(t, fmt.Sprintf("[START] Test %s initiated", t.Name()))

	// ── 2. Configuration ─────────────────────────────────────────────────────
	clusterNamePrefix := utils.GenerateTimestampedClusterPrefix(utils.GenerateRandomString())
	testLogger.Info(t, fmt.Sprintf("Generated cluster name prefix: %s", clusterNamePrefix))

	// Static non-default CIDR blocks for this scenario.
	vpcClusterPrivateSubnetsCidrBlocks := "10.241.32.0/24"
	vpcClusterLoginPrivateSubnetsCidrBlocks := "10.241.16.32/28"

	envVars, err := GetEnvVars()
	require.NoError(t, err, "Failed to load environment configuration")
	testLogger.Info(t, "Environment variables loaded successfully")

	options, err := setupOptions(t, clusterNamePrefix, terraformDir, envVars.DefaultExistingResourceGroup)
	require.NoError(t, err, "Failed to initialize test options")
	testLogger.Info(t, "Test options initialized successfully")

	options.TerraformVars["vpc_name"] = vpcName
	options.TerraformVars["vpc_cluster_private_subnets_cidr_blocks"] = vpcClusterPrivateSubnetsCidrBlocks
	options.TerraformVars["vpc_cluster_login_private_subnets_cidr_blocks"] = vpcClusterLoginPrivateSubnetsCidrBlocks
	testLogger.Info(t, fmt.Sprintf("Custom CIDR blocks applied for VPC: %s", vpcName))

	// Override default zones with existingvpc-specific region (default_region=false).
	applyRegionOverrides(t, envVars, options, "existingvpc")
	testLogger.Info(t, "Region overrides applied for existingvpc cluster configuration")

	// ── 3. Teardown ──────────────────────────────────────────────────────────
	options.SkipTestTearDown = true
	defer func() {
		testLogger.Info(t, "Initiating final resource teardown...")
		options.TestTearDown()
		testLogger.Info(t, "Resource teardown completed")
	}()

	// ── 4. Deployment ────────────────────────────────────────────────────────
	deploymentStart := time.Now()
	testLogger.Info(t, fmt.Sprintf("[START] Cluster deployment for test: %s", t.Name()))

	err = lsf.VerifyClusterCreationAndConsistency(t, options, testLogger)
	if err != nil {
		testLogger.FAIL(t, fmt.Sprintf("Cluster deployment failed after %v: %v", time.Since(deploymentStart), err))
		require.NoError(t, err, "Cluster creation and consistency check failed")
	}
	testLogger.Info(t, fmt.Sprintf("[END] Cluster deployment completed successfully (duration: %v)", time.Since(deploymentStart)))

	// ── 5. Validation ────────────────────────────────────────────────────────
	validationStart := time.Now()
	testLogger.Info(t, fmt.Sprintf("[START] Cluster validation for test: %s", t.Name()))
	lsf.ValidateClusterConfiguration(t, options, testLogger)
	testLogger.Info(t, fmt.Sprintf("[END] Cluster validation completed successfully (duration: %v)", time.Since(validationStart)))
}

// RunCreateClusterWithExistingVpcSubnetsNoDns validates cluster creation inside an existing VPC
// using pre-existing subnets with no DNS instance or custom resolver.
func RunCreateClusterWithExistingVpcSubnetsNoDns(t *testing.T, vpcName string, bastionSubnetID string, computeSubnetIDs string) {
	t.Helper()

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

	options.TerraformVars["vpc_name"] = vpcName
	options.TerraformVars["login_subnet_id"] = bastionSubnetID
	options.TerraformVars["compute_subnet_id"] = computeSubnetIDs
	testLogger.Info(t, fmt.Sprintf("Existing subnet IDs applied for VPC: %s (no DNS)", vpcName))

	// Override default zones with existingvpc-specific region (default_region=false).
	applyRegionOverrides(t, envVars, options, "existingvpc")
	testLogger.Info(t, "Region overrides applied for existingvpc cluster configuration")

	// ── 3. Teardown ──────────────────────────────────────────────────────────
	options.SkipTestTearDown = true
	defer func() {
		testLogger.Info(t, "Initiating final resource teardown...")
		options.TestTearDown()
		testLogger.Info(t, "Resource teardown completed")
	}()

	// ── 4. Deployment ────────────────────────────────────────────────────────
	deploymentStart := time.Now()
	testLogger.Info(t, fmt.Sprintf("[START] Cluster deployment for test: %s", t.Name()))

	err = lsf.VerifyClusterCreationAndConsistency(t, options, testLogger)
	if err != nil {
		testLogger.FAIL(t, fmt.Sprintf("Cluster deployment failed after %v: %v", time.Since(deploymentStart), err))
		require.NoError(t, err, "Cluster creation and consistency check failed")
	}
	testLogger.Info(t, fmt.Sprintf("[END] Cluster deployment completed successfully (duration: %v)", time.Since(deploymentStart)))

	// ── 5. Validation ────────────────────────────────────────────────────────
	validationStart := time.Now()
	testLogger.Info(t, fmt.Sprintf("[START] Cluster validation for test: %s", t.Name()))
	lsf.ValidateClusterConfiguration(t, options, testLogger)
	testLogger.Info(t, fmt.Sprintf("[END] Cluster validation completed successfully (duration: %v)", time.Since(validationStart)))
}

// TestRunCreateVpcWithCustomDns validates cluster creation with a brand new VPC and custom DNS,
// then runs two sequential subtests to verify cluster creation with a full DNS+resolver
// configuration and with a resolver-only configuration.
//
// Prerequisites:
//   - Valid environment configuration
//   - Proper test suite initialization
//   - Required permissions for VPC, DNS, and resource operations
func TestRunCreateVpcWithCustomDns(t *testing.T) {
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

	options, err := setupOptionsVPC(t, clusterNamePrefix, createVpcTerraformDir, envVars.DefaultExistingResourceGroup)
	require.NoError(t, err, "Failed to initialize VPC test options")
	testLogger.Info(t, "VPC test options initialized successfully")

	options.TerraformVars["enable_hub"] = true
	options.TerraformVars["dns_zone_name"] = "hpc.local"
	testLogger.Info(t, "Hub and DNS zone configured for custom DNS VPC")

	// Override default zones with existingvpc-specific region (default_region=false).
	applyRegionOverrides(t, envVars, options, "existingvpc")
	testLogger.Info(t, "Region overrides applied for existingvpc cluster configuration")

	// ── 3. Teardown ──────────────────────────────────────────────────────────
	options.SkipTestTearDown = true
	defer func() {
		testLogger.Info(t, "Initiating final resource teardown...")
		options.TestTearDown()
		testLogger.Info(t, "Resource teardown completed")
	}()

	// ── 4. VPC Deployment ────────────────────────────────────────────────────
	deploymentStart := time.Now()
	testLogger.Info(t, fmt.Sprintf("[START] VPC deployment for test: %s", t.Name()))

	output, err := options.RunTest()
	if err != nil {
		testLogger.FAIL(t, fmt.Sprintf("VPC deployment failed after %v: %v", time.Since(deploymentStart), err))
	}
	require.NoError(t, err, "VPC deployment failed")
	require.NotNil(t, output, "VPC deployment returned nil output")
	testLogger.Info(t, fmt.Sprintf("[END] VPC deployment completed successfully (duration: %v)", time.Since(deploymentStart)))

	// Extract VPC and DNS outputs for use in subtests.
	outputs := options.LastTestTerraformOutputs
	vpcName := outputs["vpc_name"].(string)
	testLogger.Info(t, fmt.Sprintf("VPC name retrieved from outputs: %s", vpcName))

	instanceID, customResolverID := utils.GetDnsCustomResolverIds(outputs)
	bastionSubnetID, computeSubnetIDs := utils.GetSubnetIds(outputs)
	testLogger.Info(t, "DNS instance ID, custom resolver ID, and subnet IDs retrieved from VPC outputs")

	// ── 5. Subtests ──────────────────────────────────────────────────────────
	// RunCreateClusterWithDnsAndResolver and RunCreateClusterWithOnlyResolver
	// run sequentially by design — both depend on the VPC created above.
	// Do NOT add t.Parallel() to either subtest.
	t.Run("RunCreateClusterWithDnsAndResolver", func(t *testing.T) {
		RunCreateClusterWithDnsAndResolver(t, vpcName, bastionSubnetID, computeSubnetIDs, instanceID, customResolverID)
	})

	t.Run("RunCreateClusterWithOnlyResolver", func(t *testing.T) {
		RunCreateClusterWithOnlyResolver(t, vpcName, bastionSubnetID, computeSubnetIDs, customResolverID)
	})
}

// RunCreateClusterWithDnsAndResolver validates cluster creation with both an existing
// DNS instance ID and an existing custom resolver ID.
func RunCreateClusterWithDnsAndResolver(t *testing.T, vpcName string, bastionSubnetID string, computeSubnetIDs string, instanceID string, customResolverID string) {
	t.Helper()

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

	options.TerraformVars["vpc_name"] = vpcName
	options.TerraformVars["login_subnet_id"] = bastionSubnetID
	options.TerraformVars["compute_subnet_id"] = computeSubnetIDs
	options.TerraformVars["dns_instance_id"] = instanceID
	options.TerraformVars["dns_custom_resolver_id"] = customResolverID
	testLogger.Info(t, fmt.Sprintf("Existing DNS instance and custom resolver configured for VPC: %s", vpcName))

	// Override default zones with existingvpc-specific region (default_region=false).
	applyRegionOverrides(t, envVars, options, "existingvpc")
	testLogger.Info(t, "Region overrides applied for existingvpc cluster configuration")

	// ── 3. Teardown ──────────────────────────────────────────────────────────
	options.SkipTestTearDown = true
	defer func() {
		testLogger.Info(t, "Initiating final resource teardown...")
		options.TestTearDown()
		testLogger.Info(t, "Resource teardown completed")
	}()

	// ── 4. Deployment ────────────────────────────────────────────────────────
	deploymentStart := time.Now()
	testLogger.Info(t, fmt.Sprintf("[START] Cluster deployment for test: %s", t.Name()))

	err = lsf.VerifyClusterCreationAndConsistency(t, options, testLogger)
	if err != nil {
		testLogger.FAIL(t, fmt.Sprintf("Cluster deployment failed after %v: %v", time.Since(deploymentStart), err))
		require.NoError(t, err, "Cluster creation and consistency check failed")
	}
	testLogger.Info(t, fmt.Sprintf("[END] Cluster deployment completed successfully (duration: %v)", time.Since(deploymentStart)))

	// ── 5. Validation ────────────────────────────────────────────────────────
	validationStart := time.Now()
	testLogger.Info(t, fmt.Sprintf("[START] Cluster validation for test: %s", t.Name()))
	lsf.ValidateClusterConfiguration(t, options, testLogger)
	testLogger.Info(t, fmt.Sprintf("[END] Cluster validation completed successfully (duration: %v)", time.Since(validationStart)))
}

// RunCreateClusterWithOnlyResolver validates cluster creation with an existing custom
// resolver ID but no pre-existing DNS instance (a new DNS instance will be created).
func RunCreateClusterWithOnlyResolver(t *testing.T, vpcName string, bastionSubnetID string, computeSubnetIDs string, customResolverID string) {
	t.Helper()

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

	options.TerraformVars["vpc_name"] = vpcName
	options.TerraformVars["login_subnet_id"] = bastionSubnetID
	options.TerraformVars["compute_subnet_id"] = computeSubnetIDs
	options.TerraformVars["dns_custom_resolver_id"] = customResolverID
	testLogger.Info(t, fmt.Sprintf("Existing custom resolver configured for VPC: %s (new DNS instance will be created)", vpcName))

	// Override default zones with existingvpc-specific region (default_region=false).
	applyRegionOverrides(t, envVars, options, "existingvpc")
	testLogger.Info(t, "Region overrides applied for existingvpc cluster configuration")

	// ── 3. Teardown ──────────────────────────────────────────────────────────
	options.SkipTestTearDown = true
	defer func() {
		testLogger.Info(t, "Initiating final resource teardown...")
		options.TestTearDown()
		testLogger.Info(t, "Resource teardown completed")
	}()

	// ── 4. Deployment ────────────────────────────────────────────────────────
	deploymentStart := time.Now()
	testLogger.Info(t, fmt.Sprintf("[START] Cluster deployment for test: %s", t.Name()))

	err = lsf.VerifyClusterCreationAndConsistency(t, options, testLogger)
	if err != nil {
		testLogger.FAIL(t, fmt.Sprintf("Cluster deployment failed after %v: %v", time.Since(deploymentStart), err))
		require.NoError(t, err, "Cluster creation and consistency check failed")
	}
	testLogger.Info(t, fmt.Sprintf("[END] Cluster deployment completed successfully (duration: %v)", time.Since(deploymentStart)))

	// ── 5. Validation ────────────────────────────────────────────────────────
	validationStart := time.Now()
	testLogger.Info(t, fmt.Sprintf("[START] Cluster validation for test: %s", t.Name()))
	lsf.ValidateClusterConfiguration(t, options, testLogger)
	testLogger.Info(t, fmt.Sprintf("[END] Cluster validation completed successfully (duration: %v)", time.Since(validationStart)))
}

// TestRunCreateVpcWithCustomDnsOnlyDNS creates a new VPC with custom DNS and validates
// cluster creation using an existing DNS instance with no custom resolver (resolver is null).
//
// Prerequisites:
//   - Valid environment configuration
//   - Proper test suite initialization
//   - Required permissions for VPC and DNS operations
func TestRunCreateVpcWithCustomDnsOnlyDNS(t *testing.T) {
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

	options, err := setupOptionsVPC(t, clusterNamePrefix, createVpcTerraformDir, envVars.DefaultExistingResourceGroup)
	require.NoError(t, err, "Failed to initialize VPC test options")
	testLogger.Info(t, "VPC test options initialized successfully")

	options.TerraformVars["enable_hub"] = true
	options.TerraformVars["dns_zone_name"] = "hpc.local"
	testLogger.Info(t, "Hub and DNS zone configured for custom DNS VPC")

	// Override default zones with existingvpc-specific region (default_region=false).
	applyRegionOverrides(t, envVars, options, "existingvpc")
	testLogger.Info(t, "Region overrides applied for existingvpc cluster configuration")

	// ── 3. Teardown ──────────────────────────────────────────────────────────
	options.SkipTestTearDown = true
	defer func() {
		testLogger.Info(t, "Initiating final resource teardown...")
		options.TestTearDown()
		testLogger.Info(t, "Resource teardown completed")
	}()

	// ── 4. VPC Deployment ────────────────────────────────────────────────────
	deploymentStart := time.Now()
	testLogger.Info(t, fmt.Sprintf("[START] VPC deployment for test: %s", t.Name()))

	output, err := options.RunTest()
	if err != nil {
		testLogger.FAIL(t, fmt.Sprintf("VPC deployment failed after %v: %v", time.Since(deploymentStart), err))
	}
	require.NoError(t, err, "VPC deployment failed")
	require.NotNil(t, output, "VPC deployment returned nil output")
	testLogger.Info(t, fmt.Sprintf("[END] VPC deployment completed successfully (duration: %v)", time.Since(deploymentStart)))

	// Extract DNS instance ID; custom resolver ID is intentionally discarded (_).
	outputs := options.LastTestTerraformOutputs
	instanceID, _ := utils.GetDnsCustomResolverIds(outputs)
	testLogger.Info(t, fmt.Sprintf("DNS instance ID retrieved: %s (custom resolver not used)", instanceID))

	// ── 5. Subtest ───────────────────────────────────────────────────────────
	t.Run("RunCreateClusterWithOnlyDns", func(t *testing.T) {
		RunCreateClusterWithOnlyDns(t, instanceID)
	})
}

// RunCreateClusterWithOnlyDns validates cluster creation using an existing DNS instance
// with no custom resolver (custom_resolver_id = null; a new resolver will be created).
func RunCreateClusterWithOnlyDns(t *testing.T, instanceID string) {
	t.Helper()

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

	// dns_custom_resolver_id intentionally omitted — verifies cluster creates its own resolver.
	options.TerraformVars["dns_instance_id"] = instanceID
	testLogger.Info(t, fmt.Sprintf("Existing DNS instance configured: %s (custom resolver will be created)", instanceID))

	// Override default zones with existingvpc-specific region (default_region=false).
	applyRegionOverrides(t, envVars, options, "existingvpc")
	testLogger.Info(t, "Region overrides applied for existingvpc cluster configuration")

	// ── 3. Teardown ──────────────────────────────────────────────────────────
	options.SkipTestTearDown = true
	defer func() {
		testLogger.Info(t, "Initiating final resource teardown...")
		options.TestTearDown()
		testLogger.Info(t, "Resource teardown completed")
	}()

	// ── 4. Deployment ────────────────────────────────────────────────────────
	deploymentStart := time.Now()
	testLogger.Info(t, fmt.Sprintf("[START] Cluster deployment for test: %s", t.Name()))

	err = lsf.VerifyClusterCreationAndConsistency(t, options, testLogger)
	if err != nil {
		testLogger.FAIL(t, fmt.Sprintf("Cluster deployment failed after %v: %v", time.Since(deploymentStart), err))
		require.NoError(t, err, "Cluster creation and consistency check failed")
	}
	testLogger.Info(t, fmt.Sprintf("[END] Cluster deployment completed successfully (duration: %v)", time.Since(deploymentStart)))

	// ── 5. Validation ────────────────────────────────────────────────────────
	validationStart := time.Now()
	testLogger.Info(t, fmt.Sprintf("[START] Cluster validation for test: %s", t.Name()))
	lsf.ValidateClusterConfiguration(t, options, testLogger)
	testLogger.Info(t, fmt.Sprintf("[END] Cluster validation completed successfully (duration: %v)", time.Since(validationStart)))
}
