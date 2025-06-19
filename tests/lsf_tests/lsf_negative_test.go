package tests

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	lsf "github.com/terraform-ibm-modules/terraform-ibm-hpc/lsf"
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

// TestRunInvalidSubnetCIDR validates cluster creation with invalid subnet CIDR ranges
func TestRunInvalidSubnetCIDR(t *testing.T) {
	t.Parallel()

	setupTestSuite(t)
	testLogger.Info(t, "Cluster creation process initiated for "+t.Name())

	hpcClusterPrefix := utils.GenerateTimestampedClusterPrefix(utils.GenerateRandomString())
	envVars, err := GetEnvVars()
	require.NoError(t, err, "Failed to get environment variables")

	terraformDirPath := getTerraformDirPath(t)

	terraformVars := map[string]interface{}{
		"cluster_prefix":     hpcClusterPrefix,
		"ssh_keys":           utils.SplitAndTrim(envVars.SSHKeys, ","),
		"zones":              utils.SplitAndTrim(envVars.Zones, ","),
		"remote_allowed_ips": utils.SplitAndTrim(envVars.RemoteAllowedIPs, ","),
		"vpc_cluster_private_subnets_cidr_blocks": utils.SplitAndTrim(invalidSubnetCIDR1, ","),
		// "bastion_subnets_cidr":            utils.SplitAndTrim(invalidSubnetCIDR1, ","),
		// "client_subnets_cidr":             utils.SplitAndTrim(invalidSubnetCIDR2, ","),
		// "compute_subnets_cidr":            utils.SplitAndTrim(invalidSubnetCIDR3, ","),
		"scc_enable":                      false,
		"observability_atracker_enable":   false,
		"observability_monitoring_enable": false,
	}

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: terraformDirPath,
		Vars:         terraformVars,
	})

	UpgradeTerraformOnce(t, terraformOptions)
	_, err = terraform.InitAndApplyE(t, terraformOptions)

	assert.Error(t, err, "Expected an error during apply")
	if err != nil {
		//const expectedError = "Key: 'SubnetTemplateOneOf.SubnetTemplate.CIDRBlock' Error:Field validation for 'CIDRBlock' failed on the 'validcidr' tag"
		const expectedError = "\"ipv4_cidr_block\" must be a valid cidr address"
		validationPassed := utils.VerifyDataContains(t, err.Error(), expectedError, testLogger)
		assert.True(t, validationPassed)
		testLogger.LogValidationResult(t, validationPassed, "Invalid Subnet CIDR range")
	} else {
		testLogger.FAIL(t, "Expected error did not occur on Invalid Subnet CIDR range")
		t.Error("Expected error did not occur")
	}

	defer terraform.Destroy(t, terraformOptions)
}

// TestRunInvalidSshKeysAndRemoteAllowedIP validates cluster creation with invalid ssh keys and remote allowed IP
func TestRunInvalidSshKeysAndRemoteAllowedIP(t *testing.T) {
	t.Parallel()

	setupTestSuite(t)
	testLogger.Info(t, "Cluster creation process initiated for "+t.Name())

	hpcClusterPrefix := utils.GenerateTimestampedClusterPrefix(utils.GenerateRandomString())
	envVars, err := GetEnvVars()
	require.NoError(t, err, "Failed to get environment variables")

	terraformDirPath := getTerraformDirPath(t)

	terraformVars := map[string]interface{}{
		"cluster_prefix": hpcClusterPrefix,
		"ssh_keys":       []string{""},
		// "compute_ssh_keys": []string{""},
		"zones":              utils.SplitAndTrim(envVars.Zones, ","),
		"remote_allowed_ips": []string{""},
	}

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: terraformDirPath,
		Vars:         terraformVars,
	})

	UpgradeTerraformOnce(t, terraformOptions)
	_, err = terraform.PlanE(t, terraformOptions)

	assert.Error(t, err, "Expected an error during plan")
	if err != nil {
		// validationPassed := utils.VerifyDataContains(t, err.Error(), "The provided IP address format is not valid", testLogger) &&
		// 	utils.VerifyDataContains(t, err.Error(), "No SSH Key found with name", testLogger)

		validationPassed := utils.VerifyDataContains(t, err.Error(), "No SSH Key found with name", testLogger)
		assert.True(t, validationPassed)
		testLogger.LogValidationResult(t, validationPassed, "Invalid ssh keys and remote allowed IP")
	} else {
		testLogger.FAIL(t, "Expected error did not occur on Invalid ssh keys and remote allowed IP")
		t.Error("Expected error did not occur")
	}
}

