##############################################################################
# Offering Variations
##############################################################################
variable "ibm_customer_number" {
  type        = string
  sensitive   = true
  description = "Comma-separated list of the IBM Customer Number(s) (ICN) that is used for the Bring Your Own License (BYOL) entitlement check. For more information on how to find your ICN, see [What is my IBM Customer Number (ICN)?](https://www.ibm.com/support/pages/what-my-ibm-customer-number-icn)."
  validation {
    condition     = can(regex("^[0-9A-Za-z]*([0-9A-Za-z]+,[0-9A-Za-z]+)*$", var.ibm_customer_number))
    error_message = "The IBM customer number input value cannot have special characters."
  }
}

##############################################################################
# Account Variables
##############################################################################
variable "ibmcloud_api_key" {
  type        = string
  sensitive   = true
  description = "IBM Cloud API Key that will be used for authentication in scripts run in this module. Only required if certain options are required."
}

##############################################################################
# Cluster Level Variables
##############################################################################
variable "zone" {
  type        = string
  description = "Zone where VPC will be created."
}

variable "ssh_keys" {
  type        = list(string)
  default     = null
  description = "The key pair to use to access the HPC cluster."
}

variable "allowed_cidr" {
  type        = list(string)
  description = "Network CIDR to access the VPC. This is used to manage network ACL rules for accessing the cluster."
}

variable "prefix" {
  type        = string
  default     = "scale"
  description = "A unique identifier for resources. Must begin with a letter and end with a letter or number. This prefix will be prepended to any resources provisioned by this template. Prefixes must be 16 or fewer characters."
  validation {
    error_message = "Prefix must begin and end with a letter and contain only letters, numbers, and - characters."
    condition     = can(regex("^([A-z]|[a-z][-a-z0-9]*[a-z0-9])$", var.prefix))
  }
}

##############################################################################
# Resource Groups Variables
##############################################################################
variable "resource_group" {
  type        = string
  default     = "Default"
  description = "String describing resource groups to create or reference"

}

##############################################################################
# VPC Variables
##############################################################################
variable "vpc" {
  type        = string
  default     = null
  description = "Name of an existing VPC in which the cluster resources will be deployed. If no value is given, then a new VPC will be provisioned for the cluster. [Learn more](https://cloud.ibm.com/docs/vpc)"
}

variable "network_cidr" {
  type        = string
  default     = "10.0.0.0/8"
  description = "Network CIDR for the VPC. This is used to manage network ACL rules for cluster provisioning."
}

