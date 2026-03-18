package tests

import (
	"encoding/json"
	"fmt"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/stretchr/testify/require"
	lsf "github.com/terraform-ibm-modules/terraform-ibm-hpc/lsf"
	utils "github.com/terraform-ibm-modules/terraform-ibm-hpc/utilities"
)

// TestRunAppCenter validates cluster creation with Application Center enabled.
//   - Deploys the cluster with Application Center configuration
//   - Performs consistency checks during cluster creation
//   - Validates basic cluster configuration with Application Center
//   - Ensures resources are cleaned up after test execution
func TestRunAppCenter(t *testing.T) {
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
	require.NoError(t, err, "Failed to load environment configuration")

	options, err := setupOptions(t, clusterNamePrefix, terraformDir, envVars.DefaultExistingResourceGroup)
	require.NoError(t, err, "Failed to initialize test options")

	// Override default zones with appcenter-specific region since default_region=false
	applyRegionOverrides(t, envVars, options, "appcenter")

	// Set Appcenter
	options.TerraformVars["enable_appcenter"] = true

	// Configure Resource Cleanup
	options.SkipTestTearDown = true
	defer func() {
		testLogger.Info(t, "Final cleanup: destroying resources")
		options.TestTearDown()
	}()

	// Deploy Cluster
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

	// Post-deployment Validation
	t.Run("ValidateCluster", func(t *testing.T) {
		validationStart := time.Now()
		lsf.ValidateBasicClusterConfigurationWithAppcenter(t, options, testLogger)
		testLogger.Info(t, fmt.Sprintf("Validation completed (duration: %v)", time.Since(validationStart)))
	})
}

// TestRunAPI validates cluster API configuration with Application Center enabled.
//   - Deploys the cluster with Application Center configuration
//   - Performs consistency checks during cluster creation
//   - Validates cluster API endpoint configuration
//   - Ensures resources are cleaned up after test execution
func TestRunAPI(t *testing.T) {
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

	options, err := setupOptions(t, clusterNamePrefix, terraformDir, envVars.DefaultExistingResourceGroup)
	require.NoError(t, err, "Failed to initialize test options")

	// Override default zones with appcenter-specific region since default_region=false
	applyRegionOverrides(t, envVars, options, "appcenter")

	// Set Appcenter
	options.TerraformVars["enable_appcenter"] = true

	// Resource Cleanup Configuration
	options.SkipTestTearDown = true
	defer func() {
		testLogger.Info(t, "Final cleanup: destroying resources")
		options.TestTearDown()
	}()

	// Deploy Cluster
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

	// Post-deployment Validation
	t.Run("ValidateCluster", func(t *testing.T) {
		validationStart := time.Now()
		lsf.ValidateClusterAPIConfiguration(t, options, testLogger)
		testLogger.Info(t, fmt.Sprintf("Validation completed (duration: %v)", time.Since(validationStart)))
	})
}

// TestRunAppcenterAndLDAP validates cluster creation with LDAP and Application Center.
//   - Deploys the cluster with LDAP and Application Center enabled
//   - Performs consistency checks during cluster creation
//   - Validates LDAP user access and Application Center configuration
//   - Ensures resources are cleaned up after test execution
func TestRunAppcenterAndLDAP(t *testing.T) {
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
	require.NoError(t, err, "Failed to load environment configuration")

	// Validate LDAP Configuration
	require.Equal(t, "true", strings.ToLower(envVars.EnableLdap), "LDAP must be enabled for this test")
	require.NotEmpty(t, envVars.LdapAdminPassword, "LDAP admin password must be provided") // pragma: allowlist secret
	require.NotEmpty(t, envVars.LdapUserName, "LDAP username must be provided")
	require.NotEmpty(t, envVars.LdapUserPassword, "LDAP user password must be provided") // pragma: allowlist secret

	options, err := setupOptions(t, clusterNamePrefix, terraformDir, envVars.DefaultExistingResourceGroup)
	require.NoError(t, err, "Failed to initialize test options")

	// Override default zones with appcenter-specific region since default_region=false
	applyRegionOverrides(t, envVars, options, "appcenter")

	// Set Appcenter
	options.TerraformVars["enable_appcenter"] = true

	// Set LDAP Terraform Variables
	options.TerraformVars["enable_ldap"] = strings.ToLower(envVars.EnableLdap)
	options.TerraformVars["ldap_basedns"] = envVars.LdapBaseDns
	options.TerraformVars["ldap_admin_password"] = envVars.LdapAdminPassword // pragma: allowlist secret
	options.TerraformVars["ldap_user_name"] = envVars.LdapUserName
	options.TerraformVars["ldap_user_password"] = envVars.LdapUserPassword // pragma: allowlist secret

	// Configure Resource Cleanup
	options.SkipTestTearDown = true
	defer func() {
		testLogger.Info(t, "Final cleanup: destroying resources")
		options.TestTearDown()
	}()

	// Deploy Cluster
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

	// Post-deployment Validation
	t.Run("ValidateCluster", func(t *testing.T) {
		validationStart := time.Now()
		lsf.ValidateLDAPClusterConfigurationWithAppcenter(t, options, testLogger)
		testLogger.Info(t, fmt.Sprintf("Validation completed (duration: %v)", time.Since(validationStart)))
	})
}

