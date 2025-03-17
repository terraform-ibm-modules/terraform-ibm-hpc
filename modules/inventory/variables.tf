variable "hosts" {
  description = "Hosts"
  type        = list(string)
  default     = ["localhost"]
}

variable "inventory_path" {
  description = "Inventory file path"
  type        = string
  default     = "inventory.ini"
}

variable "name_mount_path_map" {
  description = "File share mount path"
  #type        = list(string)
  default     = null
}

# LDAP
variable "enable_ldap" {
  type        = bool
  default     = false
  description = "Set this option to true to enable LDAP for IBM Spectrum LSF, with the default value set to false."
}

variable "ldap_inventory_path" {
  description = "Inventory file path"
  type        = string
  default     = "ldap.ini"
}

variable "ldap_hosts" {
  description = "LDAP Hosts"
  type        = list(string)
  default     = ["localhost"]
}