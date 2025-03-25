variable "json_inventory_path" {
  type        = string
  default     = "inventory.json"
  description = "Json inventory file path"
}

variable "lsf_masters" {
  type        = list(string)
  default     = null
  description = "list of lsf master nodes"
}

variable "lsf_servers" {
  type        = list(string)
  default     = null
  description = "list of lsf server nodes"
}

variable "lsf_clients" {
  type        = list(string)
  default     = null
  description = "list of lsf client nodes"
}

variable "gui_hosts" {
  type        = list(string)
  default     = null
  description = "list of lsf gui nodes"
}

variable "db_hosts" {
  type        = list(string)
  default     = null
  description = "list of lsf gui db nodes"
}

variable "my_cluster_name" {
  type        = string
  default     = null
  description = "Name of lsf cluster"
}

variable "ha_shared_dir" {
  type        = string
  default     = null
  description = "Path for lsf shared dir"
}

variable "nfs_install_dir" {
  type        = string
  default     = null
  description = "Private key file path"
}

variable "enable_monitoring" {
  type        = bool
  default     = null
  description = "Option to enable the monitoring"
}

variable "lsf_deployer_hostname" {
  type        = string
  default     = null
  description = "Deployer host name"
}

variable "compute_dns_name" {
  type        = string
  default     = null
  description = "Compute dns name"
}
