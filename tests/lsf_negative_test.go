package tests

import (
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

// TestRunLSFWithoutMandatory tests Terraform's behavior when mandatory variables are missing
func TestRunLSFWithoutMandatory(t *testing.T) {
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
	if err != nil {
		validationPassed :=
			utils.VerifyDataContains(t, err.Error(), "remote_allowed_ips", testLogger)

		assert.True(t, validationPassed)

	} else {
		testLogger.FAIL(t, "Expected error did not occur on LSF without mandatory")
		t.Error("Expected error did not occur")
	}
}

// TestEmptyIbmcloudApiKey validates cluster creation with empty IBM Cloud API key
func TestEmptyIbmcloudApiKey(t *testing.T) {
	t.Parallel()

	setupTestSuite(t)
	testLogger.Info(t, "Cluster creation process initiated for "+t.Name())

	hpcClusterPrefix := utils.GenerateTimestampedClusterPrefix(utils.GenerateRandomString())
	envVars, err := GetEnvVars()
	require.NoError(t, err, "Failed to get environment variables")

	terraformDirPath := getTerraformDirPath(t)

	terraformVars := map[string]interface{}{
		"cluster_prefix":          hpcClusterPrefix,
		"ibmcloud_api_key":        "", // Empty API key  // pragma: allowlist secret
		"ssh_keys":                utils.SplitAndTrim(envVars.SSHKeys, ","),
		"zones":                   utils.SplitAndTrim(envVars.Zones, ","),
		"remote_allowed_ips":      utils.SplitAndTrim(envVars.RemoteAllowedIPs, ","),
		"app_center_gui_password": APP_CENTER_GUI_PASSWORD, //pragma: allowlist secret
	}

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: terraformDirPath,
		Vars:         terraformVars,
	})

	UpgradeTerraformOnce(t, terraformOptions)
	_, err = terraform.PlanE(t, terraformOptions)

	assert.Error(t, err, "Expected an error during plan")
	if err != nil {
		validationPassed := utils.VerifyDataContains(t, err.Error(), "The API key for IBM Cloud must be set", testLogger)
		assert.True(t, validationPassed)
		testLogger.LogValidationResult(t, validationPassed, "Empty IBM Cloud API key validation")
	} else {
		testLogger.FAIL(t, "Expected error did not occur for empty IBM Cloud API key")
		t.Error("Expected error did not occur")
	}
}

// TestInvalidLsfVersion validates cluster creation with invalid LSF version
func TestInvalidLsfVersion(t *testing.T) {
	t.Parallel()

	setupTestSuite(t)
	testLogger.Info(t, "Cluster creation process initiated for "+t.Name())

	hpcClusterPrefix := utils.GenerateTimestampedClusterPrefix(utils.GenerateRandomString())
	envVars, err := GetEnvVars()
	require.NoError(t, err, "Failed to get environment variables")

	terraformDirPath := getTerraformDirPath(t)

	terraformVars := map[string]interface{}{
		"cluster_prefix":          hpcClusterPrefix,
		"lsf_version":             "invalid_version", // Invalid LSF version
		"ssh_keys":                utils.SplitAndTrim(envVars.SSHKeys, ","),
		"zones":                   utils.SplitAndTrim(envVars.Zones, ","),
		"remote_allowed_ips":      utils.SplitAndTrim(envVars.RemoteAllowedIPs, ","),
		"app_center_gui_password": APP_CENTER_GUI_PASSWORD, //pragma: allowlist secret
	}

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: terraformDirPath,
		Vars:         terraformVars,
	})

	UpgradeTerraformOnce(t, terraformOptions)
	_, err = terraform.PlanE(t, terraformOptions)

	assert.Error(t, err, "Expected an error during plan")
	if err != nil {
		validationPassed := utils.VerifyDataContains(t, err.Error(), "Invalid LSF version. Allowed values are 'fixpack_14' and 'fixpack_15'", testLogger)
		assert.True(t, validationPassed)
		testLogger.LogValidationResult(t, validationPassed, "Invalid LSF version validation")
	} else {
		testLogger.FAIL(t, "Expected error did not occur for invalid LSF version")
		t.Error("Expected error did not occur")
	}
}

