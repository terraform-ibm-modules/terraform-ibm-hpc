package tests

import (
	"errors"
	"fmt"
	"strings"
	"testing"

	utils "github.com/terraform-ibm-modules/terraform-ibm-hpc/utilities"
	"golang.org/x/crypto/ssh"
)

// VerifyManagementNodeConfig verifies the configuration of a management node by performing various checks.
// It checks the cluster ID, master name, Reservation ID, MTU, IP route, hyperthreading, LSF version, Run tasks and file mount.
// The results of the checks are logged using the provided logger.
func VerifyManagementNodeConfig(
	t *testing.T,
	sshMgmtClient *ssh.Client,
	expectedClusterID, expectedMasterName, expectedReservationID string,
	expectedHyperthreadingStatus bool,
	managementNodeIPList []string,
	lsfVersion string,
	logger *utils.AggregatedLogger,
) {

	// Verify cluster ID
	checkClusterIDErr := LSFCheckClusterID(t, sshMgmtClient, expectedClusterID, logger)
	utils.LogVerificationResult(t, checkClusterIDErr, "check Cluster ID on management node", logger)

	// Verify master name
	checkMasterNameErr := LSFCheckMasterName(t, sshMgmtClient, expectedMasterName, logger)
	utils.LogVerificationResult(t, checkMasterNameErr, "check Master name on management node", logger)

	// Verify Reservation ID
	ReservationIDErr := HPCCheckReservationID(t, sshMgmtClient, expectedReservationID, logger)
	utils.LogVerificationResult(t, ReservationIDErr, "check Reservation ID on management node", logger)

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
	fileMountErr := HPCCheckFileMount(t, sshMgmtClient, managementNodeIPList, "management", logger)
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

	defer sshClient.Close()

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

	// MTU check for management nodes
	mtuCheckErr := LSFMTUCheck(t, sshMgmtClient, computeNodeIPList, logger)
	utils.LogVerificationResult(t, mtuCheckErr, "MTU check on compute node", logger)

	// IP route check for management nodes
	ipRouteCheckErr := LSFIPRouteCheck(t, sshMgmtClient, computeNodeIPList, logger)
	utils.LogVerificationResult(t, ipRouteCheckErr, "IP route check on compute node", logger)

	// Hyperthreading check
	hyperthreadErr := LSFCheckHyperthreading(t, sshMgmtClient, expectedHyperthreadingStatus, logger)
	utils.LogVerificationResult(t, hyperthreadErr, "Hyperthreading check on compute node", logger)

	// File mount
	fileMountErr := HPCCheckFileMount(t, sshMgmtClient, computeNodeIPList, "compute", logger)
	utils.LogVerificationResult(t, fileMountErr, "File mount check on compute node", logger)

	// Intel One mpi
	intelOneMpiErr := LSFCheckIntelOneMpiOnComputeNodes(t, sshMgmtClient, computeNodeIPList, logger)
	utils.LogVerificationResult(t, intelOneMpiErr, "Intel One Mpi check on compute node", logger)

}

// VerifyAPPCenterConfig verifies the configuration of the application center by performing various checks.
func VerifyAPPCenterConfig(
	t *testing.T,
	sshMgmtClient *ssh.Client,
	logger *utils.AggregatedLogger,
) {

	// Verify application center
	appCenterErr := LSFAPPCenterConfiguration(t, sshMgmtClient, logger)
	utils.LogVerificationResult(t, appCenterErr, "check Application center", logger)

}