// TestRunInvalidLDAPServerIP validates cluster creation with invalid LDAP server IP
func TestRunInvalidLDAPServerIP(t *testing.T) {
	t.Parallel()

	setupTestSuite(t)
	testLogger.Info(t, "Cluster creation process initiated for "+t.Name())

	hpcClusterPrefix := utils.GenerateTimestampedClusterPrefix(utils.GenerateRandomString())
	envVars, err := GetEnvVars()
	require.NoError(t, err, "Failed to get environment variables")

	if strings.ToLower(envVars.EnableLdap) != "true" {
		require.FailNow(t, "LDAP is not enabled. Set the 'enable_ldap' environment variable to 'true' to enable LDAP.")
	}
	if len(envVars.LdapAdminPassword) == 0 || len(envVars.LdapUserName) == 0 || len(envVars.LdapUserPassword) == 0 {
		require.FailNow(t, "LDAP credentials are missing. Make sure LDAP admin password, LDAP user name, and LDAP user password are provided.")
	}

	terraformDirPath := getTerraformDirPath(t)

	terraformVars := map[string]interface{}{
		"cluster_prefix":                  hpcClusterPrefix,
		"ssh_keys":                        utils.SplitAndTrim(envVars.SSHKeys, ","),
		"zones":                           utils.SplitAndTrim(envVars.Zones, ","),
		"remote_allowed_ips":              utils.SplitAndTrim(envVars.RemoteAllowedIPs, ","),
		"enable_ldap":                     true,
		"ldap_admin_password":             envVars.LdapAdminPassword, //pragma: allowlist secret
		"ldap_server":                     invalidLDAPServerIP,
		"ldap_server_cert":                "SampleTest",
		"scc_enable":                      false,
		"observability_monitoring_enable": false,
		"observability_atracker_enable":   false,
	}

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: terraformDirPath,
		Vars:         terraformVars,
	})

	UpgradeTerraformOnce(t, terraformOptions)
	output, err := terraform.InitAndApplyE(t, terraformOptions)

	assert.Error(t, err, "Expected an error during apply")
	if err != nil {
		expectedError := fmt.Sprintf("The connection to the existing LDAP server %s failed", invalidLDAPServerIP)
		validationPassed := utils.VerifyDataContains(t, output, expectedError, testLogger)
		assert.True(t, validationPassed)
		testLogger.LogValidationResult(t, validationPassed, "Invalid LDAP server IP")
	} else {
		testLogger.FAIL(t, "Expected error did not occur on Invalid LDAP Server IP")
		t.Error("Expected error did not occur")
	}

	defer terraform.Destroy(t, terraformOptions)
}

