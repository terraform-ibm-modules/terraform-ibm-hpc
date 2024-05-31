package tests

import (
	"bufio"
	"bytes"
	"context"
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

	"github.com/IBM/go-sdk-core/core"
	"github.com/IBM/secrets-manager-go-sdk/secretsmanagerv2"
	"github.com/stretchr/testify/assert"
	"github.com/terraform-ibm-modules/ibmcloud-terratest-wrapper/testhelper"
	"golang.org/x/crypto/ssh"
)

const (
	// TimeLayout is the layout string for date and time format (DDMonHHMMSS).
	TimeLayout = "Jan02"
)

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

// #########  file operations functions ##############

// ToCreateFile creates a file on the remote server using SSH.
// It takes an SSH client, the path where the file should be created, and the file name.
// Returns a boolean indicating success or failure and an error if any.
func ToCreateFile(t *testing.T, sClient *ssh.Client, filePath, fileName string, logger *AggregatedLogger) (bool, error) {
	// Check if the specified path exists on the remote server
	isPathExist, err := IsPathExist(t, sClient, filePath, logger)
	if err != nil {
		// Error occurred while checking path existence
		return false, err
	}

	if isPathExist {
		// Path exists, create the file using SSH command
		command := "cd " + filePath + " && touch " + fileName
		_, createFileErr := RunCommandInSSHSession(sClient, command)

		if createFileErr == nil {
			logger.Info(t, "File created successfully: "+fileName)
			// File created successfully
			return true, nil
		} else {
			// Error occurred while creating the file
			return false, fmt.Errorf(" %s file not created", fileName)
		}
	}

	// Path does not exist
	return false, fmt.Errorf("directory not exist : %s", filePath)
}

// IsFileExist checks if a file exists on the remote server using SSH.
// It takes an SSH client, the path where the file should exist, and the file name.
// Returns a boolean indicating whether the file exists and an error if any.
func IsFileExist(t *testing.T, sClient *ssh.Client, filePath, fileName string, logger *AggregatedLogger) (bool, error) {
	// Check if the specified path exists on the remote server
	isPathExist, err := IsPathExist(t, sClient, filePath, logger)
	if err != nil {
		// Error occurred while checking path existence
		return false, err
	}

	if isPathExist {
		// Path exists, check if the file exists using an SSH command
		command := "[ -f " + filePath + fileName + " ] && echo 'File exist' || echo 'File not exist'"
		isFileExist, err := RunCommandInSSHSession(sClient, command)

		if err != nil {
			// Error occurred while running the command
			return false, err
		}

		if strings.Contains(isFileExist, "File exist") {
			logger.Info(t, fmt.Sprintf("File exist : %s", fileName))
			// File exists
			return true, nil
		} else {
			logger.Info(t, fmt.Sprintf("File not exist : %s", fileName))
			// File does not exist
			return false, nil
		}
	}

	// Path does not exist
	return false, fmt.Errorf("directory not exist : %s", filePath)
}

// IsPathExist checks if a directory exists on the remote server using SSH.
// It takes an SSH client and the path to check for existence.
// Returns a boolean indicating whether the directory exists and an error if any.
func IsPathExist(t *testing.T, sClient *ssh.Client, filePath string, logger *AggregatedLogger) (bool, error) {
	// Run an SSH command to test if the directory exists
	command := "test -d " + filePath + " && echo 'Directory Exist' || echo 'Directory Not Exist'"
	result, err := RunCommandInSSHSession(sClient, command)

	if err != nil {
		// Error occurred while running the command
		return false, err
	}

	if strings.Contains(result, "Directory Exist") {
		logger.Info(t, fmt.Sprintf("Directory exist : %s", filePath))
		// Directory exists
		return true, nil
	} else {
		logger.Info(t, fmt.Sprintf("Directory not exist : %s", filePath))
		// Directory does not exist
		return false, nil
	}
}

// GetDirList retrieves the list of files in a directory on a remote server via SSH.
// It takes an SSH client and the path of the directory.
// Returns a string containing the list of files and an error if any.
func GetDirList(t *testing.T, sClient *ssh.Client, filePath string, logger *AggregatedLogger) ([]string, error) {
	command := "cd " + filePath + " && ls"
	output, err := RunCommandInSSHSession(sClient, command)
	if err == nil {
		listDir := strings.Split(strings.TrimSpace(output), "\n")
		logger.Info(t, fmt.Sprintf("Directory list : %q ", listDir))
		return listDir, nil
	}
	return nil, err
}

