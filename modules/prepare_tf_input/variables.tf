##############################################################################
# Account Variables
##############################################################################
variable "ibmcloud_api_key" {
  type        = string
  sensitive   = true
  default     = null
  description = "IBM Cloud API Key that will be used for authentication in scripts run in this module. Only required if certain options are required."
}

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

##############################################################################
# Cluster Level Variables
##############################################################################
variable "prefix" {
  type        = string
  default     = "hpc"
  description = "A unique identifier for resources. Must begin with a letter and end with a letter or number. This prefix will be prepended to any resources provisioned by this template. Prefixes must be 16 or fewer characters."
  validation {
    error_message = "Prefix must begin and end with a letter and contain only letters, numbers, and - characters."
    condition     = can(regex("^([A-z]|[a-z][-a-z0-9]*[a-z0-9])$", var.prefix))
  }
}

variable "zones" {
  description = "Region where VPC will be created. To find your VPC region, use `ibmcloud is regions` command to find available regions."
  type        = list(string)
}

variable "allowed_cidr" {
  type        = list(string)
  default     = ["10.0.0.0/8"]
  description = "Network CIDR to access the VPC. This is used to manage network ACL rules for accessing the cluster."
}

variable "existing_resource_group" {
  type        = string
  default     = "Default"
  description = "String describing resource groups to create or reference"

}

##############################################################################
# Compute Variables
##############################################################################
variable "client_subnets" {
  type        = list(string)
  default     = null
  description = "Name of an existing subnets in which the cluster resources will be deployed. If no value is given, then new subnet(s) will be provisioned for the cluster. [Learn more](https://cloud.ibm.com/docs/vpc)"
}

variable "compute_ssh_keys" {
  type        = list(string)
  default     = null
  description = "The key pair to use to launch the compute host."
}

variable "client_instances" {
  type = list(
    object({
      profile = string
      count   = number
      image   = string
    })
  )
  description = "Number of instances to be launched for client."
}

variable "client_ssh_keys" {
  type        = list(string)
  default     = null
  description = "The key pair to use to launch the client host."
}

variable "compute_subnets" {
  type        = list(string)
  default     = null
  description = "Name of an existing subnets in which the cluster resources will be deployed. If no value is given, then new subnet(s) will be provisioned for the cluster. [Learn more](https://cloud.ibm.com/docs/vpc)"
}

variable "management_instances" {
  type = list(
    object({
      profile = string
      count   = number
      image   = string
    })
  )
  description = "Number of instances to be launched for management."
}

variable "static_compute_instances" {
  type = list(
    object({
      profile    = string
      count      = number
      image      = string
      filesystem = string
    })
  )
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
  description = "MaxNumber of instances to be launched for compute cluster."
}

##############################################################################
# Access Variables
##############################################################################
variable "bastion_subnets" {
  type        = list(string)
  default     = null
  description = "Name of an existing subnets in which the cluster resources will be deployed. If no value is given, then new subnet(s) will be provisioned for the cluster. [Learn more](https://cloud.ibm.com/docs/vpc)"
}

##############################################################################
# Storage Variables
##############################################################################
variable "storage_subnets" {
  type        = list(string)
  default     = null
  description = "Name of an existing subnets in which the cluster resources will be deployed. If no value is given, then new subnet(s) will be provisioned for the cluster. [Learn more](https://cloud.ibm.com/docs/vpc)"
}

variable "storage_ssh_keys" {
  type        = list(string)
  default     = null
  description = "The key pair to use to launch the storage cluster host."
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
  description = "Number of instances to be launched for storage cluster."
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
  description = "Number of BareMetal Servers to be launched for storage cluster."
}

variable "protocol_instances" {
  type = list(
    object({
      profile = string
      count   = number
      image   = string
    })
  )
  description = "Number of instances to be launched for protocol hosts."
}

variable "protocol_subnets" {
  type        = list(string)
  default     = null
  description = "Name of an existing subnets in which the cluster resources will be deployed. If no value is given, then new subnet(s) will be provisioned for the cluster. [Learn more](https://cloud.ibm.com/docs/vpc)"
}

##############################################################################
# VPC Variables
##############################################################################
variable "vpc_name" {
  type        = string
  default     = null
  description = "Name of an existing VPC in which the cluster resources will be deployed. If no value is given, then a new VPC will be provisioned for the cluster. [Learn more](https://cloud.ibm.com/docs/vpc)"
}

##############################################################################
# DNS Variables
##############################################################################
variable "dns_domain_names" {
  type = object({
    compute  = string
    storage  = string
    protocol = string
    client   = string
    gklm     = string
  })
  description = "IBM Cloud HPC DNS domain names."
}

##############################################################################
# Deployer Variables
##############################################################################
variable "enable_deployer" {
  type        = bool
  default     = false
  description = "Deployer should be only used for better deployment performance"
}

##############################################################################
# Offering Variations
##############################################################################
variable "ibm_customer_number" {
  type        = string
  sensitive   = true
  description = "Comma-separated list of the IBM Customer Number(s) (ICN) that is used for the Bring Your Own License (BYOL) entitlement check. For more information on how to find your ICN, see [What is my IBM Customer Number (ICN)?](https://www.ibm.com/support/pages/what-my-ibm-customer-number-icn)."
}

##############################################################################
# Observability Variables
##############################################################################
variable "enable_cos_integration" {
  type        = bool
  default     = false
  description = "Integrate COS with HPC solution"
}

variable "enable_vpc_flow_logs" {
  type        = bool
  default     = false
  description = "Enable Activity tracker"
}