// TestRunInvalidLDAPServerCert validates cluster creation with invalid LDAP server Cert
func TestRunInvalidLDAPServerCert(t *testing.T) {
	t.Parallel()

	setupTestSuite(t)
	testLogger.Info(t, "Cluster creation process initiated for "+t.Name())

	hpcClusterPrefix := utils.GenerateTimestampedClusterPrefix(utils.GenerateRandomString())
	envVars, err := GetEnvVars()
	require.NoError(t, err, "Failed to get environment variables")

	if strings.ToLower(envVars.EnableLdap) != "true" {
		require.FailNow(t, "LDAP is not enabled. Set the 'enable_ldap' environment variable to 'true' to enable LDAP.")
	}
	if len(envVars.LdapAdminPassword) == 0 || len(envVars.LdapUserName) == 0 || len(envVars.LdapUserPassword) == 0 {
		require.FailNow(t, "LDAP credentials are missing. Make sure LDAP admin password, LDAP user name, and LDAP user password are provided.")
	}

	terraformDirPath := getTerraformDirPath(t)

	terraformVars := map[string]interface{}{
		"cluster_prefix": hpcClusterPrefix,
		// "bastion_ssh_keys":    utils.SplitAndTrim(envVars.SSHKey, ","),
		// "compute_ssh_keys":    utils.SplitAndTrim(envVars.SSHKey, ","),
		"ssh_keys":            utils.SplitAndTrim(envVars.SSHKeys, ","),
		"zones":               utils.SplitAndTrim(envVars.Zones, ","),
		"remote_allowed_ips":  utils.SplitAndTrim(envVars.RemoteAllowedIPs, ","),
		"enable_ldap":         true,
		"ldap_admin_password": envVars.LdapAdminPassword, //pragma: allowlist secret
		"ldap_server":         invalidLDAPServerIP,
		"ldap_server_cert":    "",
		"scc_enable":          false,
	}

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: terraformDirPath,
		Vars:         terraformVars,
	})

	UpgradeTerraformOnce(t, terraformOptions)
	_, err = terraform.InitAndPlanE(t, terraformOptions)

	assert.Error(t, err, "Expected an error during plan")
	if err != nil {
		const expectedError = "Provide the current LDAP server certificate. This is required if 'ldap_server' is not set to 'null'"
		validationPassed := utils.VerifyDataContains(t, err.Error(), expectedError, testLogger)
		assert.True(t, validationPassed)
		testLogger.LogValidationResult(t, validationPassed, "Invalid LDAP server Cert")
	} else {
		testLogger.FAIL(t, "Expected error did not occur on Invalid LDAP Server Cert")
		t.Error("Expected error did not occur")
	}

	defer terraform.Destroy(t, terraformOptions)
}

// TestRunInvalidLDAPUsernamePassword tests invalid LDAP username and password combinations
func TestRunInvalidLDAPUsernamePassword(t *testing.T) {
	t.Parallel()

	setupTestSuite(t)
	testLogger.Info(t, "Cluster creation process initiated for "+t.Name())

	hpcClusterPrefix := utils.GenerateTimestampedClusterPrefix(utils.GenerateRandomString())
	envVars, err := GetEnvVars()
	require.NoError(t, err, "Failed to get environment variables")

	invalidLDAPUsername := []string{
		"usr",
		"user@1234567890123456789012345678901",
		"",
		"user 1234",
	}

	invalidLDAPPassword := []string{
		"password",
		"PasswoRD123",
		"password123",
		"Password@",
		"Password123",
		"password@12345678901234567890",
	}

	terraformDirPath := getTerraformDirPath(t)

	for _, username := range invalidLDAPUsername {
		for _, password := range invalidLDAPPassword { //pragma: allowlist secret
			terraformVars := map[string]interface{}{
				"cluster_prefix": hpcClusterPrefix,
				// "bastion_ssh_keys":    utils.SplitAndTrim(envVars.SSHKey, ","),
				// "compute_ssh_keys":    utils.SplitAndTrim(envVars.SSHKey, ","),
				// "zones":               utils.SplitAndTrim(envVars.Zones, ","),
				// "allowed_cidr":        utils.SplitAndTrim(envVars.AllowedCidr, ","),
				"ssh_keys":            utils.SplitAndTrim(envVars.SSHKeys, ","),
				"zones":               utils.SplitAndTrim(envVars.Zones, ","),
				"remote_allowed_ips":  utils.SplitAndTrim(envVars.RemoteAllowedIPs, ","),
				"enable_ldap":         true,
				"ldap_user_name":      username,
				"ldap_user_password":  password,
				"ldap_admin_password": password,
			}

			terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
				TerraformDir: terraformDirPath,
				Vars:         terraformVars,
			})

			UpgradeTerraformOnce(t, terraformOptions)
			_, err = terraform.PlanE(t, terraformOptions)

			if err != nil {
				validationPassed := utils.VerifyDataContains(t, err.Error(), "ldap_user_name", testLogger) &&
					utils.VerifyDataContains(t, err.Error(), "ldap_usr_pwd", testLogger) &&
					utils.VerifyDataContains(t, err.Error(), "ldap_adm_pwd", testLogger)
				assert.True(t, validationPassed)
				testLogger.LogValidationResult(t, validationPassed, "Invalid LDAP credentials")
			} else {
				testLogger.FAIL(t, "Expected error did not contain required fields: ldap_user_name, ldap_user_password or ldap_admin_password")
				t.Error("Expected error did not occur")
			}
		}
	}
}

