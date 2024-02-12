package tests

import (
	"testing"

	"github.com/stretchr/testify/assert"
	util "github.com/terraform-ibm-modules/terraform-ibm-hpc/utils"
)

func TestSampleMTUCheck(t *testing.T) {

	log, err := util.NewAggregatedLogger("Welcome.log")
	assert.Nil(t, err, "Expected no errors, but got: %v", err)
	log.Info(t, "Welcome")
	log.Warn(t, "Welcome")

}
