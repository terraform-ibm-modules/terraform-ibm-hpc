package tests

import (
	"log"
	"os"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/require"
	deploy "github.com/terraform-ibm-modules/terraform-ibm-hpc/deployment"
	lsf_tests "github.com/terraform-ibm-modules/terraform-ibm-hpc/lsf_tests"
	scale_tests "github.com/terraform-ibm-modules/terraform-ibm-hpc/scale_tests"
	utils "github.com/terraform-ibm-modules/terraform-ibm-hpc/utilities"
)

func TestRunLSFDefault(t *testing.T) {
	t.Parallel()

	require.NoError(t, os.Setenv("ZONES", "us-east-3"), "Failed to set ZONES env variable")
	require.NoError(t, os.Setenv("DEFAULT_EXISTING_RESOURCE_GROUP", "Default"), "Failed to set DEFAULT_EXISTING_RESOURCE_GROUP")

	t.Log("Running default LSF cluster test for region us-east-3")
	lsf_tests.DefaultTest(t)
}

func TestRunScaleDefault(t *testing.T) {
	t.Parallel()

	require.NoError(t, os.Setenv("ZONES", "us-east-3"), "Failed to set ZONES env variable")
	require.NoError(t, os.Setenv("DEFAULT_EXISTING_RESOURCE_GROUP", "Default"), "Failed to set DEFAULT_EXISTING_RESOURCE_GROUP")

	t.Log("Running default LSF cluster test for region us-east-3")
	scale_tests.DefaultTest(t)
}

// TestMain is the entry point for all tests
func TestMain(m *testing.M) {

	// Load LSF version configuration
	lsfProductFileName, err := lsf_tests.GetLSFVersionConfig()
	if err != nil {
		log.Fatalf("❌ Failed to get LSF version config: %v", err)
	}

	// Load and validate configuration
	lsfConfigFilePath, err := filepath.Abs("data/" + lsfProductFileName)
	if err != nil {
		log.Fatalf("❌ Failed to resolve config path: %v", err)
	}

	if _, err := os.Stat(lsfConfigFilePath); err != nil {
		log.Fatalf("❌ Config file not accessible: %v", err)
	}

	if _, err := deploy.GetLSFConfigFromYAML(lsfConfigFilePath); err != nil {
		log.Fatalf("❌ Config load failed: %v", err)
	}
	log.Printf("✅ lsf Configuration loaded successfully from %s", filepath.Base(lsfConfigFilePath))

	// Load Scale version configuration
	scaleProductFileName, err := scale_tests.GetScaleVersionConfig()
	if err != nil {
		log.Fatalf("❌ Failed to get LSF version config: %v", err)
	}

	// Load and validate configuration
	scaleConfigFilePath, err := filepath.Abs("data/" + scaleProductFileName)
	if err != nil {
		log.Fatalf("❌ Failed to resolve config path: %v", err)
	}

	if _, err := os.Stat(scaleConfigFilePath); err != nil {
		log.Fatalf("❌ Config file not accessible: %v", err)
	}

	if _, err := deploy.GetScaleConfigFromYAML(scaleConfigFilePath); err != nil {
		log.Fatalf("❌ Config load failed: %v", err)
	}
	log.Printf("✅ Scale Configuration loaded successfully from %s", filepath.Base(scaleConfigFilePath))

	// Execute tests
	exitCode := m.Run()

	// Generate HTML report if JSON log exists
	if jsonFileName, ok := os.LookupEnv("LOG_FILE_NAME"); ok {
		if _, err := os.Stat(jsonFileName); err == nil {
			results, err := utils.ParseJSONFile(jsonFileName)
			if err != nil {
				log.Printf("Failed to parse JSON results: %v", err)
			} else if err := utils.GenerateHTMLReport(results); err != nil {
				log.Printf("Failed to generate HTML report: %v", err)
			}
		}
	}

	os.Exit(exitCode)
}
