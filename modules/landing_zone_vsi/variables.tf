##############################################################################
# Offering Variations
##############################################################################
# variable "storage_type" {
#   type        = string
#   default     = "scratch"
#   description = "Select the required storage type(scratch/persistent/eval)."
# }

##############################################################################
# Account Variables
##############################################################################

variable "ibmcloud_api_key" {
  description = "IBM Cloud API Key that will be used for authentication in scripts run in this module. Only required if certain options are required."
  type        = string
  sensitive   = true
  default     = null
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

variable "vpc_id" {
  type        = string
  description = "ID of an existing VPC in which the cluster resources will be deployed."
}

##############################################################################
# Access Variables
##############################################################################

variable "bastion_fip" {
  type        = string
  description = "Bastion FIP."
}

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

variable "cluster_user" {
  type        = string
  description = "Linux user for cluster administration."
}

variable "compute_private_key_content" {
  type        = string
  description = "Compute private key content"
}

variable "bastion_private_key_content" {
  type        = string
  description = "Bastion private key content"
}

##############################################################################
# Compute Variables
##############################################################################

variable "compute_subnets" {
  type = list(object({
    name = string
    id   = string
    zone = string
    cidr = string
    crn  = string
  }))
  default     = []
  description = "Subnets to launch the compute host."
}

variable "compute_ssh_keys" {
  type        = list(string)
  description = "The key pair to use to launch the compute host."
}

variable "management_image_name" {
  type        = string
  default     = "hpcaas-lsf10-rhel810-v12"
  description = "Image name to use for provisioning the management cluster instances."
}

variable "compute_image_name" {
  type        = string
  default     = "hpcaas-lsf10-rhel810-compute-v8"
  description = "Image name to use for provisioning the compute cluster instances."
}

variable "login_image_name" {
  type        = string
  default     = "hpcaas-lsf10-rhel810-compute-v8"
  description = "Image name to use for provisioning the login instance."
}

##############################################################################
# DNS Template Variables
##############################################################################

variable "dns_domain_names" {
  type = object({
    compute = string
    #storage  = string
    #protocol = string
  })
  default = {
    compute  = "comp.com"
    storage  = "strg.com"
    protocol = "ces.com"
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

variable "cluster_id" {
  type        = string
  description = "Ensure that you have received the cluster ID from IBM technical sales. A unique identifer for HPC cluster used by IBM Cloud HPC to differentiate different HPC clusters within the same contract. This can be up to 39 alphanumeric characters including the underscore (_), the hyphen (-), and the period (.) characters. You cannot change the cluster ID after deployment."
}

variable "contract_id" {
  type        = string
  sensitive   = true
  description = "Ensure that you have received the contract ID from IBM technical sales. Contract ID is a unique identifier to distinguish different IBM Cloud HPC service agreements. It must start with a letter and can only contain letters, numbers, hyphens (-), or underscores (_)."
}

variable "hyperthreading_enabled" {
  type        = bool
  default     = true
  description = "Setting this to true will enable hyper-threading in the compute nodes of the cluster (default). Otherwise, hyper-threading will be disabled."
}

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

variable "share_path" {
  type        = string
  description = "Provide the exact path to where the VPC file share needs to be mounted"
}

variable "mount_path" {
  type = list(object({
    mount_path = string,
    size       = optional(number),
    iops       = optional(number),
    nfs_share  = optional(string)
  }))
  description = "Provide the path for the vpc file share to be mounted on to the HPC Cluster nodes"
}

variable "file_share" {
  type        = list(string)
  description = "VPC file share mount points considering the ip address and the file share name"
}

variable "login_private_ips" {
  description = "Login private IPs"
  type        = string
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

variable "ssh_keys" {
  type        = list(string)
  description = "The key pair to use to access the host."
}

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

variable "ldap_server_cert" {
  type        = string
  sensitive   = true
  default     = "null"
  description = "Provide the existing LDAP server certificate. If not provided, the value should be set to 'null'."
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
  default     = "ibm-ubuntu-22-04-4-minimal-amd64-3"
  description = "Image name to be used for provisioning the LDAP instances."
}

variable "ldap_primary_ip" {
  type        = list(string)
  description = "List of LDAP primary IPs."
}

##############################################################################
# High Availability
##############################################################################
variable "app_center_high_availability" {
  type        = bool
  default     = true
  description = "Set to false to disable the IBM Spectrum LSF Application Center GUI High Availability (default: true) ."
}

###########################################################################
# IBM Cloud Dababase for MySQL Instance variables
###########################################################################
variable "db_instance_info" {
  description = "The IBM Cloud Database for MySQL information required to reference the PAC database."
  type = object({
    id          = string
    admin_user  = string
    hostname    = string
    port        = number
    certificate = string
  })
  default = null
}

variable "db_admin_password" {
  type        = string
  default     = null
  sensitive   = true
  description = "The IBM Cloud Database for MySQL password required to reference the PAC database."
}

variable "storage_security_group_id" {
  type        = string
  default     = null
  description = "Existing Scale storage security group id"
}

##############################################################################
# Observability Variables
##############################################################################

variable "observability_monitoring_enable" {
  description = "Set true to enable IBM Cloud Monitoring instance provisioning."
  type        = bool
  default     = false
}

variable "observability_monitoring_on_compute_nodes_enable" {
  description = "Set true to enable IBM Cloud Monitoring on Compute Nodes."
  type        = bool
  default     = false
}

variable "cloud_monitoring_access_key" {
  description = "IBM Cloud Monitoring access key for agents to use"
  type        = string
  sensitive   = true
}

variable "cloud_monitoring_ingestion_url" {
  description = "IBM Cloud Monitoring ingestion url for agents to use"
  type        = string
}

variable "cloud_monitoring_prws_key" {
  description = "IBM Cloud Monitoring Prometheus Remote Write ingestion key"
  type        = string
  sensitive   = true
}

variable "cloud_monitoring_prws_url" {
  description = "IBM Cloud Monitoring Prometheus Remote Write ingestion url"
  type        = string
}

###########################################################################
# Existing Bastion Support variables
###########################################################################

variable "bastion_instance_name" {
  type        = string
  default     = null
  description = "Bastion instance name."
}

##############################################################################
# Code Engine Variables
##############################################################################

variable "ce_project_guid" {
  description = "The GUID of the Code Engine Project associated to this cluster Reservation"
  type        = string
}

variable "existing_kms_instance_guid" {
  type        = string
  default     = null
  description = "GUID of boot volume encryption key"
}

variable "cloud_logs_ingress_private_endpoint" {
  description = "String describing resource groups to create or reference"
  type        = string
  default     = null
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

variable "solution" {
  type        = string
  default     = "lsf"
  description = "Provide the value for the solution that is needed for the support of lsf and HPC"
}

variable "ibm_customer_number" {
  type        = string
  sensitive   = true
  default     = null
  description = "Comma-separated list of the IBM Customer Number(s) (ICN) that is used for the Bring Your Own License (BYOL) entitlement check. For more information on how to find your ICN, see [What is my IBM Customer Number (ICN)?](https://www.ibm.com/support/pages/what-my-ibm-customer-number-icn)."
}

variable "worker_node_max_count" {
  type        = number
  default     = 10
  description = "The maximum number of worker nodes that can be deployed in the Spectrum LSF cluster. In order to use the [Resource Connector](https://www.ibm.com/docs/en/spectrum-lsf/10.1.0?topic=lsf-resource-connnector) feature to dynamically create and delete worker nodes based on workload demand, the value selected for this parameter must be larger than worker_node_min_count. If you plan to deploy only static worker nodes in the LSF cluster, e.g., when using Spectrum Scale storage, the value for this parameter should be equal to worker_node_min_count. Enter a value in the range 1 - 500."
  validation {
    condition     = 1 <= var.worker_node_max_count && var.worker_node_max_count <= 500
    error_message = "Input \"worker_node_max_count must\" be >= 1 and <= 500."
  }
}
##############################################################################
# Dedicated Host
##############################################################################

variable "enable_dedicated_host" {
  type        = bool
  default     = false
  description = "Set this option to true to enable dedicated hosts for the VSI created for workload servers, with the default value set to false."
}

variable "dedicated_host_id" {
  type        = string
  description = "Dedicated Host for the worker nodes"
  default     = null
}

variable "worker_node_instance_type" {
  type = list(object({
    count         = number
    instance_type = string
  }))
  description = "The minimum number of worker nodes refers to the static worker nodes provisioned during cluster creation. The solution supports various instance types, so specify the node count based on the requirements of each instance profile. For choices on profile types, see [Instance profiles](https://cloud.ibm.com/docs/vpc?topic=vpc-profiles)."
  default = [
    {
      count         = 3
      instance_type = "bx2-4x16"
    },
    {
      count         = 0
      instance_type = "cx2-8x16"
    }
  ]
}
