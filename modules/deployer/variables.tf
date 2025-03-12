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

# variable "zones" {
#   description = "Region where VPC will be created. To find your VPC region, use `ibmcloud is regions` command to find available regions."
#   type        = list(string)
# }

##############################################################################
# VPC Variables
##############################################################################

variable "vpc_id" {
  type        = string
  description = "ID of an existing VPC in which the cluster resources will be deployed."
}

variable "network_cidr" {
  description = "Network CIDR for the VPC. This is used to manage network ACL rules for cluster provisioning."
  type        = string
  default     = "10.0.0.0/8"
}

##############################################################################
# Access Variables
##############################################################################
variable "enable_bastion" {
  type        = bool
  default     = true
  description = "The solution supports multiple ways to connect to your HPC cluster for example, using bastion node, via VPN or direct connection. If connecting to the HPC cluster via VPN or direct connection, set this value to false."
}

variable "bastion_image" {
  type        = string
  default     = "ibm-ubuntu-22-04-3-minimal-amd64-1"
  description = "The image to use to deploy the bastion host."
}

variable "bastion_instance_profile" {
  type        = string
  default     = "cx2-4x8"
  description = "Deployer should be only used for better deployment performance"
}

variable "bastion_subnets" {
  type = list(object({
    name = string
    id   = string
    zone = string
    cidr = string
  }))
  default     = []
  description = "Subnets to launch the bastion host."
}

##############################################################################
# Deployer Variables
##############################################################################
variable "enable_deployer" {
  type        = bool
  default     = false
  description = "deployer should be only used for better deployment performance"
}

variable "deployer_image" {
  type        = string
  default     = "ibm-redhat-8-10-minimal-amd64-2"
  description = "The image to use to deploy the deployer host."
}

variable "deployer_instance_profile" {
  type        = string
  default     = "mx2-4x32"
  description = "deployer should be only used for better deployment performance"
}

variable "ssh_keys" {
  type        = list(string)
  description = "The key pair to use to access the host."
}

variable "allowed_cidr" {
  description = "Network CIDR to access the VPC. This is used to manage network ACL rules for accessing the cluster."
  type        = list(string)
  default     = ["10.0.0.0/8"]
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

variable "skip_iam_authorization_policy" {
  type        = bool
  default     = false
  description = "Set to false if authorization policy is required for VPC block storage volumes to access kms. This can be set to true if authorization policy already exists. For more information on how to create authorization policy manually, see [creating authorization policies for block storage volume](https://cloud.ibm.com/docs/vpc?topic=vpc-block-s2s-auth&interface=ui)."
}

# variable "management_instances" {
#   type = list(
#     object({
#       profile = string
#       count   = number
#       image   = string
#     })
#   )
#   description = "Number of instances to be launched for management."
# }

# variable "static_compute_instances" {
#   type = list(
#     object({
#       profile = string
#       count   = number
#       image   = string
#     })
#   )
#   description = "Total Number of instances to be launched for compute cluster."
# }

variable "dns_domain_names" {
  type = object({
    compute  = string
    storage  = string
    protocol = string
  })
  description = "IBM Cloud HPC DNS domain names."
}
