package tests

import (
	"encoding/json"
	"fmt"
	"log"
	"os"
	"strconv"
	"strings"

	utils "github.com/terraform-ibm-modules/terraform-ibm-hpc/utilities"
	"gopkg.in/yaml.v3"
)

// globalIP stores the public IP address
var globalIP string

// ManagementNodeInstances represents each management node instance.
type ManagementNodeInstances struct {
	Profile string `yaml:"profile" json:"profile"`
	Count   int    `yaml:"count" json:"count"`
	Image   string `yaml:"image" json:"image"`
}

// LoginNodeInstance represents  login node instance.
type LoginNodeInstance struct {
	Profile string `yaml:"profile" json:"profile"`
	Image   string `yaml:"image" json:"image"`
}

// BastionInstance represents bastion node instance.
type BastionInstance struct {
	Profile string `yaml:"profile" json:"profile"`
	Image   string `yaml:"image" json:"image"`
}

// DeployerInstance represents  deployer node instance.
type DeployerInstance struct {
	Profile string `yaml:"profile" json:"profile"`
	Image   string `yaml:"image" json:"image"`
}

// StaticWorkerInstances represents each static compute instance.
type StaticWorkerInstances struct {
	Profile string `yaml:"profile" json:"profile"`
	Count   int    `yaml:"count" json:"count"`
	Image   string `yaml:"image" json:"image"`
}

// DynamicWorkerInstances represents each dynamic compute instance.
type DynamicWorkerInstances struct {
	Profile string `yaml:"profile" json:"profile"`
	Count   int    `yaml:"count" json:"count"`
	Image   string `yaml:"image" json:"image"`
}

// LDAPServerNodeInstance represents each ldap node instance.
type LDAPServerNodeInstance struct {
	Profile string `yaml:"profile" json:"profile"`
	Image   string `yaml:"image" json:"image"`
	Count   int    `yaml:"count" json:"count"`
}

// CustomFileShare represents custom file share configuration.
type CustomFileShare struct {
	MountPath string `yaml:"mount_path" json:"mount_path"`
	Size      string `yaml:"size" json:"size"`
	IOPS      string `yaml:"iops" json:"iops"`
}

// DnsDomainNames represents DNS configuration.
type DnsDomainName struct {
	Compute string `yaml:"compute" json:"compute"`
}

