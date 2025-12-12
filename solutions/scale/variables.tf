##############################################################################
# Offering Variations
##############################################################################

variable "ibm_customer_number" {
  type        = string
  sensitive   = true
  default     = null
  description = "IBM Customer Number (ICN) used for Bring Your Own License (BYOL) entitlement check and not required if storage_type is evaluation, but must be provided if storage_type is vsi or baremetal. Failing to provide an ICN will cause the deployment to fail to decrypt the packages. For more information on how to find your ICN, see [What is my IBM Customer Number (ICN)?](https://www.ibm.com/support/pages/what-my-ibm-customer-number-icn)."
  # Format validation - Only if value is not null
  validation {
    condition = (
      var.ibm_customer_number == null ||
      can(regex("^[0-9]+(,[0-9]+)*$", var.ibm_customer_number))
    )
    error_message = "The IBM customer number must be a comma-separated list of numeric values with no alphabets and special characters."
  }

  # Presence validation - Must be set when storage_type is not evaluation
  validation {
    condition = (
      var.storage_type == "evaluation" || var.ibm_customer_number != null
    )
    error_message = "The IBM customer number cannot be null when storage_type is 'vsi' or 'baremetal'."
  }
}


##############################################################################
# Account Variables
##############################################################################
variable "ibmcloud_api_key" {
  type        = string
  sensitive   = true
  description = "Provide the IBM Cloud API key for the account where the IBM Storage Scale cluster will be deployed, this is a required value that must be provided as it is used to authenticate and authorize access during the deployment. For instructions on creating an API key, see [Managing user API keys](https://cloud.ibm.com/docs/account?topic=account-userapikey&interface=ui)."
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
  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[1-3]$", var.zones[0]))
    error_message = "Provide a value from the supported regions."
  }
}

variable "ssh_keys" {
  type        = list(string)
  default     = null
  description = "Provide the names of the SSH keys already configured in your IBM Cloud account to enable access to the Storage Scale nodes. The solution does not create new SSH keys, so ensure you provide existing ones. These keys must reside in the same resource group and region as the cluster being provisioned.To provide multiple SSH keys, use a comma-separated list in the format: [\"key-name-1\", \"key-name-2\"]. If you do not have an SSH key in your IBM Cloud account, you can create one by following the instructions [SSH Keys](https://cloud.ibm.com/docs/vpc?topic=vpc-ssh-keys)."
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
      for a in var.remote_allowed_ips : can(regex("^((25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9][0-9]|[0-9])\\.){3}(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9][0-9]|[0-9])(/(3[0-2]|2[0-9]|1[0-9]|[0-9]))?$", a))

    ])
    error_message = "The provided IP address format is not valid. Check if the IP address contains a comma instead of a dot, and ensure there are double quotation marks between each IP address range if using multiple IP ranges. For multiple IP address, use the format [\"169.45.117.34\",\"128.122.144.145\"]."
  }
}

variable "cluster_prefix" {
  type        = string
  default     = "scale"
  description = "Prefix that is used to name the IBM Cloud resources that are provisioned to build the Storage Scale cluster. Make sure that the prefix is unique, since you cannot create multiple resources with the same name. The maximum length of supported characters is 64. Preifx must begin with a letter and end with a letter or number."
  validation {
    error_message = "Prefix must begin with a lower case letter, should not end with '-' and contain only lower case letters, numbers, and '-' characters."
    condition     = can(regex("^[a-z](?:[a-z0-9]*(-[a-z0-9]+)*)?$", var.cluster_prefix))
  }
  validation {
    condition     = length(trimspace(var.cluster_prefix)) > 0 && length(var.cluster_prefix) <= 16
    error_message = "The cluster_prefix must be 16 characters or fewer. No spaces allowed. "
  }
}

##############################################################################
# Resource Groups Variables
##############################################################################
variable "existing_resource_group" {
  type        = string
  default     = "Default"
  description = "Specify the name of the existing resource group in your IBM Cloud account where cluster resources will be deployed. By default, the resource group is set to 'Default.' In some older accounts, it may be 'default,' so please verify the resource group name before proceeding. If the value is set to \"null\", the automation will create two separate resource groups: 'workload-rg' and 'service-rg.' For more details, see [Managing resource groups](https://cloud.ibm.com/docs/account?topic=account-rgs&interface=ui)."
  validation {
    condition     = var.existing_resource_group != null && length(trimspace(var.existing_resource_group)) > 0 && var.existing_resource_group == trimspace(var.existing_resource_group)
    error_message = "If you want to provide null for resource_group variable, it should be within double quotes and must not be null, empty, or contain leading/trailing spaces"
  }
}

##############################################################################
# VPC Variables
##############################################################################
variable "vpc_name" {
  type        = string
  default     = null
  description = "Provide the name of an existing VPC in which the cluster resources will be deployed. If no value is given, the solution provisions a new VPC. [Learn more](https://cloud.ibm.com/docs/vpc). You can also choose to use existing subnets under this VPC or let the solution create new subnets as part of the deployment. If a custom DNS resolver is already configured for your VPC, specify its ID under the dns_custom_resolver_id input value."
}

variable "vpc_cidr" {
  type        = string
  default     = "10.241.0.0/18"
  description = "Provide an address prefix to create a new VPC when the vpc_name variable is set to null. VPC will be created using this address prefix, and subnets can then be defined within it using the specified subnet CIDR blocks. For more information on address prefix, see [Setting IP ranges](https://cloud.ibm.com/docs/vpc?topic=vpc-vpc-addressing-plan-design)."
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
    image   = "ibm-ubuntu-22-04-5-minimal-amd64-8"
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
  description = "Bastion node functions as a jump server to enable secure SSH access to cluster nodes, ensuring controlled connectivity within the private network. Specify the configuration details for the bastion node, including the image and instance profile. Only Ubuntu 22.04 stock images are supported."
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
    image   = "hpcc-scale-deployer-v2"
    profile = "bx2-8x32"
  }
  validation {
    condition     = can(regex("^(b|c|m)x[0-9]+d?-[0-9]+x[0-9]+$", var.deployer_instance.profile))
    error_message = "The profile must be a valid virtual server instance profile and must be from the Balanced, Compute, Memory Categories"
  }
  description = "A deployer node is a dedicated virtual machine or server instance used to automate the deployment and configuration of infrastructure and applications for HPC cluster components. Specify the configuration for the deployer node, including the custom image and virtual server instance profile."
}

