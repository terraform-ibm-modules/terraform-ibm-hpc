package tests

import (
	"fmt"
	"path/filepath"
	"strings"
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	utils "github.com/terraform-ibm-modules/terraform-ibm-hpc/utilities"
)

const (
	lsfSolutionPath     = "solutions/lsf"
	testPathPrefix      = "tests/lsf_tests/"
	invalidLDAPServerIP = "10.10.10.10"
	invalidSubnetCIDR1  = "1.1.1.1/20"
	invalidSubnetCIDR2  = "2.2.2.2/20"
	invalidSubnetCIDR3  = "3.3.3.3/20"
	invalidKMSKeyName   = "sample-key"
	invalidKMSInstance  = "sample-ins"
)

// getTerraformDirPath returns the absolute path to the LSF solution directory
func getTerraformDirPath(t *testing.T) string {
	absPath, err := filepath.Abs(lsfSolutionPath)
	require.NoError(t, err, "Failed to get absolute path for LSF solution")
	return strings.ReplaceAll(absPath, testPathPrefix, "")
}

// getBaseVars returns common variables for tests
func getBaseVars(t *testing.T) map[string]interface{} {
	envVars, err := GetEnvVars()
	require.NoError(t, err, "Failed to get environment variables")
	return map[string]interface{}{
		"cluster_prefix":          utils.GenerateTimestampedClusterPrefix(utils.GenerateRandomString()),
		"ssh_keys":                utils.SplitAndTrim(envVars.SSHKeys, ","),
		"zones":                   utils.SplitAndTrim(envVars.Zones, ","),
		"remote_allowed_ips":      utils.SplitAndTrim(envVars.RemoteAllowedIPs, ","),
		"app_center_gui_password": APP_CENTER_GUI_PASSWORD, // pragma: allowlist secret
	}
}

// TestInvalidRunLSFWithoutMandatory tests Terraform's behavior when mandatory variables are missing
func TestInvalidRunLSFWithoutMandatory(t *testing.T) {
	t.Parallel()

	setupTestSuite(t)
	testLogger.Info(t, "Cluster creation process initiated for "+t.Name())

	terraformDirPath := getTerraformDirPath(t)

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: terraformDirPath,
		Vars:         map[string]interface{}{},
	})

	UpgradeTerraformOnce(t, terraformOptions)

	_, err := terraform.PlanE(t, terraformOptions)
	require.Error(t, err, "Expected an error during plan")

	validationPassed := utils.VerifyDataContains(t, err.Error(), "remote_allowed_ips", testLogger)
	assert.True(t, validationPassed, "Should fail with missing mandatory variables")
	testLogger.LogValidationResult(t, validationPassed, "Missing mandatory variables validation")
}

// TestInvalidEmptyIbmcloudApiKey validates cluster creation with empty IBM Cloud API key
func TestInvalidEmptyIbmcloudApiKey(t *testing.T) {
	t.Parallel()

	setupTestSuite(t)
	testLogger.Info(t, "Cluster creation process initiated for "+t.Name())

	// Get base Terraform variables
	terraformVars := getBaseVars(t)
	testLogger.Info(t, fmt.Sprintf("Generated cluster prefix: %s", terraformVars["cluster_prefix"]))
	terraformVars["ibmcloud_api_key"] = "" // Empty API key //pragma: allowlist secret

	terraformDirPath := getTerraformDirPath(t)
	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: terraformDirPath,
		Vars:         terraformVars,
	})

	UpgradeTerraformOnce(t, terraformOptions)
	_, err := terraform.PlanE(t, terraformOptions)

	require.Error(t, err, "Expected an error during plan")
	validationPassed := utils.VerifyDataContains(t, err.Error(), "The API key for IBM Cloud must be set", testLogger)
	assert.True(t, validationPassed, "Should fail with empty API key error")
	testLogger.LogValidationResult(t, validationPassed, "Empty IBM Cloud API key validation")
}

// TestInvalidLsfVersion validates cluster creation with invalid LSF version
func TestInvalidLsfVersion(t *testing.T) {
	t.Parallel()

	setupTestSuite(t)
	testLogger.Info(t, "Cluster creation process initiated for "+t.Name())

	// Get base Terraform variables
	terraformVars := getBaseVars(t)
	testLogger.Info(t, fmt.Sprintf("Generated cluster prefix: %s", terraformVars["cluster_prefix"]))
	terraformVars["lsf_version"] = "invalid_version" // Invalid LSF version

	terraformDirPath := getTerraformDirPath(t)
	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: terraformDirPath,
		Vars:         terraformVars,
	})

	UpgradeTerraformOnce(t, terraformOptions)
	_, err := terraform.PlanE(t, terraformOptions)

	require.Error(t, err, "Expected an error during plan")
	validationPassed := utils.VerifyDataContains(t, err.Error(), "Invalid LSF version. Allowed values are 'fixpack_14' and 'fixpack_15'", testLogger)
	assert.True(t, validationPassed, "Should fail with invalid LSF version error")
	testLogger.LogValidationResult(t, validationPassed, "Invalid LSF version validation")
}