// TestInvalidAppCenterPassword validates cluster creation with invalid App Center password
func TestInvalidAppCenterPassword(t *testing.T) {
	t.Parallel()

	setupTestSuite(t)
	testLogger.Info(t, "Cluster creation process initiated for "+t.Name())

	hpcClusterPrefix := utils.GenerateTimestampedClusterPrefix(utils.GenerateRandomString())
	envVars, err := GetEnvVars()
	require.NoError(t, err, "Failed to get environment variables")

	terraformDirPath := getTerraformDirPath(t)

	terraformVars := map[string]interface{}{
		"cluster_prefix":          hpcClusterPrefix,
		"ssh_keys":                utils.SplitAndTrim(envVars.SSHKeys, ","),
		"zones":                   utils.SplitAndTrim(envVars.Zones, ","),
		"remote_allowed_ips":      utils.SplitAndTrim(envVars.RemoteAllowedIPs, ","),
		"app_center_gui_password": "weak", // Invalid password  // pragma: allowlist secret
	}

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: terraformDirPath,
		Vars:         terraformVars,
	})

	UpgradeTerraformOnce(t, terraformOptions)
	_, err = terraform.PlanE(t, terraformOptions)

	assert.Error(t, err, "Expected an error during plan")
	if err != nil {
		validationPassed := utils.VerifyDataContains(t, err.Error(), "The password must be at least 8 characters long", testLogger)
		assert.True(t, validationPassed)
		testLogger.LogValidationResult(t, validationPassed, "Invalid App Center password validation")
	} else {
		testLogger.FAIL(t, "Expected error did not occur for invalid App Center password")
		t.Error("Expected error did not occur")
	}
}

// TestMultipleZones validates cluster creation with multiple zones
func TestMultipleZones(t *testing.T) {
	t.Parallel()

	setupTestSuite(t)
	testLogger.Info(t, "Cluster creation process initiated for "+t.Name())

	hpcClusterPrefix := utils.GenerateTimestampedClusterPrefix(utils.GenerateRandomString())
	envVars, err := GetEnvVars()
	require.NoError(t, err, "Failed to get environment variables")

	terraformDirPath := getTerraformDirPath(t)

	terraformVars := map[string]interface{}{
		"cluster_prefix":          hpcClusterPrefix,
		"ssh_keys":                utils.SplitAndTrim(envVars.SSHKeys, ","),
		"zones":                   []string{"us-east-1", "us-east-2"}, // Multiple zones
		"remote_allowed_ips":      utils.SplitAndTrim(envVars.RemoteAllowedIPs, ","),
		"app_center_gui_password": APP_CENTER_GUI_PASSWORD, //pragma: allowlist secret
	}

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: terraformDirPath,
		Vars:         terraformVars,
	})

	UpgradeTerraformOnce(t, terraformOptions)
	_, err = terraform.PlanE(t, terraformOptions)

	assert.Error(t, err, "Expected an error during plan")
	if err != nil {
		validationPassed := utils.VerifyDataContains(t, err.Error(), "HPC product deployment supports only a single zone", testLogger)
		assert.True(t, validationPassed)
		testLogger.LogValidationResult(t, validationPassed, "Multiple zones validation")
	} else {
		testLogger.FAIL(t, "Expected error did not occur for multiple zones")
		t.Error("Expected error did not occur")
	}
}

