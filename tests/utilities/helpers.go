package tests

import (
	"bufio"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"math/rand"
	"os"
	"os/exec"
	"path/filepath"
	"reflect"
	"regexp"
	"strconv"
	"strings"
	"testing"
	"time"

	"github.com/IBM/go-sdk-core/v5/core"
	"github.com/IBM/secrets-manager-go-sdk/v2/secretsmanagerv2"
	"github.com/stretchr/testify/assert"
	"github.com/terraform-ibm-modules/ibmcloud-terratest-wrapper/testhelper"
	"golang.org/x/crypto/ssh"
)

const (
	// TimeLayout is the layout string for date and time format (DDMonHHMMSS).
	TimeLayout = "Jan02"
)

// VerifyDataContains is a generic function that checks if a value is present in data (string, []string, or int).
// It performs a verification operation on the provided data to determine if it contains the specified value.
// Logs the result using the provided AggregatedLogger. Returns true if the value is found, false otherwise.
func VerifyDataContains(t *testing.T, data interface{}, val interface{}, logger *AggregatedLogger) bool {
	switch d := data.(type) {
	case string:
		// Check if val is a string
		substr, ok := val.(string)
		if !ok {
			logger.Info(t, "Invalid type for val parameter: expected string")
			return false
		}
		if substr != "" && strings.Contains(d, substr) {
			logger.Info(t, fmt.Sprintf("The string '%s' contains the substring '%s'\n", d, substr))
			return true
		}
		logger.Info(t, fmt.Sprintf("The string '%s' does not contain the substring '%s'\n", d, substr))
		return false

	case []string:
		switch v := val.(type) {
		case string:
			for _, arrVal := range d {
				if arrVal == v {
					logger.Info(t, fmt.Sprintf("The array '%q' contains the value: %s\n", d, v))
					return true
				}
			}
			logger.Info(t, fmt.Sprintf("The array '%q' does not contain the value: %s\n", d, v))
			return false

		case []string:
			if reflect.DeepEqual(d, v) {
				logger.Info(t, fmt.Sprintf("The array '%q' contains the subarray '%q'\n", d, v))
				return true
			}
			logger.Info(t, fmt.Sprintf("The array '%q' does not contain the subarray '%q'\n", d, v))
			return false

		default:
			logger.Info(t, "Invalid type for val parameter: expected string or []string")
			return false
		}

	case int:
		// Check if val is an int
		v, ok := val.(int)
		if !ok {
			logger.Info(t, "Invalid type for val parameter: expected int")
			return false
		}
		if d == v {
			logger.Info(t, fmt.Sprintf("The integers match: %d == %d\n", d, v))
			return true
		}
		logger.Info(t, fmt.Sprintf("The integers do not match: %d != %d\n", d, v))
		return false

	default:
		logger.Info(t, fmt.Sprintf("Unsupported type for data parameter: %T", data))
		return false
	}
}

func CountStringOccurrences(str string, substr string) int {
	return strings.Count(str, substr)
}

func SplitString(strValue string, splitCharacter string, indexValue int) string {
	split := strings.Split(strValue, splitCharacter)
	return split[indexValue]
}

// StringToInt converts a string to an integer.
// Returns the converted integer and an error if the conversion fails.
func StringToInt(str string) (int, error) {
	num, err := strconv.Atoi(str)
	if err != nil {
		return 0, err
	}
	return num, nil
}

// RemoveNilValues removes nil value keys from the given map.
func RemoveNilValues(data map[string]interface{}) map[string]interface{} {
	for key, value := range data {
		if value == nil {
			delete(data, key)
		}
	}
	return data
}

// LogVerificationResult logs the result of a verification check.
func LogVerificationResult(t *testing.T, err error, checkName string, logger *AggregatedLogger) {
	if err == nil {
		logger.Info(t, fmt.Sprintf("%s verification successful", checkName))
	} else {
		assert.Nil(t, err, fmt.Sprintf("%s verification failed", checkName))
		logger.Error(t, fmt.Sprintf("%s verification failed: %s", checkName, err.Error()))
	}
}