// TestInvalidAppCenterPassword validates cluster creation with invalid App Center password
// TestInvalidAppCenterPassword validates cluster creation with invalid App Center password
func TestInvalidAppCenterPassword(t *testing.T) {
	t.Parallel()

	invalidPasswords := []string{
		"weak",                          // Too short
		"PasswoRD123",                   // Contains dictionary word // pragma: allowlist secret
		"password123",                   // All lowercase            // pragma: allowlist secret
		"Password@",                     // Missing numbers          // pragma: allowlist secret
		"Password123",                   // Common password pattern   // pragma: allowlist secret
		"password@12345678901234567890", // Too long                   // pragma: allowlist secret
		"ValidPass123\\",                //Backslash not in allowed special chars  // pragma: allowlist secret
		"Pass word@1",                   //Contains space       // pragma: allowlist secret
	}

	setupTestSuite(t)
	testLogger.Info(t, "Cluster creation process initiated for "+t.Name())

	for _, password := range invalidPasswords { // pragma: allowlist secret
		password := password                 // create local copy for parallel tests    // pragma: allowlist secret
		t.Run(password, func(t *testing.T) { // pragma: allowlist secret
			t.Parallel()

			// Get base Terraform variables
			terraformVars := getBaseVars(t)
			testLogger.Info(t, fmt.Sprintf("Generated cluster prefix: %s", terraformVars["cluster_prefix"]))
			terraformVars["app_center_gui_password"] = password // Invalid password    // pragma: allowlist secret

			terraformDirPath := getTerraformDirPath(t)
			terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
				TerraformDir: terraformDirPath,
				Vars:         terraformVars,
			})

			UpgradeTerraformOnce(t, terraformOptions)
			_, err := terraform.PlanE(t, terraformOptions)

			require.Error(t, err, "Expected an error during plan")
			validationPassed := utils.VerifyDataContains(t, err.Error(), "The password must be at least 8 characters long", testLogger) // pragma: allowlist secret
			assert.True(t, validationPassed, "Should fail with invalid password error")                                                 // pragma: allowlist secret
			testLogger.LogValidationResult(t, validationPassed, "Invalid App Center password validation")                               // pragma: allowlist secret
		})
	}
}

// TestInvalidMultipleZones validates cluster creation with multiple zones
func TestInvalidMultipleZones(t *testing.T) {
	t.Parallel()

	setupTestSuite(t)
	testLogger.Info(t, "Cluster creation process initiated for "+t.Name())

	// Get base Terraform variables
	terraformVars := getBaseVars(t)
	testLogger.Info(t, fmt.Sprintf("Generated cluster prefix: %s", terraformVars["cluster_prefix"]))
	terraformVars["zones"] = []string{"us-east-1", "us-east-2"} // Multiple zones

	terraformDirPath := getTerraformDirPath(t)
	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: terraformDirPath,
		Vars:         terraformVars,
	})

	UpgradeTerraformOnce(t, terraformOptions)
	_, err := terraform.PlanE(t, terraformOptions)

	require.Error(t, err, "Expected an error during plan")
	validationPassed := utils.VerifyDataContains(t, err.Error(), "HPC product deployment supports only a single zone", testLogger)
	assert.True(t, validationPassed, "Should fail with multiple zones error")
	testLogger.LogValidationResult(t, validationPassed, "Multiple zones validation")
}

// TestInvalidClusterPrefix validates cluster creation with invalid cluster prefix
func TestInvalidClusterPrefix(t *testing.T) {
	t.Parallel()

	setupTestSuite(t)
	testLogger.Info(t, "Cluster creation process initiated for "+t.Name())

	// Get base Terraform variables
	terraformVars := getBaseVars(t)
	testLogger.Info(t, fmt.Sprintf("Generated cluster prefix: %s", terraformVars["cluster_prefix"]))
	terraformVars["cluster_prefix"] = "--invalid-prefix--" // Invalid prefix

	terraformDirPath := getTerraformDirPath(t)
	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: terraformDirPath,
		Vars:         terraformVars,
	})

	UpgradeTerraformOnce(t, terraformOptions)
	_, err := terraform.PlanE(t, terraformOptions)

	require.Error(t, err, "Expected an error during plan")
	validationPassed := utils.VerifyDataContains(t, err.Error(), "Prefix must start with a lowercase letter", testLogger)
	assert.True(t, validationPassed, "Should fail with invalid prefix error")
	testLogger.LogValidationResult(t, validationPassed, "Invalid cluster prefix validation")
}