// TestInvalidClusterPrefix validates cluster creation with invalid cluster prefix
func TestInvalidClusterPrefix(t *testing.T) {
	t.Parallel()

	setupTestSuite(t)
	testLogger.Info(t, "Cluster creation process initiated for "+t.Name())

	envVars, err := GetEnvVars()
	require.NoError(t, err, "Failed to get environment variables")

	terraformDirPath := getTerraformDirPath(t)

	terraformVars := map[string]interface{}{
		"cluster_prefix":          "--invalid-prefix--", // Invalid prefix
		"ssh_keys":                utils.SplitAndTrim(envVars.SSHKeys, ","),
		"zones":                   utils.SplitAndTrim(envVars.Zones, ","),
		"remote_allowed_ips":      utils.SplitAndTrim(envVars.RemoteAllowedIPs, ","),
		"app_center_gui_password": APP_CENTER_GUI_PASSWORD, //pragma: allowlist secret
	}

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: terraformDirPath,
		Vars:         terraformVars,
	})

	UpgradeTerraformOnce(t, terraformOptions)
	_, err = terraform.PlanE(t, terraformOptions)

	assert.Error(t, err, "Expected an error during plan")
	if err != nil {
		validationPassed := utils.VerifyDataContains(t, err.Error(), "Prefix must start with a lowercase letter", testLogger)
		assert.True(t, validationPassed)
		testLogger.LogValidationResult(t, validationPassed, "Invalid cluster prefix validation")
	} else {
		testLogger.FAIL(t, "Expected error did not occur for invalid cluster prefix")
		t.Error("Expected error did not occur")
	}
}

// TestInvalidResourceGroup validates cluster creation with null resource group
func TestInvalidResourceGroup(t *testing.T) {
	t.Parallel()

	setupTestSuite(t)
	testLogger.Info(t, "Cluster creation process initiated for "+t.Name())

	hpcClusterPrefix := utils.GenerateTimestampedClusterPrefix(utils.GenerateRandomString())
	envVars, err := GetEnvVars()
	require.NoError(t, err, "Failed to get environment variables")

	terraformDirPath := getTerraformDirPath(t)

	terraformVars := map[string]interface{}{
		"cluster_prefix":          hpcClusterPrefix,
		"existing_resource_group": nil, // Invalid resource group
		"ssh_keys":                utils.SplitAndTrim(envVars.SSHKeys, ","),
		"zones":                   utils.SplitAndTrim(envVars.Zones, ","),
		"remote_allowed_ips":      utils.SplitAndTrim(envVars.RemoteAllowedIPs, ","),
		"app_center_gui_password": APP_CENTER_GUI_PASSWORD, //pragma: allowlist secret
	}

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: terraformDirPath,
		Vars:         terraformVars,
	})

	UpgradeTerraformOnce(t, terraformOptions)
	_, err = terraform.PlanE(t, terraformOptions)

	assert.Error(t, err, "Expected an error during plan")
	if err != nil {
		validationPassed := utils.VerifyDataContains(t, err.Error(), "If you want to provide null for resource_group variable", testLogger)
		assert.True(t, validationPassed)
		testLogger.LogValidationResult(t, validationPassed, "Invalid resource group validation")
	} else {
		testLogger.FAIL(t, "Expected error did not occur for invalid resource group")
		t.Error("Expected error did not occur")
	}
}

// TestInvalidDeployerImage validates cluster creation with mismatched deployer image and LSF version
func TestInvalidDeployerImage(t *testing.T) {
	t.Parallel()

	setupTestSuite(t)
	testLogger.Info(t, "Cluster creation process initiated for "+t.Name())

	hpcClusterPrefix := utils.GenerateTimestampedClusterPrefix(utils.GenerateRandomString())
	envVars, err := GetEnvVars()
	require.NoError(t, err, "Failed to get environment variables")

	terraformDirPath := getTerraformDirPath(t)

	terraformVars := map[string]interface{}{
		"cluster_prefix":          hpcClusterPrefix,
		"lsf_version":             "fixpack_14",
		"deployer_image":          "hpc-lsf-fp15-deployer-rhel810-v1", // Mismatched image
		"ssh_keys":                utils.SplitAndTrim(envVars.SSHKeys, ","),
		"zones":                   utils.SplitAndTrim(envVars.Zones, ","),
		"remote_allowed_ips":      utils.SplitAndTrim(envVars.RemoteAllowedIPs, ","),
		"app_center_gui_password": APP_CENTER_GUI_PASSWORD, //pragma: allowlist secret
	}

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: terraformDirPath,
		Vars:         terraformVars,
	})

	UpgradeTerraformOnce(t, terraformOptions)
	_, err = terraform.PlanE(t, terraformOptions)

	assert.Error(t, err, "Expected an error during plan")
	if err != nil {
		validationPassed := utils.VerifyDataContains(t, err.Error(), "Mismatch between deployer_image and lsf_version", testLogger)
		assert.True(t, validationPassed)
		testLogger.LogValidationResult(t, validationPassed, "Mismatched deployer image validation")
	} else {
		testLogger.FAIL(t, "Expected error did not occur for mismatched deployer image")
		t.Error("Expected error did not occur")
	}
}