// ParsePropertyValue parses the content of a string, searching for a property with the specified key.
// It returns the value of the property if found, or an empty string and an error if the property is not found.
func ParsePropertyValue(content, propertyKey string) (string, error) {
	lines := strings.Split(content, "\n")
	for _, line := range lines {
		if strings.HasPrefix(line, propertyKey+"=") {
			// Extract the value, removing quotes if present
			value := strings.Trim(line[len(propertyKey)+1:], `"`)
			return value, nil
		}
	}

	// Property not found
	return "", fmt.Errorf("property '%s' not found in content:\n%s", propertyKey, content)
}

// ParsePropertyValue parses the content of a string, searching for a property with the specified key.
// It returns the value of the property if found, or an empty string and an error if the property is not found.
func FindImageNamesByCriteria(name string) (string, error) {
	// Get the absolute path of the image map file
	absPath, err := filepath.Abs("modules/landing_zone_vsi/image_map.tf")
	if err != nil {
		return "", err
	}

	absPath = strings.ReplaceAll(absPath, "tests", "")
	readFile, err := os.Open(absPath)
	if err != nil {
		return "", err
	}
	defer readFile.Close()

	// Create a scanner to read lines from the file
	fileScanner := bufio.NewScanner(readFile)

	var imageName string

	for fileScanner.Scan() {
		line := fileScanner.Text()
		if strings.Contains(strings.ToLower(line), strings.ToLower(name)) && strings.Contains(line, "compute") {
			pattern := "[^a-zA-Z0-9\\s-]"

			// Compile the regular expression.
			regex, err := regexp.Compile(pattern)
			if err != nil {
				return "", errors.New("error on image compiling regex")
			}
			// Use the regex to replace all matches with an empty string.
			imageName = strings.TrimSpace(regex.ReplaceAllString(line, ""))
		}
	}

	// Check if any image names were found
	if len(imageName) == 0 {
		return imageName, errors.New("no image found with the specified criteria")
	}

	return imageName, nil
}

//Create IBMCloud Resources

// LoginIntoIBMCloudUsingCLI logs into IBM Cloud using CLI.
func LoginIntoIBMCloudUsingCLI(t *testing.T, apiKey, region, resourceGroup string) error {
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Minute)
	defer cancel()

	// Configure IBM Cloud CLI
	configCmd := exec.CommandContext(ctx, "ibmcloud", "config", "--check-version=false")
	configOutput, err := configCmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("failed to configure IBM Cloud CLI: %w. Output: %s", err, string(configOutput))
	}

	// Login to IBM Cloud and set the target resource group
	loginCmd := exec.CommandContext(ctx, "ibmcloud", "login", "--apikey", apiKey, "-r", region, "-g", resourceGroup)
	loginOutput, err := loginCmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("failed to login to IBM Cloud: %w. Output: %s", err, string(loginOutput))
	}

	return nil
}

// GenerateTimestampedClusterPrefix generates a cluster prefix by appending a timestamp to the given prefix.
func GenerateTimestampedClusterPrefix(prefix string) string {
	//Place current time in the string.
	t := time.Now()
	//return strings.ToLower("cicd" + "-" + t.Format(TimeLayout) + "-" + prefix)
	return strings.ToLower("cicd" + "-" + t.Format(TimeLayout) + "-" + prefix)
}

// GetPublicIP returns the public IP address using ifconfig.io API
func GetPublicIP() (string, error) {
	cmd := exec.Command("bash", "-c", "(curl -s ifconfig.io)")
	output, err := cmd.CombinedOutput()
	if err != nil {
		return "", err
	}
	return strings.TrimSpace(string(output)), nil
}

// GetOrDefault returns the environment variable value if it's not empty, otherwise returns the default value.
func GetOrDefault(envVar, defaultValue string) string {
	if envVar != "" {
		return envVar
	}
	return defaultValue
}