// TestInvalidResourceGroup validates cluster creation with null resource group
func TestInvalidResourceGroup(t *testing.T) {
	t.Parallel()

	setupTestSuite(t)
	testLogger.Info(t, "Cluster creation process initiated for "+t.Name())

	// Get base Terraform variables
	terraformVars := getBaseVars(t)
	testLogger.Info(t, fmt.Sprintf("Generated cluster prefix: %s", terraformVars["cluster_prefix"]))
	terraformVars["existing_resource_group"] = "Invalid" // Invalid resource group

	terraformDirPath := getTerraformDirPath(t)
	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: terraformDirPath,
		Vars:         terraformVars,
	})

	UpgradeTerraformOnce(t, terraformOptions)
	_, err := terraform.PlanE(t, terraformOptions)

	require.Error(t, err, "Expected an error during plan")
	validationPassed := utils.VerifyDataContains(t, err.Error(), "Given Resource Group is not found in the account", testLogger)
	assert.True(t, validationPassed, "Should fail with invalid resource group error")
	testLogger.LogValidationResult(t, validationPassed, "Invalid resource group validation")
}

// TestInvalidLoginSubnet validates cluster creation with invalid subnet combination
func TestInvalidLoginSubnet(t *testing.T) {
	t.Parallel()

	setupTestSuite(t)
	testLogger.Info(t, "Cluster creation process initiated for "+t.Name())

	// Get base Terraform variables
	terraformVars := getBaseVars(t)
	testLogger.Info(t, fmt.Sprintf("Generated cluster prefix: %s", terraformVars["cluster_prefix"]))
	terraformVars["login_subnet_id"] = "subnet-123" // Only providing login subnet

	terraformDirPath := getTerraformDirPath(t)
	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: terraformDirPath,
		Vars:         terraformVars,
	})

	UpgradeTerraformOnce(t, terraformOptions)
	_, err := terraform.PlanE(t, terraformOptions)

	require.Error(t, err, "Expected an error during plan")
	validationPassed := utils.VerifyDataContains(t, err.Error(), "In case of existing subnets, provide both login_subnet_id and", testLogger)
	assert.True(t, validationPassed, "Should fail with invalid subnet combination error")
	testLogger.LogValidationResult(t, validationPassed, "Invalid subnet combination validation")
}

// TestInvalidDynamicComputeInstances validates cluster creation with multiple dynamic compute instances
func TestInvalidDynamicComputeInstances(t *testing.T) {
	t.Parallel()

	setupTestSuite(t)
	testLogger.Info(t, "Cluster creation process initiated for "+t.Name())

	// Get base Terraform variables
	terraformVars := getBaseVars(t)
	testLogger.Info(t, fmt.Sprintf("Generated cluster prefix: %s", terraformVars["cluster_prefix"]))
	terraformVars["dynamic_compute_instances"] = []map[string]interface{}{
		{
			"profile": "bx2-4x16",
			"count":   1024,
			"image":   "hpc-lsf-fp15-compute-rhel810-v1",
		},
		{
			"profile": "cx2-4x8",
			"count":   1024,
			"image":   "hpc-lsf-fp15-compute-rhel810-v1",
		},
	}

	terraformDirPath := getTerraformDirPath(t)
	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: terraformDirPath,
		Vars:         terraformVars,
	})

	UpgradeTerraformOnce(t, terraformOptions)
	_, err := terraform.PlanE(t, terraformOptions)

	require.Error(t, err, "Expected an error during plan")
	validationPassed := utils.VerifyDataContains(t, err.Error(), "Only a single map (one instance profile) is allowed for dynamic compute", testLogger)
	assert.True(t, validationPassed, "Should fail with multiple dynamic compute instances error")
	testLogger.LogValidationResult(t, validationPassed, "Multiple dynamic compute instances validation")
}

// TestInvalidKmsKeyName validates cluster creation with KMS key name but no instance name
func TestInvalidKmsKeyName(t *testing.T) {
	t.Parallel()

	setupTestSuite(t)
	testLogger.Info(t, "Cluster creation process initiated for "+t.Name())

	// Get base Terraform variables
	terraformVars := getBaseVars(t)
	testLogger.Info(t, fmt.Sprintf("Generated cluster prefix: %s", terraformVars["cluster_prefix"]))
	terraformVars["key_management"] = "key_protect"
	terraformVars["kms_key_name"] = "my-key" // Key name without instance name

	terraformDirPath := getTerraformDirPath(t)
	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: terraformDirPath,
		Vars:         terraformVars,
	})

	UpgradeTerraformOnce(t, terraformOptions)
	_, err := terraform.PlanE(t, terraformOptions)

	require.Error(t, err, "Expected an error during plan")
	validationPassed := utils.VerifyDataContains(t, err.Error(), "Please make sure you are passing the kms_instance_name", testLogger)
	assert.True(t, validationPassed, "Should fail with missing KMS instance name error")
	testLogger.LogValidationResult(t, validationPassed, "KMS key name without instance name validation")
}

