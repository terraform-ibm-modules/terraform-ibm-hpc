##############################################################################
# Account Variables
##############################################################################
variable "ibmcloud_api_key" {
  type        = string
  sensitive   = true
  default     = null
  description = "IBM Cloud API Key that will be used for authentication in scripts run in this module. Only required if certain options are required."
}

variable "lsf_version" {
  type        = string
  default     = "fixpack_15"
  description = "Select the desired version of IBM Spectrum LSF to deploy either fixpack_15 or fixpack_14. By default, the solution uses the latest available version, which is Fix Pack 15. If you need to deploy an earlier version such as Fix Pack 14, update the lsf_version field to fixpack_14. When changing the LSF version, ensure that all custom images used for management, compute, and login nodes correspond to the same version. This is essential to maintain compatibility across the cluster and to prevent deployment issues."
}

##############################################################################
# Offering Variations
##############################################################################
variable "scheduler" {
  type        = string
  default     = null
  description = "Select one of the scheduler (Scale/LSF/Symphony/Slurm/null)"
}

variable "ibm_customer_number" {
  type        = string
  sensitive   = true
  default     = null
  description = "Comma-separated list of the IBM Customer Number(s) (ICN) that is used for the Bring Your Own License (BYOL) entitlement check. For more information on how to find your ICN, see [What is my IBM Customer Number (ICN)?](https://www.ibm.com/support/pages/what-my-ibm-customer-number-icn)."
}

##############################################################################
# Cluster Level Variables
##############################################################################
variable "cluster_prefix" {
  type        = string
  default     = "lsf"
  description = "A unique identifier for resources. Must begin with a letter and end with a letter or number. This cluster_prefix will be prepended to any resources provisioned by this template. Prefixes must be 16 or fewer characters."
  validation {
    error_message = "cluster_prefix must begin and end with a letter and contain only letters, numbers, and - characters."
    condition     = can(regex("^([A-z]|[a-z][-a-z0-9]*[a-z0-9])$", var.cluster_prefix))
  }
  validation {
    condition     = length(var.cluster_prefix) <= 16
    error_message = "The cluster_prefix must be 16 characters or fewer."
  }
}

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
variable "bastion_instance" {
  type = object({
    image   = string
    profile = string
  })
  default = {
    image   = "ibm-ubuntu-22-04-3-minimal-amd64-1"
    profile = "cx2-4x8"
  }
  description = "Configuration for the Bastion node, including the image and instance profile. Only Ubuntu stock images are supported."
}

variable "login_subnet_id" {
  type        = string
  default     = null
  description = "Name of an existing subnets in which the cluster resources will be deployed. If no value is given, then new subnet(s) will be provisioned for the cluster. [Learn more](https://cloud.ibm.com/docs/vpc)"
}

variable "vpc_cluster_login_private_subnets_cidr_blocks" {
  type        = string
  default     = "10.241.16.0/28"
  description = "Provide the CIDR block required for the creation of the login cluster's private subnet. Only one CIDR block is needed. If using a hybrid environment, modify the CIDR block to avoid conflicts with any on-premises CIDR blocks. Since the login subnet is used only for the creation of login virtual server instances, provide a CIDR range of /28."
  validation {
    condition = can(
      regex(
        "^((25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])\\.){3}(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])/(2[8-9]|3[0-2])$", trimspace(var.vpc_cluster_login_private_subnets_cidr_blocks)
      )
    )
    error_message = "This subnet is used to create only a login virtual server instance. Providing a larger CIDR size will waste the usage of available IPs. A CIDR range of /28 is sufficient for the creation of the login subnet."
  }
}

##############################################################################
# Deployer Variables
##############################################################################
variable "enable_deployer" {
  type        = bool
  default     = true
  description = "Deployer should be only used for better deployment performance"
}

variable "deployer_instance" {
  type = object({
    image   = string
    profile = string
  })
  default = {
    image   = "ibm-redhat-8-10-minimal-amd64-10"
    profile = "bx2-8x32"
  }
  description = "Configuration for the deployer node, including the custom image and instance profile. By default, uses fixpack_15 image and a bx2-8x32 profile."
}

##############################################################################
# Compute Variables
##############################################################################
variable "client_subnet_id" {
  type        = string
  default     = null
  description = "Name of an existing subnets in which the cluster resources will be deployed. If no value is given, then new subnet(s) will be provisioned for the cluster. [Learn more](https://cloud.ibm.com/docs/vpc)"
}

variable "client_subnets_cidr" {
  type        = list(string)
  default     = ["10.241.50.0/24"]
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
    count   = 0
    image   = "ibm-redhat-8-10-minimal-amd64-6"
  }]
  description = "Number of instances to be launched for client."
}