// GenerateRandomString generates a random string of length 4 using lowercase characters
func GenerateRandomString() string {
	// Define the character set containing lowercase letters
	charset := "abcdefghijklmnopqrstuvwxyz"

	b := make([]byte, 4)

	// Loop through each index of the byte slice
	for i := range b {
		// Generate a random index within the length of the character set
		randomIndex := rand.Intn(len(charset))

		b[i] = charset[randomIndex]
	}

	// Convert the byte slice to a string and return it
	return string(b)
}

// GetSecretsManagerKey retrieves a secret from IBM Secrets Manager.
func GetSecretsManagerKey(smID, smRegion, smKeyID string) (*string, error) {
	secretsManagerService, err := secretsmanagerv2.NewSecretsManagerV2(&secretsmanagerv2.SecretsManagerV2Options{
		URL: fmt.Sprintf("https://%s.%s.secrets-manager.appdomain.cloud", smID, smRegion),
		Authenticator: &core.IamAuthenticator{
			ApiKey: os.Getenv("TF_VAR_ibmcloud_api_key"),
		},
	})
	if err != nil {
		return nil, err
	}

	getSecretOptions := secretsManagerService.NewGetSecretOptions(smKeyID)

	secret, _, err := secretsManagerService.GetSecret(getSecretOptions)
	if err != nil {
		return nil, err
	}

	secretPayload, ok := secret.(*secretsmanagerv2.ArbitrarySecret)
	if !ok {
		return nil, fmt.Errorf("unexpected secret type: %T", secret)
	}

	return secretPayload.Payload, nil
}

// GetValueForKey retrieves the value associated with the specified key from the given map.
func GetValueForKey(inputMap map[string]string, key string) string {
	return inputMap[key]
}

// Configuration struct matches the structure of your JSON data
type Configuration struct {
	ClusterName             string   `json:"ClusterName"`
	ReservationID           string   `json:"reservationID"`
	ClusterPrefixName       string   `json:"clusterPrefixName"`
	ResourceGroup           string   `json:"resourceGroup"`
	KeyManagement           string   `json:"keyManagement"`
	DnsDomainName           string   `json:"dnsDomainName"`
	Zones                   string   `json:"zones"`
	IsHyperthreadingEnabled bool     `json:"isHyperthreadingEnabled"`
	BastionIP               string   `json:"bastionIP"`
	ManagementNodeIPList    []string `json:"managementNodeIPList"`
	LoginNodeIP             string   `json:"loginNodeIP"`
	LdapServerIP            string   `json:"ldapServerIP"`
	LdapDomain              string   `json:"ldapDomain"`
	LdapAdminPassword       string   `json:"ldapAdminPassword"`
	LdapUserName            string   `json:"ldapUserName"`
	LdapUserPassword        string   `json:"ldapUserPassword"`
	AppCenterEnabled        string   `json:"appCenterEnabled"`
	SshKeyPath              string   `json:"sshKeyPath"`
	ComputeSshKeysList      []string `json:"computeSshKeysList"`
}

// ParseConfig reads a JSON file from the given file path and parses it into a Configuration struct
func ParseConfig(filePath string) (*Configuration, error) {
	// Read the entire content of the file
	byteValue, err := os.ReadFile(filePath)
	if err != nil {
		return nil, fmt.Errorf("error reading file %s: %w", filePath, err)
	}

	// Unmarshal the JSON data into the Configuration struct
	var config Configuration
	err = json.Unmarshal(byteValue, &config)
	if err != nil {
		return nil, fmt.Errorf("error parsing JSON from file %s: %w", filePath, err)
	}

	// Return the configuration struct and nil error on success
	return &config, nil
}

// GetLdapIP retrieves the IP addresses of various servers, including the LDAP server,
// from the specified file path in the provided test options, using the provided logger for logging.
// It returns the LDAP server IP and any error encountered.
func GetLdapIP(t *testing.T, options *testhelper.TestOptions, logger *AggregatedLogger) (ldapIP string, err error) {
	// Retrieve the Terraform directory from the options.
	filePath := options.TerraformOptions.TerraformDir

	// Get the LDAP server IP and handle errors.
	ldapIP, err = GetLdapServerIPFromIni(t, filePath, logger)
	if err != nil {
		return "", fmt.Errorf("error getting LDAP server IP: %w", err)
	}

	// Return the retrieved IP address and any error.
	return ldapIP, nil
}

