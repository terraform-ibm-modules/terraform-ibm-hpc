variable "turn_on" {
  type        = string
  description = "It is used to turn on the null resources based on conditions."
}

variable "create_scale_cluster" {
  type        = string
  description = "It enables scale cluster configuration."
}

variable "clone_path" {
  type        = string
  description = "Scale repo clone path"
}

variable "compute_inventory_path" {
  type        = string
  description = "Compute JSON inventory path"
}

variable "compute_gui_inventory_path" {
  type        = string
  description = "Compute GUI inventory path"
}

variable "storage_inventory_path" {
  type        = string
  description = "Storage JSON inventory path"
}

variable "storage_gui_inventory_path" {
  type        = string
  description = "Storage GUI inventory path"
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

variable "using_rest_initialization" {
  type        = bool
  description = "If false, skips GUI initialization on compute cluster for remote mount configuration."
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

variable "using_jumphost_connection" {
  type        = bool
  description = "If true, will skip the jump/bastion host configuration."
}

variable "compute_cluster_create_complete" {
  type        = bool
  description = "Compute cluster creation completed."
}
variable "storage_cluster_create_complete" {
  type        = bool
  description = "Storage cluster creation completed."
}
