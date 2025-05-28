##############################################################################
# Account Variables
##############################################################################
variable "ibmcloud_api_key" {
  type        = string
  sensitive   = true
  default     = null
  description = "IBM Cloud API Key that will be used for authentication in scripts run in this module. Only required if certain options are required."
}

# Delete this variable before pushing to the public repository.
variable "github_token" {
  type        = string
  default     = null
  description = "Provide your GitHub token to download the HPCaaS code into the Deployer node"
}

##############################################################################
# Deployer Variables
##############################################################################
variable "enable_deployer" {
  type        = bool
  default     = false
  description = "Deployer should be only used for better deployment performance"
}

variable "deployer_ip" {
  type        = string
  default     = null
  description = "deployer node ip"
}

##############################################################################
# Offering Variations
##############################################################################
variable "scheduler" {
  type        = string
  default     = null
  description = "Select one of the scheduler (LSF/Symphony/Slurm/null)"
}

##############################################################################
# Bastion Variables
##############################################################################
variable "bastion_fip" {
  type        = string
  default     = null
  description = "bastion fip"
}

variable "bastion_private_key_content" {
  type        = string
  sensitive   = true
  default     = null
  description = "Bastion private key content."
}

##############################################################################
# Terraform generic Variables
#############################################################################
# tflint-ignore: all
variable "TF_PARALLELISM" {
  type        = string
  default     = "250"
  description = "Limit the number of concurrent operation."
}

# tflint-ignore: all
variable "TF_LOG" {
  type        = string
  default     = "ERROR"
  description = "The Terraform log level used for output in the Schematics workspace."
}
