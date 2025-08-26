variable "ibmcloud_api_key" {
  type        = string
  sensitive   = true
  default     = null
  description = "IBM Cloud API Key that will be used for authentication in scripts run in this module. Only required if certain options are required."
}

variable "resource_group" {
  description = "String describing resource groups to create or reference"
  type        = string
  default     = null
}

variable "vpc_region" {
  type        = string
  default     = null
  description = "vpc region"
}

variable "storage_hosts" {
  description = "Map of storage hosts configuration"
  type        = map(string)
  default     = {}
}

variable "storage_mgmnt_hosts" {
  description = "Map of storage management hosts configuration"
  type        = map(string)
  default     = {}
}

variable "storage_tb_hosts" {
  description = "Map of storage TB (tape backup?) hosts configuration"
  type        = map(string)
  default     = {}
}

variable "compute_hosts" {
  description = "Map of compute hosts configuration"
  type        = map(string)
  default     = {}
}

variable "compute_mgmnt_hosts" {
  description = "Map of compute management hosts configuration"
  type        = map(string)
  default     = {}
}

variable "client_hosts" {
  description = "Map of client hosts configuration"
  type        = map(string)
  default     = {}
}

variable "protocol_hosts" {
  description = "Map of protocol hosts configuration"
  type        = map(string)
  default     = {}
}

variable "gklm_hosts" {
  description = "Map of GKLM (Global Key Lifecycle Manager?) hosts configuration"
  type        = map(string)
  default     = {}
}

variable "afm_hosts" {
  description = "Map of AFM (Azure File Manager?) hosts configuration"
  type        = map(string)
  default     = {}
}

variable "storage_bms_hosts" {
  description = "Map of storage BMS (Bare Metal Server?) hosts configuration"
  type = map(object({
    name = string
    id   = optional(string)
  }))
  default = {}
}

variable "storage_tb_bms_hosts" {
  description = "Map of storage TB BMS (tape backup bare metal servers?) configuration"
  type = map(object({
    name = string
    id   = optional(string)
  }))
  default = {}
}

variable "protocol_bms_hosts" {
  description = "Map of protocol BMS (bare metal servers) configuration"
  type = map(object({
    name = string
    id   = optional(string)
  }))
  default = {}
}

variable "afm_bms_hosts" {
  description = "Map of AFM BMS (bare metal servers) configuration"
  type = map(object({
    name = string
    id   = optional(string)
  }))
  default = {}
}

variable "clone_path" {
  type        = string
  description = "Scale repo clone path"
}

variable "scheduler" {
  default     = null
  type        = string
  description = "Select one of the scheduler (Scale/LSF/Symphony/Slurm/null)"
}

variable "storage_type" {
  type        = string
  default     = "scratch"
  description = "Select the required storage type(scratch/persistent/eval)."
}

variable "domain_names" {
  type = object({
    compute  = string
    storage  = optional(string)
    protocol = optional(string)
    client   = optional(string)
    gklm     = optional(string)
  })
  default = {
    compute  = "comp.com"
    storage  = "strg.com"
    protocol = "ces.com"
    client   = "clnt.com"
    gklm     = "gklm.com"
  }
  description = "IBM Cloud HPC DNS domain names."
}

variable "storage_interface" {
  description = "Network interface to use for storage traffic"
  type        = string
}

variable "protocol_interface" {
  description = "Network interface to use for protocol traffic"
  type        = string
}

variable "enable_protocol" {
  description = "Enable protocol services (true/false)"
  type        = bool
}

variable "protocol_subnets" {
  description = "List of subnets available for protocol services"
  type        = string
}

variable "bms_boot_drive_encryption" {
  type        = bool
  default     = false
  description = "To enable the encryption for the boot drive of bare metal server. Select true or false"
}
