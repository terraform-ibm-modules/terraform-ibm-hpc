package tests

import (
	"encoding/json"
	"fmt"
	"os"
	"strings"
	"testing"

	"github.com/stretchr/testify/require"
	lsf "github.com/terraform-ibm-modules/terraform-ibm-hpc/lsf"
	utils "github.com/terraform-ibm-modules/terraform-ibm-hpc/utilities"
)

// TestAppCenterWithAPI validates cluster creation with Application Center enabled.
//   - Deploys the cluster with Application Center configuration
//   - Performs consistency checks during cluster creation
//   - Validates basic cluster configuration with Application Center
//   - Ensures resources are cleaned up after test execution
//   - Validates cluster API endpoint configuration
func TestAppCenterWithAPI(t *testing.T) {
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

	// Override default zones with appcenter-specific region (default_region=false).
	applyRegionOverrides(t, envVars, options, "appcenter")
	testLogger.Info(t, "Region overrides applied for appcenter cluster configuration")

	options.TerraformVars["enable_appcenter"] = true
	testLogger.Info(t, "Application Center enabled")

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
	utils.DeployCluster(t, options, testLogger)

	// ── 5. Validation ────────────────────────────────────────────────────────
	utils.RunValidateCluster(t, testLogger, func(t *testing.T) {
		lsf.ValidateBasicClusterConfigurationWithAppcenter(t, options, testLogger)
	})
}

// TestLDAPAppCenterIntegration validates cluster creation with LDAP and Application Center.
//   - Deploys the cluster with LDAP and Application Center enabled
//   - Performs consistency checks during cluster creation
//   - Validates LDAP user access and Application Center configuration
//   - Ensures resources are cleaned up after test execution
func TestLDAPAppCenterIntegration(t *testing.T) {
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

	// Validate required LDAP credentials before proceeding.
	require.Equal(t, "true", strings.ToLower(envVars.EnableLdap), "LDAP must be enabled for this test")
	require.NotEmpty(t, envVars.LdapAdminPassword, "LDAP admin password must be provided") // pragma: allowlist secret
	require.NotEmpty(t, envVars.LdapUserName, "LDAP username must be provided")
	require.NotEmpty(t, envVars.LdapUserPassword, "LDAP user password must be provided") // pragma: allowlist secret
	testLogger.Info(t, "LDAP credentials validated successfully")

	options, err := setupOptions(t, clusterNamePrefix, terraformDir, envVars.DefaultExistingResourceGroup)
	utils.NoError(t, err, "Failed to initialize test options", testLogger)
	testLogger.Info(t, "Test options initialized successfully")

	// Override default zones with appcenter-specific region (default_region=false).
	applyRegionOverrides(t, envVars, options, "appcenter")
	testLogger.Info(t, "Region overrides applied for appcenter cluster configuration")

	options.TerraformVars["enable_appcenter"] = true
	options.TerraformVars["enable_ldap"] = strings.ToLower(envVars.EnableLdap)
	options.TerraformVars["ldap_basedns"] = envVars.LdapBaseDns
	options.TerraformVars["ldap_admin_password"] = envVars.LdapAdminPassword // pragma: allowlist secret
	options.TerraformVars["ldap_user_name"] = envVars.LdapUserName
	options.TerraformVars["ldap_user_password"] = envVars.LdapUserPassword // pragma: allowlist secret
	testLogger.Info(t, "Application Center and LDAP Terraform variables configured")

	// ── 3. Teardown ──────────────────────────────────────────────────────────
	options.SkipTestTearDown = true
	defer func() {
		testLogger.Info(t, "Initiating final resource teardown...")
		options.TestTearDown()
		testLogger.Info(t, "Resource teardown completed")
	}()

	// ── 4. Deployment ────────────────────────────────────────────────────────
	utils.DeployCluster(t, options, testLogger)

	// ── 5. Validation ────────────────────────────────────────────────────────
	utils.RunValidateCluster(t, testLogger, func(t *testing.T) {
		lsf.ValidateLDAPClusterConfigurationWithAppcenter(t, options, testLogger)
	})
}