variable "compute_subnet_id" {
  type        = string
  default     = null
  description = "Name of an existing subnets in which the cluster resources will be deployed. If no value is given, then new subnet(s) will be provisioned for the cluster. [Learn more](https://cloud.ibm.com/docs/vpc)"
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
    count   = 0
    image   = "ibm-redhat-8-10-minimal-amd64-10"
  }]
  description = "Number of instances to be launched for management."
}

variable "static_compute_instances" {
  type = list(
    object({
      profile    = string
      count      = number
      image      = string
      filesystem = optional(string)
    })
  )
  default = [{
    profile    = "cx2-2x4"
    count      = 0
    image      = "ibm-redhat-8-10-minimal-amd64-10"
    filesystem = "/ibm/fs1"
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
    count   = 500
    image   = "ibm-redhat-8-10-minimal-amd64-10"
  }]
  description = "MaxNumber of instances to be launched for compute cluster."
}

variable "compute_gui_username" {
  type        = string
  default     = ""
  sensitive   = true
  description = "GUI user to perform system management and monitoring tasks on compute cluster."
}

variable "compute_gui_password" {
  type        = string
  default     = ""
  sensitive   = true
  description = "Password for compute cluster GUI"
}

##############################################################################
# Storage Variables
##############################################################################
variable "storage_subnet_id" {
  type        = string
  default     = null
  description = "Name of an existing subnets in which the cluster resources will be deployed. If no value is given, then new subnet(s) will be provisioned for the cluster. [Learn more](https://cloud.ibm.com/docs/vpc)"
}

variable "storage_subnets_cidr" {
  type        = list(string)
  default     = ["10.241.30.0/24"]
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
    profile    = "bx2d-32x128"
    count      = 0
    image      = "ibm-redhat-8-10-minimal-amd64-10"
    filesystem = "/ibm/fs1"
  }]
  description = "Number of instances to be launched for storage cluster."
}

variable "storage_servers" {
  type = list(
    object({
      profile    = string
      count      = number
      image      = string
      filesystem = optional(string)
    })
  )
  default = [{
    profile    = "cx2d-metal-96x192"
    count      = 0
    image      = "ibm-redhat-8-10-minimal-amd64-10"
    filesystem = "/ibm/fs1"
  }]
  description = "Number of BareMetal Servers to be launched for storage cluster."
}

variable "tie_breaker_bm_server_profile" {
  type        = string
  default     = null
  description = "Specify the bare metal server profile type name to be used for creating the bare metal Tie breaker node. If no value is provided, the storage bare metal server profile will be used as the default. For more information, see [bare metal server profiles](https://cloud.ibm.com/docs/vpc?topic=vpc-bare-metal-servers-profile&interface=ui). [Tie Breaker Node](https://www.ibm.com/docs/en/storage-scale/5.2.2?topic=quorum-node-tiebreaker-disks)"
}

variable "scale_management_vsi_profile" {
  type        = string
  default     = "bx2-8x32"
  description = "The virtual server instance profile type name to be used to create the Management node. For more information, see [Instance Profiles](https://cloud.ibm.com/docs/vpc?topic=vpc-profiles&interface=ui)."
}

variable "protocol_subnet_id" {
  type        = string
  default     = null
  description = "Name of an existing subnets in which the cluster resources will be deployed. If no value is given, then new subnet(s) will be provisioned for the cluster. [Learn more](https://cloud.ibm.com/docs/vpc)"
}

variable "protocol_subnets_cidr" {
  type        = list(string)
  default     = ["10.241.40.0/24"]
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
    count   = 0
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
  default     = ""
  sensitive   = true
  description = "GUI user to perform system management and monitoring tasks on storage cluster."
}

variable "storage_gui_password" {
  type        = string
  default     = ""
  sensitive   = true
  description = "Password for storage cluster GUI"
}

variable "storage_security_group_id" {
  type        = string
  default     = null
  description = "Provide the storage security group ID from the Spectrum Scale storage cluster if the mount_path in the cluster_file_share variable is set to use Scale fileset mount points. This security group is essential for establishing connections between the Spectrum LSF cluster nodes and NFS mount points, ensuring the nodes can access the specified mount points."
}

