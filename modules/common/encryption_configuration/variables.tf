variable "turn_on" {
  type        = string
  description = "To turn on the null resources based on conditions."
}

variable "clone_path" {
  type        = string
  description = "Scale repo clone path"
}

variable "create_scale_cluster" {
  type        = string
  description = "Eenables scale cluster configuration."
}

variable "meta_private_key" {
  type        = string
  description = "Meta private key."
}

variable "scale_cluster_clustername" {}
variable "scale_encryption_servers" {
  type        = list(string)
  description = "GKLM encryption servers."
}

variable "scale_encryption_servers_dns" {}


variable "scale_encryption_admin_default_password" {
  type        = string
  default     = "SKLM@dmin123"
  description = "The default administrator password used for resetting the admin password based on the user input. The password has to be updated which was configured during the GKLM installation."
}

variable "scale_encryption_admin_username" {
  type        = string
  default     = null
  description = "The default Admin username for Security Key Lifecycle Manager(GKLM)."
}

variable "scale_encryption_admin_password" {
  type        = string
  default     = null
  description = "Password that is used for performing administrative operations for the GKLM.The password must contain at least 8 characters and at most 20 characters. For a strong password, at least three alphabetic characters are required, with at least one uppercase and one lowercase letter.  Two numbers, and at least one special character from this(~@_+:). Make sure that the password doesn't include the username. Visit this [page](https://www.ibm.com/docs/en/gklm/3.0.1?topic=roles-password-policy) to know more about password policy of GKLM. "
}

variable "scale_encryption_type" {
  type        = string
  default     = null
  description = "To enable filesystem encryption, specify either 'key_protect' or 'gklm'. If neither is specified, the default value will be 'null' and encryption is disabled"
}

variable "compute_cluster_create_complete" {
  type        = bool
  description = "Status of the compute cluster complete"
}

variable "storage_cluster_create_complete" {
  type        = bool
  description = "Status of the compute cluster complete"
}
variable "remote_mount_create_complete" {
  type        = bool
  description = "Status of the compute cluster complete"
}

variable "compute_cluster_encryption" {
  type        = bool
  description = "Status of the compute cluster complete"
}

variable "storage_cluster_encryption" {
  type        = bool
  description = "Status of the compute cluster complete"
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