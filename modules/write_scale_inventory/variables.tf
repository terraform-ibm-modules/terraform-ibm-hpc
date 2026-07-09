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
  default     = "lsf"
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
  type        = list(string)
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

variable "bastion_user" {
  type        = string
  default     = "ubuntu"
  description = "Provide the username for Bastion login."
}

variable "bastion_instance_id" {
  type        = string
  default     = null
  description = "Bastion instance id."
}

variable "bastion_instance_public_ip" {
  type        = string
  default     = null
  description = "Bastion instance public ip address."
}

variable "compute_cluster_instance_ids" {
  type        = list(string)
  description = "Compute cluster instance ids."
}

variable "compute_cluster_instance_private_ips" {
  type        = list(string)
  description = "Compute cluster instance private ips."
}

variable "compute_cluster_instance_private_dns_ip_map" {
  type        = map(string)
  description = "Compute cluster instance private DNS and ip map."
}

variable "storage_cluster_filesystem_mountpoint" {
  type        = string
  description = "Storage cluster (owningCluster) Filesystem mount point."
}

variable "storage_cluster_instance_ids" {
  type        = list(string)
  description = "Storage cluster instance ids."
}

variable "storage_cluster_instance_private_ips" {
  type        = list(string)
  description = "Storage cluster instance ips."
}

variable "storage_cluster_with_data_volume_mapping" {
  type        = map(list(string))
  description = "Storage cluster data volume mapping."
}

variable "storage_cluster_instance_private_dns_ip_map" {
  type        = map(string)
  description = "Storage cluster instance private DNS and ip map."
}

variable "storage_cluster_desc_instance_ids" {
  type        = list(string)
  description = "Storage cluster desc instance id."
}

variable "storage_cluster_desc_instance_private_ips" {
  type        = list(string)
  description = "Storage cluster desc instance private ips."
}

variable "storage_cluster_desc_data_volume_mapping" {
  type        = map(list(string))
  description = "Storage cluster desc data volume mapping."
}

variable "storage_cluster_desc_instance_private_dns_ip_map" {
  type        = map(string)
  description = "Storage cluster desc instance private dns ip map."
}

variable "compute_cluster_instance_names" {
  type        = list(string)
  description = "Compute cluster instance names."
}
variable "storage_cluster_instance_names" {
  type        = list(string)
  description = "Storage cluster instance names."
}

variable "storage_subnet_cidr" {
  type        = string
  description = "Storage cluster subnet CIDR block."
}

variable "compute_subnet_cidr" {
  type        = string
  description = "Compute cluster subnet CIDR block."
}

variable "scale_remote_cluster_clustername" {
  type        = string
  description = "Scale remote cluster clustername."
}
variable "protocol_cluster_instance_names" {
  type        = list(string)
  description = "Protocol cluster instance names."
}

variable "client_cluster_instance_names" {
  type        = list(string)
  description = "Client cluster instance names."
}

variable "protocol_cluster_reserved_names" {
  type        = string
  description = "Protocol cluster reserved ips names."
}

variable "smb" {
  type        = bool
  description = "Enable SMB protocol."
}
variable "nfs" {
  type        = bool
  description = "Enable NFS protocol."
}

variable "interface" {
  type        = list(string)
  description = "Interface Name."
}

variable "export_ip_pool" {
  type        = list(string)
  description = "List of export ip pool"
}

variable "filesystem" {
  type        = string
  description = "File system name example: cesSharedRoot"
}

variable "mountpoint" {
  type        = string
  description = "Mount point for NFS protocol"
}

variable "object" {
  type        = string
  description = "object"
}

variable "protocol_gateway_ip" {
  type        = string
  description = "Protocol gateway ip"
}

variable "filesets" {
  type = map(number)
  # type = object({
  #   mount_path = string,
  #   size       = number,
  # })
  description = "filesets"
}

variable "afm_cos_bucket_details" {
  type = list(object({
    akey   = string
    bucket = string
    skey   = string
  }))
  description = "List of AFM COS bucket details"
}

variable "afm_config_details" {
  type = list(object({
    bucket     = string
    endpoint   = string
    fileset    = string
    filesystem = string
    mode       = string
  }))
  description = "List of AFM config details"
}

variable "afm_cluster_instance_names" {
  type        = list(string)
  description = "AFM cluster instance names"
}

variable "filesystem_mountpoint" {
  type        = string
  description = "filesystem mountpoint"
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
