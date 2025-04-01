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

# New Variables
variable "enable_hyperthreading" {
  type        = bool
  default     = true
  description = "Option to enable the Hyperthreading"
}

variable "dynamic_compute_instances" {
  type = list(
    object({
      profile = string
      count   = number
      image   = string
    })
  )
  default = [{
    profile = "cx2-2x4"
    count   = 250
    image   = "ibm-redhat-8-10-minimal-amd64-2"
  }]
  description = "MaxNumber of instances to be launched for compute cluster."
}

variable "compute_subnets_cidr" {
  type        = list(string)
  default     = ["10.10.20.0/24", "10.20.20.0/24", "10.30.20.0/24"]
  description = "Subnet CIDR block to launch the compute cluster host."
}

variable "compute_ssh_keys_ids" {
  type        = list(string)
  default     = null
  description = "The key pair to use to launch the compute host."
}

variable "compute_subnet_crn" {
  type        = string
  default     = null
  description = "ID of an existing VPC in which the cluster resources will be deployed."
}

variable "vcpus" {
  description = "Number of vCPUs"
  type        = number
  default     = null
}

variable "ncores" {
  description = "Number of cores"
  type        = number
  default     = null
}

variable "ncpus" {
  description = "Number of CPUs"
  type        = number
  default     = null
}

variable "mem_in_mb" {
  description = "Memory in MB"
  type        = number
  default     = null
}

variable "rc_max_num" {
  description = "Maximum number of resource instances"
  type        = number
  default     = null
}

variable "rc_profile" {
  description = "Resource profile"
  type        = string
  default     = null
}

variable "image_id" {
  description = "Image ID for the compute instance"
  type        = string
  default     = null
}

variable "compute_subnet_id" {
  description = "Compute subnet ID"
  type        = string
  default     = null
}

variable "region" {
  description = "Deployment region"
  type        = string
  default     = null
}

variable "resource_group_id" {
  description = "Resource group ID"
  type        = string
  default     = null
}

variable "vpc_id" {
  type        = string
  default     = null
  description = "ID of an existing VPC in which the cluster resources will be deployed."
}

variable "ibmcloud_api_key" {
  type        = string
  sensitive   = true
  default     = null
  description = "IBM Cloud API Key that will be used for authentication in scripts run in this module. Only required if certain options are required."
}