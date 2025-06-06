package tests

import (
	"encoding/json"
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
)

// Define a struct with fields that match the structure of the YAML data
const yamlLocation = "../common-dev-assets/common-go-assets/common-permanent-resources.yaml"

// WorkerNode represents the structure of each worker node instance type.
type WorkerNode struct {
	Count        int    `yaml:"count"`
	InstanceType string `yaml:"instance_type"`
}

// Config represents the structure of the configuration file.
type Config struct {
	DefaultExistingResourceGroup                string       `yaml:"default_existing_resource_group"`
	NonDefaultExistingResourceGroup             string       `yaml:"non_default_existing_resource_group"`
	Zone                                        string       `yaml:"zone"`
	ClusterName                                 string       `yaml:"cluster_name"`
	ReservationID                               string       `yaml:"reservation_id"`
	RemoteAllowedIPs                            string       `yaml:"remote_allowed_ips"`
	SSHKey                                      string       `yaml:"ssh_key"`
	LoginNodeInstanceType                       string       `yaml:"login_node_instance_type"`
	LoginNodeImageName                          string       `yaml:"login_image_name"`
	ManagementImageName                         string       `yaml:"management_image_name"`
	ComputeImageName                            string       `yaml:"compute_image_name"`
	ManagementNodeInstanceType                  string       `yaml:"management_node_instance_type"`
	ManagementNodeCount                         int          `yaml:"management_node_count"`
	EnableVPCFlowLogs                           bool         `yaml:"enable_vpc_flow_logs"`
	KeyManagement                               string       `yaml:"key_management"`
	KMSInstanceName                             string       `yaml:"kms_instance_name"`
	KMSKeyName                                  string       `yaml:"kms_key_name"`
	HyperthreadingEnabled                       bool         `yaml:"hyperthreading_enabled"`
	DnsDomainName                               string       `yaml:"dns_domain_name"`
	EnableAppCenter                             bool         `yaml:"enable_app_center"`
	AppCenterGuiPassword                        string       `yaml:"app_center_gui_pwd"` // pragma: allowlist secret
	EnableLdap                                  bool         `yaml:"enable_ldap"`
	LdapBaseDns                                 string       `yaml:"ldap_basedns"`
	LdapServer                                  string       `yaml:"ldap_server"`
	LdapAdminPassword                           string       `yaml:"ldap_admin_password"` // pragma: allowlist secret
	LdapUserName                                string       `yaml:"ldap_user_name"`
	LdapUserPassword                            string       `yaml:"ldap_user_password"` // pragma: allowlist secret
	USEastZone                                  string       `yaml:"us_east_zone"`
	USEastClusterName                           string       `yaml:"us_east_cluster_name"`
	USEastReservationID                         string       `yaml:"us_east_reservation_id"`
	JPTokZone                                   string       `yaml:"jp_tok_zone"`
	JPTokClusterName                            string       `yaml:"jp_tok_cluster_name"`
	JPTokReservationID                          string       `yaml:"jp_tok_reservation_id"`
	EUDEZone                                    string       `yaml:"eu_de_zone"`
	EUDEClusterName                             string       `yaml:"eu_de_cluster_name"`
	EUDEReservationID                           string       `yaml:"eu_de_reservation_id"`
	USSouthZone                                 string       `yaml:"us_south_zone"`
	USSouthClusterName                          string       `yaml:"us_south_cluster_name"`
	USSouthReservationID                        string       `yaml:"us_south_reservation_id"`
	SSHFilePath                                 string       `yaml:"ssh_file_path"`
	SSHFilePathTwo                              string       `yaml:"ssh_file_path_two"`
	Solution                                    string       `yaml:"solution"`
	WorkerNodeMaxCount                          int          `yaml:"worker_node_max_count"`
	WorkerNodeInstanceType                      []WorkerNode `yaml:"worker_node_instance_type"`
	SccEnabled                                  bool         `yaml:"scc_enable"`
	SccEventNotificationPlan                    string       `yaml:"scc_event_notification_plan"`
	SccLocation                                 string       `yaml:"scc_location"`
	ObservabilityMonitoringEnable               bool         `yaml:"observability_monitoring_enable"`
	ObservabilityMonitoringOnComputeNodesEnable bool         `yaml:"observability_monitoring_on_compute_nodes_enable"`
}

