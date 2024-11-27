##############################################################################
# Offering Variations
##############################################################################
variable "scheduler" {
  type        = string
  default     = "LSF"
  description = "Select one of the scheduler (LSF/Symphony/Slurm/null)"
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
  type        = list(string)
  description = "Region where VPC will be created. To find your VPC region, use `ibmcloud is regions` command to find available regions."
}

variable "ssh_keys" {
  type        = list(string)
  default     = null
  description = "The key pair to use to access the HPC cluster."
}

variable "allowed_cidr" {
  type        = list(string)
  description = "Network CIDR to access the VPC. This is used to manage network ACL rules for accessing the cluster."
}

variable "prefix" {
  type        = string
  default     = "lsf"
  description = "A unique identifier for resources. Must begin with a letter and end with a letter or number. This prefix will be prepended to any resources provisioned by this template. Prefixes must be 16 or fewer characters."
  validation {
    error_message = "Prefix must begin and end with a letter and contain only letters, numbers, and - characters."
    condition     = can(regex("^([A-z]|[a-z][-a-z0-9]*[a-z0-9])$", var.prefix))
  }
}

##############################################################################
# Resource Groups Variables
##############################################################################
variable "resource_group" {
  type        = string
  default     = "Default"
  description = "String describing resource groups to create or reference"

}

##############################################################################
# VPC Variables
##############################################################################
variable "vpc" {
  type        = string
  default     = null
  description = "Name of an existing VPC in which the cluster resources will be deployed. If no value is given, then a new VPC will be provisioned for the cluster. [Learn more](https://cloud.ibm.com/docs/vpc)"
}

