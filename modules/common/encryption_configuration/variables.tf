variable "turn_on" {}
variable "clone_path" {}
variable "create_scale_cluster" {}
variable "meta_private_key" {}
variable "scale_cluster_clustername" {}
variable "scale_encryption_servers" {}
variable "scale_encryption_servers_dns" {}
variable "scale_encryption_admin_default_password" {}
variable "scale_encryption_admin_password" {}
variable "scale_encryption_admin_username" {}
variable "scale_encryption_type" {}
variable "compute_cluster_create_complete" {}
variable "storage_cluster_create_complete" {}
variable "remote_mount_create_complete" {}
variable "compute_cluster_encryption" {}
variable "storage_cluster_encryption" {}

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
