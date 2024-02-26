##############################################################################
# Offering Variations
##############################################################################
# Future use
/*
variable "scheduler" {
  type        = string
  default     = "LSF"
  description = "Select one of the scheduler (LSF/Symphony/Slurm/None)"
}

variable "storage_type" {
  type        = string
  default     = "scratch"
  description = "Select the required storage type(scratch/persistent/eval)."
}
*/

variable "ibm_customer_number" {
  type        = string
  sensitive   = true
  default     = ""
  description = "Comma-separated list of the IBM Customer Number(s) (ICN) that is used for the Bring Your Own License (BYOL) entitlement check. For more information on how to find your ICN, see [What is my IBM Customer Number (ICN)?](https://www.ibm.com/support/pages/what-my-ibm-customer-number-icn)."
  validation {
    # regex(...) fails if the IBM customer number has special characters.
    condition     = can(regex("^[0-9A-Za-z]*([0-9A-Za-z]+,[0-9A-Za-z]+)*$", var.ibm_customer_number))
    error_message = "The IBM customer number input value cannot have special characters."
  }
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
  default     = "Default"
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
  default     = "null"
}

variable "subnet_id" {
  type        = list(string)
  default     = null
  description = "List of existing subnet IDs under the VPC, where the cluster will be provisioned."
}

variable "login_subnet_id" {
  type        = string
  default     = "null"
  description = "List of existing subnet ID under the VPC, where the login/Bastion server will be provisioned."
}

variable "network_cidr" {
  description = "Network CIDR for the VPC. This is used to manage network ACL rules for cluster provisioning."
  type        = string
  default     = "10.0.0.0/8"
}

variable "existing_subnet_cidrs" {
  description = "Network CIDR for the Existing Subnet. This is used to manage network ACL rules for cluster provisioning."
  type        = list(string)
  default     = null
}

# variable "placement_strategy" {
#   type        = string
#   default     = null
#   description = "VPC placement groups to create (null / host_spread / power_spread)"
# }
##############################################################################
# Access Variables
##############################################################################
# variable "enable_bastion" {
#   type        = bool
#   default     = true
#   description = "The solution supports multiple ways to connect to your HPC cluster for example, using bastion node, via VPN or direct connection. If connecting to the HPC cluster via VPN or direct connection, set this value to false."
# }

# variable "enable_bootstrap" {
#   type        = bool
#   default     = false
#   description = "Bootstrap should be only used for better deployment performance"
# }

# variable "bootstrap_instance_profile" {
#   type        = string
#   default     = "mx2-4x32"
#   description = "Bootstrap should be only used for better deployment performance"
# }

variable "bastion_ssh_keys" {
  type        = list(string)
  description = "The key pair to use to access the bastion host."
}

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

# variable "peer_cidr_list" {
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
# Future use
/*
variable "login_subnets_cidr" {
  type        = list(string)
  default     = ["10.10.10.0/24", "10.20.10.0/24", "10.30.10.0/24"]
  description = "Subnet CIDR block to launch the login host."
}
*/

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

variable "compute_subnets_cidr" {
  type        = list(string)
  default     = ["10.10.20.0/24", "10.20.20.0/24", "10.30.20.0/24"]
  description = "Subnet CIDR block to launch the compute cluster host."
}

variable "compute_ssh_keys" {
  type        = list(string)
  description = "The key pair to use to launch the compute host."
}

variable "management_image_name" {
  type        = string
  default     = "ibm-redhat-8-6-minimal-amd64-5"
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
  default     = "ibm-redhat-8-6-minimal-amd64-5"
  description = "Image name to use for provisioning the compute cluster instances."
}
# Future use
/*
variable "compute_gui_username" {
  type        = string
  default     = "admin"
  sensitive   = true
  description = "GUI user to perform system management and monitoring tasks on compute cluster."
}

variable "compute_gui_password" {
  type        = string
  sensitive   = true
  description = "Password for compute cluster GUI"
}
*/
##############################################################################
# Scale Storage Variables
##############################################################################

# variable "storage_subnets_cidr" {
#   type        = list(string)
#   default     = ["10.10.30.0/24", "10.20.30.0/24", "10.30.30.0/24"]
#   description = "Subnet CIDR block to launch the storage cluster host."
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
# Future use
/*
variable "storage_gui_username" {
  type        = string
  default     = "admin"
  sensitive   = true
  description = "GUI user to perform system management and monitoring tasks on storage cluster."
}

variable "storage_gui_password" {
  type        = string
  sensitive   = true
  description = "Password for storage cluster GUI"
}
*/

variable "file_shares" {
  type = list(
    object({
      mount_path = string,
      size       = number,
      iops       = number
    })
  )
  default = [{
    mount_path = "/mnt/binaries"
    size       = 100
    iops       = 1000
    }, {
    mount_path = "/mnt/data"
    size       = 100
    iops       = 1000
  }]
  description = "Custom file shares to access shared storage"
}

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
#   description = "Storage scale NSD details"
# }

##############################################################################
# DNS Template Variables
##############################################################################

variable "dns_instance_id" {
  type        = string
  default     = "null"
  description = "IBM Cloud HPC DNS service instance id."
}

variable "dns_custom_resolver_id" {
  type        = string
  default     = "null"
  description = "IBM Cloud DNS custom resolver id."
}

