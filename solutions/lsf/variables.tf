##############################################################################
# Offering Variations
##############################################################################
variable "ibm_customer_number" {
  type        = string
  sensitive   = true
  description = "Comma-separated list of the IBM Customer Number(s) (ICN) that is used for the Bring Your Own License (BYOL) entitlement check. For more information on how to find your ICN, see [What is my IBM Customer Number (ICN)?](https://www.ibm.com/support/pages/what-my-ibm-customer-number-icn)."
  validation {
    condition     = can(regex("^[0-9A-Za-z]*([0-9A-Za-z]+,[0-9A-Za-z]+)*$", var.ibm_customer_number))
    error_message = "The IBM customer number input value cannot have special characters."
  }
}

##############################################################################
# Account Variables
##############################################################################
variable "ibmcloud_api_key" {
  type        = string
  sensitive   = true
  description = "IBM Cloud API Key that will be used for authentication in scripts run in this module. Only required if certain options are required."
}

##############################################################################
# Cluster Level Variables
##############################################################################
variable "zones" {
  type        = list(string)
  default     = ["us-south-1", "us-south-2", "us-south-3"]
  description = "Region where VPC will be created. To find your VPC region, use `ibmcloud is regions` command to find available regions."
}

variable "ssh_keys" {
  type        = list(string)
  default     = null
  description = "The key pair to use to access the HPC cluster."
}

variable "allowed_cidr" {
  type        = list(string)
  description = "Network CIDR to access the VPC. This is used to manage network ACL rules for accessing the cluster."
}

variable "prefix" {
  type        = string
  default     = "lsf"
  description = "A unique identifier for resources. Must begin with a letter and end with a letter or number. This prefix will be prepended to any resources provisioned by this template. Prefixes must be 16 or fewer characters."
  validation {
    error_message = "Prefix must begin and end with a letter and contain only letters, numbers, and - characters."
    condition     = can(regex("^([A-z]|[a-z][-a-z0-9]*[a-z0-9])$", var.prefix))
  }
}

##############################################################################
# Resource Groups Variables
##############################################################################
variable "existing_resource_group" {
  type        = string
  default     = "Default"
  description = "String describing resource groups to create or reference"

}

##############################################################################
# VPC Variables
##############################################################################
variable "vpc_name" {
  type        = string
  default     = null
  description = "Name of an existing VPC in which the cluster resources will be deployed. If no value is given, then a new VPC will be provisioned for the cluster. [Learn more](https://cloud.ibm.com/docs/vpc)"
}

variable "network_cidr" {
  type        = string
  default     = "10.0.0.0/8"
  description = "Network CIDR for the VPC. This is used to manage network ACL rules for cluster provisioning."
}

variable "placement_strategy" {
  type        = string
  default     = null
  description = "VPC placement groups to create (null / host_spread / power_spread)"
}

##############################################################################
# Access Variables
##############################################################################
variable "enable_bastion" {
  type        = bool
  default     = true
  description = "The solution supports multiple ways to connect to your HPC cluster for example, using bastion node, via VPN or direct connection. If connecting to the HPC cluster via VPN or direct connection, set this value to false."
}

variable "bastion_image" {
  type        = string
  default     = "ibm-ubuntu-22-04-3-minimal-amd64-1"
  description = "The image to use to deploy the bastion host."
}

variable "bastion_instance_profile" {
  type        = string
  default     = "cx2-4x8"
  description = "Deployer should be only used for better deployment performance"
}

variable "bastion_ssh_keys" {
  type        = list(string)
  default     = null
  description = "The key pair to use to access the bastion host."
}

variable "bastion_subnets" {
  type        = list(string)
  default     = [""]
  description = "Name of an existing subnets in which the cluster resources will be deployed. If no value is given, then new subnet(s) will be provisioned for the cluster. [Learn more](https://cloud.ibm.com/docs/vpc)"
}

variable "bastion_subnets_cidr" {
  type        = string
  default     = "10.0.0.0/24"
  description = "Subnet CIDR block to launch the bastion host."
}

variable "enable_vpn" {
  type        = bool
  default     = false
  description = "The solution supports multiple ways to connect to your HPC cluster for example, using bastion node, via VPN or direct connection. If connecting to the HPC cluster via VPN, set this value to true."
}

