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

variable "inventory_path" {
  type        = string
  description = "Scale JSON inventory path"
}

variable "inventory_format" {
  type        = string
  description = "Scale inventory format"
}

variable "using_packer_image" {
  type        = bool
  description = "If true, gpfs rpm copy step will be skipped during the configuration."
}

variable "using_jumphost_connection" {
  type        = bool
  description = "If true, will skip the jump/bastion host configuration."
}

variable "using_rest_initialization" {
  type        = bool
  description = "If false, skips GUI initialization on compute cluster for remote mount configuration."
}

variable "compute_cluster_gui_username" {
  type        = string
  sensitive   = true
  description = "GUI user to perform system management and monitoring tasks on compute cluster."
}

variable "compute_cluster_gui_password" {
  type        = string
  sensitive   = true
  description = "Password for compute cluster GUI"
}

variable "comp_memory" {
  type        = string
  description = "Compute server memory"
}

variable "comp_vcpus_count" {
  type        = string
  description = "Compute vcpus count"
}

variable "comp_bandwidth" {
  type        = string
  description = "Compute bandwidth"
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

variable "meta_private_key" {
  type        = string
  description = "Meta private key."
}

variable "scale_version" {
  type        = string
  description = "Storage scale version."
}

variable "spectrumscale_rpms_path" {
  type        = string
  description = "Path that contains IBM Spectrum Scale product cloud rpms."
}

variable "enable_mrot_conf" {
  type        = bool
  description = "Enable MROT configuration."
}

variable "scale_encryption_enabled" {
  type        = bool
  description = "To enable the encryption for the filesystem. Select true or false"
}

variable "scale_encryption_admin_password" {
  type        = string
  description = "Password that is used for performing administrative operations for the GKLM.The password must contain at least 8 characters and at most 20 characters. For a strong password, at least three alphabetic characters are required, with at least one uppercase and one lowercase letter.  Two numbers, and at least one special character from this(~@_+:). Make sure that the password doesn't include the username. Visit this [page](https://www.ibm.com/docs/en/gklm/3.0.1?topic=roles-password-policy) to know more about password policy of GKLM. "
}

variable "scale_encryption_servers" {
  type        = list(string)
  description = "GKLM encryption servers."
}

variable "enable_ces" {
  type        = bool
  description = "Enable CES."
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

variable "enable_afm" {
  type        = bool
  description = "Enable AFM service."
}

variable "enable_key_protect" {
  type        = string
  description = "Enable Key Protect."
}