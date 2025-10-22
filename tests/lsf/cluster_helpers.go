package tests

import (
	"errors"
	"fmt"
	"strings"
	"testing"

	"github.com/stretchr/testify/require"
	"github.com/terraform-ibm-modules/ibmcloud-terratest-wrapper/testhelper"
	utils "github.com/terraform-ibm-modules/terraform-ibm-hpc/utilities"
	"golang.org/x/crypto/ssh"
)

// VerifyManagementNodeConfig verifies the configuration of a management node by performing various checks.
// It checks the cluster ID, master name, MTU, IP route, hyperthreading, LSF version, Run tasks and file mount.
// The results of the checks are logged using the provided logger.
func VerifyManagementNodeConfig(
	t *testing.T,
	sshMgmtClient *ssh.Client,
	clusterPrefix string,
	expectedHyperthreadingStatus bool,
	managementNodeIPList []string,
	lsfVersion string,
	logger *utils.AggregatedLogger,
) {

	// Validate LSF health on the management node
	healthCheckErr := LSFHealthCheck(t, sshMgmtClient, logger)
	utils.LogVerificationResult(t, healthCheckErr, "Validate LSF health on management node", logger)

	// Verify cluster name
	clusterNameErr := LSFCheckClusterName(t, sshMgmtClient, clusterPrefix, logger)
	utils.LogVerificationResult(t, clusterNameErr, "Verify cluster name on management node", logger)

	// Verify Master Name
	checkMasterNameErr := LSFCheckMasterName(t, sshMgmtClient, clusterPrefix, logger)
	utils.LogVerificationResult(t, checkMasterNameErr, "Check Master Name on management node", logger)

	// MTU check for management nodes
	mtuCheckErr := LSFMTUCheck(t, sshMgmtClient, managementNodeIPList, logger)
	utils.LogVerificationResult(t, mtuCheckErr, "MTU check on management node", logger)

	// IP route check for management nodes
	ipRouteCheckErr := LSFIPRouteCheck(t, sshMgmtClient, managementNodeIPList, logger)
	utils.LogVerificationResult(t, ipRouteCheckErr, "IP route check on management node", logger)

	// Hyperthreading check
	hyperthreadErr := LSFCheckHyperthreading(t, sshMgmtClient, expectedHyperthreadingStatus, logger)
	utils.LogVerificationResult(t, hyperthreadErr, "Hyperthreading check on management node", logger)

	// LSF version check
	versionErr := CheckLSFVersion(t, sshMgmtClient, lsfVersion, logger)
	utils.LogVerificationResult(t, versionErr, "check LSF version on management node", logger)

	//File Mount
	fileMountErr := CheckFileMount(t, sshMgmtClient, managementNodeIPList, "management", logger)
	utils.LogVerificationResult(t, fileMountErr, "File mount check on management node", logger)

}

// VerifySSHKey verifies SSH keys for both management and compute nodes.
// It checks SSH keys for a specified node type (management or compute) on a list of nodes.
// Logs errors if the node list is empty or an invalid node type is provided.
// Verification results are logged using the provided logger.
func VerifySSHKey(t *testing.T, sshMgmtClient *ssh.Client, publicHostIP, publicHostName, privateHostName string, nodeType string, nodeList []string, numOfKeys int, logger *utils.AggregatedLogger) {

	// Check if the node list is empty
	if len(nodeList) == 0 {
		errorMsg := fmt.Sprintf("%s node IPs cannot be empty", nodeType)
		utils.LogVerificationResult(t, fmt.Errorf("%s", errorMsg), fmt.Sprintf("%s node SSH check", nodeType), logger)
		return
	}

	// Normalize nodeType to lowercase
	nodeType = strings.ToLower(nodeType)
	var sshKeyCheckErr error
	switch nodeType {
	case "management":
		sshKeyCheckErr = LSFCheckSSHKeyForManagementNodes(t, publicHostName, publicHostIP, privateHostName, nodeList, numOfKeys, logger)
	case "compute":
		sshKeyCheckErr = LSFCheckSSHKeyForComputeNodes(t, sshMgmtClient, nodeList, logger)
	default:
		errorMsg := fmt.Sprintf("unknown node type for SSH key verification: %s", nodeType)
		utils.LogVerificationResult(t, fmt.Errorf("%s", errorMsg), fmt.Sprintf("%s node SSH check", nodeType), logger)
		return
	}

	// Log the result of the SSH key check
	utils.LogVerificationResult(t, sshKeyCheckErr, fmt.Sprintf("%s node SSH check", nodeType), logger)
}

// FailoverAndFailback performs a failover and failback procedure for a cluster using LSF (Load Sharing Facility).
// It stops the bctrl daemon, runs jobs, and starts the bctrl daemon.
// It logs verification results using the provided logger.
func FailoverAndFailback(t *testing.T, sshMgmtClient *ssh.Client, jobCommand string, logger *utils.AggregatedLogger) {

	//Stop sbatchd
	stopDaemonsErr := LSFControlBctrld(t, sshMgmtClient, "stop", logger)
	utils.LogVerificationResult(t, stopDaemonsErr, "check bctrl stop on management node", logger)

	//Run job
	jobErr := LSFRunJobs(t, sshMgmtClient, jobCommand, logger)
	utils.LogVerificationResult(t, jobErr, "check Run job on management node", logger)

	//Start sbatchd
	startDaemonsErr := LSFControlBctrld(t, sshMgmtClient, "start", logger)
	utils.LogVerificationResult(t, startDaemonsErr, "check bctrl start on management node", logger)
}

