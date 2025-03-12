##############################################################################
# Account Variables
##############################################################################
variable "ibmcloud_api_key" {
  type        = string
  sensitive   = true
  default     = null
  description = "IBM Cloud API Key that will be used for authentication in scripts run in this module. Only required if certain options are required."
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
# Bastion Variables
##############################################################################
variable "bastion_fip" {
  type        = string
  default     = null
  description = "bastion fip"
}

# variable "bastion_public_key_content" {
#   type        = string
#   sensitive   = true
#   default     = null
#   description = "Bastion public key content."
# }

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
# variable "TF_VERSION" {
#   type        = string
#   default     = "1.9"
#   description = "The version of the Terraform engine that's used in the Schematics workspace."
# }

# tflint-ignore: all
variable "TF_LOG" {
  type        = string
  default     = "ERROR"
  description = "The Terraform log level used for output in the Schematics workspace."
}
