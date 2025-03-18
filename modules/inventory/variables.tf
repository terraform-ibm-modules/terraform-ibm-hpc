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

variable "ldap_hosts" {
  description = "LDAP Hosts"
  type        = list(string)
  default     = ["localhost"]
}