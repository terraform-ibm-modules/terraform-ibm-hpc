##############################################################################
# Account Variables
##############################################################################

variable "ibmcloud_api_key" {
  description = "IBM Cloud API Key that will be used for authentication in scripts run in this module. Only required if certain options are required."
  type        = string
  sensitive   = true
  default     = null
}

variable "enable_landing_zone" {
  type        = bool
  default     = true
  description = "Run landing zone module."
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
# VPC Variables
##############################################################################

variable "vpc" {
  type        = string
  description = "Name of an existing VPC in which the cluster resources will be deployed. If no value is given, then a new VPC will be provisioned for the cluster. [Learn more](https://cloud.ibm.com/docs/vpc)"
  default     = null
}

variable "subnet_id" {
  type        = list(string)
  default     = null
  description = "List of existing subnet IDs under the VPC, where the cluster will be provisioned."
}

variable "network_cidr" {
  description = "Network CIDR for the VPC. This is used to manage network ACL rules for cluster provisioning."
  type        = string
  default     = "10.0.0.0/8"
}

# variable "placement_strategy" {
#   type        = string
#   default     = null
#   description = "VPC placement groups to create (null / host_spread / power_spread)"
# }

variable "ssh_keys" {
  type        = list(string)
  description = "The key pair to use to access the servers."
}

##############################################################################
# Access Variables
##############################################################################


variable "bastion_subnets_cidr" {
  type        = list(string)
  default     = ["10.0.0.0/24"]
  description = "Subnet CIDR block to launch the bastion host."
}

variable "enable_vpn" {
  type        = bool
  default     = false
  description = "The solution supports multiple ways to connect to your HPC cluster for example, using bastion node, via VPN or direct connection. If connecting to the HPC cluster via VPN, set this value to true."
}

variable "public_gateways" {
  type        = any
  description = "The solution supports multiple ways to connect to your HPC cluster for example, using bastion node, via VPN or direct connection. If connecting to the HPC cluster via VPN, set this value to true."
}

# variable "vpn_peer_cidr" {
#   type        = list(string)
#   default     = null
#   description = "The peer CIDRs (e.g., 192.168.0.0/24) to which the VPN will be connected."
# }

# variable "vpn_peer_address" {
#   type        = string
#   default     = null
#   description = "The peer public IP address to which the VPN will be connected."
# }

# variable "vpn_preshared_key" {
#   type        = string
#   default     = null
#   description = "The pre-shared key for the VPN."
# }

variable "allowed_cidr" {
  description = "Network CIDR to access the VPC. This is used to manage network ACL rules for accessing the cluster."
  type        = list(string)
  default     = ["10.0.0.0/8"]
}

##############################################################################
# Compute Variables
##############################################################################
# variable "login_subnets_cidr" {
#   type        = list(string)
#   default     = ["10.10.10.0/24", "10.20.10.0/24", "10.30.10.0/24"]
#   description = "Subnet CIDR block to launch the login host."
# }

# variable "login_instances" {
#   type = list(
#     object({
#       profile = string
#       count   = number
#     })
#   )
#   default = [{
#     profile = "cx2-2x4"
#     count   = 1
#   }]
#   description = "Number of instances to be launched for login."
# }

variable "compute_subnets_cidr" {
  type        = list(string)
  default     = ["10.10.20.0/24", "10.20.20.0/24", "10.30.20.0/24"]
  description = "Subnet CIDR block to launch the compute cluster host."
}

# variable "management_instances" {
#   type = list(
#     object({
#       profile = string
#       count   = number
#     })
#   )
#   default = [{
#     profile = "cx2-2x4"
#     count   = 3
#   }]
#   description = "Number of instances to be launched for management."
# }

# variable "compute_instances" {
#   type = list(
#     object({
#       profile = string
#       count   = number
#     })
#   )
#   default = [{
#     profile = "cx2-2x4"
#     count   = 0
#   }]
#   description = "Min Number of instances to be launched for compute cluster."
# }

##############################################################################
# Scale Storage Variables
##############################################################################

# variable "storage_subnets_cidr" {
#   type        = list(string)
#   default     = ["10.10.30.0/24", "10.20.30.0/24", "10.30.30.0/24"]
#   description = "Subnet CIDR block to launch the storage cluster host."
# }

# variable "storage_instances" {
#   type = list(
#     object({
#       profile = string
#       count   = number
#     })
#   )
#   default = [{
#     profile = "bx2-2x8"
#     count   = 3
#   }]
#   description = "Number of instances to be launched for storage cluster."
# }

# variable "protocol_subnets_cidr" {
#   type        = list(string)
#   default     = ["10.10.40.0/24", "10.20.40.0/24", "10.30.40.0/24"]
#   description = "Subnet CIDR block to launch the storage cluster host."
# }

# variable "protocol_instances" {
#   type = list(
#     object({
#       profile = string
#       count   = number
#     })
#   )
#   default = [{
#     profile = "bx2-2x8"
#     count   = 2
#   }]
#   description = "Number of instances to be launched for protocol hosts."
# }

##############################################################################
# Observability Variables
##############################################################################

variable "enable_cos_integration" {
  type        = bool
  default     = true
  description = "Integrate COS with HPC solution"
}

variable "cos_instance_name" {
  type        = string
  default     = null
  description = "Exiting COS instance name"
}

# variable "enable_atracker" {
#   type        = bool
#   default     = true
#   description = "Enable Activity tracker"
# }

variable "enable_vpc_flow_logs" {
  type        = bool
  default     = true
  description = "Enable Activity tracker"
}

##############################################################################
# Encryption Variables
##############################################################################

variable "key_management" {
  type        = string
  default     = null
  description = "null/key_protect"
}

variable "kms_instance_name" {
  type        = string
  default     = null
  description = "Name of the Key Protect instance associated with the Key Management Service. The ID can be found under the details of the KMS, see [View key-protect ID](https://cloud.ibm.com/docs/key-protect?topic=key-protect-retrieve-instance-ID&interface=ui)."
}

variable "kms_key_name" {
  type        = string
  default     = null
  description = "Provide the existing KMS encryption key name that you want to use for the IBM Cloud HPC cluster. (for example kms_key_name: my-encryption-key)."
}

# variable "hpcs_instance_name" {
#   type        = string
#   default     = null
#   description = "Hyper Protect Crypto Service instance"
# }

variable "management_node_count" {
  type        = number
  default     = 3
  description = "Number of management nodes. This is the total number of management nodes. Enter a value between 1 and 10."
  validation {
    condition     = 1 <= var.management_node_count && var.management_node_count <= 10
    error_message = "Input \"management_node_count\" must be must be greater than or equal to 1 and less than or equal to 10."
  }
}