// GetBastionIP retrieves the bastion server IP address based on the provided test options.
// It returns the bastion IP address and an error if any step fails.
func GetBastionIP(t *testing.T, options *testhelper.TestOptions, logger *AggregatedLogger) (bastionIP string, err error) {
	// Retrieve the Terraform directory from the options.
	filePath := options.TerraformOptions.TerraformDir

	// Get the bastion server IP and handle errors.
	bastionIP, err = GetBastionServerIPFromIni(t, filePath, logger)
	if err != nil {
		return "", fmt.Errorf("error getting bastion server IP: %w", err)
	}

	// Return the bastion IP address.
	return bastionIP, nil
}

// GetValueFromIniFile retrieves a value from an INI file based on the provided section and key.
// It reads the specified INI file, extracts the specified section, and returns the value associated with the key.
func GetValueFromIniFile(filePath, sectionName string) ([]string, error) {
	// Read the content of the file
	absolutePath, err := filepath.Abs(filePath)
	if err != nil {
		return nil, err
	}
	data, err := os.ReadFile(absolutePath)
	if err != nil {
		return nil, err
	}

	// Convert the byte slice to a string
	content := string(data)

	// Split the input into sections based on empty lines
	sections := strings.Split(content, "\n\n")

	// Loop through sections and find the one with the specified sectionName
	for _, section := range sections {

		if strings.Contains(section, "["+sectionName+"]") {
			// Split the section into lines
			lines := strings.Split(section, "\n")

			// Extract values
			var sectionValues []string
			for i := 1; i < len(lines); i++ {
				// Skip the first line, as it contains the section name
				sectionValues = append(sectionValues, strings.TrimSpace(lines[i]))
			}

			return sectionValues, nil
		}
	}

	return nil, fmt.Errorf("section [%s] not found in file %s", sectionName, filePath)
}

// GetRegion returns the region from a given zone.
func GetRegion(zone string) string {
	// Extract region from zone
	region := zone[:len(zone)-2]
	return region
}

// SplitAndTrim splits the input string into a list of trimmed strings based on the comma separator.
func SplitAndTrim(str, separator string) []string {
	words := strings.Split(str, separator)
	var trimmedWords []string

	for _, word := range words {
		trimmedWord := strings.TrimSpace(word)
		if trimmedWord != "" {
			trimmedWords = append(trimmedWords, trimmedWord)
		}
	}
	return trimmedWords
}

// RemoveKeys removes the key-value pairs with the specified keys from the given map.
func RemoveKeys(m map[string]interface{}, keysToRemove []string) {
	for _, key := range keysToRemove {
		delete(m, key)
	}
}

// IsStringInSlice checks if a string exists in a slice of strings.
func IsStringInSlice(slice []string, item string) bool {
	for _, str := range slice {
		if str == item {
			return true
		}
	}
	return false
}

// Helper function to retrieve the master node name
func GetMasterNodeName(t *testing.T, sClient *ssh.Client, logger *AggregatedLogger) (string, error) {
	output, err := RunCommandInSSHSession(sClient, `lsid | grep master | cut -d" " -f5`)
	if err != nil {
		return "", fmt.Errorf("failed to retrieve the master node name: %w", err)
	}
	masterName := strings.TrimSpace(output)
	logger.Info(t, fmt.Sprintf("Master node: %s", masterName))
	return masterName, nil
}

// Helper function to retrieve management node names
func GetManagementNodeNames(t *testing.T, sClient *ssh.Client, logger *AggregatedLogger) ([]string, error) {
	output, err := RunCommandInSSHSession(sClient, `bhosts -w -noheader | cut -d" " -f1 | grep mgmt | tr '\n' ' ' | sed 's/ *$//'`)
	if err != nil {
		return nil, fmt.Errorf("failed to retrieve management node names: %w", err)
	}
	managementNodes := strings.Fields(output)
	logger.Info(t, fmt.Sprintf("Management nodes: %s", managementNodes))
	return managementNodes, nil
}

