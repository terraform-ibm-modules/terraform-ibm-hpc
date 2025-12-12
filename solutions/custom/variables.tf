##############################################################################
# Offering Variations
##############################################################################
variable "scheduler" {
  type        = string
  default     = "LSF"
  description = "Select one of the scheduler (Scale/LSF/Symphony/Slurm/null)"
}

variable "ibm_customer_number" {
  type        = string
  sensitive   = true
  description = "Comma-separated list of the IBM Customer Number(s) (ICN) that is used for the Bring Your Own License (BYOL) entitlement check. For more information on how to find your ICN, see [What is my IBM Customer Number (ICN)?](https://www.ibm.com/support/pages/what-my-ibm-customer-number-icn)."
  validation {
    condition     = can(regex("^[0-9A-Za-z]*([0-9A-Za-z]+,[0-9A-Za-z]+)*$", var.ibm_customer_number))
    error_message = "The IBM customer number input value cannot have special characters."
  }
}

##############################################################################
# Account Variables
##############################################################################
variable "ibmcloud_api_key" {
  type        = string
  sensitive   = true
  description = "IBM Cloud API Key that will be used for authentication in scripts run in this module. Only required if certain options are required."
}

##############################################################################
# Cluster Level Variables
##############################################################################
variable "zones" {
  description = "Specify the IBM Cloud zone within the chosen region where the IBM Spectrum LSF cluster will be deployed. A single zone input is required, and the management nodes, file storage shares, and compute nodes will all be provisioned in this zone.[Learn more](https://cloud.ibm.com/docs/vpc?topic=vpc-creating-a-vpc-in-a-different-region#get-zones-using-the-cli)."
  type        = list(string)
  default     = ["us-east-1"]
  validation {
    condition     = length(var.zones) == 1
    error_message = "HPC product deployment supports only a single zone. Provide a value for a single zone from the supported regions: eu-de-2 or eu-de-3 for eu-de, us-east-1 or us-east-3 for us-east, and us-south-1 for us-south."
  }
}

variable "ssh_keys" {
  type        = list(string)
  default     = null
  description = "The key pair to use to access the HPC cluster."
}

variable "remote_allowed_ips" {
  type        = list(string)
  description = "Comma-separated list of IP addresses that can access the IBM Spectrum LSF cluster instance through an SSH interface. For security purposes, provide the public IP addresses assigned to the devices that are authorized to establish SSH connections (for example, [\"169.45.117.34\"]). To fetch the IP address of the device, use [https://ipv4.icanhazip.com/](https://ipv4.icanhazip.com/)."
  validation {
    condition = alltrue([
      for o in var.remote_allowed_ips : !contains(["0.0.0.0/0", "0.0.0.0"], o)
    ])
    error_message = "For security, provide the public IP addresses assigned to the devices authorized to establish SSH connections. Use https://ipv4.icanhazip.com/ to fetch the ip address of the device."
  }
  validation {
    condition = alltrue([
      for a in var.remote_allowed_ips : can(regex("^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)(/(3[0-2]|2[0-9]|1[0-9]|[0-9]))?$", a))
    ])
    error_message = "The provided IP address format is not valid. Check if the IP address contains a comma instead of a dot, and ensure there are double quotation marks between each IP address range if using multiple IP ranges. For multiple IP address, use the format [\"169.45.117.34\",\"128.122.144.145\"]."
  }
}

variable "cluster_prefix" {
  type        = string
  default     = "lsf"
  description = "A unique identifier for resources. Must begin with a letter and end with a letter or number. This cluster_prefix will be prepended to any resources provisioned by this template. Prefixes must be 16 or fewer characters."
  validation {
    error_message = "Prefix must begin and end with a letter and contain only letters, numbers, and - characters."
    condition     = can(regex("^([A-z]|[a-z][-a-z0-9]*[a-z0-9])$", var.cluster_prefix))
  }
  validation {
    condition     = length(var.cluster_prefix) <= 16
    error_message = "The cluster_prefix must be 16 characters or fewer."
  }
}

##############################################################################
# Resource Groups Variables
##############################################################################
variable "existing_resource_group" {
  type        = string
  default     = "Default"
  description = "String describing resource groups to create or reference"

}

##############################################################################
# VPC Variables
##############################################################################
variable "vpc_name" {
  type        = string
  default     = null
  description = "Name of an existing VPC in which the cluster resources will be deployed. If no value is given, then a new VPC will be provisioned for the cluster. [Learn more](https://cloud.ibm.com/docs/vpc)"
}

