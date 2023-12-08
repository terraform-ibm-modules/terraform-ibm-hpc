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

variable "resource_group_id" {
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
# VPC Variables
##############################################################################

variable "vpc" {
  type        = string
  description = "Name of an existing VPC in which the cluster resources will be deployed."
}

variable "vpc_id" {
  type        = string
  description = "ID of an existing VPC in which the cluster resources will be deployed."
}

##############################################################################
# Access Variables
##############################################################################
variable "enable_bastion" {
  type        = bool
  default     = true
  description = "The solution supports multiple ways to connect to your HPC cluster for example, using bastion node, via VPN or direct connection. If connecting to the HPC cluster via VPN or direct connection, set this value to false."
}

variable "bastion_subnets" {
  type = list(object({
    name = string
    id   = string
    zone = string
    cidr = string
  }))
  default     = null
  description = "Subnets to launch the bastion host."
}

variable "enable_bootstrap" {
  type        = bool
  default     = false
  description = "Bootstrap should be only used for better deployment performance"
}

variable "bootstrap_instance_profile" {
  type        = string
  default     = "mx2-4x32"
  description = "Bootstrap should be only used for better deployment performance"
}

variable "ssh_keys" {
  type        = list(string)
  description = "The key pair to use to access the host."
}

variable "security_group_ids" {
  type        = list(string)
  description = "Security group IDs for bootstrap server."
}

variable "bastion_public_key_content" {
  type        = string
  sensitive   = true
  default     = null
  description = "Bastion public key content."
}

# TODO: landing-zone-vsi limitation to opt out encryption
variable "kms_encryption_enabled" {
  description = "Enable Key management"
  type        = bool
  default     = true
}

variable "boot_volume_encryption_key" {
  type        = string
  default     = null
  description = "CRN of boot volume encryption key"
}

variable "existing_kms_instance_guid" {
  type        = string
  default     = null
  description = "GUID of boot volume encryption key"
}


variable "compute_ssh_keys" {
  type        = list(string)
  description = "The key pair to use to launch the compute host."
}

variable "login_ssh_keys" {
  type        = list(string)
  description = "The key pair to use to launch the login host."
}

variable "storage_ssh_keys" {
  type        = list(string)
  description = "The key pair to use to launch the storage cluster host."
}

variable "login_subnets" {
  type = list(object({
    name = string
    id   = string
    zone = string
    cidr = string
  }))
  default     = null
  description = "Subnets to launch the login hosts."
}

variable "compute_subnets" {
  type = list(object({
    name = string
    id   = string
    zone = string
    cidr = string
  }))
  default     = null
  description = "Subnets to launch the compute host."
}

variable "storage_subnets" {
  type = list(object({
    name = string
    id   = string
    zone = string
    cidr = string
  }))
  default     = null
  description = "Subnets to launch the storage host."
}

variable "protocol_subnets" {
  type = list(object({
    name = string
    id   = string
    zone = string
    cidr = string
  }))
  default     = null
  description = "Subnets to launch the bastion host."
}

variable "dns_instance_id" {
  type        = string
  default     = null
  description = "IBM Cloud HPC DNS service resource id."
}

variable "dns_custom_resolver_id" {
  type        = string
  default     = null
  description = "IBM Cloud DNS custom resolver id."
}