// TestRunInvalidAPPCenterPassword tests invalid values for app center password
func TestRunInvalidAPPCenterPassword(t *testing.T) {
	t.Parallel()

	setupTestSuite(t)
	testLogger.Info(t, "Cluster creation process initiated for "+t.Name())

	invalidAPPCenterPwd := []string{
		"pass@1234",
		"Pass1234",
		"Pas@12",
		"",
	}

	for _, password := range invalidAPPCenterPwd { //pragma: allowlist secret
		hpcClusterPrefix := utils.GenerateTimestampedClusterPrefix(utils.GenerateRandomString())
		envVars, err := GetEnvVars()
		require.NoError(t, err, "Failed to get environment variables")

		terraformDirPath := getTerraformDirPath(t)

		terraformVars := map[string]interface{}{
			"cluster_prefix":     hpcClusterPrefix,
			"ssh_keys":           utils.SplitAndTrim(envVars.SSHKeys, ","),
			"zones":              utils.SplitAndTrim(envVars.Zones, ","),
			"remote_allowed_ips": utils.SplitAndTrim(envVars.RemoteAllowedIPs, ","),
			"enable_app_center":  true,
			"app_center_gui_pwd": password,
		}

		terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
			TerraformDir: terraformDirPath,
			Vars:         terraformVars,
		})

		UpgradeTerraformOnce(t, terraformOptions)
		_, err = terraform.PlanE(t, terraformOptions)

		if err != nil {
			validationPassed := utils.VerifyDataContains(t, err.Error(), "app_center_gui_pwd", testLogger)
			assert.True(t, validationPassed)
			testLogger.LogValidationResult(t, validationPassed, "Invalid Application Center Password")
		} else {
			testLogger.FAIL(t, "Expected error did not occur on Invalid Application Center Password")
			t.Error("Expected error did not occur")
		}
	}
}

// TestRunInvalidDomainName validates cluster creation with invalid domain name
func TestRunInvalidDomainName(t *testing.T) {
	t.Parallel()

	setupTestSuite(t)
	testLogger.Info(t, "Cluster creation process initiated for "+t.Name())

	hpcClusterPrefix := utils.GenerateTimestampedClusterPrefix(utils.GenerateRandomString())
	envVars, err := GetEnvVars()
	require.NoError(t, err, "Failed to get environment variables")

	terraformDirPath := getTerraformDirPath(t)

	terraformVars := map[string]interface{}{
		"cluster_prefix":     hpcClusterPrefix,
		"ssh_keys":           utils.SplitAndTrim(envVars.SSHKeys, ","),
		"zones":              utils.SplitAndTrim(envVars.Zones, ","),
		"remote_allowed_ips": utils.SplitAndTrim(envVars.RemoteAllowedIPs, ","),
		"dns_domain_names": map[string]string{
			"compute":  "comp",
			"storage":  "strg",
			"protocol": "ces",
			"client":   "clnt",
			"gklm":     "gklm",
		},
		"scc_enable":                      false,
		"observability_monitoring_enable": false,
		"observability_atracker_enable":   false,
	}

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: terraformDirPath,
		Vars:         terraformVars,
	})

	UpgradeTerraformOnce(t, terraformOptions)
	_, err = terraform.PlanE(t, terraformOptions)

	assert.Error(t, err, "Expected an error during plan")
	if err != nil {
		const expectedError = "The domain name provided for compute is not a fully qualified domain name"
		validationPassed := utils.VerifyDataContains(t, err.Error(), expectedError, testLogger)
		assert.True(t, validationPassed)
		testLogger.LogValidationResult(t, validationPassed, "Invalid domain name")
	} else {
		testLogger.FAIL(t, "Expected error did not occur on Invalid domain name")
		t.Error("Expected error did not occur")
	}
}

