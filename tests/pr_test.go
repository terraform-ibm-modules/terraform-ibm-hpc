package tests

import (
	"fmt"
	"log"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"sync"
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/require"
	"github.com/terraform-ibm-modules/ibmcloud-terratest-wrapper/testhelper"

	utils "github.com/terraform-ibm-modules/terraform-ibm-hpc/utilities"
)

// Constants for better organization
const (
	// Path of the Terraform directory
	terraformDir = "solutions/hpc"
)

var ignoreDestroys = []string{
	"module.landing_zone_vsi.module.hpc.module.check_cluster_status.null_resource.remote_exec[0]",
	"module.landing_zone_vsi.module.hpc.module.check_node_status.null_resource.remote_exec[1]",
	"module.landing_zone_vsi.module.hpc.module.check_node_status.null_resource.remote_exec[0]",
	"module.landing_zone_vsi.module.hpc.module.check_node_status.null_resource.remote_exec[2]",
	"module.check_node_status.null_resource.remote_exec[0]",
	"module.landing_zone_vsi.module.wait_management_vsi_booted.null_resource.remote_exec[0]",
	"module.check_node_status.null_resource.remote_exec[1]",
	"module.landing_zone_vsi.module.wait_management_candidate_vsi_booted.null_resource.remote_exec[0]",
	"module.check_cluster_status.null_resource.remote_exec[0]",
	"module.landing_zone_vsi.module.hpc.module.landing_zone_vsi.module.wait_management_candidate_vsi_booted.null_resource.remote_exec[0]",
	"module.landing_zone_vsi.module.hpc.module.landing_zone_vsi.module.wait_management_vsi_booted.null_resource.remote_exec[0]",
	"module.landing_zone_vsi.module.do_management_vsi_configuration.null_resource.remote_exec_script_cp_files[1]",
	"module.landing_zone_vsi.module.do_management_vsi_configuration.null_resource.remote_exec_script_new_file[0]",
	"module.landing_zone_vsi.module.do_management_vsi_configuration.null_resource.remote_exec_script_cp_files[0]",
	"module.landing_zone_vsi.module.do_management_candidate_vsi_configuration.null_resource.remote_exec_script_new_file[0]",
	"module.landing_zone_vsi.module.do_management_candidate_vsi_configuration.null_resource.remote_exec_script_run[0]",
	"module.landing_zone_vsi[0].module.wait_management_vsi_booted.null_resource.remote_exec[0]",
	"module.landing_zone_vsi[0].module.lsf_entitlement[0].null_resource.remote_exec[0]",
	"module.landing_zone_vsi[0].module.wait_management_candidate_vsi_booted.null_resource.remote_exec[1]",
	"module.landing_zone_vsi[0].module.wait_management_candidate_vsi_booted.null_resource.remote_exec[0]",
	"module.landing_zone_vsi[0].module.wait_worker_vsi_booted[0].null_resource.remote_exec[0]",
	"module.check_node_status.null_resource.remote_exec[2]",
	"module.landing_zone_vsi[0].module.wait_worker_vsi_booted[0].null_resource.remote_exec[1]",
}

var ignoreUpdates = []string{
	"module.file_storage.ibm_is_share.share[0]",
	"module.file_storage.ibm_is_share.share[1]",
	"module.file_storage.ibm_is_share.share[2]",
	"module.file_storage.ibm_is_share.share[3]",
	"module.file_storage.ibm_is_share.share[4]",
}