// GetConfigFromYAML reads configuration from a YAML file and sets environment variables based on the configuration.
// It returns a Config struct populated with the configuration values.
func GetConfigFromYAML(filePath string) (*Config, error) {
	var config Config

	// Open the YAML file
	file, err := os.Open(filePath)
	if err != nil {
		return nil, fmt.Errorf("failed to open YAML file %s: %v", filePath, err)
	}

	defer func() {
		if err := file.Close(); err != nil {
			fmt.Printf("warning: failed to close file: %v\n", err)
		}
	}()

	// Decode the YAML file into the config struct
	if err := yaml.NewDecoder(file).Decode(&config); err != nil {
		return nil, fmt.Errorf("failed to decode YAML: %v", err)
	}

	// Get the public IP
	ip, err = GetPublicIP()
	if err != nil {
		return nil, fmt.Errorf("failed to get public IP: %v", err)
	}

	// Load permanent resources from YAML
	permanentResources, err := common.LoadMapFromYaml(yamlLocation)
	if err != nil {
		return nil, fmt.Errorf("failed to load permanent resources from YAML: %v", err)
	}

	// Retrieve reservation ID from Secret Manager                        // pragma: allowlist secret
	reservationIDVal, ok := permanentResources["reservation_id_secret_id"].(string)
	if !ok {
		fmt.Println("Invalid type or nil value for reservation_id_secret_id")
	}

	reservationIDEastPtr, err := GetSecretsManagerKey(
		permanentResources["secretsManagerGuid"].(string),
		permanentResources["secretsManagerRegion"].(string),
		reservationIDVal, // Pass safely extracted value
	)

	if err != nil {
		fmt.Printf("Error retrieving reservation ID from secrets: %v\n", err) // pragma: allowlist secret
	} else if reservationIDEastPtr != nil {
		reservationIDEast = *reservationIDEastPtr
	}

	// Set environment variables from config
	if err := setEnvFromConfig(&config); err != nil {
		return nil, fmt.Errorf("failed to set environment variables: %v", err)
	}
	return &config, nil
}