variable "vpc_cidr" {
  type        = string
  default     = "10.241.0.0/18"
  description = "Network CIDR for the VPC. This is used to manage network ACL rules for cluster provisioning."
}

variable "placement_strategy" {
  type        = string
  default     = null
  description = "VPC placement groups to create (null / host_spread / power_spread)"
}

##############################################################################
# Access Variables
##############################################################################

variable "deployer_instance" {
  type = object({
    image   = string
    profile = string
  })
  default = {
    image   = "hpc-lsf-fp15-deployer-rhel810-v1"
    profile = "bx2-8x32"
  }
  description = "Configuration for the deployer node, including the custom image and instance profile. By default, uses fixpack_15 image and a bx2-8x32 profile."
}

# variable "enable_bastion" {
#   type        = bool
#   default     = true
#   description = "The solution supports multiple ways to connect to your HPC cluster for example, using bastion node, via VPN or direct connection. If connecting to the HPC cluster via VPN or direct connection, set this value to false."
# }

variable "vpc_cluster_login_private_subnets_cidr_blocks" {
  type        = string
  default     = "10.241.16.0/28"
  description = "Provide the CIDR block required for the creation of the login cluster's private subnet. Only one CIDR block is needed. If using a hybrid environment, modify the CIDR block to avoid conflicts with any on-premises CIDR blocks. Since the login subnet is used only for the creation of login virtual server instances, provide a CIDR range of /28."
  validation {
    condition     = tonumber(regex("^.*?/(\\d+)$", var.vpc_cluster_login_private_subnets_cidr_blocks)[0]) <= 28
    error_message = "This subnet is used to create only a login virtual server instance. Providing a larger CIDR size will waste the usage of available IPs. A CIDR range of /28 is sufficient for the creation of the login subnet."
  }
}

##############################################################################
# Compute Variables
##############################################################################
variable "client_subnets_cidr" {
  type        = string
  default     = "10.241.50.0/24"
  description = "Subnet CIDR block to launch the client host."
}

variable "client_instances" {
  type = list(
    object({
      profile = string
      count   = number
      image   = string
    })
  )
  default = [{
    profile = "cx2-2x4"
    count   = 2
    image   = "ibm-redhat-8-10-minimal-amd64-2"
  }]
  description = "Number of instances to be launched for client."
}

variable "vpc_cluster_private_subnets_cidr_blocks" {
  type        = string
  default     = "10.241.0.0/20"
  description = "Provide the CIDR block required for the creation of the compute cluster's private subnet. One CIDR block is required. If using a hybrid environment, modify the CIDR block to avoid conflicts with any on-premises CIDR blocks. Ensure the selected CIDR block size can accommodate the maximum number of management and dynamic compute nodes expected in your cluster. For more information on CIDR block size selection, refer to the documentation, see [Choosing IP ranges for your VPC](https://cloud.ibm.com/docs/vpc?topic=vpc-choosing-ip-ranges-for-your-vpc)."
}

variable "management_instances" {
  type = list(
    object({
      profile = string
      count   = number
      image   = string
    })
  )
  default = [{
    profile = "cx2-2x4"
    count   = 2
    image   = "ibm-redhat-8-10-minimal-amd64-2"
  }]
  description = "Number of instances to be launched for management."
}

variable "static_compute_instances" {
  type = list(
    object({
      profile = string
      count   = number
      image   = string
    })
  )
  default = [{
    profile = "cx2-2x4"
    count   = 0
    image   = "ibm-redhat-8-10-minimal-amd64-4"
  }]
  description = "Min Number of instances to be launched for compute cluster."
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
    count   = 1024
    image   = "ibm-redhat-8-10-minimal-amd64-2"
  }]
  description = "MaxNumber of instances to be launched for compute cluster."
}

variable "compute_gui_username" {
  type        = string
  default     = "admin"
  sensitive   = true
  description = "GUI user to perform system management and monitoring tasks on compute cluster."
}

variable "compute_gui_password" {
  type        = string
  default     = "hpc@IBMCloud"
  sensitive   = true
  description = "Password for compute cluster GUI"
}

##############################################################################
# Storage Scale Variables
##############################################################################
variable "storage_subnets_cidr" {
  type        = string
  default     = "10.241.30.0/24"
  description = "Subnet CIDR block to launch the storage cluster host."
}

