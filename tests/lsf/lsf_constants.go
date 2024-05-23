package tests

const (
	IMAGE_NAME_PATH                         = "modules/landing_zone_vsi/image_map.tf"
	LSF_PUBLIC_HOST_NAME                    = "ubuntu"
	LSF_PRIVATE_HOST_NAME                   = "lsfadmin"
	LSF_LDAP_HOST_NAME                      = "ubuntu"
	HYPERTHREADTING_TRUE                    = true
	HYPERTHREADTING_FALSE                   = false
	LSF_DEFAULT_RESOURCE_GROUP              = "Default"
	LSF_CUSTOM_RESOURCE_GROUP_VALUE_AS_NULL = "null"
	EXPECTED_LSF_VERSION                    = "10.1.0.14"
	JOB_COMMAND_LOW_MEM                     = `bsub -J myjob[1-2] -R "select[family=mx2] rusage[mem=10G]" sleep 60`
	JOB_COMMAND_MED_MEM                     = `bsub -J myjob[1-2] -R "select[family=mx2] rusage[mem=30G]" sleep 60`
	JOB_COMMAND_HIGH_MEM                    = `bsub -J myjob[1-2] -R "select[family=mx2] rusage[mem=90G]" sleep 60`
	JOB_COMMAND_LOW_MEM_SOUTH               = `bsub -J myjob[1-2] -R "select[family=mx3d] rusage[mem=10G]" sleep 60`
	JOB_COMMAND_MED_MEM_SOUTH               = `bsub -J myjob[1-2] -R "select[family=mx3d] rusage[mem=30G]" sleep 60`
	JOB_COMMAND_HIGH_MEM_SOUTH              = `bsub -J myjob[1-2] -R "select[family=mx3d] rusage[mem=90G]" sleep 60`
	JOB_COMMAND_LOW_MEM_WITH_MORE_SLEEP     = `bsub -J myjob[1-2] -R "select[family=mx2] rusage[mem=30G]" sleep 60`
)

var (
	LSF_CUSTOM_RESOURCE_GROUP_OTHER_THAN_DEFAULT = "WES_TEST"
	LSF_US_EAST_ZONES                            = []string{"us-east-3"}
	LSF_EU_GB_ZONES                              = []string{"eu-de-2"}
	KMS_KEY_INSTANCE_NAME                        = "cicd-key-instance"
	KMS_KEY_NAME                                 = "cicd-key-name"
)