// GetDirectoryFileList retrieves the list of files in a directory on a remote server via SSH.
// It takes an SSH client and the path of the directory.
// Returns a slice of strings representing the file names and an error if any.
func GetDirectoryFileList(t *testing.T, sClient *ssh.Client, directoryPath string, logger *AggregatedLogger) ([]string, error) {
	command := "cd " + directoryPath + " && ls"
	output, err := RunCommandInSSHSession(sClient, command)
	if err == nil {
		fileList := strings.Split(strings.TrimSpace(output), "\n")
		logger.Info(t, fmt.Sprintf("Directory file list :  %q", fileList))
		return fileList, nil
	}

	return nil, err
}

// ToDeleteFile deletes a file on the remote server using SSH.
// It takes an SSH client, the path of the file's directory, and the file name.
// Returns a boolean indicating whether the file was deleted successfully and an error if any.
func ToDeleteFile(t *testing.T, sClient *ssh.Client, filePath, fileName string, logger *AggregatedLogger) (bool, error) {
	isPathExist, err := IsPathExist(t, sClient, filePath, logger)
	if isPathExist {
		command := "cd " + filePath + " && rm -rf " + fileName
		_, deleFileErr := RunCommandInSSHSession(sClient, command)
		if deleFileErr == nil {
			logger.Info(t, fmt.Sprintf("File deleted successfully: %s", fileName))
			return true, nil
		}
		return false, fmt.Errorf("files not deleted: %s", fileName)
	}
	return isPathExist, err
}

// ToCreateFileWithContent creates a file on the remote server using SSH.
// It takes an SSH client, the path where the file should be created, the file name, content to write to the file,
// a log file for logging, and returns a boolean indicating success or failure and an error if any.
func ToCreateFileWithContent(t *testing.T, sClient *ssh.Client, filePath, fileName, content string, logger *AggregatedLogger) (bool, error) {
	// Check if the specified path exists on the remote server
	isPathExist, err := IsPathExist(t, sClient, filePath, logger)
	if err != nil {
		// Error occurred while checking path existence
		return false, fmt.Errorf("error checking path existence: %w", err)
	}

	if isPathExist {
		// Path exists, create the file using SSH command
		command := "cd " + filePath + " && echo '" + content + "' > " + fileName
		_, createFileErr := RunCommandInSSHSession(sClient, command)

		if createFileErr == nil {
			// File created successfully
			logger.Info(t, "File created successfully: "+fileName)
			return true, nil
		}

		// Error occurred while creating the file
		return false, fmt.Errorf("error creating file %s: %w", fileName, createFileErr)
	}

	// Path does not exist
	return false, fmt.Errorf("directory not exist : %s", filePath)
}

// ReadRemoteFileContents reads the content of a file on the remote server via SSH.
// It checks if the specified file path exists, creates an SSH command to concatenate the file contents,
// and returns the content as a string upon success. In case of errors, an empty string and an error are returned.
func ReadRemoteFileContents(t *testing.T, sClient *ssh.Client, filePath, fileName string, logger *AggregatedLogger) (string, error) {
	isPathExist, err := IsPathExist(t, sClient, filePath, logger)
	if err != nil {
		return "", fmt.Errorf("error checking path existence: %w", err)
	}

	if isPathExist {
		command := "cd " + filePath + " && cat " + fileName
		actualText, outErr := RunCommandInSSHSession(sClient, command)

		if outErr == nil {
			logger.Info(t, "content: "+actualText)
			return actualText, nil
		}

		return "", fmt.Errorf("error reading file %s: %w", fileName, outErr)
	}

	return "", fmt.Errorf("directory does not exist: %s", filePath)
}

