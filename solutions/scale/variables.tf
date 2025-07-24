##############################################################################
# Offering Variations
##############################################################################
variable "ibm_customer_number" {
  type        = string
  sensitive   = true
  description = "Comma-separated list of the IBM Customer Number(s) (ICN) that is used for the Bring Your Own License (BYOL) entitlement check. For more information on how to find your ICN, see [What is my IBM Customer Number (ICN)?](https://www.ibm.com/support/pages/what-my-ibm-customer-number-icn)."
  validation {
    condition = (
      var.ibm_customer_number == null ||
      can(regex("^[0-9A-Za-z]+(,[0-9A-Za-z]+)*$", var.ibm_customer_number))
    )
    error_message = "The IBM customer number input value cannot have special characters."
  }
  validation {
    condition     = var.storage_type == "evaluation" || var.ibm_customer_number != ""
    error_message = "The IBM customer number cannot be empty when storage_type is not 'evaluation'."
  }
}

##############################################################################
# Account Variables
##############################################################################
variable "ibmcloud_api_key" {
  type        = string
  sensitive   = true
  description = "Provide the IBM Cloud API key for the account where the IBM Storage Scale cluster will be deployed. For instructions on creating an API key, see [Managing user API keys](https://cloud.ibm.com/docs/account?topic=account-userapikey&interface=ui)."
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
    error_message = "Provide a value for a single zone from the supported regions."
  }
}

variable "ssh_keys" {
  type        = list(string)
  default     = null
  description = "Specify the names of the SSH keys already configured in your IBM Cloud account to enable access to the Storage Scale nodes. The solution does not create new SSH keys, so ensure you provide existing ones. These keys must reside in the same resource group and region as the cluster being provisioned.To provide multiple SSH keys, use a comma-separated list in the format: [\"key-name-1\", \"key-name-2\"]. If you do not have an SSH key in your IBM Cloud account, you can create one by following the instructions [SSH Keys](https://cloud.ibm.com/docs/vpc?topic=vpc-ssh-keys)."
}

variable "remote_allowed_ips" {
  type        = list(string)
  description = "To ensure secure access to the IBM Storage Scale cluster via SSH, you must specify the public IP addresses of the devices that are permitted to connect. These IPs will be used to configure access restrictions and protect the environment from unauthorized connections. To allow access from multiple devices, provide the IP addresses as a comma-separated list in the format: [\"169.45.117.34\", \"203.0.113.25\"]. Identify your current public IP address, you can visit: https://ipv4.icanhazip.com."
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
  description = "Prefix that is used to name the IBM Cloud resources that are provisioned to build the Storage Scale cluster. Make sure that the prefix is unique, since you cannot create multiple resources with the same name. The maximum length of supported characters is 64. Must begin with a letter and end with a letter or number."
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
  description = "Provide the name of an existing VPC in which the cluster resources will be deployed. If no value is given, solution provisions a new VPC. [Learn more](https://cloud.ibm.com/docs/vpc). If a custom DNS resolver is already configured for your VPC, specify its ID under the dns_custom_resolver_id input value."
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
    image   = "ibm-ubuntu-22-04-5-minimal-amd64-5"
    profile = "cx2-4x8"
  }
  validation {
    condition     = can(regex("^ibm-ubuntu", var.bastion_instance.image))
    error_message = "Only IBM Ubuntu stock images are supported for the Bastion node."
  }

  validation {
    condition     = can(regex("^[^\\s]+-[0-9]+x[0-9]+", var.bastion_instance.profile))
    error_message = "The profile must be a valid virtual server instance profile."
  }
  description = "Configuration for the bastion node, including the image and instance profile. Only Ubuntu 22.04 stock images are supported."
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
  validation {
    condition     = can(regex("^(b|c|m)x[0-9]+d?-[0-9]+x[0-9]+$", var.deployer_instance.profile))
    error_message = "The profile must be a valid virtual server instance profile."
  }
  description = "Configuration for the deployer node, including the custom image and instance profile. By default, uses fixpack_15 image and a bx2-8x32 profile."
}