// TestInvalidLoginSubnet validates cluster creation with invalid subnet combination
func TestInvalidLoginSubnet(t *testing.T) {
	t.Parallel()

	setupTestSuite(t)
	testLogger.Info(t, "Cluster creation process initiated for "+t.Name())

	hpcClusterPrefix := utils.GenerateTimestampedClusterPrefix(utils.GenerateRandomString())
	envVars, err := GetEnvVars()
	require.NoError(t, err, "Failed to get environment variables")

	terraformDirPath := getTerraformDirPath(t)

	terraformVars := map[string]interface{}{
		"cluster_prefix":          hpcClusterPrefix,
		"login_subnet_id":         "subnet-123", // Only providing login subnet
		"ssh_keys":                utils.SplitAndTrim(envVars.SSHKeys, ","),
		"zones":                   utils.SplitAndTrim(envVars.Zones, ","),
		"remote_allowed_ips":      utils.SplitAndTrim(envVars.RemoteAllowedIPs, ","),
		"app_center_gui_password": APP_CENTER_GUI_PASSWORD, //pragma: allowlist secret
	}

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: terraformDirPath,
		Vars:         terraformVars,
	})

	UpgradeTerraformOnce(t, terraformOptions)
	_, err = terraform.PlanE(t, terraformOptions)

	assert.Error(t, err, "Expected an error during plan")
	if err != nil {
		validationPassed := utils.VerifyDataContains(t, err.Error(), "In case of existing subnets, provide both login_subnet_id and", testLogger)
		assert.True(t, validationPassed)
		testLogger.LogValidationResult(t, validationPassed, "Invalid subnet combination validation")
	} else {
		testLogger.FAIL(t, "Expected error did not occur for invalid subnet combination")
		t.Error("Expected error did not occur")
	}
}

// TestInvalidDynamicComputeInstances validates cluster creation with multiple dynamic compute instances
func TestInvalidDynamicComputeInstances(t *testing.T) {
	t.Parallel()

	setupTestSuite(t)
	testLogger.Info(t, "Cluster creation process initiated for "+t.Name())

	hpcClusterPrefix := utils.GenerateTimestampedClusterPrefix(utils.GenerateRandomString())
	envVars, err := GetEnvVars()
	require.NoError(t, err, "Failed to get environment variables")

	terraformDirPath := getTerraformDirPath(t)

	terraformVars := map[string]interface{}{
		"cluster_prefix":          hpcClusterPrefix,
		"ssh_keys":                utils.SplitAndTrim(envVars.SSHKeys, ","),
		"zones":                   utils.SplitAndTrim(envVars.Zones, ","),
		"remote_allowed_ips":      utils.SplitAndTrim(envVars.RemoteAllowedIPs, ","),
		"app_center_gui_password": APP_CENTER_GUI_PASSWORD, //pragma: allowlist secret
		"dynamic_compute_instances": []map[string]interface{}{
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
		},
	}

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: terraformDirPath,
		Vars:         terraformVars,
	})

	UpgradeTerraformOnce(t, terraformOptions)
	_, err = terraform.PlanE(t, terraformOptions)

	assert.Error(t, err, "Expected an error during plan")
	if err != nil {
		validationPassed := utils.VerifyDataContains(t, err.Error(), "Only a single map (one instance profile) is allowed for dynamic compute", testLogger)
		assert.True(t, validationPassed)
		testLogger.LogValidationResult(t, validationPassed, "Multiple dynamic compute instances validation")
	} else {
		testLogger.FAIL(t, "Expected error did not occur for multiple dynamic compute instances")
		t.Error("Expected error did not occur")
	}
}

