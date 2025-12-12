##############################################################################
# Offering Variations
##############################################################################
variable "storage_type" {
  type        = string
  default     = "vsi"
  description = "Select the required storage type(vsi/baremetal/eval)."
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


variable "cluster_cidr" {
  description = "Network CIDR of the VPC. This is used to manage network security rules for cluster provisioning."
  type        = string
  default     = "10.241.0.0/18"
}

##############################################################################
# VPC Variables
##############################################################################

variable "vpc_id" {
  type        = string
  description = "ID of an existing VPC in which the cluster resources will be deployed."
}

variable "placement_group_ids" {
  type        = string
  default     = null
  description = "VPC placement group ids"
}

##############################################################################
# Access Variables
##############################################################################

variable "bastion_security_group_id" {
  type        = string
  description = "Bastion security group id."
}

variable "bastion_public_key_content" {
  type        = string
  sensitive   = true
  default     = null
  description = "Bastion security group id."
}

variable "storage_security_group_id" {
  type        = string
  default     = null
  description = "Existing Scale storage security group id"
}

variable "mtu_value" {
  type        = number
  default     = 9000
  description = "Default MTU is 9000. For deployments using Spectrum Scale with LSF and PPNLB enabled, configure the MTU at 8500 or lower to ensure compatibility."
}

##############################################################################
# Compute Variables
##############################################################################

variable "client_subnets" {
  type = list(object({
    name = string
    id   = string
    zone = string
    cidr = string
  }))
  default     = []
  description = "Subnets to launch the client hosts."
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
    image   = "ibm-redhat-8-10-minimal-amd64-10"
  }]
  description = "Number of instances to be launched for client."
}

variable "compute_subnet_id" {
  type = list(object({
    name = string
    id   = string
    zone = string
    cidr = string
  }))
  default     = []
  description = "Subnets to launch the compute host."
}

variable "ssh_keys" {
  type        = list(string)
  default     = []
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
    image   = "ibm-redhat-8-10-minimal-amd64-10"
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
    image   = "ibm-redhat-8-10-minimal-amd64-10"
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
    count   = 250
    image   = "ibm-redhat-8-10-minimal-amd64-10"
  }]
  description = "MaxNumber of instances to be launched for compute cluster."
}

# variable "compute_gui_username" {
#   type        = string
#   default     = "admin"
#   sensitive   = true
#   description = "GUI user to perform system management and monitoring tasks on compute cluster."
# }

# variable "compute_gui_password" {
#   type        = string
#   default     = "hpc@IBMCloud"
#   sensitive   = true
#   description = "Password for compute cluster GUI"
# }

##############################################################################
# Scale Storage Variables
##############################################################################

variable "storage_subnets" {
  type = list(object({
    name = string
    id   = string
    zone = string
    cidr = string
  }))
  default     = []
  description = "Subnets to launch the storage host."
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
    profile         = "bx2d-32x128"
    count           = 0
    image           = "ibm-redhat-8-10-minimal-amd64-10"
    filesystem_name = "fs1"
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
    filesystem = "fs1"
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
  description = "The virtual server instance profile type name to be used to create the Management node. For more information, see [Instance Profiles](https://cloud.ibm.com/docs/vpc?topic=vpc-profiles&interface=ui)."
}

