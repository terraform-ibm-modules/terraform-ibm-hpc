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

variable "playbooks_root_path" {
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