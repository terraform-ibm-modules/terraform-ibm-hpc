package tests

import (
	"fmt"
	"strings"
	"testing"

	"golang.org/x/crypto/ssh"
)

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
		//command := "cd " + filePath + " && echo '" + content + "' > " + fileName
		command := fmt.Sprintf("cd %s && echo %q > %s", filePath, content, fileName)
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