##############################################################################
# SCC Variables
##############################################################################
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

##############################################################################
# SCC Variables
##############################################################################

variable "scc_enable" {
  type        = bool
  default     = true
  description = "Flag to enable SCC instance creation. If true, an instance of SCC (Security and Compliance Center) will be created."
}

variable "scc_profile" {
  type        = string
  default     = "CIS IBM Cloud Foundations Benchmark v1.1.0"
  description = "Profile to be set on the SCC Instance (accepting empty, 'CIS IBM Cloud Foundations Benchmark' and 'IBM Cloud Framework for Financial Services')"
  validation {
    condition     = can(regex("^(|CIS IBM Cloud Foundations Benchmark v1.1.0|IBM Cloud Framework for Financial Services)$", var.scc_profile))
    error_message = "Provide SCC Profile Name to be used (accepting empty, 'CIS IBM Cloud Foundations Benchmark' and 'IBM Cloud Framework for Financial Services')."
  }
}

variable "scc_location" {
  description = "Location where the SCC instance is provisioned (possible choices 'us-south', 'eu-de', 'ca-tor', 'eu-es')"
  type        = string
  default     = "us-south"
  validation {
    condition     = can(regex("^(|us-south|eu-de|ca-tor|eu-es)$", var.scc_location))
    error_message = "Provide region where it's possible to deploy an SCC Instance (possible choices 'us-south', 'eu-de', 'ca-tor', 'eu-es') or leave blank and it will default to 'us-south'."
  }
}

variable "scc_event_notification_plan" {
  type        = string
  default     = "lite"
  description = "Event Notifications Instance plan to be used (it's used with S.C.C. instance), possible values 'lite' and 'standard'."
  validation {
    condition     = can(regex("^(|lite|standard)$", var.scc_event_notification_plan))
    error_message = "Provide Event Notification instance plan to be used (accepting 'lite' and 'standard', defaulting to 'lite'). This instance is used in conjuction with S.C.C. one."
  }
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

variable "scc_cos_bucket" {
  type        = string
  default     = null
  description = "scc cos bucket"
}

variable "scc_cos_instance_crn" {
  type        = string
  default     = null
  description = "scc cos instance crn"
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

variable "enable_hyperthreading" {
  description = "Enable or disable hyperthreading"
  type        = bool
  default     = null
}






#############################################################################
# VARIABLES TO BE CHECKED
##############################################################################








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
}

variable "ldap_user_password" {
  type        = string
  sensitive   = true
  default     = ""
  description = "The LDAP user password should be 8 to 20 characters long, with a mix of at least three alphabetic characters, including one uppercase and one lowercase letter. It must also include two numerical digits and at least one special character from (~@_+:) are required.It is important to avoid including the username in the password for enhanced security.[This value is ignored for an existing LDAP server]."
}

variable "ldap_instance_key_pair" {
  type        = list(string)
  default     = null
  description = "Name of the SSH key configured in your IBM Cloud account that is used to establish a connection to the LDAP Server. Make sure that the SSH key is present in the same resource group and region where the LDAP Servers are provisioned. If you do not have an SSH key in your IBM Cloud account, create one by using the [SSH keys](https://cloud.ibm.com/docs/vpc?topic=vpc-ssh-keys) instructions."
}

variable "ldap_instances" {
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

variable "gklm_instance_key_pair" {
  type        = list(string)
  default     = null
  description = "The key pair to use to launch the GKLM host."
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
    image   = "ibm-redhat-8-10-minimal-amd64-4"
  }]
  description = "Number of instances to be launched for client."
}

# variable "scale_encryption_admin_default_password" {
#   type        = string
#   default     = null
#   description = "The default administrator password used for resetting the admin password based on the user input. The password has to be updated which was configured during the GKLM installation."
# }

# variable "scale_encryption_admin_username" {
#   type        = string
#   default     = null
#   description = "The default Admin username for Security Key Lifecycle Manager(GKLM)."
# }

variable "scale_encryption_admin_password" {
  type        = string
  default     = null
  description = "Password that is used for performing administrative operations for the GKLM.The password must contain at least 8 characters and at most 20 characters. For a strong password, at least three alphabetic characters are required, with at least one uppercase and one lowercase letter.  Two numbers, and at least one special character from this(~@_+:). Make sure that the password doesn't include the username. Visit this [page](https://www.ibm.com/docs/en/gklm/3.0.1?topic=roles-password-policy) to know more about password policy of GKLM. "
}

variable "storage_type" {
  type        = string
  default     = "scratch"
  description = "Select the required storage type(scratch/persistent/eval)."
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
}

variable "colocate_protocol_cluster_instances" {
  type        = bool
  default     = true
  description = "Enable it to use storage instances as protocol instances"
}

variable "afm_instances" {
  type = list(
    object({
      profile = string
      count   = number
      image   = string
    })
  )
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
  default     = null
  description = "AFM configurations."
}

variable "filesystem_config" {
  type = list(
    object({
      filesystem               = string
      block_size               = string
      default_data_replica     = number
      default_metadata_replica = number
      max_data_replica         = number
      max_metadata_replica     = number
      mount_point              = string
    })
  )
  default     = null
  description = "File system configurations."
}

variable "scheduler" {
  type        = string
  default     = null
  description = "Select one of the scheduler (LSF/Symphony/Slurm/null)"
}

##############################################################################
# Dedicatedhost Variables
##############################################################################

variable "enable_dedicated_host" {
  type        = bool
  default     = false
  description = "Enables dedicated host to the compute instances"
}
