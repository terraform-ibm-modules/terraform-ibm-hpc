package tests

import (
	"bytes"
	"fmt"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/retry"
	"golang.org/x/crypto/ssh"
)

// sshClientJumpHost establishes an SSH connection through a jump host.
// It takes two SSH client configurations (config and config1) for the jump host and the target machine,
// along with the IP and port of the jump host (jumpHostIPPort) and the target machine (machineIPPort).
// The function returns an SSH client connected to the target machine through the jump host.
// If any step in the process fails, an error is returned with a descriptive message.
func sshClientJumpHost(config, config1 *ssh.ClientConfig, publicHostIP, privateHostIP string) (*ssh.Client, error) {
	client, err := ssh.Dial("tcp", publicHostIP, config)
	if err != nil {
		return nil, fmt.Errorf("failed to dial jump host: %w", err)
	}

	conn, err := client.Dial("tcp", privateHostIP)
	if err != nil {
		return nil, fmt.Errorf("failed to dial target machine: %w", err)
	}

	ncc, chans, reqs, err := ssh.NewClientConn(conn, privateHostIP, config1)
	if err != nil {
		return nil, fmt.Errorf("failed to create new client connection: %w", err)
	}

	sClient := ssh.NewClient(ncc, chans, reqs)
	return sClient, nil
}

// runCommandInSSHSession executes a command in a new SSH session and returns the output.
// It takes an existing SSH client (sClient) and the command (cmd) to be executed.
// The function opens an SSH session, runs the specified command, captures the output,
// and returns the output as a string. If any step in the process fails, an error is returned with a descriptive message.
func RunCommandInSSHSession(sClient *ssh.Client, cmd string) (string, error) {
	session, err := sClient.NewSession()
	if err != nil {
		return "", fmt.Errorf("failed to create SSH session: %w", err)
	}
	defer session.Close()

	var b bytes.Buffer
	session.Stdout = &b

	if err := session.Run(cmd); err != nil {
		return "", fmt.Errorf("failed to execute command '%s': %w", cmd, err)
	}

	return b.String(), nil
}

// getSshConfig retrieves SSH configuration variables.
// It takes an SSH private key (key) and a username (user).
// The function creates and returns an SSH client configuration (ClientConfig)
// with the specified user, ignoring host key verification, and using public key authentication.
func getSshConfig(key ssh.Signer, user string) *ssh.ClientConfig {
	config := &ssh.ClientConfig{
		User:            user,
		HostKeyCallback: ssh.InsecureIgnoreHostKey(),
		Auth: []ssh.AuthMethod{
			ssh.PublicKeys(key),
		},
	}

	return config
}

// ConnectToHost establishes an SSH connection to a target machine.
// It takes the target machine's floating IP (floatingIP), IP and port (machineIPPort),
// and the login usernames for the jump host (loginUserName) and the target machine (vsiUserName).
// The function retrieves the SSH private key, creates SSH client configurations for the jump host and target machine,
// and establishes an SSH connection to the target machine through the jump host.
// If any step in the process fails, an error is returned with a descriptive message.
func ConnectToHost(publicHostName, publicHostIP, privateHostName, privateHostIP string) (*ssh.Client, error) {
	// Get the SSH private key file path from the environment variable
	sshFilePath := os.Getenv("SSH_FILE_PATH")

	// Check if the file exists
	_, err := os.Stat(sshFilePath)
	if os.IsNotExist(err) {
		return nil, fmt.Errorf("SSH private key file '%s' does not exist", sshFilePath)
	} else if err != nil {
		return nil, fmt.Errorf("error checking SSH private key file: %v", err)
	}

	key, err := getSshKeyFile(sshFilePath)
	if err != nil {
		return nil, fmt.Errorf("failed to get SSH key: %w", err)
	}

	config := getSshConfig(key, publicHostName)
	config1 := getSshConfig(key, privateHostName)

	sClient, err := sshClientJumpHost(config, config1, publicHostIP+":22", privateHostIP+":22")
	if err != nil {
		return nil, fmt.Errorf("unable to log in to the node: %w", err)
	}
	return sClient, nil
}

// getSshKeyFile reads an SSH private key file.
// It takes the file path (filepath) of the SSH private key.
// The function reads the private key file, parses it, and returns an SSH signer.
// If any step in the process fails, an error is returned with a descriptive message.
func getSshKeyFile(filepath string) (key ssh.Signer, err error) {
	privateKey, err := os.ReadFile(filepath)
	if err != nil {
		return nil, fmt.Errorf("failed to read private key file: %w", err)
	}

	key, err = ssh.ParsePrivateKey(privateKey)
	if err != nil {
		return nil, fmt.Errorf("failed to parse private key: %w", err)
	}

	return key, nil
}

func ConnectionE(t *testing.T, publicHostName, publicHostIP, privateHostName, privateHostIP, command string) (string, error) {
	sshFilePath := os.Getenv("SSH_FILE_PATH")
	if _, err := os.Stat(sshFilePath); os.IsNotExist(err) {
		return "", fmt.Errorf("SSH private key file '%s' does not exist", sshFilePath)
	} else if err != nil {
		return "", fmt.Errorf("error checking SSH private key file: %v", err)
	}

	key, err := getSshKeyFile(sshFilePath)
	if err != nil {
		return "", fmt.Errorf("failed to get SSH key: %w", err)
	}

	maxRetries := 1
	timeBetweenRetries := 10 * time.Second
	description := "SSH into host"
	var output string
	var sClient *ssh.Client

	retry.DoWithRetry(t, description, maxRetries, timeBetweenRetries, func() (string, error) {
		var config *ssh.ClientConfig

		if len(strings.TrimSpace(publicHostIP)) != 0 && len(strings.TrimSpace(publicHostName)) != 0 {
			config = getSshConfig(key, publicHostName)
			config1 := getSshConfig(key, privateHostName)
			sClient, err = sshClientJumpHost(config, config1, publicHostIP+":22", privateHostIP+":22")
		} else {
			config = getSshConfig(key, privateHostName)
			sClient, err = ssh.Dial("tcp", privateHostIP+":22", config)
		}

		if err != nil {
			return "", fmt.Errorf("unable to log in to the node: %w", err)
		}

		output, err = RunCommandInSSHSession(sClient, command)
		return output, err
	})

	return output, err
}

