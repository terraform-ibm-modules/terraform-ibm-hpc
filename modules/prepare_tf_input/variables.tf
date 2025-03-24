##############################################################################
# Account Variables
##############################################################################
variable "ibmcloud_api_key" {
  type        = string
  sensitive   = true
  default     = null
  description = "IBM Cloud API Key that will be used for authentication in scripts run in this module. Only required if certain options are required."
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
      profile = string
      count   = number
      image   = string
    })
  )
  description = "Min Number of instances to be launched for compute cluster."
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