variable "custom_file_shares" {
  type = list(object({
    mount_path = string,
    size       = optional(number),
    iops       = optional(number),
    nfs_share  = optional(string)
  }))
  default     = [{ mount_path = "/mnt/vpcstorage/tools", size = 100, iops = 2000 }, { mount_path = "/mnt/vpcstorage/data", size = 100, iops = 6000 }, { mount_path = "/mnt/scale/tools", nfs_share = "" }]
  description = "Provide details for customizing your shared file storage layout, including mount points, sizes (in GB), and IOPS ranges for up to five file shares if using VPC file storage as the storage option.If using IBM Storage Scale as an NFS mount, update the appropriate mount path and nfs_share values created from the Storage Scale cluster. Note that VPC file storage supports attachment to a maximum of 256 nodes. Exceeding this limit may result in mount point failures due to attachment restrictions.For more information, see [Storage options](https://test.cloud.ibm.com/docs/hpc-ibm-spectrumlsf?topic=hpc-ibm-spectrumlsf-integrating-scale#integrate-scale-and-hpc)."
  validation {
    condition     = length([for item in var.custom_file_shares : item if item.nfs_share == null]) <= 5
    error_message = "The VPC storage custom file share count \"custom_file_shares\" must be less than or equal to 5. Unlimited NFS mounts are allowed."
  }
  validation {
    condition     = length([for mounts in var.custom_file_shares : mounts.mount_path]) == length(toset([for mounts in var.custom_file_shares : mounts.mount_path]))
    error_message = "Mount path values should not be duplicated."
  }
  validation {
    condition     = alltrue([for mounts in var.custom_file_shares : can(mounts.size) && mounts.size != null ? (10 <= mounts.size && mounts.size <= 32000) : true])
    error_message = "The custom_file_share size must be greater than or equal to 10 and less than or equal to 32000."
  }
}

variable "mtu_value" {
  type        = number
  default     = 9000
  description = "Default MTU is 9000. For deployments using Spectrum Scale with LSF and PPNLB enabled, configure the MTU at 8500 or lower to ensure compatibility."
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
    storage  = optional(string)
    protocol = optional(string)
    client   = optional(string)
    gklm     = optional(string)
    ppnlb    = optional(string)
  })
  default = {
    compute  = "comp.com"
    storage  = "strg.com"
    protocol = "ces.com"
    client   = "clnt.com"
    gklm     = "gklm.com"
    ppnlb    = "strgscale.private"
  }
  description = "IBM Cloud HPC DNS domain names."
}

##############################################################################
# Encryption Variables
##############################################################################
variable "key_management" {
  type        = string
  default     = null
  description = "Set the value as key_protect to enable customer managed encryption for boot volume and file share. If the key_management is set as null, IBM Cloud resources will be always be encrypted through provider managed."
  validation {
    condition     = var.key_management == "null" || var.key_management == null || var.key_management == "key_protect"
    error_message = "key_management must be either 'null' or 'key_protect'."
  }
}

variable "kms_instance_name" {
  type        = string
  default     = null
  description = "Provide the name of the existing Key Protect instance associated with the Key Management Service. Note: To use existing kms_instance_name set key_management as key_protect. The name can be found under the details of the KMS, see [View key-protect ID](https://cloud.ibm.com/docs/key-protect?topic=key-protect-retrieve-instance-ID&interface=ui)."
}

variable "kms_key_name" {
  type        = string
  default     = null
  description = "Provide the existing kms key name that you want to use for the IBM Cloud HPC cluster. Note: kms_key_name to be considered only if key_management value is set as key_protect.(for example kms_key_name: my-encryption-key)."
}

variable "skip_iam_share_authorization_policy" {
  type        = bool
  default     = false
  description = "When using an existing KMS instance name, set this value to true if authorization is already enabled between KMS instance and the VPC file share. Otherwise, default is set to false. Ensuring proper authorization avoids access issues during deployment.For more information on how to create authorization policy manually, see [creating authorization policies for VPC file share](https://cloud.ibm.com/docs/vpc?topic=vpc-file-s2s-auth&interface=ui)."
}

variable "boot_volume_encryption_key" {
  type        = string
  default     = null
  description = "The kms_key crn."
}

variable "existing_kms_instance_guid" {
  type        = string
  default     = null
  description = "The existing KMS instance guid."
}

variable "key_protect_instance_id" {
  type        = string
  default     = null
  description = "An existing Key Protect instance used for filesystem encryption"
}

# variable "hpcs_instance_name" {
#   type        = string
#   default     = null
#   description = "Hyper Protect Crypto Service instance"
# }

variable "vpn_enabled" {
  type        = bool
  default     = false
  description = "Set the value as true to deploy a VPN gateway for VPC in the cluster."
}

variable "skip_flowlogs_s2s_auth_policy" {
  type        = bool
  default     = false
  description = "Skip auth policy between flow logs service and COS instance, set to true if this policy is already in place on account."
}

variable "skip_kms_s2s_auth_policy" {
  type        = bool
  default     = false
  description = "Skip auth policy between KMS service and COS instance, set to true if this policy is already in place on account."
}

variable "skip_iam_block_storage_authorization_policy" {
  type        = bool
  default     = false
  description = "When using an existing KMS instance name, set this value to true if authorization is already enabled between KMS instance and the block storage volume. Otherwise, default is set to false. Ensuring proper authorization avoids access issues during deployment.For more information on how to create authorization policy manually, see [creating authorization policies for block storage volume](https://cloud.ibm.com/docs/vpc?topic=vpc-block-s2s-auth&interface=ui)."
}