// RestartLsfDaemon restarts the LSF (Load Sharing Facility) daemons.
// It logs verification results using the provided logger.
func RestartLsfDaemon(t *testing.T, sshMgmtClient *ssh.Client, logger *utils.AggregatedLogger) {

	//Restart Daemons
	restartDaemonErr := LSFRestartDaemons(t, sshMgmtClient, logger)
	utils.LogVerificationResult(t, restartDaemonErr, "check lsf_daemons restart", logger)

}

// RebootInstance reboots an instance in a cluster using LSF (Load Sharing Facility).
// It performs instance reboot, establishes a new SSH connection to the master node,
// checks the bhosts response, and logs verification results using the provided logger.
func RebootInstance(t *testing.T, sshMgmtClient *ssh.Client, publicHostIP, publicHostName, privateHostName, managementNodeIP string, logger *utils.AggregatedLogger) {

	//Reboot the management node one
	rebootErr := LSFRebootInstance(t, sshMgmtClient, logger)
	utils.LogVerificationResult(t, rebootErr, "instance reboot", logger)

	// Connect to the master node via SSH and handle connection errors
	sshClient, connectionErr := utils.ConnectToHost(publicHostName, publicHostIP, privateHostName, managementNodeIP)
	utils.LogVerificationResult(t, connectionErr, "SSH connection to the master", logger)

	//Run bhost command
	bhostRespErr := LSFCheckBhostsResponse(t, sshClient, logger)
	utils.LogVerificationResult(t, bhostRespErr, "bhosts response non-empty", logger)

	defer func() {
		if err := sshClient.Close(); err != nil {
			logger.Info(t, fmt.Sprintf("failed to close sshClient: %v", err))
		}
	}()

}

// VerifyComputeNodeConfig verifies the configuration of compute nodes by performing various checks
// It checks the cluster ID,such as MTU, IP route, hyperthreading, file mount, and Intel One MPI.
// The results of the checks are logged using the provided logger.
// NOTE : Compute Node nothing but worker node
func VerifyComputeNodeConfig(
	t *testing.T,
	sshMgmtClient *ssh.Client,
	expectedHyperthreadingStatus bool,
	computeNodeIPList []string,
	logger *utils.AggregatedLogger,
) {

	// MTU check for compute nodes
	mtuCheckErr := LSFMTUCheck(t, sshMgmtClient, computeNodeIPList, logger)
	utils.LogVerificationResult(t, mtuCheckErr, "MTU check on compute node", logger)

	// IP route check for compute nodes
	ipRouteCheckErr := LSFIPRouteCheck(t, sshMgmtClient, computeNodeIPList, logger)
	utils.LogVerificationResult(t, ipRouteCheckErr, "IP route check on compute node", logger)

	// Hyperthreading check
	hyperthreadErr := LSFCheckHyperthreading(t, sshMgmtClient, expectedHyperthreadingStatus, logger)
	utils.LogVerificationResult(t, hyperthreadErr, "Hyperthreading check on compute node", logger)

	// File mount
	fileMountErr := CheckFileMount(t, sshMgmtClient, computeNodeIPList, "compute", logger)
	utils.LogVerificationResult(t, fileMountErr, "File mount check on compute node", logger)

	// Intel One mpi
	intelOneMpiErr := LSFCheckIntelOneMpiOnComputeNodes(t, sshMgmtClient, computeNodeIPList, logger)
	utils.LogVerificationResult(t, intelOneMpiErr, "Intel One Mpi check on compute node", logger)

}

// VerifyAPPCenterConfig verifies the configuration of the Application Center by performing various checks.
// If more than one management node exists, validation runs on node 2; otherwise on node 1.
func VerifyAPPCenterConfig(
	t *testing.T,
	sshMgmtClient *ssh.Client,
	publicHostIP, publicHostName, privateHostName string,
	managementNodeIPs []string,
	logger *utils.AggregatedLogger,
) {
	var targetSSHClient *ssh.Client
	var nodeLabel string

	if len(managementNodeIPs) > 1 {
		// Connect to management node 2
		appCenterSSHClient, err := utils.ConnectToHost(publicHostName, publicHostIP, privateHostName, managementNodeIPs[1])
		if err != nil {
			msg := fmt.Sprintf(
				"Failed to SSH to management node 2 via bastion (%s) -> private IP (%s): %v",
				publicHostIP, managementNodeIPs[1], err,
			)
			logger.FAIL(t, msg)
			require.FailNow(t, msg)
		}
		defer func() {
			if cerr := appCenterSSHClient.Close(); cerr != nil {
				logger.Warn(t, fmt.Sprintf("Failed to close SSH connection: %v", cerr))
			}
		}()
		targetSSHClient = appCenterSSHClient
		nodeLabel = "Application Center (mgmt node 2)"
	} else {
		// Use the provided SSH client (mgmt node 1)
		targetSSHClient = sshMgmtClient
		nodeLabel = "Application Center (mgmt node 1)"
	}

	// Run App Center validation
	appCenterErr := LSFAPPCenterConfiguration(t, targetSSHClient, logger)
	utils.LogVerificationResult(t, appCenterErr, nodeLabel, logger)

	logger.Info(t, fmt.Sprintf("Completed %s validation.", nodeLabel))

}