// TestInvalidSshKeyFormat validates cluster creation with invalid SSH key format
func TestInvalidSshKeyFormat(t *testing.T) {
	t.Parallel()

	setupTestSuite(t)
	testLogger.Info(t, "Test: "+t.Name())

	// Get base Terraform variables
	terraformVars := getBaseVars(t)
	testLogger.Info(t, fmt.Sprintf("Generated cluster prefix: %s", terraformVars["cluster_prefix"]))
	terraformVars["ssh_keys"] = []string{"invalid-key-with spaces"} // Invalid format

	terraformDirPath := getTerraformDirPath(t)
	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: terraformDirPath,
		Vars:         terraformVars,
	})

	UpgradeTerraformOnce(t, terraformOptions)
	_, err := terraform.PlanE(t, terraformOptions)

	require.Error(t, err, "Expected an error during plan")
	assert.True(t,
		strings.Contains(err.Error(), "Invalid SSH key") ||
			strings.Contains(err.Error(), "No SSH Key found"),
		"Error should be about SSH key validation. Got: %s", err.Error(),
	)
	testLogger.LogValidationResult(t, true, "Invalid SSH key format validation")
}

// TestInvalidZoneRegionCombination validates invalid zone/region combination
func TestInvalidZoneRegionCombination(t *testing.T) {
	t.Parallel()

	setupTestSuite(t)
	testLogger.Info(t, "Test: "+t.Name())

	// Get base Terraform variables
	terraformVars := getBaseVars(t)
	testLogger.Info(t, fmt.Sprintf("Generated cluster prefix: %s", terraformVars["cluster_prefix"]))
	terraformVars["zones"] = []string{"eu-tok-1"} // Invalid for US region

	terraformDirPath := getTerraformDirPath(t)
	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: terraformDirPath,
		Vars:         terraformVars,
	})

	UpgradeTerraformOnce(t, terraformOptions)
	_, err := terraform.PlanE(t, terraformOptions)

	require.Error(t, err, "Expected an error during plan")
	assert.True(t,
		strings.Contains(err.Error(), "dial tcp: lookup eu-tok.iaas.cloud.ibm.com: no such host") ||
			strings.Contains(err.Error(), "invalid zone"),
		"Error should be about zone/region mismatch. Got: %s", err.Error(),
	)
	testLogger.LogValidationResult(t, true, "Invalid zone/region validation")
}

// TestExceedManagementNodeLimit validates exceeding management node limit
func TestExceedManagementNodeLimit(t *testing.T) {
	t.Parallel()

	setupTestSuite(t)
	testLogger.Info(t, "Test: "+t.Name())

	// Get base Terraform variables
	terraformVars := getBaseVars(t)
	testLogger.Info(t, fmt.Sprintf("Generated cluster prefix: %s", terraformVars["cluster_prefix"]))
	terraformVars["management_instances"] = []map[string]interface{}{
		{
			"count":   11, // Exceeds limit of 10
			"profile": "bx2-16x64",
			"image":   "hpc-lsf-fp15-rhel810-v1",
		},
	}

	terraformDirPath := getTerraformDirPath(t)
	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: terraformDirPath,
		Vars:         terraformVars,
	})

	UpgradeTerraformOnce(t, terraformOptions)
	_, err := terraform.PlanE(t, terraformOptions)

	require.Error(t, err, "Expected an error during plan")
	assert.True(t,
		strings.Contains(err.Error(), "must not exceed") ||
			strings.Contains(err.Error(), "limit of 10"),
		"Error should be about management node limit. Got: %s", err.Error(),
	)
	testLogger.LogValidationResult(t, true, "Management node limit validation")
}

// TestInvalidFileShareConfiguration validates invalid file share config
func TestInvalidFileShareConfiguration(t *testing.T) {
	t.Parallel()

	setupTestSuite(t)
	testLogger.Info(t, "Test: "+t.Name())

	// Get base Terraform variables
	terraformVars := getBaseVars(t)
	testLogger.Info(t, fmt.Sprintf("Generated cluster prefix: %s", terraformVars["cluster_prefix"]))
	terraformVars["custom_file_shares"] = []map[string]interface{}{
		{
			"mount_path": "/mnt/vpcstorage/tools",
			"size":       5, // Below minimum 10GB
			"iops":       2000,
		},
	}

	terraformDirPath := getTerraformDirPath(t)
	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: terraformDirPath,
		Vars:         terraformVars,
	})

	UpgradeTerraformOnce(t, terraformOptions)
	_, err := terraform.PlanE(t, terraformOptions)

	require.Error(t, err, "Expected an error during plan")
	assert.True(t,
		strings.Contains(err.Error(), "must be greater than or equal to 10"),
		"Error should be about file share size. Got: %s", err.Error(),
	)
	testLogger.LogValidationResult(t, true, "File share size validation")
}

