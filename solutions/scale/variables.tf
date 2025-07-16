##############################################################################
# Offering Variations
##############################################################################
variable "ibm_customer_number" {
  type        = string
  sensitive   = true
  default     = null
  description = "Comma-separated list of the IBM Customer Number(s) (ICN) that is used for the Bring Your Own License (BYOL) entitlement check. For more information on how to find your ICN, see [What is my IBM Customer Number (ICN)?](https://www.ibm.com/support/pages/what-my-ibm-customer-number-icn)."
  validation {
    condition = (
      var.ibm_customer_number == null ||
      can(regex("^[0-9A-Za-z]+(,[0-9A-Za-z]+)*$", var.ibm_customer_number))
    )
    error_message = "The IBM customer number input value cannot have special characters."
  }
}

##############################################################################
# Account Variables
##############################################################################
variable "ibmcloud_api_key" {
  type        = string
  sensitive   = true
  description = "This is the IBM Cloud API key for the IBM Cloud account where the IBM Storage Scale cluster needs to be deployed. For more information on how to create an API key, see [Managing user API keys](https://cloud.ibm.com/docs/account?topic=account-userapikey&interface=ui)."
}

# Delete this variable before pushing to the public repository.
variable "github_token" {
  type        = string
  default     = null
  description = "Provide your GitHub token to download the HPCaaS code into the Deployer node"
}

##############################################################################
# Cluster Level Variables
##############################################################################
variable "zones" {
  description = "Specify the IBM Cloud zone within the chosen region where the IBM Storage scale cluster will be deployed. A single zone input is required, (for example, [\"us-east-1\"]) all the cluster nodes will all be provisioned in this zone.[Learn more](https://cloud.ibm.com/docs/vpc?topic=vpc-creating-a-vpc-in-a-different-region#get-zones-using-the-cli)."
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
  description = "Provide the list of SSH key names already configured in your IBM Cloud account to establish a connection to the storage scale nodes. Solution does not create new SSH keys, provide the existing keys. Make sure the SSH key exists in the same resource group and region where the cluster is being provisioned. To pass multiple SSH keys, use the format [\"key-name-1\", \"key-name-2\"]. If you don't have an SSH key in your IBM Cloud account, you can create one by following the provided .[SSH Keys](https://cloud.ibm.com/docs/vpc?topic=vpc-ssh-keys)."
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
  default     = "scale"
  description = "Prefix that is used to name the IBM Cloud resources that are provisioned to build the Storage Scale cluster. Make sure that the prefix is unique since you cannot create multiple resources with the same name. The maximum length of supported characters is 64. Must begin with a letter and end with a letter or number."
  validation {
    error_message = "Prefix must begin and end with a letter and contain only letters, numbers, and - characters."
    condition     = can(regex("^([A-z]|[a-z][-a-z0-9]*[a-z0-9])$", var.cluster_prefix))
  }
  validation {
    condition     = length(var.cluster_prefix) <= 64
    error_message = "The cluster_prefix must be 64 characters or fewer."
  }
}

##############################################################################
# Resource Groups Variables
##############################################################################
variable "existing_resource_group" {
  type        = string
  default     = "Default"
  description = "Specify the name of the existing resource group in your IBM Cloud account where VPC resources will be deployed. By default, the resource group is set to 'Default.' In some older accounts, it may be 'default,' so please verify the resource group name before proceeding. If the value is set to \"null\", the automation will create two separate resource groups: 'workload-rg' and 'service-rg.' For more details, see Managing resource groups."
  validation {
    condition     = var.existing_resource_group != null
    error_message = "If you want to provide null for resource_group variable, it should be within double quotes."
  }
}

##############################################################################
# VPC Variables
##############################################################################
variable "vpc_name" {
  type        = string
  default     = null
  description = "Name of an existing VPC in which the cluster resources will be deployed. If no value is given, then a new VPC will be provisioned for the cluster. [Learn more](https://cloud.ibm.com/docs/vpc). If your VPC has an existing DNS service ensure the name of the DNS Service ends with prefix scale-scaledns [Example: cluster-name-scale-scaledns]"
}

