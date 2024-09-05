package tests

import (
	"fmt"
	"testing"
	"time"

	utils "github.com/terraform-ibm-modules/terraform-ibm-hpc/common_utils"
	"golang.org/x/crypto/ssh"
)

// VerifyManagementNodeConfigCustomImageBuilder verifies the configuration of a management node by performing various checks.
// It checks the cluster ID, master name, Reservation ID and Run tasks.
// The results of the checks are logged using the provided logger.
func VerifyManagementNodeConfigCustomImageBuilder(
	t *testing.T,
	sshMgmtClient *ssh.Client,
	expectedClusterID, expectedMasterName, expectedReservationID string,
	jobCommand string,
	logger *utils.AggregatedLogger,
) {

	// Running modifycontentforcustomimagebuilder.py in management server
	_, err := utils.RunCommandInSSHSession(sshMgmtClient, "sudo python3 modifycontentforcustomimagebuilder.py")
	if err != nil {
		_ = fmt.Sprintf("Python file not executed and got error %s", err)
	}

	// Restart the systemctl after modifying the file content
	utils.RunCommandInSSHSession(sshMgmtClient, "sudo systemctl restart lsfd")
	time.Sleep(30 * time.Second)

	// Verify cluster ID
	checkClusterIDErr := LSFCheckClusterID(t, sshMgmtClient, expectedClusterID, logger)
	utils.LogVerificationResult(t, checkClusterIDErr, "check Cluster ID on management node", logger)

	// Verify master name
	checkMasterNameErr := LSFCheckMasterName(t, sshMgmtClient, expectedMasterName, logger)
	utils.LogVerificationResult(t, checkMasterNameErr, "check Master name on management node", logger)

	// Verify Reservation ID
	ReservationIDErr := HPCCheckReservationID(t, sshMgmtClient, expectedReservationID, logger)
	utils.LogVerificationResult(t, ReservationIDErr, "check Reservation ID on management node", logger)

	//Run job
	jobErr := LSFRunJobs(t, sshMgmtClient, jobCommand, logger)
	utils.LogVerificationResult(t, jobErr, "check Run job on management node", logger)
}

// VerifyComputeNodeConfigCustomImageBuilder verifies the configuration of compute nodes by performing various checks
// It checks the cluster ID, such as verify LSF commands.
// The results of the checks are logged using the provided logger.
// NOTE : Compute Node nothing but worker node
func VerifyComputeNodeConfigCustomImageBuilder(
	t *testing.T,
	sshMgmtClient *ssh.Client,
	computeNodeIPList []string,
	logger *utils.AggregatedLogger,
) {

	// Verify LSF commands
	lsfCmdErr := VerifyLSFCommands(t, sshMgmtClient, "compute", logger)
	utils.LogVerificationResult(t, lsfCmdErr, "Check the 'lsf' command on the compute node", logger)

}

// VerifyCustomImageBuilderConfig verifies the configuration of a management node by performing various checks.
// The results of the checks are logged using the provided logger.
func VerifyCustomImageBuilderConfig(
	t *testing.T,
	sshMgmtClient *ssh.Client,
	jobCommand string,
	logger *utils.AggregatedLogger,
) {
	_, err := utils.RunCommandInSSHSession(sshMgmtClient, "sudo python3 modifycontentforcustomimagebuilder.py")
	if err != nil {
		_ = fmt.Sprintf("Python file not executed and got error %s", err)
	}

	// Restart the systemctl after modifying the file content
	utils.RunCommandInSSHSession(sshMgmtClient, "sudo systemctl restart lsfd")
	time.Sleep(30 * time.Second)

	// Run job
	jobErr := LSFRunJobs(t, sshMgmtClient, jobCommand, logger)
	utils.LogVerificationResult(t, jobErr, "check Run job on management node", logger)

}

// ValidateCustomImageBuilderCreationViaCLI validates a custom-image creation successfull or not on IBM Cloud.
// It logs into IBM Cloud using the provided API key, region, and resource group, then validate the custom-image creation
// Returns:error - An error if any operation fails, otherwise nil.
func ValidateCustomImageBuilderCreationViaCLI(t *testing.T, apiKey, expectedZone, expectedResourceGroup, customImageBuilderName string, logger *utils.AggregatedLogger) error {

	createcustomImageErr := ValidateCustomImageBuilderCreation(t, apiKey, expectedZone, expectedResourceGroup, customImageBuilderName, logger)
	// Log the verification result for creating the custom-image
	utils.LogVerificationResult(t, createcustomImageErr, "", logger)
	if createcustomImageErr != nil {
		return createcustomImageErr
	}
	return nil
}
