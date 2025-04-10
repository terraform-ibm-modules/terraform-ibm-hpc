variable "ldap_server" {
  type        = string
  description = "Provide the IP address for the existing LDAP server. If no address is given, a new LDAP server will be created."
}

variable "deployer_ip" {
  description = "Login host to be used for ssh connectivity."
  type        = string
}

variable "bastion_private_key_content" {
  description = "Login private key to be used for ssh connectivity."
  type        = string
}

variable "enable_deployer" {
  type        = bool
  default     = false
  description = "Deployer should be only used for better deployment performance"
}

variable "bastion_fip" {
  type        = string
  default     = null
  description = "deployer node ip"
}