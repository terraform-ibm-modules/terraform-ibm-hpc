##############################################################################
# Account Variables
##############################################################################

variable "enable_landing_zone" {
  type        = bool
  default     = true
  description = "Run landing zone module."
}

##############################################################################
# Resource Groups Variables
##############################################################################

variable "resource_group" {
  description = "String describing resource groups to create or reference"
  type        = string
  default     = null
}

##############################################################################
# Module Level Variables
##############################################################################

variable "prefix" {
  description = "A unique identifier for resources. Must begin with a letter and end with a letter or number. This prefix will be prepended to any resources provisioned by this template. Prefixes must be 16 or fewer characters."
  type        = string

  validation {
    error_message = "Prefix must begin and end with a letter and contain only letters, numbers, and - characters."
    condition     = can(regex("^([A-z]|[a-z][-a-z0-9]*[a-z0-9])$", var.prefix))
  }
}

variable "zones" {
  description = "Region where VPC will be created. To find your VPC region, use `ibmcloud is regions` command to find available regions."
  type        = list(string)
}

##############################################################################
# VPC Variables
##############################################################################

variable "vpc" {
  type        = string
  description = "Name of an existing VPC in which the cluster resources will be deployed. If no value is given, then a new VPC will be provisioned for the cluster. [Learn more](https://cloud.ibm.com/docs/vpc)"
  default     = null
}

variable "network_cidr" {
  description = "Network CIDR for the VPC. This is used to manage network ACL rules for cluster provisioning."
  type        = string
  default     = "10.0.0.0/8"
}

variable "placement_strategy" {
  type        = string
  default     = null
  description = "VPC placement groups to create (null / host_spread / power_spread)"
}

variable "ssh_keys" {
  type        = list(string)
  description = "The key pair to use to access the servers."
}

##############################################################################
# Access Variables
##############################################################################


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

variable "allowed_cidr" {
  description = "Network CIDR to access the VPC. This is used to manage network ACL rules for accessing the cluster."
  type        = list(string)
  default     = ["10.0.0.0/8"]
}

##############################################################################
# Compute Variables
##############################################################################
variable "client_subnets_cidr" {
  type        = list(string)
  default     = ["10.10.10.0/24", "10.20.10.0/24", "10.30.10.0/24"]
  description = "Subnet CIDR block to launch the client host."
}

variable "client_instances" {
  type = list(
    object({
      profile = string
      count   = number
    })
  )
  default = [{
    profile = "cx2-2x4"
    count   = 1
  }]
  description = "Number of instances to be launched for client."
}

variable "compute_subnets_cidr" {
  type        = list(string)
  default     = ["10.10.20.0/24", "10.20.20.0/24", "10.30.20.0/24"]
  description = "Subnet CIDR block to launch the compute cluster host."
}

variable "management_instances" {
  type = list(
    object({
      profile = string
      count   = number
    })
  )
  default = [{
    profile = "cx2-2x4"
    count   = 3
  }]
  description = "Number of instances to be launched for management."
}

variable "compute_instances" {
  type = list(
    object({
      profile = string
      count   = number
    })
  )
  default = [{
    profile = "cx2-2x4"
    count   = 0
  }]
  description = "Min Number of instances to be launched for compute cluster."
}

##############################################################################
# Scale Storage Variables
##############################################################################

variable "storage_subnets_cidr" {
  type        = list(string)
  default     = ["10.10.30.0/24", "10.20.30.0/24", "10.30.30.0/24"]
  description = "Subnet CIDR block to launch the storage cluster host."
}

variable "storage_instances" {
  type = list(
    object({
      profile = string
      count   = number
    })
  )
  default = [{
    profile = "bx2-2x8"
    count   = 3
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
    })
  )
  default = [{
    profile = "bx2-2x8"
    count   = 2
  }]
  description = "Number of instances to be launched for protocol hosts."
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
# Encryption Variables
##############################################################################

variable "key_management" {
  type        = string
  default     = null
  description = "null/key_protect/hs_crypto"
}

variable "hpcs_instance_name" {
  type        = string
  default     = null
  description = "Hyper Protect Crypto Service instance"
}

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
