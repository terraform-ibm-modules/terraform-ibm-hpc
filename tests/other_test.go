package tests

import (
	"fmt"
	"testing"
)

func setup() {
	// Perform setup operations here.
	fmt.Println("Setting up before test method...")
}

func teardown() {
	// Perform teardown operations here.
	fmt.Println("Cleaning up after test method...")
}

func TestYourMethod1(t *testing.T) {
	setupSuite(t)
	setup()
	defer teardown()

	// Your test code here.
}

func TestYourMethod2(t *testing.T) {
	setupSuite(t)
	setup()
	defer teardown()

	// Your test code here.
}

// Add more test methods as needed.
