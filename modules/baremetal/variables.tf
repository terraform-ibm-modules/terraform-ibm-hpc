##############################################################################
# Resource Groups Variables
##############################################################################

variable "existing_resource_group" {
  description = "String describing resource groups to create or reference"
  type        = string
  default     = null
}

variable "prefix" {
  description = "A unique identifier for resources. Must begin with a letter and end with a letter or number. This prefix will be prepended to any resources provisioned by this template. Prefixes must be 16 or fewer characters."
  type        = string

  validation {
    error_message = "Prefix must begin and end with a letter and contain only letters, numbers, and - characters."
    condition     = can(regex("^([A-z]|[a-z][-a-z0-9]*[a-z0-9])$", var.prefix))
  }
}

variable "image_id" {
  description = "This is the image id required for baremetal"
  type        = string
}
##############################################################################
# Scale Storage Variables
##############################################################################

/*variable "storage_subnets" {
  type = list(object({
    name = string
    id   = string
    zone = string
    cidr = string
  }))
  default     = []
  description = "Subnets to launch the storage host."
}*/

variable "storage_subnets" {
  type        = list(string)
  description = "Subnets to launch the storage host."
}

variable "storage_ssh_keys" {
  type        = list(string)
  description = "The key pair to use to launch the storage cluster host."
}

variable "storage_servers" {
  type = list(
    object({
      profile    = string
      count      = number
      image      = string
      filesystem = optional(string)
    })
  )
  default = [{
    profile    = "cx2d-metal-96x192"
    count      = 0
    image      = "ibm-redhat-8-10-minimal-amd64-4"
    filesystem = "/gpfs/fs1"
  }]
  description = "Number of BareMetal Servers to be launched for storage cluster."
}

variable "sapphire_rapids_profile_check" {
  type        = bool
  default     = false
  description = "Check whether the profile uses Cascade Lake processors (x2) or Intel Sapphire Rapids processors (x3)."
}

variable "allowed_vlan_ids" {
  description = "A list of VLAN IDs that are permitted for the bare metal server, ensuring network isolation and control. Example: [100, 102]"
  type        = list(number)
  default     = ["100", "102"]
}

variable "security_group_ids" {
  description = "A list of security group ID's"
  type        = list(string)
  default     = []
}

variable "secondary_security_group_ids" {
  description = "A list of secondary security group ID's"
  type        = list(string)
  default     = []
}

variable "secondary_vni_enabled" {
  description = "Whether to enable a secondary virtual network interface"
  type        = bool
  default     = false
}

variable "user_data" {
  description = "User Data script path"
  type        = string
  default     = null
}

variable "protocol_subnets" {
  type = list(object({
    name = string
    id   = string
    zone = string
    cidr = string
  }))
  default     = []
  description = "Subnets to launch the bastion host."
}