// Config represents the YAML configuration.
type Config struct {
	BastionInstance                             BastionInstance           `yaml:"bastion_instance"`
	Scheduler                                   string                    `yaml:"scheduler"`
	DefaultExistingResourceGroup                string                    `yaml:"default_existing_resource_group"`
	NonDefaultExistingResourceGroup             string                    `yaml:"non_default_existing_resource_group"`
	Zones                                       string                    `yaml:"zones"`
	ClusterName                                 string                    `yaml:"cluster_name"`
	RemoteAllowedIPs                            string                    `yaml:"remote_allowed_ips"`
	SSHKeys                                     string                    `yaml:"ssh_keys"`
	DeployerInstance                            DeployerInstance          `yaml:"deployer_instance"`
	EnableVPCFlowLogs                           bool                      `yaml:"enable_vpc_flow_logs"`
	KeyManagement                               string                    `yaml:"key_management"`
	KMSInstanceName                             string                    `yaml:"kms_instance_name"`
	KMSKeyName                                  string                    `yaml:"kms_key_name"`
	EnableHyperthreading                        bool                      `yaml:"enable_hyperthreading"`
	DnsDomainName                               DnsDomainName             `yaml:"dns_domain_name"`
	EnableLdap                                  bool                      `yaml:"enable_ldap"`
	LdapBaseDns                                 string                    `yaml:"ldap_basedns"`
	LdapAdminPassword                           string                    `yaml:"ldap_admin_password"` // pragma: allowlist secret
	LdapUserName                                string                    `yaml:"ldap_user_name"`
	LdapUserPassword                            string                    `yaml:"ldap_user_password"` // pragma: allowlist secret
	LdapInstance                                []LDAPServerNodeInstance  `yaml:"ldap_instance"`
	USEastZone                                  string                    `yaml:"us_east_zone"`
	USEastClusterName                           string                    `yaml:"us_east_cluster_name"`
	JPTokZone                                   string                    `yaml:"jp_tok_zone"`
	JPTokClusterName                            string                    `yaml:"jp_tok_cluster_name"`
	EUDEZone                                    string                    `yaml:"eu_de_zone"`
	EUDEClusterName                             string                    `yaml:"eu_de_cluster_name"`
	USSouthZone                                 string                    `yaml:"us_south_zone"`
	USSouthClusterName                          string                    `yaml:"us_south_cluster_name"`
	SSHFilePath                                 string                    `yaml:"ssh_file_path"`
	SSHFilePathTwo                              string                    `yaml:"ssh_file_path_two"`
	StaticComputeInstances                      []StaticWorkerInstances   `yaml:"static_compute_instances"`
	DynamicComputeInstances                     []DynamicWorkerInstances  `yaml:"dynamic_compute_instances"`
	SccEnabled                                  bool                      `yaml:"scc_enable"`
	SccEventNotificationPlan                    string                    `yaml:"scc_event_notification_plan"`
	SccLocation                                 string                    `yaml:"scc_location"`
	ObservabilityMonitoringEnable               bool                      `yaml:"observability_monitoring_enable"`
	ObservabilityMonitoringOnComputeNodesEnable bool                      `yaml:"observability_monitoring_on_compute_nodes_enable"`
	ObservabilityAtrackerEnable                 bool                      `yaml:"observability_atracker_enable"`
	ObservabilityAtrackerTargetType             string                    `yaml:"observability_atracker_target_type"`
	ObservabilityLogsEnableForManagement        bool                      `yaml:"observability_logs_enable_for_management"`
	ObservabilityLogsEnableForCompute           bool                      `yaml:"observability_logs_enable_for_compute"`
	ObservabilityEnablePlatformLogs             bool                      `yaml:"observability_enable_platform_logs"`
	ObservabilityEnableMetricsRouting           bool                      `yaml:"observability_enable_metrics_routing"`
	ObservabilityLogsRetentionPeriod            int                       `yaml:"observability_logs_retention_period"`
	ObservabilityMonitoringPlan                 string                    `yaml:"observability_monitoring_plan"`
	EnableCosIntegration                        bool                      `yaml:"enable_cos_integration"`
	CustomFileShares                            []CustomFileShare         `yaml:"custom_file_shares"`
	PlacementStrategy                           string                    `yaml:"placement_strategy"`
	ManagementInstances                         []ManagementNodeInstances `yaml:"management_instances"`
	ManagementInstancesImage                    string                    `yaml:"management_instances_image"`
	StaticComputeInstancesImage                 string                    `yaml:"static_compute_instances_image"`
	DynamicComputeInstancesImage                string                    `yaml:"dynamic_compute_instances_image"`
	AppCenterGuiPassword                        string                    `yaml:"app_center_gui_password"` // pragma: allowlist secret
	LsfVersion                                  string                    `yaml:"lsf_version"`
	LoginInstance                               []LoginNodeInstance       `yaml:"login_instance"`
	AttrackerTestZone                           string                    `yaml:"attracker_test_zone"`
}

// GetConfigFromYAML reads a YAML file and populates the Config struct.
func GetConfigFromYAML(filePath string) (*Config, error) {
	file, err := os.Open(filePath)
	if err != nil {
		return nil, fmt.Errorf("failed to open YAML file %s: %w", filePath, err)
	}
	defer func() {
		if closeErr := file.Close(); closeErr != nil {
			log.Printf("Warning: failed to close file %s: %v", filePath, closeErr)
		}
	}()

	var config Config
	if err := yaml.NewDecoder(file).Decode(&config); err != nil {
		return nil, fmt.Errorf("failed to decode YAML from %s: %w", filePath, err)
	}

	// Get the public IP
	globalIP, err = utils.GetPublicIP()
	if err != nil {
		return nil, fmt.Errorf("failed to get public IP: %w", err)
	}

	if err := setEnvFromConfig(&config); err != nil {
		return nil, fmt.Errorf("failed to set environment variables: %w", err)
	}

	return &config, nil
}

