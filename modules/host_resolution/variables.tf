variable "storage_hosts" {}
variable "storage_mgmnt_hosts" {}
variable "storage_tb_hosts" {}
variable "compute_hosts" {}
variable "compute_mgmnt_hosts" {}
variable "client_hosts" {}
variable "protocol_hosts" {}
variable "gklm_hosts" {}
variable "afm_hosts" {}
variable "ldap_hosts" {}
variable "storage_bms_hosts" {}
variable "storage_tb_bms_hosts" {}
variable "protocol_bms_hosts" {}
variable "afm_bms_hosts" {}

variable "clone_path" {
  type        = string
  description = "Scale repo clone path"
}

variable "scheduler" {
  default     = null
  type        = string
  description = "Select one of the scheduler (Scale/LSF/Symphony/Slurm/null)"
}

variable "playbooks_path" {
  description = "Playbooks path"
  type        = string
  default     = ""
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