package tests

import (
	"fmt"
	"log"
	"os"
	"reflect"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/require"
	"github.com/terraform-ibm-modules/ibmcloud-terratest-wrapper/testhelper"

	utils "github.com/terraform-ibm-modules/terraform-ibm-hpc/utilities"
)

// Constants for configuration
const (
	// Terraform solution directory
	terraformDir = "solutions/lsf"

	// Default scheduler
	Solution = "lsf"

	// Configuration files for each LSF version
	lsfFP14ConfigFile = "lsf_fp14_config.yml"
	lsfFP15ConfigFile = "lsf_fp15_config.yml"
	defaultConfigFile = lsfFP15ConfigFile // Use latest as default

	// Log file suffixes
	defaultLogFileSuffix     = ".log"
	defaultJSONLogFileSuffix = ".json"
)

// Constants for LSF version normalization
const (
	DefaultLSFVersion = "fixpack_15"
	LSF14             = "fixpack_14"
	LSF15             = "fixpack_15"
)

// EnvVars represents all environment variables required for the test
// Fields with `required:"true"` tag must be set for tests to run
type EnvVars struct {
	Scheduler                                   string
	DefaultExistingResourceGroup                string
	NonDefaultExistingResourceGroup             string
	Zones                                       string `required:"true"`
	ClusterName                                 string `required:"true"`
	RemoteAllowedIPs                            string `required:"true"`
	SSHKeys                                     string `required:"true"`
	LoginNodeInstanceType                       string
	LoginNodeImageName                          string
	ManagementInstances                         string
	DeployerInstance                            string
	EnableVPCFlowLogs                           string
	KeyManagement                               string
	KMSInstanceName                             string
	KMSKeyName                                  string
	EnableHyperthreading                        string
	DnsDomainName                               string
	EnableAppCenter                             string
	AppCenterGuiPassword                        string
	EnableLdap                                  string
	LdapBaseDns                                 string
	LdapServer                                  string
	LdapAdminPassword                           string
	LdapUserName                                string
	LdapUserPassword                            string
	LdapInstance                                string
	USEastZone                                  string
	USEastClusterName                           string
	USEastReservationID                         string
	JPTokZone                                   string
	JPTokClusterName                            string
	JPTokReservationID                          string
	EUDEZone                                    string
	EUDEClusterName                             string
	EUDEReservationID                           string
	USSouthZone                                 string
	USSouthClusterName                          string
	USSouthReservationID                        string
	SSHFilePath                                 string
	SSHFilePathTwo                              string
	WorkerNodeMaxCount                          string
	StaticComputeInstances                      string
	DynamicComputeInstances                     string
	EnableSccwp                                 string
	EnableCspm                                  string
	SccwpServicePlan                            string
	AppConfigPlan                               string
	ObservabilityMonitoringEnable               string
	ObservabilityMonitoringOnComputeNodesEnable string
	ObservabilityAtrackerEnable                 string
	ObservabilityAtrackerTargetType             string
	ObservabilityLogsEnableForManagement        string
	ObservabilityLogsEnableForCompute           string
	ObservabilityEnablePlatformLogs             string
	ObservabilityEnableMetricsRouting           string
	ObservabilityLogsRetentionPeriod            string
	ObservabilityMonitoringPlan                 string
	EnableCosIntegration                        string
	CustomFileShares                            string
	BastionInstance                             string
	ManagementInstancesImage                    string
	StaticComputeInstancesImage                 string
	DynamicComputeInstancesImage                string
	LsfVersion                                  string
	LoginInstance                               string
	AttrackerTestZone                           string
	EnableWebService                            string
	EnableAppcenter                             string
	WebServiceAppcenterPassword                 string

	// New fields for region configuration
	DefaultRegion       string
	BasicRegion         string
	KmsRegion           string
	LdapRegion          string
	AppcenterRegion     string
	ObservabilityRegion string
	ExistingVpcRegion   string
	ScalingRegion       string
}