// connectToHostsWithMultipleUsers establishes SSH connections to a host using multiple user credentials.
// It takes the public and private IP addresses and host names for two different users.
// Returns two SSH clients for the respective users, along with any errors encountered during the process.
func ConnectToHostsWithMultipleUsers(publicHostName, publicHostIP, privateHostName, privateHostIP string) (*ssh.Client, *ssh.Client, error, error) {
	// Get the SSH private key file path for the first user from the environment variable
	sshKeyFilePathUserOne := os.Getenv("SSHFILEPATH")
	// Check if the file exists
	if _, err := os.Stat(sshKeyFilePathUserOne); os.IsNotExist(err) {
		return nil, nil, fmt.Errorf("SSH private key file '%s' does not exist", sshKeyFilePathUserOne), nil
	} else if err != nil {
		return nil, nil, fmt.Errorf("error checking SSH private key file: %v", err), nil
	}
	sshKeyUserOne, errUserOne := getSshKeyFile(sshKeyFilePathUserOne)
	if errUserOne != nil {
		return nil, nil, fmt.Errorf("failed to get SSH key for user one: %w", errUserOne), nil
	}

	// Get the SSH private key file path for the second user from the environment variable
	sshKeyFilePathUserTwo := os.Getenv("SSHFILEPATHTWO")
	// Check if the file exists
	if _, err := os.Stat(sshKeyFilePathUserTwo); os.IsNotExist(err) {
		return nil, nil, nil, fmt.Errorf("SSH private key file '%s' does not exist", sshKeyFilePathUserTwo)
	} else if err != nil {
		return nil, nil, nil, fmt.Errorf("error checking SSH private key file: %v", err)
	}
	sshKeyUserTwo, errUserTwo := getSshKeyFile(sshKeyFilePathUserTwo)
	if errUserTwo != nil {
		return nil, nil, nil, fmt.Errorf("failed to get SSH key for user two: %w", errUserTwo)
	}

	// Combine errors for better readability
	var combinedErrUserOne error
	if errUserOne != nil {
		combinedErrUserOne = fmt.Errorf("user one SSH key error: %v", errUserOne)
	}
	var combinedErrUserTwo error
	if errUserTwo != nil {
		combinedErrUserTwo = fmt.Errorf("user two SSH key error: %v", errUserTwo)
	}

	if combinedErrUserOne != nil && combinedErrUserTwo != nil {
		return nil, nil, combinedErrUserOne, combinedErrUserTwo
	}

	// Create SSH configurations for each user and host combination
	sshConfigUserOnePrivate := getSshConfig(sshKeyUserOne, privateHostName)
	sshConfigUserOnePublic := getSshConfig(sshKeyUserOne, publicHostName)
	sshConfigUserTwoPrivate := getSshConfig(sshKeyUserTwo, privateHostName)
	sshConfigUserTwoPublic := getSshConfig(sshKeyUserTwo, publicHostName)

	// Establish SSH connections for each user to the host
	clientUserOne, errUserOne := sshClientJumpHost(sshConfigUserOnePrivate, sshConfigUserOnePublic, publicHostIP+":22", privateHostIP+":22")
	clientUserTwo, errUserTwo := sshClientJumpHost(sshConfigUserTwoPrivate, sshConfigUserTwoPublic, publicHostIP+":22", privateHostIP+":22")

	// Combine errors for better readability
	var combinedErrClientUserOne error
	if errUserOne != nil {
		combinedErrClientUserOne = fmt.Errorf("user one unable to log in to the node: %v", errUserOne)
	}
	var combinedErrClientUserTwo error
	if errUserTwo != nil {
		combinedErrClientUserTwo = fmt.Errorf("user two unable to log in to the node: %v", errUserTwo)
	}

	return clientUserOne, clientUserTwo, combinedErrClientUserOne, combinedErrClientUserTwo
}

func ConnectToHostAsLDAPUser(publicHostName, publicHostIP, privateHostIP, ldapUser, ldapPassword string) (*ssh.Client, error) {

	sshFilePath := os.Getenv("SSH_FILE_PATH")

	// Check if the file exists
	_, err := os.Stat(sshFilePath)
	if os.IsNotExist(err) {
		return nil, fmt.Errorf("SSH private key file '%s' does not exist", sshFilePath)
	} else if err != nil {
		return nil, fmt.Errorf("error checking SSH private key file: %v", err)
	}

	key, err := getSshKeyFile(sshFilePath)
	if err != nil {
		return nil, fmt.Errorf("failed to get SSH key: %w", err)
	}

	config := getSshConfig(key, publicHostName)

	config1 := &ssh.ClientConfig{
		User: ldapUser,
		Auth: []ssh.AuthMethod{
			ssh.Password(ldapPassword),
		},
		HostKeyCallback: ssh.InsecureIgnoreHostKey(),
	}

	sClient, err := sshClientJumpHost(config, config1, publicHostIP+":22", privateHostIP+":22")
	if err != nil {
		return nil, fmt.Errorf("unable to log in to the node: %w", err)
	}
	return sClient, nil
}
