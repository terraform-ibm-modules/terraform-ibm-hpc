##############################################################################
# Offering Variations
##############################################################################
variable "storage_type" {
  type        = string
  default     = "scratch"
  description = "Select the required storage type(scratch/persistent/eval)."
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

variable "placement_group_ids" {
  type        = string
  default     = null
  description = "VPC placement group ids"
}

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

variable "client_subnets" {
  type = list(object({
    name = string
    id   = string
    zone = string
    cidr = string
  }))
  default     = []
  description = "Subnets to launch the client hosts."
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

variable "compute_subnets" {
  type = list(object({
    name = string
    id   = string
    zone = string
    cidr = string
  }))
  default     = []
  description = "Subnets to launch the compute host."
}

variable "compute_ssh_keys" {
  type        = list(string)
  default     = null
  description = "The key pair to use to launch the compute host."
}

variable "management_instances" {
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
  description = "Number of instances to be launched for management."
}

variable "static_compute_instances" {
  type = list(
    object({
      profile = string
      count   = number
      image   = string
    })
  )
  default = [{
    profile = "cx2-2x4"
    count   = 1
    image   = "ibm-redhat-8-10-minimal-amd64-2"
  }]
  description = "Min Number of instances to be launched for compute cluster."
}

variable "dynamic_compute_instances" {
  type = list(
    object({
      profile = string
      count   = number
      image   = string
    })
  )
  default = [{
    profile = "cx2-2x4"
    count   = 250
    image   = "ibm-redhat-8-10-minimal-amd64-2"
  }]
  description = "MaxNumber of instances to be launched for compute cluster."
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
# Scale Storage Variables
##############################################################################

variable "storage_subnets" {
  type = list(object({
    name = string
    id   = string
    zone = string
    cidr = string
  }))
  default     = []
  description = "Subnets to launch the storage host."
}

variable "storage_ssh_keys" {
  type        = list(string)
  description = "The key pair to use to launch the storage cluster host."
}

variable "storage_instances" {
  type = list(
    object({
      profile         = string
      count           = number
      image           = string
      filesystem_name = optional(string)
    })
  )
  default = [{
    profile         = "bx2-2x8"
    count           = 2
    image           = "ibm-redhat-8-10-minimal-amd64-2"
    filesystem_name = "fs1"
  }]
  description = "Number of instances to be launched for storage cluster."
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

variable "nsd_details" {
  type = list(
    object({
      profile  = string
      capacity = optional(number)
      iops     = optional(number)
    })
  )
  default     = null
  description = "NSD details"
}

##############################################################################
# DNS Template Variables
##############################################################################

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
# LDAP Variables
# TODO: Auth Server (LDAP/AD) Variables
##############################################################################
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

variable "ldap_server_cert" {
  type        = string
  sensitive   = true
  default     = "null"
  description = "Provide the existing LDAP server certificate. If not provided, the value should be set to 'null'."
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
  default     = "ibm-ubuntu-22-04-4-minimal-amd64-3"
  description = "Image name to be used for provisioning the LDAP instances."
}

variable "ldap_primary_ip" {
  type        = list(string)
  description = "List of LDAP primary IPs."
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
  default     = ""
  description = "To enable filesystem encryption, specify either 'key_protect' or 'gklm'. If neither is specified, the default value will be 'null' and encryption is disabled"
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