##############################################################################
# Compute Variables
##############################################################################
variable "login_subnets_cidr" {
  type        = string
  default     = "10.241.16.0/28"
  description = "Provide the CIDR block required for the creation of the login cluster's private subnet. Only one CIDR block is needed. If using a hybrid environment, modify the CIDR block to avoid conflicts with any on-premises CIDR blocks. Since the login subnet is used only for the creation of login virtual server instances, provide a CIDR range of /28."
  validation {
    condition     = tonumber(regex("^.*?/(\\d+)$", var.login_subnets_cidr)[0]) <= 28
    error_message = "This subnet is used to create only a login virtual server instance. Providing a larger CIDR size will waste the usage of available IPs. A CIDR range of /28 is sufficient for the creation of the login subnet."
  }
}

variable "compute_subnets_cidr" {
  type        = string
  default     = "10.241.0.0/20"
  description = "Provide the CIDR block required for the creation of the compute private subnet. One CIDR block is required. If using a hybrid environment, modify the CIDR block to avoid conflicts with any on-premises CIDR blocks. Ensure the selected CIDR block size can accommodate the maximum number of scale compute nodes expected in your cluster. For more information on CIDR block size selection, refer to the documentation, see [Choosing IP ranges for your VPC](https://cloud.ibm.com/docs/vpc?topic=vpc-choosing-ip-ranges-for-your-vpc)."
}

variable "storage_subnets_cidr" {
  type        = string
  default     = "10.241.30.0/24"
  description = "Provide the CIDR block required for the creation of the storage private subnet. One CIDR block is required. If using a hybrid environment, modify the CIDR block to avoid conflicts with any on-premises CIDR blocks. Ensure the selected CIDR block size can accommodate the maximum number of scale storage nodes expected in your cluster. For more information on CIDR block size selection, refer to the documentation, see [Choosing IP ranges for your VPC](https://cloud.ibm.com/docs/vpc?topic=vpc-choosing-ip-ranges-for-your-vpc)."
}

variable "protocol_subnets_cidr" {
  type        = string
  default     = "10.241.40.0/24"
  description = "Provide the CIDR block required for the creation of the protocal private subnet. One CIDR block is required. If using a hybrid environment, modify the CIDR block to avoid conflicts with any on-premises CIDR blocks. Ensure the selected CIDR block size can accommodate the maximum number of scale storage nodes expected in your cluster. For more information on CIDR block size selection, refer to the documentation, see [Choosing IP ranges for your VPC](https://cloud.ibm.com/docs/vpc?topic=vpc-choosing-ip-ranges-for-your-vpc)."
}

variable "client_subnets_cidr" {
  type        = string
  default     = "10.241.50.0/24"
  description = "Provide the CIDR block required for the creation of the client private subnet. One CIDR block is required. If using a hybrid environment, modify the CIDR block to avoid conflicts with any on-premises CIDR blocks. Ensure the selected CIDR block size can accommodate the maximum number of scale client nodes expected in your cluster. For more information on CIDR block size selection, refer to the documentation, see [Choosing IP ranges for your VPC](https://cloud.ibm.com/docs/vpc?topic=vpc-choosing-ip-ranges-for-your-vpc)."
}

variable "compute_gui_username" {
  type        = string
  default     = ""
  sensitive   = true
  description = "GUI username to perform system management and monitoring tasks on the compute cluster. The Username should be at least 4 characters, (any combination of lowercase and uppercase letters)."
  validation {
    condition     = sum([for inst in var.compute_instances : inst.count]) == 0 || (length(var.compute_gui_username) >= 4 && length(var.compute_gui_username) <= 32 && trimspace(var.compute_gui_username) != "")
    error_message = "Specified input for \"compute_gui_username\" is not valid. Username should be greater or equal to 4 letters and less than equal to 32."
  }
}

