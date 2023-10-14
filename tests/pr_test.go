package tests

import (
	"testing"
	"os"
	"github.com/stretchr/testify/assert"
	"github.com/terraform-ibm-modules/ibmcloud-terratest-wrapper/testhelper"
)

const (
	exampleBasicTerraformDir = "examples/basic" // Path of the Terraform directory
	defaultResourceGroup     = "Default"        // Use existing resource group for tests
	prefix                   = "dv-hpc-cicd"      // HPC cluster ID
)


// TestRunHpcBasicExample
func TestRunHpcBasicExample(t *testing.T) {
	t.Parallel()

	// Create test options
	//options := setupOptions(t, hpcClusterPrefix, clusterID, exampleBasicTerraformDir, defaultResourceGroup, ignoreDestroysForBasicExample)
    options := &testhelper.TestOptions{
        Testing:        t,
        TerraformDir:   exampleBasicTerraformDir,
        //IgnoreDestroys: testhelper.Exemptions{List: ignoreDestroys},
        TerraformVars: map[string]interface{}{
            "ibmcloud_api_key":   os.Getenv("envIBMCloudAPIKey"),
            "login_ssh_keys":     os.Getenv("envLoginSSHKey"),
            "bastion_ssh_keys": os.Getenv("envBastionSSHKey"),
            "compute_ssh_keys": os.Getenv("envComputeSSHKey"),
            "storage_ssh_keys": os.Getenv("envStorageSSHKey"),
            "zones":              os.Getenv("envZones"),
            "allowed_cidr": os.Getenv("envAllowedCIDRs"),
            "prefix":     prefix,
            "resource_group":     defaultResourceGroup,
            "compute_gui_password":        os.Getenv("envCompGUIPass"),
            "storage_gui_password": os.Getenv("envStrgGUIPass"),
        },
    }
	// Run the test
	output, err := options.RunTestConsistency()

	// Check for errors
	assert.Nil(t, err, "Expected no errors, but got: %v", err)

	// Check the output for specific strings
	assert.NotNil(t, output, "Expected non-nil output, but got nil")
}