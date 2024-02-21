##############################################################################
# Offering Variations
##############################################################################
# Future use
/*
variable "scheduler" {
  type        = string
  default     = "LSF"
  description = "Select one of the scheduler (LSF/Symphony/Slurm/None)"
}

variable "storage_type" {
  type        = string
  default     = "scratch"
  description = "Select the required storage type(scratch/persistent/eval)."
}
*/

#variable "ibm_customer_number" {
#  type        = string
#  sensitive   = true
#  default     = ""
#  description = "Comma-separated list of the IBM Customer Number(s) (ICN) that is used for the Bring Your Own License (BYOL) entitlement check. For more information on how to find your ICN, see [What is my IBM Customer Number (ICN)?](https://www.ibm.com/support/pages/what-my-ibm-customer-number-icn)."
#  validation {
#    # regex(...) fails if the IBM customer number has special characters.
#    condition     = can(regex("^[0-9A-Za-z]*([0-9A-Za-z]+,[0-9A-Za-z]+)*$", var.ibm_customer_number))
#    error_message = "The IBM customer number input value cannot have special characters."
#  }
#}

##############################################################################
# Account Variables
##############################################################################

variable "ibmcloud_api_key" {
  description = "IBM Cloud API key for the IBM Cloud account where the IBM Cloud HPC cluster needs to be deployed. For more information on how to create an API key, see [Managing user API keys](https://cloud.ibm.com/docs/account?topic=account-userapikey)."
  type        = string
  sensitive   = true
  validation {
    condition     = var.ibmcloud_api_key != ""
    error_message = "The API key for IBM Cloud must be set."
  }  
}

##############################################################################
# Resource Groups Variables
##############################################################################

variable "resource_group" {
  description = "Resource group name from your IBM Cloud account where the VPC resources should be deployed. Note. If the resource group value is set as null, automation creates two different RG with the name (workload-rg and service-rg). For additional information on resource groups, see [Managing resource groups](https://cloud.ibm.com/docs/account?topic=account-rgs)."
  type        = string
  default     = "Default"
}

##############################################################################
# Module Level Variables
##############################################################################

variable "cluster_prefix" {
  description = "Prefix that is used to name the IBM Cloud HPC cluster and IBM Cloud resources that are provisioned to build the IBM Cloud HPC cluster instance. You cannot create more than one instance of the IBM Cloud HPC cluster with the same name. Ensure that the name is unique."
  type        = string
  default     = "hpcaas"

  validation {
    error_message = "Prefix must begin and end with a letter and contain only letters, numbers, and - characters."
    condition     = can(regex("^([A-z]|[a-z][-a-z0-9]*[a-z0-9])$", var.cluster_prefix))
  }
}

variable "zones" {
  description = "IBM Cloud zone names within the selected region where the IBM Cloud HPC cluster should be deployed. Two zone names are required as input value and supported zones for eu-de are eu-de-2, eu-de-3 and for us-east us-east-1, us-east-3. The management nodes and file storage shares will be deployed to the first zone in the list. Compute nodes will be deployed across both first and second zones, where the first zone in the list will be considered as the most preferred zone for compute nodes deployment. [Learn more](https://cloud.ibm.com/docs/vpc?topic=vpc-creating-a-vpc-in-a-different-region#get-zones-using-the-cli)."
  type        = list(string)
  validation {
    condition     = length(var.zones) == 2
    error_message = "Provide list of zones to deploy the cluster."
  }  
}

##############################################################################
# VPC Variables
##############################################################################

variable "vpc_name" {
  type        = string
  description = "Name of an existing VPC in which the cluster resources will be deployed. If no value is given, then a new VPC will be provisioned for the cluster. [Learn more](https://cloud.ibm.com/docs/vpc)"
  default     = null
}

