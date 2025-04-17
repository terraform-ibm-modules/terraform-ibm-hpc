variable "turn_on" {
  type        = string
  description = "It is used to turn on the null resources based on conditions."
}

variable "clone_path" {
  type        = string
  description = "Scale repo clone path"
}

variable "script_path" {
  type        = string
  description = "Python script path"
}

variable "create_scale_cluster" {
  type        = string
  description = "It enables scale cluster configuration."
}

variable "meta_private_key" {
  type        = string
  description = "Meta private key."
}

variable "ldap_cluster_prefix" {
  type        = string
  description = "LDAP cluster prefix."
}

variable "using_jumphost_connection" {
  type        = bool
  description = "If true, will skip the jump/bastion host configuration."
}

variable "write_inventory_complete" {
  type        = string
  description = "It is used to confirm inventory file written is completed."
}

variable "ldap_basedns" {
  type        = string
  description = "The dns domain name is used for configuring the LDAP server. If an LDAP server is already in existence, ensure to provide the associated DNS domain name."
}

variable "ldap_server" {
  type        = string
  description = "Provide the IP address for the existing LDAP server. If no address is given, a new LDAP server will be created."
}

variable "ldap_admin_password" {
  type        = string
  sensitive   = true
  description = "The LDAP administrative password should be 8 to 20 characters long, with a mix of at least three alphabetic characters, including one uppercase and one lowercase letter. It must also include two numerical digits and at least one special character from (~@_+:) are required. It is important to avoid including the username in the password for enhanced security."
}

variable "ldap_user_name" {
  type        = string
  description = "Custom LDAP User for performing cluster operations. Note: Username should be between 4 to 32 characters, (any combination of lowercase and uppercase letters).[This value is ignored for an existing LDAP server]"
}

variable "ldap_user_password" {
  type        = string
  sensitive   = true
  description = "The LDAP user password should be 8 to 20 characters long, with a mix of at least three alphabetic characters, including one uppercase and one lowercase letter. It must also include two numerical digits and at least one special character from (~@_+:) are required.It is important to avoid including the username in the password for enhanced security.[This value is ignored for an existing LDAP server]."
}

variable "bastion_user" {
  type        = string
  description = "Provide the username for Bastion login."
}

variable "bastion_instance_public_ip" {
  type        = string
  description = "Bastion instance public ip address."
}

variable "bastion_ssh_private_key" {
  type        = string
  description = "Bastion SSH private key path, which will be used to login to bastion host."
}