// TestRunLDAP validates cluster creation with LDAP authentication enabled.
// Verifies proper LDAP configuration and user authentication functionality.
//
// Prerequisites:
//   - LDAP enabled in environment configuration
//   - Valid LDAP credentials (admin password, username, user password)
//   - Proper test suite initialization
func TestRunLDAP(t *testing.T) {
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
	require.NoError(t, err, "Failed to load environment configuration")

	// Validate LDAP Configuration
	require.Equal(t, "true", strings.ToLower(envVars.EnableLdap), "LDAP must be enabled for this test")
	require.NotEmpty(t, envVars.LdapAdminPassword, "LDAP admin password must be provided") // pragma: allowlist secret
	require.NotEmpty(t, envVars.LdapUserName, "LDAP username must be provided")
	require.NotEmpty(t, envVars.LdapUserPassword, "LDAP user password must be provided") // pragma: allowlist secret

	options, err := setupOptions(t, clusterNamePrefix, terraformDir, envVars.DefaultExistingResourceGroup)
	require.NoError(t, err, "Failed to initialize test options")

	// Override default zones with appcenter-specific region since default_region=false
	applyRegionOverrides(t, envVars, options, "appcenter")

	// Set LDAP Terraform Variables
	options.TerraformVars["enable_ldap"] = strings.ToLower(envVars.EnableLdap)
	options.TerraformVars["ldap_basedns"] = envVars.LdapBaseDns
	options.TerraformVars["ldap_admin_password"] = envVars.LdapAdminPassword // pragma: allowlist secret
	options.TerraformVars["ldap_user_name"] = envVars.LdapUserName
	options.TerraformVars["ldap_user_password"] = envVars.LdapUserPassword // pragma: allowlist secret

	// Configure Resource Cleanup
	options.SkipTestTearDown = true
	defer func() {
		testLogger.Info(t, "Final cleanup: destroying resources")
		options.TestTearDown()
	}()

	// Deploy Cluster
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

	// Post-deployment Validation
	t.Run("ValidateCluster", func(t *testing.T) {
		validationStart := time.Now()
		lsf.ValidateLDAPClusterConfiguration(t, options, testLogger)
		testLogger.Info(t, fmt.Sprintf("Validation completed (duration: %v)", time.Since(validationStart)))
	})
}