##############################################################################
# Compute Variables
##############################################################################
variable "login_subnets_cidr" {
  type        = string
  default     = "10.241.16.0/28"
  description = "Provide the CIDR block required for the creation of the login cluster private subnet. Single CIDR block is required. If using a hybrid environment, modify the CIDR block to avoid conflicts with any on-premises CIDR blocks. Since the login subnet is used only for the creation of login virtual server instances, provide a CIDR range of /28."
  validation {
    condition = (
      can(
        regex(
          "^((25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])\\.){3}(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])/(3[0-2]|[12]?[0-9])$", trimspace(var.login_subnets_cidr)
        )
      )
    )
    error_message = "login_node_cidr must be a valid IPv4 CIDR (e.g., 192.168.1.0/28)."
  }

  validation {
    condition = can(
      regex(
        "^((25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])\\.){3}(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])/(2[8-9]|3[0-2])$", trimspace(var.login_subnets_cidr)
      )
    )
    error_message = "This subnet is used to create only a login virtual server instance. Providing a larger CIDR size will waste the usage of available IPs. A CIDR range of /28 is sufficient for the creation of the login subnet."
  }
}

variable "compute_subnets_cidr" {
  type        = string
  default     = "10.241.0.0/20"
  description = "Provide the CIDR block required for the creation of the compute private subnet. Single CIDR block is required. If using a hybrid environment, modify the CIDR block to avoid conflicts with any on-premises CIDR blocks. Ensure the selected CIDR block size can accommodate the maximum number of scale compute nodes expected in your cluster. For more information on CIDR block size selection, refer to the documentation, see [Choosing IP ranges for your VPC](https://cloud.ibm.com/docs/vpc?topic=vpc-choosing-ip-ranges-for-your-vpc)."
}

variable "storage_subnets_cidr" {
  type        = string
  default     = "10.241.30.0/24"
  description = "Provide the CIDR block required for the creation of the storage private subnet. Single CIDR block is required. If using a hybrid environment, modify the CIDR block to avoid conflicts with any on-premises CIDR blocks. Ensure the selected CIDR block size can accommodate the maximum number of scale storage nodes expected in your cluster. For more information on CIDR block size selection, refer to the documentation, see [Choosing IP ranges for your VPC](https://cloud.ibm.com/docs/vpc?topic=vpc-choosing-ip-ranges-for-your-vpc)."
}

variable "protocol_subnets_cidr" {
  type        = string
  default     = "10.241.40.0/24"
  description = "Provide the CIDR block required for the creation of the protocol private subnet. Single CIDR block is required. If using a hybrid environment, modify the CIDR block to avoid conflicts with any on-premises CIDR blocks. Ensure the selected CIDR block size can accommodate the maximum number of protocol nodes expected in your cluster. For more information on CIDR block size selection, refer to the documentation, see [Choosing IP ranges for your VPC](https://cloud.ibm.com/docs/vpc?topic=vpc-choosing-ip-ranges-for-your-vpc)."
}

variable "client_subnets_cidr" {
  type        = string
  default     = "10.241.50.0/24"
  description = "Provide the CIDR block required for the creation of the client private subnet. Single CIDR block is required. If using a hybrid environment, modify the CIDR block to avoid conflicts with any on-premises CIDR blocks. Ensure the selected CIDR block size can accommodate the maximum number of scale client nodes expected in your cluster. For more information on CIDR block size selection, refer to the documentation, see [Choosing IP ranges for your VPC](https://cloud.ibm.com/docs/vpc?topic=vpc-choosing-ip-ranges-for-your-vpc)."
}

variable "compute_gui_username" {
  type        = string
  default     = ""
  sensitive   = true
  description = "GUI username to perform system management and monitoring tasks on the compute cluster. The Username should be at least 4 characters, (any combination of lowercase and uppercase letters)."
  validation {
    condition     = sum([for inst in var.compute_instances : inst.count]) == 0 || (length(var.compute_gui_username) >= 4 && length(var.compute_gui_username) <= 30 && trimspace(var.compute_gui_username) != "")
    error_message = "Specified input for \"compute_gui_username\" is not valid. Username should be greater or equal to 4 letters and less than equal to 30."
  }
  validation {
    # Structural check
    condition = sum([for inst in var.compute_instances : inst.count]) == 0 || can(regex("^[A-Za-z0-9]([._]?[A-Za-z0-9])*$", var.compute_gui_username))

    error_message = "Specified input for \"compute_gui_username\" is not valid. Username should only have alphanumerics, dot(.) and underscore(_). No consecutive dots or underscores"
  }
}