// TestInvalidDnsDomainName validates invalid DNS domain name
func TestInvalidDnsDomainName(t *testing.T) {
	t.Parallel()

	setupTestSuite(t)
	testLogger.Info(t, "Test: "+t.Name())

	// Get base Terraform variables
	terraformVars := getBaseVars(t)
	testLogger.Info(t, fmt.Sprintf("Generated cluster prefix: %s", terraformVars["cluster_prefix"]))
	terraformVars["dns_domain_name"] = map[string]interface{}{
		"compute": "invalid_domain", // Missing .com
	}

	terraformDirPath := getTerraformDirPath(t)
	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: terraformDirPath,
		Vars:         terraformVars,
	})

	UpgradeTerraformOnce(t, terraformOptions)
	_, err := terraform.PlanE(t, terraformOptions)

	require.Error(t, err, "Expected an error during plan")
	assert.True(t,
		strings.Contains(err.Error(), "must be a valid FQDN"),
		"Error should be about DNS domain format. Got: %s", err.Error(),
	)
	testLogger.LogValidationResult(t, true, "DNS domain validation")
}

// TestInvalidLdapServerIP validates cluster creation with invalid LDAP server IP
func TestInvalidLdapServerIP(t *testing.T) {
	t.Parallel()

	setupTestSuite(t)
	testLogger.Info(t, "Cluster creation process initiated for "+t.Name())

	// Retrieve environment variables
	envVars, err := GetEnvVars()
	require.NoError(t, err, "Failed to get environment variables")
	if strings.ToLower(envVars.EnableLdap) != "true" {
		t.Skip("LDAP is not enabled. Set the 'enable_ldap' environment variable to 'true' to run this test.")
	}

	// Validate required LDAP credentials
	if len(envVars.LdapAdminPassword) == 0 || len(envVars.LdapUserName) == 0 || len(envVars.LdapUserPassword) == 0 { // pragma: allowlist secret
		t.Fatal("LDAP credentials are missing. Make sure LDAP admin password, LDAP user name, and LDAP user password are provided.")
	}

	// Get base Terraform variables

	terraformVars := getBaseVars(t)
	testLogger.Info(t, fmt.Sprintf("Generated cluster prefix: %s", terraformVars["cluster_prefix"]))

	// Set invalid LDAP server configuration
	terraformVars["enable_ldap"] = true
	terraformVars["ldap_server"] = "10.10.10.10" // Invalid IP
	terraformVars["ldap_server_cert"] = "SampleTest"
	terraformVars["ldap_admin_password"] = envVars.LdapAdminPassword // pragma: allowlist secret

	terraformDirPath := getTerraformDirPath(t)
	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: terraformDirPath,
		Vars:         terraformVars,
	})

	UpgradeTerraformOnce(t, terraformOptions)
	output, err := terraform.InitAndApplyE(t, terraformOptions)

	require.Error(t, err, "Expected an error during apply")
	validationPassed := utils.VerifyDataContains(t, output, "Failed to connect to LDAP server at 10.10.10.10", testLogger)
	assert.True(t, validationPassed, "Should fail with invalid LDAP server IP error")
	testLogger.LogValidationResult(t, validationPassed, "Invalid LDAP server IP validation")

	defer terraform.Destroy(t, terraformOptions)
}

// TestInvalidLdapServerCert validates cluster creation with invalid LDAP server certificate
func TestInvalidLdapServerCert(t *testing.T) {
	t.Parallel()

	setupTestSuite(t)
	testLogger.Info(t, "Cluster creation process initiated for "+t.Name())

	// Retrieve environment variables
	envVars, err := GetEnvVars()
	require.NoError(t, err, "Failed to get environment variables")

	if strings.ToLower(envVars.EnableLdap) != "true" {
		t.Skip("LDAP is not enabled. Set the 'enable_ldap' environment variable to 'true' to run this test.")
	}

	// Validate required LDAP credentials
	if len(envVars.LdapAdminPassword) == 0 || len(envVars.LdapUserName) == 0 || len(envVars.LdapUserPassword) == 0 { // pragma: allowlist secret
		t.Fatal("LDAP credentials are missing. Make sure LDAP admin password, LDAP user name, and LDAP user password are provided.")
	}

	// Get base Terraform variables

	terraformVars := getBaseVars(t)
	testLogger.Info(t, fmt.Sprintf("Generated cluster prefix: %s", terraformVars["cluster_prefix"]))

	// Set invalid LDAP server certificate configuration
	terraformVars["enable_ldap"] = true
	terraformVars["ldap_server"] = "10.10.10.10"                     // Existing server
	terraformVars["ldap_server_cert"] = ""                           // Missing certificate
	terraformVars["ldap_admin_password"] = envVars.LdapAdminPassword // pragma: allowlist secret

	terraformDirPath := getTerraformDirPath(t)
	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: terraformDirPath,
		Vars:         terraformVars,
	})

	UpgradeTerraformOnce(t, terraformOptions)
	_, err = terraform.PlanE(t, terraformOptions)

	require.Error(t, err, "Expected an error during plan")
	validationPassed := utils.VerifyDataContains(t, err.Error(),
		"Provide the current LDAP server certificate. This is required if",
		testLogger) && utils.VerifyDataContains(t, err.Error(),
		"'ldap_server' is set; otherwise, the LDAP configuration will not succeed.",
		testLogger)

	assert.True(t, validationPassed, "Should fail with missing LDAP server certificate error")
	testLogger.LogValidationResult(t, validationPassed, "Invalid LDAP server certificate validation")

}