// TestRunKMSInstanceNameAndKMSKeyNameWithInvalidValue tests KMS instances and key names with invalid values
func TestRunKMSInstanceNameAndKMSKeyNameWithInvalidValue(t *testing.T) {
	t.Parallel()

	setupTestSuite(t)
	testLogger.Info(t, "Cluster creation process initiated for "+t.Name())

	randomString := utils.GenerateRandomString()
	kmsInstanceName := "cicd-" + randomString

	hpcClusterPrefix := utils.GenerateTimestampedClusterPrefix(utils.GenerateRandomString())
	envVars, err := GetEnvVars()
	require.NoError(t, err, "Failed to get environment variables")

	err = lsf.CreateServiceInstanceAndKmsKey(t, os.Getenv("TF_VAR_ibmcloud_api_key"), utils.GetRegion(envVars.Zones),
		envVars.DefaultExistingResourceGroup, kmsInstanceName, KMS_KEY_NAME, testLogger)
	require.NoError(t, err, "Failed to create service instance and KMS key")

	defer lsf.DeleteServiceInstanceAndAssociatedKeys(t, os.Getenv("TF_VAR_ibmcloud_api_key"),
		utils.GetRegion(envVars.Zones), envVars.DefaultExistingResourceGroup, kmsInstanceName, testLogger)

	testLogger.Info(t, "Service instance and KMS key created successfully: "+t.Name())

	terraformDirPath := getTerraformDirPath(t)

	const (
		noKeyErrorMsg        = "No keys with name " + invalidKMSKeyName
		noInstanceErrorMsg   = "No resource instance found with name [" + invalidKMSInstance + "]"
		noInstanceIDErrorMsg = "Please make sure you are passing the kms_instance_name if you are passing kms_key_name"
	)

	testCases := []struct {
		name          string
		instanceName  string
		keyName       string
		expectedError string
	}{
		{
			name:          "Valid instance ID and invalid key name",
			instanceName:  kmsInstanceName,
			keyName:       invalidKMSKeyName,
			expectedError: noKeyErrorMsg,
		},
		{
			name:          "Invalid instance ID and valid key name",
			instanceName:  invalidKMSInstance,
			keyName:       KMS_KEY_NAME,
			expectedError: noInstanceErrorMsg,
		},
		{
			name:          "Without instance ID and valid key name",
			instanceName:  "",
			keyName:       KMS_KEY_NAME,
			expectedError: noInstanceIDErrorMsg,
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			terraformVars := map[string]interface{}{
				"cluster_prefix":                  hpcClusterPrefix,
				"ssh_keys":                        utils.SplitAndTrim(envVars.SSHKeys, ","),
				"zones":                           utils.SplitAndTrim(envVars.Zones, ","),
				"remote_allowed_ips":              utils.SplitAndTrim(envVars.RemoteAllowedIPs, ","),
				"scc_enable":                      false,
				"observability_monitoring_enable": false,
				"observability_atracker_enable":   false,
			}

			if tc.instanceName != "" {
				terraformVars["kms_instance_name"] = tc.instanceName
			}
			if tc.keyName != "" {
				terraformVars["kms_key_name"] = tc.keyName
			}

			terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
				TerraformDir: terraformDirPath,
				Vars:         terraformVars,
			})

			UpgradeTerraformOnce(t, terraformOptions)
			_, err := terraform.PlanE(t, terraformOptions)

			if err != nil {
				validationPassed := utils.VerifyDataContains(t, err.Error(), tc.expectedError, testLogger)
				assert.True(t, validationPassed)
				testLogger.LogValidationResult(t, validationPassed, tc.name)
			} else {
				testLogger.FAIL(t, fmt.Sprintf("Expected error did not occur in case: %s", tc.name))
				t.Error("Expected error did not occur")
			}
		})
	}
}