variable "compute_gui_password" {
  type        = string
  default     = ""
  sensitive   = true
  description = "Password for logging in to the compute cluster GUI. Must be at least 8 characters long and include a combination of uppercase and lowercase letters, a number, and a special character. It must not contain the username or start with a special character."
  validation {
    condition = (
      sum([for inst in var.compute_instances : inst.count]) == 0 || can(regex("^.{8,}$", var.compute_gui_password) != "") && can(regex("[0-9]{1,}", var.compute_gui_password) != "") && can(regex("[a-z]{1,}", var.compute_gui_password) != "") && can(regex("[A-Z]{1,}", var.compute_gui_password) != "") && can(regex("[!@#$%^&*()_+=-]{1,}", var.compute_gui_password) != "") && trimspace(var.compute_gui_password) != "" && can(regex("^[!@#$%^&*()_+=-]", var.compute_gui_password)) == false && (replace(lower(var.compute_gui_password), lower(var.compute_gui_username), "") == lower(var.compute_gui_password))
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
    profile    = "bx2-2x8"
    count      = 0
    image      = "hpcc-scale6000-rhel810-v1"
    filesystem = "/gpfs/fs1"
  }]
  validation {
    condition = alltrue([
      for inst in var.compute_instances : can(regex("^(b|c|m)x[0-9]+d?-[0-9]+x[0-9]+$", inst.profile))
    ])
    error_message = "Specified profile must be a valid IBM Cloud VPC GEN2 profile name and must be from the Balanced, Compute, Memory Categories [Learn more](https://cloud.ibm.com/docs/vpc?topic=vpc-profiles)."
  }
  validation {
    condition = alltrue([
      for inst in var.compute_instances : inst.count == 0 || (inst.count >= 3 && inst.count <= 64)
    ])
    error_message = "Specified count must be 0 or in range 3 to 64"
  }
  description = "Specify the list of virtual server instances to be provisioned as compute nodes in the cluster. Each object includes the instance profile (machine type), number of instances (count), OS image to use, and an optional filesystem mount path. This configuration allows customization of the compute tier to suit specific performance and workload requirements. The profile must match a valid IBM Cloud VPC Gen2 instance profile format. A minimum of 3 compute nodes is required to form a cluster, and a maximum of 64 nodes is supported. For more details, refer[Instance Profiles](https://cloud.ibm.com/docs/vpc?topic=vpc-profiles&interface=ui)."
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
  validation {
    condition = alltrue([
      for inst in var.client_instances : can(regex("^(b|c|m)x[0-9]+d?-[0-9]+x[0-9]+$", inst.profile))
    ])
    error_message = "Specified profile must be a valid IBM Cloud VPC GEN2 profile name and must be from the Balanced, Compute, Memory Categories (e.g., bx2-4x16, cx2d-16x64). [Learn more](https://cloud.ibm.com/docs/vpc?topic=vpc-profiles)"
  }
  validation {
    condition = alltrue([
      for inst in var.client_instances : inst.count >= 0 && inst.count <= 2000
    ])
    error_message = "client_instances 'count' value must be between 0 and 2000."
  }

  description = "Specify the list of virtual server instances to be provisioned as client nodes in the cluster. Each object includes the instance profile (machine type), number of instances (count), OS image to use. This configuration allows customization of the compute tier to suit specific performance and workload requirements. The profile must match a valid IBM Cloud VPC Gen2 instance profile format. For more details, refer [Instance Profiles](https://cloud.ibm.com/docs/vpc?topic=vpc-profiles&interface=ui)."
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
    profile    = "bx2-32x128"
    count      = 2
    image      = "hpcc-scale6000-rhel810-v1"
    filesystem = "/gpfs/fs1"
  }]
  validation {
    condition = var.storage_type != "baremetal" ? alltrue([
      for inst in var.storage_instances : can(regex("^(b|c|m)x[0-9]-[0-9]+x[0-9]+$", inst.profile))
    ]) : true
    error_message = "Specified profile must be a valid IBM Cloud VPC GEN2 profile name and must be from the Balanced, Compute, Memory Categories (e.g., bx2d-4x16, cx2d-16x64). [Learn more](https://cloud.ibm.com/docs/vpc?topic=vpc-profiles)"
  }
  validation {
    condition = alltrue([
      for inst in var.storage_instances : inst.count % 2 == 0
    ])
    error_message = "Storage count should always be an even number."
  }
  validation {
    condition = var.storage_type != "baremetal" ? alltrue([
      for inst in var.storage_instances : inst.count >= 2 && inst.count <= 64
    ]) : true
    error_message = "storage_instances 'count' value must be in range 2 to 64."
  }
  description = "Specify the list of virtual server instances to be provisioned as storage nodes in the cluster. Each object includes the instance profile (machine type), number of instances (count), OS image to use, and an optional filesystem mount path. This configuration allows customization of the storage tier to suit specific storage performance cluster. The profile must match a valid IBM Cloud VPC Gen2 instance profile format. A minimum of 2 storage nodes is required to form a cluster, and a maximum of 64 nodes is supported. For more details, refer[Instance Profiles](https://cloud.ibm.com/docs/vpc?topic=vpc-profiles&interface=ui)."
}

variable "storage_baremetal_server" {
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
    count      = 2
    image      = "hpcc-scale6000-rhel810-v1"
    filesystem = "/gpfs/fs1"
  }]

  validation {
    condition = var.storage_type == "baremetal" ? alltrue([
      for inst in var.storage_baremetal_server : can(regex("^[b|c|m]x[0-9]+d?-[a-z]+-[0-9]+x[0-9]+", inst.profile))
    ]) : true
    error_message = "Specified profile must be a valid IBM Cloud VPC GEN2 profile name [Learn more](https://cloud.ibm.com/docs/vpc?topic=vpc-profiles)."
  }

  validation {
    condition = var.storage_type == "baremetal" ? alltrue([
      for inst in var.storage_baremetal_server : inst.count >= 2 && inst.count <= 64
    ]) : true
    error_message = "Each storage_baremetal_server 'count' value must be between 2 and 64."
  }

  validation {
    condition = alltrue([
      for inst in var.storage_baremetal_server : inst.count % 2 == 0
    ])
    error_message = "Storage_baremetal_server count should always be an even number."
  }

  description = "Specify the list of bare metal servers to be provisioned for the storage cluster. Each object in the list specifies the server profile (hardware configuration), the count (number of servers), the image (OS image to use), and an optional filesystem mount path. This configuration allows flexibility in scaling and customizing the storage cluster based on performance and capacity requirements. Only valid bare metal profiles supported in IBM Cloud VPC should be used. A minimum of 2 baremetal storage nodes is required to form a cluster, and a maximum of 64 nodes is supported For available bare metal profiles, refer to the [Baremetal Profiles](https://cloud.ibm.com/docs/vpc?topic=vpc-bare-metal-servers-profile&interface=ui)."
}

variable "tie_breaker_baremetal_server_profile" {
  type        = string
  default     = null
  description = "Specify the bare metal server profile type name to be used for creating the bare metal Tie breaker node. If no value is provided, the storage bare metal server profile will be used as the default. For more information, see [bare metal server profiles](https://cloud.ibm.com/docs/vpc?topic=vpc-bare-metal-servers-profile&interface=ui). [Tie Breaker Node](https://www.ibm.com/docs/en/storage-scale/5.2.2?topic=quorum-node-tiebreaker-disks)"
}

