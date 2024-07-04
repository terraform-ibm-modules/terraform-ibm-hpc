package tests

import (
	"fmt"
	"log"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"
	"time"

	"github.com/stretchr/testify/require"
	"github.com/terraform-ibm-modules/ibmcloud-terratest-wrapper/testhelper"

	utils "github.com/terraform-ibm-modules/terraform-ibm-hpc/common_utils"
)

// Constants for better organization
const (
	// Path of the Terraform directory
	terraformDir = "solutions/hpc"
)

// Terraform resource names to ignore during consistency checks
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
}

// EnvVars stores environment variable values.
type EnvVars struct {
	DefaultResourceGroup       string
	NonDefaultResourceGroup    string
	Zone                       string
	ClusterID                  string
	ReservationID              string
	RemoteAllowedIPs           string
	SSHKey                     string
	LoginNodeInstanceType      string
	LoginNodeImageName         string
	ManagementImageName        string
	ComputeImageName           string
	ManagementNodeInstanceType string
	ManagementNodeCount        string
	KeyManagement              string
	KMSInstanceName            string
	KMSKeyName                 string
	HyperthreadingEnabled      string
	DnsDomainName              string
	EnableAppCenter            string
	AppCenterGuiPassword       string
	EnableLdap                 string
	LdapBaseDns                string
	LdapServer                 string
	LdapAdminPassword          string
	LdapUserName               string
	LdapUserPassword           string
	USEastZone                 string
	USEastReservationID        string
	USEastClusterID            string
	EUDEZone                   string
	EUDEReservationID          string
	EUDEClusterID              string
	SSHFilePath                string
	USSouthZone                string
	USSouthReservationID       string
	USSouthClusterID           string
}