// EnvVars stores environment variable values.
type EnvVars struct {
	DefaultResourceGroup                        string
	NonDefaultResourceGroup                     string
	Zone                                        string
	ClusterID                                   string
	ReservationID                               string
	RemoteAllowedIPs                            string
	SSHKey                                      string
	LoginNodeInstanceType                       string
	LoginNodeImageName                          string
	ManagementImageName                         string
	ComputeImageName                            string
	ManagementNodeInstanceType                  string
	ManagementNodeCount                         string
	KeyManagement                               string
	KMSInstanceName                             string
	KMSKeyName                                  string
	HyperthreadingEnabled                       string
	DnsDomainName                               string
	EnableAppCenter                             string
	AppCenterGuiPassword                        string
	EnableLdap                                  string
	LdapBaseDns                                 string
	LdapServer                                  string
	LdapAdminPassword                           string
	LdapUserName                                string
	LdapUserPassword                            string
	USEastZone                                  string
	USEastReservationID                         string
	USEastClusterID                             string
	EUDEZone                                    string
	EUDEReservationID                           string
	EUDEClusterID                               string
	SSHFilePath                                 string
	USSouthZone                                 string
	USSouthReservationID                        string
	USSouthClusterID                            string
	JPTokZone                                   string
	JPTokReservationID                          string
	JPTokClusterID                              string
	WorkerNodeMaxCount                          string
	WorkerNodeInstanceType                      string
	IBMCustomerNumber                           string
	Solution                                    string
	sccEnabled                                  string
	sccEventNotificationPlan                    string
	sccLocation                                 string
	observabilityMonitoringEnable               string
	observabilityMonitoringOnComputeNodesEnable string
}

// GetEnvVars retrieves environment variables.
func GetEnvVars() EnvVars {
	return EnvVars{
		DefaultResourceGroup:          os.Getenv("DEFAULT_RESOURCE_GROUP"),
		NonDefaultResourceGroup:       os.Getenv("NON_DEFAULT_RESOURCE_GROUP"),
		Zone:                          os.Getenv("ZONE"),
		ClusterID:                     os.Getenv("CLUSTER_ID"),
		ReservationID:                 os.Getenv("RESERVATION_ID"),
		RemoteAllowedIPs:              os.Getenv("REMOTE_ALLOWED_IPS"),
		SSHKey:                        os.Getenv("SSH_KEY"),
		LoginNodeInstanceType:         os.Getenv("LOGIN_NODE_INSTANCE_TYPE"),
		LoginNodeImageName:            os.Getenv("LOGIN_NODE_IMAGE_NAME"),
		ManagementImageName:           os.Getenv("MANAGEMENT_IMAGE_NAME"),
		ComputeImageName:              os.Getenv("COMPUTE_IMAGE_NAME"),
		ManagementNodeInstanceType:    os.Getenv("MANAGEMENT_NODE_INSTANCE_TYPE"),
		ManagementNodeCount:           os.Getenv("MANAGEMENT_NODE_COUNT"),
		KeyManagement:                 os.Getenv("KEY_MANAGEMENT"),
		KMSInstanceName:               os.Getenv("KMS_INSTANCE_NAME"),
		KMSKeyName:                    os.Getenv("KMS_KEY_NAME"),
		HyperthreadingEnabled:         os.Getenv("HYPERTHREADING_ENABLED"),
		DnsDomainName:                 os.Getenv("DNS_DOMAIN_NAME"),
		EnableAppCenter:               os.Getenv("ENABLE_APP_CENTER"),
		AppCenterGuiPassword:          os.Getenv("APP_CENTER_GUI_PASSWORD"),
		EnableLdap:                    os.Getenv("ENABLE_LDAP"),
		LdapBaseDns:                   os.Getenv("LDAP_BASEDNS"),
		LdapServer:                    os.Getenv("LDAP_SERVER"),
		LdapAdminPassword:             os.Getenv("LDAP_ADMIN_PASSWORD"),
		LdapUserName:                  os.Getenv("LDAP_USER_NAME"),
		LdapUserPassword:              os.Getenv("LDAP_USER_PASSWORD"),
		USEastZone:                    os.Getenv("US_EAST_ZONE"),
		USEastReservationID:           os.Getenv("US_EAST_RESERVATION_ID"),
		USEastClusterID:               os.Getenv("US_EAST_CLUSTER_ID"),
		EUDEZone:                      os.Getenv("EU_DE_ZONE"),
		EUDEReservationID:             os.Getenv("EU_DE_RESERVATION_ID"),
		EUDEClusterID:                 os.Getenv("EU_DE_CLUSTER_ID"),
		USSouthZone:                   os.Getenv("US_SOUTH_ZONE"),
		USSouthReservationID:          os.Getenv("US_SOUTH_RESERVATION_ID"),
		USSouthClusterID:              os.Getenv("US_SOUTH_CLUSTER_ID"),
		JPTokZone:                     os.Getenv("JP_TOK_ZONE"),
		JPTokReservationID:            os.Getenv("JP_TOK_RESERVATION_ID"),
		JPTokClusterID:                os.Getenv("JP_TOK_CLUSTER_ID"),
		SSHFilePath:                   os.Getenv("SSH_FILE_PATH"),
		WorkerNodeMaxCount:            os.Getenv("WORKER_NODE_MAX_COUNT"),     //LSF specific parameter
		WorkerNodeInstanceType:        os.Getenv("WORKER_NODE_INSTANCE_TYPE"), //LSF specific parameter
		IBMCustomerNumber:             os.Getenv("IBM_CUSTOMER_NUMBER"),       //LSF specific parameter
		Solution:                      os.Getenv("SOLUTION"),
		sccEnabled:                    os.Getenv("SCC_ENABLED"),
		sccEventNotificationPlan:      os.Getenv("SCC_EVENT_NOTIFICATION_PLAN"),
		sccLocation:                   os.Getenv("SCC_LOCATION"),
		observabilityMonitoringEnable: os.Getenv("OBSERVABILITY_MONITORING_ENABLE"),
		observabilityMonitoringOnComputeNodesEnable: os.Getenv("OBSERVABILITY_MONITORING_ON_COMPUTE_NODES_ENABLE"),
	}
}