variable "compute_gui_password" {
  type        = string
  default     = ""
  sensitive   = true
  description = "Password for logging in to the compute cluster GUI. Must be at least 8 characters long and include a combination of uppercase and lowercase letters, a number, and a special character. It must not contain the username or start with a special character."

  #  validation {
  #    condition = (
  #      sum([for inst in var.compute_instances : inst.count]) > 0 || can(regex("^.{8,}$", var.compute_gui_password) != "") && can(regex("[0-9]{1,}", var.compute_gui_password) != "") && can(regex("[a-z]{1,}", var.compute_gui_password) != "") && can(regex("[A-Z]{1,}", var.compute_gui_password) != "") && can(regex("[!@#$%^&*()_+=-]{1,}", var.compute_gui_password) != "") && trimspace(var.compute_gui_password) != "" && can(regex("^[!@#$%^&*()_+=-]", var.compute_gui_password)) == false
  #    )
  #    error_message = "The compute cluster GUI password is used for logging in to the compute cluster through the GUI. The password should contain a minimum of 8 characters.  For a strong password, use a combination of uppercase and lowercase letters, one number and a special character. Make sure that the password doesn't contain the username and it should not start with a special character."
  #  }
  validation {
    condition = (
      sum([for inst in var.compute_instances : inst.count]) == 0 || can(regex("^.{8,}$", var.compute_gui_password) != "") && can(regex("[0-9]{1,}", var.compute_gui_password) != "") && can(regex("[a-z]{1,}", var.compute_gui_password) != "") && can(regex("[A-Z]{1,}", var.compute_gui_password) != "") && can(regex("[!@#$%^&*()_+=-]{1,}", var.compute_gui_password) != "") && trimspace(var.compute_gui_password) != "" && can(regex("^[!@#$%^&*()_+=-]", var.compute_gui_password)) == false
    )
    error_message = "If compute instances are used, the GUI password must be at least 8 characters long, include upper/lowercase letters, a number, a special character, must not start with a special character, and must not contain the username."
  }
}

