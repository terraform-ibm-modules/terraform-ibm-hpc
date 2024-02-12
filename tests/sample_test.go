package tests

import (
	"fmt"
	"testing"

	"github.com/stretchr/testify/assert"
	lsf_util "github.com/terraform-ibm-modules/terraform-ibm-hpc/lsf"
	util "github.com/terraform-ibm-modules/terraform-ibm-hpc/utils"
)

func TestIntelOneMPI(t *testing.T) {

	sClient, connectionErr := util.ConnectToHost("161.156.82.46", "vpcuser", "10.241.0.8", "lsfadmin")
	assert.Nil(t, connectionErr, "Expected no errors, but got: %v", connectionErr)
	if connectionErr != nil {
		CLogger.Error(t, "Failed to ssh :"+connectionErr.Error())
	} else {
		CLogger.Info(t, "Successfully ssh into cluster")
	}

	ips := []string{"10.241.0.8"}

	err := lsf_util.LSFCheckIntelOneMpiOnComputeNodes(t, sClient, ips, CLogger)
	if assert.NotNil(t, err) {
		CLogger.Error(t, "Failed to ssh :"+err.Error())
	} else {
		CLogger.Info(t, "Successfully validated Intel One MPI.")
	}

	checkClusterIDErr := lsf_util.LSFCheckClusterID(t, sClient, "HPC-LSF-1", CLogger)
	if checkClusterIDErr != nil {
		CLogger.Error(t, checkClusterIDErr.Error())
		assert.Nil(t, checkClusterIDErr, "Expected no errors, but got: %v", connectionErr)
	} else {
		CLogger.Info(t, "Cluster ID check successful.")
	}

	checkMasterNameErr := lsf_util.LSFCheckMasterName(t, sClient, "anbu-new-tc-one", CLogger)
	if checkMasterNameErr != nil {
		CLogger.Error(t, checkMasterNameErr.Error())
		assert.Nil(t, checkClusterIDErr, "Expected no errors, but got: %v", checkMasterNameErr)
	} else {
		CLogger.Info(t, "Master name check successful.")
	}

	mtuCheckErr := lsf_util.LSFMTUCheck(t, sClient, ips, CLogger)
	if mtuCheckErr != nil {
		CLogger.Error(t, mtuCheckErr.Error())
	} else {
		CLogger.Info(t, "MTU check successful.")
	}

	jobErr := lsf_util.LSFRunJobs(t, sClient, "bsub -J myjob[1-1] -R \"rusage[mem=8G]\" sleep 10", CLogger)
	if jobErr != nil {
		CLogger.Error(t, jobErr.Error())
	} else {
		CLogger.Info(t, "Job submitted and executed successfully.")
	}

	bctrldStopErr := lsf_util.LSFControlBctrld(t, sClient, "stop", CLogger)
	if bctrldStopErr != nil {
		CLogger.Error(t, bctrldStopErr.Error())
	} else {
		CLogger.Info(t, "LSF daemon stopped successfully.")
	}
	bctrldStartErr := lsf_util.LSFControlBctrld(t, sClient, "start", CLogger)
	if bctrldStartErr != nil {
		CLogger.Error(t, bctrldStartErr.Error())
	} else {
		CLogger.Info(t, "LSF daemon started successfully.")
	}

	ip, errorV := lsf_util.LSFGETDynamicComputeNodeIPs(t, sClient, CLogger)
	if errorV != nil {
		CLogger.Error(t, errorV.Error())
	}
	fmt.Println(ip)

	dynamicNodeErr := lsf_util.LSFWaitForDynamicNodeDisappear(t, sClient, CLogger)
	if dynamicNodeErr != nil {
		CLogger.Error(t, dynamicNodeErr.Error())
	} else {
		CLogger.Info(t, "Dynamic node disappeared successfully.")
	}

	appCenterErr := lsf_util.LSFAPPCenter(t, sClient, CLogger)
	if appCenterErr != nil {
		CLogger.Error(t, appCenterErr.Error())
	} else {
		CLogger.Info(t, "LSF Application Center configured successfully.")
	}

	mountErr := lsf_util.HPCCheckFileMount(t, sClient, ips, CLogger)
	if mountErr != nil {
		CLogger.Error(t, mountErr.Error())
	} else {
		CLogger.Info(t, "LSF file mount as expected.")
	}

	daemonErr := lsf_util.LSFDaemonsStatus(t, sClient, CLogger)
	if daemonErr != nil {
		CLogger.Error(t, daemonErr.Error())
	} else {
		CLogger.Info(t, "LSF Daemon status is running.")
	}

	CLogger.Info(t, "TestIntelOneMPI validation ends.")
}

func TestFile(t *testing.T) {

	CLogger.Info(t, "Test File validation get Starts ...")

	sClient, connectionErr := util.ConnectToHost("161.156.82.46", "vpcuser", "10.241.0.8", "lsfadmin")
	assert.Nil(t, connectionErr, "Expected no errors, but got: %v", connectionErr)
	if connectionErr != nil {
		CLogger.Error(t, "Failed to ssh :"+connectionErr.Error())
	} else {
		CLogger.Info(t, "Successfully ssh into cluster")
	}

	_, createErr := util.ToCreateFile(t, sClient, ".", "sample.txt", CLogger)
	if createErr != nil {
		CLogger.Error(t, "Failed to ssh :"+createErr.Error())
	}

	delStatus, delErr := util.ToDeleteFile(t, sClient, ".", "sample.txt", CLogger)
	if delErr != nil {
		CLogger.Error(t, "Failed to ssh :"+delErr.Error())
	}
	fmt.Println(delStatus)

	dirStr, dirErr := util.GetDirList(t, sClient, "/mnt", CLogger)
	if dirErr != nil {
		CLogger.Error(t, "Failed to ssh :"+dirErr.Error())
	}
	fmt.Println(dirStr)

	pathStatus, pathErr := util.IsPathExist(t, sClient, "/mnt", CLogger)
	if pathErr != nil {
		CLogger.Error(t, "Failed to ssh :"+pathErr.Error())
	}
	fmt.Println(pathStatus)

	hyperthreadingEnabled, err := lsf_util.LSFCheckHyperthreadingIsEnabled(t, sClient, CLogger)
	if err != nil {
		CLogger.Error(t, err.Error())
	}
	fmt.Println(hyperthreadingEnabled)
}

func TestSampleMain(t *testing.T) {
	//161.156.160.128
	//149.81.219.17

	CLogger.Info(t, "TestSampleMain validation get Starts ...")
	sClient, connectionErr := util.ConnectToHost("161.156.82.46", "vpcuser", "10.241.0.8", "lsfadmin")
	assert.Nil(t, connectionErr, "Expected no errors, but got: %v", connectionErr)
	if connectionErr != nil {
		CLogger.Error(t, "Failed to ssh :"+connectionErr.Error())
	} else {
		CLogger.Info(t, "Successfully ssh into cluster")
	}

	hyperthreadingEnabled, err := lsf_util.LSFCheckHyperthreadingIsEnabled(t, sClient, CLogger)
	if err != nil {
		fmt.Println("Error:", err.Error())
	}
	fmt.Println(hyperthreadingEnabled)

	isCreated, err := util.ToCreateFileWithContent(t, sClient, ".", "sample.txt", "Welcome to india3", CLogger)
	if err != nil {
		fmt.Println("Error:", err.Error())
	}
	fmt.Println(isCreated)

	text, err := util.ReadRemoteFileContents(t, sClient, ".", "sample.txt", CLogger)
	if err != nil {
		fmt.Println("Error:", err.Error())
	}
	fmt.Println(text)
}