variable "storage_instances" {
  type = list(
    object({
      profile    = string
      count      = number
      image      = string
      filesystem = optional(string)
    })
  )
  default = [{
    profile    = "bx2-2x8"
    count      = 0
    image      = "ibm-redhat-8-10-minimal-amd64-4"
    filesystem = "/ibm/fs1"
  }]
  description = "Number of instances to be launched for storage cluster."
}

variable "protocol_subnets_cidr" {
  type        = string
  default     = "10.241.40.0/24"
  description = "Subnet CIDR block to launch the storage cluster host."
}

variable "protocol_instances" {
  type = list(
    object({
      profile = string
      count   = number
      image   = string
    })
  )
  default = [{
    profile = "bx2-2x8"
    count   = 2
    image   = "ibm-redhat-8-10-minimal-amd64-2"
  }]
  description = "Number of instances to be launched for protocol hosts."
}

# variable "colocate_protocol_instances" {
#   type        = bool
#   default     = true
#   description = "Enable it to use storage instances as protocol instances"
# }

variable "storage_gui_username" {
  type        = string
  default     = "admin"
  sensitive   = true
  description = "GUI user to perform system management and monitoring tasks on storage cluster."
}

variable "storage_gui_password" {
  type        = string
  default     = "hpc@IBMCloud"
  sensitive   = true
  description = "Password for storage cluster GUI"
}

variable "custom_file_shares" {
  type = list(
    object({
      mount_path = string,
      size       = number,
      iops       = number
    })
  )
  default = [{
    mount_path = "/mnt/binaries"
    size       = 100
    iops       = 1000
    }, {
    mount_path = "/mnt/data"
    size       = 100
    iops       = 1000
  }]
  description = "Custom file shares to access shared storage"
}

##############################################################################
# DNS Variables
##############################################################################

variable "dns_instance_id" {
  type        = string
  default     = null
  description = "IBM Cloud HPC DNS service instance id."
}

variable "dns_custom_resolver_id" {
  type        = string
  default     = null
  description = "IBM Cloud DNS custom resolver id."
}

