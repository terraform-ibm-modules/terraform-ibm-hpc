##############################################################################
# Mandatory Required variables
##############################################################################
variable "ibmcloud_api_key" {
  description = "Provide the IBM Cloud API key associated with the account to deploy the IBM Spectrum LSF cluster. This key is used to authenticate your deployment and grant the necessary access to create and manage resources in your IBM Cloud environment, see [Managing user API keys](https://cloud.ibm.com/docs/account?topic=account-userapikey)."
  type        = string
  sensitive   = true
  validation {
    condition     = var.ibmcloud_api_key != ""
    error_message = "The API key for IBM Cloud must be set."
  }
}

variable "lsf_version" {
  type        = string
  default     = "fixpack_15"
  description = "Select the desired version of IBM Spectrum LSF to deploy either fixpack_15 or fixpack_14. By default, the solution uses the latest available version, which is Fix Pack 15. If you need to deploy an earlier version such as Fix Pack 14, update the lsf_version field to fixpack_14. When changing the LSF version, ensure that all custom images used for management, compute, and login nodes correspond to the same version. This is essential to maintain compatibility across the cluster and to prevent deployment issues."

  validation {
    condition     = contains(["fixpack_14", "fixpack_15"], var.lsf_version)
    error_message = "Invalid LSF version. Allowed values are 'fixpack_14' and 'fixpack_15'"
  }
}

variable "lsf_pay_per_use" {
  type        = bool
  default     = true
  description = "When lsf_pay_per_use is set to true, the LSF cluster nodes are provisioned using predefined custom images under a pay-per-use pricing plan, where billing is based on vCPU usage per hour. In this mode, providing custom images for the nodes is not required, and Bring Your Own Image (BYOI) is not supported. The pay-per-use option is available only for FP15 images. If you set the variable to false, the automation uses default images for all cluster nodes and enables support for BYOI, with no pay-per-use billing applied."
}