variable "vpc_cidr" {
  type        = string
  default     = "10.241.0.0/18"
  description = "An address prefix is created for the new VPC when the vpc_name variable is set to null. This prefix is required to provision subnets within a single zone, and the subnets will be created using the specified CIDR blocks. For more information, see [Setting IP ranges](https://cloud.ibm.com/docs/vpc?topic=vpc-vpc-addressing-plan-design)."
}

variable "placement_strategy" {
  type        = string
  default     = null
  description = "VPC placement groups to create (null / host_spread / power_spread)"
}

##############################################################################
# Access Variables
##############################################################################
# variable "enable_bastion" {
#   type        = bool
#   default     = true
#   description = "The solution supports multiple ways to connect to your HPC cluster for example, using bastion node, via VPN or direct connection. If connecting to the HPC cluster via VPN or direct connection, set this value to false."
# }

variable "bastion_instance" {
  type = object({
    image   = string
    profile = string
  })
  default = {
    image   = "ibm-ubuntu-22-04-5-minimal-amd64-3"
    profile = "cx2-4x8"
  }
  description = "Configuration for the bastion node, including the image and instance profile. Only Ubuntu 22.04 stock images are supported."
}

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
# Deployer Variables
##############################################################################

variable "deployer_instance" {
  type = object({
    image   = string
    profile = string
  })
  default = {
    image   = "jay-lsf-new-image"
    profile = "mx2-4x32"
  }
  description = "Name of the custom image that you would like to use to create the Bootstrap node for the Storage Scale cluster. The solution supports only the default custom image that has been provided."
  validation {
    condition = alltrue([
      for inst in var.deployer_instance : can(regex("^[^\\s]+-[0-9]+x[0-9]+", inst.profile))
    ])
    error_message = "Specified profile must be a valid IBM Cloud VPC GEN2 profile name [Learn more](https://cloud.ibm.com/docs/vpc?topic=vpc-profiles)."
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
    image   = "ibm-redhat-8-10-minimal-amd64-4"
  }]
  description = "The virtual server instance profile type name to be used to create the client cluster nodes. For more information, see [Instance Profiles](https://cloud.ibm.com/docs/vpc?topic=vpc-profiles&interface=ui)."
  validation {
    condition = alltrue([
      for inst in var.client_instances : can(regex("^[^\\s]+-[0-9]+x[0-9]+", inst.profile))
    ])
    error_message = "Specified profile must be a valid IBM Cloud VPC GEN2 profile name [Learn more](https://cloud.ibm.com/docs/vpc?topic=vpc-profiles)."
  }
}

variable "vpc_cluster_private_subnets_cidr_blocks" {
  type        = string
  default     = "10.241.0.0/20"
  description = "Provide the CIDR block required for the creation of the compute cluster's private subnet. One CIDR block is required. If using a hybrid environment, modify the CIDR block to avoid conflicts with any on-premises CIDR blocks. Ensure the selected CIDR block size can accommodate the maximum number of management and dynamic compute nodes expected in your cluster. For more information on CIDR block size selection, refer to the documentation, see [Choosing IP ranges for your VPC](https://cloud.ibm.com/docs/vpc?topic=vpc-choosing-ip-ranges-for-your-vpc)."
  validation {
    condition     = length(var.vpc_cluster_private_subnets_cidr_blocks) <= 1
    error_message = "Our Automation supports only a single AZ to deploy resources. Provide one CIDR range of subnet creation."
  }
}

variable "compute_instances" {
  type = list(
    object({
      profile    = string
      count      = number
      image      = string
      filesystem = string
    })
  )
  default = [{
    profile    = "cx2-2x4"
    count      = 3
    image      = "ibm-redhat-8-10-minimal-amd64-4"
    filesystem = "/gpfs/fs1"
  }]
  description = "Specify the list of static compute node configurations, including instance profile, image name, filesystem and count. The solution allows customization of instance profiles and counts, but mixing custom images and IBM stock images across instances is not supported. If using IBM stock images, only Red Hat-based images are allowed.."
  validation {
    condition = alltrue([
      for inst in var.compute_instances : can(regex("^[^\\s]+-[0-9]+x[0-9]+", inst.profile))
    ])
    error_message = "Specified profile must be a valid IBM Cloud VPC GEN2 profile name [Learn more](https://cloud.ibm.com/docs/vpc?topic=vpc-profiles)."
  }
}

