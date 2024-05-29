package tests

import (
	"fmt"
	"os"
	"strings"

	"github.com/terraform-ibm-modules/ibmcloud-terratest-wrapper/common"
	"gopkg.in/yaml.v3"
)

var (
	ip                 string
	reservationIDSouth string
	reservationIDEast  string
	permanentResources map[string]interface{}
)

// Define a struct with fields that match the structure of the YAML data
const yamlLocation = "../common-dev-assets/common-go-assets/common-permanent-resources.yaml"

// Config represents the structure of the configuration file.
type Config struct {
	DefaultResourceGroup       string `yaml:"default_resource_group"`
	NonDefaultResourceGroup    string `yaml:"non_default_resource_group"`
	Zone                       string `yaml:"zone"`
	ClusterID                  string `yaml:"cluster_id"`
	ReservationID              string `yaml:"reservation_id"`
	RemoteAllowedIPs           string `yaml:"remote_allowed_ips"`
	SSHKey                     string `yaml:"ssh_key"`
	LoginNodeInstanceType      string `yaml:"login_node_instance_type"`
	LoginNodeImageName         string `yaml:"login_image_name"`
	ManagementImageName        string `yaml:"management_image_name"`
	ComputeImageName           string `yaml:"compute_image_name"`
	ManagementNodeInstanceType string `yaml:"management_node_instance_type"`
	ManagementNodeCount        int    `yaml:"management_node_count"`
	EnableVPCFlowLogs          bool   `yaml:"enable_vpc_flow_logs"`
	KeyManagement              string `yaml:"key_management"`
	KMSInstanceName            string `yaml:"kms_instance_name"`
	KMSKeyName                 string `yaml:"kms_key_name"`
	HyperthreadingEnabled      bool   `yaml:"hyperthreading_enabled"`
	DnsDomainName              string `yaml:"dns_domain_name"`
	EnableAppCenter            bool   `yaml:"enable_app_center"`
	AppCenterGuiPassword       string `yaml:"app_center_gui_pwd"` // pragma: allowlist secret
	EnableLdap                 bool   `yaml:"enable_ldap"`
	LdapBaseDns                string `yaml:"ldap_basedns"`
	LdapServer                 string `yaml:"ldap_server"`
	LdapAdminPassword          string `yaml:"ldap_admin_password"` // pragma: allowlist secret
	LdapUserName               string `yaml:"ldap_user_name"`
	LdapUserPassword           string `yaml:"ldap_user_password"` // pragma: allowlist secret
	USEastZone                 string `yaml:"us_east_zone"`
	USEastClusterID            string `yaml:"us_east_cluster_id"`
	USEastReservationID        string `yaml:"us_east_reservation_id"`
	EUDEZone                   string `yaml:"eu_de_zone"`
	EUDEClusterID              string `yaml:"eu_de_cluster_id"`
	EUDEReservationID          string `yaml:"eu_de_reservation_id"`
	USSouthZone                string `yaml:"us_south_zone"`
	USSouthClusterID           string `yaml:"us_south_cluster_id"`
	USSouthReservationID       string `yaml:"us_south_reservation_id"`
	SSHFilePath                string `yaml:"ssh_file_path"`
}

// GetConfigFromYAML reads configuration from a YAML file and sets environment variables based on the configuration.
// It returns a Config struct populated with the configuration values.
func GetConfigFromYAML(filePath string) (Config, error) {
	var config Config

	file, err := os.Open(filePath)
	if err != nil {
		return config, fmt.Errorf("failed to open YAML file %s: %v", filePath, err)
	}
	defer file.Close()

	err = yaml.NewDecoder(file).Decode(&config)
	if err != nil {
		return config, fmt.Errorf("failed to decode YAML: %v", err)
	}

	ip, err = GetPublicIP()
	if err != nil {
		return config, fmt.Errorf("failed to get remote allowed IPs: %v", err)
	}
	config.RemoteAllowedIPs = ip

	permanentResources, err = common.LoadMapFromYaml(yamlLocation)
	if err != nil {
		return config, err
	}

	// Retrieve reservation IDs from Secret Manager

	reservationIDEastPtr, err := GetSecretsManagerKey(
		permanentResources["secretsManagerGuid"].(string),
		permanentResources["secretsManagerRegion"].(string),
		permanentResources["reservation_id_secret_id"].(string),
	)

	if err != nil {

		fmt.Printf("error retrieving reservation id from secrets: %v", err) // pragma: allowlist secret

	} else if reservationIDEastPtr != nil {

		reservationIDEast = *reservationIDEastPtr

	}

	if err := setEnvFromConfig(&config); err != nil {
		return config, fmt.Errorf("failed to set environment variables: %v", err)
	}

	return config, nil
}