var (
	// testLogger stores the logger instance for logging test messages.
	testLogger *utils.AggregatedLogger
	// loggerErr stores the error occurred during logger initialization.
	loggerErr error
	// testSuiteInitialized indicates whether the test suite has been initialized.
	testSuiteInitialized bool
)

// setupTestSuite initializes the test suite.
func setupTestSuite(t *testing.T) {
	if !testSuiteInitialized {
		fmt.Println("Started executing the test suite...")
		// timestamp := time.Now().Format("2006-01-02_15-04-05")
		if validationLogFilePrefix, ok := os.LookupEnv("LOG_FILE_NAME"); ok {
			fileName := strings.Split(validationLogFilePrefix, ".json")[0]
			logFileName := fmt.Sprintf("%s.log", fileName)
			testLogger, loggerErr = utils.NewAggregatedLogger(logFileName)
			if loggerErr != nil {
				t.Fatalf("Error initializing logger: %v", loggerErr)
			}
			testSuiteInitialized = true
		}
	}
}

var upgradeOnce sync.Once // Ensures upgrade is performed only once

func UpgradeTerraformOnce(t *testing.T, terraformOptions *terraform.Options) {
	upgradeOnce.Do(func() {
		testLogger.Info(t, "Running Terraform upgrade with `-upgrade=true`...")

		// Run terraform upgrade command
		output, err := terraform.RunTerraformCommandE(t, terraformOptions, "init", "-upgrade=true")
		require.NoError(t, err, "Terraform upgrade failed")

		// Log the Terraform upgrade output in case of any failures
		testLogger.FAIL(t, fmt.Sprintf("Terraform upgrade output:\n%s", output))
	})
}

// validateEnvVars validates required environment variables based on the solution type.
func validateEnvVars(solution string, envVars EnvVars) error {
	var requiredVars []string

	// Determine required variables based on the solution type
	if strings.Contains(solution, "hpc") {
		requiredVars = []string{"SSHKey", "ClusterID", "Zone", "ReservationID"}
	} else if strings.Contains(solution, "lsf") {
		requiredVars = []string{"SSHKey", "ClusterID", "Zone", "IBMCustomerNumber"}
	} else {
		return fmt.Errorf("invalid solution type: %s", solution)
	}

	// Validate if the required variables are set
	for _, fieldName := range requiredVars {
		if fieldValue := reflect.ValueOf(envVars).FieldByName(fieldName).String(); fieldValue == "" {
			return fmt.Errorf("missing required environment variable: %s", fieldName)
		}
	}
	return nil
}