##############################################################################
# Storage Scale Variables
##############################################################################
variable "compute_instances" {
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
    image      = "ibm-redhat-8-10-minimal-amd64-4"
    filesystem = "/gpfs/fs1"
  }]
  validation {
    condition = alltrue([
      for inst in var.compute_instances : can(regex("^(b|c|m)x[0-9]+d?-[0-9]+x[0-9]+$", inst.profile))
    ])
    error_message = "Specified profile must be a valid IBM Cloud VPC GEN2 profile name [Learn more](https://cloud.ibm.com/docs/vpc?topic=vpc-profiles)."
  }
  description = "Specifies the list of virtual server instances to be provisioned as compute nodes in the cluster. Each object in the list defines the instance profile (machine type), the count (number of instances), the image (OS image to use), and an optional filesystem mount path. This configuration allows you to customize the compute tier of the cluster based on your performance and workload requirements. For more details, refer [Instance Profiles](https://cloud.ibm.com/docs/vpc?topic=vpc-profiles&interface=ui)."
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
  validation {
    condition = alltrue([
      for inst in var.client_instances : can(regex("^(b|c|m)x[0-9]+d?-[0-9]+x[0-9]+$", inst.profile))
    ])
    error_message = "Specified profile must be a valid IBM Cloud VPC GEN2 profile name [Learn more](https://cloud.ibm.com/docs/vpc?topic=vpc-profiles)."
  }
  description = "Defines the list of virtual server instances to be provisioned as client nodes in the cluster. Each object in the list specifies the instance profile (machine type), the count (number of instances), and the image (OS image to use). This allows you to customize the hardware configuration and image for the client nodes based on your workload requirements. The profile must match a valid IBM Cloud VPC Gen2 instance profile format. For more details, refer [Instance Profiles](https://cloud.ibm.com/docs/vpc?topic=vpc-profiles&interface=ui)."

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
    count      = 2
    image      = "ibm-redhat-8-10-minimal-amd64-4"
    filesystem = "/ibm/fs1"
  }]
  validation {
    condition = alltrue([
      for inst in var.storage_instances : can(regex("^(b|c|m)x[0-9]+d?-[0-9]+x[0-9]+$", inst.profile))
    ])
    error_message = "Specified profile must be a valid IBM Cloud VPC GEN2 profile name [Learn more](https://cloud.ibm.com/docs/vpc?topic=vpc-profiles)."
  }
  description = "Specifies the list of virtual server instances to be provisioned as storage nodes in the cluster. Each object in the list defines the instance profile (machine type), the count (number of instances), the image (OS image to use), and an optional filesystem mount path. This configuration allows you to customize the compute tier of the cluster based on your performance and workload requirements. For more details, refer [Instance Profiles](https://cloud.ibm.com/docs/vpc?topic=vpc-profiles&interface=ui)."
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
    image      = "ibm-redhat-8-10-minimal-amd64-4"
    filesystem = "/gpfs/fs1"
  }]
  validation {
    condition = alltrue([
      for inst in var.storage_servers : can(regex("^[b|c|m]x[0-9]+d?-[a-z]+-[0-9]+x[0-9]+", inst.profile))
    ])
    error_message = "Specified profile must be a valid IBM Cloud VPC GEN2 profile name [Learn more](https://cloud.ibm.com/docs/vpc?topic=vpc-profiles)."
  }
  description = "Specify the list of bare metal servers to be provisioned for the storage cluster. Each object in the list specifies the server profile (hardware configuration), the count (number of servers), the image (OS image to use), and an optional filesystem mount path. This configuration allows flexibility in scaling and customizing the storage cluster based on performance and capacity requirements. Only valid bare metal profiles supported in IBM Cloud VPC should be used. For available bare metal profiles, refer to the [Baremetal Profiles](https://cloud.ibm.com/docs/vpc?topic=vpc-bare-metal-servers-profile&interface=ui)."
}

variable "tie_breaker_bm_server_profile" {
  type        = string
  default     = null
  description = "Specify the bare metal server profile type name to be used for creating the bare metal Tie breaker node. If no value is provided, the storage bare metal server profile will be used as the default. For more information, see [bare metal server profiles](https://cloud.ibm.com/docs/vpc?topic=vpc-bare-metal-servers-profile&interface=ui). [Tie Breaker Node](https://www.ibm.com/docs/en/storage-scale/5.2.2?topic=quorum-node-tiebreaker-disks)"
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
    image   = "ibm-redhat-8-10-minimal-amd64-4"
  }]
  validation {
    condition = alltrue([
      for inst in var.afm_instances : can(regex("^(b|c|m)x[0-9]+d?-[0-9]+x[0-9]+$", inst.profile))
    ])
    error_message = "Specified profile must be a valid IBM Cloud VPC GEN2 profile name [Learn more](https://cloud.ibm.com/docs/vpc?topic=vpc-profiles)."
  }
  description = "Specify the list of virtual server instances to be provisioned as afm nodes in the cluster. Each object in the list defines the instance profile (machine type), the count (number of instances), the image (OS image to use), and an optional filesystem mount path. This configuration allows you to customize the compute tier of the cluster based on your performance and workload requirements. For more details, refer [Instance Profiles](https://cloud.ibm.com/docs/vpc?topic=vpc-profiles&interface=ui)."
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
  validation {
    condition = alltrue([
      for inst in var.protocol_instances : can(regex("^(b|c|m)x[0-9]+d?-[0-9]+x[0-9]+$", inst.profile))
    ])
    error_message = "Specified profile must be a valid IBM Cloud VPC GEN2 profile name [Learn more](https://cloud.ibm.com/docs/vpc?topic=vpc-profiles)."
  }
  description = "Specify the list of virtual server instances to be provisioned as protocol nodes in the cluster. Each object in the list defines the instance profile (machine type), the count (number of instances), the image (OS image to use), and an optional filesystem mount path. This configuration allows you to customize the compute tier of the cluster based on your performance and workload requirements. For more details, refer [Instance Profiles](https://cloud.ibm.com/docs/vpc?topic=vpc-profiles&interface=ui)."
}

