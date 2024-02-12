##############################################################################
# Account Variables
##############################################################################

variable "ibmcloud_api_key" {
  description = "IBM Cloud API Key that will be used for authentication in scripts run in this module. Only required if certain options are required."
  type        = string
  sensitive   = true
}

##############################################################################
# Resource Groups Variables
##############################################################################

variable "resource_group" {
  description = "String describing resource groups to create or reference"
  type        = string
  # TODO: Temp fix
  default = "Default"
}

##############################################################################
# Module Level Variables
##############################################################################

variable "prefix" {
  description = "A unique identifier for resources. Must begin with a letter and end with a letter or number. This prefix will be prepended to any resources provisioned by this template. Prefixes must be 16 or fewer characters."
  type        = string
  default     = "tim-hpc"
  validation {
    error_message = "Prefix must begin and end with a letter and contain only letters, numbers, and - characters."
    condition     = can(regex("^([A-z]|[a-z][-a-z0-9]*[a-z0-9])$", var.prefix))
  }
}

variable "zones" {
  description = "Region where VPC will be created. To find your VPC region, use `ibmcloud is regions` command to find available regions."
  type        = list(string)
  # TODO: Temp fix
  default = "[\"eu-de-2\",\"eu-de-3\"]"
}

##############################################################################
# Access Variables
##############################################################################
variable "ssh_keys" {
  type        = list(string)
  description = "The key pair to use to access the bastion host."
  # TODO: Temp fix
  default = ["anbu-key"]
}
