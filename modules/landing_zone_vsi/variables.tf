##############################################################################
# Offering Variations
##############################################################################
variable "storage_type" {
  type        = string
  default     = "scratch"
  description = "Select the required storage type(scratch/persistent/eval)."
}

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
# VPC Variables
##############################################################################

variable "vpc_id" {
  type        = string
  description = "ID of an existing VPC in which the cluster resources will be deployed."
}

# variable "placement_group_ids" {
#   type        = string
#   default     = null
#   description = "VPC placement group ids"
# }

##############################################################################
# Access Variables
##############################################################################

variable "bastion_security_group_id" {
  type        = string
  description = "Bastion security group id."
}

variable "bastion_public_key_content" {
  type        = string
  sensitive   = true
  default     = null
  description = "Bastion security group id."
}

##############################################################################
# Compute Variables
##############################################################################

# variable "login_subnets" {
#   type = list(object({
#     name = string
#     id   = string
#     zone = string
#     cidr = string
#   }))
#   default     = []
#   description = "Subnets to launch the login hosts."
# }

# variable "login_ssh_keys" {
#   type        = list(string)
#   description = "The key pair to use to launch the login host."
# }

# variable "login_image_name" {
#   type        = string
#   default     = "ibm-redhat-8-6-minimal-amd64-5"
#   description = "Image name to use for provisioning the login instances."
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

variable "compute_subnets" {
  type = list(object({
    name = string
    id   = string
    zone = string
    cidr = string
    crn  = string
  }))
  default     = []
  description = "Subnets to launch the compute host."
}

variable "compute_ssh_keys" {
  type        = list(string)
  description = "The key pair to use to launch the compute host."
}