variable "colocate_protocol_instances" {
  type        = bool
  default     = true
  description = "Enable it to use storage instances as protocol instances."
}

variable "storage_gui_username" {
  type        = string
  default     = ""
  sensitive   = true
  description = "GUI username to perform system management and monitoring tasks on the storage cluster. Note: Username should be at least 4 characters, (any combination of lowercase and uppercase letters)."
  validation {
    condition     = var.storage_gui_username == "" || (length(var.storage_gui_username) >= 4 && length(var.storage_gui_username) <= 32)
    error_message = "Specified input for \"storage_cluster_gui_username\" is not valid. Username should be greater or equal to 4 letters and less that or equal to 32."
  }
}

variable "storage_gui_password" {
  type        = string
  default     = ""
  sensitive   = true
  description = "Password for storage cluster GUI"
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
  }))
  default = [{
    filesystem               = "/ibm/fs1"
    block_size               = "4M"
    default_data_replica     = 2
    default_metadata_replica = 2
    max_data_replica         = 3
    max_metadata_replica     = 3
  }]
  description = "Specify the configuration parameters for one or more IBM Storage Scale (GPFS) filesystems. Each object in the list includes the filesystem mount point, block size, and replica settings for both data and metadata. These settings determine how data is distributed and replicated across the cluster for performance and fault tolerance."
}

variable "filesets_config" {
  type = list(object({
    client_mount_path = string
    quota             = number
  }))
  default = [
    {
      client_mount_path = "/mnt/scale/tools"
      quota             = 0
    },
    {
      client_mount_path = "/mnt/scale/data"
      quota             = 0
    }
  ]
  description = "Specify a list of filesets with client mount paths and optional storage quotas (0 means no quota) to be created within the IBM Storage Scale filesystem.."
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
  # default = [{
  #   afm_fileset          = "afm_fileset"
  #   mode                 = "iw"
  #   cos_instance         = null
  #   bucket_name          = null
  #   bucket_region        = "us-south"
  #   cos_service_cred_key = ""
  #   bucket_storage_class = "smart"
  #   bucket_type          = "region_location"
  # }]
  description = "AFM configurations."
}

##############################################################################
# DNS Variables
##############################################################################

variable "dns_instance_id" {
  type        = string
  default     = null
  description = "Specify the ID of an existing IBM Cloud DNS service instance. When provided, domain names are created within the specified instance. If set to null, a new DNS service instance is created, and the required DNS zones are associated with it."
}