// TestLDAPNewServer validates cluster creation with LDAP authentication enabled.
// Verifies proper LDAP configuration and user authentication functionality.
//
// Prerequisites:
//   - LDAP enabled in environment configuration
//   - Valid LDAP credentials (admin password, username, user password)
//   - Proper test suite initialization
func TestLDAPNewServer(t *testing.T) {
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

	// Validate required LDAP credentials before proceeding.
	require.Equal(t, "true", strings.ToLower(envVars.EnableLdap), "LDAP must be enabled for this test")
	require.NotEmpty(t, envVars.LdapAdminPassword, "LDAP admin password must be provided") // pragma: allowlist secret
	require.NotEmpty(t, envVars.LdapUserName, "LDAP username must be provided")
	require.NotEmpty(t, envVars.LdapUserPassword, "LDAP user password must be provided") // pragma: allowlist secret
	testLogger.Info(t, "LDAP credentials validated successfully")

	options, err := setupOptions(t, clusterNamePrefix, terraformDir, envVars.DefaultExistingResourceGroup)
	utils.NoError(t, err, "Failed to initialize test options", testLogger)
	testLogger.Info(t, "Test options initialized successfully")

	// Override default zones with appcenter-specific region (default_region=false).
	applyRegionOverrides(t, envVars, options, "appcenter")
	testLogger.Info(t, "Region overrides applied for appcenter cluster configuration")

	options.TerraformVars["enable_ldap"] = strings.ToLower(envVars.EnableLdap)
	options.TerraformVars["ldap_basedns"] = envVars.LdapBaseDns
	options.TerraformVars["ldap_admin_password"] = envVars.LdapAdminPassword // pragma: allowlist secret
	options.TerraformVars["ldap_user_name"] = envVars.LdapUserName
	options.TerraformVars["ldap_user_password"] = envVars.LdapUserPassword // pragma: allowlist secret
	testLogger.Info(t, "LDAP Terraform variables configured")

	// ── 3. Teardown ──────────────────────────────────────────────────────────
	options.SkipTestTearDown = true
	defer func() {
		testLogger.Info(t, "Initiating final resource teardown...")
		options.TestTearDown()
		testLogger.Info(t, "Resource teardown completed")
	}()

	// ── 4. Deployment ────────────────────────────────────────────────────────
	utils.DeployCluster(t, options, testLogger)

	// ── 5. Validation ────────────────────────────────────────────────────────
	utils.RunValidateCluster(t, testLogger, func(t *testing.T) {
		lsf.ValidateLDAPClusterConfiguration(t, options, testLogger)
	})
}

