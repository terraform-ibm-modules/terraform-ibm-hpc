package tests

import (
	"log"
	"os"
	"path/filepath"
	"testing"

	deploy "github.com/terraform-ibm-modules/terraform-ibm-hpc/deployment"
	utils "github.com/terraform-ibm-modules/terraform-ibm-hpc/utilities"
)

func TestRunDefault(t *testing.T) {
	t.Parallel()
	DefaultTest(t)
}

// TestMain is the entry point for all tests
func TestMain(m *testing.M) {

	productFileName, err := GetLSFVersionConfig()

	if err != nil {
		log.Fatalf("Unsupported solution specified: %s", solution)
	}

	// Load configuration from YAML
	configFilePath, err := filepath.Abs("data/" + productFileName)
	if err != nil {
		log.Fatalf("❌ Failed to get absolute path for config file: %v", err)
	}

	// Check if the file exists
	if _, err := os.Stat(configFilePath); os.IsNotExist(err) {
		log.Fatalf("❌ Configuration file not found: %s", configFilePath)
	}

	// Load the config
	_, err = deploy.GetConfigFromYAML(configFilePath)
	if err != nil {
		log.Fatalf("❌ Failed to load configuration: %v", err)
	}

	log.Printf("✅ Successfully loaded configuration")

	// Run tests
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