variable "cluster_subnet_ids" {
  type        = list(string)
  default     = []
  description = "List of existing subnet IDs under the VPC, where the cluster will be provisioned. Two subnet ids are required as input value and supported zones for eu-de are eu-de-2, eu-de-3 and for us-east us-east-1, us-east-3. The management nodes and file storage shares will be deployed to the first zone in the list. Compute nodes will be deployed across both first and second zones, where the first zone in the list will be considered as the most preferred zone for compute nodes deployment."
  validation {
    condition     = contains([0, 2], length(var.cluster_subnet_ids))
    error_message = "The subnet_id value should either be empty or contain exactly two elements."
  }
}

variable "login_subnet_id" {
  type        = string
  default     = null
  description = "List of existing subnet ID under the VPC, where the login/Bastion server will be provisioned. One subnet id is required as input value for the creation of login node and bastion in the same zone as the management nodes are created. Note: Provide a different subnet id for login_subnet_id, do not overlap or provide the same subnet id that was already provided for cluster_subnet_ids."
}

variable "vpc_cidr" {
  description = "Creates the address prefix for the new VPC, when the vpc_name variable is empty. The VPC requires an address prefix for each subnet in two different zones. The subnets are created with the specified CIDR blocks, enabling support for two zones within the VPC. For more information, see [Setting IP ranges](https://cloud.ibm.com/docs/vpc?topic=vpc-vpc-addressing-plan-design)."
  type        = string
  default     = "10.241.0.0/18,10.241.64.0/18"
}

# variable "placement_strategy" {
#   type        = string
#   default     = null
#   description = "VPC placement groups to create (null / host_spread / power_spread)"
# }

##############################################################################
# Access Variables
##############################################################################
# variable "enable_bastion" {
#   type        = bool
#   default     = true
#   description = "The solution supports multiple ways to connect to your HPC cluster for example, using bastion node, via VPN or direct connection. If connecting to the HPC cluster via VPN or direct connection, set this value to false."
# }

# variable "enable_bootstrap" {
#   type        = bool
#   default     = false
#   description = "Bootstrap should be only used for better deployment performance"
# }

# variable "bootstrap_instance_profile" {
#   type        = string
#   default     = "mx2-4x32"
#   description = "Bootstrap should be only used for better deployment performance"
# }

variable "bastion_ssh_keys" {
  type        = list(string)
  description = "List of names of the SSH keys that is configured in your IBM Cloud account, used to establish a connection to the IBM Cloud HPC bastion node. Ensure that the SSH key is present in the same resource group and region where the cluster is being provisioned. If you do not have an SSH key in your IBM Cloud account, create one by according to [SSH Keys](https://cloud.ibm.com/docs/vpc?topic=vpc-ssh-keys)."
}

variable "login_node_instance_type" {
  type        = string
  default     = "bx2-2x8"
  description = "Specify the virtual server instance profile type to be used to create the login node for the IBM Cloud HPC cluster. For choices on profile types, see [Instance profiles](https://cloud.ibm.com/docs/vpc?topic=vpc-profiles)."
  validation {
    condition     = can(regex("^[^\\s]+-[0-9]+x[0-9]+", var.login_node_instance_type))
    error_message = "The profile must be a valid profile name."
  }
}

variable "vpc_cluster_login_private_subnets_cidr_blocks" {
  type        = list(string)
  default     = ["10.241.16.0/28"]
  description = "The CIDR block that's required for the creation of the login cluster private subnet. Modify the CIDR block if it conflicts with any on-premises CIDR blocks when using a hybrid environment. Provide only one CIDR block for the creation of the login subnet. Since login subnet is used only for the creation of login virtual server instances,  provide a CIDR range of /28."
  validation {
    condition     = length(var.vpc_cluster_login_private_subnets_cidr_blocks) <= 1
    error_message = "Only a single zone is supported to deploy resources. Provide a CIDR range of subnet creation."
  }
  validation {
    condition     = tonumber(regex("/(\\d+)", join(",", var.vpc_cluster_login_private_subnets_cidr_blocks))[0]) <= 28
    error_message = "This subnet is used to create only a login virtual server instance. Providing a larger CIDR size will waste the usage of available IPs. A CIDR range of /28 is sufficient for the creation of the login subnet."
  }
}