// VerifyLoginNodeConfig verifies the configuration of a login node by performing various checks.
// It checks the cluster ID, master name, Reservation ID, MTU, IP route, hyperthreading, LSF version, Run tasks and file mount.
// The results of the checks are logged using the provided logger.
func VerifyLoginNodeConfig(
	t *testing.T,
	sshLoginClient *ssh.Client,
	expectedClusterID, expectedMasterName, expectedReservationID string,
	expectedHyperthreadingStatus bool,
	loginNodeIP string,
	jobCommand string,
	lsfVersion string,
	logger *utils.AggregatedLogger,
) {

	// Verify cluster ID
	checkClusterIDErr := LSFCheckClusterID(t, sshLoginClient, expectedClusterID, logger)
	utils.LogVerificationResult(t, checkClusterIDErr, "check Cluster ID on login node", logger)

	// Verify master name
	checkMasterNameErr := LSFCheckMasterName(t, sshLoginClient, expectedMasterName, logger)
	utils.LogVerificationResult(t, checkMasterNameErr, "check Master name on login node", logger)

	// MTU check for login nodes
	mtuCheckErr := LSFMTUCheck(t, sshLoginClient, []string{loginNodeIP}, logger)
	utils.LogVerificationResult(t, mtuCheckErr, "MTU check on login node", logger)

	// IP route check for login nodes
	ipRouteCheckErr := LSFIPRouteCheck(t, sshLoginClient, []string{loginNodeIP}, logger)
	utils.LogVerificationResult(t, ipRouteCheckErr, "IP route check on login node", logger)

	// Hyperthreading check
	hyperthreadErr := LSFCheckHyperthreading(t, sshLoginClient, expectedHyperthreadingStatus, logger)
	utils.LogVerificationResult(t, hyperthreadErr, "Hyperthreading check on login node", logger)

	// LSF version check
	versionErr := CheckLSFVersion(t, sshLoginClient, lsfVersion, logger)
	utils.LogVerificationResult(t, versionErr, "check LSF version", logger)

	//File Mount
	fileMountErr := HPCCheckFileMount(t, sshLoginClient, []string{loginNodeIP}, "login", logger)
	utils.LogVerificationResult(t, fileMountErr, "File mount check on login node", logger)

	//Run job
	jobErr := LSFRunJobs(t, sshLoginClient, LOGIN_NODE_EXECUTION_PATH+jobCommand, logger) //Added the executable path
	utils.LogVerificationResult(t, jobErr, "check Run job on login node", logger)

	// Verify LSF commands
	lsfCmdErr := VerifyLSFCommands(t, sshLoginClient, "login", logger)
	utils.LogVerificationResult(t, lsfCmdErr, "Check the 'lsf' command on the login node", logger)
}

// VerifyTestTerraformOutputs is a function that verifies the Terraform outputs for a test scenario.
func VerifyTestTerraformOutputs(
	t *testing.T,
	LastTestTerraformOutputs map[string]interface{},
	isAPPCenterEnabled bool,
	ldapServerEnabled bool,
	logger *utils.AggregatedLogger,
) {

	// Check the Terraform logger outputs
	outputErr := VerifyTerraformOutputs(t, LastTestTerraformOutputs, isAPPCenterEnabled, ldapServerEnabled, logger)
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
	appCenterErr := HPCCheckNoVNC(t, sshMgmtClient, logger)
	utils.LogVerificationResult(t, appCenterErr, "check noVnc", logger)

}

// VerifyJobs verifies LSF job execution, logging any errors.
func VerifyJobs(t *testing.T, sshClient *ssh.Client, jobCommand string, logger *utils.AggregatedLogger) {

	//Run job
	jobErr := LSFRunJobs(t, sshClient, jobCommand, logger)
	utils.LogVerificationResult(t, jobErr, "check Run job", logger)

}

// VerifyFileShareEncryption verifies encryption settings for file shares.
func VerifyFileShareEncryption(t *testing.T, apiKey, region, resourceGroup, clusterPrefix, keyManagement string, logger *utils.AggregatedLogger) {
	// Validate encryption
	encryptErr := VerifyEncryption(t, apiKey, region, resourceGroup, clusterPrefix, keyManagement, logger)
	utils.LogVerificationResult(t, encryptErr, "encryption", logger)
}