// setupOptionsVpc creates a test options object with the given parameters to creating brand new vpc
func setupOptionsVpc(t *testing.T, hpcClusterPrefix, terraformDir, resourceGroup string) (*testhelper.TestOptions, error) {

	// Check if TF_VAR_ibmcloud_api_key is set
	if os.Getenv("TF_VAR_ibmcloud_api_key") == "" {
		return nil, fmt.Errorf("TF_VAR_ibmcloud_api_key is not set")
	}

	// Retrieve environment variables
	envVars := GetEnvVars()

	// Validate required environment variables
	requiredVars := []string{"SSHKey", "Zone"}
	for _, fieldName := range requiredVars {
		// Check if the field value is empty
		if fieldValue := reflect.ValueOf(envVars).FieldByName(fieldName).String(); fieldValue == "" {
			return nil, fmt.Errorf("missing required environment variable: %s", fieldName)
		}
	}

	// Generate timestamped cluster prefix
	prefix := utils.GenerateTimestampedClusterPrefix(hpcClusterPrefix)

	// Create test options
	options := &testhelper.TestOptions{
		Testing:        t,
		TerraformDir:   terraformDir,
		IgnoreDestroys: testhelper.Exemptions{List: ignoreDestroys},
		TerraformVars: map[string]interface{}{
			"cluster_prefix":     prefix,
			"bastion_ssh_keys":   utils.SplitAndTrim(envVars.SSHKey, ","),
			"zones":              utils.SplitAndTrim(envVars.Zone, ","),
			"remote_allowed_ips": utils.SplitAndTrim(envVars.RemoteAllowedIPs, ","),
			"resource_group":     resourceGroup,
		},
	}
	return options, nil
}

// setupOptions creates a test options object with the given parameters.
func setupOptions(t *testing.T, hpcClusterPrefix, terraformDir, resourceGroup string, ignoreDestroys []string, ignoreUpdates []string) (*testhelper.TestOptions, error) {

	// Check if TF_VAR_ibmcloud_api_key is set
	if os.Getenv("TF_VAR_ibmcloud_api_key") == "" {
		return nil, fmt.Errorf("TF_VAR_ibmcloud_api_key is not set")
	}

	// Lookup environment variable for solution type
	solution, ok := os.LookupEnv("SOLUTION")
	if !ok || solution == "" {
		return nil, fmt.Errorf("SOLUTION environment variable not set")
	}

	// Convert solution to lowercase for consistency
	solution = strings.ToLower(solution)

	// Retrieve environment variables
	envVars := GetEnvVars()

	// Validate environment variables based on solution type
	if err := validateEnvVars(solution, envVars); err != nil {
		return nil, err
	}

	// Generate timestamped cluster prefix
	prefix := utils.GenerateTimestampedClusterPrefix(hpcClusterPrefix)

	// Create test options
	options := &testhelper.TestOptions{
		Testing:        t,
		TerraformDir:   terraformDir,
		IgnoreDestroys: testhelper.Exemptions{List: ignoreDestroys},
		IgnoreUpdates:  testhelper.Exemptions{List: ignoreUpdates},
		TerraformVars: map[string]interface{}{
			"cluster_prefix":                prefix,
			"bastion_ssh_keys":              utils.SplitAndTrim(envVars.SSHKey, ","),
			"compute_ssh_keys":              utils.SplitAndTrim(envVars.SSHKey, ","),
			"zones":                         utils.SplitAndTrim(envVars.Zone, ","),
			"remote_allowed_ips":            utils.SplitAndTrim(envVars.RemoteAllowedIPs, ","),
			"cluster_id":                    envVars.ClusterID,
			"reservation_id":                envVars.ReservationID,
			"resource_group":                resourceGroup,
			"login_node_instance_type":      envVars.LoginNodeInstanceType,
			"login_image_name":              envVars.LoginNodeImageName,
			"management_image_name":         envVars.ManagementImageName,
			"management_node_instance_type": envVars.ManagementNodeInstanceType,
			"management_node_count":         envVars.ManagementNodeCount,
			"compute_image_name":            envVars.ComputeImageName,
			"key_management":                envVars.KeyManagement,
			"hyperthreading_enabled":        strings.ToLower(envVars.HyperthreadingEnabled),
			"app_center_high_availability":  false,
			"observability_atracker_enable": false,
			"dns_domain_name":               map[string]string{"compute": envVars.DnsDomainName},
			"worker_node_max_count":         envVars.WorkerNodeMaxCount,     //LSF specific parameter
			"ibm_customer_number":           envVars.IBMCustomerNumber,      //LSF specific parameter
			"worker_node_instance_type":     envVars.WorkerNodeInstanceType, //LSF specific parameter
			"solution":                      envVars.Solution,
			"scc_enable":                    false,
		},
	}

	// Remove optional parameters based on solution type
	if solution == "hpc" {
		delete(options.TerraformVars, "worker_node_max_count")
		delete(options.TerraformVars, "worker_node_instance_type")
		delete(options.TerraformVars, "ibm_customer_number")

	}

	// Remove any variables with empty values
	for key, value := range options.TerraformVars {
		if value == "" {
			delete(options.TerraformVars, key)
		}
	}

	return options, nil
}