variable "vpn_enabled" {
  type        = bool
  default     = false
  description = "Set the value as true to deploy a VPN gateway for VPC in the cluster."
}

# variable "peer_cidr_list" {
#   type        = list(string)
#   default     = null
#   description = "The peer CIDRs (e.g., 192.168.0.0/24) to which the VPN will be connected."
# }

# variable "vpn_peer_address" {
#   type        = string
#   default     = null
#   description = "The peer public IP address to which the VPN will be connected."
# }

# variable "vpn_preshared_key" {
#   type        = string
#   default     = null
#   description = "The pre-shared key for the VPN."
# }

variable "remote_allowed_ips" {
  type        = list(string)
  description = "Comma-separated list of IP addresses that can access the IBM Cloud HPC cluster instance through an SSH interface. For security purposes, provide the public IP addresses assigned to the devices that are authorized to establish SSH connections (for example, [\"169.45.117.34\"]). To fetch the IP address of the device, use [https://ipv4.icanhazip.com/](https://ipv4.icanhazip.com/)."
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
# Compute Variables
##############################################################################
# Future use
/*
variable "login_subnets_cidr" {
  type        = list(string)
  default     = ["10.10.10.0/24", "10.20.10.0/24", "10.30.10.0/24"]
  description = "Subnet CIDR block to launch the login host."
}
*/

# variable "login_ssh_keys" {
#   type        = list(string)
#   description = "The key pair to use to launch the login host."
# }

# variable "login_image_name" {
#   type        = string
#   default     = "ibm-redhat-8-6-minimal-amd64-5"
#   description = "Image name to use for provisioning the login instances."
# }

# variable "login_instances" {
#   type = list(
#     object({
#       profile = string
#       count   = number
#     })
#   )
#   default = [{
#     profile = "cx2-2x4"
#     count   = 0
#   }]
#   description = "Number of instances to be launched for login."
# }

variable "vpc_cluster_private_subnets_cidr_blocks" {
  type        = list(string)
  default     = ["10.241.0.0/20", "10.241.64.0/20"]
  description = "The CIDR block that's required for the creation of the compute cluster private subnet. Modify the CIDR block if it conflicts with any on-premises CIDR blocks when using a hybrid environment. Make sure to select a CIDR block size that will accommodate the maximum number of management and dynamic compute nodes that you expect to have in your cluster. Requires one CIDR block for each subnet in two different zones. For more information on CIDR block size selection, see [Choosing IP ranges for your VPC](https://cloud.ibm.com/docs/vpc?topic=vpc-choosing-ip-ranges-for-your-vpc)."
  validation {
    condition     = length(var.vpc_cluster_private_subnets_cidr_blocks) == 2
    error_message = "Multiple zones are supported to deploy resources. Provide a CIDR range of subnets creation."
  }
}

variable "compute_ssh_keys" {
  type        = list(string)
  description = "List of names of the SSH keys that is configured in your IBM Cloud account, used to establish a connection to the IBM Cloud HPC cluster node. Ensure that the SSH key is present in the same resource group and region where the cluster is being provisioned. If you do not have an SSH key in your IBM Cloud account, create one by according to [SSH Keys](https://cloud.ibm.com/docs/vpc?topic=vpc-ssh-keys)."
}

variable "management_image_name" {
  type        = string
  default     = "hpcaas-lsf10-rhel88-v3"
  description = "Name of the custom image that you want to use to create virtual server instances in your IBM Cloud account to deploy the IBM Cloud HPC cluster management nodes. By default, the solution uses a base image with additional software packages mentioned [here](https://cloud.ibm.com/docs/hpc-spectrum-LSF#create-custom-image). If you would like to include your application-specific binary files, follow the instructions in [ Planning for custom images ](https://cloud.ibm.com/docs/vpc?topic=vpc-planning-custom-images) to create your own custom image and use that to build the IBM Cloud HPC cluster through this offering."
}

variable "management_node_count" {
  type        = number
  default     = 3
  description = "Number of management nodes. This is the total number of management nodes. Enter a value between 1 and 10."
  validation {
    condition     = 1 <= var.management_node_count && var.management_node_count <= 10
    error_message = "Input \"management_node_count\" must be must be greater than or equal to 1 and less than or equal to 10."
  }
}

variable "management_node_instance_type" {
  type        = string
  default     = "bx2-16x64"
  description = "Specify the virtual server instance profile type to be used to create the management nodes for the IBM Cloud HPC cluster. For choices on profile types, see [Instance profiles](https://cloud.ibm.com/docs/vpc?topic=vpc-profiles)."
  validation {
    condition     = can(regex("^[^\\s]+-[0-9]+x[0-9]+", var.management_node_instance_type))
    error_message = "The profile must be a valid profile name."
  }
}
# variable "management_instances" {
#   type = list(
#     object({
#       profile = string
#       count   = number
#     })
#   )
#   default = [{
#     profile = "bx2-16x64"
#     count   = 1
#   }]
#   description = "Number of instances to be launched for management."
# }

# variable "static_compute_instances" {
#   type = list(
#     object({
#       profile = string
#       count   = number
#     })
#   )
#   default = [{
#     profile = "cx2-2x4"
#     count   = 0
#   }]
#   description = "Min Number of instances to be launched for compute cluster."
# }

# variable "dynamic_compute_instances" {
#   type = list(
#     object({
#       profile = string
#       count   = number
#     })
#   )
#   default = [{
#     profile = "cx2-2x4"
#     count   = 250
#   }]
#   description = "MaxNumber of instances to be launched for compute cluster."
# }

variable "compute_image_name" {
  type        = string
  default     = "hpcaas-lsf10-rhel88-compute-v2"
  description = "Name of the custom image that you want to use to create virtual server instances in your IBM Cloud account to deploy the IBM Cloud HPC cluster dynamic compute nodes. By default, the solution uses a RHEL 8-6 OS image with additional software packages mentioned [here](https://cloud.ibm.com/docs/hpc-spectrum-LSF#create-custom-image). The solution also offers, Ubuntu 22-04 OS base image (hpcaas-lsf10-ubuntu2204-compute-v1). If you would like to include your application-specific binary files, follow the instructions in [ Planning for custom images ](https://cloud.ibm.com/docs/vpc?topic=vpc-planning-custom-images) to create your own custom image and use that to build the IBM Cloud HPC cluster through this offering."
}
# Future use
/*
variable "compute_gui_username" {
  type        = string
  default     = "admin"
  sensitive   = true
  description = "GUI user to perform system management and monitoring tasks on compute cluster."
}

variable "compute_gui_password" {
  type        = string
  sensitive   = true
  description = "Password for compute cluster GUI"
}
*/
##############################################################################
# Scale Storage Variables
##############################################################################

# variable "storage_subnets_cidr" {
#   type        = list(string)
#   default     = ["10.10.30.0/24", "10.20.30.0/24", "10.30.30.0/24"]
#   description = "Subnet CIDR block to launch the storage cluster host."
# }

# variable "storage_ssh_keys" {
#   type        = list(string)
#   description = "The key pair to use to launch the storage cluster host."
# }

# variable "storage_instances" {
#   type = list(
#     object({
#       profile = string
#       count   = number
#     })
#   )
#   default = [{
#     profile = "bx2-2x8"
#     count   = 0
#   }]
#   description = "Number of instances to be launched for storage cluster."
# }

# variable "storage_image_name" {
#   type        = string
#   default     = "ibm-redhat-8-6-minimal-amd64-5"
#   description = "Image name to use for provisioning the storage cluster instances."
# }

# variable "protocol_subnets_cidr" {
#   type        = list(string)
#   default     = ["10.10.40.0/24", "10.20.40.0/24", "10.30.40.0/24"]
#   description = "Subnet CIDR block to launch the storage cluster host."
# }

# variable "protocol_instances" {
#   type = list(
#     object({
#       profile = string
#       count   = number
#     })
#   )
#   default = [{
#     profile = "bx2-2x8"
#     count   = 0
#   }]
#   description = "Number of instances to be launched for protocol hosts."
# }
# Future use
/*
variable "storage_gui_username" {
  type        = string
  default     = "admin"
  sensitive   = true
  description = "GUI user to perform system management and monitoring tasks on storage cluster."
}

variable "storage_gui_password" {
  type        = string
  sensitive   = true
  description = "Password for storage cluster GUI"
}
*/

variable "custom_file_shares" {
  type = list(object({
    mount_path = string,
    size       = number,
    iops       = number
  }))
  default     = [{ mount_path = "/mnt/binaries", size = 100, iops = 2000 }, { mount_path = "/mnt/data", size = 100, iops = 6000 }]
  description = "Mount points and sizes in GB and IOPS range of file shares that can be used to customize shared file storage layout. Provide the details for up to 5 shares. Each file share size in GB supports different range of IOPS. For more information, see [file share IOPS value](https://cloud.ibm.com/docs/vpc?topic=vpc-file-storage-profiles&interface=ui)."
  validation {
    condition     = length(var.custom_file_shares) <= 5
    error_message = "The custom file share count \"custom_file_shares\" must be less than or equal to 5."
  }
  validation {
    condition     = !anytrue([for mounts in var.custom_file_shares : mounts.mount_path == "/mnt/lsf"])
    error_message = "The mount path /mnt/lsf is reserved for internal usage and can't be used as file share mount_path."
  }
  validation {
    condition     = length([for mounts in var.custom_file_shares : mounts.mount_path]) == length(toset([for mounts in var.custom_file_shares : mounts.mount_path]))
    error_message = "Mount path values should not be duplicated."
  }
  validation {
    condition     = alltrue([for mounts in var.custom_file_shares : (10 <= mounts.size && mounts.size <= 32000)])
    error_message = "The custom_file_share size must be greater than or equal to 10 and less than or equal to 32000."
  }
}

# variable "nsd_details" {
#   type = list(
#     object({
#       profile  = string
#       capacity = optional(number)
#       iops     = optional(number)
#     })
#   )
#   default = [{
#     profile = "custom"
#     size    = 100
#     iops    = 100
#   }]
#   description = "Storage scale NSD details"
# }

##############################################################################
# DNS Template Variables
##############################################################################

variable "dns_instance_id" {
  type        = string
  default     = null
  description = "Provide the id of existing IBM Cloud DNS services domain name to used for the IBM Cloud HPC cluster."
}

variable "dns_domain_names" {
  type = object({
    compute  = string
    #storage  = string
    #protocol = string
  })
  default = {
    compute  = "hpcaasnew.com"
  }
  description = "IBM Cloud DNS Services domain name to be used for the IBM Cloud HPC cluster."
  validation {
    condition = can(regex("^([a-zA-Z0-9][a-zA-Z0-9-]{0,61}[a-zA-Z0-9])\\.com$", var.dns_domain_names.compute))
    #condition = can(regex("^([a-zA-Z0-9][a-zA-Z0-9-]{0,61}[a-zA-Z0-9]\\.)+[a-zA-Z]{2,6}$", var.dns_domain_names.compute))
    #condition = can(regex("^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\\.[a-zA-Z]{2,6}$", var.dns_domain_names.compute))
    #condition     = can(regex("^([[:alnum:]]*[A-Za-z0-9-]{1,63}\\.)+[A-Za-z]{2,6}$", var.dns_domain_names.compute))
    error_message = "The domain name provided for compute is not a fully qualified domain name (FQDN). An FQDN can contain letters (a-z, A-Z), digits (0-9), hyphens (-), dots (.), and must start and end with an alphanumeric character."
  }  
}

################################################
# TODO : Commented the variable as supporting the existing dns_instance_id will work for custom resolver
################################################
#variable "dns_custom_resolver_id" {
#  type        = string
#  default     = null
#  description = "IBM Cloud DNS custom resolver id."
#}

##############################################################################
# Observability Variables
##############################################################################

variable "enable_cos_integration" {
  type        = bool
  default     = false
  description = "Set to true to create an extra cos bucket to integrate with HPC cluster deployment."
}

variable "cos_instance_name" {
  type        = string
  default     = null
  description = "Provide the name of the existing cos instance to store vpc flow logs."
}

# variable "enable_atracker" {
#   type        = bool
#   default     = true
#   description = "Enable Activity tracker"
# }

variable "enable_vpc_flow_logs" {
  type        = bool
  default     = false
  description = "Flag to enable VPC flow logs. If true, a flow log collector will be created."
}

##############################################################################
# Encryption Variables
##############################################################################

variable "key_management" {
  type        = string
  default     = "key_protect"
  description = "Setting this to key_protect will enable customer managed encryption for boot volume and file share. If the key_management is set as null, encryption will be always provider managed."
  validation {
    condition     = var.key_management == "null" || var.key_management == null || var.key_management == "key_protect"
    error_message = "key_management must be either 'null' or 'key_protect'."
  }  
}

variable "kms_instance_name" {
  type        = string
  default     = null
  description = "Name of the Key Protect instance associated with the Key Management Service. Note: kms_instance_name to be considered only if key_management value is set to key_protect. The name can be found under the details of the KMS, see [View key-protect ID](https://cloud.ibm.com/docs/key-protect?topic=key-protect-retrieve-instance-ID&interface=ui)."
}

variable "kms_key_name" {
  type        = string
  default     = null
  description = "Provide the existing KMS encryption key name that you want to use for the IBM Cloud HPC cluster. Note: kms_instance_name to be considered only if key_management value is set to key_protect. (for example kms_key_name: my-encryption-key)."
}

# variable "hpcs_instance_name" {
#   type        = string
#   default     = null
#   description = "Hyper Protect Crypto Service instance"
# }

##############################################################################
# TODO: Sagar variables
##############################################################################

variable "cluster_id" {
  type        = string
  description = "Ensure that you have received the cluster ID from IBM technical sales. A unique identifer for HPC cluster used by IBM Cloud HPC to differentiate different HPC clusters within the same contract. This can be up to 39 alphanumeric characters including the underscore (_), the hyphen (-), and the period (.) characters. You cannot change the cluster ID after deployment."
  validation {
    condition     = 0 < length(var.cluster_id) && length(var.cluster_id) < 40 && can(regex("^[a-zA-Z0-9_.-]+$", var.cluster_id))
    error_message = "The ID can be up to 39 alphanumeric characters including the underscore (_), the hyphen (-), and the period (.) characters. Other special characters and spaces are not allowed."
  }  
}

variable "contract_id" {
  type        = string
  sensitive   = true
  description = "Ensure that you have received the contract ID from IBM technical sales. Contract ID is a unique identifier to distinguish different IBM Cloud HPC service agreements. It must start with a letter and can only contain letters, numbers, hyphens (-), or underscores (_)."
  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9-_]*$", var.contract_id))
    error_message = "Contract ID must start with a letter and can only contain letters, numbers, hyphens (-), or underscores (_)."
  }  
}