// setEnvFromConfig sets environment variables based on the provided configuration.
func setEnvFromConfig(config *Config) error {
	envVars := map[string]interface{}{
		"DEFAULT_RESOURCE_GROUP":        config.DefaultResourceGroup,
		"NON_DEFAULT_RESOURCE_GROUP":    config.NonDefaultResourceGroup,
		"ZONE":                          config.Zone,
		"CLUSTER_ID":                    config.ClusterID,
		"RESERVATION_ID":                config.ReservationID,
		"REMOTE_ALLOWED_IPS":            config.RemoteAllowedIPs,
		"SSH_KEY":                       config.SSHKey,
		"LOGIN_NODE_INSTANCE_TYPE":      config.LoginNodeInstanceType,
		"LOGIN_NODE_IMAGE_NAME":         config.LoginNodeImageName,
		"MANAGEMENT_IMAGE_NAME":         config.ManagementImageName,
		"COMPUTE_IMAGE_NAME":            config.ComputeImageName,
		"MANAGEMENT_NODE_INSTANCE_TYPE": config.ManagementNodeInstanceType,
		"MANAGEMENT_NODE_COUNT":         config.ManagementNodeCount,
		"ENABLE_VPC_FLOW_LOGS":          config.EnableVPCFlowLogs,
		"KEY_MANAGEMENT":                config.KeyManagement,
		"KMS_INSTANCE_NAME":             config.KMSInstanceName,
		"KMS_KEY_NAME":                  config.KMSKeyName,
		"HYPERTHREADING_ENABLED":        config.HyperthreadingEnabled,
		"DNS_DOMAIN_NAME":               config.DnsDomainName,
		"ENABLE_APP_CENTER":             config.EnableAppCenter,
		"APP_CENTER_GUI_PASSWORD":       config.AppCenterGuiPassword, //pragma: allowlist secret
		"ENABLE_LDAP":                   config.EnableLdap,
		"LDAP_BASEDNS":                  config.LdapBaseDns,
		"LDAP_SERVER":                   config.LdapServer,
		"LDAP_ADMIN_PASSWORD":           config.LdapAdminPassword, //pragma: allowlist secret
		"LDAP_USER_NAME":                config.LdapUserName,
		"LDAP_USER_PASSWORD":            config.LdapUserPassword, //pragma: allowlist secret
		"US_EAST_ZONE":                  config.USEastZone,
		"US_EAST_RESERVATION_ID":        config.USEastReservationID,
		"US_EAST_CLUSTER_ID":            config.USEastClusterID,
		"EU_DE_ZONE":                    config.EUDEZone,
		"EU_DE_RESERVATION_ID":          config.EUDEReservationID,
		"EU_DE_CLUSTER_ID":              config.EUDEClusterID,
		"US_SOUTH_ZONE":                 config.USSouthZone,
		"US_SOUTH_RESERVATION_ID":       config.USSouthReservationID,
		"US_SOUTH_CLUSTER_ID":           config.USSouthClusterID,
		"SSH_FILE_PATH":                 config.SSHFilePath,
	}

	for key, value := range envVars {
		val, ok := os.LookupEnv(key)
		switch {
		case strings.Contains(key, "KEY_MANAGEMENT") && val == "null" && ok:
			os.Setenv(key, "null")
		case strings.Contains(key, "REMOTE_ALLOWED_IPS") && !ok && value == "":
			os.Setenv(key, ip)
		case value != "" && !ok:
			switch v := value.(type) {
			case string:
				os.Setenv(key, v)
			case bool:
				os.Setenv(key, fmt.Sprintf("%t", v))
			case int:
				os.Setenv(key, fmt.Sprintf("%d", v))
			default:
				return fmt.Errorf("unsupported type for key %s", key)
			}
		}
	}

	for key, value := range envVars {
		_, ok := os.LookupEnv(key)
		switch {
		case key == "RESERVATION_ID" && !ok && value == "":
			os.Setenv("RESERVATION_ID", GetValueForKey(map[string]string{"us-south": reservationIDSouth, "us-east": reservationIDEast}, strings.ToLower(GetRegion(os.Getenv("ZONE")))))
		case key == "US_EAST_RESERVATION_ID" && !ok && value == "":
			os.Setenv("US_EAST_RESERVATION_ID", reservationIDEast)
		case key == "EU_DE_RESERVATION_ID" && !ok && value == "":
			os.Setenv("EU_DE_RESERVATION_ID", reservationIDEast)
		case key == "US_SOUTH_RESERVATION_ID" && !ok && value == "":
			os.Setenv("US_SOUTH_RESERVATION_ID", reservationIDSouth)
		}
	}
	return nil
}