variable "compute_gui_username" {
  type        = string
  default     = "admin"
  sensitive   = true
  description = "GUI username to perform system management and monitoring tasks on the compute cluster. The Username should be at least 4 characters, (any combination of lowercase and uppercase letters)."
}

variable "compute_gui_password" {
  type        = string
  default     = "hpc@IBMCloud"
  sensitive   = true
  description = "The compute cluster GUI password is used for logging in to the compute cluster through the GUI. The password should contain a minimum of 8 characters.  For a strong password, use a combination of uppercase and lowercase letters, one number and a special character. Make sure that the password doesn't contain the username and it should not start with a special character."
}

##############################################################################
# Storage Scale Variables
##############################################################################
variable "storage_subnets_cidr" {
  type        = string
  default     = "10.241.30.0/24"
  description = "The CIDR block that's required for the creation of the storage cluster private subnet. Modify the CIDR block if it has already been reserved or used for other applications within the VPC or conflicts with any on-premises CIDR blocks when using a hybrid environment. Provide only one CIDR block for the creation of the storage subnet."
  validation {
    condition     = length(var.storage_subnets_cidr) <= 1
    error_message = "Our Automation supports only a single AZ to deploy resources. Provide one CIDR range of subnet creation."
  }
}

variable "storage_instances" {
  type = list(
    object({
      profile    = string
      count      = number
      image      = string
      filesystem = string
    })
  )
  default = [{
    profile    = "bx2d-2x8"
    count      = 0
    image      = "ibm-redhat-8-10-minimal-amd64-4"
    filesystem = "/ibm/fs1"
  }]
  description = "Specify the list of static compute node configurations, including instance profile, image name, filesystem and count. The solution allows customization of instance profiles and counts, but mixing custom images and IBM stock images across instances is not supported. If using IBM stock images, only Red Hat-based images are allowed."
  validation {
    condition = alltrue([
      for inst in var.storage_instances : can(regex("^[^\\s]+-[0-9]+x[0-9]+", inst.profile))
    ])
    error_message = "Specified profile must be a valid IBM Cloud VPC GEN2 profile name [Learn more](https://cloud.ibm.com/docs/vpc?topic=vpc-profiles)."
  }
}

variable "storage_servers" {
  type = list(
    object({
      profile    = string
      count      = number
      image      = string
      filesystem = string
    })
  )
  default = [{
    profile    = "cx2d-metal-96x192"
    count      = 0
    image      = "ibm-redhat-8-10-minimal-amd64-4"
    filesystem = "/gpfs/fs1"
  }]
  description = "Specify the bare metal server profile type name to be used to create the bare metal storage nodes.."
  validation {
    condition = alltrue([
      for inst in var.storage_servers : can(regex("^[b|c|m]x[0-9]+d?-[0-9]+x[0-9]+", inst.profile))
    ])
    error_message = "Specified profile must be a valid IBM Cloud VPC GEN2 profile name [Learn more](https://cloud.ibm.com/docs/vpc?topic=vpc-profiles)."
  }
}

variable "tie_breaker_bm_server" {
  type = list(
    object({
      profile    = string
      count      = number
      image      = string
      filesystem = string
    })
  )
  default = [{
    profile    = "cx2d-metal-96x192"
    count      = 1
    image      = "ibm-redhat-8-10-minimal-amd64-4"
    filesystem = "/gpfs/fs1"
  }]
  description = "Specify the bare metal server profile type name to be used for creating the bare metal Tie breaker node. If no value is provided, the storage bare metal server profile will be used as the default. For more information, see [bare metal server profiles](https://cloud.ibm.com/docs/vpc?topic=vpc-bare-metal-servers-profile&interface=ui). [Tie Breaker Node](https://www.ibm.com/docs/en/storage-scale/5.2.2?topic=quorum-node-tiebreaker-disks)."
}