// TestInvalidLdapConfigurations validates various invalid LDAP configurations
func TestInvalidLdapConfigurations(t *testing.T) {
	t.Parallel()

	testCases := []struct {
		name           string
		config         map[string]interface{}
		expectedErrors []string
		description    string
	}{
		// Username validation tests
		{
			name: "UsernameWithSpace",
			config: map[string]interface{}{
				"enable_ldap":         true,
				"ldap_user_name":      "invalid user",
				"ldap_user_password":  "ValidPass123!", // pragma: allowlist secret
				"ldap_admin_password": "AdminPass123!", // pragma: allowlist secret
			},
			expectedErrors: []string{
				"LDAP username must be between 4-32 characters",
				"can only contain letters, numbers, hyphens, and underscores",
				"Spaces are not permitted.",
			},
			description: "Username containing space should fail",
		},
		{
			name: "UsernameTooShort",
			config: map[string]interface{}{
				"enable_ldap":         true,
				"ldap_user_name":      "usr",
				"ldap_user_password":  "ValidPass123!", // pragma: allowlist secret
				"ldap_admin_password": "AdminPass123!", // pragma: allowlist secret
			},
			expectedErrors: []string{
				"LDAP username must be between 4-32 characters long and can only contain",
				"letters, numbers, hyphens, and underscores",
			},
			description: "Username shorter than 4 characters should fail",
		},
		{
			name: "UsernameTooLong",
			config: map[string]interface{}{
				"enable_ldap":         true,
				"ldap_user_name":      "thisusernameiswaytoolongandshouldfailvalidation",
				"ldap_user_password":  "ValidPass123!", // pragma: allowlist secret
				"ldap_admin_password": "AdminPass123!", // pragma: allowlist secret
			},
			expectedErrors: []string{
				"LDAP username must be between 4-32 characters long and can only contain",
				"letters, numbers, hyphens, and underscores",
			},
			description: "Username longer than 32 characters should fail",
		},
		{
			name: "UsernameWithSpecialChars",
			config: map[string]interface{}{
				"enable_ldap":         true,
				"ldap_user_name":      "user@name#",
				"ldap_user_password":  "ValidPass123!", // pragma: allowlist secret
				"ldap_admin_password": "AdminPass123!", // pragma: allowlist secret
			},
			expectedErrors: []string{
				"LDAP username must be between 4-32 characters long and can only contain",
				"letters, numbers, hyphens, and underscores. Spaces are not permitted.",
			},
			description: "Username with special characters should fail",
		},

		// Password validation tests
		{
			name: "PasswordTooShort",
			config: map[string]interface{}{
				"enable_ldap":         true,
				"ldap_user_name":      "validuser",
				"ldap_user_password":  "Short1!",       // pragma: allowlist secret
				"ldap_admin_password": "AdminPass123!", // pragma: allowlist secret
			},
			expectedErrors: []string{
				"must be 8 to 20 characters long",
			},
			description: "Password shorter than 8 characters should fail",
		},
		{
			name: "PasswordTooLong",
			config: map[string]interface{}{
				"enable_ldap":         true,
				"ldap_user_name":      "validuser",
				"ldap_user_password":  "ThisPasswordIsWayTooLong123!", // pragma: allowlist secret
				"ldap_admin_password": "AdminPass123!",                // pragma: allowlist secret
			},
			expectedErrors: []string{
				"must be 8 to 20 characters long",
			},
			description: "Password longer than 20 characters should fail",
		},
		{
			name: "PasswordMissingUppercase",
			config: map[string]interface{}{
				"enable_ldap":         true,
				"ldap_user_name":      "validuser",
				"ldap_user_password":  "missingupper1!", // pragma: allowlist secret
				"ldap_admin_password": "AdminPass123!",  // pragma: allowlist secret
			},
			expectedErrors: []string{
				"two alphabetic characters (with one uppercase and one lowercase)",
			},
			description: "Password missing uppercase letter should fail",
		},
		{
			name: "PasswordMissingLowercase",
			config: map[string]interface{}{
				"enable_ldap":         true,
				"ldap_user_name":      "validuser",
				"ldap_user_password":  "MISSINGLOWER1!", // pragma: allowlist secret
				"ldap_admin_password": "AdminPass123!",  // pragma: allowlist secret
			},
			expectedErrors: []string{
				"two alphabetic characters (with one uppercase and one lowercase)",
			},
			description: "Password missing lowercase letter should fail",
		},
		{
			name: "PasswordMissingNumber",
			config: map[string]interface{}{
				"enable_ldap":         true,
				"ldap_user_name":      "validuser",
				"ldap_user_password":  "MissingNumber!", // pragma: allowlist secret
				"ldap_admin_password": "AdminPass123!",  // pragma: allowlist secret
			},
			expectedErrors: []string{
				"one number",
			},
			description: "Password missing number should fail",
		},
		{
			name: "PasswordMissingSpecialChar",
			config: map[string]interface{}{
				"enable_ldap":         true,
				"ldap_user_name":      "validuser",
				"ldap_user_password":  "MissingSpecial1", // pragma: allowlist secret
				"ldap_admin_password": "AdminPass123!",   // pragma: allowlist secret
			},
			expectedErrors: []string{
				"one special character",
			},
			description: "Password missing special character should fail",
		},
		{
			name: "PasswordWithSpace",
			config: map[string]interface{}{
				"enable_ldap":         true,
				"ldap_user_name":      "validuser",
				"ldap_user_password":  "Invalid Pass123!", // pragma: allowlist secret
				"ldap_admin_password": "AdminPass123!",    // pragma: allowlist secret
			},
			expectedErrors: []string{
				"password must not contain the username or any spaces",
			},
			description: "Password containing space should fail",
		},
		{
			name: "PasswordContainsUsername",
			config: map[string]interface{}{
				"enable_ldap":         true,
				"ldap_user_name":      "validuser",
				"ldap_user_password":  "Validuser123!", // pragma: allowlist secret
				"ldap_admin_password": "AdminPass123!", // pragma: allowlist secret
			},
			expectedErrors: []string{
				"The password must not contain the username",
			},
			description: "Password containing username should fail",
		},

		// Admin password validation tests
		{
			name: "AdminPasswordMissing",
			config: map[string]interface{}{
				"enable_ldap":         true,
				"ldap_user_name":      "validuser",
				"ldap_user_password":  "ValidPass123!", // pragma: allowlist secret
				"ldap_admin_password": "",              // pragma: allowlist secret
			},
			expectedErrors: []string{
				"The LDAP administrative password must be 8 to 20 characters long and include at least two alphabetic characters",
			},
			description: "Missing admin password should fail",
		},
		{
			name: "AdminPasswordTooShort",
			config: map[string]interface{}{
				"enable_ldap":         true,
				"ldap_user_name":      "validuser",
				"ldap_user_password":  "ValidPass123!", // pragma: allowlist secret
				"ldap_admin_password": "Short1!",       // pragma: allowlist secret
			},
			expectedErrors: []string{
				"must be 8 to 20 characters long",
			},
			description: "Admin password too short should fail",
		},

		// Base DNS validation
		{
			name: "MissingBaseDNS",
			config: map[string]interface{}{
				"enable_ldap":         true,
				"ldap_basedns":        "",
				"ldap_user_name":      "validuser",
				"ldap_user_password":  "ValidPass123!", // pragma: allowlist secret
				"ldap_admin_password": "AdminPass123!", // pragma: allowlist secret
			},
			expectedErrors: []string{
				"If LDAP is enabled, then the base DNS should not be empty or null.",
			},
			description: "Missing base DNS should fail",
		},
		{
			name: "InvalidBaseDNSFormat",
			config: map[string]interface{}{
				"enable_ldap":         true,
				"ldap_basedns":        "invalid_dns_format",
				"ldap_user_name":      "validuser",
				"ldap_user_password":  "UserPass123!",  // pragma: allowlist secret
				"ldap_admin_password": "AdminPass123!", // pragma: allowlist secret
			},
			expectedErrors: []string{
				"Need a valid domain name",
			},
			description: "Invalid base DNS format should fail",
		},
	}

	for _, tc := range testCases {
		tc := tc
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()

			setupTestSuite(t)
			testLogger.Info(t, "Test: "+t.Name())

			// Get base vars and merge with test case config
			terraformVars := getBaseVars(t)
			testLogger.Info(t, fmt.Sprintf("Generated cluster prefix: %s", terraformVars["cluster_prefix"]))
			for k, v := range tc.config {
				terraformVars[k] = v
			}

			terraformDirPath := getTerraformDirPath(t)
			terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
				TerraformDir: terraformDirPath,
				Vars:         terraformVars,
			})

			UpgradeTerraformOnce(t, terraformOptions)
			_, err := terraform.PlanE(t, terraformOptions)

			require.Error(t, err, "Expected an error during plan for: "+tc.description)

			// Check if any of the expected error messages are present
			var found bool
			errorMsg := err.Error()
			for _, expectedErr := range tc.expectedErrors {
				if strings.Contains(errorMsg, expectedErr) {
					found = true
					break
				}
			}

			assert.True(t, found,
				"Expected error containing one of: %v\nBut got: %s",
				tc.expectedErrors, errorMsg)

			testLogger.LogValidationResult(t, found, tc.description)
		})
	}
}