// VerifyLoginNodeConfig validates the configuration of a login node by performing multiple checks.
// It verifies the cluster name, master node name, MTU settings, IP routing, hyperthreading status,
// LSF version, file mounts, job execution, and LSF command availability.
// All results are logged using the provided logger.
func VerifyLoginNodeConfig(
	t *testing.T,
	sshLoginClient *ssh.Client,
	clusterPrefix string,
	expectedHyperthreadingStatus bool,
	loginNodeIP string,
	jobCommand string,
	lsfVersion string,
	logger *utils.AggregatedLogger,
) {
	// Verify cluster name
	clusterNameErr := LSFCheckClusterName(t, sshLoginClient, clusterPrefix, logger)
	utils.LogVerificationResult(t, clusterNameErr, "Verify cluster name on login node", logger)

	// Verify master node name
	masterNameErr := LSFCheckMasterName(t, sshLoginClient, clusterPrefix, logger)
	utils.LogVerificationResult(t, masterNameErr, "Verify master node name on login node", logger)

	// Check MTU configuration
	mtuErr := LSFMTUCheck(t, sshLoginClient, []string{loginNodeIP}, logger)
	utils.LogVerificationResult(t, mtuErr, "Verify MTU configuration on login node", logger)

	// Check IP routing
	ipRouteErr := LSFIPRouteCheck(t, sshLoginClient, []string{loginNodeIP}, logger)
	utils.LogVerificationResult(t, ipRouteErr, "Verify IP routing on login node", logger)

	// Check hyperthreading status
	hyperthreadingErr := LSFCheckHyperthreading(t, sshLoginClient, expectedHyperthreadingStatus, logger)
	utils.LogVerificationResult(t, hyperthreadingErr, "Verify hyperthreading status on login node", logger)

	// Check LSF version
	versionErr := CheckLSFVersion(t, sshLoginClient, lsfVersion, logger)
	utils.LogVerificationResult(t, versionErr, "Verify LSF version on login node", logger)

	// Verify file mounts
	fileMountErr := CheckFileMount(t, sshLoginClient, []string{loginNodeIP}, "login", logger)
	utils.LogVerificationResult(t, fileMountErr, "Verify file mounts on login node", logger)

	// Execute test job
	jobExecutionErr := LSFRunJobs(t, sshLoginClient, LOGIN_NODE_EXECUTION_PATH+jobCommand, logger)
	utils.LogVerificationResult(t, jobExecutionErr, "Verify job execution on login node", logger)

	// Verify LSF commands availability
	lsfCmdErr := VerifyLSFCommands(t, sshLoginClient, "login", logger)
	utils.LogVerificationResult(t, lsfCmdErr, "Verify availability of LSF commands on login node", logger)
}

// VerifyTestTerraformOutputs is a function that verifies the Terraform outputs for a test scenario.
func VerifyTestTerraformOutputs(
	t *testing.T,
	bastionIP, deployerIP string,
	isCloudLogEnabled, isCloudMonitoringEnabled bool,
	ldapServerEnabled bool,
	logger *utils.AggregatedLogger,
) {

	// Check the Terraform logger outputs
	outputErr := ValidateTerraformOutput(t, bastionIP, deployerIP, isCloudLogEnabled, isCloudMonitoringEnabled, ldapServerEnabled, logger)
	utils.LogVerificationResult(t, outputErr, "check terraform outputs", logger)

}

// VerifySSHConnectivityToNodesFromLogin is a function that verifies SSH connectivity from a login node to other nodes.
func VerifySSHConnectivityToNodesFromLogin(
	t *testing.T,
	sshLoginClient *ssh.Client,
	managementNodeIPList []string,
	computeNodeIPList []string,
	logger *utils.AggregatedLogger,
) {

	// ssh into management node and compute node from a login node
	sshConnectivityErr := LSFCheckSSHConnectivityToNodesFromLogin(t, sshLoginClient, managementNodeIPList, computeNodeIPList, logger)
	utils.LogVerificationResult(t, sshConnectivityErr, "check SSH connectivity from the login node to other nodes", logger)
}

// VerifyNoVNCConfig verifies the noVNC configuration by performing various checks.
func VerifyNoVNCConfig(
	t *testing.T,
	sshMgmtClient *ssh.Client,
	logger *utils.AggregatedLogger,
) {

	// Verify noVNC center
	appCenterErr := LSFCheckNoVNC(t, sshMgmtClient, logger)
	utils.LogVerificationResult(t, appCenterErr, "check noVnc", logger)

}

// VerifyJobs verifies LSF job execution, logging any errors.
func VerifyJobs(t *testing.T, sshClient *ssh.Client, jobCommand string, logger *utils.AggregatedLogger) {

	//Run job
	jobErr := LSFRunJobs(t, sshClient, jobCommand, logger)
	utils.LogVerificationResult(t, jobErr, "check Run job", logger)

}

// VerifyFileShareEncryption checks the encryption settings for file shares and verifies CRN encryption.
// It logs the results of both encryption checks for auditing purposes.
func VerifyFileShareEncryption(t *testing.T, sshMgmtClient *ssh.Client, apiKey, region, resourceGroup, clusterPrefix, keyManagement string, managementNodeIPList []string, logger *utils.AggregatedLogger) {
	// Validate encryption
	encryptErr := VerifyEncryption(t, apiKey, region, resourceGroup, clusterPrefix, keyManagement, logger)
	utils.LogVerificationResult(t, encryptErr, "File share encryption validation", logger)

	encryptCRNErr := VerifyEncryptionCRN(t, sshMgmtClient, keyManagement, managementNodeIPList, logger)
	utils.LogVerificationResult(t, encryptCRNErr, "CRN encryption validation", logger)
}