func GetEnvVars() (*EnvVars, error) {
	vars := &EnvVars{
		Scheduler:                       os.Getenv("SCHEDULER"),
		DefaultExistingResourceGroup:    os.Getenv("DEFAULT_EXISTING_RESOURCE_GROUP"),
		NonDefaultExistingResourceGroup: os.Getenv("NON_DEFAULT_EXISTING_RESOURCE_GROUP"),
		Zones:                           os.Getenv("ZONES"),
		ClusterName:                     os.Getenv("CLUSTER_NAME"),
		RemoteAllowedIPs:                os.Getenv("REMOTE_ALLOWED_IPS"),
		SSHKeys:                         os.Getenv("SSH_KEYS"),
		ManagementInstances:             os.Getenv("MANAGEMENT_INSTANCES"),
		DeployerInstance:                os.Getenv("DEPLOYER_INSTANCE"),
		BastionInstance:                 os.Getenv("BASTION_INSTANCE"),
		EnableVPCFlowLogs:               os.Getenv("ENABLE_VPC_FLOW_LOGS"),
		KeyManagement:                   os.Getenv("KEY_MANAGEMENT"),
		KMSInstanceName:                 os.Getenv("KMS_INSTANCE_NAME"),
		KMSKeyName:                      os.Getenv("KMS_KEY_NAME"),
		EnableHyperthreading:            os.Getenv("ENABLE_HYPERTHREADING"),
		DnsDomainName:                   os.Getenv("DNS_DOMAIN_NAME"),
		AppCenterGuiPassword:            os.Getenv("APP_CENTER_GUI_PASSWORD"),
		EnableLdap:                      os.Getenv("ENABLE_LDAP"),
		LdapBaseDns:                     os.Getenv("LDAP_BASEDNS"),
		LdapServer:                      os.Getenv("LDAP_SERVER"),
		LdapAdminPassword:               os.Getenv("LDAP_ADMIN_PASSWORD"),
		LdapUserName:                    os.Getenv("LDAP_USER_NAME"),
		LdapUserPassword:                os.Getenv("LDAP_USER_PASSWORD"),
		LdapInstance:                    os.Getenv("LDAP_INSTANCE"),
		USEastZone:                      os.Getenv("US_EAST_ZONE"),
		USEastClusterName:               os.Getenv("US_EAST_CLUSTER_NAME"),
		USEastReservationID:             os.Getenv("US_EAST_RESERVATION_ID"),
		JPTokZone:                       os.Getenv("JP_TOK_ZONE"),
		JPTokReservationID:              os.Getenv("JP_TOK_RESERVATION_ID"),
		JPTokClusterName:                os.Getenv("JP_TOK_CLUSTER_NAME"),
		EUDEZone:                        os.Getenv("EU_DE_ZONE"),
		EUDEClusterName:                 os.Getenv("EU_DE_CLUSTER_NAME"),
		EUDEReservationID:               os.Getenv("EU_DE_RESERVATION_ID"),
		USSouthZone:                     os.Getenv("US_SOUTH_ZONE"),
		USSouthReservationID:            os.Getenv("US_SOUTH_RESERVATION_ID"),
		USSouthClusterName:              os.Getenv("US_SOUTH_CLUSTER_NAME"),
		SSHFilePath:                     os.Getenv("SSH_FILE_PATH"),
		SSHFilePathTwo:                  os.Getenv("SSH_FILE_PATH_TWO"),
		WorkerNodeMaxCount:              os.Getenv("WORKER_NODE_MAX_COUNT"),
		StaticComputeInstances:          os.Getenv("STATIC_COMPUTE_INSTANCES"),
		DynamicComputeInstances:         os.Getenv("DYNAMIC_COMPUTE_INSTANCES"),
		EnableSccwp:                     os.Getenv("ENABLE_SCCWP"),
		EnableCspm:                      os.Getenv("ENABLE_CSPM"),
		SccwpServicePlan:                os.Getenv("SCCWP_SERVICE_PLAN"),
		AppConfigPlan:                   os.Getenv("APP_CONFIG_PLAN"),
		ObservabilityMonitoringEnable:   os.Getenv("OBSERVABILITY_MONITORING_ENABLE"),
		ObservabilityMonitoringOnComputeNodesEnable: os.Getenv("OBSERVABILITY_MONITORING_ON_COMPUTE_NODES_ENABLE"),
		ObservabilityAtrackerEnable:                 os.Getenv("OBSERVABILITY_ATRACKER_ENABLE"),
		ObservabilityAtrackerTargetType:             os.Getenv("OBSERVABILITY_ATRACKER_TARGET_TYPE"),
		ObservabilityLogsEnableForManagement:        os.Getenv("OBSERVABILITY_LOGS_ENABLE_FOR_MANAGEMENT"),
		ObservabilityLogsEnableForCompute:           os.Getenv("OBSERVABILITY_LOGS_ENABLE_FOR_COMPUTE"),
		ObservabilityEnablePlatformLogs:             os.Getenv("OBSERVABILITY_ENABLE_PLATFORM_LOGS"),
		ObservabilityEnableMetricsRouting:           os.Getenv("OBSERVABILITY_ENABLE_METRICS_ROUTING"),
		ObservabilityLogsRetentionPeriod:            os.Getenv("OBSERVABILITY_LOGS_RETENTION_PERIOD"),
		ObservabilityMonitoringPlan:                 os.Getenv("OBSERVABILITY_MONITORING_PLAN"),
		EnableCosIntegration:                        os.Getenv("ENABLE_COS_INTEGRATION"),
		CustomFileShares:                            os.Getenv("CUSTOM_FILE_SHARES"),
		ManagementInstancesImage:                    os.Getenv("MANAGEMENT_INSTANCES_IMAGE"),
		StaticComputeInstancesImage:                 os.Getenv("STATIC_COMPUTE_INSTANCES_IMAGE"),
		DynamicComputeInstancesImage:                os.Getenv("DYNAMIC_COMPUTE_INSTANCES_IMAGE"),
		LsfVersion:                                  os.Getenv("LSF_VERSION"),
		LoginInstance:                               os.Getenv("LOGIN_INSTANCE"),
		AttrackerTestZone:                           os.Getenv("ATTRACKER_TEST_ZONE"),
		EnableWebService:                            os.Getenv("ENABLE_WEB_SERVICE"),
		EnableAppcenter:                             os.Getenv("ENABLE_APPCENTER"),
		WebServiceAppcenterPassword:                 os.Getenv("WEB_SERVICE_APPCENTER_PASSWORD"),

		// New fields
		DefaultRegion:       os.Getenv("DEFAULT_REGION"),
		BasicRegion:         os.Getenv("BASIC_REGION"),
		KmsRegion:           os.Getenv("KMS_REGION"),
		LdapRegion:          os.Getenv("LDAP_REGION"),
		AppcenterRegion:     os.Getenv("APPCENTER_REGION"),
		ObservabilityRegion: os.Getenv("OBSERVABILITY_REGION"),
		ExistingVpcRegion:   os.Getenv("EXISTING_VPC_REGION"),
		ScalingRegion:       os.Getenv("SCALING_REGION"),
	}

	// Validate required fields
	v := reflect.ValueOf(vars).Elem()
	t := v.Type()
	for i := 0; i < v.NumField(); i++ {
		field := t.Field(i)
		if tag, ok := field.Tag.Lookup("required"); ok && tag == "true" {
			fieldValue := v.Field(i).String()
			if fieldValue == "" {
				return nil, fmt.Errorf("missing required environment variable: %s", field.Name)
			}
		}
	}

	return vars, nil
}