func TestMain(m *testing.M) {

	var solution string

	// Lookup environment variable
	if envSolution, ok := os.LookupEnv("SOLUTION"); ok {
		solution = envSolution
	} else {
		// Set default value if SOLUTION is not set
		solution = "lsf"
		_ = os.Setenv("SOLUTION", solution)
		log.Printf("SOLUTION environment variable is not set. Setting default value to: LSF")
	}

	// Convert the product name to lowercase and determine the config file
	solution = strings.ToLower(solution)
	var productFileName string
	switch solution {
	case "hpc":
		productFileName = "hpc_config.yml"
	case "lsf":
		productFileName = "lsf_config.yml"
	default:
		log.Fatalf("Invalid solution specified: %s", solution)
	}

	// Get the absolute path of the configuration file
	absPath, err := filepath.Abs(productFileName)
	if err != nil || absPath == "" {
		log.Fatalf("error getting absolute path for file %s: %v", productFileName, err)
	}

	// Check if the configuration file exists
	if _, err := os.Stat(absPath); os.IsNotExist(err) {
		log.Fatalf("Configuration file not found: %s", absPath)
	}

	// Load configuration from the YAML file
	config, err := utils.GetConfigFromYAML(absPath)
	if err != nil {
		log.Fatalf("Error reading configuration from YAML: %v", err)
	}
	log.Printf("Successfully loaded configuration: %+v", config)

	// Execute tests
	exitCode := m.Run()

	// Generate report if the JSON log file is set
	if jsonFileName, ok := os.LookupEnv("LOG_FILE_NAME"); ok {
		if _, err := os.Stat(jsonFileName); err == nil {
			results, err := utils.ParseJSONFile(jsonFileName)
			if err == nil {
				// Call the GenerateHTMLReport function and handle its return value
				err := utils.GenerateHTMLReport(results)
				if err != nil {
					// Log the error and take appropriate action
					log.Printf("Error generating HTML report: %v", err)
				}

			} else {
				log.Printf("Error generating HTML report: %v", err)
			}
		} else {
			log.Printf("JSON log file not found: %s", jsonFileName)
		}
	}

	// Exit with the test result code
	os.Exit(exitCode)
}

// TestRunDefault creates a basic HPC cluster and verifies its setup.
func TestRunDefault(t *testing.T) {
	// Run tests in parallel
	t.Parallel()

	// Initialize test suite
	setupTestSuite(t)

	// Log initiation of cluster creation
	testLogger.Info(t, "Initiating cluster creation for "+t.Name())

	// Generate a unique prefix for the HPC cluster
	hpcClusterPrefix := utils.GenerateRandomString()

	// Retrieve environment variables for the test
	envVars := GetEnvVars()

	// Prepare test options with necessary parameters
	options, err := setupOptions(t, hpcClusterPrefix, terraformDir, envVars.DefaultResourceGroup, ignoreDestroys, ignoreUpdates)
	if err != nil {
		testLogger.FAIL(t, fmt.Sprintf("Failed to set up test options: %v", err))
		require.NoError(t, err, "Failed to set up test options: %v", err)
	}

	// Run consistency test and handle potential errors
	output, err := options.RunTest()
	if err != nil {
		testLogger.FAIL(t, fmt.Sprintf("Error running consistency test: %v", err))
		require.NoError(t, err, "Error running consistency test: %v", err)
	}

	// Ensure that output is not nil
	require.NotNil(t, output, "Expected non-nil output, but got nil")

	// Log success if no errors occurred
	testLogger.PASS(t, "Test passed successfully")
}