variable "protocol_subnets" {
  type = list(object({
    name = string
    id   = string
    zone = string
    cidr = string
  }))
  default     = []
  description = "Subnets to launch the bastion host."
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

variable "colocate_protocol_instances" {
  type        = bool
  default     = true
  description = "Enable it to use storage instances as protocol instances"
}

##############################################################################
# DNS Template Variables
##############################################################################

variable "dns_domain_names" {
  type = object({
    compute  = string
    storage  = optional(string)
    protocol = optional(string)
    client   = optional(string)
    gklm     = optional(string)
  })
  default = {
    compute  = "comp.com"
    storage  = "strg.com"
    protocol = "ces.com"
    client   = "clnt.com"
    gklm     = "gklm.com"
  }
  description = "IBM Cloud HPC DNS domain names."
}

##############################################################################
# Encryption Variables
##############################################################################

# TODO: landing-zone-vsi limitation to opt out encryption
variable "kms_encryption_enabled" {
  description = "Enable Key management"
  type        = bool
  default     = true
}

variable "boot_volume_encryption_key" {
  type        = string
  default     = null
  description = "CRN of boot volume encryption key"
}

##############################################################################
# TODO: Auth Server (LDAP/AD) Variables
##############################################################################

# variable "compute_public_key_content" {
#   type        = string
#   sensitive   = true
#   default     = null
#   description = "Compute security key content."
# }

# variable "compute_private_key_content" {
#   type        = string
#   sensitive   = true
#   default     = null
#   description = "Compute security key content."
# }

variable "enable_deployer" {
  type        = bool
  default     = true
  description = "Deployer should be only used for better deployment performance"
}

#############################################################################
# LDAP variables
##############################################################################
variable "enable_ldap" {
  type        = bool
  default     = false
  description = "Set this option to true to enable LDAP for IBM Cloud HPC, with the default value set to false."
}

variable "ldap_server" {
  type        = string
  default     = null
  description = "Provide the IP address for the existing LDAP server. If no address is given, a new LDAP server will be created."
}

# variable "ldap_instance_key_pair" {
#   type        = list(string)
#   default     = null
#   description = "Name of the SSH key configured in your IBM Cloud account that is used to establish a connection to the LDAP Server. Make sure that the SSH key is present in the same resource group and region where the LDAP Servers are provisioned. If you do not have an SSH key in your IBM Cloud account, create one by using the [SSH keys](https://cloud.ibm.com/docs/vpc?topic=vpc-ssh-keys) instructions."
# }

variable "ldap_instances" {
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

variable "afm_instances" {
  type = list(
    object({
      profile = string
      count   = number
    })
  )
  default = [{
    profile = "bx2-32x128"
    count   = 1
  }]
  description = "Number of instances to be launched for afm hosts."
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
    image   = "ibm-redhat-8-10-minimal-amd64-10"
  }]
  description = "Number of instances to be launched for client."
}

variable "vpc_region" {
  type        = string
  default     = null
  description = "vpc region"
}

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
# Dedicatedhost Variables
##############################################################################

variable "enable_dedicated_host" {
  type        = bool
  default     = false
  description = "Enables dedicated host to the compute instances"
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

variable "bastion_subnets" {
  type = list(object({
    name = string
    id   = string
    zone = string
    cidr = string
  }))
  default     = []
  description = "Subnets to launch the bastion host."
}

variable "bms_boot_drive_encryption" {
  type        = bool
  default     = false
  description = "To enable the encryption for the boot drive of bare metal server. Select true or false"
}

variable "login_security_group_name" {
  type        = string
  default     = null
  description = "Provide the security group name to provision the bastion node. If set to null, the solution will automatically create the necessary security group and rules. If you choose to use an existing security group, ensure it has the appropriate rules configured for the bastion node to function properly."
}

variable "storage_security_group_name" {
  type        = string
  default     = null
  description = "Provide the security group name to provision the storage nodes. If set to null, the solution will automatically create the necessary security group and rules. If you choose to use an existing security group, ensure it has the appropriate rules configured for the storage nodes to function properly."
}

variable "compute_security_group_name" {
  type        = string
  default     = null
  description = "Provide the security group name to provision the compute nodes. If set to null, the solution will automatically create the necessary security group and rules. If you choose to use an existing security group, ensure it has the appropriate rules configured for the compute nodes to function properly."
}

variable "client_security_group_name" {
  type        = string
  default     = null
  description = "Provide the security group name to provision the gklm nodes. If set to null, the solution will automatically create the necessary security group and rules. If you choose to use an existing security group, ensure it has the appropriate rules configured for the gklm nodes to function properly."
}

variable "gklm_security_group_name" {
  type        = string
  default     = null
  description = "Provide the security group name to provision the gklm nodes. If set to null, the solution will automatically create the necessary security group and rules. If you choose to use an existing security group, ensure it has the appropriate rules configured for the gklm nodes to function properly."
}

variable "ldap_security_group_name" {
  type        = string
  default     = null
  description = "Provide the security group name to provision the ldap nodes. If set to null, the solution will automatically create the necessary security group and rules. If you choose to use an existing security group, ensure it has the appropriate rules configured for the ldap nodes to function properly."
}

variable "volume_storages" {
  description = "The Block Volume Storage Profile to use for the boot volume of the virtual instance"
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
  default = []
}

variable "lsf_pay_per_use" {
  type        = bool
  default     = true
  description = "When lsf_pay_per_use is set to true, the LSF cluster nodes are provisioned using predefined custom images under a pay-per-use pricing plan, where billing is based on vCPU usage per hour. In this mode, providing custom images for the nodes is not required, and Bring Your Own Image (BYOL) is not supported. The pay-per-use option is available only for FP15 images. If you set the variable to false, the automation uses default images for all cluster nodes and enables support for BYOL, with no pay-per-use billing applied."
}

variable "protocol_instance_eth1_mtu" {
  type        = number
  description = "Enable the Private Path NLB for CES. When enabled, MTU must be 8500 or lower because PPNLB does not support MTU 9000. When disabled, protocol nodes can safely use MTU 9000."
}