// TestInvalidDeployerImage validates invalid deployer image configurations
func TestInvalidDeployerImage(t *testing.T) {
	t.Parallel()

	setupTestSuite(t)
	testLogger.Info(t, "Starting negative tests for deployer image validation")

	invalidCases := []struct {
		name          string
		lsfVersion    string
		deployerImage string
		expectedError string
	}{
		{
			name:          "FP14_LSF_with_FP15_Image",
			lsfVersion:    "fixpack_14",
			deployerImage: "hpc-lsf-fp15-deployer-rhel810-v1",
			expectedError: "Mismatch between deployer_instance.image and lsf_version",
		},
		{
			name:          "FP15_LSF_with_FP14_Image",
			lsfVersion:    "fixpack_15",
			deployerImage: "hpc-lsf-fp14-deployer-rhel810-v1",
			expectedError: "Mismatch between deployer_instance.image and lsf_version",
		},
		{
			name:          "Malformed_Image_Name",
			lsfVersion:    "fixpack_15",
			deployerImage: "custom-fp15-image",
			expectedError: "Invalid deployer image. Allowed values",
		},
		{
			name:          "Empty_Image_Name",
			lsfVersion:    "fixpack_15",
			deployerImage: "",
			expectedError: "Invalid deployer image",
		},
		{
			name:          "Unsupported_FP13_Deployer",
			lsfVersion:    "fixpack_13",
			deployerImage: "hpc-lsf-fp13-deployer-rhel810-v1",
			expectedError: "Invalid LSF version. Allowed values are 'fixpack_14' and 'fixpack_15'",
		},
	}

	for _, tc := range invalidCases {
		tc := tc
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()

			// Get base Terraform variables
			terraformVars := getBaseVars(t)
			testLogger.Info(t, fmt.Sprintf("Generated cluster prefix: %s", terraformVars["cluster_prefix"]))
			terraformVars["lsf_version"] = tc.lsfVersion
			terraformVars["deployer_instance"] = map[string]interface{}{
				"image":   tc.deployerImage,
				"profile": "bx2-8x32",
			}

			terraformDirPath := getTerraformDirPath(t)
			terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
				TerraformDir: terraformDirPath,
				Vars:         terraformVars,
			})

			_, err := terraform.PlanE(t, terraformOptions)
			require.Error(t, err, "Expected '%s' to fail but it passed", tc.name)
			assert.Contains(t, err.Error(), tc.expectedError,
				"Expected error message mismatch for case: %s", tc.name)
			testLogger.Info(t, fmt.Sprintf("Correctly blocked invalid case: %s", tc.name))
		})
	}
}