variable "protocol_subnets_cidr" {
  type        = string
  default     = "10.241.40.0/24"
  description = "The CIDR block that's required for the creation of the protocol nodes private subnet."
  validation {
    condition     = length(var.protocol_subnets_cidr) <= 1
    error_message = "Our Automation supports only a single AZ to deploy resources. Provide one CIDR range of subnet creation."
  }
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
    image   = "ibm-redhat-8-10-minimal-amd64-4"
  }]
  description = "Specify the list of static compute node configurations, including instance profile, image name, filesystem and count. The solution allows customization of instance profiles and counts, but mixing custom images and IBM stock images across instances is not supported. If using IBM stock images, only Red Hat-based images are allowed."
  validation {
    condition = alltrue([
      for inst in var.protocol_instances : can(regex("^[^\\s]+-[0-9]+x[0-9]+", inst.profile))
    ])
    error_message = "Specified profile must be a valid IBM Cloud VPC GEN2 profile name [Learn more](https://cloud.ibm.com/docs/vpc?topic=vpc-profiles)."
  }
}

variable "colocate_protocol_instances" {
  type        = bool
  default     = true
  description = "Enable it to use storage instances as protocol instances"
}

variable "storage_gui_username" {
  type        = string
  sensitive   = true
  description = "GUI username to perform system management and monitoring tasks on the storage cluster. Note: Username should be at least 4 characters, (any combination of lowercase and uppercase letters)."
  validation {
    condition     = var.storage_gui_username == "" || (length(var.storage_gui_username) >= 4 && length(var.storage_gui_username) <= 32)
    error_message = "Specified input for \"storage_cluster_gui_username\" is not valid. username should be greater or equal to 4 letters."
  }
}

variable "storage_gui_password" {
  type        = string
  sensitive   = true
  description = "The storage cluster GUI password is required to access the storage cluster through its graphical interface. The password must be at least 8 characters long. For enhanced security, it should include a mix of uppercase and lowercase letters, at least one number, and a special character. Ensure the password does not include the username and does not begin with a special character."
  validation {
    condition     = can(regex("^.{8,}$", var.storage_gui_password) != "") && can(regex("[0-9]{1,}", var.storage_gui_password) != "") && can(regex("[a-z]{1,}", var.storage_gui_password) != "") && can(regex("[A-Z]{1,}", var.storage_gui_password) != "") && can(regex("[!@#$%^&*()_+=-]{1,}", var.storage_gui_password) != "") && trimspace(var.storage_gui_password) != "" && can(regex("^[!@#$%^&*()_+=-]", var.storage_gui_password)) == false
    error_message = "The storage cluster GUI Password should contain minimum of 8 characters and for strong password it must be a combination of uppercase letter, lowercase letter, one number and a special character. Ensure password doesn't comprise with username and it should not start with a special character."
  }
}

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
  default = [{
    filesystem               = "fs1"
    block_size               = "4M"
    default_data_replica     = 2
    default_metadata_replica = 2
    max_data_replica         = 3
    max_metadata_replica     = 3
    mount_point              = "/ibm/fs1"
  }]
  description = "List of file system configuration objects defining filesystem name, block size, data/metadata replica counts, and mount point for storage setup."
}