// VerifyManagementNodeLDAPConfig verifies the configuration of a management node by performing various checks.
// It checks LDAP configuration, LSF commands, Run tasks, file mount, and SSH into all management nodes as an LDAP user.
// The results of the checks are logged using the provided logger.
func VerifyManagementNodeLDAPConfig(
	t *testing.T,
	sshMgmtClient *ssh.Client,
	bastionIP string,
	ldapServerIP string,
	managementNodeIPList []string,
	jobCommand string,
	ldapDomainName string,
	ldapUserName string,
	ldapPassword string,
	logger *utils.AggregatedLogger,
) {
	// Verify LDAP configuration
	ldapErr := VerifyLDAPConfig(t, sshMgmtClient, "management", ldapServerIP, ldapDomainName, ldapUserName, logger)
	if ldapErr != nil {
		utils.LogVerificationResult(t, ldapErr, "ldap configuration verification failed", logger)
		return
	}

	// Connect to the master node via SSH and handle connection errors
	sshLdapClient, connectionErr := utils.ConnectToHostAsLDAPUser(LSF_PUBLIC_HOST_NAME, bastionIP, managementNodeIPList[0], ldapUserName, ldapPassword)
	if connectionErr != nil {
		utils.LogVerificationResult(t, connectionErr, "connect to the management node via SSH as LDAP User failed", logger)
		return
	}
	defer sshLdapClient.Close()

	// Check file mount
	fileMountErr := HPCCheckFileMountAsLDAPUser(t, sshLdapClient, "management", logger)
	utils.LogVerificationResult(t, fileMountErr, "check file mount as an LDAP user on the management node", logger)

	// Verify LSF commands on management node as LDAP user
	lsfCmdErr := VerifyLSFCommandsAsLDAPUser(t, sshLdapClient, ldapUserName, "management", logger)
	utils.LogVerificationResult(t, lsfCmdErr, "Check the 'lsf' command as an LDAP user on the management node", logger)

	// Run job as ldap user
	jobErr := LSFRunJobsAsLDAPUser(t, sshLdapClient, jobCommand, ldapUserName, logger)
	utils.LogVerificationResult(t, jobErr, "check Run job as an LDAP user on the management node", logger)

	// Loop through management node IPs and perform checks
	for i := 0; i < len(managementNodeIPList); i++ {
		sshLdapClientUser, connectionErr := utils.ConnectToHostAsLDAPUser(LSF_PUBLIC_HOST_NAME, bastionIP, managementNodeIPList[i], ldapUserName, ldapPassword)
		if connectionErr == nil {
			logger.Info(t, fmt.Sprintf("connect to the management node %s via SSH as LDAP User", managementNodeIPList[i]))
		}
		utils.LogVerificationResult(t, connectionErr, "connect to the management node via SSH as LDAP User", logger)
		defer sshLdapClientUser.Close()
	}
}

