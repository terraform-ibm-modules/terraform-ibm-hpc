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
  type        = map(string)
  default     = {}
}

variable "storage_tb_bms_hosts" {
  description = "Map of storage TB BMS (tape backup bare metal servers?) configuration"
  type        = map(string)
  default     = {}
}

variable "protocol_bms_hosts" {
  description = "Map of protocol BMS (bare metal servers) configuration"
  type        = map(string)
  default     = {}
}

variable "afm_bms_hosts" {
  description = "Map of AFM BMS (bare metal servers) configuration"
  type        = map(string)
  default     = {}
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