variable "scale_management_vsi_profile" {
  type        = string
  default     = "bx2-8x32"
  description = "The virtual server instance profile type name to be used to create the Management node. For more information, see [Instance Profiles](https://cloud.ibm.com/docs/vpc?topic=vpc-profiles&interface=ui)."
  validation {
    condition     = can(regex("^[b|c|m]x[0-9]+d?-[0-9]+x[0-9]+", var.scale_management_vsi_profile))
    error_message = "Specified profile must be a valid IBM Cloud VPC GEN2 Instance Storage profile name [Learn more](https://cloud.ibm.com/docs/vpc?topic=vpc-profiles)."
  }
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
  validation {
    condition = alltrue([
      for inst in var.afm_instances : can(regex("^[bcm]x[0-9]+d?(-[a-z]+)?-[0-9]+x[0-9]+$", inst.profile))
    ])
    error_message = "Specified profile must be a valid IBM Cloud VPC GEN2 profile name and must be from the Balanced, Compute, Memory Categories [Learn more](https://cloud.ibm.com/docs/vpc?topic=vpc-profiles)."
  }
  validation {
    condition = alltrue([
      for inst in var.afm_instances : inst.count >= 0 && inst.count <= 16
    ])
    error_message = "afm_instances 'count' value must be between 0 and 16."
  }
  description = "Specify the list of virtual server instances to be provisioned as AFM nodes in the cluster. Each object in the list includes the instance profile (machine type), the count (number of instances), the image (OS image to use). This configuration allows you to access remote data  and high-performance computing needs.This input can be used to provision virtual server instances (VSI). If baremetal, high-throughput storage is required, consider using bare metal instances instead. Ensure you provide valid instance profiles. Maximum of 16 afm nodes is supported. For more details, refer to [Instance Profiles](https://cloud.ibm.com/docs/vpc?topic=vpc-profiles&interface=ui)."
}


variable "protocol_instances" {
  type = list(
    object({
      profile = string
      count   = number
    })
  )
  default = [{
    profile = "cx2-32x64"
    count   = 2
  }]
  validation {
    condition = alltrue([
      for inst in var.protocol_instances : can(regex("^[bcm]x[0-9]+d?(-[a-z]+)?-[0-9]+x[0-9]+$", inst.profile))
    ])
    error_message = "Specified profile must be a valid IBM Cloud VPC GEN2 profile name [Learn more](https://cloud.ibm.com/docs/vpc?topic=vpc-profiles)."
  }
  validation {
    condition = alltrue([
      for inst in var.protocol_instances : inst.count >= 0 && inst.count <= 32
    ])
    error_message = "protocol_instances 'count' value must be between 0 and 32."
  }
  description = "Specify the list of virtual server instances to be provisioned as protocol nodes in the cluster. Each object in the list includes the instance profile (machine type), the count (number of instances), the image (OS image to use). This configuration allows allows for a unified data management solution, enabling different clients to access the same data using NFS protocol.This input can be used to provision virtual server instances (VSI). If baremetal, high-throughput storage is required, consider using bare metal instances instead. Ensure you provide valid instance profiles. Maximum of 32 VSI or baremetal nodes are supported. For more details, refer to [Instance Profiles](https://cloud.ibm.com/docs/vpc?topic=vpc-profiles&interface=ui)."
}

variable "colocate_protocol_instances" {
  type        = bool
  default     = true
  description = "Enable this option to colocate protocol services on the same virtual server instances used for storage. When set to true, the storage nodes will also act as protocol nodes for reducing the need for separate infrastructure. This can optimize resource usage and simplify the cluster setup, especially for smaller environments or cost-sensitive deployments. For larger or performance-intensive workloads, consider deploying dedicated protocol instances instead."
  validation {
    condition     = anytrue([var.colocate_protocol_instances == true && var.storage_type != "baremetal" && sum(var.protocol_instances[*]["count"]) <= sum(var.storage_instances[*]["count"]), var.colocate_protocol_instances == true && var.storage_type == "baremetal" && sum(var.protocol_instances[*]["count"]) <= sum(var.storage_baremetal_server[*]["count"]), var.colocate_protocol_instances == false])
    error_message = "When colocation is true, protocol instance count should always be less than or equal to storage instance count"
  }
}

variable "storage_gui_username" {
  type        = string
  default     = ""
  sensitive   = true
  description = "GUI username to perform system management and monitoring tasks on the storage cluster. Note: Username should be at least 4 characters, (any combination of lowercase and uppercase letters)."
  validation {
    condition     = length(var.storage_gui_username) >= 4 && length(var.storage_gui_username) <= 30 && trimspace(var.storage_gui_username) != ""
    error_message = "Specified input for \"storage_gui_username\" is not valid. Username should be greater or equal to 4 letters and less than equal to 30."
  }
  validation {
    # Structural check
    condition = can(regex("^[A-Za-z0-9]([._]?[A-Za-z0-9])*$", var.storage_gui_username))

    error_message = "Specified input for \"storage_gui_username\" is not valid. Username should only have alphanumerics, dot(.) and underscore(_). No consecutive dots or underscores"
  }
}

