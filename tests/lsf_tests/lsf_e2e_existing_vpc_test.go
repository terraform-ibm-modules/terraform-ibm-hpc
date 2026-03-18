package tests

import (
	"fmt"
	"testing"
	"time"

	"github.com/stretchr/testify/require"
	lsf "github.com/terraform-ibm-modules/terraform-ibm-hpc/lsf"
	utils "github.com/terraform-ibm-modules/terraform-ibm-hpc/utilities"
)

// ******************* Existing VPC ***************************

// TestRunCreateClusterWithExistingVPC as brand new
func TestRunCreateClusterWithExistingVPC(t *testing.T) {
	// Parallelize the test to run concurrently with others
	t.Parallel()

	// Set up the test suite and prepare the testing environment
	setupTestSuite(t)

	testLogger.Info(t, "Brand new VPC creation initiated for "+t.Name())

	// Generate Unique Cluster Prefix
	clusterNamePrefix := utils.GenerateTimestampedClusterPrefix(utils.GenerateRandomString())
	testLogger.Info(t, fmt.Sprintf("Generated cluster prefix: %s", clusterNamePrefix))

	// Get and validate environment variables
	envVars, err := GetEnvVars()
	require.NoError(t, err, "Failed to get environment variables")

	// Set up the test options with the relevant parameters, including environment variables and resource group, set up test environment
	options, err := setupOptionsVPC(t, clusterNamePrefix, createVpcTerraformDir, envVars.DefaultExistingResourceGroup)
	require.NoError(t, err, "Error setting up test options: %v", err)

	// Override default zones with existingvpc-specific region since default_region=false
	applyRegionOverrides(t, envVars, options, "existingvpc")

	// Skip test teardown for further inspection
	options.SkipTestTearDown = true
	defer options.TestTearDown()

	// Cluster Deployment
	deploymentStart := time.Now()
	testLogger.Info(t, fmt.Sprintf("Starting cluster deployment for test: %s", t.Name()))
	output, err := options.RunTest()
	require.NoError(t, err, "Error running consistency test: %v", err)
	require.NotNil(t, output, "Expected non-nil output, but got nil")
	testLogger.Info(t, fmt.Sprintf("Cluster deployment completed (duration: %v)", time.Since(deploymentStart)))

	outputs := (options.LastTestTerraformOutputs)
	vpcName := outputs["vpc_name"].(string)

	bastionsubnetId, computesubnetIds := utils.GetSubnetIds(outputs)

	t.Run("RunCreateClusterWithExistingVpcCIDRs", func(t *testing.T) {
		RunCreateClusterWithExistingVpcCIDRs(t, vpcName)
	})

	t.Run("RunCreateClusterWithExistingVpcSubnetsNoDns", func(t *testing.T) {
		RunCreateClusterWithExistingVpcSubnetsNoDns(t, vpcName, bastionsubnetId, computesubnetIds)
	})

	// Test Result Evaluation
	if t.Failed() {
		testLogger.Error(t, fmt.Sprintf("Test %s failed - inspect validation logs", t.Name()))
	} else {
		testLogger.PASS(t, fmt.Sprintf("Test %s completed successfully", t.Name()))
	}
}