# variable "filesets_config" {
#   type = list(object({
#     fileset           = string
#     filesystem        = string
#     junction_path     = string
#     client_mount_path = string
#     quota             = number
#   }))
#   default = [{
#     fileset           = "fileset1"
#     filesystem        = "fs1"
#     junction_path     = "/gpfs/fs1/fileset1"
#     client_mount_path = "/mnt"
#     quota             = 100
#   }]
#   description = "Fileset configurations."
# }

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
    image   = "ibm-redhat-8-10-minimal-amd64-4"
  }]
  description = "Number of instances to be launched for afm hosts."
  validation {
    condition     = element((split("x", var.afm_instances)), length(split("x", var.afm_instances)) - 1) >= 128
    error_message = "Minimum 128 GB of memory is needed for the AFM gateway node"
  }
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
  description = "Please provide details for the Cloud Object Storage (COS) instance, including information about the COS bucket, service credentials (HMAC key), AFM fileset, mode (such as Read-only (RO), Single writer (SW), Local updates (LU), and Independent writer (IW)), storage class (standard, vault, cold, or smart), and bucket type (single_site_location, region_location, cross_region_location). Note : The 'afm_cos_config' can contain up to 5 entries. For further details on COS bucket locations, refer to the relevant documentation https://cloud.ibm.com/docs/cloud-object-storage/basics?topic=cloud-object-storage-endpoints."
  validation {
    condition     = length([for item in var.afm_cos_config : item ]) <= 5
    error_message = "The length of \"afm_cos_config\" must be less than or equal to 5."
  }
  validation {
    condition     = alltrue([for item in var.afm_cos_config : item.mode != ""])
    error_message = "The \"mode\" field must not be empty."
  }
  validation {
    condition     = length(distinct([for item in var.afm_cos_config : item.afm_fileset])) == length(var.afm_cos_config)
    error_message = "The \"afm_fileset\" name should be unique for each AFM COS bucket relation."
  }
  validation {
    condition     = alltrue([for item in var.afm_cos_config : item.afm_fileset != ""])
    error_message = "The \"afm_fileset\" field must not be empty."
  }
  validation {
    condition     = alltrue([for config in var.afm_cos_config : !(config.bucket_type == "single_site_location") || contains(["ams03", "che01", "mil01", "mon01", "par01", "sjc04", "sng01"], config.bucket_region)])
    error_message = "When 'bucket_type' is 'single_site_location', 'bucket_region' must be one of ['ams03', 'che01', 'mil01', 'mon01', 'par01', 'sjc04', 'sng01']."
  }
  validation {
    condition     = alltrue([for config in var.afm_cos_config : !(config.bucket_type == "cross_region_location") || contains(["us", "eu", "ap"], config.bucket_region)])
    error_message = "When 'bucket_type' is 'cross_region_location', 'bucket_region' must be one of ['us', 'eu', 'ap']."
  }
  validation {
    condition     = alltrue([for config in var.afm_cos_config : !(config.bucket_type == "region_location") || contains(["us-south", "us-east", "eu-gb", "eu-de", "jp-tok", "au-syd", "jp-osa", "ca-tor", "br-sao", "eu-es"], config.bucket_region)])
    error_message = "When 'bucket_type' is 'region_location', 'bucket_region' must be one of ['us-south', 'us-east', 'eu-gb', 'eu-de', 'jp-tok', 'au-syd', 'jp-osa', 'ca-tor', 'br-sao', 'eu-es']."
  }
  validation {
  condition     = alltrue([for item in var.afm_cos_config : (item.bucket_type == "" || contains(["cross_region_location", "single_site_location", "region_location"], item.bucket_type))])
  error_message = "Each 'bucket_type' must be either empty or one of 'region_location', 'single_site_location', 'cross_region_location'."
  }
  validation {
  condition     = alltrue([for item in var.afm_cos_config : (item.bucket_storage_class == "" || (can(regex("^[a-z]+$", item.bucket_storage_class)) && contains(["smart", "standard", "cold", "vault"], item.bucket_storage_class)))])
  error_message = "Each 'bucket_storage_class' must be either empty or one of 'smart', 'standard', 'cold', or 'vault', and all in lowercase."
  }
  validation {
    condition     = alltrue([for item in var.afm_cos_config : item.bucket_region != ""])
    error_message = "The \"bucket_region\" field must not be empty."
  }
}


##############################################################################
# DNS Variables
##############################################################################

variable "dns_instance_id" {
  type        = string
  default     = null
  description = "Name of an existing dns resource instance. If no value is given, a new dns resource instance will be created"
}

variable "dns_custom_resolver_id" {
  type        = string
  default     = null
  description = "Name of an existing dns custom resolver. If no value is given, a new dns custom resolver will be created."
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
  description = "DNS domain names for IBM Cloud HPC components: compute, storage, protocol, client, and GKLM."
}

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
  description = "Activity Tracker Event Routing to configure how to route auditing events. While multiple Activity Tracker instances can be created, only one tracker is needed to capture all events. Creating additional trackers is unnecessary if an existing Activity Tracker is already integrated with a COS bucket. In such cases, set the value to false, as all events can be monitored and accessed through the existing Activity Tracker."
}