// TestRunExistSubnetIDVpcNameAsNull verifies that existing subnet_id requires vpc_name
func TestRunExistSubnetIDVpcNameAsNull(t *testing.T) {
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

	options.SkipTestTearDown = true
	defer options.TestTearDown()

	output, err := options.RunTest()
	require.NoError(t, err, "Error running consistency test")
	require.NotNil(t, output, "Expected non-nil output, but got nil")
	outputs := (options.LastTestTerraformOutputs)

	bastionsubnetId, computesubnetIds := utils.GetSubnetIds(outputs)
	terraformDirPath := getTerraformDirPath(t)

	terraformVars := map[string]interface{}{
		"cluster_prefix":     clusterNamePrefix,
		"ssh_keys":           utils.SplitAndTrim(envVars.SSHKeys, ","),
		"zones":              utils.SplitAndTrim(envVars.Zones, ","),
		"remote_allowed_ips": utils.SplitAndTrim(envVars.RemoteAllowedIPs, ","),
		"cluster_subnet_id":  utils.SplitAndTrim(computesubnetIds, ","),
		"login_subnet_id":    bastionsubnetId,
	}

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: terraformDirPath,
		Vars:         terraformVars,
	})

	UpgradeTerraformOnce(t, terraformOptions)
	_, err = terraform.PlanE(t, terraformOptions)

	assert.Error(t, err, "Expected an error during plan")
	if err != nil {
		expectedErrors := []string{
			"If the cluster_subnet_id are provided, the user should also provide the vpc_name",
			"Provided cluster subnets should be in appropriate zone",
			"Provided login subnet should be within the vpc entered",
			"Provided login subnet should be in appropriate zone",
			"Provided cluster subnets should be within the vpc entered",
			"Provided existing cluster_subnet_id should have public gateway attached",
		}

		validationPassed := true
		for _, expected := range expectedErrors {
			if !utils.VerifyDataContains(t, err.Error(), expected, testLogger) {
				validationPassed = false
				break
			}
		}

		assert.True(t, validationPassed)
		testLogger.LogValidationResult(t, validationPassed, "Without VPC name and with valid cluster_subnet_id and login_subnet_id")
	} else {
		testLogger.FAIL(t, "Expected error did not occur on Without VPC name and with valid cluster_subnet_id and login_subnet_id")
		t.Error("Expected error did not occur")
	}
}

// TestRunInvalidDedicatedHostConfigurationWithZeroWorkerNodes validates dedicated host with zero worker nodes
func TestRunInvalidDedicatedHostConfigurationWithZeroWorkerNodes(t *testing.T) {
	t.Parallel()

	setupTestSuite(t)
	hpcClusterPrefix := utils.GenerateRandomString()
	testLogger.Info(t, "Cluster creation process initiated for "+t.Name())

	envVars, err := GetEnvVars()
	require.NoError(t, err, "Failed to get environment variables")

	options, err := setupOptions(t, hpcClusterPrefix, terraformDir, envVars.DefaultExistingResourceGroup)
	require.NoError(t, err, "Error setting up test options")

	options.TerraformVars["enable_dedicated_host"] = true
	options.TerraformVars["static_compute_instances"] = []map[string]interface{}{
		{
			"profile":    "cx2-2x4",
			"count":      2,
			"image":      "ibm-redhat-8-10-minimal-amd64-2",
			"filesystem": "/gpfs/fs1",
		},
	}

	options.SkipTestTearDown = true
	defer options.TestTearDown()

	lsf.ValidateBasicClusterConfigurationWithDedicatedHost(t, options, false, testLogger)
}

