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

variable "enable_bootstrap" {
  type        = bool
  default     = false
  description = "Bootstrap should be only used for better deployment performance"
}