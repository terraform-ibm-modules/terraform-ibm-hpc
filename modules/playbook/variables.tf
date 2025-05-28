variable "bastion_fip" {
  type        = string
  default     = null
  description = "If Bastion is enabled, jump-host connection is required."
}

variable "private_key_path" {
  description = "Private key file path"
  type        = string
  default     = "id_rsa"
}

variable "inventory_path" {
  description = "Inventory file path"
  type        = string
  default     = "inventory.ini"
}

variable "playbook_path" {
  description = "Playbook path"
  type        = string
  default     = "ssh.yaml"
}

variable "enable_bastion" {
  type        = bool
  default     = true
  description = "The solution supports multiple ways to connect to your HPC cluster for example, using bastion node, via VPN or direct connection. If connecting to the HPC cluster via VPN or direct connection, set this value to false."
}

variable "observability_playbook_path" {
  description = "Observability Playbook path"
  type        = string
  default     = "ssh.yaml"
}

variable "lsf_mgmt_playbooks_path" {
  description = "Playbook root path"
  type        = string
  default     = ""
}

variable "ibmcloud_api_key" {
  type        = string
  default     = ""
  description = "IBM Cloud API Key that will be used for authentication in scripts run in this module. Only required if certain options are required."
}

variable "observability_provision" {
  description = "Set true to provision observability instances"
  type        = bool
  default     = false
}

variable "enable_ldap" {
  type        = bool
  default     = false
  description = "Set this option to true to enable LDAP for IBM Spectrum LSF, with the default value set to false."
}

variable "ldap_server" {
  type        = string
  default     = "null"
  description = "Provide the IP address for the LDAP server."
}

variable "playbooks_path" {
  description = "Playbooks path"
  type        = string
  default     = ""
}

variable "cloudlogs_provision" {
  description = "Set true to provision cloud logs instances"
  type        = bool
  default     = false
}

variable "scheduler" {
  default     = null
  type        = string
  description = "Select one of the scheduler (LSF/Symphony/Slurm/null)"
}