// VerifyManagementNodeLDAPConfig performs various checks on a management node's LDAP configuration.
// It verifies the LDAP configuration, checks the SSSD service, mounts files, runs jobs, and SSHs into nodes.
// The results of each check are logged with the provided logger.
func VerifyManagementNodeLDAPConfig(
	t *testing.T,
	sshMgmtClient *ssh.Client,
	bastionIP, ldapServerIP string,
	managementNodeIPList []string,
	jobCommand, ldapDomainName, ldapUserName, ldapPassword string,
	logger *utils.AggregatedLogger,
) {
	// Verify LDAP configuration
	if err := VerifyLDAPConfig(t, sshMgmtClient, "management", ldapServerIP, ldapDomainName, ldapUserName, logger); err != nil {
		utils.LogVerificationResult(t, err, "LDAP configuration verification failed", logger)
		return
	}

	// Check SSSD service status
	if err := CheckSSSDServiceStatus(t, sshMgmtClient, logger); err != nil {
		utils.LogVerificationResult(t, err, "SSSD configuration verification failed", logger)
		return
	}

	// Connect to the master node via SSH and handle errors
	sshLdapClient, err := utils.ConnectToHostAsLDAPUser(LSF_PUBLIC_HOST_NAME, bastionIP, managementNodeIPList[0], ldapUserName, ldapPassword)
	if err != nil {
		utils.LogVerificationResult(t, err, "Connection to management node via SSH as LDAP User failed", logger)
		return
	}

	defer func() {
		if err := sshLdapClient.Close(); err != nil {
			logger.Info(t, fmt.Sprintf("failed to close sshLdapClient: %v", err))
		}
	}()

	// Check file mount
	if err := CheckFileMountAsLDAPUser(t, sshLdapClient, "management", logger); err != nil {
		utils.LogVerificationResult(t, err, "File mount check as LDAP user on management node failed", logger)
	}

	// Verify LSF commands on management node as LDAP user
	if err := VerifyLSFCommandsAsLDAPUser(t, sshLdapClient, ldapUserName, "management", logger); err != nil {
		utils.LogVerificationResult(t, err, "LSF command verification as LDAP user on management node failed", logger)
	}

	// Run job as LDAP user
	if err := LSFRunJobsAsLDAPUser(t, sshLdapClient, jobCommand, ldapUserName, logger); err != nil {
		utils.LogVerificationResult(t, err, "Running job as LDAP user on management node failed", logger)
	}

	// Loop through management node IPs and perform SSH checks
	for _, ip := range managementNodeIPList {
		sshLdapClientUser, err := utils.ConnectToHostAsLDAPUser(LSF_PUBLIC_HOST_NAME, bastionIP, ip, ldapUserName, ldapPassword)
		if err != nil {
			utils.LogVerificationResult(t, err, "SSH connection to management node as LDAP user failed", logger)
			continue
		}
		logger.Info(t, fmt.Sprintf("Connected to management node %s via SSH as LDAP user", ip))
		// Close connection immediately after usage
		defer func() {
			if err := sshLdapClientUser.Close(); err != nil {
				logger.Info(t, fmt.Sprintf("failed to close sshLdapClientUser: %v", err))
			}
		}()

	}
}

// VerifyLoginNodeLDAPConfig performs various checks on a login node's LDAP configuration.
// It verifies the LDAP configuration, checks the SSSD service, mounts files, runs jobs, and checks LSF commands.
// The results of each check are logged with the provided logger.
func VerifyLoginNodeLDAPConfig(
	t *testing.T,
	sshLoginClient *ssh.Client,
	bastionIP, loginNodeIP, ldapServerIP, jobCommand, ldapDomainName, ldapUserName, ldapPassword string,
	logger *utils.AggregatedLogger,
) {
	// Verify LDAP configuration
	if err := VerifyLDAPConfig(t, sshLoginClient, "login", ldapServerIP, ldapDomainName, ldapUserName, logger); err != nil {
		utils.LogVerificationResult(t, err, "LDAP configuration verification failed", logger)
		return
	}

	// Check SSSD service status
	if err := CheckSSSDServiceStatus(t, sshLoginClient, logger); err != nil {
		utils.LogVerificationResult(t, err, "SSSD configuration verification failed", logger)
		return
	}

	// Connect to the login node via SSH and handle errors
	sshLdapClient, err := utils.ConnectToHostAsLDAPUser(LSF_PUBLIC_HOST_NAME, bastionIP, loginNodeIP, ldapUserName, ldapPassword)
	if err != nil {
		utils.LogVerificationResult(t, err, "Connection to login node via SSH as LDAP User failed", logger)
		return
	}

	defer func() {
		if err := sshLdapClient.Close(); err != nil {
			logger.Info(t, fmt.Sprintf("failed to close sshLdapClient: %v", err))
		}
	}()

	// Check file mount
	if err := CheckFileMountAsLDAPUser(t, sshLdapClient, "login", logger); err != nil {
		utils.LogVerificationResult(t, err, "File mount check as LDAP user on login node failed", logger)
	}

	// Run job as LDAP user
	if err := LSFRunJobsAsLDAPUser(t, sshLdapClient, LOGIN_NODE_EXECUTION_PATH+jobCommand, ldapUserName, logger); err != nil {
		utils.LogVerificationResult(t, err, "Running job as LDAP user on login node failed", logger)
	}

	// Verify LSF commands on login node as LDAP user
	if err := VerifyLSFCommandsAsLDAPUser(t, sshLdapClient, ldapUserName, "login", logger); err != nil {
		utils.LogVerificationResult(t, err, "LSF command verification as LDAP user on login node failed", logger)
	}
}

