variable "observability_monitoring_plan" {
  description = "Type of service observability_monitoring_plan."
  type        = string
  default     = "graduated-tier"
}

variable "cluster_prefix" {
  description = "Prefix that is used to name the IBM Cloud HPC cluster and IBM Cloud resources that are provisioned to build the IBM Cloud HPC cluster instance. You cannot create more than one instance of the IBM Cloud HPC cluster with the same name. Ensure that the name is unique. Prefix must start with a lowercase letter and contain only lowercase letters, digits, and hyphens in between. Hyphens must be followed by at least one lowercase letter or digit. There are no leading, trailing, or consecutive hyphens.Character length for cluster_prefix should be less than 16."
  type        = string
  default     = "hpcaas"
}

variable "location" {
  description = "Location where the resource is provisioned"
  type        = string
  default     = "us-south"
}

variable "cloud_logs_instance_name" {
  description = "Name of the resource cloud_logs_instance_name"
  type        = string
  default     = "demo-auditing-tf-instance"
}

variable "cloud_monitoring_instance_name" {
  description = "Name of the resource cloud_monitoring_instance_name"
  type        = string
  default     = "demo-auditing-tf-instance"
}

variable "cloud_logs_as_atracker_target" {
  description = "Set to true if you want cloud logs instance as a target for atracker event routing"
  type        = bool
  default     = false
}

variable "rg" {
  description = "Name of the resource group associated with the instance"
  type        = string
  default     = "default"
}

variable "cloud_logs_provision" {
  description = "Set true to provision cloud_logs_provision instance"
  type        = bool
  default     = false
}

variable "cloud_monitoring_provision" {
  description = "Set true to provision cloud_monitoring_provision instance"
  type        = bool
  default     = false
}

variable "cloud_logs_retention_period" {
  description = "The number of days IBM Cloud Logs will retain the logs data in Priority insights. Allowed values: 7, 14, 30, 60, 90."
  type        = number
  default     = 7
}

variable "tags" {
  description = "Comma-separated list of tags"
  type        = list(string)
  default     = []
}

variable "enable_platform_logs" {
  description = "Setting this to true will create a tenant in the same region that the Cloud Logs instance is provisioned to enable platform logs for that region. NOTE: You can only have 1 tenant per region in an account."
  type        = bool
  default     = true
}

variable "enable_metrics_routing" {
  description = "Enable metrics routing to manage metrics at the account-level by configuring targets and routes that define where data points are routed."
  type        = bool
  default     = false
}

variable "cloud_logs_data_bucket" {
  description = "Query logs stored in Cloud Object Storage directly via the IBM Cloud Logs dashboard and configure bucket retention and archiving policies to meet compliance needs."
  type        = any
}

variable "cloud_metrics_data_bucket" {
  description = "Generate and store metrics from your events so you can visualize, track, and alert on log events in real-time."
  type        = any
}