##############################################################################
# Observability Variables
##############################################################################
variable "enable_cos_integration" {
  type        = bool
  default     = false
  description = "Integrate COS with HPC solution"
}

variable "cos_instance_name" {
  type        = string
  default     = null
  description = "Exiting COS instance name"
}

variable "enable_vpc_flow_logs" {
  type        = bool
  default     = false
  description = "Enable Activity tracker"
}

##############################################################################
# Scale specific Variables
##############################################################################
variable "filesystem_config" {
  type = list(
    object({
      filesystem               = string
      block_size               = string
      default_data_replica     = number
      default_metadata_replica = number
      max_data_replica         = number
      max_metadata_replica     = number
    })
  )
  default     = null
  description = "File system configurations."
}

variable "filesets_config" {
  type = list(
    object({
      client_mount_path = string
      quota             = number
    })
  )
  default     = null
  description = "Fileset configurations."
}

variable "afm_instances" {
  type = list(
    object({
      profile = string
      count   = number
    })
  )
  default = [{
    profile = "bx2-32x128"
    count   = 0
  }]
  description = "Number of instances to be launched for afm hosts."
}

variable "afm_cos_config" {
  type = list(
    object({
      afm_fileset          = string,
      mode                 = string,
      cos_instance         = string,
      bucket_name          = string,
      bucket_region        = string,
      cos_service_cred_key = string,
      bucket_type          = string,
      bucket_storage_class = string
    })
  )
  default = [{
    afm_fileset          = "afm_fileset"
    mode                 = "iw"
    cos_instance         = ""
    bucket_name          = ""
    bucket_region        = "us-south"
    cos_service_cred_key = ""
    bucket_storage_class = "smart"
    bucket_type          = "region_location"
  }]
  nullable    = false
  description = "AFM configurations."
}

variable "scale_afm_bucket_config_details" {
  description = "Scale AFM COS Bucket and Configuration Details"
  type = list(object({
    bucket     = string
    endpoint   = string
    fileset    = string
    filesystem = string
    mode       = string
  }))
  default = null
}

variable "scale_afm_cos_hmac_key_params" {
  description = "Scale AFM COS HMAC Key Details"
  type = list(object({
    akey   = string
    bucket = string
    skey   = string
  }))
  default = null
}

##############################################################################
# LSF specific Variables
##############################################################################
# variable "cluster_id" {
#   type        = string
#   default     = "HPCCluster"
#   description = "Unique ID of the cluster used by LSF for configuration of resources. This can be up to 39 alphanumeric characters."
#   validation {
#     condition     = 0 < length(var.cluster_id) && length(var.cluster_id) < 40 && can(regex("^[a-zA-Z0-9_.-]+$", var.cluster_id))
#     error_message = "The ID can be up to 39 alphanumeric characters including the underscore (_), the hyphen (-), and the period (.) characters."
#   }
# }

variable "enable_hyperthreading" {
  type        = bool
  default     = true
  description = "Setting this to true will enable hyper-threading in the worker nodes of the cluster (default). Otherwise, hyper-threading will be disabled."
}

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

variable "app_center_gui_password" {
  type        = string
  default     = ""
  sensitive   = true
  description = "Password for IBM Spectrum LSF Application Center GUI."
}

##############################################################################
# Symphony specific Variables
##############################################################################

##############################################################################
# Slurm  specific Variables
##############################################################################

##############################################################################
# Observability Variables
##############################################################################

variable "observability_atracker_enable" {
  type        = bool
  default     = false
  description = "Activity Tracker Event Routing to configure how to route auditing events. While multiple Activity Tracker instances can be created, only one tracker is needed to capture all events. Creating additional trackers is unnecessary if an existing Activity Tracker is already integrated with a COS bucket. In such cases, set the value to false, as all events can be monitored and accessed through the existing Activity Tracker."
}

variable "observability_atracker_target_type" {
  type        = string
  default     = "cloudlogs"
  description = "All the events will be stored in either COS bucket or Cloud Logs on the basis of user input, so customers can retrieve or ingest them in their system."
  validation {
    condition     = contains(["cloudlogs", "cos"], var.observability_atracker_target_type)
    error_message = "Allowed values for atracker target type is cloudlogs and cos."
  }
}

variable "observability_monitoring_enable" {
  description = "Set false to disable IBM Cloud Monitoring integration. If enabled, infrastructure and LSF application metrics from Management Nodes will be ingested."
  type        = bool
  default     = false
}

variable "observability_logs_enable_for_management" {
  description = "Set false to disable IBM Cloud Logs integration. If enabled, infrastructure and LSF application logs from Management Nodes will be ingested."
  type        = bool
  default     = false
}