variable "storage_gui_password" {
  type        = string
  default     = ""
  sensitive   = true
  description = "The storage cluster GUI password is used for logging in to the storage cluster through the GUI. The password should contain a minimum of 8 characters. For a strong password, use a combination of uppercase and lowercase letters, one number, and a special character. Make sure that the password doesn't contain the username and it should not start with a special character."
  validation {
    condition     = can(regex("^.{8,20}$", var.storage_gui_password) != "") && can(regex("[0-9]", var.storage_gui_password) != "") && can(regex("[a-z]", var.storage_gui_password) != "") && can(regex("[A-Z]", var.storage_gui_password) != "") && can(regex("[!@#$%^&*()_+=-]", var.storage_gui_password) != "") && trimspace(var.storage_gui_password) != "" && can(regex("^[!@#$%^&*()_+=-]", var.storage_gui_password)) == false && can(regex(lower(var.storage_gui_username), lower(var.storage_gui_password))) == false
    error_message = "The Storage GUI password must be 8 to 20 characters long and include at least two alphabetic characters (with one uppercase and one lowercase), one number, and one special character from the set (!@#$%^&*()_+=-). The password must not contain the username or any spaces."
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
    filesystem               = "/gpfs/fs1"
    block_size               = "4M"
    default_data_replica     = 2
    default_metadata_replica = 2
    max_data_replica         = 3
    max_metadata_replica     = 3
  }]
  description = "Specify the configuration parameters for one or more IBM Storage Scale (GPFS) filesystems. Each object in the list includes the filesystem mount point, block size, and replica settings for both data and metadata. These settings determine how data is distributed and replicated across the cluster for performance and fault tolerance."
  validation {
    condition = alltrue([
      for fs in var.filesystem_config :

      fs.default_data_replica >= 1 &&
      fs.default_data_replica <= 3 &&
      fs.max_data_replica >= 1 &&
      fs.max_data_replica <= 3 &&

      fs.default_metadata_replica >= 1 &&
      fs.default_metadata_replica <= 3 &&
      fs.max_metadata_replica >= 1 &&
      fs.max_metadata_replica <= 3 &&

      fs.max_data_replica > fs.default_data_replica &&
      fs.max_metadata_replica > fs.default_metadata_replica
    ])
    error_message = "In filesystem_config, replica values must be between 1 and 3. Additionally, max_data_replica must be greater than default_data_replica, and max_metadata_replica must be greater than default_metadata_replica."
  }
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
  nullable    = false
  description = "Please provide details for the Cloud Object Storage (COS) instance, including information about the COS bucket, service credentials (HMAC key), AFM fileset, mode (such as Read-only (RO), Single writer (SW), Local updates (LU), and Independent writer (IW)), storage class (standard, vault, cold, or smart), and bucket type (single_site_location, region_location, cross_region_location). Note : The 'afm_cos_config' can contain up to 5 entries. For further details on COS bucket locations, refer to the relevant documentation https://cloud.ibm.com/docs/cloud-object-storage/basics?topic=cloud-object-storage-endpoints."
  validation {
    condition     = length([for item in var.afm_cos_config : item]) >= 1 && length([for item in var.afm_cos_config : item]) <= 5
    error_message = "The length of \"afm_cos_config\" must be greater than or equal to 1 and less than or equal to 5."
  }
  validation {
    condition     = alltrue([for item in var.afm_cos_config : trimspace(item.mode) != "" && item.mode != null])
    error_message = "The \"mode\" field must not be empty or null."
  }
  validation {
    condition     = length(distinct([for item in var.afm_cos_config : item.afm_fileset])) == length(var.afm_cos_config)
    error_message = "The \"afm_fileset\" name should be unique for each AFM COS bucket relation."
  }
  validation {
    condition     = alltrue([for item in var.afm_cos_config : trimspace(item.afm_fileset) != "" && item.afm_fileset != null])
    error_message = "The \"afm_fileset\" field must not be empty or null."
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
    condition     = alltrue([for item in var.afm_cos_config : trimspace(item.bucket_region) != "" && item.bucket_region != null])
    error_message = "The \"bucket_region\" field must not be empty or null."
  }
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
    ppnlb    = string
  })
  default = {
    compute  = "comp.com"
    storage  = "strg.com"
    protocol = "ces.com"
    client   = "clnt.com"
    gklm     = "gklm.com"
    ppnlb    = "strgscale.private"
  }
  description = "DNS domain names are user-friendly addresses that map to systems within a network, making them easier to identify and access. Provide the DNS domain names for IBM Cloud HPC components: compute, storage, protocol, client, and GKLM. These domains will be assigned to the respective nodes that are part of the scale cluster."
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
  description = "Set this option to true to enable LDAP for IBM Spectrum Scale (GPFS), with the default value set to false."
}

variable "ldap_basedns" {
  type        = string
  default     = "ldapscale.com"
  description = "The dns domain name is used for configuring the LDAP server. If an LDAP server is already in existence, ensure to provide the associated DNS domain name."
  validation {
    condition     = var.enable_ldap == false || (var.ldap_basedns != null ? (length(trimspace(var.ldap_basedns)) > 3 && length(var.ldap_basedns) <= 253 && var.ldap_basedns != "null" && !startswith(trimspace(var.ldap_basedns), "www.") && can(regex("^[a-zA-Z0-9]+([a-zA-Z0-9.]*[a-zA-Z0-9]+)*([a-zA-Z0-9]+[a-zA-Z0-9-]*[a-zA-Z0-9]+)*\\.[a-zA-Z]{2,63}$", trimspace(var.ldap_basedns)))) : false)
    error_message = "If LDAP is enabled, then the base DNS should not be empty or null. Furthermore, DNS provided should be a properly formatted domain name (without www. prefix), between 4-253 characters, and matches standard DNS naming rules."
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
    condition     = var.enable_ldap == true && var.ldap_server != null ? var.ldap_server_cert != null : true
    error_message = "Provide the current LDAP server certificate. This is required if 'ldap_server' is set; otherwise, the LDAP configuration will not succeed."
  }
}