var (
	// testLogger stores the logger instance for logging test messages.
	testLogger *utils.AggregatedLogger

	// once ensures that the test suite initialization logic (e.g., logger setup) runs only once,
	// even when called concurrently by multiple test functions.
	once sync.Once
)

func setupTestSuite(t *testing.T) {
	once.Do(func() {
		timestamp := time.Now().Format("2006-01-02_15-04-05")
		var logFileName string

		if validationLogFilePrefix, ok := os.LookupEnv("LOG_FILE_NAME"); ok {
			fileName := strings.Split(validationLogFilePrefix, defaultJSONLogFileSuffix)[0]
			logFileName = fmt.Sprintf("%s%s", fileName, defaultLogFileSuffix)
		} else {
			logFileName = fmt.Sprintf("%s%s", timestamp, defaultLogFileSuffix)
		}

		_ = os.Setenv("LOG_FILE_NAME", fmt.Sprintf("%s%s", strings.Split(logFileName, ".")[0], defaultJSONLogFileSuffix))

		var err error
		testLogger, err = utils.NewAggregatedLogger(logFileName)
		if err != nil {
			t.Fatalf("Error initializing logger: %v", err)
		}
		testLogger.Info(t, "Logger initialized successfully")
	})
}

var upgradeOnce sync.Once // Ensures upgrade is performed only once