// VerifyComputeNodeLDAPConfig verifies the LDAP configuration, file mount, LSF commands,
// and SSH connection to all compute nodes as an LDAP user.
func VerifyComputeNodeLDAPConfig(
	t *testing.T,
	bastionIP string,
	ldapServerIP string,
	computeNodeIPList []string,
	ldapDomainName string,
	ldapUserName string,
	ldapPassword string,
	logger *utils.AggregatedLogger,
) {
	if len(computeNodeIPList) == 0 {
		utils.LogVerificationResult(t, errors.New("compute node IPs cannot be empty"), "compute ldap configuration check", logger)
		return
	}
	// Connect to the first compute node via SSH as an LDAP user
	sshLdapClient, connectionErr := utils.ConnectToHostAsLDAPUser(LSF_PUBLIC_HOST_NAME, bastionIP, computeNodeIPList[0], ldapUserName, ldapPassword)
	if connectionErr != nil {
		utils.LogVerificationResult(t, connectionErr, "connect to the compute node via SSH as LDAP User failed", logger)
		return
	}

	defer func() {
		if err := sshLdapClient.Close(); err != nil {
			logger.Info(t, fmt.Sprintf("failed to close sshLdapClient: %v", err))
		}
	}()

	// Verify LDAP configuration
	ldapErr := VerifyLDAPConfig(t, sshLdapClient, "compute", ldapServerIP, ldapDomainName, ldapUserName, logger)
	utils.LogVerificationResult(t, ldapErr, "ldap configuration check on the compute node", logger)

	// Check file mount
	fileMountErr := CheckFileMountAsLDAPUser(t, sshLdapClient, "compute", logger)
	utils.LogVerificationResult(t, fileMountErr, "check file mount as an LDAP user on the compute node", logger)

	// Verify LSF commands
	lsfCmdErr := VerifyLSFCommandsAsLDAPUser(t, sshLdapClient, ldapUserName, "compute", logger)
	utils.LogVerificationResult(t, lsfCmdErr, "Check the 'lsf' command as an LDAP user on the compute node", logger)

	// SSH connection to other compute nodes
	for i := 0; i < len(computeNodeIPList); i++ {
		sshLdapClientUser, connectionErr := utils.ConnectToHostAsLDAPUser(LSF_PUBLIC_HOST_NAME, bastionIP, computeNodeIPList[i], ldapUserName, ldapPassword)
		if connectionErr == nil {
			logger.Info(t, fmt.Sprintf("connect to the compute node %s via SSH as LDAP User", computeNodeIPList[i]))
		}
		utils.LogVerificationResult(t, connectionErr, "connect to the compute node via SSH as LDAP User", logger)

		defer func() {
			if err := sshLdapClientUser.Close(); err != nil {
				logger.Info(t, fmt.Sprintf("failed to close sshLdapClientUser: %v", err))
			}
		}()
	}
}

// CheckLDAPServerStatus performs verification of LDAP server configuration on a remote machine
// using SSH and logs the status.
func CheckLDAPServerStatus(t *testing.T, sClient *ssh.Client, ldapAdminpassword, ldapDomain, ldapUser string, logger *utils.AggregatedLogger) {
	// Validate LDAP server configuration
	ldapErr := VerifyLDAPServerConfig(t, sClient, ldapAdminpassword, ldapDomain, ldapUser, logger)
	utils.LogVerificationResult(t, ldapErr, "ldap Server Status", logger)
}

// // VerifyPTRRecordsForManagementAndLoginNodes verifies PTR records for 'mgmt' or 'login' nodes and ensures their resolution via SSH.
// // It retrieves hostnames, performs nslookup to verify PTR records, and returns an error if any step fails.
// func VerifyPTRRecordsForManagementAndLoginNodes(t *testing.T, sClient *ssh.Client, publicHostName, publicHostIP, privateHostName string, managementNodeIPList []string, loginNodeIP string, domainName string, logger *utils.AggregatedLogger) {
// 	// Call sub-function to verify PTR records
// 	err := verifyPTRRecords(t, sClient, publicHostName, publicHostIP, privateHostName, managementNodeIPList, loginNodeIP, domainName, logger)
// 	// Log the verification result
// 	utils.LogVerificationResult(t, err, "PTR Records For Management And Login Nodes", logger)

// }

// VerifyPTRRecordsForManagementAndLoginNodes verifies PTR records for 'mgmt' nodes and ensures their resolution via SSH.
// It retrieves hostnames, performs nslookup to verify PTR records, and returns an error if any step fails.
func VerifyPTRRecordsForManagement(t *testing.T, sClient *ssh.Client, publicHostName, publicHostIP, privateHostName string, managementNodeIPList []string, domainName string, logger *utils.AggregatedLogger) {
	// Call sub-function to verify PTR records
	err := verifyPTRRecords(t, sClient, publicHostName, publicHostIP, privateHostName, managementNodeIPList, domainName, logger)
	// Log the verification result
	utils.LogVerificationResult(t, err, "PTR Records For Management And Login Nodes", logger)

}