// setEnvFromConfig sets environment variables based on the provided configuration.
func setEnvFromConfig(config *Config) error {
	envVars := map[string]interface{}{
		"BASTION_INSTANCE":                    config.BastionInstance,
		"DEFAULT_EXISTING_RESOURCE_GROUP":     config.DefaultExistingResourceGroup,
		"NON_DEFAULT_EXISTING_RESOURCE_GROUP": config.NonDefaultExistingResourceGroup,
		"ZONES":                               config.Zones,
		"CLUSTER_NAME":                        config.ClusterName,
		"REMOTE_ALLOWED_IPS":                  config.RemoteAllowedIPs,
		"SSH_KEYS":                            config.SSHKeys,
		"DEPLOYER_INSTANCE":                   config.DeployerInstance,
		"ENABLE_VPC_FLOW_LOGS":                config.EnableVPCFlowLogs,
		"KEY_MANAGEMENT":                      config.KeyManagement,
		"KMS_INSTANCE_NAME":                   config.KMSInstanceName,
		"KMS_KEY_NAME":                        config.KMSKeyName,
		"ENABLE_HYPERTHREADING":               config.EnableHyperthreading,
		"DNS_DOMAIN_NAME":                     config.DnsDomainName,
		"ENABLE_LDAP":                         config.EnableLdap,
		"LDAP_BASEDNS":                        config.LdapBaseDns,
		"LDAP_ADMIN_PASSWORD":                 config.LdapAdminPassword, // pragma: allowlist secret
		"LDAP_USER_NAME":                      config.LdapUserName,
		"LDAP_USER_PASSWORD":                  config.LdapUserPassword, // pragma: allowlist secret
		"LDAP_INSTANCE":                       config.LdapInstance,
		"US_EAST_ZONE":                        config.USEastZone,
		"US_EAST_CLUSTER_NAME":                config.USEastClusterName,
		"EU_DE_ZONE":                          config.EUDEZone,
		"EU_DE_CLUSTER_NAME":                  config.EUDEClusterName,
		"US_SOUTH_ZONE":                       config.USSouthZone,
		"US_SOUTH_CLUSTER_NAME":               config.USSouthClusterName,
		"JP_TOK_ZONE":                         config.JPTokZone,
		"JP_TOK_CLUSTER_NAME":                 config.JPTokClusterName,
		"SSH_FILE_PATH":                       config.SSHFilePath,
		"SSH_FILE_PATH_TWO":                   config.SSHFilePathTwo,
		"SCHEDULER":                           config.Scheduler,
		"SCC_ENABLED":                         config.SccEnabled,
		"SCC_EVENT_NOTIFICATION_PLAN":         config.SccEventNotificationPlan,
		"SCC_LOCATION":                        config.SccLocation,
		"OBSERVABILITY_MONITORING_ENABLE":     config.ObservabilityMonitoringEnable,
		"OBSERVABILITY_MONITORING_ON_COMPUTE_NODES_ENABLE": config.ObservabilityMonitoringOnComputeNodesEnable,
		"OBSERVABILITY_ATRACKER_ENABLE":                    config.ObservabilityAtrackerEnable,
		"OBSERVABILITY_ATRACKER_TARGET_TYPE":               config.ObservabilityAtrackerTargetType,
		"OBSERVABILITY_LOGS_ENABLE_FOR_MANAGEMENT":         config.ObservabilityLogsEnableForManagement,
		"OBSERVABILITY_LOGS_ENABLE_FOR_COMPUTE":            config.ObservabilityLogsEnableForCompute,
		"OBSERVABILITY_ENABLE_PLATFORM_LOGS":               config.ObservabilityEnablePlatformLogs,
		"OBSERVABILITY_ENABLE_METRICS_ROUTING":             config.ObservabilityEnableMetricsRouting,
		"OBSERVABILITY_LOGS_RETENTION_PERIOD":              config.ObservabilityLogsRetentionPeriod,
		"OBSERVABILITY_MONITORING_PLAN":                    config.ObservabilityMonitoringPlan,
		"ENABLE_COS_INTEGRATION":                           config.EnableCosIntegration,
		"CUSTOM_FILE_SHARES":                               config.CustomFileShares,
		"PLACEMENT_STRATEGY":                               config.PlacementStrategy,
		"MANAGEMENT_INSTANCES":                             config.ManagementInstances,
		"MANAGEMENT_INSTANCES_IMAGE":                       config.ManagementInstancesImage,
		"STATIC_COMPUTE_INSTANCES_IMAGE":                   config.StaticComputeInstancesImage,
		"DYNAMIC_COMPUTE_INSTANCES_IMAGE":                  config.DynamicComputeInstancesImage,
		"APP_CENTER_GUI_PASSWORD":                          config.AppCenterGuiPassword, // pragma: allowlist secret
		"LSF_VERSION":                                      config.LsfVersion,
		"LOGIN_INSTANCE":                                   config.LoginInstance,
		"ATTRACKER_TEST_ZONE":                              config.AttrackerTestZone,
	}

	if err := processSliceConfigs(config, envVars); err != nil {
		return fmt.Errorf("error processing slice configurations: %w", err)
	}

	for key, value := range envVars {
		if err := setEnvironmentVariable(key, value); err != nil {
			return fmt.Errorf("failed to set environment variable %s: %w", key, err)
		}
	}

	return nil
}

