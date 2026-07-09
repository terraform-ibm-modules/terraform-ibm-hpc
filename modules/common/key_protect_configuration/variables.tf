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

variable "scale_encryption_type" {
  type        = string
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