variable "hyperthreading_enabled" {
  type        = bool
  default     = true
  description = "Setting this to true will enable hyper-threading in the compute nodes of the cluster (default). Otherwise, hyper-threading will be disabled."
}

##############################################################################
# Encryption Variables
##############################################################################
variable "enable_app_center" {
  type        = bool
  default     = false
  description = "Set to true to enable the IBM Spectrum LSF Application Center GUI (default: false). [System requirements](https://www.ibm.com/docs/en/slac/10.2.0?topic=requirements-system-102-fix-pack-14) for IBM Spectrum LSF Application Center Version 10.2 Fix Pack 14."
}

variable "app_center_gui_pwd" {
  type        = string
  sensitive   = true
  default     = ""
  description = "Password for IBM Spectrum LSF Application Center GUI. Note: Password should be at least 8 characters, must have one number, one lowercase letter, one uppercase letter, and at least one special character."
}

# variable "ssh_key_name" {
#   type        = string
#   description = "Comma-separated list of names of the SSH keys that is configured in your IBM Cloud account, used to establish a connection to the IBM Cloud HPC cluster node. Ensure that the SSH key is present in the same resource group and region where the cluster is being provisioned. If you do not have an SSH key in your IBM Cloud account, create one by according to [SSH Keys](https://cloud.ibm.com/docs/vpc?topic=vpc-ssh-keys)."
# }