variable "vpn_peer_cidr" {
  type        = list(string)
  default     = null
  description = "The peer CIDRs (e.g., 192.168.0.0/24) to which the VPN will be connected."
}

variable "vpn_peer_address" {
  type        = string
  default     = null
  description = "The peer public IP address to which the VPN will be connected."
}

variable "vpn_preshared_key" {
  type        = string
  default     = null
  description = "The pre-shared key for the VPN."
}

##############################################################################
# Deployer Variables
##############################################################################
variable "enable_deployer" {
  type        = bool
  default     = false
  description = "Deployer should be only used for better deployment performance"
}

variable "deployer_image" {
  type        = string
  default     = "jay-lsf-new-image"
  description = "The image to use to deploy the deployer host."
}

variable "deployer_instance_profile" {
  type        = string
  default     = "bx2-8x32"
  description = "Deployer should be only used for better deployment performance"
}

##############################################################################
# Compute Variables
##############################################################################
variable "client_subnets_cidr" {
  type        = string
  default     = "10.10.10.0/24"
  description = "Subnet CIDR block to launch the client host."
}

variable "client_ssh_keys" {
  type        = list(string)
  default     = null
  description = "The key pair to use to launch the client host."
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
    image   = "ibm-redhat-8-10-minimal-amd64-2"
  }]
  description = "Number of instances to be launched for client."
}

variable "compute_subnets" {
  type        = list(string)
  default     = [""]
  description = "Name of an existing subnets in which the cluster resources will be deployed. If no value is given, then new subnet(s) will be provisioned for the cluster. [Learn more](https://cloud.ibm.com/docs/vpc)"
}

variable "compute_subnets_cidr" {
  type        = string
  default     = "10.10.20.0/24"
  description = "Subnet CIDR block to launch the compute cluster host."
}

variable "compute_ssh_keys" {
  type        = list(string)
  default     = null
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
    image   = "ibm-redhat-8-10-minimal-amd64-2"
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
    image   = "ibm-redhat-8-10-minimal-amd64-2"
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
    count   = 1024
    image   = "ibm-redhat-8-10-minimal-amd64-2"
  }]
  description = "MaxNumber of instances to be launched for compute cluster."
}

variable "compute_gui_username" {
  type        = string
  default     = "admin"
  sensitive   = true
  description = "GUI user to perform system management and monitoring tasks on compute cluster."
}

variable "compute_gui_password" {
  type        = string
  default     = "hpc@IBMCloud"
  sensitive   = true
  description = "Password for compute cluster GUI"
}

# variable "cluster_name" {
#   type        = string
#   default     = "HPCCluster"
#   description = "Unique ID of the cluster used by LSF for configuration of resources. This can be up to 39 alphanumeric characters."
#   validation {
#     condition     = 0 < length(var.cluster_name) && length(var.cluster_name) < 40 && can(regex("^[a-zA-Z0-9_.-]+$", var.cluster_name))
#     error_message = "The ID can be up to 39 alphanumeric characters including the underscore (_), the hyphen (-), and the period (.) characters."
#   }
# }

# variable "enable_hyperthreading" {
#   type        = bool
#   default     = true
#   description = "Setting this to true will enable hyper-threading in the worker nodes of the cluster (default). Otherwise, hyper-threading will be disabled."
# }

# variable "enable_dedicated_host" {
#   type        = bool
#   default     = false
#   description = "Set to true to use dedicated hosts for compute hosts (default: false)."
# }

# variable "dedicated_host_placement" {
#   type        = string
#   default     = "spread"
#   description = "Specify 'pack' or 'spread'. The 'pack' option will deploy VSIs on one dedicated host until full before moving on to the next dedicated host."
#   validation {
#     condition     = var.dedicated_host_placement == "spread" || var.dedicated_host_placement == "pack"
#     error_message = "Supported values for dedicated_host_placement: spread or pack."
#   }
# }

# variable "enable_app_center" {
#   type        = bool
#   default     = false
#   description = "Set to true to install and enable use of the IBM Spectrum LSF Application Center GUI."
# }

# variable "app_center_gui_password" {
#   type        = string
#   default     = "hpc@IBMCloud"
#   sensitive   = true
#   description = "Password for IBM Spectrum LSF Application Center GUI."
# }