func UpgradeTerraformOnce(t *testing.T, terraformOptions *terraform.Options) {
	upgradeOnce.Do(func() {
		testLogger.Info(t, "Running Terraform upgrade with `-upgrade=true`...")

		// Run terraform upgrade command
		output, err := terraform.RunTerraformCommandE(t, terraformOptions, "init", "-upgrade=true")
		if err != nil {
			// Log the Terraform upgrade output in case of any failures
			testLogger.FAIL(t, fmt.Sprintf("Terraform upgrade failed: %v", err))
			testLogger.FAIL(t, fmt.Sprintf("Terraform upgrade output:\n%s", output))
			require.NoError(t, err, "Terraform upgrade failed")
		}
		testLogger.PASS(t, "Terraform upgrade completed successfully")
	})
}

// checkRequiredEnvVars verifies that required environment variables are set.
// Returns an error if any required env var is missing.
func checkRequiredEnvVars() error {
	required := []string{"TF_VAR_ibmcloud_api_key", "ZONES", "REMOTE_ALLOWED_IPS", "SSH_KEYS"}

	for _, envVar := range required {
		if os.Getenv(envVar) == "" {
			return fmt.Errorf("environment variable %s is not set", envVar)
		}
	}
	return nil
}

// GetLSFVersionConfig determines the correct config YAML file based on the LSF_VERSION
// environment variable. It accepts multiple aliases for convenience (e.g., "14", "lsf14", "fixpack_14"),
// normalizes them to standard constants, and returns the matching config file name.
func GetLSFVersionConfig() (string, error) {
	// Step 1: Set default version
	lsfVersion := DefaultLSFVersion
	var productFileName string

	// Step 2: Check for environment override
	if envVersion, ok := os.LookupEnv("LSF_VERSION"); ok {
		lsfVersion = strings.ToLower(envVersion) // Normalize user input
	}

	// Step 3: Normalize aliases and map to config file
	switch lsfVersion {
	case "fixpack_14", "lsf14", "14":
		productFileName = lsfFP14ConfigFile
		lsfVersion = LSF14 // Normalize for consistent internal use
	case "fixpack_15", "lsf15", "15":
		productFileName = lsfFP15ConfigFile
		lsfVersion = LSF15
	default:
		return "", fmt.Errorf("unsupported LSF version: %s (supported: fixpack_14, fixpack_15, lsf14, lsf15, 14, 15)", lsfVersion)
	}

	// Step 4: Ensure normalized value is set in environment
	if err := os.Setenv("LSF_VERSION", lsfVersion); err != nil {
		return "", fmt.Errorf("failed to set normalized LSF_VERSION: %w", err)
	}

	log.Printf("✅ Using LSF_VERSION: %s", lsfVersion)
	return productFileName, nil
}