// GetEnvVars retrieves environment variables.
func GetEnvVars() EnvVars {
	return EnvVars{
		DefaultResourceGroup:       os.Getenv("DEFAULT_RESOURCE_GROUP"),
		NonDefaultResourceGroup:    os.Getenv("NON_DEFAULT_RESOURCE_GROUP"),
		Zone:                       os.Getenv("ZONE"),
		ClusterID:                  os.Getenv("CLUSTER_ID"),
		ReservationID:              os.Getenv("RESERVATION_ID"),
		RemoteAllowedIPs:           os.Getenv("REMOTE_ALLOWED_IPS"),
		SSHKey:                     os.Getenv("SSH_KEY"),
		LoginNodeInstanceType:      os.Getenv("LOGIN_NODE_INSTANCE_TYPE"),
		LoginNodeImageName:         os.Getenv("LOGIN_NODE_IMAGE_NAME"),
		ManagementImageName:        os.Getenv("MANAGEMENT_IMAGE_NAME"),
		ComputeImageName:           os.Getenv("COMPUTE_IMAGE_NAME"),
		ManagementNodeInstanceType: os.Getenv("MANAGEMENT_NODE_INSTANCE_TYPE"),
		ManagementNodeCount:        os.Getenv("MANAGEMENT_NODE_COUNT"),
		KeyManagement:              os.Getenv("KEY_MANAGEMENT"),
		KMSInstanceName:            os.Getenv("KMS_INSTANCE_NAME"),
		KMSKeyName:                 os.Getenv("KMS_KEY_NAME"),
		HyperthreadingEnabled:      os.Getenv("HYPERTHREADING_ENABLED"),
		DnsDomainName:              os.Getenv("DNS_DOMAIN_NAME"),
		EnableAppCenter:            os.Getenv("ENABLE_APP_CENTER"),
		AppCenterGuiPassword:       os.Getenv("APP_CENTER_GUI_PASSWORD"),
		EnableLdap:                 os.Getenv("ENABLE_LDAP"),
		LdapBaseDns:                os.Getenv("LDAP_BASEDNS"),
		LdapServer:                 os.Getenv("LDAP_SERVER"),
		LdapAdminPassword:          os.Getenv("LDAP_ADMIN_PASSWORD"),
		LdapUserName:               os.Getenv("LDAP_USER_NAME"),
		LdapUserPassword:           os.Getenv("LDAP_USER_PASSWORD"),
		USEastZone:                 os.Getenv("US_EAST_ZONE"),
		USEastReservationID:        os.Getenv("US_EAST_RESERVATION_ID"),
		USEastClusterID:            os.Getenv("US_EAST_CLUSTER_ID"),
		EUDEZone:                   os.Getenv("EU_DE_ZONE"),
		EUDEReservationID:          os.Getenv("EU_DE_RESERVATION_ID"),
		EUDEClusterID:              os.Getenv("EU_DE_CLUSTER_ID"),
		USSouthZone:                os.Getenv("US_SOUTH_ZONE"),
		USSouthReservationID:       os.Getenv("US_SOUTH_RESERVATION_ID"),
		USSouthClusterID:           os.Getenv("US_SOUTH_CLUSTER_ID"),
		SSHFilePath:                os.Getenv("SSH_FILE_PATH"),
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
		timestamp := time.Now().Format("2006-01-02_15-04-05")
		logFileName := fmt.Sprintf("log_%s.log", timestamp)
		testLogger, loggerErr = utils.NewAggregatedLogger(logFileName)
		if loggerErr != nil {
			t.Fatalf("Error initializing logger: %v", loggerErr)
		}
		testSuiteInitialized = true
	}
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
func setupOptions(t *testing.T, hpcClusterPrefix, terraformDir, resourceGroup string, ignoreDestroys []string) (*testhelper.TestOptions, error) {

	// Check if TF_VAR_ibmcloud_api_key is set
	if os.Getenv("TF_VAR_ibmcloud_api_key") == "" {
		return nil, fmt.Errorf("TF_VAR_ibmcloud_api_key is not set")
	}

	// Retrieve environment variables
	envVars := GetEnvVars()

	// Validate required environment variables
	requiredVars := []string{"SSHKey", "ClusterID", "Zone", "ReservationID"}
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
			"cluster_prefix":                       prefix,
			"bastion_ssh_keys":                     utils.SplitAndTrim(envVars.SSHKey, ","),
			"compute_ssh_keys":                     utils.SplitAndTrim(envVars.SSHKey, ","),
			"zones":                                utils.SplitAndTrim(envVars.Zone, ","),
			"remote_allowed_ips":                   utils.SplitAndTrim(envVars.RemoteAllowedIPs, ","),
			"cluster_id":                           envVars.ClusterID,
			"reservation_id":                       envVars.ReservationID,
			"resource_group":                       resourceGroup,
			"login_node_instance_type":             envVars.LoginNodeInstanceType,
			"login_image_name":                     envVars.LoginNodeImageName,
			"management_image_name":                envVars.ManagementImageName,
			"management_node_instance_type":        envVars.ManagementNodeInstanceType,
			"management_node_count":                envVars.ManagementNodeCount,
			"compute_image_name":                   envVars.ComputeImageName,
			"key_management":                       envVars.KeyManagement,
			"hyperthreading_enabled":               strings.ToLower(envVars.HyperthreadingEnabled),
			"app_center_high_availability":         false,
			"observability_atracker_on_cos_enable": false,
			"dns_domain_name":                      map[string]string{"compute": envVars.DnsDomainName},
		},
	}

	// Remove parameters with empty values
	for key, value := range options.TerraformVars {
		if value == "" {
			delete(options.TerraformVars, key)
		}
	}

	return options, nil
}

func TestMain(m *testing.M) {

	absPath, err := filepath.Abs("test_config.yml")
	if err != nil {
		log.Fatalf("error getting absolute path: %v", err)
	}

	// Read configuration from yaml file
	_, err = utils.GetConfigFromYAML(absPath)
	if err != nil {
		log.Fatalf("error reading configuration from yaml: %v", err)
	}

	os.Exit(m.Run())

}

// TestRunDefault create basic cluster of an HPC cluster.
func TestRunDefault(t *testing.T) {

	// Parallelize the test
	t.Parallel()

	// Setup test suite
	setupTestSuite(t)

	testLogger.Info(t, "Cluster creation process initiated for "+t.Name())

	// HPC cluster prefix
	hpcClusterPrefix := utils.GenerateRandomString()

	// Retrieve cluster information from environment variables
	envVars := GetEnvVars()

	// Create test options
	options, err := setupOptions(t, hpcClusterPrefix, terraformDir, envVars.DefaultResourceGroup, ignoreDestroys)
	require.NoError(t, err, "Error setting up test options: %v", err)

	// Run the test and handle errors
	output, err := options.RunTestConsistency()
	require.NoError(t, err, "Error running consistency test: %v", err)
	require.NotNil(t, output, "Expected non-nil output, but got nil")

}
