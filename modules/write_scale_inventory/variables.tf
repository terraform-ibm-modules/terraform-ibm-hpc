# variable "lsf_masters" {
#   type        = list(string)
#   default     = null
#   description = "list of lsf master nodes"
# }

# variable "lsf_servers" {
#   type        = list(string)
#   default     = null
#   description = "list of lsf server nodes"
# }

# variable "lsf_clients" {
#   type        = list(string)
#   default     = null
#   description = "list of lsf client nodes"
# }

# variable "gui_hosts" {
#   type        = list(string)
#   default     = null
#   description = "list of lsf gui nodes"
# }

# variable "db_hosts" {
#   type        = list(string)
#   default     = null
#   description = "list of lsf gui db nodes"
# }

# variable "my_cluster_name" {
#   type        = string
#   default     = null
#   description = "Name of lsf cluster"
# }

# variable "ha_shared_dir" {
#   type        = string
#   default     = null
#   description = "Path for lsf shared dir"
# }

# variable "nfs_install_dir" {
#   type        = string
#   default     = null
#   description = "Private key file path"
# }

# variable "Enable_Monitoring" {
#   type        = bool
#   default     = null
#   description = "Option to enable the monitoring"
# }

# variable "lsf_deployer_hostname" {
#   type        = string
#   default     = null
#   description = "Deployer host name"
# }

variable "json_inventory_path" {
  type        = string
  default     = "inventory.json"
  description = "Json inventory file path"
}

variable "cloud_platform" {
  type        = string
  default     = null
  description = "cloud platform name"
}

variable "resource_prefix" {
  type        = string
  default     = "hpc"
  description = "A unique identifier for resources. Must begin with a letter and end with a letter or number. This prefix will be prepended to any resources provisioned by this template. Prefixes must be 16 or fewer characters."
}

variable "vpc_region" {
  type        = string
  default     = null
  description = "vpc region"
}

variable "filesystem_block_size" {
  type        = string
  default     = "4M"
  description = "Filesystem block size."
}

variable "vpc_availability_zones" {
  # type        = list(string)
  default     = null
  description = "A list of availability zones names or ids in the region."
}

variable "scale_version" {
  type        = string
  default     = null
  description = "IBM Storage Scale Version."
}

variable "compute_cluster_filesystem_mountpoint" {
  type        = string
  default     = "/gpfs/fs1"
  description = "Compute cluster (accessingCluster) Filesystem mount point."
}

variable "bastion_user" {}
variable "bastion_instance_id" {}
variable "bastion_instance_public_ip" {}
variable "compute_cluster_instance_ids" {}
variable "compute_cluster_instance_private_ips" {}
variable "compute_cluster_instance_private_dns_ip_map" {}
variable "storage_cluster_filesystem_mountpoint" {}
variable "storage_cluster_instance_ids" {}
variable "storage_cluster_instance_private_ips" {}
variable "storage_cluster_with_data_volume_mapping" {}
variable "storage_cluster_instance_private_dns_ip_map" {}
variable "storage_cluster_desc_instance_ids" {}
variable "storage_cluster_desc_instance_private_ips" {}
variable "storage_cluster_desc_data_volume_mapping" {}
variable "storage_cluster_desc_instance_private_dns_ip_map" {}
variable "compute_cluster_instance_names" {}
variable "storage_cluster_instance_names" {}
variable "storage_subnet_cidr" {}
variable "compute_subnet_cidr" {}
variable "scale_remote_cluster_clustername" {}
variable "protocol_cluster_instance_names" {}
variable "client_cluster_instance_names" {}
variable "protocol_cluster_reserved_names" {}
variable "smb" {}
variable "nfs" {}
variable "interface" {}
variable "export_ip_pool" {}
variable "filesystem" {}
variable "mountpoint" {}
variable "object" {}
variable "protocol_gateway_ip" {}
variable "filesets" {}
variable "afm_cos_bucket_details" {}
variable "afm_config_details" {}
variable "afm_cluster_instance_names" {}
variable "filesystem_mountpoint" {}