variable "enable_fip" {
  type        = bool
  default     = true
  description = "The solution supports multiple ways to connect to your IBM Cloud HPC cluster for example, using a login node, or using VPN or direct connection. If connecting to the IBM Cloud HPC cluster using VPN or direct connection, set this value to false."
}

###########################################################################
# List of script filenames used by validation test suites.
# If provided, these scripts will be executed as part of validation test suites execution.
###########################################################################

variable "TF_VALIDATION_SCRIPT_FILES" {
  type        = list(string)
  default     = []
  description = "List of script file names used by validation test suites. If provided, these scripts will be executed as part of validation test suites execution."
  validation {
    condition     = alltrue([for filename in var.TF_VALIDATION_SCRIPT_FILES : can(regex(".*\\.sh$", filename))])
    error_message = "All validation script file names must end with .sh."
  }
}

##############################################################################
# ldap Variables
##############################################################################
variable "enable_ldap" {
  type        = bool
  default     = false
  description = "Set this option to true to enable LDAP for IBM Cloud HPC, with the default value set to false."
}

variable "ldap_basedns" {
  type        = string
  default     = "hpcaas.com"
  description = "The dns domain name is used for configuring the LDAP server. If an LDAP server is already in existence, ensure to provide the associated DNS domain name."
}

variable "ldap_server" {
  type        = string
  default     = "null"
  description = "Provide the IP address for the existing LDAP server. If no address is given, a new LDAP server will be created."
}

