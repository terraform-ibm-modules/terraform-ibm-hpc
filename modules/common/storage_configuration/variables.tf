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

variable "scale_config_path" {
  type        = string
  description = "Path to clone github.com/IBM/ibm-spectrum-scale-install-infra."
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

variable "storage_cluster_gui_username" {
  type        = string
  sensitive   = true
  description = "GUI user to perform system management and monitoring tasks on storage cluster."
}

variable "storage_cluster_gui_password" {
  type        = string
  sensitive   = true
  description = "Password for storage cluster GUI"
}

variable "colocate_protocol_instances" {
  type        = bool
  description = "Enable it to use storage instances as protocol instances"
}

variable "is_colocate_protocol_subset" {
  type        = bool
  description = "It checks protocol node should be less than or equal storage node when colocation is enabled."
}

variable "mgmt_memory" {
  type        = string
  description = "Storage management node memory"
}

variable "mgmt_vcpus_count" {
  type        = string
  description = "Storage management node vcpu count"
}

variable "mgmt_bandwidth" {
  type        = string
  description = "Storage management node bandwidth"
}

variable "strg_desc_memory" {
  type        = string
  description = "Storage desc node memory"
}

variable "strg_desc_vcpus_count" {
  type        = string
  description = "Storage desc node vcpu count"
}

variable "strg_desc_bandwidth" {
  type        = string
  description = "Storage desc node bandwidth"
}

variable "strg_memory" {
  type        = string
  description = "Storage node memory"
}

variable "strg_vcpus_count" {
  type        = string
  description = "Storage node vcpu count"
}

variable "strg_bandwidth" {
  type        = string
  description = "Storage node bandwidth"
}

variable "proto_memory" {
  type        = string
  description = "Protocol node memory"
}

variable "proto_vcpus_count" {
  type        = string
  description = "Protocol node vcpu count"
}

variable "proto_bandwidth" {
  type        = string
  description = "Protocol node bandwidth"
}

variable "strg_proto_memory" {
  type        = string
  description = "Memory when storage node is used as protocol node."
}

variable "strg_proto_vcpus_count" {
  type        = string
  description = "Vcpu count when storage node is used as protocol node."
}
variable "strg_proto_bandwidth" {
  type        = string
  description = "Bandwidth when storage node is used as protocol node."
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

variable "scale_encryption_type" {
  type        = string
  description = "To enable filesystem encryption, specify either 'key_protect' or 'gklm'. If neither is specified, the default value will be 'null' and encryption is disabled"
}

variable "scale_encryption_admin_password" {
  type        = string
  description = "Password that is used for performing administrative operations for the GKLM.The password must contain at least 8 characters and at most 20 characters. For a strong password, at least three alphabetic characters are required, with at least one uppercase and one lowercase letter.  Two numbers, and at least one special character from this(~@_+:). Make sure that the password doesn't include the username. Visit this [page](https://www.ibm.com/docs/en/gklm/3.0.1?topic=roles-password-policy) to know more about password policy of GKLM. "
}

variable "scale_encryption_servers" {
  type        = list(string)
  description = "GKLM encryption servers."
}

variable "disk_type" {
  type        = string
  description = "Disk type."
}

variable "default_metadata_replicas" {
  type        = string
  description = "Default metadata replicas."
}

variable "max_metadata_replicas" {
  type        = string
  description = "Max metadata replicas."
}

variable "default_data_replicas" {
  type        = string
  description = "Default data replicas."
}

variable "max_data_replicas" {
  type        = string
  description = "Max data replicas."
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

variable "ldap_server_cert" {
  type        = string
  sensitive   = true
  description = "Provide the existing LDAP server certificate. This value is required if the 'ldap_server' variable is not set to null. If the certificate is not provided or is invalid, the LDAP configuration may fail."
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

variable "afm_memory" {
  type        = string
  description = "AFM node memory"
}

variable "afm_vcpus_count" {
  type        = string
  description = "AFM node vcpus count"
}

variable "afm_bandwidth" {
  type        = string
  description = "AFM node bandwidth"
}

variable "storage_type" {
  type        = string
  default     = "vsi"
  description = "Select the required storage type(vsi/baremetal/eval)."
}

variable "boot_volume_disk_grow" {
  type        = bool
  default     = false
  description = "Boot volume disk size grow option for SDP."
}

variable "block_volume_disk_grow" {
  type        = bool
  default     = false
  description = "Block volume disk size grow option for SDP."
}

variable "bms_boot_drive_encryption" {
  type        = bool
  default     = false
  description = "To enable the encryption for the boot drive of bare metal server. Select true or false"
}