// CreateServiceInstanceAndKmsKey creates a service instance on IBM Cloud and a KMS key within that instance.
// It logs into IBM Cloud using the provided API key, region, and resource group, then creates the service instance
// and the KMS key with the specified names. It logs the results of each operation.
// Returns:error - An error if any operation fails, otherwise nil.
func CreateServiceInstanceAndKmsKey(t *testing.T, apiKey, expectedZone, expectedResourceGroup, kmsInstanceName, kmsKeyName string, logger *utils.AggregatedLogger) error {
	// Create the service instance and return its GUID
	_, createInstanceErr := CreateServiceInstanceAndReturnGUID(t, apiKey, expectedZone, expectedResourceGroup, kmsInstanceName, logger)
	// Log the verification result for creating the service instance
	utils.LogVerificationResult(t, createInstanceErr, "Create Service Instance", logger)
	if createInstanceErr != nil {
		return createInstanceErr
	}

	// If the service instance creation was successful, create the KMS key
	createKmsKeyErr := CreateKey(t, apiKey, expectedZone, expectedResourceGroup, kmsInstanceName, kmsKeyName, logger)
	// Log the verification result for creating the KMS key
	utils.LogVerificationResult(t, createKmsKeyErr, "Create KMS Key", logger)
	if createKmsKeyErr != nil {
		return createKmsKeyErr
	}

	return nil
}

// DeleteServiceInstanceAndAssociatedKeys deletes a service instance and its associated keys, then logs the result.
// This function deletes the specified service instance and its associated keys, then logs the verification result.
func DeleteServiceInstanceAndAssociatedKeys(t *testing.T, apiKey, expectedZone, expectedResourceGroup, kmsInstanceName string, logger *utils.AggregatedLogger) {

	deleteInstanceAndKey := DeleteServiceInstance(t, apiKey, expectedZone, expectedResourceGroup, kmsInstanceName, logger)

	// Log the verification result for deleting the service instance and associated KMS key
	utils.LogVerificationResult(t, deleteInstanceAndKey, "Delete Service Instance and associated KMS Key", logger)
}

// VerifyLSFDNS performs a DNS configuration check on a list of nodes using LSFDNSCheck function.
// It logs the verification result.
func VerifyLSFDNS(t *testing.T, sClient *ssh.Client, ipsList []string, domainName string, logger *utils.AggregatedLogger) {
	dnsCheckErr := LSFDNSCheck(t, sClient, ipsList, domainName, logger)
	utils.LogVerificationResult(t, dnsCheckErr, "dns check", logger)
}

// VerifyCreateNewLdapUserAndManagementNodeLDAPConfig creates a new LDAP user, verifies the LDAP configuration on the
// management node by connecting via SSH, running jobs, and verifying LSF commands. It connects to the management node
// as the new LDAP user and runs specified commands to ensure the new user is properly configured.
// It logs into the LDAP server using the provided SSH client, admin password, domain name, and user information, then
// verifies the configuration on the management node.
// Returns an error if any step fails
func VerifyCreateNewLdapUserAndManagementNodeLDAPConfig(
	t *testing.T,
	sldapClient *ssh.Client,
	bastionIP string,
	ldapServerIP string,
	managementNodeIPList []string,
	jobCommand string,
	ldapUserName string,
	ldapAdminPassword string,
	ldapDomainName string,
	newLdapUserName string,
	newLdapUserPassword string,
	logger *utils.AggregatedLogger,
) {

	// Add a new LDAP user
	if err := LSFAddNewLDAPUser(t, sldapClient, ldapAdminPassword, ldapDomainName, ldapUserName, newLdapUserName, newLdapUserPassword, logger); err != nil {
		utils.LogVerificationResult(t, err, "add new LDAP user", logger)
		return
	}

	// Connect to the management node via SSH as the new LDAP user
	sshLdapClientUser, err := utils.ConnectToHostAsLDAPUser(LSF_PUBLIC_HOST_NAME, bastionIP, managementNodeIPList[0], newLdapUserName, newLdapUserPassword)
	if err != nil {
		utils.LogVerificationResult(t, err, "connect to the management node via SSH as the new LDAP user", logger)
		return
	}

	defer func() {
		if err := sshLdapClientUser.Close(); err != nil {
			logger.Info(t, fmt.Sprintf("failed to close sshLdapClientUser: %v", err))
		}
	}()

	// Run job as the new LDAP user
	if err := LSFRunJobsAsLDAPUser(t, sshLdapClientUser, jobCommand, newLdapUserName, logger); err != nil {
		utils.LogVerificationResult(t, err, "run job as the new LDAP user on the management node", logger)
	}

	// Verify LSF commands on the management node as the new LDAP user
	if err := VerifyLSFCommandsAsLDAPUser(t, sshLdapClientUser, newLdapUserName, "management", logger); err != nil {
		utils.LogVerificationResult(t, err, "Check the 'lsf' command as the new LDAP user on the management node", logger)
	}

}

