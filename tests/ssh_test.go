package tests

import (
	"fmt"
	"testing"

	"github.com/stretchr/testify/assert"
	lsf_util "github.com/terraform-ibm-modules/terraform-ibm-hpc/lsf"
	utils "github.com/terraform-ibm-modules/terraform-ibm-hpc/utils"
)

var CLogger *utils.AggregatedLogger
var CLoggerErr error
var suiteInitialized bool

func setupSuite(t *testing.T) {
	if !suiteInitialized {
		// Run your setup code here.
		fmt.Println("Setting up the test suite...")
		CLogger, CLoggerErr = utils.NewAggregatedLogger("Dec04.Log")
		assert.Nil(t, CLoggerErr, "Expected no errors, but got: %v", CLoggerErr)
		suiteInitialized = true
	}
}

func TestSSHAgentToPrivateHostUsingJumpHost(t *testing.T) {

	// Run `terraform output` to get the value of an output variable
	publicInstanceIP := "158.176.4.10"
	privateInstanceIP := "10.241.0.8"
	expectedClusterID := "HPC-LSF-1"
	expectedMasterName := "anbu-hpc-tc-dec-07-mgmt-1"

	_, err := utils.ConnectionE(t, publicInstanceIP, "vpcuser", privateInstanceIP, "lsfadmin", "lsid")
	if err != nil {
		CLogger.Error(t, err.Error())
	}

	lsidOutput, err := utils.ConnectionE(t, publicInstanceIP, "vpcuser", privateInstanceIP, "lsfadmin", "lsid")
	if err != nil {
		CLogger.Error(t, err.Error())
	}
	clusterIDstatus := utils.VerifyDataContains(t, lsidOutput, "My cluster name is "+expectedClusterID, CLogger)
	assert.True(t, clusterIDstatus)
	masterNameStatus := utils.VerifyDataContains(t, lsidOutput, "My master name is "+expectedMasterName, CLogger)
	assert.True(t, masterNameStatus)

}

func TestSSHAgentToPrivateHost(t *testing.T) {

	publicInstanceIP := "158.176.4.10"
	_, err := utils.ConnectionE(t, "", "", publicInstanceIP, "vpcuser", "cat /etc/os-release")
	if err != nil {
		CLogger.Error(t, err.Error())
	}

	status := utils.VerifyDataContains(t, "Welcome", "Welcome", CLogger)
	fmt.Println(status)
}

func TestAnbu(t *testing.T) {
	//161.156.160.128
	//149.81.219.17

	setupSuite(t)

	CLogger.Info(t, "TestSampleMain validation get Starts ...")
	sClient, connectionErr := utils.ConnectToHost("158.176.4.10", "vpcuser", "10.241.0.8", "lsfadmin")
	assert.Nil(t, connectionErr, "Expected no errors, but got: %v", connectionErr)
	if connectionErr != nil {
		CLogger.Error(t, "Failed to ssh :"+connectionErr.Error())
	} else {
		CLogger.Info(t, "Successfully ssh into cluster")
	}

	err := lsf_util.HPCCheckContractID(t, sClient, "Contract-IBM-F", CLogger)
	if err != nil {
		CLogger.Error(t, err.Error())
	}
	errM := lsf_util.LSFCheckSshKeyForManagement(t, sClient, CLogger)
	if errM != nil {
		CLogger.Error(t, errM.Error())
	}
	errC := lsf_util.LSFCheckSshKeyForCompute(t, sClient, CLogger)
	if errC != nil {
		CLogger.Error(t, errC.Error())
	}
}
