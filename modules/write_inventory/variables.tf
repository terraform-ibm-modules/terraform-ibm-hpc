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

variable "Enable_Monitoring" {
  type        = bool
  default     = null
  description = "Option to enable the monitoring"
}

variable "lsf_deployer_hostname" {
  type        = string
  default     = null
  description = "Deployer host name"
}

# variable "enable_hyperthreading" {
#   type        = bool
#   default     = null
#   description = "Enable Hyperthreading"
# }

# variable "ibmcloud_api_key" {
#   type        = string
#   sensitive   = true
#   default     = null
#   description = "IBM Cloud API Key that will be used for authentication in scripts run in this module. Only required if certain options are required."
# }

# variable "vcpus" {
#   type     = number
#   default  = null
# }

# variable "ncores" {
#   type     = number
#   default  = null
# }

# variable "ncpus" {
#   type     = number
#   default  = null
# }

# variable "memInMB" {
#   type     = number
#   default  = null
# }

# variable "rc_maxNum" {
#   type = number
#   default = null
# }

# variable "rc_profile" {
#   type = string
#   default = null
# }

# variable "imageID" {
#   type = string
#   default = null
# }

# variable "compute_subnet_id" {
#   type = string
#   default = null
# }

# variable "region" {
#   type = string
#   default = null
# }

# variable "resource_group_id" {
#   type = string
#   default = null
# }

# variable "zones" {
#   type = string
#   default = null
# }

variable "dns_domain_names" {
  type = object({
    compute  = string
    storage  = string
    protocol = string
  })
  default = {
    compute  = "comp.com"
    storage  = "strg.com"
    protocol = "ces.com"
  }
  description = "IBM Cloud HPC DNS domain names."
}

# variable "compute_ssh_keys_ids" {
#   type        = list(string)
#   default     = [""]
#   description = "List of SSH key IDs for compute instances."
# }

# variable "dynamic_compute_instances" {
#   type = list(
#     object({
#       profile = string
#       count   = number
#       image   = string
#     })
#   )
#   default = [{
#     profile = "cx2-2x4"
#     count   = 1024
#     image   = "ibm-redhat-8-10-minimal-amd64-2"
#   }]
#   description = "MaxNumber of instances to be launched for compute cluster."
# }

# variable "compute_subnets_cidr" {
#   type        = list(string)
#   default     = null
#   description = "List of compute subnet CIDR blocks."
# }

variable "enable_hyperthreading" {
  description = "Enable or disable hyperthreading"
  type        = bool
  default     = null
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

variable "memInMB" {
  description = "Memory in MB"
  type        = number
  default     = null
}

variable "rc_maxNum" {
  description = "Maximum number of resource instances"
  type        = number
  default     = null
}

variable "rc_profile" {
  description = "Resource profile"
  type        = string
  default     = null
}

variable "imageID" {
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

variable "compute_subnets_cidr" {
  description = "List of compute subnets CIDR"
  type        = list(string)
  default     = null
}

variable "dynamic_compute_instances" {
  description = "Dynamic compute instances configuration"
  type        = list(map(any))
  default     = null
}

variable "compute_ssh_keys_ids" {
  description = "List of compute SSH key IDs"
  type        = list(string)
  default     = null
}

# variable "dns_domain_names" {
#   description = "IBM Cloud HPC DNS domain names."
#   type        = map(string)
#   default     = null
# }

variable "ibmcloud_api_key" {
  type        = string
  sensitive   = true
  default     = null
}

variable "zones" {
  description = "List of availability zones"
  type        = list(string)
  default     = null
}