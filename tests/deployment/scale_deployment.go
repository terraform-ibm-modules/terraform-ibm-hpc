package tests

import (
	"encoding/json"
	"fmt"
	"log"
	"os"
	"strconv"
	"strings"

	"github.com/terraform-ibm-modules/ibmcloud-terratest-wrapper/common"
	utils "github.com/terraform-ibm-modules/terraform-ibm-hpc/utilities"
	"gopkg.in/yaml.v3"
)

var scaleGlobalIP string
var IbmCustomerNumberValue string

const yamlLocation = "../common-dev-assets/common-go-assets/common-permanent-resources.yaml"

type ClientInstance struct {
	Profile string `yaml:"profile" json:"profile"`
	Count   int    `yaml:"count" json:"count"`
	Image   string `yaml:"image" json:"image"`
}

type ProtocolInstance struct {
	Profile string `yaml:"profile" json:"profile"`
	Count   int    `yaml:"count" json:"count"`
	Image   string `yaml:"image" json:"image"`
}

type ComputeInstance struct {
	Profile    string `yaml:"profile" json:"profile"`
	Count      int    `yaml:"count" json:"count"`
	Image      string `yaml:"image" json:"image"`
	Filesystem string `yaml:"filesystem" json:"filesystem"`
}

type StorageInstance struct {
	Profile    string `yaml:"profile" json:"profile"`
	Count      int    `yaml:"count" json:"count"`
	Image      string `yaml:"image" json:"image"`
	Filesystem string `yaml:"filesystem" json:"filesystem"`
}

type ScaleDeployerInstance struct {
	Profile string `yaml:"profile" json:"profile"`
	Image   string `yaml:"image" json:"image"`
}

// GKLMInstance represents GKLM node configuration
type GKLMInstance struct {
	Profile string `yaml:"profile" json:"profile"`
	Count   int    `yaml:"count" json:"count"`
	Image   string `yaml:"image" json:"image"`
}

// FilesystemConfig represents filesystem configuration
type FilesystemConfig struct {
	Filesystem             string `yaml:"filesystem" json:"filesystem"`
	BlockSize              string `yaml:"block_size" json:"block_size"`
	DefaultDataReplica     int    `yaml:"default_data_replica" json:"default_data_replica"`
	DefaultMetadataReplica int    `yaml:"default_metadata_replica" json:"default_metadata_replica"`
	MaxDataReplica         int    `yaml:"max_data_replica" json:"max_data_replica"`
	MaxMetadataReplica     int    `yaml:"max_metadata_replica" json:"max_metadata_replica"`
}

// FilesetConfig represents fileset configuration
type FilesetConfig struct {
	ClientMountPath string `yaml:"client_mount_path" json:"client_mount_path"`
	Quota           int    `yaml:"quota" json:"quota"`
}

// DNSDomainNames represents DNS configuration
type DNSDomainNames struct {
	Compute  string `yaml:"compute" json:"compute"`
	Storage  string `yaml:"storage" json:"storage"`
	Protocol string `yaml:"protocol" json:"protocol"`
	Client   string `yaml:"client" json:"client"`
	GKLM     string `yaml:"gklm" json:"gklm"`
}

type AfmInstance struct {
	Profile string `yaml:"profile" json:"profile"`
	Count   int    `yaml:"count" json:"count"`
	Image   string `yaml:"image" json:"image"`
}