// RunCreateClusterWithExistingVpcCIDRs with Cidr blocks
func RunCreateClusterWithExistingVpcCIDRs(t *testing.T, vpcName string) {

	// Set up the test suite and prepare the testing environment
	setupTestSuite(t)

	// Log the initiation of the cluster creation process
	testLogger.Info(t, "Cluster creation process initiated for RunCreateClusterWithExistingVpcCIDRs")

	// Generate Unique Cluster Prefix
	clusterNamePrefix := utils.GenerateTimestampedClusterPrefix(utils.GenerateRandomString())
	testLogger.Info(t, fmt.Sprintf("Generated cluster prefix: %s", clusterNamePrefix))

	// Static values for CIDR other than default CIDR
	vpcClusterPrivateSubnetsCidrBlocks := "10.241.32.0/24"
	vpcClusterLoginPrivateSubnetsCidrBlocks := "10.241.16.32/28"

	// Get and validate environment variables
	envVars, err := GetEnvVars()
	require.NoError(t, err, "Failed to get environment variables")

	// Set up the test options with the relevant parameters, including environment variables and resource group
	options, err := setupOptions(t, clusterNamePrefix, terraformDir, envVars.DefaultExistingResourceGroup)
	options.TerraformVars["vpc_name"] = vpcName
	options.TerraformVars["vpc_cluster_private_subnets_cidr_blocks"] = vpcClusterPrivateSubnetsCidrBlocks
	options.TerraformVars["vpc_cluster_login_private_subnets_cidr_blocks"] = vpcClusterLoginPrivateSubnetsCidrBlocks
	require.NoError(t, err, "Error setting up test options: %v", err)

	// Override default zones with existingvpc-specific region since default_region=false
	applyRegionOverrides(t, envVars, options, "existingvpc")

	// Skip test teardown for further inspection
	options.SkipTestTearDown = true
	defer options.TestTearDown()

	// Cluster Deployment
	deploymentStart := time.Now()
	testLogger.Info(t, fmt.Sprintf("Starting cluster deployment for test: %s", t.Name()))

	clusterCreationErr := lsf.VerifyClusterCreationAndConsistency(t, options, testLogger)
	if clusterCreationErr != nil {
		testLogger.Error(t, fmt.Sprintf("Cluster deployment failed after %v: %v", time.Since(deploymentStart), clusterCreationErr))
		require.NoError(t, clusterCreationErr, "Cluster creation failed")
	}
	testLogger.Info(t, fmt.Sprintf("Cluster deployment completed successfully (duration: %v)", time.Since(deploymentStart)))

	lsf.ValidateClusterConfiguration(t, options, testLogger)

	testLogger.Info(t, fmt.Sprintf("Finished execution: %s", t.Name()))
}

// RunCreateClusterWithExistingVpcSubnetsNoDns with compute and login subnet id. Both custom_resolver and dns_instance null
func RunCreateClusterWithExistingVpcSubnetsNoDns(t *testing.T, vpcName string, bastionsubnetId string, computesubnetIds string) {

	// Set up the test suite and prepare the testing environment
	setupTestSuite(t)

	// Log the initiation of the cluster creation process
	testLogger.Info(t, "Cluster creation process initiated for RunCreateClusterWithExistingVpcSubnetsNoDns")

	// Generate Unique Cluster Prefix
	clusterNamePrefix := utils.GenerateTimestampedClusterPrefix(utils.GenerateRandomString())
	testLogger.Info(t, fmt.Sprintf("Generated cluster prefix: %s", clusterNamePrefix))

	// Get and validate environment variables
	envVars, err := GetEnvVars()
	require.NoError(t, err, "Failed to get environment variables")

	// Set up the test options with the relevant parameters, including environment variables and resource group
	options, err := setupOptions(t, clusterNamePrefix, terraformDir, envVars.DefaultExistingResourceGroup)
	options.TerraformVars["vpc_name"] = vpcName
	options.TerraformVars["login_subnet_id"] = bastionsubnetId
	options.TerraformVars["compute_subnet_id"] = computesubnetIds
	require.NoError(t, err, "Error setting up test options: %v", err)

	// Override default zones with existingvpc-specific region since default_region=false
	applyRegionOverrides(t, envVars, options, "existingvpc")

	// Skip test teardown for further inspection
	options.SkipTestTearDown = true
	defer options.TestTearDown()

	// Cluster Deployment
	deploymentStart := time.Now()
	testLogger.Info(t, fmt.Sprintf("Starting cluster deployment for test: %s", t.Name()))

	clusterCreationErr := lsf.VerifyClusterCreationAndConsistency(t, options, testLogger)
	if clusterCreationErr != nil {
		testLogger.Error(t, fmt.Sprintf("Cluster deployment failed after %v: %v", time.Since(deploymentStart), clusterCreationErr))
		require.NoError(t, clusterCreationErr, "Cluster creation failed")
	}
	testLogger.Info(t, fmt.Sprintf("Cluster deployment completed successfully (duration: %v)", time.Since(deploymentStart)))

	lsf.ValidateClusterConfiguration(t, options, testLogger)
	testLogger.Info(t, fmt.Sprintf("Finished execution: %s", t.Name()))
}