# variable "app_center_db_password" {
#   type        = string
#   default     = "hpc@IBMCloud"
#   sensitive   = true
#   description = "Password for IBM Spectrum LSF Application Center database GUI."
# }

##############################################################################
# Storage Scale Variables
##############################################################################
variable "storage_subnets_cidr" {
  type        = string
  default     = "10.10.30.0/24"
  description = "Subnet CIDR block to launch the storage cluster host."
}

variable "storage_ssh_keys" {
  type        = list(string)
  default     = null
  description = "The key pair to use to launch the storage cluster host."
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
    profile         = "bx2-2x8"
    count           = 2
    image           = "ibm-redhat-8-10-minimal-amd64-2"
    filesystem_name = "fs1"
  }]
  description = "Number of instances to be launched for storage cluster."
}

variable "protocol_subnets_cidr" {
  type        = string
  default     = "10.10.40.0/24"
  description = "Subnet CIDR block to launch the storage cluster host."
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
    image   = "ibm-redhat-8-10-minimal-amd64-2"
  }]
  description = "Number of instances to be launched for protocol hosts."
}

variable "storage_gui_username" {
  type        = string
  default     = "admin"
  sensitive   = true
  description = "GUI user to perform system management and monitoring tasks on storage cluster."
}

variable "storage_gui_password" {
  type        = string
  default     = "hpc@IBMCloud"
  sensitive   = true
  description = "Password for storage cluster GUI"
}

variable "file_shares" {
  type = list(
    object({
      mount_path = string,
      size       = number,
      iops       = number
    })
  )
  default = [{
    mount_path = "/mnt/binaries"
    size       = 100
    iops       = 1000
    }, {
    mount_path = "/mnt/data"
    size       = 100
    iops       = 1000
  }]
  description = "Custom file shares to access shared storage"
}

##############################################################################
# DNS Variables
##############################################################################

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

variable "dns_domain_names" {
  type = object({
    compute  = string
    storage  = string
    protocol = string
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
  description = "Provide the name of the existing Key Protect instance associated with the Key Management Service. Note: To use existing kms_instance_name set key_management as key_protect. The name can be found under the details of the KMS, see [View key-protect ID](https://cloud.ibm.com/docs/key-protect?topic=key-protect-retrieve-instance-ID&interface=ui)."
}

variable "kms_key_name" {
  type        = string
  default     = null
  description = "Provide the existing kms key name that you want to use for the IBM Cloud HPC cluster. Note: kms_key_name to be considered only if key_management value is set as key_protect.(for example kms_key_name: my-encryption-key)."
}

variable "hpcs_instance_name" {
  type        = string
  default     = null
  description = "Hyper Protect Crypto Service instance"
}

##############################################################################
# Observability Variables
##############################################################################
variable "enable_cos_integration" {
  type        = bool
  default     = true
  description = "Integrate COS with HPC solution"
}

variable "cos_instance_name" {
  type        = string
  default     = null
  description = "Exiting COS instance name"
}

variable "enable_vpc_flow_logs" {
  type        = bool
  default     = true
  description = "Enable Activity tracker"
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

# variable "scc_profile_version" {
#   type        = string
#   default     = "1.1.0"
#   description = "Version of the Profile to be set on the SCC Instance (accepting empty, CIS and Financial Services profiles versions)"
#   validation {
#     condition     = can(regex("^(|\\d+\\.\\d+(\\.\\d+)?)$", var.scc_profile_version))
#     error_message = "Provide SCC Profile Version to be used."
#   }
# }

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

variable "skip_flowlogs_s2s_auth_policy" {
  type        = bool
  default     = false
  description = "Skip auth policy between flow logs service and COS instance, set to true if this policy is already in place on account."
}

variable "skip_kms_s2s_auth_policy" {
  type        = bool
  default     = false
  description = "Skip auth policy between KMS service and COS instance, set to true if this policy is already in place on account."
}

variable "skip_iam_authorization_policy" {
  type        = bool
  default     = false
  description = "Set to false if authorization policy is required for VPC block storage volumes to access kms. This can be set to true if authorization policy already exists. For more information on how to create authorization policy manually, see [creating authorization policies for block storage volume](https://cloud.ibm.com/docs/vpc?topic=vpc-block-s2s-auth&interface=ui)."
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