// setEnvFromConfig sets environment variables based on the provided configuration.
func setEnvFromConfig(config *Config) error {
	envVars := map[string]interface{}{
		"DEFAULT_EXISTING_RESOURCE_GROUP":     config.DefaultExistingResourceGroup,
		"NON_DEFAULT_EXISTING_RESOURCE_GROUP": config.NonDefaultExistingResourceGroup,
		"ZONE":                                config.Zone,
		"CLUSTER_NAME":                        config.ClusterName,
		"RESERVATION_ID":                      config.ReservationID,
		"REMOTE_ALLOWED_IPS":                  config.RemoteAllowedIPs,
		"SSH_KEY":                             config.SSHKey,
		"LOGIN_NODE_INSTANCE_TYPE":            config.LoginNodeInstanceType,
		"LOGIN_NODE_IMAGE_NAME":               config.LoginNodeImageName,
		"MANAGEMENT_IMAGE_NAME":               config.ManagementImageName,
		"COMPUTE_IMAGE_NAME":                  config.ComputeImageName,
		"MANAGEMENT_NODE_INSTANCE_TYPE":       config.ManagementNodeInstanceType,
		"MANAGEMENT_NODE_COUNT":               config.ManagementNodeCount,
		"ENABLE_VPC_FLOW_LOGS":                config.EnableVPCFlowLogs,
		"KEY_MANAGEMENT":                      config.KeyManagement,
		"KMS_INSTANCE_NAME":                   config.KMSInstanceName,
		"KMS_KEY_NAME":                        config.KMSKeyName,
		"HYPERTHREADING_ENABLED":              config.HyperthreadingEnabled,
		"DNS_DOMAIN_NAME":                     config.DnsDomainName,
		"ENABLE_APP_CENTER":                   config.EnableAppCenter,
		"APP_CENTER_GUI_PASSWORD":             config.AppCenterGuiPassword, //pragma: allowlist secret
		"ENABLE_LDAP":                         config.EnableLdap,
		"LDAP_BASEDNS":                        config.LdapBaseDns,
		"LDAP_SERVER":                         config.LdapServer,
		"LDAP_ADMIN_PASSWORD":                 config.LdapAdminPassword, //pragma: allowlist secret
		"LDAP_USER_NAME":                      config.LdapUserName,
		"LDAP_USER_PASSWORD":                  config.LdapUserPassword, //pragma: allowlist secret
		"US_EAST_ZONE":                        config.USEastZone,
		"US_EAST_RESERVATION_ID":              config.USEastReservationID,
		"US_EAST_CLUSTER_NAME":                config.USEastClusterName,
		"EU_DE_ZONE":                          config.EUDEZone,
		"EU_DE_RESERVATION_ID":                config.EUDEReservationID,
		"EU_DE_CLUSTER_NAME":                  config.EUDEClusterName,
		"US_SOUTH_ZONE":                       config.USSouthZone,
		"US_SOUTH_RESERVATION_ID":             config.USSouthReservationID,
		"US_SOUTH_CLUSTER_NAME":               config.USSouthClusterName,
		"JP_TOK_ZONE":                         config.JPTokZone,
		"JP_TOK_RESERVATION_ID":               config.JPTokReservationID,
		"JP_TOK_CLUSTER_NAME":                 config.JPTokClusterName,
		"SSH_FILE_PATH":                       config.SSHFilePath,
		"SSH_FILE_PATH_TWO":                   config.SSHFilePathTwo,
		"SOLUTION":                            config.Solution,
		"WORKER_NODE_MAX_COUNT":               config.WorkerNodeMaxCount, //LSF specific parameter
		"SCC_ENABLED":                         config.SccEnabled,
		"SCC_EVENT_NOTIFICATION_PLAN":         config.SccEventNotificationPlan,
		"SCC_LOCATION":                        config.SccLocation,
		"OBSERVABILITY_MONITORING_ENABLE":     config.ObservabilityMonitoringEnable,
		"OBSERVABILITY_MONITORING_ON_COMPUTE_NODES_ENABLE": config.ObservabilityMonitoringOnComputeNodesEnable,
	}

	// Format WorkerNodeInstanceType into JSON string
	if len(config.WorkerNodeInstanceType) > 0 {
		var formattedWorkerNodeInstanceType []map[string]interface{}
		for _, workerNode := range config.WorkerNodeInstanceType {
			// If instance_type is empty, provide a default
			if workerNode.InstanceType == "" {
				fmt.Printf("Warning: WorkerNode InstanceType is empty, setting to default\n")
			}

			node := map[string]interface{}{
				"count":         workerNode.Count,
				"instance_type": workerNode.InstanceType,
			}
			formattedWorkerNodeInstanceType = append(formattedWorkerNodeInstanceType, node)
		}

		// Marshal to JSON string
		workerNodeInstanceTypeJSON, err := json.Marshal(formattedWorkerNodeInstanceType)
		if err != nil {
			return fmt.Errorf("failed to marshal WORKER_NODE_INSTANCE_TYPE: %v", err)
		}

		envVars["WORKER_NODE_INSTANCE_TYPE"] = string(workerNodeInstanceTypeJSON)
	} else {
		envVars["WORKER_NODE_INSTANCE_TYPE"] = "[]" // Empty array if not set
	}

	// Set environment variables
	for key, value := range envVars {
		val, ok := os.LookupEnv(key)
		switch {
		case strings.Contains(key, "KEY_MANAGEMENT") && val == "null" && ok:
			if err := os.Setenv(key, "null"); err != nil {
				return fmt.Errorf("failed to set %s to 'null': %v", key, err)
			}
		case strings.Contains(key, "REMOTE_ALLOWED_IPS") && !ok && value == "":
			if err := os.Setenv(key, ip); err != nil {
				return fmt.Errorf("failed to set %s to %s: %v", key, ip, err)
			}
		case value != "" && !ok:
			switch v := value.(type) {
			case string:
				if err := os.Setenv(key, v); err != nil {
					return fmt.Errorf("failed to set %s to %s: %v", key, v, err)
				}
			case bool:
				if err := os.Setenv(key, fmt.Sprintf("%t", v)); err != nil {
					return fmt.Errorf("failed to set %s to %t: %v", key, v, err)
				}
			case int:
				if err := os.Setenv(key, fmt.Sprintf("%d", v)); err != nil {
					return fmt.Errorf("failed to set %s to %d: %v", key, v, err)
				}
			case float64:
				if err := os.Setenv(key, fmt.Sprintf("%f", v)); err != nil {
					return fmt.Errorf("failed to set %s to %f: %v", key, v, err)
				}
			case []string:
				if err := os.Setenv(key, strings.Join(v, ",")); err != nil {
					return fmt.Errorf("failed to set %s to joined string: %v", key, err)
				}
			case []WorkerNode:
				workerNodeInstanceTypeJSON, err := json.Marshal(v)
				if err != nil {
					return fmt.Errorf("failed to marshal %s: %v", key, err)
				}
				if err := os.Setenv(key, string(workerNodeInstanceTypeJSON)); err != nil {
					return fmt.Errorf("failed to set %s to JSON: %v", key, err)
				}
			default:
				return fmt.Errorf("unsupported type for key %s", key)
			}
		}
	}

	// Handle missing reservation IDs if necessary
	for key, value := range envVars {
		_, ok := os.LookupEnv(key)
		switch {
		case key == "RESERVATION_ID" && !ok && value == "":
			val := GetValueForKey(
				map[string]string{
					"us-south": reservationIDSouth,
					"us-east":  reservationIDEast,
				},
				strings.ToLower(GetRegion(os.Getenv("ZONE"))),
			)
			if err := os.Setenv("RESERVATION_ID", val); err != nil {
				return fmt.Errorf("failed to set RESERVATION_ID: %v", err)
			}
		case key == "US_EAST_RESERVATION_ID" && !ok && value == "":
			if err := os.Setenv("US_EAST_RESERVATION_ID", reservationIDEast); err != nil {
				return fmt.Errorf("failed to set US_EAST_RESERVATION_ID: %v", err)
			}
		case key == "EU_DE_RESERVATION_ID" && !ok && value == "":
			if err := os.Setenv("EU_DE_RESERVATION_ID", reservationIDEast); err != nil {
				return fmt.Errorf("failed to set EU_DE_RESERVATION_ID: %v", err)
			}
		case key == "US_SOUTH_RESERVATION_ID" && !ok && value == "":
			if err := os.Setenv("US_SOUTH_RESERVATION_ID", reservationIDSouth); err != nil {
				return fmt.Errorf("failed to set US_SOUTH_RESERVATION_ID: %v", err)
			}
		}
	}

	return nil
}