variable "app_center_gui_password" {
  type        = string
  default     = ""
  sensitive   = true
  description = "Password required to access the IBM Spectrum LSF Application Center (App Center) GUI, which is enabled by default in both Fix Pack 15 and Fix Pack 14 with HTTPS. This is a mandatory value and omitting it will result in deployment failure. The password must meet the following requirements, at least 15 characters in length, and must include one uppercase letter, one lowercase letter, one number, and one special character. Spaces are not allowed."

  validation {
    condition = (
      can(regex("^.{15,}$", var.app_center_gui_password)) &&
      can(regex("[0-9]", var.app_center_gui_password)) &&
      can(regex("[a-z]", var.app_center_gui_password)) &&
      can(regex("[A-Z]", var.app_center_gui_password)) &&
      can(regex("[!@#$%^&*()_+=-]", var.app_center_gui_password)) &&
      !can(regex(".*\\s.*", var.app_center_gui_password))
    )
    error_message = "The password must be at least 15 characters long and include at least one lowercase letter, one uppercase letter, one number, and one special character (!@#$%^&*()_+=-). Spaces are not allowed."
  }
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
  description = "Provide the list of SSH key names already configured in your IBM Cloud account to establish a connection to the Spectrum LSF nodes. Solution does not create new SSH keys, provide the existing keys. Make sure the SSH key exists in the same resource group and region where the cluster is being provisioned. To pass multiple SSH keys, use the format [\"key-name-1\", \"key-name-2\"]. If you don't have an SSH key in your IBM Cloud account, you can create one by following the provided .[SSH Keys](https://cloud.ibm.com/docs/vpc?topic=vpc-ssh-keys)."
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

##############################################################################
# Prefix Variables
##############################################################################
variable "cluster_prefix" {
  description = "This prefix uniquely identifies the IBM Cloud Spectrum LSF cluster and its resources, it must always be unique. The name must start with a lowercase letter and can include only lowercase letters, digits, and hyphens. Hyphens must be followed by a lowercase letter or digit, with no leading, trailing, or consecutive hyphens. The prefix length must be less than 16 characters."
  type        = string
  default     = "hpc-lsf"

  validation {
    error_message = "Prefix must start with a lowercase letter and contain only lowercase letters, digits, and hyphens in between. Hyphens must be followed by at least one lowercase letter or digit. There are no leading, trailing, or consecutive hyphens."
    condition     = can(regex("^[a-z](?:[a-z0-9]*(-[a-z0-9]+)*)?$", var.cluster_prefix))
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
  description = "Specify the name of the existing resource group in your IBM Cloud account where VPC resources will be deployed. By default, the resource group is set to 'Default.' In some older accounts, it may be 'default,' so please verify the resource group name before proceeding. If the value is set to \"null\", the automation will create two separate resource groups: 'workload-rg' and 'service-rg.' For more details, see Managing resource groups."
  type        = string
  default     = "Default"
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
  description = "Provide the name of an existing VPC in which the cluster resources will be deployed. If no value is given, solution provisions a new VPC. [Learn more](https://cloud.ibm.com/docs/vpc)."
}

variable "vpc_cidr" {
  type        = string
  default     = "10.241.0.0/18"
  description = "An address prefix is created for the new VPC when the vpc_name variable is set to null. This prefix is required to provision subnets within a single zone, and the subnets will be created using the specified CIDR blocks. For more information, see [Setting IP ranges](https://cloud.ibm.com/docs/vpc?topic=vpc-vpc-addressing-plan-design)."
}

variable "vpc_cluster_login_private_subnets_cidr_blocks" {
  type        = string
  default     = "10.241.16.0/28"
  description = "Specify the CIDR block for the private subnet used by the login cluster. Only a single CIDR block is required. In hybrid environments, ensure the CIDR range does not overlap with any on-premises networks. Since this subnet is dedicated to login virtual server instances, a /28 CIDR range is recommended."
  validation {
    condition     = tonumber(regex("^.*?/(\\d+)$", var.vpc_cluster_login_private_subnets_cidr_blocks)[0]) <= 28
    error_message = "This subnet is used to create only a login virtual server instance. Providing a larger CIDR size will waste the usage of available IPs. A CIDR range of /28 is sufficient for the creation of the login subnet."
  }
}

variable "vpc_cluster_private_subnets_cidr_blocks" {
  type        = string
  default     = "10.241.0.0/20"
  description = "Provide the CIDR block required for the creation of the compute cluster's private subnet. One CIDR block is required. If using a hybrid environment, modify the CIDR block to avoid conflicts with any on-premises CIDR blocks. Ensure the selected CIDR block size can accommodate the maximum number of management and dynamic compute nodes expected in your cluster. For more information on CIDR block size selection, refer to the documentation, see [Choosing IP ranges for your VPC](https://cloud.ibm.com/docs/vpc?topic=vpc-choosing-ip-ranges-for-your-vpc)."
}

variable "login_subnet_id" {
  type        = string
  default     = null
  description = "Provide the ID of an existing subnet to deploy cluster resources, this is used only for provisioning bastion, deployer, and login nodes. If not provided, new subnet will be created.When providing an existing subnet ID, make sure that the subnet has an associated public gateway..[Learn more](https://cloud.ibm.com/docs/vpc)."
  validation {
    condition     = (var.compute_subnet_id == null && var.login_subnet_id == null) || (var.compute_subnet_id != null && var.login_subnet_id != null)
    error_message = "In case of existing subnets, provide both login_subnet_id and compute_subnet_id."
  }
}

variable "compute_subnet_id" {
  type        = string
  default     = null
  description = "Provide the ID of an existing subnet to deploy cluster resources; this is used only for provisioning VPC file storage shares, management, and compute nodes. If not provided, a new subnet will be created. Ensure that a public gateway is attached to enable VPC API communication. [Learn more](https://cloud.ibm.com/docs/vpc)."
  validation {
    condition     = anytrue([var.vpc_name != null && var.compute_subnet_id != null, var.compute_subnet_id == null])
    error_message = "If the compute_subnet_id are provided, the user should also provide the vpc_name."
  }
}
##############################################################################
# Bastion/Deployer Variables
##############################################################################

variable "bastion_instance" {
  type = object({
    image   = string
    profile = string
  })
  default = {
    image   = "ibm-ubuntu-22-04-5-minimal-amd64-8"
    profile = "cx2-4x8"
  }
  description = "Configuration for the bastion node, including the image and instance profile. Only Ubuntu 22.04 stock images are supported."

  validation {
    condition     = can(regex("^ibm-ubuntu", var.bastion_instance.image))
    error_message = "Only IBM Ubuntu stock images are supported for the Bastion node."
  }

  validation {
    condition     = can(regex("^[^\\s]+-[0-9]+x[0-9]+", var.bastion_instance.profile))
    error_message = "The profile must be a valid virtual server instance profile."
  }
}

variable "deployer_instance" {
  type = object({
    image   = string
    profile = string
  })
  default = {
    image   = "hpc-lsf-fp15-deployer-rhel810-v2"
    profile = "bx2-8x32"
  }
  description = "Configuration for the deployer node, including the custom image and instance profile. By default, deployer node is created using Fix Pack 15. If deploying with Fix Pack 14, set lsf_version to fixpack_14 and use the corresponding image hpc-lsf-fp14-deployer-rhel810-v1. The selected image must align with the specified lsf_version, any mismatch may lead to deployment failures."
  validation {
    condition = contains([
      "hpc-lsf-fp15-deployer-rhel810-v2",
      "hpc-lsf-fp14-deployer-rhel810-v1"
    ], var.deployer_instance.image)
    error_message = "Invalid deployer image. Allowed values for fixpack_15 is 'hpc-lsf-fp15-deployer-rhel810-v2' and for fixpack_14 is 'hpc-lsf-fp14-deployer-rhel810-v1'."
  }
  validation {
    condition = (
      (!can(regex("fp15", var.deployer_instance.image)) || var.lsf_version == "fixpack_15") &&
      (!can(regex("fp14", var.deployer_instance.image)) || var.lsf_version == "fixpack_14")
    )
    error_message = "Mismatch between deployer_instance.image and lsf_version. Use an image with 'fp14' only when lsf_version is fixpack_14, and 'fp15' only with fixpack_15."
  }
  validation {
    condition     = can(regex("^[^\\s]+-[0-9]+x[0-9]+", var.deployer_instance.profile))
    error_message = "The profile must be a valid virtual server instance profile."
  }
}

##############################################################################
# LSF Cluster Variables
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
    image   = "hpc-lsf-fp15-compute-rhel810-v2"
  }]
  description = "Specify the list of login node configurations, including instance profile, image name. By default, login node is created using Fix Pack 15. If deploying with Fix Pack 14, set lsf_version to fixpack_14 and use the corresponding image hpc-lsf-fp14-compute-rhel810-v1. The selected image must align with the specified lsf_version, any mismatch may lead to deployment failures."
  validation {
    condition = alltrue([
      for inst in var.login_instance : can(regex("^[^\\s]+-[0-9]+x[0-9]+", inst.profile))
    ])
    error_message = "The profile must be a valid virtual server instance profile."
  }
  validation {
    condition = alltrue([
      for inst in var.login_instance : (
        (!can(regex("fp15", inst.image)) || var.lsf_version == "fixpack_15") &&
        (!can(regex("fp14", inst.image)) || var.lsf_version == "fixpack_14")
      )
    ])
    error_message = "Mismatch between login_instance image and lsf_version. Use an image with 'fp14' only when lsf_version is fixpack_14, and 'fp15' only with fixpack_15."
  }
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
    profile = "bx2-16x64"
    count   = 2
    image   = "hpc-lsf-fp15-rhel810-v2"
  }]
  description = "Specify the list of management node configurations, including instance profile, image name, and count. By default, all management nodes are created using Fix Pack 15. If deploying with Fix Pack 14, set lsf_version to fixpack_14 and use the corresponding image hpc-lsf-fp14-rhel810-v1. The selected image must align with the specified lsf_version, any mismatch may lead to deployment failures. The solution allows customization of instance profiles and counts, but mixing custom images and IBM stock images across instances is not supported. If using IBM stock images, only Red Hat-based images are allowed. Management nodes must have a minimum of 9 GB RAM. Select a profile with 9 GB or higher."
  validation {
    condition     = alltrue([for inst in var.management_instances : !contains([for i in var.management_instances : can(regex("^ibm", i.image))], true) || can(regex("^ibm-redhat", inst.image))])
    error_message = "When defining management_instances, all instances must either use custom images or IBM stock images exclusively — mixing the two is not supported. If stock images are used, only Red Hat-based IBM images (e.g., ibm-redhat-*) are allowed."
  }
  validation {
    condition = alltrue([
      for inst in var.management_instances : can(regex("^[^\\s]+-[0-9]+x[0-9]+", inst.profile))
    ])
    error_message = "The profile must be a valid virtual server instance profile."
  }
  validation {
    condition     = sum([for inst in var.management_instances : inst.count]) <= 10
    error_message = "The total number of management node instances (sum of counts) must not exceed 10."
  }
  validation {
    condition = alltrue([
      for inst in var.management_instances : (
        (!can(regex("fp15", inst.image)) || var.lsf_version == "fixpack_15") &&
        (!can(regex("fp14", inst.image)) || var.lsf_version == "fixpack_14")
      )
    ])
    error_message = "Mismatch between management_instances image and lsf_version. Use an image with 'fp14' only when lsf_version is fixpack_14, and 'fp15' only with fixpack_15."
  }
  validation {
    condition = alltrue([
      for inst in var.management_instances :
      tonumber(regex("\\d+$", inst.profile)) >= 9
    ])
    error_message = "Management node memory requirement not met. Minimum: 9 GB RAM. Please select a profile with 9 GB or higher."
  }
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
    profile = "bx2-4x16"
    count   = 0
    image   = "hpc-lsf-fp15-compute-rhel810-v2"
  }]
  description = "Specify the list of static compute node configurations, including instance profile, image name, and count. By default, all compute nodes are created using Fix Pack 15. If deploying with Fix Pack 14, set lsf_version to fixpack_14 and use the corresponding image hpc-lsf-fp14-compute-rhel810-v1. The selected image must align with the specified lsf_version, any mismatch may lead to deployment failures. The solution allows customization of instance profiles and counts, but mixing custom images and IBM stock images across instances is not supported. If using IBM stock images, only Red Hat-based images are allowed."
  validation {
    condition = alltrue([
      for inst in var.static_compute_instances :
      # If any instance uses IBM stock image, all must use it, and it should be redhat.
      (!contains([for i in var.static_compute_instances : can(regex("^ibm-", i.image))], true) || can(regex("^ibm-redhat", inst.image)))
    ])
    error_message = "When defining static_compute_instances, all instances must either use custom images or IBM stock images exclusively—mixing the two is not supported. If stock images are used, only Red Hat-based IBM images (e.g., ibm-redhat-*) are allowed."
  }
  validation {
    condition = alltrue([
      for inst in var.static_compute_instances : can(regex("^[^\\s]+-[0-9]+x[0-9]+", inst.profile))
    ])
    error_message = "The profile must be a valid virtual server instance profile."
  }
  validation {
    condition = alltrue([
      for inst in var.static_compute_instances : (
        (!can(regex("fp15", inst.image)) || var.lsf_version == "fixpack_15") &&
        (!can(regex("fp14", inst.image)) || var.lsf_version == "fixpack_14")
      )
    ])
    error_message = "Mismatch between static_compute_instances image and lsf_version. Use an image with 'fp14' only when lsf_version is fixpack_14, and 'fp15' only with fixpack_15."
  }
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
    profile = "bx2-4x16"
    count   = 500
    image   = "hpc-lsf-fp15-compute-rhel810-v2"
  }]
  description = "Specify the list of dynamic compute node configurations, including instance profile, image name, and count. By default, all dynamic compute nodes are created using Fix Pack 15. If deploying with Fix Pack 14, set lsf_version to fixpack_14 and use the corresponding image hpc-lsf-fp14-compute-rhel810-v1. The selected image must align with the specified lsf_version, any mismatch may lead to deployment failures. Currently, only a single instance profile is supported for dynamic compute nodes—multiple profiles are not yet supported.."
  validation {
    condition = alltrue([
      for inst in var.dynamic_compute_instances : can(regex("^[^\\s]+-[0-9]+x[0-9]+", inst.profile))
    ])
    error_message = "The profile must be a valid virtual server instance profile."
  }
  validation {
    condition     = length(var.dynamic_compute_instances) == 1
    error_message = "Only a single map (one instance profile) is allowed for dynamic compute instances."
  }
  validation {
    condition = alltrue([
      for inst in var.dynamic_compute_instances : (
        (!can(regex("fp15", inst.image)) || var.lsf_version == "fixpack_15") &&
        (!can(regex("fp14", inst.image)) || var.lsf_version == "fixpack_14")
      )
    ])
    error_message = "Mismatch between dynamic_compute_instances image and lsf_version. Use an image with 'fp14' only when lsf_version is fixpack_14, and 'fp15' only with fixpack_15."
  }
}