type ScaleConfig struct {
	ScaleVersion                         string                `yaml:"scale_version" json:"scale_version"`
	IbmCustomerNumber                    string                `yaml:"ibm_customer_number" json:"ibm_customer_number"`
	Zones                                []string              `yaml:"zones" json:"zones"`
	RemoteAllowedIPs                     []string              `yaml:"remote_allowed_ips" json:"remote_allowed_ips"`
	ExistingResourceGroup                string                `yaml:"existing_resource_group" json:"existing_resource_group"`
	StorageType                          string                `yaml:"storage_type" json:"storage_type"`
	SSHKeys                              string                `yaml:"ssh_keys" json:"ssh_keys"`
	ScaleDeployerInstance                ScaleDeployerInstance `yaml:"deployer_instance" json:"deployer_instance"`
	ComputeGUIUsername                   string                `yaml:"compute_gui_username" json:"compute_gui_username"`
	ComputeGUIPassword                   string                `yaml:"compute_gui_password" json:"compute_gui_password"`
	StorageGUIUsername                   string                `yaml:"storage_gui_username" json:"storage_gui_username"`
	StorageGUIPassword                   string                `yaml:"storage_gui_password" json:"storage_gui_password"`
	ComputeInstances                     []ComputeInstance     `yaml:"compute_instances" json:"compute_instances"`
	ClientInstances                      []ClientInstance      `yaml:"client_instances" json:"client_instances"`
	StorageInstances                     []StorageInstance     `yaml:"storage_instances" json:"storage_instances"`
	ScaleEncryptionEnabled               bool                  `yaml:"scale_encryption_enabled" json:"scale_encryption_enabled"`
	ScaleEncryptionType                  string                `yaml:"scale_encryption_type" json:"scale_encryption_type"`
	ScaleObservabilityAtrackerEnable     bool                  `yaml:"observability_atracker_enable" json:"observability_atracker_enable"`
	ScaleObservabilityAtrackerTargetType string                `yaml:"observability_atracker_target_type" json:"observability_atracker_target_type"`
	ScaleSCCWPEnable                     bool                  `yaml:"sccwp_enable" json:"sccwp_enable"`
	ScaleCSPMEnabled                     bool                  `yaml:"cspm_enabled" json:"cspm_enabled"`
	ScaleSCCWPServicePlan                string                `yaml:"sccwp_service_plan" json:"sccwp_service_plan"`
	GKLMInstances                        []GKLMInstance        `yaml:"gklm_instances" json:"gklm_instances"`
	ScaleEncryptionAdminPassword         string                `yaml:"scale_encryption_admin_password" json:"scale_encryption_admin_password"` // pragma: allowlist secret
	ScaleFilesystemConfig                []FilesystemConfig    `yaml:"filesystem_config" json:"filesystem_config"`
	ScaleFilesetsConfig                  []FilesetConfig       `yaml:"filesets_config" json:"filesets_config"`
	ScaleDNSDomainNames                  DNSDomainNames        `yaml:"dns_domain_names" json:"dns_domain_names"`
	ScaleEnableCOSIntegration            bool                  `yaml:"enable_cos_integration" json:"enable_cos_integration"`
	ScaleEnableVPCFlowLogs               bool                  `yaml:"enable_vpc_flow_logs" json:"enable_vpc_flow_logs"`
	AfmInstances                         []AfmInstance         `yaml:"afm_instances" json:"afm_instances"`
	ProtocolInstances                    []ProtocolInstance    `yaml:"protocol_instances" json:"protocol_instances"`
}

func GetScaleConfigFromYAML(filePath string) (*ScaleConfig, error) {
	file, err := os.Open(filePath)
	if err != nil {
		return nil, fmt.Errorf("failed to open YAML file: %w", err)
	}

	defer func() {
		if closeErr := file.Close(); closeErr != nil {
			log.Printf("Warning: failed to close file %s: %v", filePath, closeErr)
		}
	}()

	var config ScaleConfig
	if err := yaml.NewDecoder(file).Decode(&config); err != nil {
		return nil, fmt.Errorf("failed to decode YAML: %w", err)
	}

	scaleGlobalIP, err = utils.GetPublicIP()
	if err != nil {
		return nil, fmt.Errorf("failed to get public IP: %w", err)
	}

	// Load permanent resources from YAML
	permanentResources, err := common.LoadMapFromYaml(yamlLocation)
	if err != nil {
		return nil, fmt.Errorf("failed to load permanent resources from YAML: %v", err)
	}

	// Retrieve ibmCustomerNumberSecretID from Secrets Manager                        // pragma: allowlist secret
	ibmCustomerNumberSecretID, ok := permanentResources["hpc_ibm_customer_number_secret_id"].(string)
	if !ok {
		fmt.Println("Invalid type or nil value for hpc_ibm_customer_number_secret_id")
	} else {
		ibmCustomerNumberValue, err := utils.GetSecretsManagerKey(
			permanentResources["secretsManagerGuid"].(string),
			permanentResources["secretsManagerRegion"].(string),
			ibmCustomerNumberSecretID, // Safely extracted value
		)

		if err != nil {
			fmt.Printf("WARN : Retrieving ibmCustomerNumberSecretID from Secrets Manager") // pragma: allowlist secret
		} else if ibmCustomerNumberValue != nil {
			IbmCustomerNumberValue = *ibmCustomerNumberValue
		}
	}

	if err := scaleSetEnvFromConfig(&config); err != nil {
		return nil, fmt.Errorf("failed to set environment variables: %w", err)
	}

	return &config, nil
}