// TestInvalidSshKeys validates cluster creation with invalid ssh keys
func TestInvalidSshKeys(t *testing.T) {
	t.Parallel()

	setupTestSuite(t)
	testLogger.Info(t, "Cluster creation process initiated for "+t.Name())

	// Retrieve environment variables
	_, err := GetEnvVars()
	require.NoError(t, err, "Failed to get environment variables")

	// Get base Terraform variables
	terraformVars := getBaseVars(t)
	testLogger.Info(t, fmt.Sprintf("Generated cluster prefix: %s", terraformVars["cluster_prefix"]))

	// Test cases for invalid SSH keys
	testCases := []struct {
		name        string
		key         string
		errorPhrase string
	}{
		{
			name:        "Empty SSH key",
			key:         "",
			errorPhrase: "No SSH Key found with name",
		},
		{
			name:        "Invalid key format",
			key:         "invalid@key",
			errorPhrase: "No SSH Key found with name",
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			terraformVars["ssh_keys"] = []string{tc.key}

			terraformDirPath := getTerraformDirPath(t)
			terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
				TerraformDir: terraformDirPath,
				Vars:         terraformVars,
			})

			UpgradeTerraformOnce(t, terraformOptions)
			output, err := terraform.PlanE(t, terraformOptions)

			require.Error(t, err, "Expected an error during plan")
			validationPassed := utils.VerifyDataContains(t, output,
				tc.errorPhrase,
				testLogger)

			assert.True(t, validationPassed, fmt.Sprintf("Should fail with %s", tc.name))
			testLogger.LogValidationResult(t, validationPassed, fmt.Sprintf("%s validation", tc.name))
		})
	}
}

// TestInvalidRemoteAllowedIP validates cluster creation with invalid remote allowed IP
func TestInvalidRemoteAllowedIP(t *testing.T) {
	t.Parallel()

	setupTestSuite(t)
	testLogger.Info(t, "Cluster creation process initiated for "+t.Name())

	// Get base Terraform variables
	terraformVars := getBaseVars(t)
	testLogger.Info(t, fmt.Sprintf("Generated cluster prefix: %s", terraformVars["cluster_prefix"]))
	terraformVars["remote_allowed_ips"] = []string{""}

	terraformDirPath := getTerraformDirPath(t)
	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: terraformDirPath,
		Vars:         terraformVars,
	})

	UpgradeTerraformOnce(t, terraformOptions)
	output, err := terraform.PlanE(t, terraformOptions)

	require.Error(t, err, "Expected an error during plan")
	validationPassed := utils.VerifyDataContains(t, output,
		"The provided IP address format is not valid",
		testLogger)

	assert.True(t, validationPassed, "Should fail with invalid SSH keys and IP error")
	testLogger.LogValidationResult(t, validationPassed, "Invalid SSH keys and remote allowed IP validation")
}