// TestRunExistingLDAP validates cluster creation with existing LDAP integration.
// Verifies proper configuration of LDAP authentication with an existing LDAP server.
//
// Prerequisites:
//   - LDAP enabled in environment configuration
//   - Valid LDAP credentials
//   - Existing LDAP server configuration
//   - Proper test suite initialization
func TestRunExistingLDAP(t *testing.T) {
	t.Parallel()

	// Initialization and Setup
	setupTestSuite(t)
	require.NotNil(t, testLogger, "Test logger must be initialized")
	defer logResult(t)
	testLogger.Info(t, fmt.Sprintf("Test %s initiated", t.Name()))

	// Generate Unique Cluster Prefix
	clusterNamePrefix := utils.GenerateTimestampedClusterPrefix(utils.GenerateRandomString())
	testLogger.Info(t, fmt.Sprintf("Generated cluster prefix: %s", clusterNamePrefix))

	// Environment Configuration
	envVars, err := GetEnvVars()
	require.NoError(t, err, "Failed to load environment configuration")

	// LDAP Validation
	require.Equal(t, "true", strings.ToLower(envVars.EnableLdap), "LDAP must be enabled for this test")
	require.NotEmpty(t, envVars.LdapAdminPassword, "LDAP admin password must be provided") // pragma: allowlist secret
	require.NotEmpty(t, envVars.LdapUserName, "LDAP username must be provided")
	require.NotEmpty(t, envVars.LdapUserPassword, "LDAP user password must be provided") // pragma: allowlist secret

	// First Cluster Configuration
	options1, err := setupOptions(t, clusterNamePrefix, terraformDir, envVars.DefaultExistingResourceGroup)
	require.NoError(t, err, "Failed to initialize test options")

	// Override default zones with appcenter-specific region since default_region=false
	applyRegionOverrides(t, envVars, options1, "appcenter")

	// First Cluster LDAP Configuration
	options1.TerraformVars["enable_ldap"] = strings.ToLower(envVars.EnableLdap)
	options1.TerraformVars["ldap_basedns"] = envVars.LdapBaseDns
	options1.TerraformVars["ldap_admin_password"] = envVars.LdapAdminPassword // pragma: allowlist secret
	options1.TerraformVars["ldap_user_name"] = envVars.LdapUserName
	options1.TerraformVars["ldap_user_password"] = envVars.LdapUserPassword // pragma: allowlist secret

	// First Cluster Cleanup
	options1.SkipTestTearDown = true
	defer func() {
		testLogger.Info(t, "Final cleanup: destroying first cluster resources")
		options1.TestTearDown()
	}()

	// Deploy First Cluster
	// DeployFirstCluster and SetupSecondCluster subtests are intentionally sequential.
	// Neither calls t.Parallel(), so t.Run blocks until each subtest completes
	// before the parent resumes. Do not add t.Parallel() to either subtest.
	t.Run("DeployFirstCluster", func(t *testing.T) {
		deploymentStart := time.Now()
		testLogger.Info(t, fmt.Sprintf("Starting first cluster deployment for test: %s", t.Name()))

		output, err := options1.RunTest()
		require.NoError(t, err, "First cluster validation failed")
		require.NotNil(t, output, "First cluster validation returned nil output")

		testLogger.Info(t, fmt.Sprintf("First cluster deployment completed successfully (duration: %v)", time.Since(deploymentStart)))
	})

	// Abort the parent test immediately if DeployFirstCluster failed.
	// Using require.False ensures the overall test is marked as FAILED (not skipped),
	// so CI pipelines correctly surface deployment failures.
	require.False(t, t.Failed(), "DeployFirstCluster failed — aborting test, skipping SetupSecondCluster")

	// Setup and Deploy Second Cluster
	t.Run("SetupSecondCluster", func(t *testing.T) {

		// Retrieve Custom Resolver ID
		customResolverID, err := utils.GetCustomResolverID(t, os.Getenv("TF_VAR_ibmcloud_api_key"), utils.GetRegion(envVars.Zones), envVars.DefaultExistingResourceGroup, clusterNamePrefix, testLogger)
		require.NoError(t, err, "Error retrieving custom resolver ID: %v", err)

		// Retrieve LDAP IP and Bastion IP
		ldapIP, err := utils.GetLdapIP(t, options1, testLogger)
		require.NoError(t, err, "Error retrieving LDAP IP address: %v", err)

		ldapServerBastionIP, err := utils.GetBastionIP(t, options1, testLogger)
		require.NoError(t, err, "Error retrieving LDAP server bastion IP address: %v", err)

		serverCertErr := utils.RetrieveAndUpdateSecurityGroup(t, os.Getenv("TF_VAR_ibmcloud_api_key"), utils.GetRegion(envVars.Zones), envVars.DefaultExistingResourceGroup, clusterNamePrefix, "10.241.0.0/18", "389", "389", testLogger)
		require.NoError(t, serverCertErr, "Failed to retrieve LDAP server certificate via SSH")

		// Second Cluster Configuration
		hpcClusterPrefix2 := utils.GenerateTimestampedClusterPrefix(utils.GenerateRandomString())
		testLogger.Info(t, fmt.Sprintf("Generated cluster prefix: %s", hpcClusterPrefix2))

		options2, err := setupOptions(t, hpcClusterPrefix2, terraformDir, envVars.DefaultExistingResourceGroup)
		require.NoError(t, err, "Error setting up test options for the second cluster: %v", err)

		// Override default zones with appcenter-specific region since default_region=false
		applyRegionOverrides(t, envVars, options2, "appcenter")

		// LDAP Certificate Retrieval
		ldapServerCert, serverCertErr := lsf.GetLDAPServerCert(lsf.LSF_PUBLIC_HOST_NAME, ldapServerBastionIP, lsf.LSF_LDAP_HOST_NAME, ldapIP)
		require.NoError(t, serverCertErr, "Must retrieve LDAP server certificate")
		testLogger.Info(t, fmt.Sprintf("LDAP server certificate: %s", strings.TrimSpace(ldapServerCert)))

		// Second Cluster LDAP Configuration
		options2.TerraformVars["vpc_name"] = options1.TerraformVars["cluster_prefix"].(string) + "-lsf"
		options2.TerraformVars["vpc_cluster_private_subnets_cidr_blocks"] = CLUSTER_TWO_VPC_CLUSTER_PRIVATE_SUBNETS_CIDR_BLOCKS
		options2.TerraformVars["vpc_cluster_login_private_subnets_cidr_blocks"] = CLUSTER_TWO_VPC_CLUSTER_LOGIN_PRIVATE_SUBNETS_CIDR_BLOCKS
		dnsMap := map[string]string{
			"compute": "comp2.com",
		}
		dnsJSON, err := json.Marshal(dnsMap)
		require.NoError(t, err, "Failed to marshal DNS domain name map to JSON")

		options2.TerraformVars["dns_domain_name"] = string(dnsJSON)
		options2.TerraformVars["dns_custom_resolver_id"] = customResolverID
		options2.TerraformVars["enable_ldap"] = strings.ToLower(envVars.EnableLdap)
		options2.TerraformVars["ldap_basedns"] = envVars.LdapBaseDns
		options2.TerraformVars["ldap_server"] = ldapIP
		options2.TerraformVars["ldap_server_cert"] = strings.TrimSpace(ldapServerCert)

		// Second Cluster Cleanup
		options2.SkipTestTearDown = true
		defer func() {
			testLogger.Info(t, "Final cleanup: destroying second cluster resources")
			options2.TestTearDown()
		}()

		// Deploy Second Cluster
		// DeploySecondCluster and ValidateSecondCluster subtests are intentionally sequential.
		// Neither calls t.Parallel(), so t.Run blocks until each subtest completes
		// before the parent resumes. Do not add t.Parallel() to either subtest.
		t.Run("DeploySecondCluster", func(t *testing.T) {
			deploymentStart := time.Now()
			testLogger.Info(t, fmt.Sprintf("Starting second cluster deployment for test: %s", t.Name()))

			clusterCreationErr := lsf.VerifyClusterCreationAndConsistency(t, options2, testLogger)
			require.NoError(t, clusterCreationErr, "Second cluster creation failed")

			testLogger.Info(t, fmt.Sprintf("Second cluster deployment completed (duration: %v)", time.Since(deploymentStart)))
		})

		// Abort the parent test immediately if DeploySecondCluster failed.
		// Using require.False ensures the overall test is marked as FAILED (not skipped),
		// so CI pipelines correctly surface deployment failures.
		require.False(t, t.Failed(), "DeploySecondCluster failed — aborting test, skipping ValidateSecondCluster")

		// Post-deployment Validation
		t.Run("ValidateSecondCluster", func(t *testing.T) {
			validationStart := time.Now()
			testLogger.Info(t, "Starting existing LDAP validation for second cluster")

			lsf.ValidateExistingLDAPClusterConfig(t, ldapServerBastionIP, ldapIP, envVars.LdapBaseDns, envVars.LdapAdminPassword, envVars.LdapUserName, envVars.LdapUserPassword, options2, testLogger)

			testLogger.Info(t, fmt.Sprintf("Validation completed (duration: %v)", time.Since(validationStart)))
		})
	})
}
