##############################################################################
# Account Variables
##############################################################################
variable "ibmcloud_api_key" {
  type        = string
  sensitive   = true
  default     = null
  description = "IBM Cloud API Key that will be used for authentication in scripts run in this module. Only required if certain options are required."
}

variable "lsf_version" {
  type        = string
  default     = "fixpack_15"
  description = "Select the LSF version to deploy: 'fixpack_14' or 'fixpack_15'. Use null to skip LSF deployment."
}

##############################################################################
# Cluster Level Variables
##############################################################################
variable "cluster_prefix" {
  type        = string
  default     = "lsf"
  description = "A unique identifier for resources. Must begin with a letter and end with a letter or number. This cluster_prefix will be prepended to any resources provisioned by this template. Prefixes must be 16 or fewer characters."
  validation {
    error_message = "Prefix must begin and end with a letter and contain only letters, numbers, and - characters."
    condition     = can(regex("^([A-z]|[a-z][-a-z0-9]*[a-z0-9])$", var.cluster_prefix))
  }
}

variable "zones" {
  description = "Region where VPC will be created. To find your VPC region, use `ibmcloud is regions` command to find available regions."
  type        = list(string)
}

variable "remote_allowed_ips" {
  type        = list(string)
  default     = ["10.0.0.0/8"]
  description = "Network CIDR to access the VPC. This is used to manage network ACL rules for accessing the cluster."
}

variable "resource_group_ids" {
  type        = any
  default     = null
  description = "Map describing resource groups to create or reference"
}

##############################################################################
# Compute Variables
##############################################################################
variable "client_subnets" {
  type        = list(string)
  default     = null
  description = "Name of an existing subnets in which the cluster resources will be deployed. If no value is given, then new subnet(s) will be provisioned for the cluster. [Learn more](https://cloud.ibm.com/docs/vpc)"
}

variable "ssh_keys" {
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

variable "cluster_subnet_id" {
  type        = string
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
      profile = string
      count   = number
      image   = string
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
variable "login_subnet_id" {
  type        = string
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
# Deployer Variables
##############################################################################
variable "enable_deployer" {
  type        = bool
  default     = false
  description = "Deployer should be only used for better deployment performance"
}

variable "existing_resource_group" {
  type        = string
  default     = "Default"
  description = "String describing resource groups to create or reference"
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

variable "existing_bastion_security_group_id" {
  type        = string
  default     = null
  description = "Existing Bastion Security Group ID"
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

variable "bastion_fip" {
  type        = string
  default     = null
  description = "bastion node fip"
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

variable "colocate_protocol_instances" {
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

##############################################################################
# Encryption Variables
##############################################################################
variable "key_management" {
  type        = string
  default     = null
  description = "Set the value as key_protect to enable customer managed encryption for boot volume and file share. If the key_management is set as null, IBM Cloud resources will be always be encrypted through provider managed."
  validation {
    condition     = var.key_management == "null" || var.key_management == null || var.key_management == "key_protect"
    error_message = "key_management must be either 'null' or 'key_protect'."
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
  description = "Provide the existing kms key name that you want to use for the IBM Cloud HPC cluster. Note: kms_key_name to be considered only if key_management value is set as key_protect.(for example kms_key_name: my-encryption-key)."
}

variable "boot_volume_encryption_key" {
  type        = string
  default     = null
  description = "The kms_key crn."
}

variable "existing_kms_instance_guid" {
  type        = string
  default     = null
  description = "The existing KMS instance guid."
}

variable "skip_iam_share_authorization_policy" {
  type        = bool
  default     = false
  description = "When using an existing KMS instance name, set this value to true if authorization is already enabled between KMS instance and the VPC file share. Otherwise, default is set to false. Ensuring proper authorization avoids access issues during deployment.For more information on how to create authorization policy manually, see [creating authorization policies for VPC file share](https://cloud.ibm.com/docs/vpc?topic=vpc-file-s2s-auth&interface=ui)."
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

###########################################################################
# Existing Bastion Support variables
###########################################################################

variable "existing_bastion_instance_name" {
  type        = string
  default     = null
  description = "Bastion instance name."
}

###########################################################################
# Application Center variables
###########################################################################

variable "app_center_gui_password" {
  type        = string
  default     = ""
  sensitive   = true
  description = "Password for IBM Spectrum LSF Application Center GUI."
}

###########################################################################
# Login Node variables
###########################################################################
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

variable "vpc_cluster_private_subnets_cidr_blocks" {
  type        = string
  default     = "10.241.0.0/20"
  description = "Provide the CIDR block required for the creation of the compute cluster's private subnet. One CIDR block is required. If using a hybrid environment, modify the CIDR block to avoid conflicts with any on-premises CIDR blocks. Ensure the selected CIDR block size can accommodate the maximum number of management and dynamic compute nodes expected in your cluster. For more information on CIDR block size selection, refer to the documentation, see [Choosing IP ranges for your VPC](https://cloud.ibm.com/docs/vpc?topic=vpc-choosing-ip-ranges-for-your-vpc)."
}

##############################################################################
# SCC Variables
##############################################################################

variable "sccwp_service_plan" {
  description = "IBM service pricing plan."
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
  description = "Flag to enable SCC instance creation. If true, an instance of SCC (Security and Compliance Center) will be created."
}

variable "cspm_enabled" {
  description = "Enable Cloud Security Posture Management (CSPM) for the Workload Protection instance. This will create a trusted profile associated with the SCC Workload Protection instance that has viewer / reader access to the App Config service and viewer access to the Enterprise service. [Learn more](https://cloud.ibm.com/docs/workload-protection?topic=workload-protection-about)."
  type        = bool
  default     = false
  nullable    = false
}

variable "app_config_plan" {
  description = "IBM service pricing plan."
  type        = string
  default     = "basic"
  validation {
    error_message = "Plan for App configuration can only be basic, lite, standard, enterprise.."
    condition = contains(
      ["basic", "lite", "standardv2", "enterprise"],
      var.app_config_plan
    )
  }
}
