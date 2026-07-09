variable "compute_cluster_create_complete" {
  type        = bool
  description = "Compute cluster creation completed."
}

variable "storage_cluster_create_complete" {
  type        = bool
  description = "Storage cluster creation completed."
}

variable "network_playbook_path" {
  type        = string
  description = "Path for network playbook."
}

variable "turn_on" {
  type        = string
  description = "It is used to turn on the null resources based on conditions."
}

variable "create_scale_cluster" {
  type        = string
  description = "It enables scale cluster configuration."
}

variable "inventory_path" {
  type        = string
  description = "Scale JSON inventory path"
}