// TestRunCreateVpcWithCustomDns brand new VPC with DNS
func TestRunCreateVpcWithCustomDns(t *testing.T) {
	// Parallelize the test to run concurrently with others
	t.Parallel()

	// Set up the test suite and prepare the testing environment
	setupTestSuite(t)

	// Log the initiation of the cluster creation process
	testLogger.Info(t, "Cluster creation process initiated for "+t.Name())

	// Generate Unique Cluster Prefix
	clusterNamePrefix := utils.GenerateTimestampedClusterPrefix(utils.GenerateRandomString())
	testLogger.Info(t, fmt.Sprintf("Generated cluster prefix: %s", clusterNamePrefix))

	// Get and validate environment variables
	envVars, err := GetEnvVars()
	require.NoError(t, err, "Failed to get environment variables")

	// Set up the test options with the relevant parameters, including environment variables and resource group, set up test environment
	options, err := setupOptionsVPC(t, clusterNamePrefix, createVpcTerraformDir, envVars.DefaultExistingResourceGroup)
	options.TerraformVars["enable_hub"] = true
	options.TerraformVars["dns_zone_name"] = "hpc.local"
	require.NoError(t, err, "Error setting up test options: %v", err)

	// Override default zones with existingvpc-specific region since default_region=false
	applyRegionOverrides(t, envVars, options, "existingvpc")

	// Skip test teardown for further inspection
	options.SkipTestTearDown = true
	defer options.TestTearDown()

	// Cluster Deployment
	deploymentStart := time.Now()
	testLogger.Info(t, fmt.Sprintf("Starting cluster deployment for test: %s", t.Name()))
	output, err := options.RunTest()
	require.NoError(t, err, "Error running consistency test: %v", err)
	require.NotNil(t, output, "Expected non-nil output, but got nil")
	testLogger.Info(t, fmt.Sprintf("Cluster deployment completed (duration: %v)", time.Since(deploymentStart)))

	outputs := (options.LastTestTerraformOutputs)
	vpcName := outputs["vpc_name"].(string)
	instanceId, customResolverId := utils.GetDnsCustomResolverIds(outputs)
	bastionsubnetId, computesubnetIds := utils.GetSubnetIds(outputs)

	t.Run("RunCreateClusterWithDnsAndResolver", func(t *testing.T) {
		RunCreateClusterWithDnsAndResolver(t, vpcName, bastionsubnetId, computesubnetIds, instanceId, customResolverId)
	})

	t.Run("RunCreateClusterWithOnlyResolver", func(t *testing.T) {
		RunCreateClusterWithOnlyResolver(t, vpcName, bastionsubnetId, computesubnetIds, customResolverId)
	})

	// Test Result Evaluation
	if t.Failed() {
		testLogger.Error(t, fmt.Sprintf("Test %s failed - inspect validation logs", t.Name()))
	} else {
		testLogger.PASS(t, fmt.Sprintf("Test %s completed successfully", t.Name()))
	}
}

// RunCreateClusterWithDnsAndResolver with existing custom_resolver_id and dns_instance_id
func RunCreateClusterWithDnsAndResolver(t *testing.T, vpcName string, bastionsubnetId string, computesubnetIds string, instanceId string, customResolverId string) {

	// Set up the test suite and prepare the testing environment
	setupTestSuite(t)

	// Log the initiation of the cluster creation process
	testLogger.Info(t, "Cluster creation process initiated for RunCreateClusterWithDnsAndResolver")

	// Generate Unique Cluster Prefix
	clusterNamePrefix := utils.GenerateTimestampedClusterPrefix(utils.GenerateRandomString())
	testLogger.Info(t, fmt.Sprintf("Generated cluster prefix: %s", clusterNamePrefix))

	// Get and validate environment variables
	envVars, err := GetEnvVars()
	require.NoError(t, err, "Failed to get environment variables")

	// Set up the test options with the relevant parameters, including environment variables and resource group
	options, err := setupOptions(t, clusterNamePrefix, terraformDir, envVars.DefaultExistingResourceGroup)
	options.TerraformVars["vpc_name"] = vpcName
	options.TerraformVars["login_subnet_id"] = bastionsubnetId
	options.TerraformVars["compute_subnet_id"] = computesubnetIds
	options.TerraformVars["dns_instance_id"] = instanceId
	options.TerraformVars["dns_custom_resolver_id"] = customResolverId
	require.NoError(t, err, "Error setting up test options: %v", err)

	// Override default zones with existingvpc-specific region since default_region=false
	applyRegionOverrides(t, envVars, options, "existingvpc")

	// Skip test teardown for further inspection
	options.SkipTestTearDown = true
	defer options.TestTearDown()

	// Cluster Deployment
	deploymentStart := time.Now()
	testLogger.Info(t, fmt.Sprintf("Starting cluster deployment for test: %s", t.Name()))

	clusterCreationErr := lsf.VerifyClusterCreationAndConsistency(t, options, testLogger)
	if clusterCreationErr != nil {
		testLogger.Error(t, fmt.Sprintf("Cluster deployment failed after %v: %v", time.Since(deploymentStart), clusterCreationErr))
		require.NoError(t, clusterCreationErr, "Cluster creation failed")
	}
	testLogger.Info(t, fmt.Sprintf("Cluster deployment completed successfully (duration: %v)", time.Since(deploymentStart)))

	lsf.ValidateClusterConfiguration(t, options, testLogger)
	testLogger.Info(t, fmt.Sprintf("Finished execution: %s", t.Name()))

}