variable "management_image_name" {
  type        = string
  default     = "hpcaas-lsf10-rhel88-v3"
  description = "Image name to use for provisioning the management cluster instances."
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

# variable "static_compute_instances" {
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

# variable "dynamic_compute_instances" {
#   type = list(
#     object({
#       profile = string
#       count   = number
#     })
#   )
#   default = [{
#     profile = "cx2-2x4"
#     count   = 250
#   }]
#   description = "MaxNumber of instances to be launched for compute cluster."
# }

variable "compute_image_name" {
  type        = string
  default     = "hpcaas-lsf10-rhel88-compute-v2"
  description = "Image name to use for provisioning the compute cluster instances."
}

##############################################################################
# Scale Storage Variables
##############################################################################

# variable "storage_subnets" {
#   type = list(object({
#     name = string
#     id   = string
#     zone = string
#     cidr = string
#   }))
#   default     = []
#   description = "Subnets to launch the storage host."
# }

# variable "storage_ssh_keys" {
#   type        = list(string)
#   description = "The key pair to use to launch the storage cluster host."
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

# variable "storage_image_name" {
#   type        = string
#   default     = "ibm-redhat-8-6-minimal-amd64-5"
#   description = "Image name to use for provisioning the storage cluster instances."
# }

# variable "protocol_subnets" {
#   type = list(object({
#     name = string
#     id   = string
#     zone = string
#     cidr = string
#   }))
#   default     = []
#   description = "Subnets to launch the bastion host."
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

# variable "nsd_details" {
#   type = list(
#     object({
#       profile  = string
#       capacity = optional(number)
#       iops     = optional(number)
#     })
#   )
#   default = [{
#     profile = "custom"
#     size    = 100
#     iops    = 100
#   }]
#   description = "NSD details"
# }

##############################################################################
# DNS Template Variables
##############################################################################

variable "dns_domain_names" {
  type = object({
    compute  = string
    #storage  = string
    #protocol = string
  })
  default = {
    compute  = "comp.com"
    storage  = "strg.com"
    protocol = "ces.com"
  }
  description = "IBM Cloud HPC DNS domain names."
}

##############################################################################
# Encryption Variables
##############################################################################

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

##############################################################################
# TODO: Sagar variables
##############################################################################
variable "cluster_id" {
  type        = string
  description = "Ensure that you have received the cluster ID from IBM technical sales. A unique identifer for HPC cluster used by IBM Cloud HPC to differentiate different HPC clusters within the same contract. This can be up to 39 alphanumeric characters including the underscore (_), the hyphen (-), and the period (.) characters. You cannot change the cluster ID after deployment."
}

variable "contract_id" {
  type        = string
  sensitive   = true
  description = "Ensure that you have received the contract ID from IBM technical sales. Contract ID is a unique identifier to distinguish different IBM Cloud HPC service agreements. It must start with a letter and can only contain letters, numbers, hyphens (-), or underscores (_)."
}

variable "hyperthreading_enabled" {
  type        = bool
  default     = true
  description = "Setting this to true will enable hyper-threading in the compute nodes of the cluster (default). Otherwise, hyper-threading will be disabled."
}

variable "enable_app_center" {
  type        = bool
  default     = false
  description = "Set to true to enable the IBM Spectrum LSF Application Center GUI (default: false). [System requirements](https://www.ibm.com/docs/en/slac/10.2.0?topic=requirements-system-102-fix-pack-14) for IBM Spectrum LSF Application Center Version 10.2 Fix Pack 14."
}

variable "app_center_gui_pwd" {
  type        = string
  sensitive   = true
  default     = ""
  description = "Password for IBM Spectrum LSF Application Center GUI. Note: Password should be at least 8 characters, must have one number, one lowercase letter, one uppercase letter, and at least one special character."
}

variable "management_node_count" {
  type        = number
  default     = 3
  description = "Number of management nodes. This is the total number of management nodes. Enter a value between 1 and 10."
  validation {
    condition     = 1 <= var.management_node_count && var.management_node_count <= 10
    error_message = "Input \"management_node_count\" must be must be greater than or equal to 1 and less than or equal to 10."
  }
}

variable "management_node_instance_type" {
  type        = string
  default     = "bx2-16x64"
  description = "Specify the virtual server instance profile type to be used to create the management nodes for the IBM Cloud HPC cluster. For choices on profile types, see [Instance profiles](https://cloud.ibm.com/docs/vpc?topic=vpc-profiles)."
  validation {
    condition     = can(regex("^[^\\s]+-[0-9]+x[0-9]+", var.management_node_instance_type))
    error_message = "The profile must be a valid profile name."
  }
}

variable "share_path" {}
variable "mount_path" {}
variable "file_share" {}
variable "login_private_ips" {}

variable "login_node_instance_type" {
  type        = string
  default     = "bx2-2x8"
  description = "Specify the virtual server instance profile type to be used to create the login node for the IBM Cloud HPC cluster. For choices on profile types, see [Instance profiles](https://cloud.ibm.com/docs/vpc?topic=vpc-profiles)."
  validation {
    condition     = can(regex("^[^\\s]+-[0-9]+x[0-9]+", var.login_node_instance_type))
    error_message = "The profile must be a valid profile name."
  }
}

variable "existing_kms_instance_guid" {
  type        = string
  default     = null
  description = "GUID of boot volume encryption key"
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

variable "ssh_keys" {
  type        = list(string)
  description = "The key pair to use to access the host."
}

variable "enable_ldap" {}
variable "ldap_basedns" {}
variable "ldap_server" {}
variable "ldap_user_name" {}
variable "ldap_admin_password" {}
variable "ldap_user_password" {}
variable "ldap_vsi_profile" {}
variable "ldap_vsi_osimage_name" {}
variable "ldap_primary_ip" {}
variable "subnet_id" {
  type        = list(string)
  default     = []
  description = "List of existing subnet IDs under the VPC, where the cluster will be provisioned."
  validation {
    condition     = contains([0, 2], length(var.subnet_id))
    error_message = "The subnet_id value should either be empty or contain exactly two elements."
  }
}

##############################################################################
# High Availability (Hidden Feature)
##############################################################################
variable "enable_high_availability" {
  type        = bool
  default     = false
  description = "The solution supports high availability as an hidden feature that is disabled by default. You can enable the feature setting this value to true."
}

###########################################################################
# IBM Cloud Dababase for MySQL Instance variables
###########################################################################
variable "db_instance_info" {
  description = "The IBM Cloud Database for MySQL information required to reference the PAC database."
  type = object({
    id     = string
    adminuser     = string
    adminpassword = string
    hostname      = string
    port          = number
    certificate   = string
  })
  default     = null
}
