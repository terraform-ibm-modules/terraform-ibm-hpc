##############################################################################
# Account Variables
##############################################################################

variable "ibmcloud_api_key" {
  description = "IBM Cloud API Key that will be used for authentication in scripts run in this module. Only required if certain options are required."
  type        = string
  sensitive   = true
  default     = null
}

##############################################################################
# Resource Groups Variables
##############################################################################

variable "resource_group" {
  description = "String describing resource groups to create or reference"
  type        = string
  default     = null
}

##############################################################################
# Module Level Variables
##############################################################################

variable "prefix" {
  description = "A unique identifier for resources. Must begin with a letter and end with a letter or number. This prefix will be prepended to any resources provisioned by this template. Prefixes must be 16 or fewer characters."
  type        = string

  validation {
    error_message = "Prefix must begin and end with a letter and contain only letters, numbers, and - characters."
    condition     = can(regex("^([A-z]|[a-z][-a-z0-9]*[a-z0-9])$", var.prefix))
  }
}

variable "zones" {
  description = "Region where VPC will be created. To find your VPC region, use `ibmcloud is regions` command to find available regions."
  type        = list(string)
}

##############################################################################
# Access Variables
##############################################################################
variable "bastion_ssh_keys" {
  type        = list(string)
  description = "The key pair to use to access the bastion host."
}

variable "allowed_cidr" {
  description = "Network CIDR to access the VPC. This is used to manage network ACL rules for accessing the cluster."
  type        = list(string)
  default     = ["10.0.0.0/8"]
}

##############################################################################
# Compute Variables
##############################################################################

variable "login_subnets_cidr" {
  type        = list(string)
  default     = ["10.10.10.0/24", "10.20.10.0/24", "10.30.10.0/24"]
  description = "Subnet CIDR block to launch the login host."
}

variable "login_ssh_keys" {
  type        = list(string)
  description = "The key pair to use to launch the login host."
}

variable "compute_ssh_keys" {
  type        = list(string)
  description = "The key pair to use to launch the compute host."
}


variable "compute_gui_password" {
  type        = string
  sensitive   = true
  description = "Password for compute cluster GUI"
}

##############################################################################
# Scale Storage Variables
##############################################################################

variable "storage_ssh_keys" {
  type        = list(string)
  description = "The key pair to use to launch the storage cluster host."
}

variable "storage_gui_password" {
  type        = string
  sensitive   = true
  description = "Password for storage cluster GUI"
}

##############################################################################
# DNS Template Variables
##############################################################################

##############################################################################
# Observability Variables
##############################################################################

##############################################################################
# Encryption Variables
##############################################################################

##############################################################################
# TODO: Auth Server (LDAP/AD) Variables
##############################################################################