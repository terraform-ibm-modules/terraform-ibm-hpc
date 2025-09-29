package tests

import (
	"fmt"
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
	terraformDir = "solutions/scale"

	// Default scheduler
	Solution = "scale"

	// Configuration files for  Scale version
	defaultConfigFile = "scale_config.yml" // Use latest as default

	// Log file suffixes
	defaultLogFileSuffix     = ".log"
	defaultJSONLogFileSuffix = ".json"
)

// EnvVars represents all environment variables required for the test
type EnvVars struct {
	ScaleVersion                         string
	IbmCustomerNumber                    string
	Zones                                string `required:"true"`
	RemoteAllowedIPs                     string `required:"true"`
	ExistingResourceGroup                string `required:"true"`
	StorageType                          string `required:"true"`
	SSHKeys                              string `required:"true"`
	ScaleDeployerInstance                string
	ComputeGUIUsername                   string
	ComputeGUIPassword                   string // pragma: allowlist secret
	StorageGUIUsername                   string `required:"true"`
	StorageGUIPassword                   string `required:"true"` // pragma: allowlist secret
	ComputeInstances                     string
	ClientInstances                      string
	StorageInstances                     string
	ScaleEncryptionEnabled               string
	ScaleEncryptionType                  string
	ScaleObservabilityAtrackerEnable     string
	ScaleObservabilityAtrackerTargetType string
	ScaleSCCWPEnable                     string
	ScaleCSPMEnabled                     string
	ScaleSCCWPServicePlan                string
	GKLMInstances                        string
	ScaleEncryptionAdminPassword         string // pragma: allowlist secret
	ScaleFilesystemConfig                string
	ScaleFilesetsConfig                  string
	ScaleDNSDomainNames                  string
	ScaleEnableCOSIntegration            string
	ScaleEnableVPCFlowLogs               string
	AfmInstances                         string
	ProtocolInstances                    string
}

