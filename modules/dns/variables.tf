##############################################################################
# Resource Groups Variables
##############################################################################

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

##############################################################################
# VPC Variables
##############################################################################

variable "vpc_crn" {
  type        = string
  description = "VPC CRN"
}

variable "subnets_crn" {
  type        = list(string)
  description = "Subnet CRN"
}

##############################################################################
# DNS Template Variables
##############################################################################

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

variable "dns_domain_names" {
  type        = list(string)
  default     = null
  description = "IBM Cloud HPC DNS domain names."
}
