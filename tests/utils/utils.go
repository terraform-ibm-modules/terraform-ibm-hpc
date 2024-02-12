package utils

import (
	"fmt"
	"reflect"
	"strconv"
	"strings"
	"testing"

	"golang.org/x/crypto/ssh"
	"gopkg.in/ini.v1"
)

// GetValueFromIniFile retrieves a value from an INI file based on the provided section and key.
// It reads the specified INI file, extracts the specified section, and returns the value associated with the key.
func GetValueFromIniFile(iniFileName, sectionName, key string) (string, error) {
	// Load the INI file
	inidata, err := ini.Load(iniFileName)
	if err != nil {
		return "", fmt.Errorf("failed to read INI file: %v", err)
	}

	// Retrieve the specified section
	section := inidata.Section(sectionName)

	// Retrieve the value associated with the key in the specified section
	value := section.Key(key).String()

	return value, nil
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

func CountStringOccurences(str string, substr string) int {
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