variable "observability_logs_enable_for_compute" {
  description = "Set false to disable IBM Cloud Logs integration. If enabled, infrastructure and LSF application logs from Compute Nodes will be ingested."
  type        = bool
  default     = false
}

variable "observability_enable_platform_logs" {
  description = "Setting this to true will create a tenant in the same region that the Cloud Logs instance is provisioned to enable platform logs for that region. NOTE: You can only have 1 tenant per region in an account."
  type        = bool
  default     = false
}

variable "observability_enable_metrics_routing" {
  description = "Enable metrics routing to manage metrics at the account-level by configuring targets and routes that define where data points are routed."
  type        = bool
  default     = false
}

variable "observability_logs_retention_period" {
  description = "The number of days IBM Cloud Logs will retain the logs data in Priority insights. Allowed values: 7, 14, 30, 60, 90."
  type        = number
  default     = 7
  validation {
    condition     = contains([7, 14, 30, 60, 90], var.observability_logs_retention_period)
    error_message = "Allowed values for cloud logs retention period is 7, 14, 30, 60, 90."
  }
}

variable "observability_monitoring_on_compute_nodes_enable" {
  description = "Set false to disable IBM Cloud Monitoring integration. If enabled, infrastructure metrics from Compute Nodes will be ingested."
  type        = bool
  default     = false
}

variable "observability_monitoring_plan" {
  description = "Type of service plan for IBM Cloud Monitoring instance. You can choose one of the following: lite, graduated-tier. For all details visit [IBM Cloud Monitoring Service Plans](https://cloud.ibm.com/docs/monitoring?topic=monitoring-service_plans)."
  type        = string
  default     = "graduated-tier"
  validation {
    condition     = can(regex("lite|graduated-tier", var.observability_monitoring_plan))
    error_message = "Please enter a valid plan for IBM Cloud Monitoring, for all details visit https://cloud.ibm.com/docs/monitoring?topic=monitoring-service_plans."
  }
}

variable "enable_landing_zone" {
  type        = bool
  default     = true
  description = "Run landing zone module."
}

variable "enable_atracker" {
  type        = bool
  default     = false
  description = "Enable Activity tracker"
}

variable "bastion_security_group_id" {
  type        = string
  default     = null
  description = "bastion security group id"
}

variable "deployer_hostname" {
  type        = string
  default     = null
  description = "deployer node hostname"
}

variable "deployer_ip" {
  type        = string
  default     = null
  description = "deployer node ip"
}

variable "cloud_logs_data_bucket" {
  type        = any
  default     = null
  description = "cloud logs data bucket"
}

variable "cloud_metrics_data_bucket" {
  type        = any
  default     = null
  description = "cloud metrics data bucket"
}

#############################################################################
# VARIABLES TO BE CHECKED
##############################################################################


variable "sccwp_enable" {
  type        = bool
  default     = false
  description = "Flag to enable SCC instance creation. If true, an instance of SCC (Security and Compliance Center) will be created."
}

#############################################################################
# LDAP variables
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
  default     = "null"
  description = "Provide the IP address for the existing LDAP server. If no address is given, a new LDAP server will be created."
}

variable "ldap_server_cert" {
  type        = string
  sensitive   = true
  default     = ""
  description = "Provide the existing LDAP server certificate. This value is required if the 'ldap_server' variable is not set to null. If the certificate is not provided or is invalid, the LDAP configuration may fail."
}

variable "ldap_admin_password" {
  type        = string
  sensitive   = true
  default     = null
  description = "The LDAP administrative password should be 8 to 20 characters long, with a mix of at least three alphabetic characters, including one uppercase and one lowercase letter. It must also include two numerical digits and at least one special character from (~@_+:) are required. It is important to avoid including the username in the password for enhanced security."
}

variable "ldap_user_name" {
  type        = string
  default     = ""
  description = "Custom LDAP User for performing cluster operations. Note: Username should be between 4 to 32 characters, (any combination of lowercase and uppercase letters).[This value is ignored for an existing LDAP server]"
}

variable "ldap_user_password" {
  type        = string
  sensitive   = true
  default     = ""
  description = "The LDAP user password should be 8 to 20 characters long, with a mix of at least three alphabetic characters, including one uppercase and one lowercase letter. It must also include two numerical digits and at least one special character from (~@_+:) are required.It is important to avoid including the username in the password for enhanced security.[This value is ignored for an existing LDAP server]."
}

# variable "ldap_instance_key_pair" {
#   type        = list(string)
#   default     = null
#   description = "Name of the SSH key configured in your IBM Cloud account that is used to establish a connection to the LDAP Server. Make sure that the SSH key is present in the same resource group and region where the LDAP Servers are provisioned. If you do not have an SSH key in your IBM Cloud account, create one by using the [SSH keys](https://cloud.ibm.com/docs/vpc?topic=vpc-ssh-keys) instructions."
# }