// ValidateCosServiceInstanceAndVpcFlowLogs checks both the COS service instance and the VPC flow logs.
// It logs the verification result.
func ValidateCosServiceInstanceAndVpcFlowLogs(t *testing.T, apiKey, expectedZone, expectedResourceGroup, clusterPrefix string, logger *utils.AggregatedLogger) {
	// Verify the COS service instance details
	cosErr := VerifyCosServiceInstance(t, apiKey, expectedZone, expectedResourceGroup, clusterPrefix, logger)
	utils.LogVerificationResult(t, cosErr, "COS check", logger)

	// Verify the VPC flow log details
	flowLogsErr := ValidateFlowLogs(t, apiKey, expectedZone, expectedResourceGroup, clusterPrefix, logger)
	utils.LogVerificationResult(t, flowLogsErr, "VPC flow logs check", logger)
}

// ValidateLSFLogs validates the log files in the shared folder and checks their status after a master node reboot.
// It performs two main checks: verifying log files in the shared folder and ensuring the log files are intact after the reboot.
// This ensures that LSF logs are available and up-to-date in LSF log-related scenarios.
func ValidateLSFLogs(t *testing.T, sshClient *ssh.Client, apiKey, region, resourceGroup, bastionIP string, managementMasterNodeIPList []string, logger *utils.AggregatedLogger) {
	// Check the log files in the shared folder for all nodes
	err := LogFilesInSharedFolder(t, sshClient, logger)
	utils.LogVerificationResult(t, err, "Log files in shared folder check", logger)

	// Validate that log files are still available after the master node reboot
	err = LogFilesAfterMasterReboot(t, sshClient, bastionIP, managementMasterNodeIPList[0], logger)
	utils.LogVerificationResult(t, err, "Log files after master reboot check", logger)

	// Reconnect to the management node after reboot
	sshClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementMasterNodeIPList[0])
	if connectionErr != nil {
		logger.Error(t, fmt.Sprintf("Failed to reconnect to the master via SSH after reboot: %s", connectionErr))
		utils.LogVerificationResult(t, connectionErr, fmt.Sprintf("Failed to reconnect to the master via SSH after reboot: %s", connectionErr), logger)
		return // Exit if SSH connection fails
	}

	// Validate the log files after the master node shutdown
	err = LogFilesAfterMasterShutdown(t, sshClient, apiKey, region, resourceGroup, bastionIP, managementMasterNodeIPList, logger)
	utils.LogVerificationResult(t, err, "Log files after master shutdown check", logger)
}

// ValidatePACHAOnManagementNodes validates the configuration of the PACHA application center.
// It performs validation on both the management node and additional management nodes.

func ValidatePACHAOnManagementNodes(t *testing.T, sshClient *ssh.Client, domainName, publicHostIP string, managementNodeIPList []string, logger *utils.AggregatedLogger) {

	// Validate the application center configuration on the primary management node.
	err := ValidatePACHAConfigOnManagementNode(t, sshClient, domainName, logger)
	utils.LogVerificationResult(t, err, "Validation of application center configuration on the primary management node", logger)

	// Validate the application center configuration on additional management nodes.
	err = ValidatePACHAConfigOnManagementNodes(t, sshClient, publicHostIP, managementNodeIPList, domainName, logger)
	utils.LogVerificationResult(t, err, "Validation of application center configuration on additional management nodes", logger)

}

// ValidatePACHAFailoverHealthCheckOnManagementNodes validates the failover functionality and configuration of the PACHA application center.
// It performs validation on both the management node and additional management nodes to ensure failover functionality.

func ValidatePACHAFailoverHealthCheckOnManagementNodes(t *testing.T, sshClient *ssh.Client, domainName, publicHostIP string, managementNodeIPList []string, logger *utils.AggregatedLogger) {

	err := ValidatePACHAFailoverOnManagementNodes(t, sshClient, publicHostIP, managementNodeIPList, logger)
	utils.LogVerificationResult(t, err, "Validation of application center configuration on additional management nodes", logger)
}

// ValidateDedicatedHost validates whether the dedicated host exists and is properly configured.
// It calls the verifyDedicatedHost function to perform the actual validation and logs the result.
func ValidateDedicatedHost(t *testing.T, apiKey, region, resourceGroup, clusterPrefix string, expectedWorkerNodeCount int, expectedDedicatedHostPresence bool, logger *utils.AggregatedLogger) {
	// Perform dedicated host verification
	err := verifyDedicatedHost(t, apiKey, region, resourceGroup, clusterPrefix, expectedWorkerNodeCount, expectedDedicatedHostPresence, logger)

	// Log failure if verification fails
	utils.LogVerificationResult(t, err, "Dedicated host verification", logger)

}

// It checks the service instance details, extracts relevant GUIDs, and ensures attachments are in the expected state.
func ValidateSCCInstance(t *testing.T, apiKey, region, resourceGroup, clusterPrefix, sccInstanceRegion string, logger *utils.AggregatedLogger) {

	err := VerifySCCInstance(t, apiKey, region, resourceGroup, clusterPrefix, sccInstanceRegion, logger)

	// Log failure if verification fails
	utils.LogVerificationResult(t, err, "Scc Instance verification", logger)

}