variable "dns_domain_names" {
  type = object({
    compute  = string
    storage  = string
    protocol = string
    client   = string
    gklm     = string
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

##############################################################################
# Auth Variables
##############################################################################
# variable "enable_ldap" {
#   type        = bool
#   default     = false
#   description = "Set this option to true to enable LDAP for IBM Cloud HPC, with the default value set to false."
# }

# variable "ldap_basedns" {
#   type        = string
#   default     = "ldapscale.com"
#   description = "The dns domain name is used for configuring the LDAP server. If an LDAP server is already in existence, ensure to provide the associated DNS domain name."
# }

# variable "ldap_server" {
#   type        = string
#   default     = null
#   description = "Provide the IP address for the existing LDAP server. If no address is given, a new LDAP server will be created."
# }

# variable "ldap_admin_password" {
#   type        = string
#   sensitive   = true
#   default     = "hpc@IBMCloud"
#   description = "The LDAP administrative password should be 8 to 20 characters long, with a mix of at least three alphabetic characters."
# }

# variable "ldap_user_name" {
#   type        = string
#   default     = "admin"
#   description = "Custom LDAP User for performing cluster operations. Note: Username should be between 4 to 32 characters."
# }

# variable "ldap_user_password" {
#   type        = string
#   sensitive   = true
#   default     = "hpc@IBMCloud"
#   description = "The LDAP user password should be 8 to 20 characters long, with a mix of at least three alphabetic character."
# }

# variable "ldap_ssh_keys" {
#   type        = list(string)
#   default     = null
#   description = "Name of the SSH key configured in your IBM Cloud account that is used to establish a connection to the LDAP Server."
# }

# variable "ldap_instances" {
#   type = list(
#     object({
#       profile = string
#       count   = number
#       image   = string
#     })
#   )
#   default = [{
#     profile = "bx2-2x8"
#     count   = 0
#     image   = "ibm-redhat-8-10-minimal-amd64-2"
#   }]
#   description = "Number of instances to be launched for ldap hosts."
# }

##############################################################################
# Encryption Variables
##############################################################################
variable "key_management" {
  type        = string
  default     = "key_protect"
  description = "Set the value as key_protect to enable customer managed encryption for boot volume and file share. If the key_management is set as null, IBM Cloud resources will be always be encrypted through provider managed."
  validation {
    condition     = var.key_management == "null" || var.key_management == null || var.key_management == "key_protect"
    error_message = "key_management must be either 'null' or 'key_protect'."
  }
}

variable "hpcs_instance_name" {
  type        = string
  default     = null
  description = "Hyper Protect Crypto Service instance"
}

##############################################################################
# Observability Variables
##############################################################################
variable "enable_cos_integration" {
  type        = bool
  default     = true
  description = "Integrate COS with HPC solution"
}

variable "cos_instance_name" {
  type        = string
  default     = null
  description = "Exiting COS instance name"
}

variable "enable_atracker" {
  type        = bool
  default     = true
  description = "Enable Activity tracker"
}

variable "enable_vpc_flow_logs" {
  type        = bool
  default     = true
  description = "Enable Activity tracker"
}

##############################################################################
# LSF specific Variables
##############################################################################
# variable "cluster_name" {
#   type        = string
#   default     = "HPCCluster"
#   description = "Unique ID of the cluster used by LSF for configuration of resources. This can be up to 39 alphanumeric characters."
#   validation {
#     condition     = 0 < length(var.cluster_name) && length(var.cluster_name) < 40 && can(regex("^[a-zA-Z0-9_.-]+$", var.cluster_name))
#     error_message = "The ID can be up to 39 alphanumeric characters including the underscore (_), the hyphen (-), and the period (.) characters."
#   }
# }

# variable "enable_hyperthreading" {
#   type        = bool
#   default     = true
#   description = "Setting this to true will enable hyper-threading in the worker nodes of the cluster (default). Otherwise, hyper-threading will be disabled."
# }

# variable "enable_dedicated_host" {
#   type        = bool
#   default     = false
#   description = "Set to true to use dedicated hosts for compute hosts (default: false)."
# }

# variable "dedicated_host_placement" {
#   type        = string
#   default     = "spread"
#   description = "Specify 'pack' or 'spread'. The 'pack' option will deploy VSIs on one dedicated host until full before moving on to the next dedicated host."
#   validation {
#     condition     = var.dedicated_host_placement == "spread" || var.dedicated_host_placement == "pack"
#     error_message = "Supported values for dedicated_host_placement: spread or pack."
#   }
# }

# variable "enable_app_center" {
#   type        = bool
#   default     = false
#   description = "Set to true to install and enable use of the IBM Spectrum LSF Application Center GUI."
# }

# variable "app_center_gui_password" {
#   type        = string
#   default     = "hpc@IBMCloud"
#   sensitive   = true
#   description = "Password for IBM Spectrum LSF Application Center GUI."
# }

# variable "app_center_db_password" {
#   type        = string
#   default     = "hpc@IBMCloud"
#   sensitive   = true
#   description = "Password for IBM Spectrum LSF Application Center database GUI."
# }

##############################################################################
# Symphony specific Variables
##############################################################################

##############################################################################
# Slurm  specific Variables
##############################################################################

##############################################################################
# Landing Zone Variables
##############################################################################
# variable "clusters" {
#   default     = null
#   description = "A list describing clusters workloads to create"
#   type = list(
#     object({
#       name                                  = string           # Name of Cluster
#       vpc_name                              = string           # Name of VPC
#       subnet_names                          = list(string)     # List of vpc subnets for cluster
#       workers_per_subnet                    = number           # Worker nodes per subnet.
#       machine_type                          = string           # Worker node flavor
#       kube_type                             = string           # iks or openshift
#       kube_version                          = optional(string) # Can be a version from `ibmcloud ks versions` or `default`
#       entitlement                           = optional(string) # entitlement option for openshift
#       secondary_storage                     = optional(string) # Secondary storage type
#       pod_subnet                            = optional(string) # Portable subnet for pods
#       service_subnet                        = optional(string) # Portable subnet for services
#       existing_resource_group                        = string           # Resource Group used for cluster
#       cos_name                              = optional(string) # Name of COS instance Required only for OpenShift clusters
#       access_tags                           = optional(list(string), [])
#       boot_volume_crk_name                  = optional(string)      # Boot volume encryption key name
#       disable_public_endpoint               = optional(bool, true)  # disable cluster public, leaving only private endpoint
#       disable_outbound_traffic_protection   = optional(bool, false) # public outbound access from the cluster workers
#       cluster_force_delete_storage          = optional(bool, false) # force the removal of baremetal storage associated with the cluster during cluster deletion
#       operating_system                      = string                # The operating system of the workers in the default worker pool. See https://cloud.ibm.com/docs/openshift?topic=openshift-openshift_versions#openshift_versions_available .
#       kms_wait_for_apply                    = optional(bool, true)  # make terraform wait until KMS is applied to master and it is ready and deployed
#       verify_cluster_network_readiness      = optional(bool, true)  # Flag to run a script will run kubectl commands to verify that all worker nodes can communicate successfully with the master. If the runtime does not have access to the kube cluster to run kubectl commands, this should be set to false.
#       use_ibm_cloud_private_api_endpoints   = optional(bool, true)  # Flag to force all cluster related api calls to use the IBM Cloud private endpoints.
#       import_default_worker_pool_on_create  = optional(bool)        # (Advanced users) Whether to handle the default worker pool as a stand-alone ibm_container_vpc_worker_pool resource on cluster creation. Only set to false if you understand the implications of managing the default worker pool as part of the cluster resource. Set to true to import the default worker pool as a separate resource. Set to false to manage the default worker pool as part of the cluster resource.
#       allow_default_worker_pool_replacement = optional(bool)        # (Advanced users) Set to true to allow the module to recreate a default worker pool. Only use in the case where you are getting an error indicating that the default worker pool cannot be replaced on apply. Once the default worker pool is handled as a stand-alone ibm_container_vpc_worker_pool, if you wish to make any change to the default worker pool which requires the re-creation of the default pool set this variable to true
#       labels                                = optional(map(string)) # A list of labels that you want to add to the default worker pool.
#       addons = optional(object({                                    # Map of OCP cluster add-on versions to install
#         debug-tool                = optional(string)
#         image-key-synchronizer    = optional(string)
#         openshift-data-foundation = optional(string)
#         vpc-file-csi-driver       = optional(string)
#         static-route              = optional(string)
#         cluster-autoscaler        = optional(string)
#         vpc-block-csi-driver      = optional(string)
#         ibm-storage-operator      = optional(string)
#       }), {})
#       manage_all_addons = optional(bool, false) # Instructs Terraform to manage all cluster addons, even if addons were installed outside of the module. If set to 'true' this module will destroy any addons that were installed by other sources.
#       kms_config = optional(
#         object({
#           crk_name         = string         # Name of key
#           private_endpoint = optional(bool) # Private endpoint
#         })
#       )
#       worker_pools = optional(
#         list(
#           object({
#             name                 = string                # Worker pool name
#             vpc_name             = string                # VPC name
#             workers_per_subnet   = number                # Worker nodes per subnet
#             flavor               = string                # Worker node flavor
#             subnet_names         = list(string)          # List of vpc subnets for worker pool
#             entitlement          = optional(string)      # entitlement option for openshift
#             secondary_storage    = optional(string)      # Secondary storage type
#             boot_volume_crk_name = optional(string)      # Boot volume encryption key name
#             operating_system     = string                # The operating system of the workers in the worker pool. See https://cloud.ibm.com/docs/openshift?topic=openshift-openshift_versions#openshift_versions_available .
#             labels               = optional(map(string)) # A list of labels that you want to add to all the worker nodes in the worker pool.
#           })
#         )
#       )
#     })
#   )
# }

##############################################################################
# Terraform generic Variables
##############################################################################
# tflint-ignore: all
# variable "TF_PARALLELISM" {
#   type        = string
#   default     = "250"
#   description = "Limit the number of concurrent operation."
# }

# tflint-ignore: all
# variable "TF_VERSION" {
#   type        = string
#   default     = "1.9"
#   description = "The version of the Terraform engine that's used in the Schematics workspace."
# }

# tflint-ignore: all
# variable "TF_LOG" {
#   type        = string
#   default     = "ERROR"
#   description = "The Terraform log level used for output in the Schematics workspace."
# }

##############################################################################
# Override JSON
##############################################################################
variable "override" {
  type        = bool
  default     = false
  description = "Override default values with custom JSON template. This uses the file `override.json` to allow users to create a fully customized environment."

}

variable "override_json_string" {
  type        = string
  default     = null
  description = "Override default values with a JSON object. Any JSON other than an empty string overrides other configuration changes."
}