variable "ldap_admin_password" {
  type        = string
  sensitive   = true
  default     = null
  description = "The LDAP admin password must be 8 to 20 characters long and include at least two alphabetic characters (with one uppercase and one lowercase), one number, and one special character from the set (!@#$%^&*()_+=-). The password must not contain the username or any spaces. [This value is ignored for an existing LDAP server]."
  validation {
    condition = (
      var.enable_ldap ? (
        var.ldap_admin_password != null ? (
          try(length(var.ldap_admin_password)) >= 8 &&
          try(length(var.ldap_admin_password)) <= 20 &&
          try(can(regex(".*[0-9].*", var.ldap_admin_password)), false) &&
          try(can(regex(".*[A-Z].*", var.ldap_admin_password)), false) &&
          try(can(regex(".*[a-z].*", var.ldap_admin_password)), false) &&
          try(can(regex(".*[!@#$%^&*()_+=-].*", var.ldap_admin_password)), false) &&
          !try(can(regex(".*\\s.*", var.ldap_admin_password)), false)
        ) : false
      ) : true
    )
    error_message = "LDAP admin password must be provided whenever LDAP is enabled. The LDAP admin password must be 8 to 20 characters long and include at least two alphabetic characters (with one uppercase and one lowercase), one number, and one special character from the set (!@#$%^&*()_+=-). The password must not contain any spaces."
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
    image   = "ibm-ubuntu-22-04-5-minimal-amd64-8"
  }]
  description = "Specify the list of virtual server instances to be provisioned as ldap nodes in the cluster. Each object in the list defines the instance profile (machine type), the count (number of instances), the image (OS image to use). This configuration allows you to customize the server for setting up ldap server. The profile must match a valid IBM Cloud VPC Gen2 instance profile format. For more details, refer [Instance Profiles](https://cloud.ibm.com/docs/vpc?topic=vpc-profiles&interface=ui)."
  validation {
    condition = alltrue([
      for inst in var.ldap_instance : can(regex("^(b|c|m)x[0-9]+d?-[0-9]+x[0-9]+$", inst.profile))
    ])
    error_message = "Specified profile must be a valid IBM Cloud VPC GEN2 profile name [Learn more](https://cloud.ibm.com/docs/vpc?topic=vpc-profiles)."
  }
  validation {
    condition = alltrue([
      for inst in var.ldap_instance : can(regex("^ibm-ubuntu", inst.image))
    ])
    error_message = "Specified image should necessarily be an IBM Ubuntu image [Learn more](https://cloud.ibm.com/docs/vpc?group=stock-images)."
  }
}


##############################################################################
# GKLM variables
##############################################################################
variable "scale_encryption_enabled" {
  type        = bool
  default     = false
  description = "Encryption ensures that data stored in the filesystem is protected from unauthorized access and secures sensitive information at rest. To enable the encryption for the filesystem. Select true or false"
}

variable "scale_encryption_type" {
  type        = string
  default     = "null"
  description = "To enable filesystem encryption, specify either 'key_protect' or 'gklm'. If neither is specified, the default value will be 'null' and encryption is disabled"

  validation {
    condition     = can(regex("^(key_protect|gklm|null)$", var.scale_encryption_type)) && (var.scale_encryption_type == "null" || var.scale_encryption_enabled) && (!var.scale_encryption_enabled || var.scale_encryption_type != "null")
    error_message = <<EOT
    Invalid encryption configuration:
    1. Encryption type must be 'key_protect', 'gklm', or 'null'
    2. When encryption is enabled (true), type must be 'key_protect' or 'gklm'
    3. When encryption is disabled (false), type must be 'null'
    EOT
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
    image   = "hpcc-scale-gklm4202-v2-5-3"
  }]
  validation {
    condition = (
      var.scale_encryption_type != "gklm" ||
      alltrue([
        for inst in var.gklm_instances : can(regex("^(b|c|m)x[0-9]+d?-[0-9]+x[0-9]+$", inst.profile)) &&
        inst.count >= 2 && inst.count <= 5
      ])
    )
    error_message = "Specified profile must be a valid IBM Cloud VPC GEN2 profile name [Learn more](https://cloud.ibm.com/docs/vpc?topic=vpc-profiles)."
  }
  validation {
    condition = (var.scale_encryption_type != "gklm" || (sum([for inst in var.gklm_instances : inst.count]) >= 2 && sum([for inst in var.gklm_instances : inst.count]) <= 5))
    #condition   = (sum([for inst in var.gklm_instances : inst.count]) == 0 || (sum([for inst in var.gklm_instances : inst.count]) >= 2 && sum([for inst in var.gklm_instances : inst.count]) <= 5))
    error_message = "For High availability the GKLM instance type should be greater than 2 or less than 5"
  }
  description = "Specify the list of virtual server instances to be provisioned as GKLM (Guardium Key Lifecycle Manager) nodes in the cluster. Each object in the list includes the instance profile (machine type), the count (number of instances), and the image (OS image to use).  This configuration allows you to  manage and securely store encryption keys used across the cluster components. The profile must match a valid IBM Cloud VPC Gen2 instance profile format. A minimum of 2 and maximum of 5 gklm nodes are supported. For more details, refer[Instance Profiles](https://cloud.ibm.com/docs/vpc?topic=vpc-profiles&interface=ui)."
}

variable "scale_encryption_admin_password" {
  type        = string
  sensitive   = true
  default     = null
  description = "Specifies the administrator password for GKLM-based encryption. This is required when encryption is enabled for IBM Spectrum Scale (GPFS) and the encryption type is set to 'gklm'. The password is used to authenticate administrative access to the Guardium Key Lifecycle Manager (GKLM) for managing encryption keys. Ensure the password meets your organization's security standards."

  validation {
    condition = (
      var.scale_encryption_enabled && var.scale_encryption_type == "gklm"
      ? (
        var.scale_encryption_admin_password != null &&
        length(var.scale_encryption_admin_password) >= 8 &&
        length(var.scale_encryption_admin_password) <= 20 &&
        can(regex(".*[0-9].*", var.scale_encryption_admin_password)) &&
        can(regex(".*[A-Z].*", var.scale_encryption_admin_password)) &&
        can(regex(".*[a-z].*", var.scale_encryption_admin_password)) &&
        can(regex(".*[!@#$%^&*()_+=-].*", var.scale_encryption_admin_password)) &&
        !can(regex(".*\\s.*", var.scale_encryption_admin_password)) # no spaces
      )
      : true
    )

    error_message = "You must provide scale_encryption_admin_password when scale_encryption_enabled is true and scale_encryption_type is 'gklm'. The scale encryption admin password must be 8 to 20 characters long and include at least two alphabetic characters (with one uppercase and one lowercase), one number, and one special character from the set (!@#$%^&*()_+=-). The password must not contain any spaces."
  }
}

# Existing Key Protect Instance Details

variable "key_protect_instance_id" {
  type        = string
  default     = null
  description = "Provide the ID of an existing IBM Key Protect instance to be used for filesystem encryption in IBM Storage Scale. If this value is provided, the automation will use the existing Key Protect instance and create a new encryption key within it. If not provided, a new Key Protect instance will be created automatically during deployment."
}