variable "ldap_instance" {
  type = list(
    object({
      profile = string
      image   = string
    })
  )
  default = [{
    profile = "cx2-2x4"
    image   = "ibm-ubuntu-22-04-5-minimal-amd64-8"
  }]
  description = "Profile and Image name to be used for provisioning the LDAP instances. Note: Debian based OS are only supported for the LDAP feature"
}

##############################################################################
# GKLM variables
##############################################################################
variable "scale_encryption_enabled" {
  type        = bool
  default     = false
  description = "To enable the encryption for the filesystem. Select true or false"
}

variable "scale_encryption_type" {
  type        = string
  default     = null
  description = "To enable filesystem encryption, specify either 'key_protect' or 'gklm'. If neither is specified, the default value will be 'null' and encryption is disabled"
}

variable "gklm_instances" {
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
    image   = "hpcc-scale-gklm4202-v2-5-2"
  }]
  description = "Number of GKLM instances to be launched for scale cluster."
}

variable "scale_encryption_admin_password" {
  type        = string
  default     = null
  description = "Password that is used for performing administrative operations for the GKLM.The password must contain at least 8 characters and at most 20 characters. For a strong password, at least three alphabetic characters are required, with at least one uppercase and one lowercase letter.  Two numbers, and at least one special character from this(~@_+:). Make sure that the password doesn't include the username. Visit this [page](https://www.ibm.com/docs/en/gklm/3.0.1?topic=roles-password-policy) to know more about password policy of GKLM. "
}

variable "scale_ansible_repo_clone_path" {
  type        = string
  default     = "/opt/ibm/ibm-spectrumscale-cloud-deploy"
  description = "Path to clone github.com/IBM/ibm-spectrum-scale-install-infra."
}

variable "scale_config_path" {
  type        = string
  default     = "/opt/IBM/ibm-spectrumscale-cloud-deploy"
  description = "Path to clone github.com/IBM/ibm-spectrum-scale-install-infra."
}

variable "spectrumscale_rpms_path" {
  type        = string
  default     = "/opt/IBM/gpfs_cloud_rpms"
  description = "Path that contains IBM Spectrum Scale product cloud rpms."
}

variable "storage_type" {
  type        = string
  default     = "vsi"
  description = "Select the required storage type(vsi/baremetal/eval)."
}

variable "using_packer_image" {
  type        = bool
  default     = false
  description = "If true, gpfs rpm copy step will be skipped during the configuration."
}

variable "using_jumphost_connection" {
  type        = bool
  default     = false
  description = "If true, will skip the jump/bastion host configuration."
}

variable "bastion_user" {
  type        = string
  default     = "ubuntu"
  description = "Provide the username for Bastion login."
}

variable "inventory_format" {
  type        = string
  default     = "ini"
  description = "Specify inventory format suited for ansible playbooks."
}

variable "bastion_instance_id" {
  type        = string
  default     = null
  description = "Bastion instance id."
}

variable "bastion_ssh_private_key" {
  type        = string
  default     = "None"
  description = "Bastion SSH private key path, which will be used to login to bastion host."
}

variable "create_separate_namespaces" {
  type        = bool
  default     = true
  description = "Flag to select if separate namespace needs to be created for compute instances."
}

variable "create_scale_cluster" {
  type        = bool
  default     = true
  description = "Flag to represent whether to create scale cluster or not."
}

variable "using_rest_api_remote_mount" {
  type        = string
  default     = true
  description = "If false, skips GUI initialization on compute cluster for remote mount configuration."
}

variable "bastion_fip" {
  type        = string
  default     = null
  description = "bastion fip"
}
##############################################################################
# Dedicatedhost Variables
##############################################################################

variable "enable_dedicated_host" {
  type        = bool
  default     = false
  description = "Enables dedicated host to the compute instances"
}

###########################################################################
# Existing Bastion Support variables
###########################################################################

variable "existing_bastion_instance_name" {
  type        = string
  default     = null
  description = "Provide the name of the bastion instance. If none given then new bastion will be created."
}

variable "existing_bastion_instance_public_ip" {
  type        = string
  default     = null
  description = "Provide the public ip address of the bastion instance to establish the remote connection."
}

variable "existing_bastion_security_group_id" {
  type        = string
  default     = null
  description = "Specify the security group ID for the bastion server. This ID will be added as an allowlist rule on the HPC cluster nodes to facilitate secure SSH connections through the bastion node. By restricting access through a bastion server, this setup enhances security by controlling and monitoring entry points into the cluster environment. Ensure that the specified security group is correctly configured to permit only authorized traffic for secure and efficient management of cluster resources."
}

