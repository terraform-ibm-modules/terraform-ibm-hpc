##############################################################################
# Account Variables
##############################################################################
variable "ibmcloud_api_key" {
  type        = string
  sensitive   = true
  default     = null
  description = "IBM Cloud API Key that will be used for authentication in scripts run in this module. Only required if certain options are required."
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
  default     = null
  description = "Name of an existing VPC in which the cluster resources will be deployed. If no value is given, then a new VPC will be provisioned for the cluster. [Learn more](https://cloud.ibm.com/docs/vpc)"
}

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

variable "management_instances" {
  type = list(
    object({
      profile = string
      count   = number
      image   = string
    })
  )
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
  description = "Total Number of instances to be launched for compute cluster."
}

variable "dns_domain_names" {
  type = object({
    compute  = string
    storage  = string
    protocol = string
  })
  description = "IBM Cloud HPC DNS domain names."
}

##############################################################################
# Compute Variables
##############################################################################
variable "client_subnets" {
  type        = list(string)
  default     = null
  description = "Name of an existing subnets in which the cluster resources will be deployed. If no value is given, then new subnet(s) will be provisioned for the cluster. [Learn more](https://cloud.ibm.com/docs/vpc)"
}

variable "compute_ssh_keys" {
  type        = list(string)
  default     = null
  description = "The key pair to use to launch the compute host."
}

variable "client_instances" {
  type = list(
    object({
      profile = string
      count   = number
      image   = string
    })
  )
  description = "Number of instances to be launched for client."
}

variable "compute_subnets" {
  type        = list(string)
  default     = null
  description = "Name of an existing subnets in which the cluster resources will be deployed. If no value is given, then new subnet(s) will be provisioned for the cluster. [Learn more](https://cloud.ibm.com/docs/vpc)"
}

##############################################################################
# Storage Variables
##############################################################################
variable "storage_subnets" {
  type        = list(string)
  default     = null
  description = "Name of an existing subnets in which the cluster resources will be deployed. If no value is given, then new subnet(s) will be provisioned for the cluster. [Learn more](https://cloud.ibm.com/docs/vpc)"
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
  description = "Number of instances to be launched for storage cluster."
}

variable "protocol_instances" {
  type = list(
    object({
      profile = string
      count   = number
      image   = string
    })
  )
  description = "Number of instances to be launched for protocol hosts."
}

variable "protocol_subnets" {
  type        = list(string)
  default     = null
  description = "Name of an existing subnets in which the cluster resources will be deployed. If no value is given, then new subnet(s) will be provisioned for the cluster. [Learn more](https://cloud.ibm.com/docs/vpc)"
}

##############################################################################
# Offering Variations
##############################################################################
variable "ibm_customer_number" {
  type        = string
  sensitive   = true
  description = "Comma-separated list of the IBM Customer Number(s) (ICN) that is used for the Bring Your Own License (BYOL) entitlement check. For more information on how to find your ICN, see [What is my IBM Customer Number (ICN)?](https://www.ibm.com/support/pages/what-my-ibm-customer-number-icn)."
}

##############################################################################
# Observability Variables
##############################################################################
variable "enable_cos_integration" {
  type        = bool
  default     = false
  description = "Integrate COS with HPC solution"
}

variable "enable_vpc_flow_logs" {
  type        = bool
  default     = false
  description = "Enable Activity tracker"
}

##############################################################################
# SCC Variables
##############################################################################
variable "enable_atracker" {
  type        = bool
  default     = false
  description = "Enable Activity tracker"
}

variable "compute_public_key_content" {
  type        = string
  sensitive   = true
  default     = null
  description = "Compute security key content."
}

variable "compute_private_key_content" {
  type        = string
  sensitive   = true
  default     = null
  description = "Compute security key content."
}

variable "bastion_security_group_id" {
  type        = string
  default     = null
  description = "bastion security group id"
}

variable "deployer_hostname" {
  type        = string
  default     = null
  description = "deployer node hostname"
}

variable "deployer_ip" {
  type        = string
  default     = null
  description = "deployer node ip"
}

##############################################################################
# Terraform generic Variables
##############################################################################
variable "TF_PARALLELISM" {
  type        = string
  default     = "250"
  description = "Limit the number of concurrent operation."
}

variable "TF_VERSION" {
  type        = string
  default     = "1.9"
  description = "The version of the Terraform engine that's used in the Schematics workspace."
}

variable "TF_LOG" {
  type        = string
  default     = "ERROR"
  description = "The Terraform log level used for output in the Schematics workspace."
}