variable "dns_domain_names" {
  type = object({
    compute = string
    #storage  = string
    #protocol = string
  })
  default = {
    compute = "comp.com"
  }
  description = "IBM Cloud HPC DNS domain names."
}

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
  default     = "key_protect"
  description = "null/key_protect"
}

variable "kms_instance_name" {
  type        = string
  default     = "null"
  description = "Name of the Key Protect instance associated with the Key Management Service. The ID can be found under the details of the KMS, see [View key-protect ID](https://cloud.ibm.com/docs/key-protect?topic=key-protect-retrieve-instance-ID&interface=ui)."
}

variable "kms_key_name" {
  type        = string
  default     = "null"
  description = "Provide the existing KMS encryption key name that you want to use for the IBM Cloud HPC cluster. (for example kms_key_name: my-encryption-key)."
}

# variable "hpcs_instance_name" {
#   type        = string
#   default     = null
#   description = "Hyper Protect Crypto Service instance"
# }

##############################################################################
# TODO: Sagar changes
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

# variable "ssh_key_name" {
#   type        = string
#   description = "Comma-separated list of names of the SSH keys that is configured in your IBM Cloud account, used to establish a connection to the IBM Cloud HPC cluster node. Ensure that the SSH key is present in the same resource group and region where the cluster is being provisioned. If you do not have an SSH key in your IBM Cloud account, create one by according to [SSH Keys](https://cloud.ibm.com/docs/vpc?topic=vpc-ssh-keys)."
# }

variable "enable_fip" {
  type        = bool
  default     = true
  description = "The solution supports multiple ways to connect to your IBM Cloud HPC cluster for example, using a login node, or using VPN or direct connection. If connecting to the IBM Cloud HPC cluster using VPN or direct connection, set this value to false."
}

###########################################################################
# List of script filenames used by validation test suites.
# If provided, these scripts will be executed as part of validation test suites execution.
###########################################################################

variable "TF_VALIDATION_SCRIPT_FILES" {
  type        = list(string)
  default     = []
  description = "List of script file names used by validation test suites. If provided, these scripts will be executed as part of validation test suites execution."
  validation {
    condition     = alltrue([for filename in var.TF_VALIDATION_SCRIPT_FILES : can(regex(".*\\.sh$", filename))])
    error_message = "All validation script file names must end with .sh."
  }
}

variable "login_node_instance_type" {
  type        = string
  default     = "bx2-2x8"
  description = "Specify the virtual server instance profile type to be used to create the login node for the IBM Cloud HPC cluster. For choices on profile types, see [Instance profiles](https://cloud.ibm.com/docs/vpc?topic=vpc-profiles)."
  validation {
    condition     = can(regex("^[^\\s]+-[0-9]+x[0-9]+", var.login_node_instance_type))
    error_message = "The profile must be a valid profile name."
  }
}

variable "enable_ldap" {
  type        = bool
  default     = false
  description = "Set this option to true to enable LDAP for IBM Cloud HPC, with the default value set to false."
}

variable "ldap_basedns" {
  type        = string
  default     = "hpcaas.com"
  description = "The dns domain name is used for configuring the LDAP server. If an LDAP server is already in existence, ensure to provide the associated DNS domain name."
}

variable "ldap_server" {
  type        = string
  default     = "null"
  description = "Provide the IP address for the existing LDAP server. If no address is given, a new LDAP server will be created."
}

variable "ldap_admin_password" {
  type        = string
  sensitive   = true
  default     = ""
  description = "The LDAP administrative password should be 8 to 20 characters long, with a mix of at least three alphabetic characters, including one uppercase and one lowercase letter. It must also include two numerical digits and at least one special character from (~@_+:) are required. It is important to avoid including the username in the password for enhanced security.[This value is ignored for an existing LDAP server]."
}

variable "ldap_user_name" {
  type        = string
  default     = ""
  description = "Custom LDAP User for performing cluster operations. Note: Username should be between 4 to 32 characters, (any combination of lowercase and uppercase letters).[This value is ignored for an existing LDAP server]"
}

variable "ldap_user_password" {
  type        = string
  sensitive   = true
  default     = ""
  description = "The LDAP user password should be 8 to 20 characters long, with a mix of at least three alphabetic characters, including one uppercase and one lowercase letter. It must also include two numerical digits and at least one special character from (~@_+:) are required.It is important to avoid including the username in the password for enhanced security.[This value is ignored for an existing LDAP server]."
}

variable "ldap_vsi_profile" {
  type        = string
  default     = "cx2-2x4"
  description = "Profile to be used for LDAP virtual server instance."
}

variable "ldap_vsi_osimage_name" {
  type        = string
  default     = "ibm-ubuntu-22-04-3-minimal-amd64-1"
  description = "Image name to be used for provisioning the LDAP instances."
}

variable "skip_iam_authorization_policy" {
  type        = string
  default     = null
  description = "Skip IAM Authorization policy"
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
# IBM Cloud Dababase for MySQL Variables
###########################################################################
variable "db_template" {
  type        = list(any)
  description = "Set the initial resource allocation: members count, RAM (Mb), Disks (Mb) and CPU cores count."
  default     = [3, 12288, 122880, 3]
}