// RunCreateClusterWithOnlyResolver with existing custom_resolver_id and new dns_instance_id
func RunCreateClusterWithOnlyResolver(t *testing.T, vpcName string, bastionsubnetId string, computesubnetIds string, customResolverId string) {

	// Set up the test suite and prepare the testing environment
	setupTestSuite(t)

	// Log the initiation of the cluster creation process
	testLogger.Info(t, "Cluster creation process initiated for RunCreateClusterWithOnlyResolver")

	// Generate Unique Cluster Prefix
	clusterNamePrefix := utils.GenerateTimestampedClusterPrefix(utils.GenerateRandomString())
	testLogger.Info(t, fmt.Sprintf("Generated cluster prefix: %s", clusterNamePrefix))

	// Get and validate environment variables
	envVars, err := GetEnvVars()
	require.NoError(t, err, "Failed to get environment variables")

	// Set up the test options with the relevant parameters, including environment variables and resource group
	options, err := setupOptions(t, clusterNamePrefix, terraformDir, envVars.DefaultExistingResourceGroup)
	options.TerraformVars["vpc_name"] = vpcName
	options.TerraformVars["login_subnet_id"] = bastionsubnetId
	options.TerraformVars["compute_subnet_id"] = computesubnetIds
	options.TerraformVars["dns_custom_resolver_id"] = customResolverId
	require.NoError(t, err, "Error setting up test options: %v", err)

	// Override default zones with existingvpc-specific region since default_region=false
	applyRegionOverrides(t, envVars, options, "existingvpc")

	// Skip test teardown for further inspection
	options.SkipTestTearDown = true
	defer options.TestTearDown()

	// Cluster Deployment
	deploymentStart := time.Now()
	testLogger.Info(t, fmt.Sprintf("Starting cluster deployment for test: %s", t.Name()))

	clusterCreationErr := lsf.VerifyClusterCreationAndConsistency(t, options, testLogger)
	if clusterCreationErr != nil {
		testLogger.Error(t, fmt.Sprintf("Cluster deployment failed after %v: %v", time.Since(deploymentStart), clusterCreationErr))
		require.NoError(t, clusterCreationErr, "Cluster creation failed")
	}
	testLogger.Info(t, fmt.Sprintf("Cluster deployment completed successfully (duration: %v)", time.Since(deploymentStart)))

	lsf.ValidateClusterConfiguration(t, options, testLogger)
	testLogger.Info(t, fmt.Sprintf("Finished execution: %s", t.Name()))
}