// TestInvalidKmsKeyName validates cluster creation with KMS key name but no instance name
func TestInvalidKmsKeyName(t *testing.T) {
	t.Parallel()

	setupTestSuite(t)
	testLogger.Info(t, "Cluster creation process initiated for "+t.Name())

	hpcClusterPrefix := utils.GenerateTimestampedClusterPrefix(utils.GenerateRandomString())
	envVars, err := GetEnvVars()
	require.NoError(t, err, "Failed to get environment variables")

	terraformDirPath := getTerraformDirPath(t)

	terraformVars := map[string]interface{}{
		"cluster_prefix":          hpcClusterPrefix,
		"key_management":          "key_protect",
		"kms_key_name":            "my-key", // Key name without instance name
		"ssh_keys":                utils.SplitAndTrim(envVars.SSHKeys, ","),
		"zones":                   utils.SplitAndTrim(envVars.Zones, ","),
		"remote_allowed_ips":      utils.SplitAndTrim(envVars.RemoteAllowedIPs, ","),
		"app_center_gui_password": APP_CENTER_GUI_PASSWORD, // pragma: allowlist secret
	}

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: terraformDirPath,
		Vars:         terraformVars,
	})

	UpgradeTerraformOnce(t, terraformOptions)
	_, err = terraform.PlanE(t, terraformOptions)

	assert.Error(t, err, "Expected an error during plan")
	if err != nil {
		validationPassed := utils.VerifyDataContains(t, err.Error(), "Please make sure you are passing the kms_instance_name", testLogger)
		assert.True(t, validationPassed)
		testLogger.LogValidationResult(t, validationPassed, "KMS key name without instance name validation")
	} else {
		testLogger.FAIL(t, "Expected error did not occur for KMS key name without instance name")
		t.Error("Expected error did not occur")
	}
}

// TestInvalidSshKeyFormat validates cluster creation with invalid SSH key format
func TestInvalidSshKeyFormat(t *testing.T) {
	t.Parallel()

	setupTestSuite(t)
	testLogger.Info(t, "Test: "+t.Name())

	terraformVars := getBaseVars(t)
	terraformVars["ssh_keys"] = []string{"invalid-key-with spaces"} // Invalid format

	terraformOptions := createTerraformOptions(t, terraformVars)

	_, err := terraform.InitAndPlanE(t, terraformOptions)

	assert.Error(t, err)
	if err != nil {
		assert.True(t, strings.Contains(err.Error(), "Invalid SSH key") ||
			strings.Contains(err.Error(), "No SSH Key found"))
		testLogger.LogValidationResult(t, true, "Invalid SSH key format validation")
	}
}

// TestInvalidZoneRegionCombination validates invalid zone/region combination
func TestInvalidZoneRegionCombination(t *testing.T) {
	t.Parallel()

	setupTestSuite(t)
	testLogger.Info(t, "Test: "+t.Name())

	terraformVars := getBaseVars(t)
	terraformVars["zones"] = []string{"eu-de-1"} // Invalid for US region

	terraformOptions := createTerraformOptions(t, terraformVars)

	_, err := terraform.InitAndPlanE(t, terraformOptions)

	assert.Error(t, err)
	if err != nil {
		assert.True(t, strings.Contains(err.Error(), "not valid for region") ||
			strings.Contains(err.Error(), "invalid zone"))
		testLogger.LogValidationResult(t, true, "Invalid zone/region validation")
	}
}

