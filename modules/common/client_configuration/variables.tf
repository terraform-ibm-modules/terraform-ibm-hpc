variable "turn_on" {
  type        = string
  description = "It is used to turn on the null resources based on conditions."
}

variable "write_inventory_complete" {
  type        = string
  description = "It is used to confirm inventory file written is completed."
}

variable "create_scale_cluster" {
  type        = string
  description = "It enables scale cluster configuration."
}

variable "clone_path" {
  type        = string
  description = "Scale repo clone path"
}

variable "using_jumphost_connection" {
  type        = bool
  description = "If true, will skip the jump/bastion host configuration."
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

variable "enable_ldap" {
  type        = bool
  description = "Set this option to true to enable LDAP for IBM Cloud HPC, with the default value set to false."
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

variable "storage_cluster_create_complete" {
  type        = bool
  description = "Storage cluster crete complete"
}

variable "client_inventory_path" {
  type        = string
  description = "Client inventory path"
}

variable "client_meta_private_key" {
  type        = string
  description = "Client SSH private key path, which will be used to login to client host."
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