func scaleSetEnvFromConfig(config *ScaleConfig) error {
	envVars := map[string]interface{}{
		"SCALE_VERSION":                            config.ScaleVersion,
		"IBM_CUSTOMER_NUMBER":                      config.IbmCustomerNumber,
		"ZONES":                                    strings.Join(config.Zones, ","),
		"REMOTE_ALLOWED_IPS":                       strings.Join(config.RemoteAllowedIPs, ","),
		"EXISTING_RESOURCE_GROUP":                  config.ExistingResourceGroup,
		"STORAGE_TYPE":                             config.StorageType,
		"SSH_KEYS":                                 config.SSHKeys,
		"SCALE_DEPLOYER_INSTANCE":                  config.ScaleDeployerInstance,
		"COMPUTE_GUI_USERNAME":                     config.ComputeGUIUsername,
		"COMPUTE_GUI_PASSWORD":                     config.ComputeGUIPassword, // # pragma: allowlist secret
		"STORAGE_GUI_USERNAME":                     config.StorageGUIUsername,
		"STORAGE_GUI_PASSWORD":                     config.StorageGUIPassword, //  # pragma: allowlist secret
		"COMPUTE_INSTANCES":                        config.ComputeInstances,
		"CLIENT_INSTANCES":                         config.ClientInstances,
		"STORAGE_INSTANCES":                        config.StorageInstances,
		"SCALE_ENCRYPTION_ENABLED":                 config.ScaleEncryptionEnabled,
		"SCALE_ENCRYPTION_TYPE":                    config.ScaleEncryptionType,
		"SCALE_OBSERVABILITY_ATRACKER_ENABLE":      config.ScaleObservabilityAtrackerEnable,
		"SCALE_OBSERVABILITY_ATRACKER_TARGET_TYPE": config.ScaleObservabilityAtrackerTargetType,
		"SCALE_SCCWP_ENABLE":                       config.ScaleSCCWPEnable,
		"SCALE_CSPM_ENABLED":                       config.ScaleCSPMEnabled,
		"SCALE_SCCWP_SERVICE_PLAN":                 config.ScaleSCCWPServicePlan,
		"GKLM_INSTANCES":                           config.GKLMInstances,
		"SCALE_ENCRYPTION_ADMIN_PASSWORD":          config.ScaleEncryptionAdminPassword, // # pragma: allowlist secret
		"SCALE_FILESYSTEM_CONFIG":                  config.ScaleFilesystemConfig,
		"SCALE_FILESETS_CONFIG":                    config.ScaleFilesetsConfig,
		"SCALE_DNS_DOMAIN_NAMES":                   config.ScaleDNSDomainNames,
		"SCALE_ENABLE_COS_INTEGRATION":             config.ScaleEnableCOSIntegration,
		"SCALE_ENABLE_VPC_FLOW_LOGS":               config.ScaleEnableVPCFlowLogs,
		"AFM_INSTANCES":                            config.AfmInstances,
		"PROTOCOL_INSTANCES":                       config.ProtocolInstances,
	}

	if config.ScaleEncryptionType == "null" {
		delete(envVars, "SCALE_ENCRYPTION_TYPE")
	}

	if err := processScaleSliceConfigs(config, envVars); err != nil {
		return fmt.Errorf("error processing slice configurations: %w", err)
	}

	for key, value := range envVars {
		if err := scaleSetEnvironmentVariable(key, value); err != nil {
			return fmt.Errorf("failed to set %s: %w", key, err)
		}
	}

	return nil
}

func processScaleSliceConfigs(config *ScaleConfig, envVars map[string]interface{}) error {
	sliceProcessors := []struct {
		name      string
		instances interface{}
	}{
		{"COMPUTE_INSTANCES", config.ComputeInstances},
		{"CLIENT_INSTANCES", config.ClientInstances},
		{"STORAGE_INSTANCES", config.StorageInstances},
		{"AFM_INSTANCES", config.AfmInstances},
		{"PROTOCOL_INSTANCES", config.ProtocolInstances},
	}

	for _, processor := range sliceProcessors {
		if err := scaleMarshalToEnv(processor.name, processor.instances, envVars); err != nil {
			return err
		}
	}

	return nil
}

func scaleMarshalToEnv(key string, data interface{}, envVars map[string]interface{}) error {
	jsonBytes, err := json.Marshal(data)
	if err != nil {
		return fmt.Errorf("failed to marshal %s: %w", key, err)
	}
	envVars[key] = string(jsonBytes)
	return nil
}

func scaleSetEnvironmentVariable(key string, value interface{}) error {
	if value == nil {
		return nil
	}

	if existing := os.Getenv(key); existing != "" {
		log.Printf("Environment variable %s is already set. Skipping overwrite.", key)
		return nil
	}

	if key == "REMOTE_ALLOWED_IPS" {
		return scaleHandleRemoteAllowedIPs(value)
	}

	if key == "IBM_CUSTOMER_NUMBER" && IbmCustomerNumberValue != "" {
		return os.Setenv(key, IbmCustomerNumberValue)
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

func scaleHandleRemoteAllowedIPs(value interface{}) error {
	cidr, ok := value.(string)
	if !ok {
		return fmt.Errorf("remote_allowed_ips must be a string")
	}

	if cidr == "" || cidr == "0.0.0.0/0" {
		if scaleGlobalIP == "" {
			return fmt.Errorf("scaleGlobalIP is empty, cannot set REMOTE_ALLOWED_IPS")
		}
		return os.Setenv("REMOTE_ALLOWED_IPS", scaleGlobalIP)
	}

	return os.Setenv("REMOTE_ALLOWED_IPS", cidr)
}