variable "enable_vpc_flow_logs" {
  type        = bool
  default     = true
  description = "This flag determines whether VPC flow logs are enabled. When set to true, a flow log collector will be created to capture and monitor network traffic data within the VPC. Enabling flow logs provides valuable insights for troubleshooting, performance monitoring, and security auditing by recording information about the traffic passing through your VPC. Consider enabling this feature to enhance visibility and maintain robust network management practices."
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
  validation {
    condition     = var.enable_ldap == false || (var.ldap_basedns != null ? (length(trimspace(var.ldap_basedns)) > 0 && var.ldap_basedns != "null") : false)
    error_message = "If LDAP is enabled, then the base DNS should not be empty or null. Need a valid domain name."
  }
}

variable "ldap_server" {
  type        = string
  default     = null
  description = "Provide the IP address for the existing LDAP server. If no address is given, a new LDAP server will be created."
}

variable "ldap_server_cert" {
  type        = string
  sensitive   = true
  default     = null
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
  validation {
    condition     = var.enable_ldap == false || var.ldap_server != null || (length(var.ldap_user_name) >= 4 && length(var.ldap_user_name) <= 32 && var.ldap_user_name != "" && can(regex("^[a-zA-Z0-9_-]*$", var.ldap_user_name)) && trimspace(var.ldap_user_name) != "")
    error_message = "LDAP username must be between 4-32 characters long and can only contain letters, numbers, hyphens, and underscores. Spaces are not permitted."
  }
}

variable "ldap_user_password" {
  type        = string
  sensitive   = true
  default     = ""
  description = "The LDAP user password should be 8 to 20 characters long, with a mix of at least three alphabetic characters, including one uppercase and one lowercase letter. It must also include two numerical digits and at least one special character from (~@_+:) are required.It is important to avoid including the username in the password for enhanced security.[This value is ignored for an existing LDAP server]."
  validation {
    condition     = !var.enable_ldap || var.ldap_server != null || ((replace(lower(var.ldap_user_password), lower(var.ldap_user_name), "") == lower(var.ldap_user_password)) && length(var.ldap_user_password) >= 8 && length(var.ldap_user_password) <= 20 && can(regex("^(.*[0-9]){1}.*$", var.ldap_user_password))) && can(regex("^(.*[A-Z]){1}.*$", var.ldap_user_password)) && can(regex("^(.*[a-z]){1}.*$", var.ldap_user_password)) && can(regex("^.*[!@#$%^&*()_+=-].*$", var.ldap_user_password)) && !can(regex(".*\\s.*", var.ldap_user_password))
    error_message = "The LDAP user password must be 8 to 20 characters long and include at least two alphabetic characters (with one uppercase and one lowercase), one number, and one special character from the set (!@#$%^&*()_+=-). The password must not contain the username or any spaces."
  }
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
    image   = "ibm-ubuntu-22-04-5-minimal-amd64-1"
  }]
  description = "Specify the compute instance profile and image to be used for deploying LDAP instances. Only Debian-based operating systems, such as Ubuntu, are supported for LDAP functionality."
  validation {
    condition = alltrue([
      for inst in var.ldap_instance : can(regex("^[^\\s]+-[0-9]+x[0-9]+", inst.profile))
    ])
    error_message = "The profile must be a valid virtual server instance profile."
  }
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
  default     = "null"
  description = "To enable filesystem encryption, specify either 'key_protect' or 'gklm'. If neither is specified, the default value will be 'null' and encryption is disabled"

  validation {
    condition     = var.scale_encryption_type == "key_protect" || var.scale_encryption_type == "gklm" || var.scale_encryption_type == "null"
    error_message = "Invalid value: scale_encryption_type must be 'key_protect', 'gklm', or 'null'"
  }
}