variable "dns_custom_resolver_id" {
  type        = string
  default     = null
  description = "Specify the ID of an existing IBM Cloud DNS custom resolver to avoid creating a new one. If set to null, a new custom resolver will be created and associated with the VPC. Note: A VPC can be associated with only one custom resolver. When using an existing VPC, if a custom resolver is already associated and this ID is not provided, the deployment will fail."
  validation {
    condition     = var.vpc_name != null || var.dns_custom_resolver_id == null
    error_message = "If this is a new VPC deployment (vpc_name is null), do not provide dns_custom_resolver_id, as it may impact name resolution."
  }
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
# Observability Variables
##############################################################################
variable "enable_cos_integration" {
  type        = bool
  default     = true
  description = "Set to true to create an extra cos bucket to integrate with scale cluster deployment."
}

variable "cos_instance_name" {
  type        = string
  default     = null
  description = "Provide the name of the existing COS instance where the logs for the enabled functionalities will be stored."
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
  description = "Set this option to true to enable LDAP for IBM Spectrum LSF, with the default value set to false."
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
  validation {
    condition     = var.enable_ldap == false || var.ldap_server == null || (var.ldap_server != null ? (length(trimspace(var.ldap_server)) > 0 && var.ldap_server != "null") : true)
    error_message = "If LDAP is enabled, an existing LDAP server IP should be provided."
  }
}

variable "ldap_server_cert" {
  type        = string
  sensitive   = true
  default     = null
  description = "Provide the existing LDAP server certificate. This value is required if the 'ldap_server' variable is not set to null. If the certificate is not provided or is invalid, the LDAP configuration may fail. For more information on how to create or obtain the certificate, please refer [existing LDAP server certificate](https://cloud.ibm.com/docs/allowlist/hpc-service?topic=hpc-service-integrating-openldap)."
  validation {
    condition     = var.enable_ldap == false || var.ldap_server == null || (var.ldap_server_cert != null ? (length(trimspace(var.ldap_server_cert)) > 0 && var.ldap_server_cert != "null") : false)
    error_message = "Provide the current LDAP server certificate. This is required if 'ldap_server' is set; otherwise, the LDAP configuration will not succeed."
  }
}

variable "ldap_admin_password" {
  type        = string
  sensitive   = true
  default     = null
  description = "The LDAP admin password must be 8 to 20 characters long and include at least two alphabetic characters (with one uppercase and one lowercase), one number, and one special character from the set (!@#$%^&*()_+=-). The password must not contain the username or any spaces. [This value is ignored for an existing LDAP server]."
  validation {
    condition     = (!var.enable_ldap || var.ldap_server != null || can(var.ldap_admin_password != null && length(var.ldap_admin_password) >= 8 && length(var.ldap_admin_password) <= 20 && regex(".*[0-9].*", var.ldap_admin_password) != "" && regex(".*[A-Z].*", var.ldap_admin_password) != "" && regex(".*[a-z].*", var.ldap_admin_password) != "" && regex(".*[!@#$%^&*()_+=-].*", var.ldap_admin_password) != "" && !can(regex(".*\\s.*", var.ldap_admin_password))))
    error_message = "The LDAP admin password must be 8 to 20 characters long and include at least two alphabetic characters (with one uppercase and one lowercase), one number, and one special character from the set (!@#$%^&*()_+=-). The password must not contain the username or any spaces."
  }
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
  description = "The LDAP user password must be 8 to 20 characters long and include at least two alphabetic characters (with one uppercase and one lowercase), one numeric digit, and at least one special character from the set (!@#$%^&*()_+=-). Spaces are not allowed. The password must not contain the username for enhanced security. [This value is ignored for an existing LDAP server]."
  validation {
    condition     = !var.enable_ldap || var.ldap_server != null || ((replace(lower(var.ldap_user_password), lower(var.ldap_user_name), "") == lower(var.ldap_user_password)) && length(var.ldap_user_password) >= 8 && length(var.ldap_user_password) <= 20 && can(regex("^(.*[0-9]){1}.*$", var.ldap_user_password))) && can(regex("^(.*[A-Z]){1}.*$", var.ldap_user_password)) && can(regex("^(.*[a-z]){1}.*$", var.ldap_user_password)) && can(regex("^.*[!@#$%^&*()_+=-].*$", var.ldap_user_password)) && !can(regex(".*\\s.*", var.ldap_user_password))
    error_message = "The LDAP user password must be 8 to 20 characters long and include at least two alphabetic characters (with one uppercase and one lowercase), one number, and one special character from the set (!@#$%^&*()_+=-). The password must not contain the username or any spaces."
  }
}

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
  validation {
    condition = alltrue([
      for inst in var.ldap_instance : can(regex("^(b|c|m)x[0-9]+d?-[0-9]+x[0-9]+$", inst.profile))
    ])
    error_message = "Specified profile must be a valid IBM Cloud VPC GEN2 profile name [Learn more](https://cloud.ibm.com/docs/vpc?topic=vpc-profiles)."
  }
  description = "Specify the list of virtual server instances to be provisioned as ldap nodes in the cluster. Each object in the list defines the instance profile (machine type), the count (number of instances), the image (OS image to use), and an optional filesystem mount path. This configuration allows you to customize the compute tier of the cluster based on your performance and workload requirements. For more details, refer [Instance Profiles](https://cloud.ibm.com/docs/vpc?topic=vpc-profiles&interface=ui)."
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
  validation {
    condition = (
      var.scale_encryption_type != "gklm" ||
      alltrue([
        for inst in var.gklm_instances : can(regex("^(b|c|m)x[0-9]+d?-[0-9]+x[0-9]+$", inst.profile))
      ])
    )
    error_message = "Specified profile must be a valid IBM Cloud VPC GEN2 profile name [Learn more](https://cloud.ibm.com/docs/vpc?topic=vpc-profiles)."
  }
  validation {
    condition = (var.scale_encryption_type != "gklm" || (sum([for inst in var.gklm_instances : inst.count]) >= 2 && sum([for inst in var.gklm_instances : inst.count]) <= 5))
    #condition   = (sum([for inst in var.gklm_instances : inst.count]) == 0 || (sum([for inst in var.gklm_instances : inst.count]) >= 2 && sum([for inst in var.gklm_instances : inst.count]) <= 5))
    error_message = "For High availability the GKLM instance type should be greater than 2 or less than 5"
  }
  description = "Specify the list of virtual server instances to be provisioned as ldap nodes in the cluster. Each object in the list defines the instance profile (machine type), the count (number of instances), the image (OS image to use), and an optional filesystem mount path. This configuration allows you to customize the compute tier of the cluster based on your performance and workload requirements. For more details, refer [Instance Profiles](https://cloud.ibm.com/docs/vpc?topic=vpc-profiles&interface=ui)."

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
    condition     = can(regex("^(scratch|persistent|evaluation)$", lower(var.storage_type)))
    error_message = "The solution only support scratch, evaluation, and persistent; provide any one of the value."
  }
  validation {
    condition     = var.storage_type == "persistent" ? contains(["us-south-1", "us-south-2", "us-south-3", "us-east-1", "us-east-2", "eu-de-1", "eu-de-2", "eu-de-3", "eu-gb-1", "eu-es-3", "eu-es-1", "jp-tok-2", "jp-tok-3", "ca-tor-2", "ca-tor-3"], join(",", var.zones)) : true
    error_message = "The solution supports bare metal server creation in only given availability zones i.e. us-south-1, us-south-3, us-south-2, eu-de-1, eu-de-2, eu-de-3, jp-tok-2, eu-gb-1, us-east-1, us-east-2, eu-es-3, eu-es-1, jp-tok-3, jp-tok-2, ca-tor-2 and ca-tor-3. To deploy persistent storage provide any one of the supported availability zones."
  }
}

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

