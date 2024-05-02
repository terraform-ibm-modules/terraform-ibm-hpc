package test

import (
	"os"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/terraform-ibm-modules/ibmcloud-terratest-wrapper/testhelper"
)

const (
	exampleBasicTerraformDir = "solutions/hpc" // Path of the Terraform directory
)

// TestRunHpcBasicExample
func TestRunHpcBasicExample(t *testing.T) {
	t.Parallel()

	options := &testhelper.TestOptions{
		Testing:      t,
		TerraformDir: exampleBasicTerraformDir,
		TerraformVars: map[string]interface{}{
			"ibmcloud_api_key": os.Getenv("TF_VAR_ibmcloud_api_key"),
		},
	}
	// Run the test
	output, err := options.RunTestConsistency()

	// Check for errors
	assert.Nil(t, err, "Expected no errors, but got: %v", err)

	// Check the output for specific strings
	assert.NotNil(t, output, "Expected non-nil output, but got nil")
}