##############################################################################
# File share variables
##############################################################################
variable "storage_security_group_id" {
  type        = string
  default     = null
  description = "Provide the storage security group ID from the Spectrum Scale storage cluster when an nfs_share value is specified for a given mount_path in the cluster_file_share variable. This security group is necessary to enable network connectivity between the Spectrum LSF cluster nodes and the NFS mount point, ensuring successful access to the shared file system."
  validation {
    condition     = length([for share in var.custom_file_shares : share.nfs_share if share.nfs_share != null && share.nfs_share != ""]) == 0 || var.storage_security_group_id != null
    error_message = "Storage security group ID cannot be null when NFS share mount path is provided under cluster_file_shares variable."
  }
}

variable "custom_file_shares" {
  type = list(object({
    mount_path = string,
    size       = optional(number),
    iops       = optional(number),
    nfs_share  = optional(string)
  }))
  default     = [{ mount_path = "/mnt/vpcstorage/tools", size = 100, iops = 2000 }, { mount_path = "/mnt/vpcstorage/data", size = 100, iops = 6000 }, { mount_path = "/mnt/scale/tools", nfs_share = "" }]
  description = "Provide details for customizing your shared file storage layout, including mount points, sizes (in GB), and IOPS ranges for up to five file shares if using VPC file storage as the storage option.If using IBM Storage Scale as an NFS mount, update the appropriate mount path and nfs_share values created from the Storage Scale cluster. Note that VPC file storage supports attachment to a maximum of 256 nodes. Exceeding this limit may result in mount point failures due to attachment restrictions.For more information, see [Storage options](https://cloud.ibm.com/docs/hpc-ibm-spectrumlsf?topic=hpc-ibm-spectrumlsf-integrating-scale#integrate-scale-and-hpc)."
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
  validation {
    condition = alltrue([
      for share in var.custom_file_shares : (
        share.size != null && share.iops != null ?
        anytrue([
          for r in local.custom_fileshare_iops_range :
          share.size >= r[0] && share.size <= r[1] && share.iops >= r[2] && share.iops <= r[3]
        ]) : true
      )
    ])
    error_message = "Provided iops value is not valid for given file share size. Please refer 'File Storage for VPC profiles' page in IBM Cloud docs for a valid IOPS and size combination."
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

variable "dns_domain_name" {
  type = object({
    compute = string
  })
  default = {
    compute = "hpc.local"
  }
  description = "IBM Cloud DNS Services domain name to be used for the IBM Spectrum LSF cluster."
  validation {
    condition     = can(regex("^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\\.[a-zA-Z]{2,})+$", var.dns_domain_name.compute))
    error_message = "The compute domain name must be a valid FQDN. It may include letters, digits, hyphens, and must start and end with an alphanumeric character."
  }
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
    error_message = "key_management must be either 'null', null, or 'key_protect'."
  }
  validation {
    condition = (
      var.kms_instance_name == null &&
      (var.key_management == "null" || var.key_management == null || var.key_management == "key_protect")
      ) || (
      var.kms_instance_name != null && var.key_management == "key_protect"
    )
    error_message = "If kms_instance_name is provided, key_management must be 'key_protect'. If kms_instance_name is null, key_management can be 'key_protect', 'null' (string), or null (literal)."
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
  description = "Provide the existing kms key name that you want to use for the IBM Spectrum LSF cluster. Note: kms_key_name to be considered only if key_management value is set as key_protect.(for example kms_key_name: my-encryption-key)."
  validation {
    condition     = anytrue([alltrue([var.kms_key_name != null, var.kms_instance_name != null]), (var.kms_key_name == null), (var.key_management != "key_protect")])
    error_message = "Please make sure you are passing the kms_instance_name if you are passing kms_key_name."
  }
}

variable "skip_iam_share_authorization_policy" {
  type        = bool
  default     = false
  description = "When using an existing KMS instance name, set this value to true if authorization is already enabled between KMS instance and the VPC file share. Otherwise, default is set to false. Ensuring proper authorization avoids access issues during deployment.For more information on how to create authorization policy manually, see [creating authorization policies for VPC file share](https://cloud.ibm.com/docs/vpc?topic=vpc-file-s2s-auth&interface=ui)."
}

##############################################################################
# LDAP Variables
##############################################################################
variable "enable_ldap" {
  type        = bool
  default     = false
  description = "Set this option to true to enable LDAP for IBM Spectrum LSF, with the default value set to false."
}

variable "ldap_basedns" {
  type        = string
  default     = "hpc.local"
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
    error_message = "If LDAP is enabled and you choose to use an existing server, you must provide a valid LDAP server IP address."
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
  description = "The LDAP admin password must be 15 to 32 characters long and include at least two alphabetic characters (with one uppercase and one lowercase), one number, and one special character from the set (!@#$%^&*()_+=-). The password must not contain the username or any spaces. [This value is ignored for an existing LDAP server]."
  validation {
    condition = (
      var.enable_ldap ? (
        var.ldap_server == null ? (
          var.ldap_admin_password != null ? (
            try(length(var.ldap_admin_password)) >= 15 &&
            try(length(var.ldap_admin_password)) <= 32 &&
            try(can(regex(".*[0-9].*", var.ldap_admin_password)), false) &&
            try(can(regex(".*[A-Z].*", var.ldap_admin_password)), false) &&
            try(can(regex(".*[a-z].*", var.ldap_admin_password)), false) &&
            try(can(regex(".*[!@#$%^&*()_+=-].*", var.ldap_admin_password)), false) &&
            !try(can(regex(".*\\s.*", var.ldap_admin_password)), false)
          ) : false
        ) : true
      ) : true
    )
    error_message = "The LDAP admin password must be 15 to 32 characters long and include at least two alphabetic characters (with one uppercase and one lowercase), one number, and one special character from the set (!@#$%^&*()_+=-). The password must not contain any spaces."
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
  description = "The LDAP user password must be 15 to 32 characters long and include at least two alphabetic characters (with one uppercase and one lowercase), one numeric digit, and at least one special character from the set (!@#$%^&*()_+=-). Spaces are not allowed. The password must not contain the username for enhanced security. [This value is ignored for an existing LDAP server]."
  validation {
    condition     = !var.enable_ldap || var.ldap_server != null || ((replace(lower(var.ldap_user_password), lower(var.ldap_user_name), "") == lower(var.ldap_user_password)) && length(var.ldap_user_password) >= 15 && length(var.ldap_user_password) <= 32 && can(regex("^(.*[0-9]){1}.*$", var.ldap_user_password))) && can(regex("^(.*[A-Z]){1}.*$", var.ldap_user_password)) && can(regex("^(.*[a-z]){1}.*$", var.ldap_user_password)) && can(regex("^.*[!@#$%^&*()_+=-].*$", var.ldap_user_password)) && !can(regex(".*\\s.*", var.ldap_user_password))
    error_message = "The LDAP user password must be 15 to 32 characters long and include at least two alphabetic characters (with one uppercase and one lowercase), one number, and one special character from the set (!@#$%^&*()_+=-). The password must not contain the username or any spaces."
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
    image   = "ibm-ubuntu-22-04-5-minimal-amd64-8"
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
# Additional feature Variables
##############################################################################
variable "enable_cos_integration" {
  type        = bool
  default     = true
  description = "Set to true to create an extra cos bucket to integrate with HPC cluster deployment."
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

variable "vpn_enabled" {
  type        = bool
  default     = false
  description = "Set the value as true to deploy a VPN gateway for VPC in the cluster."
}

variable "enable_hyperthreading" {
  type        = bool
  default     = true
  description = "Setting this to true will enable hyper-threading in the worker nodes of the cluster (default). Otherwise, hyper-threading will be disabled."
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
  description = "Specify the target where Atracker events will be stored—either IBM Cloud Logs or a Cloud Object Storage (COS) bucket—based on the selected value. This allows the logs to be accessed or integrated with external systems."
  validation {
    condition     = contains(["cloudlogs", "cos"], var.observability_atracker_target_type)
    error_message = "Allowed values for atracker target type is cloudlogs and cos."
  }
}

variable "observability_monitoring_enable" {
  description = "Enables or disables IBM Cloud Monitoring integration. When enabled, metrics from both the infrastructure and LSF application running on Management Nodes will be collected. This must be set to true if monitoring is required on management nodes."
  type        = bool
  default     = true
  validation {
    condition     = var.observability_monitoring_enable == true || var.observability_monitoring_on_compute_nodes_enable == false
    error_message = "To enable monitoring on compute nodes, IBM Cloud Monitoring must also be enabled."
  }
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
  description = "Enables or disables IBM Cloud Monitoring integration. When enabled, metrics from both the infrastructure and LSF application running on compute Nodes will be collected. This must be set to true if monitoring is required on compute nodes."
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

variable "skip_flowlogs_s2s_auth_policy" {
  type        = bool
  default     = false
  description = "When using an existing COS instance, set this value to true if authorization is already enabled between COS instance and the flow logs service. Otherwise, default is set to false. Ensuring proper authorization avoids access issues during deployment."
}

variable "skip_kms_s2s_auth_policy" {
  type        = bool
  default     = false
  description = "When using an existing COS instance, set this value to true if authorization is already enabled between COS instance and the kms. Otherwise, default is set to false. Ensuring proper authorization avoids access issues during deployment."
}

variable "skip_iam_block_storage_authorization_policy" {
  type        = bool
  default     = false
  description = "When using an existing KMS instance name, set this value to true if authorization is already enabled between KMS instance and the block storage volume. Otherwise, default is set to false. Ensuring proper authorization avoids access issues during deployment.For more information on how to create authorization policy manually, see [creating authorization policies for block storage volume](https://cloud.ibm.com/docs/vpc?topic=vpc-block-s2s-auth&interface=ui)."
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

##############################################################################
# Dedicatedhost Variables
##############################################################################

variable "enable_dedicated_host" {
  type        = bool
  default     = false
  description = "Set this option to true to enable dedicated hosts for the VSIs provisioned as workload servers. The default value is false. When dedicated hosts are enabled, multiple vsi instance profiles from the same or different families (e.g., bx2, cx2, mx2) can be used. If you plan to deploy a static cluster with a third-generation profile, ensure that dedicated host support is available in the selected region, as not all regions support third-gen profiles on dedicated hosts. To learn more about dedicated host, [click here.](https://cloud.ibm.com/docs/vpc?topic=vpc-dh-profiles&interface=ui)."
}

###########################################################################
# Existing Bastion Support variables
###########################################################################

variable "existing_bastion_instance_name" {
  type        = string
  default     = null
  description = "Provide the name of the bastion instance. If none given then new bastion will be created."
  validation {
    condition = var.existing_bastion_instance_name == null || (
      var.existing_bastion_instance_public_ip != null &&
      var.existing_bastion_security_group_id != null &&
      var.existing_bastion_ssh_private_key != null
    )
    error_message = "If bastion_instance_name is set, then bastion_instance_public_ip, bastion_security_group_id, and bastion_ssh_private_key must also be provided."
  }
}

variable "existing_bastion_instance_public_ip" {
  type        = string
  default     = null
  description = "Provide the public ip address of the existing bastion instance to establish the remote connection. Also using this public ip address, connection to the LSF cluster nodes shall be established"
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

variable "sccwp_enable" {
  type        = bool
  default     = true
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
    error_message = "Plan for App configuration can only be basic, standardv2, enterprise.."
    condition = contains(
      ["basic", "standardv2", "enterprise"],
      var.app_config_plan
    )
  }
}
