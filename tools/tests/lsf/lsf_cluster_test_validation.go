package tests

import (
	"fmt"
	"os"
	"testing"

	"github.com/stretchr/testify/require"
	"github.com/terraform-ibm-modules/ibmcloud-terratest-wrapper/testhelper"
	utils "github.com/terraform-ibm-modules/terraform-ibm-hpc/common_utils"
)

// ValidateCustomImageBuilder validates basic cluster configuration like running jobs.
// This function doesn't return any value but logs errors and validation steps during the process.
func ValidateCustomImageBuilder(t *testing.T, options *testhelper.TestOptions, testLogger *utils.AggregatedLogger) {
	fmt.Println("************************************************************************************************************************")
	// Retrieve cluster information from options
	expectedClusterID := options.TerraformVars["cluster_id"].(string)
	expectedReservationID := options.TerraformVars["reservation_id"].(string)
	expectedMasterName := options.TerraformVars["cluster_prefix"].(string)

	JOB_COMMAND := `bsub -n 8 sleep 30`

	// Run the test consistency check
	output, err := options.RunTestConsistency()
	require.NoError(t, err, "Error running consistency test: %v", err)
	require.NotNil(t, output, "Expected non-nil output, but got nil")

	// Log successful cluster creation
	testLogger.Info(t, t.Name()+" Cluster created successfully")

	// Retrieve server IPs
	bastionIP, managementNodeIPList, _, ipRetrievalError := utils.GetServerIPs(t, options, testLogger)
	require.NoError(t, ipRetrievalError, "Error occurred while getting server IPs: %v", ipRetrievalError)

	bastion := fmt.Sprintf("%s@%s", LSF_PUBLIC_HOST_NAME, bastionIP)
	sshFilePath := os.Getenv("SSH_FILE_PATH")
	dest := "/home/lsfadmin"
	managementWithDest := fmt.Sprintf("%s@%s:%s", LSF_PRIVATE_HOST_NAME, managementNodeIPList[0], dest)

	// Modify Providers and HPC Config json content
	modifyErr := utils.ModifyConfigurationAsPerHPCConfigjsonHostProviders(bastion, sshFilePath, managementWithDest)
	if modifyErr != nil {
		fmt.Println(modifyErr)
	}

	// Log validation start
	testLogger.Info(t, t.Name()+" Validation started ......")

	// Connect to the master node via SSH and handle connection errors
	sshClient, connectionErr := utils.ConnectToHost(LSF_PUBLIC_HOST_NAME, bastionIP, LSF_PRIVATE_HOST_NAME, managementNodeIPList[0])
	require.NoError(t, connectionErr, "Failed to connect to the master via SSH: %v", connectionErr)
	defer sshClient.Close()

	testLogger.Info(t, "SSH connection to the master successful")
	t.Log("Validation in progress. Please wait...")

	// Verify management node configuration
	VerifyManagementNodeConfigCustomImageBuilder(t, sshClient, expectedClusterID, expectedMasterName, expectedReservationID, JOB_COMMAND, testLogger)

	// Wait for dynamic node disappearance and handle potential errors
	defer func() {
		if err := LSFWaitForDynamicNodeDisappearance(t, sshClient, testLogger); err != nil {
			t.Errorf("Error in LSFWaitForDynamicNodeDisappearance: %v", err)
		}
	}()

	// Get dynamic compute node IPs and handle errors
	computeNodeIPList, computeIPErr := LSFGETDynamicComputeNodeIPs(t, sshClient, testLogger)
	require.NoError(t, computeIPErr, "Error getting dynamic compute node IPs: %v", computeIPErr)

	// Verify compute node configuration
	VerifyComputeNodeConfigCustomImageBuilder(t, sshClient, computeNodeIPList, testLogger)

	// Log validation end
	testLogger.Info(t, t.Name()+" Validation ended")
}