func GetEnvVars() (*EnvVars, error) {
	vars := &EnvVars{
		ScaleVersion:                         os.Getenv("SCALE_VERSION"),
		IbmCustomerNumber:                    os.Getenv("IBM_CUSTOMER_NUMBER"),
		Zones:                                os.Getenv("ZONES"),
		RemoteAllowedIPs:                     os.Getenv("REMOTE_ALLOWED_IPS"),
		ExistingResourceGroup:                os.Getenv("EXISTING_RESOURCE_GROUP"),
		StorageType:                          os.Getenv("STORAGE_TYPE"),
		SSHKeys:                              os.Getenv("SSH_KEYS"),
		ScaleDeployerInstance:                os.Getenv("SCALE_DEPLOYER_INSTANCE"),
		ComputeGUIUsername:                   os.Getenv("COMPUTE_GUI_USERNAME"),
		ComputeGUIPassword:                   os.Getenv("COMPUTE_GUI_PASSWORD"),
		StorageGUIUsername:                   os.Getenv("STORAGE_GUI_USERNAME"),
		StorageGUIPassword:                   os.Getenv("STORAGE_GUI_PASSWORD"),
		ComputeInstances:                     os.Getenv("COMPUTE_INSTANCES"),
		ClientInstances:                      os.Getenv("CLIENT_INSTANCES"),
		StorageInstances:                     os.Getenv("STORAGE_INSTANCES"),
		ScaleEncryptionEnabled:               os.Getenv("SCALE_ENCRYPTION_ENABLED"),
		ScaleEncryptionType:                  os.Getenv("SCALE_ENCRYPTION_TYPE"),
		ScaleObservabilityAtrackerEnable:     os.Getenv("SCALE_OBSERVABILITY_ATRACKER_ENABLE"),
		ScaleObservabilityAtrackerTargetType: os.Getenv("SCALE_OBSERVABILITY_ATRACKER_TARGET_TYPE"),
		ScaleSCCWPEnable:                     os.Getenv("SCALE_SCCWP_ENABLE"),
		ScaleCSPMEnabled:                     os.Getenv("SCALE_CSPM_ENABLED"),
		ScaleSCCWPServicePlan:                os.Getenv("SCALE_SCCWP_SERVICE_PLAN"),
		GKLMInstances:                        os.Getenv("GKLM_INSTANCES"),
		ScaleEncryptionAdminPassword:         os.Getenv("SCALE_ENCRYPTION_ADMIN_PASSWORD"),
		ScaleFilesystemConfig:                os.Getenv("SCALE_FILESYSTEM_CONFIG"),
		ScaleFilesetsConfig:                  os.Getenv("SCALE_FILESETS_CONFIG"),
		ScaleDNSDomainNames:                  os.Getenv("SCALE_DNS_DOMAIN_NAMES"),
		ScaleEnableCOSIntegration:            os.Getenv("SCALE_ENABLE_COS_INTEGRATION"),
		ScaleEnableVPCFlowLogs:               os.Getenv("SCALE_ENABLE_VPC_FLOW_LOGS"),
		AfmInstances:                         os.Getenv("AFM_INSTANCES"),
		ProtocolInstances:                    os.Getenv("PROTOCOL_INSTANCES"),
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

var upgradeOnce sync.Once

func UpgradeTerraformOnce(t *testing.T, terraformOptions *terraform.Options) {
	upgradeOnce.Do(func() {
		testLogger.Info(t, "Running Terraform upgrade with `-upgrade=true`...")

		output, err := terraform.RunTerraformCommandE(t, terraformOptions, "init", "-upgrade=true")
		if err != nil {
			testLogger.FAIL(t, fmt.Sprintf("Terraform upgrade failed: %v", err))
			testLogger.FAIL(t, fmt.Sprintf("Terraform upgrade output:\n%s", output))
			require.NoError(t, err, "Terraform upgrade failed")
		}
		testLogger.PASS(t, "Terraform upgrade completed successfully")
	})
}

func checkRequiredEnvVars() error {
	required := []string{"TF_VAR_ibmcloud_api_key", "ZONES", "REMOTE_ALLOWED_IPS", "SSH_KEYS"}

	for _, envVar := range required {
		if os.Getenv(envVar) == "" {
			return fmt.Errorf("environment variable %s is not set", envVar)
		}
	}
	return nil
}

func setupOptions(t *testing.T, clusterNamePrefix, terraformDir, existingResourceGroup string) (*testhelper.TestOptions, error) {
	if err := checkRequiredEnvVars(); err != nil {
		return nil, err
	}

	envVars, err := GetEnvVars()
	if err != nil {
		return nil, fmt.Errorf("failed to get environment variables: %v", err)
	}

	terraformVars := map[string]interface{}{
		"cluster_prefix":                clusterNamePrefix,
		"ibm_customer_number":           envVars.IbmCustomerNumber,
		"ssh_keys":                      utils.SplitAndTrim(envVars.SSHKeys, ","),
		"zones":                         utils.SplitAndTrim(envVars.Zones, ","),
		"remote_allowed_ips":            utils.SplitAndTrim(envVars.RemoteAllowedIPs, ","),
		"existing_resource_group":       existingResourceGroup,
		"storage_type":                  envVars.StorageType,
		"deployer_instance":             envVars.ScaleDeployerInstance,
		"storage_gui_username":          envVars.StorageGUIUsername,
		"storage_gui_password":          envVars.StorageGUIPassword, //  # pragma: allowlist secret
		"storage_instances":             envVars.StorageInstances,
		"enable_cos_integration":        false,
		"enable_vpc_flow_logs":          false,
		"observability_atracker_enable": false,
		"colocate_protocol_instances":   false,
		"protocol_instances":            envVars.ProtocolInstances,
	}

	options := &testhelper.TestOptions{
		Testing:        t,
		TerraformDir:   terraformDir,
		IgnoreDestroys: testhelper.Exemptions{List: SCALEIgnoreLists.Destroys},
		IgnoreUpdates:  testhelper.Exemptions{List: SCALEIgnoreLists.Updates},
		TerraformVars:  terraformVars,
	}

	// Remove empty values from TerraformVars
	for key, value := range options.TerraformVars {
		if value == "" {
			delete(options.TerraformVars, key)
		}
	}

	return options, nil
}

func GetScaleVersionConfig() (string, error) {
	if defaultConfigFile == "" {
		return "", fmt.Errorf("default config file path is empty")
	}
	return defaultConfigFile, nil
}

// DefaultTest runs the default test using the provided Terraform directory and existing resource group.
// It provisions a cluster, waits for it to be ready, and then validates it.
func DefaultTest(t *testing.T) {
	setupTestSuite(t)
	if testLogger == nil {
		t.Fatal("Logger initialization failed")
	}
	testLogger.Info(t, fmt.Sprintf("Test %s starting execution", t.Name()))

	clusterNamePrefix := utils.GenerateTimestampedClusterPrefix(utils.GenerateRandomString())
	testLogger.Info(t, fmt.Sprintf("Generated cluster prefix: %s", clusterNamePrefix))

	envVars, err := GetEnvVars()
	if err != nil {
		testLogger.Error(t, fmt.Sprintf("Environment config error: %v", err))
	}
	require.NoError(t, err, "Environment configuration failed")

	options, err := setupOptions(t, clusterNamePrefix, terraformDir, envVars.ExistingResourceGroup)
	if err != nil {
		testLogger.Error(t, fmt.Sprintf("Test setup error: %v", err))
	}
	require.NoError(t, err, "Test options initialization failed")

	output, err := options.RunTestConsistency()
	if err != nil {
		testLogger.FAIL(t, fmt.Sprintf("Provisioning failed: %v", err))
	}
	require.NoError(t, err, "Cluster provisioning failed with output: %v", output)
	require.NotNil(t, output, "Received nil output from provisioning")

	testLogger.PASS(t, fmt.Sprintf("Test %s completed successfully", t.Name()))
}