// VerifyLoginNodeLDAPConfig verifies the configuration of a login node by performing various checks.
// It checks LDAP configuration, LSF commands, Run tasks, and file mount.
// The results of the checks are logged using the provided logger.
func VerifyLoginNodeLDAPConfig(
	t *testing.T,
	sshLoginClient *ssh.Client,
	bastionIP string,
	loginNodeIP string,
	ldapServerIP string,
	jobCommand string,
	ldapDomainName string,
	ldapUserName string,
	ldapPassword string,
	logger *utils.AggregatedLogger,
) {
	// Verify LDAP configuration
	ldapErr := VerifyLDAPConfig(t, sshLoginClient, "login", ldapServerIP, ldapDomainName, ldapUserName, logger)
	if ldapErr != nil {
		utils.LogVerificationResult(t, ldapErr, "ldap configuration verification failed", logger)
		return
	}

	// Connect to the login node via SSH and handle connection errors
	sshLdapClient, connectionErr := utils.ConnectToHostAsLDAPUser(LSF_PUBLIC_HOST_NAME, bastionIP, loginNodeIP, ldapUserName, ldapPassword)
	if connectionErr != nil {
		utils.LogVerificationResult(t, connectionErr, "connect to the login node via SSH as LDAP User failed", logger)
		return
	}
	defer sshLdapClient.Close()

	// Check file mount
	fileMountErr := HPCCheckFileMountAsLDAPUser(t, sshLdapClient, "login", logger)
	utils.LogVerificationResult(t, fileMountErr, "check file mount as an LDAP user on the login node", logger)

	// Run job as ldap user
	jobErr := LSFRunJobsAsLDAPUser(t, sshLdapClient, LOGIN_NODE_EXECUTION_PATH+jobCommand, ldapUserName, logger)
	utils.LogVerificationResult(t, jobErr, "check Run job as an LDAP user on the login node", logger)

	// Verify LSF commands on login node as LDAP user
	lsfCmdErr := VerifyLSFCommandsAsLDAPUser(t, sshLdapClient, ldapUserName, "login", logger)
	utils.LogVerificationResult(t, lsfCmdErr, "Check the 'lsf' command as an LDAP user on the login node", logger)
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
	defer sshLdapClient.Close()

	// Verify LDAP configuration
	ldapErr := VerifyLDAPConfig(t, sshLdapClient, "compute", ldapServerIP, ldapDomainName, ldapUserName, logger)
	utils.LogVerificationResult(t, ldapErr, "ldap configuration check on the compute node", logger)

	// Check file mount
	fileMountErr := HPCCheckFileMountAsLDAPUser(t, sshLdapClient, "compute", logger)
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
		defer sshLdapClientUser.Close()
	}
}

// CheckLDAPServerStatus performs verification of LDAP server configuration on a remote machine
// using SSH and logs the status.
func CheckLDAPServerStatus(t *testing.T, sClient *ssh.Client, ldapAdminpassword, ldapDomain, ldapUser string, logger *utils.AggregatedLogger) {
	// Validate LDAP server configuration
	ldapErr := VerifyLDAPServerConfig(t, sClient, ldapAdminpassword, ldapDomain, ldapUser, logger)
	utils.LogVerificationResult(t, ldapErr, "ldap Server Status", logger)
}

// VerifyPTRRecordsForManagementAndLoginNodes verifies PTR records for 'mgmt' or 'login' nodes and ensures their resolution via SSH.
// It retrieves hostnames, performs nslookup to verify PTR records, and returns an error if any step fails.
func VerifyPTRRecordsForManagementAndLoginNodes(t *testing.T, sClient *ssh.Client, publicHostName, publicHostIP, privateHostName string, managementNodeIPList []string, loginNodeIP string, domainName string, logger *utils.AggregatedLogger) {
	// Call sub-function to verify PTR records
	err := verifyPTRRecords(t, sClient, publicHostName, publicHostIP, privateHostName, managementNodeIPList, loginNodeIP, domainName, logger)
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
	ldapAdminPassword string,
	ldapDomainName string,
	ldapUserName string,
	ldapUserPassword string,
	newLdapUserName string,
	logger *utils.AggregatedLogger,
) {

	// Add a new LDAP user
	if err := HPCAddNewLDAPUser(t, sldapClient, ldapAdminPassword, ldapDomainName, ldapUserName, newLdapUserName, logger); err != nil {
		utils.LogVerificationResult(t, err, "add new LDAP user", logger)
		return
	}

	// Connect to the management node via SSH as the new LDAP user
	sshLdapClientUser, err := utils.ConnectToHostAsLDAPUser(LSF_PUBLIC_HOST_NAME, bastionIP, managementNodeIPList[0], newLdapUserName, ldapUserPassword)
	if err != nil {
		utils.LogVerificationResult(t, err, "connect to the management node via SSH as the new LDAP user", logger)
		return
	}
	defer sshLdapClientUser.Close()

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
