##############################################################################
# Account Variables
##############################################################################
variable "ibmcloud_api_key" {
  type        = string
  sensitive   = true
  default     = null
  description = "IBM Cloud API Key that will be used for authentication in scripts run in this module. Only required if certain options are required."
}

## Delete this variable before pushing to the public repository.
#variable "github_token" {
#  type        = string
#  default     = null
#  description = "Provide your GitHub token to download the HPCaaS code into the Deployer node"
#}

##############################################################################
# Cluster Level Variables
##############################################################################
variable "cluster_prefix" {
  type        = string
  default     = "hpc"
  description = "A unique identifier for resources. Must begin with a letter and end with a letter or number. This cluster_prefix will be prepended to any resources provisioned by this template. Prefixes must be 16 or fewer characters."
  validation {
    error_message = "Prefix must begin and end with a letter and contain only letters, numbers, and - characters."
    condition     = can(regex("^([A-z]|[a-z][-a-z0-9]*[a-z0-9])$", var.cluster_prefix))
  }
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

variable "existing_bastion_instance_name" {
  type        = string
  default     = null
  description = "Provide the name of the bastion instance. If none given then new bastion will be created."
}

variable "bastion_public_key_content" {
  type        = string
  sensitive   = true
  default     = null
  description = "Bastion security group id."
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