// VerifyDataContains is a generic function that checks if a value is present in data (string or string array)
// VerifyDataContains performs a verification operation on the provided data
// to determine if it contains the specified value. It supports string and
// string array types, logging results with the provided AggregatedLogger.
// Returns true if the value is found, false otherwise.
func VerifyDataContains(t *testing.T, data interface{}, val interface{}, logger *AggregatedLogger) bool {
	//The data.(type) syntax is used to check the actual type of the data variable.
	switch d := data.(type) {
	case string:
		//check if the val variable is of type string.
		substr, ok := val.(string)
		if !ok {
			logger.Info(t, "Invalid type for val parameter")
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
			logger.Info(t, "Invalid type for val parameter")
			return false
		}

	default:
		logger.Info(t, "Unsupported type for data parameter")
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

// Prerequisite: Ensure that you have logged into IBM Cloud using the LoginIntoIBMCloudUsingCLI function before calling this function
// CreateVPC creates a new Virtual Private Cloud (VPC) in IBM Cloud with the specified VPC name.
func CreateVPC(vpcName string) error {
	existingVPC, err := IsVPCExist(vpcName)
	if err != nil {
		return err
	}
	if !existingVPC {
		cmd := exec.Command("ibmcloud", "is", "vpc-create", vpcName)
		if output, err := cmd.CombinedOutput(); err != nil {
			return fmt.Errorf("VPC creation failed: %v\nCommand output: %s", err, string(output))
		}
		fmt.Printf("VPC %s created successfully\n", vpcName)
	} else {
		fmt.Println("An existing VPC is available")
	}
	return nil
}

// Prerequisite: Ensure that you have logged into IBM Cloud using the LoginIntoIBMCloudUsingCLI function before calling this function
// IsVPCExist checks if a VPC with the given name exists.
func IsVPCExist(vpcName string) (bool, error) {
	cmd := exec.Command("ibmcloud", "is", "vpcs", "--output", "json")
	output, err := cmd.Output()
	if err != nil {
		return false, fmt.Errorf("failed to list VPCs: %w", err)
	}

	return bytes.Contains(output, []byte(vpcName)), nil
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

// GetBastionServerIP retrieves the IP address from the BastionServer section in the specified INI file.
func GetBastionServerIP(t *testing.T, filePath string, logger *AggregatedLogger) (string, error) {
	value, err := GetValueFromIniFile(filePath+"/bastion.ini", "BastionServer")
	if err != nil {
		return "", fmt.Errorf("failed to get value from bastion.ini: %w", err)
	}
	logger.Info(t, fmt.Sprintf("Bastion Server IP: %s", value[1]))
	return value[1], nil
}

// GetManagementNodeIPs retrieves the IP addresses from the HPCAASCluster section in the specified INI file.
func GetManagementNodeIPs(t *testing.T, filePath string, logger *AggregatedLogger) ([]string, error) {
	value, err := GetValueFromIniFile(filePath+"/compute.ini", "HPCAASCluster")
	if err != nil {
		return nil, fmt.Errorf("failed to get value from compute.ini: %w", err)
	}
	logger.Info(t, fmt.Sprintf("Management Node IPs List: %q", value[1:]))
	return value[1:], nil
}

// GetLoginNodeIP retrieves the IP address from the LoginServer section in the specified login INI file.
func GetLoginNodeIP(t *testing.T, filePath string, logger *AggregatedLogger) (string, error) {
	value, err := GetValueFromIniFile(filePath+"/login.ini", "LoginServer")
	if err != nil {
		return "", fmt.Errorf("failed to get value from login.ini: %w", err)
	}
	logger.Info(t, fmt.Sprintf("Login Server IP: %s", value[1]))
	return value[1], nil
}

// GetLdapServerIP retrieves the IP address from the LdapServer section in the specified login INI file.
func GetLdapServerIP(t *testing.T, filePath string, logger *AggregatedLogger) (string, error) {
	value, err := GetValueFromIniFile(filePath+"/ldap.ini", "LDAPServer")
	if err != nil {
		return "", fmt.Errorf("failed to get value from ldap.ini: %w", err)
	}
	logger.Info(t, fmt.Sprintf("Ldap Server IP: %s", value[1]))
	return value[1], nil
}

// GetServerIPs retrieves the IP addresses of the bastion server, management nodes, and login node
// from the specified file path in the provided test options, using the provided logger for logging.
// It returns the bastion server IP, a list of management node IPs, the login node IP, and any error encountered.
func GetServerIPs(t *testing.T, options *testhelper.TestOptions, logger *AggregatedLogger) (bastionIP string, managementNodeIPList []string, loginNodeIP string, err error) {

	filePath := options.TerraformOptions.TerraformDir

	// Get bastion server IP and handle errors
	bastionIP, err = GetBastionServerIP(t, filePath, logger)
	if err != nil {
		return "", nil, "", fmt.Errorf("error getting bastion server IP: %v", err)
	}

	// Get management node IPs and handle errors
	managementNodeIPList, err = GetManagementNodeIPs(t, filePath, logger)
	if err != nil {
		return "", nil, "", fmt.Errorf("error getting management node IPs: %v", err)
	}

	// Get login node IP and handle errors
	loginNodeIP, err = GetLoginNodeIP(t, filePath, logger)
	if err != nil {
		return "", nil, "", fmt.Errorf("error getting login node IP: %v", err)
	}

	return bastionIP, managementNodeIPList, loginNodeIP, nil
}

// GetServerIPsWithLDAP retrieves the IP addresses of various servers, including the LDAP server.
// from the specified file path in the provided test options, using the provided logger for logging.
// It returns the bastion server IP, a list of management node IPs, the login node IP, ldap server IP and any error encountered.
func GetServerIPsWithLDAP(t *testing.T, options *testhelper.TestOptions, logger *AggregatedLogger) (bastionIP string, managementNodeIPList []string, loginNodeIP, ldapIP string, err error) {
	// Retrieve the Terraform directory from the options.
	filePath := options.TerraformOptions.TerraformDir

	// Get the bastion server IP and handle errors.
	bastionIP, err = GetBastionServerIP(t, filePath, logger)
	if err != nil {
		return "", nil, "", "", fmt.Errorf("error getting bastion server IP: %v", err)
	}

	// Get the management node IPs and handle errors.
	managementNodeIPList, err = GetManagementNodeIPs(t, filePath, logger)
	if err != nil {
		return "", nil, "", "", fmt.Errorf("error getting management node IPs: %v", err)
	}

	// Get the login node IP and handle errors.
	loginNodeIP, err = GetLoginNodeIP(t, filePath, logger)
	if err != nil {
		return "", nil, "", "", fmt.Errorf("error getting login node IP: %v", err)
	}

	// Get the LDAP server IP and handle errors.
	ldapIP, err = GetLdapServerIP(t, filePath, logger)
	if err != nil {
		return "", nil, "", "", fmt.Errorf("error getting LDAP server IP: %v", err)
	}

	// Return the retrieved IP addresses and any error.
	return bastionIP, managementNodeIPList, loginNodeIP, ldapIP, nil
}

// GenerateTimestampedClusterPrefix generates a cluster prefix by appending a timestamp to the given prefix.
func GenerateTimestampedClusterPrefix(prefix string) string {
	//Place current time in the string.
	t := time.Now()
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

// Getting BastionID and ComputeID from separately created brand new VPC
func GetSubnetIds(outputs map[string]interface{}) (string, string) {
	subnetDetailsList := outputs["subnet_detail_list"]
	var bastion []string
	var compute []string
	for _, val := range subnetDetailsList.(map[string]interface{}) {
		for key1, val1 := range val.(map[string]interface{}) {
			isContains := strings.Contains(key1, "bastion")
			if isContains {
				for key2, val2 := range val1.(map[string]interface{}) {
					if key2 == "id" {
						bastion = append(bastion, val2.(string))
					}
				}
			} else {
				for key2, val2 := range val1.(map[string]interface{}) {
					if key2 == "id" {
						compute = append(compute, val2.(string))
					}
				}
			}

		}
	}
	bastionsubnetId := strings.Join(bastion, ",")
	computesubnetIds := strings.Join(compute, ",")
	return bastionsubnetId, computesubnetIds
}

// Getting DNSInstanceID and CustomResolverID from separately created brand new VPC
func GetDnsCustomResolverIds(outputs map[string]interface{}) (string, string) {
	customResolverHub := outputs["custom_resolver_hub"]
	var instanceId string
	var customResolverId string
	for _, details := range customResolverHub.([]interface{}) {
		for key, val := range details.(map[string]interface{}) {
			if key == "instance_id" {
				instanceId = val.(string)
			}
			if key == "custom_resolver_id" {
				customResolverId = val.(string)
			}
		}
	}
	return instanceId, customResolverId
}