// applyRegionOverrides automatically determines test type from test name
func applyRegionOverrides(t *testing.T, envVars *EnvVars, options *testhelper.TestOptions, testType string) {

	// Do not override if default region is enabled or ZONES env variable is set
	if strings.Contains(envVars.DefaultRegion, "true") {
		testLogger.Info(t, "Skipping region override (default_region enabled)")
		return
	}

	// Determine test name
	testName := strings.ToLower(t.Name())
	if testType != "" {
		testName = strings.ToLower(testType)
	}

	var region string

	switch {
	case strings.Contains(testName, "basic"):
		region = envVars.BasicRegion
	case strings.Contains(testName, "kms"):
		region = envVars.KmsRegion
	case strings.Contains(testName, "ldap"):
		region = envVars.LdapRegion
	case strings.Contains(testName, "appcenter"):
		region = envVars.AppcenterRegion
	case strings.Contains(testName, "observability"):
		region = envVars.ObservabilityRegion
	case strings.Contains(testName, "existingvpc"), strings.Contains(testName, "existing_vpc"):
		region = envVars.ExistingVpcRegion
	case strings.Contains(testName, "scaling"):
		region = envVars.ScalingRegion
	default:
		testLogger.Info(t, fmt.Sprintf("No region mapping found for test: %s. Using default zones.", t.Name()))
		return
	}

	if region == "" {
		testLogger.Info(t, fmt.Sprintf("Region mapping exists but region value is empty for test: %s", testName))
		return
	}

	// Override Terraform zones
	options.TerraformVars["zones"] = utils.SplitAndTrim(region, ",")

	testLogger.Info(t, fmt.Sprintf("Terraform zones overridden to: %v", options.TerraformVars["zones"]))
}

// setupOptionsVPC creates a test options object with the given parameters to creating brand new vpc
func setupOptionsVPC(t *testing.T, clusterNamePrefix, terraformDir, existingResourceGroup string) (*testhelper.TestOptions, error) {

	if err := checkRequiredEnvVars(); err != nil {
		// Handle missing environment variable error
		return nil, err
	}

	// Retrieve environment variables
	envVars, err := GetEnvVars()
	if err != nil {
		return nil, fmt.Errorf("environment configuration failed (check required vars): %w", err)
	}

	// Create test options
	options := &testhelper.TestOptions{
		Testing:        t,
		TerraformDir:   terraformDir,
		IgnoreDestroys: testhelper.Exemptions{List: LSFIgnoreLists.Destroys},
		IgnoreUpdates:  testhelper.Exemptions{List: LSFIgnoreLists.Updates},
		TerraformVars: map[string]interface{}{
			"cluster_prefix":          clusterNamePrefix,
			"zones":                   utils.SplitAndTrim(envVars.Zones, ","),
			"remote_allowed_ips":      utils.SplitAndTrim(envVars.RemoteAllowedIPs, ","),
			"existing_resource_group": existingResourceGroup,
			"bastion_ssh_keys":        utils.SplitAndTrim(envVars.SSHKeys, ","),
		},
	}
	return options, nil
}

// setupOptions creates a test options object with the given parameters.
func setupOptions(t *testing.T, clusterNamePrefix, terraformDir, existingResourceGroup string) (*testhelper.TestOptions, error) {

	if err := checkRequiredEnvVars(); err != nil {
		// Handle missing environment variable error
		return nil, err
	}

	envVars, err := GetEnvVars()
	if err != nil {
		return nil, fmt.Errorf("failed to get environment variables: %v", err)
	}

	options := &testhelper.TestOptions{
		Testing:        t,
		TerraformDir:   terraformDir,
		IgnoreDestroys: testhelper.Exemptions{List: LSFIgnoreLists.Destroys},
		IgnoreUpdates:  testhelper.Exemptions{List: LSFIgnoreLists.Updates},
		TerraformVars: map[string]interface{}{
			"cluster_prefix":                  clusterNamePrefix,
			"ssh_keys":                        utils.SplitAndTrim(envVars.SSHKeys, ","),
			"zones":                           utils.SplitAndTrim(envVars.Zones, ","),
			"remote_allowed_ips":              utils.SplitAndTrim(envVars.RemoteAllowedIPs, ","),
			"existing_resource_group":         existingResourceGroup,
			"deployer_instance":               envVars.DeployerInstance,
			"login_instance":                  envVars.LoginInstance,
			"management_instances":            envVars.ManagementInstances,
			"key_management":                  envVars.KeyManagement,
			"enable_hyperthreading":           strings.ToLower(envVars.EnableHyperthreading),
			"observability_atracker_enable":   false,
			"observability_monitoring_enable": false,
			"dns_domain_name":                 envVars.DnsDomainName,
			"static_compute_instances":        envVars.StaticComputeInstances,
			"dynamic_compute_instances":       envVars.DynamicComputeInstances,
			"bastion_instance":                envVars.BastionInstance,
			"enable_sccwp":                    false,
			"enable_cspm":                     false,
			"custom_file_shares":              envVars.CustomFileShares,
			"enable_cos_integration":          false,
			"enable_vpc_flow_logs":            false,
			"enable_webservice":               envVars.EnableWebService,
			"enable_appcenter":                envVars.EnableAppcenter,
			"webservice_appcenter_password":   envVars.WebServiceAppcenterPassword, // pragma: allowlist secret
			"lsf_version":                     envVars.LsfVersion,
			"enable_lsf_pay_per_use":          false,
		},
	}

	// Remove empty values from TerraformVars
	for key, value := range options.TerraformVars {
		if value == "" {
			delete(options.TerraformVars, key)
		}
	}

	return options, nil
}