variable "network_cidr" {
  type        = string
  default     = "10.0.0.0/8"
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
variable "enable_deployer" {
  type        = bool
  default     = false
  description = "Deployer should be only used for better deployment performance"
}

variable "deployer_instance_profile" {
  type        = string
  default     = "mx2-4x32"
  description = "Deployer should be only used for better deployment performance"
}

variable "enable_bastion" {
  type        = bool
  default     = true
  description = "The solution supports multiple ways to connect to your HPC cluster for example, using bastion node, via VPN or direct connection. If connecting to the HPC cluster via VPN or direct connection, set this value to false."
}

variable "bastion_ssh_keys" {
  type        = list(string)
  default     = null
  description = "The key pair to use to access the bastion host."
}

variable "bastion_subnets_cidr" {
  type        = list(string)
  default     = ["10.0.0.0/24"]
  description = "Subnet CIDR block to launch the bastion host."
}

variable "enable_vpn" {
  type        = bool
  default     = false
  description = "The solution supports multiple ways to connect to your HPC cluster for example, using bastion node, via VPN or direct connection. If connecting to the HPC cluster via VPN, set this value to true."
}

variable "vpn_peer_cidr" {
  type        = list(string)
  default     = null
  description = "The peer CIDRs (e.g., 192.168.0.0/24) to which the VPN will be connected."
}

variable "vpn_peer_address" {
  type        = string
  default     = null
  description = "The peer public IP address to which the VPN will be connected."
}

variable "vpn_preshared_key" {
  type        = string
  default     = null
  description = "The pre-shared key for the VPN."
}

##############################################################################
# Compute Variables
##############################################################################
variable "client_subnets_cidr" {
  type        = list(string)
  default     = ["10.10.10.0/24", "10.20.10.0/24", "10.30.10.0/24"]
  description = "Subnet CIDR block to launch the client host."
}

variable "client_ssh_keys" {
  type        = list(string)
  default     = null
  description = "The key pair to use to launch the client host."
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

variable "compute_subnets_cidr" {
  type        = list(string)
  default     = ["10.10.20.0/24", "10.20.20.0/24", "10.30.20.0/24"]
  description = "Subnet CIDR block to launch the compute cluster host."
}

variable "compute_ssh_keys" {
  type        = list(string)
  default     = null
  description = "The key pair to use to launch the compute host."
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
    count   = 1
    image   = "ibm-redhat-8-10-minimal-amd64-2"
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
  type        = list(string)
  default     = ["10.10.30.0/24", "10.20.30.0/24", "10.30.30.0/24"]
  description = "Subnet CIDR block to launch the storage cluster host."
}

variable "storage_ssh_keys" {
  type        = list(string)
  default     = null
  description = "The key pair to use to launch the storage cluster host."
}

variable "storage_instances" {
  type = list(
    object({
      profile         = string
      count           = number
      image           = string
      filesystem_name = optional(string)
    })
  )
  default = [{
    profile         = "bx2-2x8"
    count           = 2
    image           = "ibm-redhat-8-10-minimal-amd64-2"
    filesystem_name = "fs1"
  }]
  description = "Number of instances to be launched for storage cluster."
}

variable "protocol_subnets_cidr" {
  type        = list(string)
  default     = ["10.10.40.0/24", "10.20.40.0/24", "10.30.40.0/24"]
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

variable "colocate_protocol_instances" {
  type        = bool
  default     = true
  description = "Enable it to use storage instances as protocol instances"
}

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

variable "nsd_details" {
  type = list(
    object({
      profile  = string
      capacity = optional(number)
      iops     = optional(number)
    })
  )
  default = [{
    capacity = 100
    iops     = 1000
    profile  = "custom"
  }]
  description = "Storage scale NSD details"
}

variable "file_shares" {
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
  })
  default = {
    compute  = "comp.com"
    storage  = "strg.com"
    protocol = "ces.com"
  }
  description = "IBM Cloud HPC DNS domain names."
}

##############################################################################
# Auth Variables
##############################################################################
variable "enable_ldap" {
  type        = bool
  default     = false
  description = "Set this option to true to enable LDAP for IBM Cloud HPC, with the default value set to false."
}

variable "ldap_basedns" {
  type        = string
  default     = "ldapscale.com"
  description = "The dns domain name is used for configuring the LDAP server. If an LDAP server is already in existence, ensure to provide the associated DNS domain name."
}

variable "ldap_server" {
  type        = string
  default     = null
  description = "Provide the IP address for the existing LDAP server. If no address is given, a new LDAP server will be created."
}

variable "ldap_admin_password" {
  type        = string
  sensitive   = true
  default     = "hpc@IBMCloud"
  description = "The LDAP administrative password should be 8 to 20 characters long, with a mix of at least three alphabetic characters."
}

variable "ldap_user_name" {
  type        = string
  default     = "admin"
  description = "Custom LDAP User for performing cluster operations. Note: Username should be between 4 to 32 characters."
}

variable "ldap_user_password" {
  type        = string
  sensitive   = true
  default     = "hpc@IBMCloud"
  description = "The LDAP user password should be 8 to 20 characters long, with a mix of at least three alphabetic character."
}

variable "ldap_ssh_keys" {
  type        = list(string)
  default     = null
  description = "Name of the SSH key configured in your IBM Cloud account that is used to establish a connection to the LDAP Server."
}

variable "ldap_instances" {
  type = list(
    object({
      profile = string
      count   = number
      image   = string
    })
  )
  default = [{
    profile = "bx2-2x8"
    count   = 0
    image   = "ibm-redhat-8-10-minimal-amd64-2"
  }]
  description = "Number of instances to be launched for ldap hosts."
}

##############################################################################
# Encryption Variables
##############################################################################
variable "key_management" {
  type        = string
  default     = "key_protect"
  description = "null/key_protect/hs_crypto"
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
# Scale specific Variables
##############################################################################
variable "filesystem_config" {
  type = list(object({
    filesystem               = string
    block_size               = string
    default_data_replica     = number
    default_metadata_replica = number
    max_data_replica         = number
    max_metadata_replica     = number
    mount_point              = string
  }))
  default     = null
  description = "File system configurations."
}

variable "filesets_config" {
  type = list(object({
    fileset           = string
    filesystem        = string
    junction_path     = string
    client_mount_path = string
    quota             = number
  }))
  default     = null
  description = "Fileset configurations."
}

variable "afm_instances" {
  type = list(
    object({
      profile = string
      count   = number
      image   = string
    })
  )
  default = [{
    profile = "bx2-2x8"
    count   = 0
    image   = "ibm-redhat-8-10-minimal-amd64-2"
  }]
  description = "Number of instances to be launched for afm hosts."
}

variable "afm_cos_config" {
  type = list(object({
    afm_fileset          = string,
    mode                 = string,
    cos_instance         = string,
    bucket_name          = string,
    bucket_region        = string,
    cos_service_cred_key = string,
    bucket_type          = string,
    bucket_storage_class = string
  }))
  default     = null
  description = "AFM configurations."
}

##############################################################################
# LSF specific Variables
##############################################################################
variable "cluster_id" {
  type        = string
  default     = "HPCCluster"
  description = "Unique ID of the cluster used by LSF for configuration of resources. This can be up to 39 alphanumeric characters."
  validation {
    condition     = 0 < length(var.cluster_id) && length(var.cluster_id) < 40 && can(regex("^[a-zA-Z0-9_.-]+$", var.cluster_id))
    error_message = "The ID can be up to 39 alphanumeric characters including the underscore (_), the hyphen (-), and the period (.) characters."
  }
}

variable "enable_hyperthreading" {
  type        = bool
  default     = true
  description = "Setting this to true will enable hyper-threading in the worker nodes of the cluster (default). Otherwise, hyper-threading will be disabled."
}

variable "enable_dedicated_host" {
  type        = bool
  default     = false
  description = "Set to true to use dedicated hosts for compute hosts (default: false)."
}

variable "dedicated_host_placement" {
  type        = string
  default     = "spread"
  description = "Specify 'pack' or 'spread'. The 'pack' option will deploy VSIs on one dedicated host until full before moving on to the next dedicated host."
  validation {
    condition     = var.dedicated_host_placement == "spread" || var.dedicated_host_placement == "pack"
    error_message = "Supported values for dedicated_host_placement: spread or pack."
  }
}

variable "enable_app_center" {
  type        = bool
  default     = false
  description = "Set to true to install and enable use of the IBM Spectrum LSF Application Center GUI."
}

variable "app_center_gui_password" {
  type        = string
  default     = "hpc@IBMCloud"
  sensitive   = true
  description = "Password for IBM Spectrum LSF Application Center GUI."
}

variable "app_center_db_password" {
  type        = string
  default     = "hpc@IBMCloud"
  sensitive   = true
  description = "Password for IBM Spectrum LSF Application Center database GUI."
}

##############################################################################
# Symphony specific Variables
##############################################################################

##############################################################################
# Slurm  specific Variables
##############################################################################

##############################################################################
# Landing Zone Variables
##############################################################################
variable "clusters" {
  default     = null
  description = "A list describing clusters workloads to create"
  type = list(
    object({
      name                                  = string           # Name of Cluster
      vpc_name                              = string           # Name of VPC
      subnet_names                          = list(string)     # List of vpc subnets for cluster
      workers_per_subnet                    = number           # Worker nodes per subnet.
      machine_type                          = string           # Worker node flavor
      kube_type                             = string           # iks or openshift
      kube_version                          = optional(string) # Can be a version from `ibmcloud ks versions` or `default`
      entitlement                           = optional(string) # entitlement option for openshift
      secondary_storage                     = optional(string) # Secondary storage type
      pod_subnet                            = optional(string) # Portable subnet for pods
      service_subnet                        = optional(string) # Portable subnet for services
      resource_group                        = string           # Resource Group used for cluster
      cos_name                              = optional(string) # Name of COS instance Required only for OpenShift clusters
      access_tags                           = optional(list(string), [])
      boot_volume_crk_name                  = optional(string)      # Boot volume encryption key name
      disable_public_endpoint               = optional(bool, true)  # disable cluster public, leaving only private endpoint
      disable_outbound_traffic_protection   = optional(bool, false) # public outbound access from the cluster workers
      cluster_force_delete_storage          = optional(bool, false) # force the removal of persistent storage associated with the cluster during cluster deletion
      operating_system                      = string                # The operating system of the workers in the default worker pool. See https://cloud.ibm.com/docs/openshift?topic=openshift-openshift_versions#openshift_versions_available .
      kms_wait_for_apply                    = optional(bool, true)  # make terraform wait until KMS is applied to master and it is ready and deployed
      verify_cluster_network_readiness      = optional(bool, true)  # Flag to run a script will run kubectl commands to verify that all worker nodes can communicate successfully with the master. If the runtime does not have access to the kube cluster to run kubectl commands, this should be set to false.
      use_ibm_cloud_private_api_endpoints   = optional(bool, true)  # Flag to force all cluster related api calls to use the IBM Cloud private endpoints.
      import_default_worker_pool_on_create  = optional(bool)        # (Advanced users) Whether to handle the default worker pool as a stand-alone ibm_container_vpc_worker_pool resource on cluster creation. Only set to false if you understand the implications of managing the default worker pool as part of the cluster resource. Set to true to import the default worker pool as a separate resource. Set to false to manage the default worker pool as part of the cluster resource.
      allow_default_worker_pool_replacement = optional(bool)        # (Advanced users) Set to true to allow the module to recreate a default worker pool. Only use in the case where you are getting an error indicating that the default worker pool cannot be replaced on apply. Once the default worker pool is handled as a stand-alone ibm_container_vpc_worker_pool, if you wish to make any change to the default worker pool which requires the re-creation of the default pool set this variable to true
      labels                                = optional(map(string)) # A list of labels that you want to add to the default worker pool.
      addons = optional(object({                                    # Map of OCP cluster add-on versions to install
        debug-tool                = optional(string)
        image-key-synchronizer    = optional(string)
        openshift-data-foundation = optional(string)
        vpc-file-csi-driver       = optional(string)
        static-route              = optional(string)
        cluster-autoscaler        = optional(string)
        vpc-block-csi-driver      = optional(string)
        ibm-storage-operator      = optional(string)
      }), {})
      manage_all_addons = optional(bool, false) # Instructs Terraform to manage all cluster addons, even if addons were installed outside of the module. If set to 'true' this module will destroy any addons that were installed by other sources.
      kms_config = optional(
        object({
          crk_name         = string         # Name of key
          private_endpoint = optional(bool) # Private endpoint
        })
      )
      worker_pools = optional(
        list(
          object({
            name                 = string                # Worker pool name
            vpc_name             = string                # VPC name
            workers_per_subnet   = number                # Worker nodes per subnet
            flavor               = string                # Worker node flavor
            subnet_names         = list(string)          # List of vpc subnets for worker pool
            entitlement          = optional(string)      # entitlement option for openshift
            secondary_storage    = optional(string)      # Secondary storage type
            boot_volume_crk_name = optional(string)      # Boot volume encryption key name
            operating_system     = string                # The operating system of the workers in the worker pool. See https://cloud.ibm.com/docs/openshift?topic=openshift-openshift_versions#openshift_versions_available .
            labels               = optional(map(string)) # A list of labels that you want to add to all the worker nodes in the worker pool.
          })
        )
      )
    })
  )
}

##############################################################################
# Terraform generic Variables
##############################################################################
variable "TF_PARALLELISM" {
  type        = string
  default     = "250"
  description = "Limit the number of concurrent operation."
}

variable "TF_VERSION" {
  type        = string
  default     = "1.9"
  description = "The version of the Terraform engine that's used in the Schematics workspace."
}

variable "TF_LOG" {
  type        = string
  default     = "ERROR"
  description = "The Terraform log level used for output in the Schematics workspace."
}

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