variable "placement_strategy" {
  type        = string
  default     = null
  description = "VPC placement groups to create (null / host_spread / power_spread)"
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

variable "bastion_ssh_keys" {
  type        = list(string)
  default     = null
  description = "The key pair to use to access the bastion host."
}

variable "bastion_subnets_cidr" {
  type        = string
  default     = "10.0.0.0/24"
  description = "Subnet CIDR block to launch the bastion host."
}

variable "enable_vpn" {
  type        = bool
  default     = false
  description = "The solution supports multiple ways to connect to your HPC cluster for example, using bastion node, via VPN or direct connection. If connecting to the HPC cluster via VPN, set this value to true."
}

variable "vpn_peer_cidr" {
  type        = list(string)
  default     = null
  description = "The peer CIDRs (e.g., 192.168.0.0/24) to which the VPN will be connected."
}

variable "vpn_peer_address" {
  type        = string
  default     = null
  description = "The peer public IP address to which the VPN will be connected."
}

variable "vpn_preshared_key" {
  type        = string
  default     = null
  description = "The pre-shared key for the VPN."
}

##############################################################################
# Deployer Variables
##############################################################################
variable "enable_deployer" {
  type        = bool
  default     = false
  description = "Deployer should be only used for better deployment performance"
}

variable "deployer_image" {
  type        = string
  default     = "ibm-redhat-8-10-minimal-amd64-2"
  description = "The image to use to deploy the deployer host."
}

variable "deployer_instance_profile" {
  type        = string
  default     = "mx2-4x32"
  description = "Deployer should be only used for better deployment performance"
}

##############################################################################
# Compute Variables
##############################################################################
variable "client_subnets_cidr" {
  type        = string
  default     = "10.10.10.0/24"
  description = "Subnet CIDR block to launch the client host."
}

variable "client_ssh_keys" {
  type        = list(string)
  default     = null
  description = "The key pair to use to launch the client host."
}

variable "client_instances" {
  type = list(
    object({
      profile = string
      count   = number
      image   = string
    })
  )
  default = [{
    profile = "cx2-2x4"
    count   = 2
    image   = "ibm-redhat-8-10-minimal-amd64-2"
  }]
  description = "Number of instances to be launched for client."
}

variable "compute_subnets_cidr" {
  type        = string
  default     = "10.10.20.0/24"
  description = "Subnet CIDR block to launch the compute cluster host."
}

variable "compute_ssh_keys" {
  type        = list(string)
  default     = null
  description = "The key pair to use to launch the compute host."
}

variable "compute_instances" {
  type = list(
    object({
      profile = string
      count   = number
      image   = string
    })
  )
  default = [{
    profile = "cx2-2x4"
    count   = 3
    image   = "ibm-redhat-8-10-minimal-amd64-2"
  }]
  description = "Total Number of instances to be launched for compute cluster."
}

variable "compute_gui_username" {
  type        = string
  default     = "admin"
  sensitive   = true
  description = "GUI user to perform system management and monitoring tasks on compute cluster."
}

variable "compute_gui_password" {
  type        = string
  default     = "hpc@IBMCloud"
  sensitive   = true
  description = "Password for compute cluster GUI"
}

##############################################################################
# Storage Scale Variables
##############################################################################
variable "storage_subnets_cidr" {
  type        = string
  default     = "10.10.30.0/24"
  description = "Subnet CIDR block to launch the storage cluster host."
}

variable "storage_ssh_keys" {
  type        = list(string)
  default     = null
  description = "The key pair to use to launch the storage cluster host."
}

variable "storage_instances" {
  type = list(
    object({
      profile    = string
      count      = number
      image      = string
      filesystem = optional(string)
    })
  )
  default = [{
    profile    = "bx2-2x8"
    count      = 2
    image      = "ibm-redhat-8-10-minimal-amd64-2"
    filesystem = "fs1"
  }]
  description = "Number of instances to be launched for storage cluster."
}

variable "protocol_subnets_cidr" {
  type        = string
  default     = "10.10.40.0/24"
  description = "Subnet CIDR block to launch the storage cluster host."
}

variable "protocol_instances" {
  type = list(
    object({
      profile = string
      count   = number
      image   = string
    })
  )
  default = [{
    profile = "bx2-2x8"
    count   = 2
    image   = "ibm-redhat-8-10-minimal-amd64-2"
  }]
  description = "Number of instances to be launched for protocol hosts."
}

variable "colocate_protocol_instances" {
  type        = bool
  default     = true
  description = "Enable it to use storage instances as protocol instances"
}

variable "storage_gui_username" {
  type        = string
  default     = "admin"
  sensitive   = true
  description = "GUI user to perform system management and monitoring tasks on storage cluster."
}

variable "storage_gui_password" {
  type        = string
  default     = "hpc@IBMCloud"
  sensitive   = true
  description = "Password for storage cluster GUI"
}

variable "filesystem_config" {
  type = list(object({
    filesystem               = string
    block_size               = string
    default_data_replica     = number
    default_metadata_replica = number
    max_data_replica         = number
    max_metadata_replica     = number
    mount_point              = string
  }))
  default = [{
    filesystem               = "fs1"
    block_size               = "4M"
    default_data_replica     = 2
    default_metadata_replica = 2
    max_data_replica         = 3
    max_metadata_replica     = 3
    mount_point              = "/ibm/fs1"
  }]
  description = "File system configurations."
}

variable "filesets_config" {
  type = list(object({
    fileset           = string
    filesystem        = string
    junction_path     = string
    client_mount_path = string
    quota             = number
  }))
  default = [{
    fileset           = "fileset1"
    filesystem        = "fs1"
    junction_path     = "/ibm/fs1/fileset1"
    client_mount_path = "/mnt"
    quota             = 100
  }]
  description = "Fileset configurations."
}


##############################################################################
# AFM Variables
##############################################################################

variable "afm_cos_config" {
  type = list(object({
    cos_instance         = string,
    bucket_name          = string,
    bucket_region        = string,
    cos_service_cred_key = string,
    afm_fileset          = string,
    mode                 = string,
    bucket_type          = string,
    bucket_storage_class = string
  }))
  description = "Please provide details for the Cloud Object Storage (COS) instance, including information about the COS bucket, service credentials (HMAC key), AFM fileset, mode (such as Read-only (RO), Single writer (SW), Local updates (LU), and Independent writer (IW)), storage class (standard, vault, cold, or smart), and bucket type (single_site_location, region_location, cross_region_location). Note : The 'afm_cos_config' can contain up to 5 entries. For further details on COS bucket locations, refer to the relevant documentation https://cloud.ibm.com/docs/cloud-object-storage/basics?topic=cloud-object-storage-endpoints."
  default     = [{ cos_instance = "", bucket_name = "", bucket_region = "us-south", cos_service_cred_key = "", afm_fileset = "indwriter", mode = "iw", bucket_storage_class = "smart", bucket_type = "region_location" }]
  validation {
    condition     = length([for item in var.afm_cos_config : item]) <= 5
    error_message = "The length of \"afm_cos_config\" must be less than or equal to 5."
  }
  validation {
    condition     = alltrue([for item in var.afm_cos_config : item.mode != ""])
    error_message = "The \"mode\" field must not be empty."
  }
  validation {
    condition     = length(distinct([for item in var.afm_cos_config : item.afm_fileset])) == length(var.afm_cos_config)
    error_message = "The \"afm_fileset\" name should be unique for each AFM COS bucket relation."
  }
  validation {
    condition     = alltrue([for item in var.afm_cos_config : item.afm_fileset != ""])
    error_message = "The \"afm_fileset\" field must not be empty."
  }
  validation {
    condition     = alltrue([for config in var.afm_cos_config : !(config.bucket_type == "single_site_location") || contains(["ams03", "che01", "mil01", "mon01", "par01", "sjc04", "sng01"], config.bucket_region)])
    error_message = "When 'bucket_type' is 'single_site_location', 'bucket_region' must be one of ['ams03', 'che01', 'mil01', 'mon01', 'par01', 'sjc04', 'sng01']."
  }
  validation {
    condition     = alltrue([for config in var.afm_cos_config : !(config.bucket_type == "cross_region_location") || contains(["us", "eu", "ap"], config.bucket_region)])
    error_message = "When 'bucket_type' is 'cross_region_location', 'bucket_region' must be one of ['us', 'eu', 'ap']."
  }
  validation {
    condition     = alltrue([for config in var.afm_cos_config : !(config.bucket_type == "region_location") || contains(["us-south", "us-east", "eu-gb", "eu-de", "jp-tok", "au-syd", "jp-osa", "ca-tor", "br-sao", "eu-es"], config.bucket_region)])
    error_message = "When 'bucket_type' is 'region_location', 'bucket_region' must be one of ['us-south', 'us-east', 'eu-gb', 'eu-de', 'jp-tok', 'au-syd', 'jp-osa', 'ca-tor', 'br-sao', 'eu-es']."
  }
  validation {
    condition     = alltrue([for item in var.afm_cos_config : (item.bucket_type == "" || contains(["cross_region_location", "single_site_location", "region_location"], item.bucket_type))])
    error_message = "Each 'bucket_type' must be either empty or one of 'region_location', 'single_site_location', 'cross_region_location'."
  }
  validation {
    condition     = alltrue([for item in var.afm_cos_config : (item.bucket_storage_class == "" || (can(regex("^[a-z]+$", item.bucket_storage_class)) && contains(["smart", "standard", "cold", "vault"], item.bucket_storage_class)))])
    error_message = "Each 'bucket_storage_class' must be either empty or one of 'smart', 'standard', 'cold', or 'vault', and all in lowercase."
  }
  validation {
    condition     = alltrue([for item in var.afm_cos_config : item.bucket_region != ""])
    error_message = "The \"bucket_region\" field must not be empty."
  }
}
variable "afm_instances" {
  type = list(
    object({
      profile = string
      count   = number
      image   = string
    })
  )
  default = [{
    profile = "bx2-2x8"
    count   = 0
    image   = "ibm-redhat-8-10-minimal-amd64-2"
  }]
  description = "Number of instances to be launched for afm hosts."
}

# variable "afm_cos_config" {
#   type = list(object({
#     afm_fileset          = string,
#     mode                 = string,
#     cos_instance         = string,
#     bucket_name          = string,
#     bucket_region        = string,
#     cos_service_cred_key = string,
#     bucket_type          = string,
#     bucket_storage_class = string
#   }))
#   default = [{
#     afm_fileset          = "afm_fileset"
#     mode                 = "iw"
#     cos_instance         = null
#     bucket_name          = null
#     bucket_region        = "us-south"
#     cos_service_cred_key = ""
#     bucket_storage_class = "smart"
#     bucket_type          = "region_location"
#   }]
#   description = "AFM configurations."
# }

##############################################################################
# DNS Variables
##############################################################################

variable "dns_instance_id" {
  type        = string
  default     = null
  description = "IBM Cloud HPC DNS service instance id."
}

variable "dns_custom_resolver_id" {
  type        = string
  default     = null
  description = "IBM Cloud DNS custom resolver id."
}

variable "dns_domain_names" {
  type = object({
    compute  = string
    storage  = string
    protocol = string
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
variable "key_management" {
  type        = string
  default     = "key_protect"
  description = "null/key_protect/hs_crypto"
}

variable "hpcs_instance_name" {
  type        = string
  default     = null
  description = "Hyper Protect Crypto Service instance"
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

variable "enable_atracker" {
  type        = bool
  default     = true
  description = "Enable Activity tracker"
}

variable "enable_vpc_flow_logs" {
  type        = bool
  default     = true
  description = "Enable Activity tracker"
}

##############################################################################
# Override JSON
##############################################################################
variable "override" {
  type        = bool
  default     = false
  description = "Override default values with custom JSON template. This uses the file `override.json` to allow users to create a fully customized environment."

}

variable "override_json_string" {
  type        = string
  default     = null
  description = "Override default values with a JSON object. Any JSON other than an empty string overrides other configuration changes."
}


variable "file_shares" {
  type = list(
    object({
      mount_path = string,
      size       = number,
      iops       = number
    })
  )
  default = [{
    mount_path = "/mnt/scale/tools"
    size       = 100
    iops       = 1000
    }, {
    mount_path = "/mnt/scale/data"
    size       = 100
    iops       = 1000
  }]
  description = "Custom file shares to access shared storage"
}

##############################################################################
# LDAP variables
##############################################################################
variable "enable_ldap" {
  type        = bool
  default     = false
  description = "Set this option to true to enable LDAP for IBM Cloud HPC, with the default value set to false."
}

variable "ldap_basedns" {
  type        = string
  default     = "ldapscale.com"
  description = "The dns domain name is used for configuring the LDAP server. If an LDAP server is already in existence, ensure to provide the associated DNS domain name."
}

variable "ldap_server" {
  type        = string
  default     = null
  description = "Provide the IP address for the existing LDAP server. If no address is given, a new LDAP server will be created."
}

variable "ldap_server_cert" {
  type        = string
  sensitive   = true
  default     = null
  description = "Provide the existing LDAP server certificate. This value is required if the 'ldap_server' variable is not set to null. If the certificate is not provided or is invalid, the LDAP configuration may fail."
}

variable "ldap_admin_password" {
  type        = string
  sensitive   = true
  default     = null
  description = "The LDAP administrative password should be 8 to 20 characters long, with a mix of at least three alphabetic characters, including one uppercase and one lowercase letter. It must also include two numerical digits and at least one special character from (~@_+:) are required. It is important to avoid including the username in the password for enhanced security."
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

variable "ldap_instance_key_pair" {
  type        = list(string)
  default     = null
  description = "Name of the SSH key configured in your IBM Cloud account that is used to establish a connection to the LDAP Server. Make sure that the SSH key is present in the same resource group and region where the LDAP Servers are provisioned. If you do not have an SSH key in your IBM Cloud account, create one by using the [SSH keys](https://cloud.ibm.com/docs/vpc?topic=vpc-ssh-keys) instructions."
}

variable "ldap_vsi_profile" {
  type        = string
  default     = "cx2-2x4"
  description = "Profile to be used for LDAP virtual server instance."
}

variable "ldap_vsi_osimage_name" {
  type        = string
  default     = "ibm-ubuntu-22-04-3-minimal-amd64-1"
  description = "Image name to be used for provisioning the LDAP instances. Note: Debian based OS are only supported for the LDAP feature."
}

##############################################################################
# GKLM variables
##############################################################################
variable "scale_encryption_enabled" {
  type        = bool
  default     = false
  description = "To enable the encryption for the filesystem. Select true or false"
}

variable "scale_encryption_type" {
  type        = string
  default     = "null"
  description = "To enable filesystem encryption, specify either 'key_protect' or 'gklm'. If neither is specified, the default value will be 'null' and encryption is disabled"

  validation {
    condition     = var.scale_encryption_type == "key_protect" || var.scale_encryption_type == "gklm" || var.scale_encryption_type == "null"
    error_message = "Invalid value: scale_encryption_type must be 'key_protect', 'gklm', or 'null'"
  }
}

variable "scale_encryption_admin_password" {
  type        = string
  sensitive   = true
  default     = ""
  description = "The password for administrative operations in KeyProtect or GKLM must be between 8 and 20 characters long. It must include at least three alphabetic characters (one uppercase and one lowercase), two numbers, and one special character from the set (~@_+:). The password should not contain the username. For more information, see [GKLM password policy](https://www.ibm.com/docs/en/sgklm/4.2?topic=manager-password-policy)"
}

variable "gklm_instance_key_pair" {
  type        = list(string)
  default     = null
  description = "The key pair to use to launch the GKLM host."
}

variable "gklm_instances" {
  type = list(
    object({
      profile = string
      count   = number
      image   = string
    })
  )
  default = [{
    profile = "bx2-2x8"
    count   = 2
    image   = "ibm-redhat-8-10-minimal-amd64-2"
  }]
  description = "Number of instances to be launched for client."
}