##############################################################################
# SCC Workload Protection Variables
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

##############################################################################
# Existing VPC Storage Security Variables
##############################################################################
variable "enable_sg_validation" {
  type        = bool
  default     = true
  description = "Enable or disable security group validation. Security group validation ensures that the specified security groups are properly assigned"
}

variable "login_security_group_name" {
  type        = string
  default     = null
  description = "Provide the existing security group name to provision the bastion node. If set to null, the solution will automatically create the necessary security group and rules. If you choose to use an existing security group, ensure it has the appropriate rules configured for the bastion node to function properly."
  validation {
    condition     = anytrue([var.vpc_name != null && var.login_security_group_name != null, var.login_security_group_name == null])
    error_message = "If the login_security_group_name are provided, the user should also provide the vpc_name."
  }
}

variable "storage_security_group_name" {
  type        = string
  default     = null
  description = "Provide the security group name to provision the storage nodes. If set to null, the solution will automatically create the necessary security group and rules. If you choose to use an existing security group, ensure it has the appropriate rules configured for the storage nodes to function properly."
  validation {
    condition     = anytrue([var.vpc_name != null && var.storage_security_group_name != null, var.storage_security_group_name == null])
    error_message = "If the storage_security_group_name are provided, the user should also provide the vpc_name."
  }
}