// TestExceedManagementNodeLimit validates exceeding management node limit
func TestExceedManagementNodeLimit(t *testing.T) {
	t.Parallel()

	setupTestSuite(t)
	testLogger.Info(t, "Test: "+t.Name())

	terraformVars := getBaseVars(t)
	terraformVars["management_instances"] = []map[string]interface{}{
		{
			"count":   11, // Exceeds limit of 10
			"profile": "bx2-16x64",
			"image":   "hpc-lsf-fp15-rhel810-v1",
		},
	}

	terraformOptions := createTerraformOptions(t, terraformVars)

	_, err := terraform.InitAndPlanE(t, terraformOptions)

	assert.Error(t, err)
	if err != nil {
		assert.True(t, strings.Contains(err.Error(), "must not exceed") ||
			strings.Contains(err.Error(), "limit of 10"))
		testLogger.LogValidationResult(t, true, "Management node limit validation")
	}
}

// TestInvalidFileShareConfiguration validates invalid file share config
func TestInvalidFileShareConfiguration(t *testing.T) {
	t.Parallel()

	setupTestSuite(t)
	testLogger.Info(t, "Test: "+t.Name())

	terraformVars := getBaseVars(t)
	terraformVars["custom_file_shares"] = []map[string]interface{}{
		{
			"mount_path": "/mnt/vpcstorage/tools",
			"size":       5, // Below minimum 10GB
			"iops":       2000,
		},
	}

	terraformOptions := createTerraformOptions(t, terraformVars)

	_, err := terraform.InitAndPlanE(t, terraformOptions)

	assert.Error(t, err)
	if err != nil {
		assert.True(t, strings.Contains(err.Error(), "must be greater than or equal to 10"))
		testLogger.LogValidationResult(t, true, "File share size validation")
	}
}

// TestInvalidDnsDomainName validates invalid DNS domain name
func TestInvalidDnsDomainName(t *testing.T) {
	t.Parallel()

	setupTestSuite(t)
	testLogger.Info(t, "Test: "+t.Name())

	terraformVars := getBaseVars(t)
	terraformVars["dns_domain_name"] = map[string]interface{}{
		"compute": "invalid_domain", // Missing .com
	}

	terraformOptions := createTerraformOptions(t, terraformVars)

	_, err := terraform.InitAndPlanE(t, terraformOptions)

	assert.Error(t, err)
	if err != nil {
		assert.True(t, strings.Contains(err.Error(), "must be a valid FQDN"))
		testLogger.LogValidationResult(t, true, "DNS domain validation")
	}
}

// TestInvalidLdapConfiguration validates invalid LDAP config
func TestInvalidLdapConfiguration(t *testing.T) {
	t.Parallel()

	setupTestSuite(t)
	testLogger.Info(t, "Test: "+t.Name())

	terraformVars := getBaseVars(t)
	terraformVars["enable_ldap"] = true
	terraformVars["ldap_user_password"] = "weak" // Doesn't meet requirements // pragma: allowlist secret

	terraformOptions := createTerraformOptions(t, terraformVars)

	_, err := terraform.InitAndPlanE(t, terraformOptions)

	assert.Error(t, err)
	if err != nil {
		assert.True(t, strings.Contains(err.Error(), "must contain at least") ||
			strings.Contains(err.Error(), "password requirements"))
		testLogger.LogValidationResult(t, true, "LDAP password validation")
	}
}

func getBaseVars(t *testing.T) map[string]interface{} {
	envVars, err := GetEnvVars()
	require.NoError(t, err, "Failed to get environment variables")
	return map[string]interface{}{
		"cluster_prefix": utils.GenerateTimestampedClusterPrefix(utils.GenerateRandomString()),

		"ssh_keys":                utils.SplitAndTrim(envVars.SSHKeys, ","),
		"zones":                   utils.SplitAndTrim(envVars.Zones, ","),
		"remote_allowed_ips":      utils.SplitAndTrim(envVars.RemoteAllowedIPs, ","),
		"app_center_gui_password": APP_CENTER_GUI_PASSWORD, // pragma: allowlist secret
		// Add other required default values
	}
}

func createTerraformOptions(t *testing.T, vars map[string]interface{}) *terraform.Options {
	return &terraform.Options{
		TerraformDir: "../terraform",
		Vars:         vars,
		NoColor:      true, // Disable colors for cleaner logs
		Upgrade:      true,
		RetryableTerraformErrors: map[string]string{
			".*": "retryable error",
		},
	}
}