variable "existing_bastion_ssh_private_key" {
  type        = string
  sensitive   = true
  default     = null
  description = "Provide the private SSH key (named id_rsa) used during the creation and configuration of the bastion server to securely authenticate and connect to the bastion server. This allows access to internal network resources from a secure entry point. Note: The corresponding public SSH key (named id_rsa.pub) must already be available in the ~/.ssh/authorized_keys file on the bastion host to establish authentication."
}

variable "resource_group_ids" {
  type        = any
  default     = null
  description = "Map describing resource groups to create or reference"
}

##############################################################################
# Login Variables
##############################################################################
variable "login_instance" {
  type = list(
    object({
      profile = string
      image   = string
    })
  )
  default = [{
    profile = "bx2-2x8"
    image   = "hpcaas-lsf10-rhel810-compute-v8"
  }]
  description = "Number of instances to be launched for login node."
}

##############################################################################
# Environment Variables
##############################################################################

# tflint-ignore: all
variable "TF_VERSION" {
  type        = string
  default     = "1.9"
  description = "The version of the Terraform engine that's used in the Schematics workspace."
}

# tflint-ignore: all
variable "TF_PARALLELISM" {
  type        = string
  default     = "250"
  description = "Parallelism/ concurrent operations limit. Valid values are between 1 and 256, both inclusive. [Learn more](https://www.terraform.io/docs/internals/graph.html#walking-the-graph)."
  validation {
    condition     = 1 <= var.TF_PARALLELISM && var.TF_PARALLELISM <= 256
    error_message = "Input \"TF_PARALLELISM\" must be greater than or equal to 1 and less than or equal to 256."
  }
}

##############################################################################
# SCC Variables
##############################################################################

variable "sccwp_service_plan" {
  description = "Specify the plan type for the Security and Compliance Center (SCC) Workload Protection instance. Valid values are free-trial and graduated-tier only."
  type        = string
  default     = "free-trial"
  validation {
    error_message = "Plan for SCC Workload Protection instances can only be `free-trial` or `graduated-tier`."
    condition = contains(
      ["free-trial", "graduated-tier"],
      var.sccwp_service_plan
    )
  }
}

variable "bms_boot_drive_encryption" {
  type        = bool
  default     = true
  description = "Set this flag to true to create an instance of IBM Security and Compliance Center (SCC) Workload Protection. When enabled, it provides tools to discover and prioritize vulnerabilities, monitor for security threats, and enforce configuration, permission, and compliance policies across the full lifecycle of your workloads. To view the data on the dashboard, enable the cspm to create the app configuration and required trusted profile policies.[Learn more](https://cloud.ibm.com/docs/workload-protection?topic=workload-protection-about)."
}

variable "cspm_enabled" {
  description = "CSPM (Cloud Security Posture Management) is a set of tools and practices that continuously monitor and secure cloud infrastructure. When enabled, it creates a trusted profile with viewer access to the App Configuration and Enterprise services for the SCC Workload Protection instance. Make sure the required IAM permissions are in place, as missing permissions will cause deployment to fail. If CSPM is disabled, dashboard data will not be available.[Learn more](https://cloud.ibm.com/docs/workload-protection?topic=workload-protection-about)."
  type        = bool
  default     = false
  nullable    = false
}

variable "app_config_plan" {
  description = "To enable the encryption for the boot drive of bare metal server. Select true or false"
  type        = string
  default     = "basic"
  validation {
    error_message = "Plan for App configuration can only be basic, standardv2, enterprise.."
    condition = contains(
      ["basic", "standardv2", "enterprise"],
      var.app_config_plan
    )
  }
}

variable "client_security_group_name" {
  type        = string
  default     = null
  description = "Provide the security group name to provision the client nodes. If set to null, the solution will automatically create the necessary security group and rules. If you choose to use an existing security group, ensure it has the appropriate rules configured for the client nodes to function properly."
  validation {
    condition     = anytrue([var.vpc_name != null && var.client_security_group_name != null, var.client_security_group_name == null])
    error_message = "If the client_security_group_name are provided, the user should also provide the vpc_name."
  }
}

variable "compute_security_group_name" {
  type        = string
  default     = null
  description = "Provide the security group name to provision the compute nodes. If set to null, the solution will automatically create the necessary security group and rules. If you choose to use an existing security group, ensure it has the appropriate rules configured for the compute nodes to function properly."
  validation {
    condition     = anytrue([var.vpc_name != null && var.compute_security_group_name != null, var.compute_security_group_name == null])
    error_message = "If the compute_security_group_name are provided, the user should also provide the vpc_name."
  }
}