variable "ldap_admin_password" {
  type        = string
  sensitive   = true
  default     = ""
  description = "The LDAP administrative password should be 8 to 20 characters long, with a mix of at least three alphabetic characters, including one uppercase and one lowercase letter. It must also include two numerical digits and at least one special character from (~@_+:) are required. It is important to avoid including the username in the password for enhanced security.[This value is ignored for an existing LDAP server]."
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

variable "ldap_vsi_profile" {
  type        = string
  default     = "cx2-2x4"
  description = "Profile to be used for LDAP virtual server instance."
}

variable "ldap_vsi_osimage_name" {
  type        = string
  default     = "ibm-ubuntu-22-04-3-minimal-amd64-1"
  description = "Image name to be used for provisioning the LDAP instances."
}

variable "skip_iam_authorization_policy" {
  type        = string
  default     = false
  description = "Set it to false if authorization policy is required for VPC to access COS. This can be set to true if authorization policy already exists. For more information on how to create authorization policy manually, see [creating authorization policies for VPC flow log](https://cloud.ibm.com/docs/vpc?topic=vpc-ordering-flow-log-collector&interface=ui#fl-before-you-begin-ui)."
}

##############################################################################
# High Availability (Hidden Feature)
##############################################################################
variable "ENABLE_HIGH_AVAILABILITY" {
  type        = bool
  default     = false
  description = "The solution supports high availability as an hidden feature that is disabled by default. You can enable the feature setting this value to true."
}

###########################################################################
# IBM Cloud Dababase for MySQL Variables
###########################################################################
variable "DB_TEMPLATE" {
  type        = list
  description = "Set the initial resource allocation: members count, RAM (Mb), Disks (Mb) and CPU cores count."
  default     = [3, 12288, 122880, 3]
}

