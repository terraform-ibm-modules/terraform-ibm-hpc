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
	LOGIN_NODE_EXECUTION_PATH               = "source /opt/ibm/lsf/conf/profile.lsf;"
	COMPUTE_NODE_EXECUTION_PATH             = "source /opt/ibm/lsf_worker/conf/profile.lsf;"
	HPC_JOB_COMMAND_LOW_MEM                 = `bsub -J myjob[1-1] -R "select[family=mx2] rusage[mem=10G]" sleep 90`
	HPC_JOB_COMMAND_MED_MEM                 = `bsub -J myjob[1-1] -R "select[family=mx2] rusage[mem=30G]" sleep 90`
	HPC_JOB_COMMAND_HIGH_MEM                = `bsub -J myjob[1-1] -R "select[family=mx2] rusage[mem=90G]" sleep 90`
	HPC_JOB_COMMAND_LOW_MEM_SOUTH           = `bsub -J myjob[1-1] -R "select[family=mx3d] rusage[mem=10G]" sleep 90`
	HPC_JOB_COMMAND_MED_MEM_SOUTH           = `bsub -J myjob[1-1] -R "select[family=mx3d] rusage[mem=30G]" sleep 90`
	HPC_JOB_COMMAND_HIGH_MEM_SOUTH          = `bsub -J myjob[1-1] -R "select[family=mx3d] rusage[mem=90G]" sleep 90`
	HPC_JOB_COMMAND_LOW_MEM_WITH_MORE_SLEEP = `bsub -J myjob[1-1] -R "select[family=mx2] rusage[mem=30G]" sleep 90`
	LSF_JOB_COMMAND_LOW_MEM                 = `bsub -n 4 sleep 60`
	LSF_JOB_COMMAND_MED_MEM                 = `bsub -n 6 sleep 90`
	LSF_JOB_COMMAND_HIGH_MEM                = `bsub -n 10 sleep 120`
)

var (
	LSF_CUSTOM_RESOURCE_GROUP_OTHER_THAN_DEFAULT = "WES_TEST"
	KMS_KEY_INSTANCE_NAME                        = "cicd-key-instance"
	KMS_KEY_NAME                                 = "cicd-key-name"
	EXPECTED_LSF_VERSION                         = "10.1.0.14"
	SCC_INSTANCE_REGION                          = "us-south"
)