// processSliceConfigs handles the JSON marshaling of slice configurations
func processSliceConfigs(config *Config, envVars map[string]interface{}) error {
	sliceProcessors := []struct {
		name      string
		instances interface{}
	}{
		{"STATIC_COMPUTE_INSTANCES", config.StaticComputeInstances},
		{"DYNAMIC_COMPUTE_INSTANCES", config.DynamicComputeInstances},
		{"MANAGEMENT_INSTANCES", config.ManagementInstances},
		{"LOGIN_INSTANCE", config.LoginInstance},
		{"CUSTOM_FILE_SHARES", config.CustomFileShares},
		{"LDAP_INSTANCE", config.LdapInstance},
	}

	for _, processor := range sliceProcessors {
		if processor.name == "CUSTOM_FILE_SHARES" {
			if err := checkFileShares(config.CustomFileShares); err != nil {
				return err
			}
		}
		if err := marshalToEnv(processor.name, processor.instances, envVars); err != nil {
			return err
		}
	}

	return nil
}

// checkFileShares validates file shares configuration
func checkFileShares(fileShares []CustomFileShare) error {
	for _, share := range fileShares {
		if share.MountPath == "" {
			log.Printf("Warning: FileShares MountPath is empty in configuration")
		}
	}
	return nil
}

// marshalToEnv marshals data to JSON and stores it in envVars map
func marshalToEnv(key string, data interface{}, envVars map[string]interface{}) error {
	jsonBytes, err := json.Marshal(data)
	if err != nil {
		return fmt.Errorf("failed to marshal %s: %w", key, err)
	}
	envVars[key] = string(jsonBytes)
	return nil
}

// setEnvironmentVariable sets a single environment variable with proper type handling
func setEnvironmentVariable(key string, value interface{}) error {
	if value == nil {
		return nil
	}

	if existing := os.Getenv(key); existing != "" {
		log.Printf("Environment variable %s is already set. Skipping overwrite.", key)
		return nil
	}

	if key == "REMOTE_ALLOWED_IPS" {
		return handleRemoteAllowedIPs(value)
	}

	switch v := value.(type) {
	case string:
		if v != "" {
			return os.Setenv(key, v)
		}
	case bool:
		return os.Setenv(key, strconv.FormatBool(v))
	case int:
		return os.Setenv(key, strconv.Itoa(v))
	case float64:
		return os.Setenv(key, strconv.FormatFloat(v, 'f', -1, 64))
	case []string:
		if len(v) > 0 {
			return os.Setenv(key, strings.Join(v, ","))
		}
	default:
		jsonBytes, err := json.Marshal(value)
		if err != nil {
			return fmt.Errorf("failed to marshal %s: %w", key, err)
		}
		return os.Setenv(key, string(jsonBytes))
	}

	return nil
}

// handleARemoteAllowedIPs handles special case for the remote_allowed_ips environment variable.
func handleRemoteAllowedIPs(value interface{}) error {
	// Assert value is of type string
	cidr, ok := value.(string)
	if !ok {
		return fmt.Errorf("remote_allowed_ips must be a string")
	}

	// Handle default/empty CIDR
	if cidr == "" || cidr == "0.0.0.0/0" {
		if globalIP == "" {
			return fmt.Errorf("globalIP is empty, cannot set REMOTE_ALLOWED_IPS")
		}
		return os.Setenv("REMOTE_ALLOWED_IPS", globalIP+"/32")
	}

	// Set environment variable
	return os.Setenv("REMOTE_ALLOWED_IPS", cidr)
}