variable "storage_type" {
  type        = string
  default     = "vsi"
  description = "Select the Storage Scale file system deployment method. Note: The Storage Scale vsi and evaluation type deploys the Storage Scale file system on virtual server instances, and the baremetal type deploys the Storage Scale file system on bare metal servers."
  validation {
    condition     = can(regex("^(vsi|baremetal|evaluation)$", lower(var.storage_type)))
    error_message = "The solution only support vsi, evaluation, and baremetal; provide any one of the value."
  }
  validation {
    condition     = var.storage_type == "baremetal" ? contains(["us-south-1", "us-south-2", "us-south-3", "us-east-1", "us-east-2", "eu-de-1", "eu-de-2", "eu-de-3", "eu-gb-1", "eu-es-3", "eu-es-1", "jp-tok-2", "jp-tok-3", "ca-tor-2", "ca-tor-3"], join(",", var.zones)) : true
    error_message = "The solution supports bare metal server creation in only given availability zones i.e. us-south-1, us-south-3, us-south-2, eu-de-1, eu-de-2, eu-de-3, jp-tok-2, eu-gb-1, us-east-1, us-east-2, eu-es-3, eu-es-1, jp-tok-3, jp-tok-2, ca-tor-2 and ca-tor-3. To deploy baremetal storage provide any one of the supported availability zones."
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
    error_message = "Plan for App configuration can only be basic, standardv2, enterprise.."
    condition = contains(
      ["basic", "standardv2", "enterprise"],
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
  description = "Enable or disable encryption for the boot drive of bare metal servers. When set to true, the boot drive will be encrypted to enhance data security, protecting the operating system and any sensitive information stored on the root volume. This is especially recommended for workloads with strict compliance or security requirements. Set to false to disable boot drive encryption."
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
  description = "Provide the security group name to provision the storage nodes. If set to null, the solution will automatically create the necessary security group and rules. If you choose to use an existing security group, ensure it has the appropriate rules configured for the storage nodes to function properly. When using existing security groups, you must provide the corresponding group names for all other associated components as well."
  validation {
    condition     = anytrue([var.vpc_name != null && var.storage_security_group_name != null, var.storage_security_group_name == null])
    error_message = "If the storage_security_group_name are provided, the user should also provide the vpc_name."
  }
}

variable "compute_security_group_name" {
  type        = string
  default     = null
  description = "Provide the security group name to provision the compute nodes. If set to null, the solution will automatically create the necessary security group and rules. If you choose to use an existing security group, ensure it has the appropriate rules configured for the storage nodes to function properly. When using existing security groups, you must provide the corresponding group names for all other associated components as well"
  validation {
    condition     = anytrue([var.vpc_name != null && var.compute_security_group_name != null, var.compute_security_group_name == null])
    error_message = "If the compute_security_group_name are provided, the user should also provide the vpc_name."
  }
}

variable "client_security_group_name" {
  type        = string
  default     = null
  description = "Provide the security group name to provision the client nodes. If set to null, the solution will automatically create the necessary security group and rules. If you choose to use an existing security group, ensure it has the appropriate rules configured for the storage nodes to function properly. When using existing security groups, you must provide the corresponding group names for all other associated components as well"
  validation {
    condition     = anytrue([var.vpc_name != null && var.client_security_group_name != null, var.client_security_group_name == null])
    error_message = "If the client_security_group_name are provided, the user should also provide the vpc_name."
  }
}

variable "gklm_security_group_name" {
  type        = string
  default     = null
  description = "Provide the security group name to provision the gklm nodes. If set to null, the solution will automatically create the necessary security group and rules. If you choose to use an existing security group, ensure it has the appropriate rules configured for the storage nodes to function properly. When using existing security groups, you must provide the corresponding group names for all other associated components as well"
  validation {
    condition     = anytrue([var.vpc_name != null && var.gklm_security_group_name != null, var.gklm_security_group_name == null])
    error_message = "If the gklm_security_group_name are provided, the user should also provide the vpc_name."
  }
  validation {
    condition     = anytrue([var.vpc_name != null && var.storage_security_group_name != null && sum(var.gklm_instances[*]["count"]) >= 2 ? (var.gklm_security_group_name != null ? true : false) : true])
    error_message = "If the storage_security_group_name are provided with gklm_instances count more than or equal to 2, the user should also provide the gklm_security_group_name along with vpc_name. Note: Pass the value for gklm_security_group_name as storage_security_group_name."
  }
}

variable "ldap_security_group_name" {
  type        = string
  default     = null
  description = "Provide the security group name to provision the ldap nodes. If set to null, the solution will automatically create the necessary security group and rules. If you choose to use an existing security group, ensure it has the appropriate rules configured for the storage nodes to function properly. When using existing security groups, you must provide the corresponding group names for all other associated components as well"
  validation {
    condition     = anytrue([var.vpc_name != null && var.ldap_security_group_name != null, var.ldap_security_group_name == null])
    error_message = "If the ldap_security_group_name are provided, the user should also provide the vpc_name."
  }
  validation {
    condition     = anytrue([var.vpc_name != null && var.storage_security_group_name != null && var.enable_ldap ? (var.ldap_security_group_name != null ? true : false) : true])
    error_message = "If the storage_security_group_name are provided with enable_ldap as true, the user should also provide the ldap_security_group_name along with vpc_name. Note: Pass the value for ldap_security_group_name as storage_security_group_name."
  }
}

variable "login_subnet_id" {
  type        = string
  default     = null
  description = "Provide ID of an existing subnet to be used for provisioning bastion/deployer node. This is required only when deploying into an existing VPC (i.e., when a value is provided for `vpc_name`). When specifying an existing subnet, ensure that a public gateway is attached to the subnet to enable outbound internet access if required. Additionally, if this subnet ID is provided, you must also provide subnet IDs for all other applicable components (e.g., storage , compute, client, protocol, gklm) to maintain consistency across the deployment."
  validation {
    condition     = anytrue([var.vpc_name != null && var.login_subnet_id != null, var.login_subnet_id == null])
    error_message = "If the login_subnet_id are provided, the user should also provide the vpc_name."
  }
}

variable "compute_subnet_id" {
  type        = string
  default     = null
  description = "Provide ID of an existing subnet to be used for provisioning compute nodes. This is required only when deploying into an existing VPC (i.e., when a value is provided for `vpc_name`). When specifying an existing subnet, ensure that a public gateway is attached to the subnet to enable outbound internet access if required. Additionally, if this subnet ID is provided, you must also provide subnet IDs for all other applicable components (e.g., storage , protocol, client, login, gklm) to maintain consistency across the deployment."
  validation {
    condition     = anytrue([var.vpc_name != null && var.compute_subnet_id != null, var.compute_subnet_id == null])
    error_message = "If the compute_subnet_id are provided, the user should also provide the vpc_name."
  }
}

variable "storage_subnet_id" {
  type        = string
  description = "Provide ID of an existing subnet to be used for storage nodes. This is required only when deploying into an existing VPC (i.e., when a value is provided for `vpc_name`). When specifying an existing subnet, ensure that a public gateway is attached to the subnet to enable outbound internet access if required. Additionally, if this subnet ID is provided, you must also provide subnet IDs for all other applicable components (e.g., compute , protocol, client, login, gklm) to maintain consistency across the deployment."
  default     = null
  validation {
    condition     = anytrue([var.vpc_name != null && var.storage_subnet_id != null, var.storage_subnet_id == null])
    error_message = "If the storage_subnet_id are provided, the user should also provide the vpc_name."
  }
}

variable "protocol_subnet_id" {
  type        = string
  description = "Provide ID of an existing subnet to be used for protocol nodes. This is required only when deploying into an existing VPC (i.e., when a value is provided for `vpc_name`). When specifying an existing subnet, ensure that a public gateway is attached to the subnet to enable outbound internet access if required. Additionally, if this subnet ID is provided, you must also provide subnet IDs for all other applicable components (e.g., storage , compute, client, login, gklm) to maintain consistency across the deployment."
  default     = null
  validation {
    condition     = anytrue([var.vpc_name != null && var.protocol_subnet_id != null, var.protocol_subnet_id == null])
    error_message = "If the protocol_subnet_id are provided, the user should also provide the vpc_name."
  }
}

variable "client_subnet_id" {
  type        = string
  description = "Provide ID of an existing subnet to be used for client nodes. This is required only when deploying into an existing VPC (i.e., when a value is provided for `vpc_name`). When specifying an existing subnet, ensure that a public gateway is attached to the subnet to enable outbound internet access if required. Additionally, if this subnet ID is provided, you must also provide subnet IDs for all other applicable components (e.g., storage , compute, protocol, login, gklm) to maintain consistency across the deployment."
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

variable "volume_storages" {
  description = "Configures the boot and block volumes for each instance. Boot volumes use the SDP profile by default but can be changed to a general-purpose profile if required by the workload. If the boot volume profile is set to general-purpose, the IOPS value should be set to 0 or null, as IOPS are not supported for that profile. Block volumes are always created with the SDP profile to maintain performance standards. You can specify optional boot volume settings (profile, size, IOPS), while block volume capacity and IOPS are mandatory. Both volume types support an optional auto-grow feature that allows disk size to increase automatically when needed through automation."
  type = list(
    object({
      # Boot Volume
      boot_volume_profile   = optional(string)
      boot_volume_size      = optional(number)
      boot_volume_iops      = optional(number)
      boot_volume_disk_grow = optional(bool, false)

      # Block Volume
      block_volume_capacity  = number
      block_volume_iops      = number
      block_volume_disk_grow = optional(bool, false)
    })
  )

  default = [{
    # Boot Volume
    boot_volume_profile   = "sdp"
    boot_volume_size      = 100
    boot_volume_iops      = 3000 # IOPS is not applicable for general-purpose profile
    boot_volume_disk_grow = false
    # Block Volume
    block_volume_capacity  = 500
    block_volume_iops      = 20000
    block_volume_disk_grow = false
  }]

  validation {
    condition = alltrue([
      for v in var.volume_storages : (
        (
          v.boot_volume_profile == null ? true : (
            contains(["sdp", "general-purpose"], v.boot_volume_profile) &&
            (v.boot_volume_size != null && v.boot_volume_size <= 250) &&
            (
              v.boot_volume_profile == "sdp" ?
              # For SDP: IOPS and disk_grow required
              (v.boot_volume_iops != null && v.boot_volume_iops >= 3000 && v.boot_volume_disk_grow != null)
              :
              # For general-purpose: IOPS must be null or 0
              (v.boot_volume_iops == null || v.boot_volume_iops == 0)
            )
          )
        )
        &&
        (
          v.block_volume_capacity == null || v.block_volume_capacity == "" ? true : (
            v.block_volume_iops != null &&
            (v.block_volume_iops >= 3000) &&
            v.block_volume_iops <= (
              v.block_volume_capacity <= 20 ? 3000 :
              v.block_volume_capacity <= 50 ? 5000 :
              v.block_volume_capacity <= 80 ? 20000 :
              v.block_volume_capacity <= 100 ? 30000 :
              v.block_volume_capacity <= 130 ? 45000 :
              v.block_volume_capacity <= 150 ? 60000 :
              64000
            )
          )
        )
      )
    ])

    error_message = <<EOT
Invalid volume_storages configuration:
- You can provide only block, or both sections.
- If boot_volume_profile = "sdp":
    * boot_volume_size, boot_volume_iops (>=3000), and boot_volume_disk_grow are required
- If boot_volume_profile = "general-purpose":
    * boot_volume_iops must be null or 0
- If block_volume_capacity is not null or empty:
    * block_volume_iops must be >= 3000 and within correct range for capacity
EOT
  }
}

variable "enable_private_path_nlb" {
  type        = bool
  default     = false
  description = "When set to true, provisions a private path Network Load Balancer that enables CES (NFS) storage access for the cluster. The private path integrates with the Scale NFS nodes to provide a secure, high-performance method of delivering file storage to clients within the same VPC, ensuring direct and efficient access to the CES storage nodes."
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