// TestRunCreateVpcWithCustomDnsOnlyDNS creates a new VPC and uses custom DNS (DNS-only scenario)
func TestRunCreateVpcWithCustomDnsOnlyDNS(t *testing.T) {
	// Parallelize the test to run concurrently with others
	t.Parallel()

	// Set up the test suite and prepare the testing environment
	setupTestSuite(t)

	// Log the initiation of the cluster creation process
	testLogger.Info(t, "Cluster creation process initiated for "+t.Name())

	// Generate Unique Cluster Prefix
	clusterNamePrefix := utils.GenerateTimestampedClusterPrefix(utils.GenerateRandomString())
	testLogger.Info(t, fmt.Sprintf("Generated cluster prefix: %s", clusterNamePrefix))

	// Get and validate environment variables
	envVars, err := GetEnvVars()
	require.NoError(t, err, "Failed to get environment variables")

	// Set up the test options with the relevant parameters, including environment variables and resource group, set up test environment
	options, err := setupOptionsVPC(t, clusterNamePrefix, createVpcTerraformDir, envVars.DefaultExistingResourceGroup)
	options.TerraformVars["enable_hub"] = true
	options.TerraformVars["dns_zone_name"] = "hpc.local"
	require.NoError(t, err, "Error setting up test options: %v", err)

	// Override default zones with existingvpc-specific region since default_region=false
	applyRegionOverrides(t, envVars, options, "existingvpc")

	// Skip test teardown for further inspection
	options.SkipTestTearDown = true
	defer options.TestTearDown()

	// Cluster Deployment
	deploymentStart := time.Now()
	testLogger.Info(t, fmt.Sprintf("Starting cluster deployment for test: %s", t.Name()))
	output, err := options.RunTest()
	require.NoError(t, err, "Error running consistency test: %v", err)
	require.NotNil(t, output, "Expected non-nil output, but got nil")
	testLogger.Info(t, fmt.Sprintf("Cluster deployment completed (duration: %v)", time.Since(deploymentStart)))

	outputs := (options.LastTestTerraformOutputs)
	instanceId, _ := utils.GetDnsCustomResolverIds(outputs)

	RunCreateClusterWithOnlyDns(t, instanceId)

	// Test Result Evaluation
	if t.Failed() {
		testLogger.Error(t, fmt.Sprintf("Test %s failed - inspect validation logs", t.Name()))
	} else {
		testLogger.PASS(t, fmt.Sprintf("Test %s completed successfully", t.Name()))
	}
}

// RunCreateClusterWithOnlyDns creates a cluster using existing DNS instance (custom_resolver_id = null)
func RunCreateClusterWithOnlyDns(t *testing.T, instanceId string) {

	// Set up the test suite and prepare the testing environment
	setupTestSuite(t)

	// Log the initiation of the cluster creation process
	testLogger.Info(t, "Cluster creation process initiated for RunCreateClusterWithOnlyDns")

	// Generate Unique Cluster Prefix
	clusterNamePrefix := utils.GenerateTimestampedClusterPrefix(utils.GenerateRandomString())
	testLogger.Info(t, fmt.Sprintf("Generated cluster prefix: %s", clusterNamePrefix))

	// Get and validate environment variables
	envVars, err := GetEnvVars()
	require.NoError(t, err, "Failed to get environment variables")

	// Set up the test options with the relevant parameters, including environment variables and resource group
	options, err := setupOptions(t, clusterNamePrefix, terraformDir, envVars.DefaultExistingResourceGroup)
	options.TerraformVars["dns_instance_id"] = instanceId
	require.NoError(t, err, "Error setting up test options: %v", err)

	// Override default zones with existingvpc-specific region since default_region=false
	applyRegionOverrides(t, envVars, options, "existingvpc")

	// Skip test teardown for further inspection
	options.SkipTestTearDown = true
	defer options.TestTearDown()

	// Cluster Deployment
	deploymentStart := time.Now()
	testLogger.Info(t, fmt.Sprintf("Starting cluster deployment for test: %s", t.Name()))

	clusterCreationErr := lsf.VerifyClusterCreationAndConsistency(t, options, testLogger)
	if clusterCreationErr != nil {
		testLogger.Error(t, fmt.Sprintf("Cluster deployment failed after %v: %v", time.Since(deploymentStart), clusterCreationErr))
		require.NoError(t, clusterCreationErr, "Cluster creation failed")
	}
	testLogger.Info(t, fmt.Sprintf("Cluster deployment completed successfully (duration: %v)", time.Since(deploymentStart)))

	lsf.ValidateClusterConfiguration(t, options, testLogger)
	testLogger.Info(t, fmt.Sprintf("Finished execution: %s", t.Name()))
}
