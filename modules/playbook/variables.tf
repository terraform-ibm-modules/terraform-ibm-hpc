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

# LDAP
variable "enable_ldap" {
  type        = bool
  default     = false
  description = "Set this option to true to enable LDAP for IBM Spectrum LSF, with the default value set to false."
}

variable "ldap_server" {
  type        = string
  default     = "null"
  description = "Provide the IP address for the existing LDAP server. If no address is given, a new LDAP server will be created."
}

variable "ldap_inventory_path" {
  description = "Inventory file path"
  type        = string
  default     = "ldap_server_setup.ini"
}

variable "ldap_playbook_path" {
  description = "Playbook path"
  type        = string
  default     = "ldap_server_setup.yaml"
}