// TestLDAPExistingServer validates cluster creation with existing LDAP integration.
// Verifies proper configuration of LDAP authentication with an existing LDAP server.
//
// Prerequisites:
//   - LDAP enabled in environment configuration
//   - Valid LDAP credentials
//   - Existing LDAP server configuration
//   - Proper test suite initialization
func TestLDAPExistingServer(t *testing.T) {
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

	// Validate required LDAP credentials before proceeding.
	require.Equal(t, "true", strings.ToLower(envVars.EnableLdap), "LDAP must be enabled for this test")
	require.NotEmpty(t, envVars.LdapAdminPassword, "LDAP admin password must be provided") // pragma: allowlist secret
	require.NotEmpty(t, envVars.LdapUserName, "LDAP username must be provided")
	require.NotEmpty(t, envVars.LdapUserPassword, "LDAP user password must be provided") // pragma: allowlist secret
	testLogger.Info(t, "LDAP credentials validated successfully")

	// ── 3. First Cluster Configuration ───────────────────────────────────────
	options1, err := setupOptions(t, clusterNamePrefix, terraformDir, envVars.DefaultExistingResourceGroup)
	utils.NoError(t, err, "Failed to initialize first cluster test options", testLogger)
	testLogger.Info(t, "First cluster test options initialized successfully")

	// Override default zones with appcenter-specific region (default_region=false).
	applyRegionOverrides(t, envVars, options1, "appcenter")
	testLogger.Info(t, "Region overrides applied for first cluster")

	options1.TerraformVars["enable_ldap"] = strings.ToLower(envVars.EnableLdap)
	options1.TerraformVars["ldap_basedns"] = envVars.LdapBaseDns
	options1.TerraformVars["ldap_admin_password"] = envVars.LdapAdminPassword // pragma: allowlist secret
	options1.TerraformVars["ldap_user_name"] = envVars.LdapUserName
	options1.TerraformVars["ldap_user_password"] = envVars.LdapUserPassword // pragma: allowlist secret
	testLogger.Info(t, "First cluster LDAP Terraform variables configured")

	// ── 4. First Cluster Teardown ─────────────────────────────────────────────
	options1.SkipTestTearDown = true
	defer func() {
		testLogger.Info(t, "Initiating teardown of first cluster resources...")
		options1.TestTearDown()
		testLogger.Info(t, "First cluster teardown completed")
	}()

	// ── 5. Deployment ────────────────────────────────────────────────────────
	utils.DeployCluster(t, options1, testLogger)

	// ── 6. Second Cluster Setup & Validation ─────────────────────────────────
	t.Run("SetupSecondCluster", func(t *testing.T) {
		t.Helper()
		testLogger.Info(t, fmt.Sprintf("[START] Second cluster setup for test: %s", t.Name()))

		// Retrieve networking details from first cluster.
		customResolverID, err := utils.GetCustomResolverID(t, os.Getenv("TF_VAR_ibmcloud_api_key"), utils.GetRegion(envVars.Zones), envVars.DefaultExistingResourceGroup, clusterNamePrefix, testLogger)
		utils.NoError(t, err, fmt.Sprintf("Failed to retrieve custom resolver ID: %v", err), testLogger)
		testLogger.Info(t, fmt.Sprintf("Custom resolver ID retrieved: %s", customResolverID))

		ldapIP, err := utils.GetLdapIP(t, options1, testLogger)
		utils.NoError(t, err, fmt.Sprintf("Failed to retrieve LDAP IP address: %v", err), testLogger)
		testLogger.Info(t, fmt.Sprintf("LDAP IP address retrieved: %s", ldapIP))

		ldapServerBastionIP, err := utils.GetBastionIP(t, options1, testLogger)
		utils.NoError(t, err, fmt.Sprintf("Failed to retrieve LDAP server bastion IP address: %v", err), testLogger)
		testLogger.Info(t, fmt.Sprintf("LDAP server bastion IP retrieved: %s", ldapServerBastionIP))

		// err = utils.RetrieveAndUpdateSecurityGroup(t, os.Getenv("TF_VAR_ibmcloud_api_key"), utils.GetRegion(envVars.Zones), envVars.DefaultExistingResourceGroup, clusterNamePrefix, "10.241.0.0/18", "389", "389", testLogger)
		// utils.NoError(t, err, "Failed to update security group for LDAP access", testLogger)
		// testLogger.Info(t, "Security group updated for LDAP access")

		// Generate second cluster prefix and options.
		hpcClusterPrefix2 := utils.GenerateTimestampedClusterPrefix(utils.GenerateRandomString())
		testLogger.Info(t, fmt.Sprintf("Generated second cluster name prefix: %s", hpcClusterPrefix2))

		options2, err := setupOptions(t, hpcClusterPrefix2, terraformDir, envVars.DefaultExistingResourceGroup)
		utils.NoError(t, err, fmt.Sprintf("Failed to initialize second cluster test options: %v", err), testLogger)
		testLogger.Info(t, "Second cluster test options initialized successfully")

		// Override default zones with appcenter-specific region (default_region=false).
		applyRegionOverrides(t, envVars, options2, "appcenter")
		testLogger.Info(t, "Region overrides applied for second cluster")

		// Retrieve LDAP server certificate from first cluster.
		ldapServerCert, err := lsf.GetLDAPServerCert(lsf.LSF_PUBLIC_HOST_NAME, ldapServerBastionIP, lsf.LSF_LDAP_HOST_NAME, ldapIP)
		utils.NoError(t, err, "Failed to retrieve LDAP server certificate", testLogger)
		testLogger.Info(t, fmt.Sprintf("LDAP server certificate retrieved successfully: %s", strings.TrimSpace(ldapServerCert)))

		// Configure second cluster to connect to first cluster's LDAP server.
		options2.TerraformVars["vpc_name"] = options1.TerraformVars["cluster_prefix"].(string) + "-lsf"
		options2.TerraformVars["vpc_cluster_private_subnets_cidr_blocks"] = CLUSTER_TWO_VPC_CLUSTER_PRIVATE_SUBNETS_CIDR_BLOCKS
		options2.TerraformVars["vpc_cluster_login_private_subnets_cidr_blocks"] = CLUSTER_TWO_VPC_CLUSTER_LOGIN_PRIVATE_SUBNETS_CIDR_BLOCKS

		dnsMap := map[string]string{"compute": "comp2.com"}
		dnsJSON, err := json.Marshal(dnsMap)
		utils.NoError(t, err, "Failed to marshal DNS domain name map to JSON", testLogger)

		options2.TerraformVars["dns_domain_name"] = string(dnsJSON)
		options2.TerraformVars["dns_custom_resolver_id"] = customResolverID
		options2.TerraformVars["enable_ldap"] = strings.ToLower(envVars.EnableLdap)
		options2.TerraformVars["ldap_basedns"] = envVars.LdapBaseDns
		options2.TerraformVars["ldap_server"] = ldapIP
		options2.TerraformVars["ldap_server_cert"] = strings.TrimSpace(ldapServerCert)
		testLogger.Info(t, "Second cluster LDAP and networking Terraform variables configured")

		// Second cluster teardown.
		options2.SkipTestTearDown = true
		defer func() {
			testLogger.Info(t, "Initiating teardown of second cluster resources...")
			options2.TestTearDown()
			testLogger.Info(t, "Second cluster teardown completed")
		}()

		// ── 6a. Deployment ───────────────────────────────────────────────────
		utils.DeployCluster(t, options2, testLogger)

		// ── 6b. Validation ───────────────────────────────────────────────────
		utils.RunValidateCluster(t, testLogger, func(t *testing.T) {
			lsf.ValidateExistingLDAPClusterConfig(t, ldapServerBastionIP, ldapIP, envVars.LdapBaseDns, envVars.LdapAdminPassword, envVars.LdapUserName, envVars.LdapUserPassword, options2, testLogger)
		})
	})
}