variable "gklm_instance_key_pair" {
  type        = list(string)
  default     = null
  description = "Specify the name of the SSH key in your IBM Cloud account for connecting to the Scale Encryption keyserver nodes when scale_encryption_type is set to gklm. Ensure the SSH key is in the same resource group and region as the keyservers. Only one SSH key is supported for the keyserver nodes. If you do not have an SSH key in your IBM Cloud account, create one by using the [SSH keys](https://cloud.ibm.com/docs/vpc?topic=vpc-ssh-keys) instructions."
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
   validation {
    condition = alltrue([
      for inst in var.gklm_instances : can(regex("^[^\\s]+-[0-9]+x[0-9]+", inst.profile))
    ])
    error_message = "The profile must be a valid virtual server instance profile."
  }
}

variable "scale_encryption_admin_default_password" {
  type        = string
  default     = "SKLM@dmin123"
  description = "The password for administrative operations in KeyProtect or GKLM must be between 8 and 20 characters long. It must include at least three alphabetic characters (one uppercase and one lowercase), two numbers, and one special character from the set (~@_+:). The password should not contain the username. For more information, see [GKLM password policy](https://www.ibm.com/docs/en/sgklm/4.2?topic=manager-password-policy)"
}

variable "scale_encryption_admin_username" {
  type        = string
  default     = "SKLMAdmin"
  description = "The default Admin username for Security Key Lifecycle Manager(GKLM)."
}

variable "scale_encryption_admin_password" {
  type        = string
  default     = null
  description = "Password that is used for performing administrative operations for the GKLM.The password must contain at least 8 characters and at most 20 characters. For a strong password, at least three alphabetic characters are required, with at least one uppercase and one lowercase letter.  Two numbers, and at least one special character from this(~@_+:). Make sure that the password doesn't include the username. Visit this [page](https://www.ibm.com/docs/en/gklm/3.0.1?topic=roles-password-policy) to know more about password policy of GKLM. "
}

# Existing Key Protect Instance Details

variable "key_protect_instance_id" {
  type        = string
  default     = null
  description = "An existing Key Protect instance used for filesystem encryption"
}

variable "storage_type" {
  type        = string
  default     = "scratch"
  description = "Select the Storage Scale file system deployment method. Note: The Storage Scale scratch and evaluation type deploys the Storage Scale file system on virtual server instances, and the persistent type deploys the Storage Scale file system on bare metal servers."
  validation {
    condition = can(regex("^(scratch|persistent|evaluation)$", lower(var.storage_type)))
    #condition     = contains(["scratch", "persistent"], lower(var.storage_type))
    error_message = "The solution only support scratch, evaluation, and persistent; provide any one of the value."
  }
}

##############################################################################
# Observability Variables
##############################################################################

variable "observability_atracker_enable" {
  type        = bool
  default     = true
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
  default     = true
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

variable "sccwp_enable" {
  type        = bool
  default     = false
  description = "Set this flag to true to create an instance of IBM Security and Compliance Center (SCC) Workload Protection. When enabled, it provides tools to discover and prioritize vulnerabilities, monitor for security threats, and enforce configuration, permission, and compliance policies across the full lifecycle of your workloads. To view the data on the dashboard, enable the cspm to create the app configuration and required trusted profile policies.[Learn more](https://cloud.ibm.com/docs/workload-protection?topic=workload-protection-about)."
}

variable "cspm_enabled" {
  description = "CSPM (Cloud Security Posture Management) is a set of tools and practices that continuously monitor and secure cloud infrastructure. When enabled, it creates a trusted profile with viewer access to the App Configuration and Enterprise services for the SCC Workload Protection instance. Make sure the required IAM permissions are in place, as missing permissions will cause deployment to fail. If CSPM is disabled, dashboard data will not be available.[Learn more](https://cloud.ibm.com/docs/workload-protection?topic=workload-protection-about)."
  type        = bool
  default     = true
  nullable    = false
}

variable "app_config_plan" {
  description = "Specify the IBM service pricing plan for the app configuration. Allowed values are 'basic', 'lite', 'standardv2', 'enterprise'."
  type        = string
  default     = "basic"
  validation {
    error_message = "Plan for App configuration can only be basic, lite, standardv2, enterprise.."
    condition = contains(
      ["basic", "lite", "standardv2", "enterprise"],
      var.app_config_plan
    )
  }
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

variable "bms_boot_drive_encryption" {
  type        = bool
  default     = false
  description = "To enable the encryption for the boot drive of bare metal server. Select true or false"
}
