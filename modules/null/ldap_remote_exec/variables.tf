variable "enable_ldap" {
  type        = bool
  description = "Set this option to true to enable LDAP for IBM Cloud HPC, with the default value set to false."
}

variable "ldap_server" {
  type        = string
  description = "Provide the IP address for the existing LDAP server. If no address is given, a new LDAP server will be created."
}

variable "login_host" {
  description = "Login host to be used for ssh connectivity."
  type        = string
}

variable "login_user" {
  description = "Login user to be used for ssh connectivity."
  type        = string
}

variable "login_private_key" {
  description = "Login private key to be used for ssh connectivity."
  type        = string
}