// TestRunInvalidDedicatedHostProfile validates cluster creation with an invalid instance profile
func TestRunInvalidDedicatedHostProfile(t *testing.T) {
	t.Parallel()

	setupTestSuite(t)
	testLogger.Info(t, "Cluster creation process initiated for "+t.Name())

	hpcClusterPrefix := utils.GenerateTimestampedClusterPrefix(utils.GenerateRandomString())
	envVars, err := GetEnvVars()
	require.NoError(t, err, "Failed to get environment variables")

	terraformDirPath := getTerraformDirPath(t)

	terraformVars := map[string]interface{}{
		"cluster_prefix":        hpcClusterPrefix,
		"ssh_keys":              utils.SplitAndTrim(envVars.SSHKeys, ","),
		"zones":                 utils.SplitAndTrim(envVars.Zones, ","),
		"remote_allowed_ips":    utils.SplitAndTrim(envVars.RemoteAllowedIPs, ","),
		"enable_dedicated_host": true,
		"static_compute_instances": []map[string]interface{}{
			{
				"profile":    "cx2-2x4",
				"count":      2,
				"image":      "ibm-redhat-8-10-minimal-amd64-2",
				"filesystem": "/gpfs/fs1",
			},
		},
		"dynamic_compute_instances": []map[string]interface{}{
			{
				"profile": "cx2-2x4",
				"count":   1024,
				"image":   "ibm-redhat-8-10-minimal-amd64-2",
			},
		},
		"enable_cos_integration":          false,
		"enable_vpc_flow_logs":            false,
		"key_management":                  "null",
		"scc_enable":                      false,
		"observability_monitoring_enable": false,
		"observability_atracker_enable":   false,
	}

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: terraformDirPath,
		Vars:         terraformVars,
	})

	UpgradeTerraformOnce(t, terraformOptions)
	_, err = terraform.InitAndPlanE(t, terraformOptions)

	assert.Error(t, err, "Expected an error during plan")
	if err != nil {
		errMsg := err.Error()
		containsWorkerNodeType := utils.VerifyDataContains(t, errMsg, "is list of object with 2 elements", testLogger)
		containsDedicatedHost := utils.VerifyDataContains(t, errMsg, "'enable_dedicated_host' is true, only one profile should be specified", testLogger)

		validationPassed := containsWorkerNodeType && containsDedicatedHost
		assert.True(t, validationPassed)
		testLogger.LogValidationResult(t, validationPassed, "Invalid Dedicated-Host instance profile")
	} else {
		testLogger.FAIL(t, "Expected validation error did not occur for Invalid Dedicated-Host instance profile.")
		t.Error("Expected error did not occur")
	}

	defer terraform.Destroy(t, terraformOptions)
}

// TestRunInvalidMinWorkerNodeCountGreaterThanMax validates invalid worker node counts
func TestRunInvalidMinWorkerNodeCountGreaterThanMax(t *testing.T) {
	t.Parallel()

	setupTestSuite(t)
	testLogger.Info(t, "Cluster creation process initiated for "+t.Name())

	hpcClusterPrefix := utils.GenerateTimestampedClusterPrefix(utils.GenerateRandomString())
	envVars, err := GetEnvVars()
	require.NoError(t, err, "Failed to get environment variables")

	terraformDirPath := getTerraformDirPath(t)

	terraformVars := map[string]interface{}{
		"cluster_prefix":     hpcClusterPrefix,
		"ssh_keys":           utils.SplitAndTrim(envVars.SSHKeys, ","),
		"zones":              utils.SplitAndTrim(envVars.Zones, ","),
		"remote_allowed_ips": utils.SplitAndTrim(envVars.RemoteAllowedIPs, ","),
		"static_compute_instances": []map[string]interface{}{
			{
				"profile":    "cx2-2x4",
				"count":      2,
				"image":      envVars.StaticComputeInstancesImage,
				"filesystem": "/gpfs/fs1",
			},
		},
		"dynamic_compute_instances": []map[string]interface{}{
			{
				"profile": "cx2-2x4",
				"count":   1,
				"image":   envVars.DynamicComputeInstancesImage,
			},
		},

		"scc_enable":                      false,
		"observability_monitoring_enable": false,
		"observability_atracker_enable":   false,
		"enable_cos_integration":          false,
		"enable_vpc_flow_logs":            false,
		"key_management":                  "null",
	}

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: terraformDirPath,
		Vars:         terraformVars,
	})

	UpgradeTerraformOnce(t, terraformOptions)
	_, err = terraform.InitAndPlanE(t, terraformOptions)

	assert.Error(t, err, "Expected an error during plan")
	if err != nil {
		const expectedError = "If the solution is set as lsf, the worker min count cannot be greater than worker max count."
		validationPassed := utils.VerifyDataContains(t, err.Error(), expectedError, testLogger)
		assert.True(t, validationPassed)
		testLogger.LogValidationResult(t, validationPassed, "Worker node count validation")
	} else {
		testLogger.FAIL(t, "Expected validation error did not occur for Invalid worker node count")
		t.Error("Expected error did not occur")
	}

	defer terraform.Destroy(t, terraformOptions)
	testLogger.Info(t, "TestRunInvalidMinWorkerNodeCountGreaterThanMax will execute If the solution is set as lsf")
}