// VerifyCloudLogs validates the configuration and status of cloud logging services.
// The function logs verification results for each step and handles errors gracefully.
// Parameters include test context, SSH client, cluster details, and logging configuration.
// The function does not return values but logs outcomes for validation steps.
func VerifyCloudLogs(
	t *testing.T,
	sshClient *ssh.Client,
	LastTestTerraformOutputs map[string]interface{},
	managementNodeIPList []string, staticWorkerNodeIPList []string,
	isCloudLogsEnabledForManagement, isCloudLogsEnabledForCompute bool,
	logger *utils.AggregatedLogger) {

	// Verify Fluent Bit service for management nodes
	mgmtErr := VerifyFluentBitServiceForManagementNodes(t, sshClient, managementNodeIPList, isCloudLogsEnabledForManagement, logger)
	utils.LogVerificationResult(t, mgmtErr, "Fluent Bit service for management nodes", logger)

	// Verify Fluent Bit service for compute nodes
	compErr := VerifyFluentBitServiceForComputeNodes(t, sshClient, staticWorkerNodeIPList, isCloudLogsEnabledForCompute, logger)
	utils.LogVerificationResult(t, compErr, "Fluent Bit service for compute nodes", logger)

}

// VerifyPlatformLogs validates whether platform logs are enabled or disabled.
// It uses the provided API key, region, and logger to check the platform log status.
// The result is logged using the aggregated logger.
func VerifyPlatformLogs(
	t *testing.T,
	apiKey, region, resourceGroup string,
	isPlatformLogsEnabled bool,
	logger *utils.AggregatedLogger,
) {

	err := VerifyPlatformStatus(t, apiKey, region, resourceGroup, isPlatformLogsEnabled, logger)
	utils.LogVerificationResult(t, err, "Platform logs", logger)

}

// ValidateDynamicNodeProfile validates the dynamic worker node profile by fetching it from Terraform variables
// and comparing it against the expected profile obtained from IBM Cloud CLI.
func ValidateDynamicNodeProfile(t *testing.T, apiKey, region, resourceGroup, clusterPrefix string, options *testhelper.TestOptions, logger *utils.AggregatedLogger) {

	expectedDynamicWorkerProfile, expectedWorkerNodeProfileErr := utils.GetFirstDynamicComputeProfile(t, options.TerraformVars, logger)
	utils.LogVerificationResult(t, expectedWorkerNodeProfileErr, "Fetching dynamic worker node profile", logger)

	validateDynamicWorkerProfileErr := ValidateDynamicWorkerProfile(t, apiKey, region, resourceGroup, clusterPrefix, expectedDynamicWorkerProfile, logger)
	utils.LogVerificationResult(t, validateDynamicWorkerProfileErr, "Validating dynamic worker node profile", logger)

}

// VerifyCloudMonitoring checks the cloud monitoring configuration and status.
// The function logs verification results
// and handles errors gracefully. It takes test context, SSH client, cluster
// details, monitoring flags, and a logger as parameters. No values are
// returned; only validation outcomes are logged.
func VerifyCloudMonitoring(
	t *testing.T,
	sshClient *ssh.Client,
	LastTestTerraformOutputs map[string]interface{},
	managementNodeIPList []string, staticWorkerNodeIPList []string,
	isCloudMonitoringEnableForManagement, isCloudMonitoringEnableForCompute bool,
	logger *utils.AggregatedLogger) {

	// Verify Prometheus Dragent service for management nodes
	mgmtErr := LSFPrometheusAndDragentServiceForManagementNodes(t, sshClient, managementNodeIPList, isCloudMonitoringEnableForManagement, logger)
	utils.LogVerificationResult(t, mgmtErr, "Prometheus and Dragent service for management nodes", logger)

	// Verify Dragent service for compute nodes
	compErr := LSFDragentServiceForComputeNodes(t, sshClient, staticWorkerNodeIPList, isCloudMonitoringEnableForCompute, logger)
	utils.LogVerificationResult(t, compErr, "Prometheus and Dragent service for compute nodes", logger)

}

// ValidateAtracker verifies the Atracker Route Target configuration in IBM Cloud.
// If Observability Atracker is enabled, it retrieves the target ID, ensures it meets the expected criteria,
// and validates it against the specified target type. If Observability Atracker is disabled,
// the function ensures no target ID is set. Any retrieval or validation failures are logged,
// and the function exits early in case of errors to prevent further issues.
func ValidateAtracker(t *testing.T, apiKey, region, resourceGroup, clusterPrefix, targetType string, ObservabilityAtrackerEnable bool, logger *utils.AggregatedLogger) {

	if ObservabilityAtrackerEnable {
		// Fetch the Atracker Route Target ID
		targetID, atrackerRouteTargetIDErr := GetAtrackerRouteTargetID(t, apiKey, region, resourceGroup, clusterPrefix, ObservabilityAtrackerEnable, logger)
		if atrackerRouteTargetIDErr != nil {
			utils.LogVerificationResult(t, atrackerRouteTargetIDErr, "ValidateAtracker: Failed to retrieve Atracker Route Target ID", logger)
			return // Exit early to prevent further errors
		}

		// Validate the Atracker Route Target
		atrackerRouteTargetErr := ValidateAtrackerRouteTarget(t, apiKey, region, resourceGroup, clusterPrefix, targetID, targetType, logger)
		if atrackerRouteTargetErr != nil {
			utils.LogVerificationResult(t, atrackerRouteTargetErr, "ValidateAtracker: Validation failed for Atracker Route Target", logger)
		}
	} else {
		logger.Warn(t, "Cloud atracker is disabled  - skipping validation of Atracker Route Target.")

	}
}