// GetIAMToken retrieves the IAM token using IBM Cloud CLI
func GetIAMToken() (string, error) {
	cmd := exec.Command("bash", "-c", "ibmcloud iam oauth-tokens --output json | jq -r '.iam_token'")
	output, err := cmd.CombinedOutput()
	if err != nil {
		return "", fmt.Errorf("failed to get IAM token: %w", err)
	}

	// Trim and check if the token is empty
	token := strings.TrimSpace(string(output))
	if token == "" {
		return "", fmt.Errorf("empty IAM token received")
	}

	return token, nil
}

// ConvertToInt safely converts an interface{} to an int.
func ConvertToInt(value interface{}) (int, error) {
	switch v := value.(type) {
	case int:
		return v, nil
	case float64:
		return int(v), nil // JSON numbers are often float64.
	case string:
		intVal, err := strconv.Atoi(v)
		if err != nil {
			return 0, fmt.Errorf("could not convert string '%s' to int: %v", v, err)
		}
		return intVal, nil
	default:
		return 0, fmt.Errorf("unsupported type: %T", v)
	}
}

// GetTotalWorkerNodeCount extracts and sums up all "count" values.
func GetTotalWorkerNodeCount(t *testing.T, terraformVars map[string]interface{}, logger *AggregatedLogger) (int, error) {
	rawVal, exists := terraformVars["worker_node_instance_type"]
	if !exists {
		return 0, errors.New("worker_node_instance_type key does not exist")
	}

	// Ensure rawVal is of type []map[string]interface{}
	workers, ok := rawVal.([]map[string]interface{})
	if !ok {
		return 0, fmt.Errorf("worker_node_instance_type is not a slice, but %T", rawVal)
	}

	var totalCount int
	for i, worker := range workers {
		countVal, exists := worker["count"]
		if !exists {
			return 0, fmt.Errorf("worker at index %d is missing 'count' key", i)
		}

		count, err := ConvertToInt(countVal)
		if err != nil {
			return 0, fmt.Errorf("worker at index %d has invalid 'count' value: %v", i, err)
		}
		totalCount += count
	}

	logger.Info(t, fmt.Sprintf("Total Worker Node Count: %d", totalCount))
	return totalCount, nil
}

// GetFirstWorkerNodeInstanceType retrieves the "instance_type" of the first worker node.
func GetFirstWorkerNodeInstanceType(t *testing.T, terraformVars map[string]interface{}, logger *AggregatedLogger) (string, error) {
	rawVal, exists := terraformVars["worker_node_instance_type"]
	if !exists {
		return "", errors.New("worker_node_instance_type key does not exist")
	}

	// Ensure rawVal is of type []map[string]interface{}
	workers, ok := rawVal.([]map[string]interface{})
	if !ok {
		return "", fmt.Errorf("worker_node_instance_type is not a slice, but %T", rawVal)
	}

	if len(workers) == 0 {
		return "", errors.New("worker_node_instance_type is empty")
	}

	instanceType, exists := workers[0]["instance_type"]
	if !exists {
		return "", errors.New("first worker node is missing 'instance_type' key")
	}

	instanceTypeStr, ok := instanceType.(string)
	if !ok {
		return "", errors.New("instance_type is not a string")
	}

	logger.Info(t, fmt.Sprintf("First Worker Node Instance Type: %s", instanceTypeStr))
	return instanceTypeStr, nil
}

// RunCommandWithRetry executes a shell command with retries
func RunCommandWithRetry(cmd string, retries int, delay time.Duration) ([]byte, error) {
	var output []byte
	var err error

	for i := 0; i <= retries; i++ {
		output, err = exec.Command("bash", "-c", cmd).CombinedOutput()
		if err == nil {
			return output, nil
		}
		if i < retries {
			time.Sleep(delay) // Wait before retrying
		}
	}

	return output, err
}
