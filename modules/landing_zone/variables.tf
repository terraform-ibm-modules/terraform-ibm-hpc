##############################################################################
# Account Variables
##############################################################################

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

variable "login_subnet_id" {
  type        = string
  default     = null
  description = "List of existing subnet ID under the VPC, where the login/Bastion server will be provisioned."
}

variable "network_cidr" {
  description = "Network CIDR for the VPC. This is used to manage network ACL rules for cluster provisioning."
  type        = string
  default     = "10.0.0.0/8"
}

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

##############################################################################
# Compute Variables
##############################################################################

variable "compute_subnets_cidr" {
  type        = list(string)
  default     = ["10.10.20.0/24", "10.20.20.0/24", "10.30.20.0/24"]
  description = "Subnet CIDR block to launch the compute cluster host."
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
  description = "Enable Activity tracker on COS"
}

variable "cos_expiration_days" {
  type        = number
  default     = 30
  description = "Specify the number of days after object creation to expire objects in COS buckets."
}

variable "enable_vpc_flow_logs" {
  type        = bool
  default     = true
  description = "Enable Activity tracker"
}

##############################################################################
# SCC Variables
##############################################################################

variable "scc_enable" {
  type        = bool
  default     = false
  description = "Flag to enable SCC instance creation. If true, an instance of SCC (Security and Compliance Center) will be created."
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

variable "no_addr_prefix" {
  type        = bool
  description = "Set it as true, if you don't want to create address prefixes."
}

variable "observability_logs_enable" {
  description = "Set false to disable IBM Cloud Logs integration. If enabled, infrastructure and LSF application logs from Management/Compute Nodes will be ingested under COS bucket."
  type        = bool
  default     = false
}

variable "skip_flowlogs_s2s_auth_policy" {
  type        = bool
  default     = false
  description = "Skip auth policy between flow logs service and COS instance, set to true if this policy is already in place on account."
}