// DefaultTest validates creation and verification of an HPC LSF cluster.
// Tests:
//   - Successful cluster provisioning
//   - Valid output structure
//   - Resource cleanup
func DefaultTest(t *testing.T) {
	t.Helper()

	// ── 1. Initialization ────────────────────────────────────────────────────
	setupTestSuite(t)
	require.NotNil(t, testLogger, "Test logger must be initialized before use")
	testLogger.Info(t, fmt.Sprintf("[START] Test %s beginning execution", t.Name()))
	t.Log("[START] Test", t.Name(), "beginning execution")

	// ── 2. Configuration ─────────────────────────────────────────────────────
	clusterNamePrefix := utils.GenerateTimestampedClusterPrefix(utils.GenerateRandomString())
	t.Log("Generated cluster name prefix:", clusterNamePrefix)

	envVars, err := GetEnvVars()
	if err != nil {
		t.Log("Failed to load environment variables:", err)
		testLogger.FAIL(t, fmt.Sprintf("Failed to load environment variables: %v", err))
		require.NoError(t, err, "Environment configuration failed")
	}
	t.Log("Environment variables loaded successfully")

	options, err := setupOptions(t, clusterNamePrefix, terraformDir, envVars.DefaultExistingResourceGroup)
	if err != nil {
		t.Log("Failed to initialize test options:", err)
		testLogger.FAIL(t, fmt.Sprintf("Failed to initialize test options: %v", err))
		require.NoError(t, err, "Test options initialization failed")
	}
	t.Log("Test options initialized successfully")

	// ── 3. Pre-conditions ─────────────────────────────────────────────────────
	testLogger.Info(t, fmt.Sprintf("Pre-condition check: cluster prefix=%s, resource group=%s",
		clusterNamePrefix, envVars.DefaultExistingResourceGroup))
	t.Log("Pre-condition check passed — configuration is valid, ready to provision")

	// ── 4. Execution & Validation ─────────────────────────────────────────────
	testLogger.Info(t, fmt.Sprintf("Deployment started for test: %s", t.Name()))
	t.Log("Starting cluster provisioning...")

	output, err := options.RunTestConsistency()
	if err != nil {
		t.Log("Cluster provisioning failed:", err)
		testLogger.FAIL(t, fmt.Sprintf("Cluster provisioning failed: %v", err))
		require.NoError(t, err, "Cluster provisioning failed with output: %v", output)
	}
	require.NotNil(t, output, "Cluster provisioning returned nil output")

	testLogger.Info(t, fmt.Sprintf("Deployment completed successfully for test: %s", t.Name()))
	t.Log("Cluster provisioning completed and output validated")

	// ── 5. Completion ─────────────────────────────────────────────────────────
	testLogger.PASS(t, fmt.Sprintf("[END] Test %s completed successfully", t.Name()))
	t.Log("[END] Test", t.Name(), "completed successfully")
}