variable "storage_security_group_name" {
  type        = string
  default     = null
  description = "Provide the security group name to provision the storage node. If set to null, the solution will automatically create the necessary security group and rules. If you choose to use an existing security group, ensure it has the appropriate rules configured for the storage node to function properly."
  validation {
    condition     = anytrue([var.vpc_name != null && var.storage_security_group_name != null, var.storage_security_group_name == null])
    error_message = "If the storage_security_group_name are provided, the user should also provide the vpc_name."
  }
}

variable "ldap_security_group_name" {
  type        = string
  default     = null
  description = "Provide the security group name to provision the ldap nodes. If set to null, the solution will automatically create the necessary security group and rules. If you choose to use an existing security group, ensure it has the appropriate rules configured for the ldap nodes to function properly."
  validation {
    condition     = anytrue([var.vpc_name != null && var.ldap_security_group_name != null, var.ldap_security_group_name == null])
    error_message = "If the ldap_security_group_name are provided, the user should also provide the vpc_name."
  }
}

variable "gklm_security_group_name" {
  type        = string
  default     = null
  description = "Provide the security group name to provision the gklm nodes. If set to null, the solution will automatically create the necessary security group and rules. If you choose to use an existing security group, ensure it has the appropriate rules configured for the gklm nodes to function properly."
  validation {
    condition     = anytrue([var.vpc_name != null && var.gklm_security_group_name != null, var.gklm_security_group_name == null])
    error_message = "If the gklm_security_group_name are provided, the user should also provide the vpc_name."
  }
}

variable "login_security_group_name" {
  type        = string
  default     = null
  description = "Provide the security group name to provision the bastion node. If set to null, the solution will automatically create the necessary security group and rules. If you choose to use an existing security group, ensure it has the appropriate rules configured for the bastion node to function properly."
  validation {
    condition     = anytrue([var.vpc_name != null && var.login_security_group_name != null, var.login_security_group_name == null])
    error_message = "If the login_security_group_name are provided, the user should also provide the vpc_name."
  }
}

variable "volume_storages" {
  description = "Configures the boot and block volumes for each instance. Boot volumes use the SDP profile by default but can be changed to a general-purpose profile if required by the workload. If the boot volume profile is set to general-purpose, the IOPS value should be set to 0 or null, as IOPS are not supported for that profile. Block volumes are always created with the SDP profile to maintain performance standards. You can specify optional boot volume settings (profile, size, IOPS), while block volume capacity and IOPS are mandatory. Both volume types support an optional auto-grow feature that allows disk size to increase automatically when needed through automation."
  type = list(
    object({
      boot_volume_profile    = optional(string)
      boot_volume_iops       = optional(string)
      boot_volume_size       = optional(number)
      boot_volume_disk_grow  = optional(bool, false)
      block_volume_capacity  = optional(number)
      block_volume_iops      = optional(number)
      block_volume_disk_grow = optional(bool, false)
    })
  )
  default = [{
    boot_volume_profile    = "sdp"
    boot_volume_size       = 100
    boot_volume_iops       = 3000 # IOPS is not applicable for general-purpose profile
    boot_volume_disk_grow  = false
    block_volume_capacity  = 500
    block_volume_iops      = 20000
    block_volume_disk_grow = false
  }]
}

##############################################################################
# Private Path NLB Variables
##############################################################################

variable "enable_private_path_nlb" {
  type        = bool
  default     = false
  description = "When set to true, provisions a private path Network Load Balancer that enables CES (NFS) storage access for the cluster. The private path integrates with the Scale NFS nodes to provide a secure, high-performance method of delivering file storage to clients within the same VPC, ensuring direct and efficient access to the CES storage nodes."
}

variable "lsf_pay_per_use" {
  type        = bool
  default     = true
  description = "When lsf_pay_per_use is set to true, the LSF cluster nodes are provisioned using predefined custom images under a pay-per-use pricing plan, where billing is based on vCPU usage per hour. In this mode, providing custom images for the nodes is not required, and Bring Your Own Image (BYOL) is not supported. The pay-per-use option is available only for FP15 images. If you set the variable to false, the automation uses default images for all cluster nodes and enables support for BYOL, with no pay-per-use billing applied."
}

variable "protocol_instance_eth1_mtu" {
  type        = number
  description = "Specifies the MTU value for the protocol instance on eth1. When Private Path NLB (PPNLB) is enabled, the MTU must be set within the supported range of 1500 to 8500; values above 8500 will cause cluster mount operations to fail. When PPNLB is disabled, the MTU can use the default value of 9000"
  default     = 9000

  validation {
    condition = (
      var.protocol_instance_eth1_mtu >= 1500 &&
      var.protocol_instance_eth1_mtu <= (
        var.enable_private_path_nlb ? 8500 : 9000
      )
    )
    error_message = "MTU must be between 1500-8500 when private path NLB is enabled, or 1500-9000 when disabled."
  }
}