variable "cluster_security_group_name" {
  type        = string
  default     = null
  description = "Provide the security group name to provision the compute nodes. If set to null, the solution will automatically create the necessary security group and rules. If you choose to use an existing security group, ensure it has the appropriate rules configured for the compute nodes to function properly."
  validation {
    condition     = anytrue([var.vpc_name != null && var.cluster_security_group_name != null, var.cluster_security_group_name == null])
    error_message = "If the cluster_security_group_name are provided, the user should also provide the vpc_name."
  }
}

variable "client_security_group_name" {
  type        = string
  default     = null
  description = "Provide the security group name to provision the gklm nodes. If set to null, the solution will automatically create the necessary security group and rules. If you choose to use an existing security group, ensure it has the appropriate rules configured for the gklm nodes to function properly."
  validation {
    condition     = anytrue([var.vpc_name != null && var.client_security_group_name != null, var.client_security_group_name == null])
    error_message = "If the client_security_group_name are provided, the user should also provide the vpc_name."
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

variable "ldap_security_group_name" {
  type        = string
  default     = null
  description = "Provide the security group name to provision the ldap nodes. If set to null, the solution will automatically create the necessary security group and rules. If you choose to use an existing security group, ensure it has the appropriate rules configured for the ldap nodes to function properly."
  validation {
    condition     = anytrue([var.vpc_name != null && var.ldap_security_group_name != null, var.ldap_security_group_name == null])
    error_message = "If the ldap_security_group_name are provided, the user should also provide the vpc_name."
  }
}

variable "login_subnet_id" {
  type        = string
  default     = null
  description = "Provide the ID of an existing subnet to deploy cluster resources, this is used only for provisioning bastion, deployer, and login nodes. If not provided, new subnet will be created.[Learn more](https://cloud.ibm.com/docs/vpc)."
  validation {
    condition     = anytrue([var.vpc_name != null && var.login_subnet_id != null, var.login_subnet_id == null])
    error_message = "If the login_subnet_id are provided, the user should also provide the vpc_name."
  }
}

variable "cluster_subnet_id" {
  type        = string
  default     = null
  description = "Provide the ID of an existing subnet to deploy cluster resources; this is used only for provisioning VPC file storage shares, management, and compute nodes. If not provided, a new subnet will be created. Ensure that a public gateway is attached to enable VPC API communication. [Learn more](https://cloud.ibm.com/docs/vpc)."
  validation {
    condition     = anytrue([var.vpc_name != null && var.cluster_subnet_id != null, var.cluster_subnet_id == null])
    error_message = "If the cluster_subnet_id are provided, the user should also provide the vpc_name."
  }
}

variable "storage_subnet_id" {
  type        = string
  description = "Name of an existing subnet for storage nodes. If no value is given, a new subnet will be created"
  default     = null
  validation {
    condition     = anytrue([var.vpc_name != null && var.storage_subnet_id != null, var.storage_subnet_id == null])
    error_message = "If the storage_subnet_id are provided, the user should also provide the vpc_name."
  }
}

variable "protocol_subnet_id" {
  type        = string
  description = "Name of an existing subnet for protocol nodes. If no value is given, a new subnet will be created"
  default     = null
  validation {
    condition     = anytrue([var.vpc_name != null && var.protocol_subnet_id != null, var.protocol_subnet_id == null])
    error_message = "If the protocol_subnet_id are provided, the user should also provide the vpc_name."
  }
}

variable "client_subnet_id" {
  type        = string
  description = "Name of an existing subnet for protocol nodes. If no value is given, a new subnet will be created"
  default     = null
  validation {
    condition     = anytrue([var.vpc_name != null && var.client_subnet_id != null, var.client_subnet_id == null])
    error_message = "If the client_subnet_id are provided, the user should also provide the vpc_name."
  }
}

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
