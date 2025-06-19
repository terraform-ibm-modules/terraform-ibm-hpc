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

variable "existing_resource_group" {
  description = "Resource group name from your IBM Cloud account where the VPC resources should be deployed. Note. If the resource group value is set as null, automation creates two different RG with the name (workload-rg and service-rg). For additional information on resource groups, see [Managing resource groups](https://cloud.ibm.com/docs/account?topic=account-rgs)."
  type        = string
  default     = "Default"
  validation {
    condition     = var.existing_resource_group != null
    error_message = "If you want to provide null for existing_resource_group variable, it should be within double quotes."
  }
}

##############################################################################
# Module Level Variables
##############################################################################

variable "cluster_prefix" {
  description = "Prefix that is used to name the IBM Cloud HPC cluster and IBM Cloud resources that are provisioned to build the IBM Cloud HPC cluster instance. You cannot create more than one instance of the IBM Cloud HPC cluster with the same name. Ensure that the name is unique. Prefix must begin and end with a letter and contain only letters, numbers, and - characters."
  type        = string
  default     = "hpcaas"

  validation {
    error_message = "Prefix must begin and end with a letter and contain only letters, numbers, and - characters."
    condition     = can(regex("^[a-zA-Z][-a-zA-Z0-9]*[a-zA-Z]$", var.cluster_prefix))
  }
}

variable "zones" {
  description = "IBM Cloud zone name within the selected region where the IBM Cloud HPC cluster should be deployed. Single zone name is required as input value and supported zones for eu-de are eu-de-2, eu-de-3 for us-east us-east-1, us-east-3 and for us-south us-south-1 and us-south-3. The management nodes, file storage shares and compute nodes will be deployed on the same zone.[Learn more](https://cloud.ibm.com/docs/vpc?topic=vpc-creating-a-vpc-in-a-different-region#get-zones-using-the-cli)."
  type        = list(string)
  default     = ["us-east-1"]
  validation {
    condition     = length(var.zones) == 1
    error_message = "Provide list of zones to deploy the cluster."
  }
}

##############################################################################
# VPC Variables
##############################################################################

variable "vpc_cidr" {
  description = "Creates the address prefix for the new VPC, when the vpc_name variable is empty. The VPC requires an address prefix for creation of subnet in a single zone. The subnet are created with the specified CIDR blocks. For more information, see [Setting IP ranges](https://cloud.ibm.com/docs/vpc?topic=vpc-vpc-addressing-plan-design)."
  type        = string
  default     = "10.241.0.0/18"
}

variable "vpc_cluster_private_subnets_cidr_blocks" {
  type        = list(string)
  default     = ["10.241.0.0/20"]
  description = "The CIDR block that's required for the creation of the compute cluster private subnet. Modify the CIDR block if it conflicts with any on-premises CIDR blocks when using a hybrid environment. Make sure to select a CIDR block size that will accommodate the maximum number of management and dynamic compute nodes that you expect to have in your cluster. Requires one CIDR block. For more information on CIDR block size selection, see [Choosing IP ranges for your VPC](https://cloud.ibm.com/docs/vpc?topic=vpc-choosing-ip-ranges-for-your-vpc)."
  validation {
    condition     = length(var.vpc_cluster_private_subnets_cidr_blocks) == 1
    error_message = "Single zone is supported to deploy resources. Provide a CIDR range of subnets creation."
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

##############################################################################
# Access Variables
##############################################################################

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

variable "bastion_ssh_keys" {
  type        = list(string)
  description = "List of names of the SSH keys that is configured in your IBM Cloud account, used to establish a connection to the IBM Cloud HPC bastion and login node. Ensure that the SSH key is present in the same resource group and region where the cluster is being provisioned. If you do not have an SSH key in your IBM Cloud account, create one by according to [SSH Keys](https://cloud.ibm.com/docs/vpc?topic=vpc-ssh-keys)."
}

##############################################################################
# VPC Hub-Spoke support
##############################################################################

variable "enable_hub" {
  description = "Indicates whether this VPC is enabled as a DNS name resolution hub."
  type        = bool
  default     = false
}

variable "dns_zone_name" {
  description = "The name of the DNS zone to be created."
  default     = null
  type        = string
}
