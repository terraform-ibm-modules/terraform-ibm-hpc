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
  description = "Specify the existing resource group name from your IBM Cloud account where the VPC resources should be deployed. By default, the resource group name is set to 'Default.' Note that in some older accounts, the resource group name may be 'default,' so please validate the resource_group name before deployment. If the resource group value is set to the string \"null\", the automation will create two different resource groups named 'workload-rg' and 'service-rg.' For more information on resource groups, refer to Managing resource groups."
  type        = string
  default     = "Default"
  validation {
    condition     = var.resource_group != null
    error_message = "If you want to provide null for resource_group variable, it should be within double quotes."
  }
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

variable "vpc_name" {
  type        = string
  description = "Name of an existing VPC in which the cluster resources will be deployed. If no value is given, then a new VPC will be provisioned for the cluster. [Learn more](https://cloud.ibm.com/docs/vpc)"
  default     = null
}

variable "subnet_id" {
  type        = string
  default     = null
  description = "Existing subnet ID under the VPC, where the packer VSI will be provisioned."
}

variable "network_cidr" {
  description = "Network CIDR for the VPC. This is used to manage network ACL rules for cluster provisioning."
  type        = string
  default     = "10.241.0.0/18"
}

variable "ssh_keys" {
  type        = list(string)
  description = "The key pair to use to access the servers."
}

##############################################################################
# Access Variables
##############################################################################

variable "packer_subnet_cidr" {
  type        = list(string)
  default     = ["10.241.16.0/28"]
  description = "Subnet CIDR block to launch the packer host."
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

variable "kms_instance_name" {
  type        = string
  default     = null
  description = "Name of the Key Protect instance associated with the Key Management Service. The ID can be found under the details of the KMS, see [View key-protect ID](https://cloud.ibm.com/docs/key-protect?topic=key-protect-retrieve-instance-ID&interface=ui)."
}

variable "kms_key_name" {
  type        = string
  default     = null
  description = "Provide the existing KMS encryption key name that you want to use for the IBM Cloud HPC cluster. (for example kms_key_name: my-encryption-key)."
}

variable "skip_iam_authorization_policy" {
  type        = bool
  default     = false
  description = "Set to false if authorization policy is required for VPC block storage volumes to access kms. This can be set to true if authorization policy already exists. For more information on how to create authorization policy manually, see [creating authorization policies for block storage volume](https://cloud.ibm.com/docs/vpc?topic=vpc-block-s2s-auth&interface=ui)."
}

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

variable "image_name" {
  type        = string
  description = "Image name for newly created custom image."
}

variable "source_image_name" {
  type        = string
  default     = "ibm-redhat-8-8-minimal-amd64-5"
  description = "The source image name whose root volume will be copied and provisioned on the currently running instance."

  validation {
    condition     = can(regex("^(ibm-ubuntu-22-04-4-minimal-amd64-|ibm-redhat-8-8-minimal-amd64-|ibm-rocky-linux-8-10-minimal-amd64-)", var.source_image_name))
    error_message = "We provide support for the following source images: Ubuntu 22.04, RHEL 8.8, and Rocky Linux 8.10."
  }
}

variable "install_sysdig" {
  type        = bool
  default     = false
  description = "Set the value as true to install sysdig agent on the compute node images."
}

variable "security_group_id" {
  type        = string
  default     = ""
  description = "The security group identifier to use. If not specified, IBM packer plugin creates a new temporary security group to allow SSH and WinRM access."
}

variable "enable_vpn" {
  type        = bool
  default     = false
  description = "If connecting to the Packer deployment via VPN, set this value to true."
}

variable "enable_fip" {
  type        = bool
  default     = true
  description = "If connecting to the Packer deployment via Floating IP, set this value to true."
}

# tflint-ignore: terraform_unused_declarations
variable "cluster_id" {
  type        = string
  description = "Ensure that you have received the cluster ID from IBM technical sales. A unique identifer for HPC cluster used by IBM Cloud HPC to differentiate different HPC clusters within the same reservations. This can be up to 39 alphanumeric characters including the underscore (_), the hyphen (-), and the period (.) characters. You cannot change the cluster ID after deployment."
  validation {
    condition     = 0 < length(var.cluster_id) && length(var.cluster_id) < 40 && can(regex("^[a-zA-Z0-9_.-]+$", var.cluster_id))
    error_message = "The Cluster ID can be up to 39 alphanumeric characters including the underscore (_), the hyphen (-), and the period (.) characters. Other special characters and spaces are not allowed."
  }
}

# tflint-ignore: terraform_unused_declarations
variable "reservation_id" {
  type        = string
  sensitive   = true
  description = "Ensure that you have received the reservation ID from IBM technical sales. Reservation ID is a unique identifier to distinguish different IBM Cloud HPC service agreements. It must start with a letter and can only contain letters, numbers, hyphens (-), or underscores (_)."
  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9-_]*$", var.reservation_id))
    error_message = "Reservation ID must start with a letter and can only contain letters, numbers, hyphens (-), or underscores (_)."
  }
}

# tflint-ignore: terraform_unused_declarations
variable "private_catalog_id" {
  type        = string
  default     = null
  description = "If you want to publish the created image to the CE account, please provide your private catalog ID."
}
