# Variable for IBM Cloud API Key
variable "ibmcloud_api_key" {
  description = "IBM Cloud API Key"
  type        = string
}

variable "activity_tracker_plan" {
  description = "Type of service activity_tracker_plan."
  type        = string
  default     = "7-day"
}

variable "log_analysis_plan" {
  description = "Type of service log_analysis_plan."
  type        = string
  default     = "7-day"
}

variable "observability_monitoring_plan" {
  description = "Type of service observability_monitoring_plan."
  type        = string
  default     = "graduated-tier"
}

variable "location" {
  description = "Location where the resource is provisioned"
  type        = string
  default     = "us-south"
}

variable "activity_tracker_instance_name" {
  description = "Name of the resource activity_tracker_instance_name"
  type        = string
  default     = "demo-auditing-tf-instance"
}

variable "log_analysis_instance_name" {
  description = "Name of the resource log_analysis_instance_name"
  type        = string
  default     = "demo-auditing-tf-instance"
}

variable "cloud_monitoring_instance_name" {
  description = "Name of the resource cloud_monitoring_instance_name"
  type        = string
  default     = "demo-auditing-tf-instance"
}

variable "rg" {
  description = "Name of the resource group associated with the instance"
  type        = string
  default     = "default"
}

variable "activity_tracker_provision" {
  description = "Set true to provision Activity Tracker instance"
  type        = bool
  default     = "false"
}

variable "log_analysis_provision" {
  description = "Set true to provision log_analysis_provision instance"
  type        = bool
  default     = "false"
}

variable "cloud_monitoring_provision" {
  description = "Set true to provision cloud_monitoring_provision instance"
  type        = bool
  default     = "false"
}

variable "tags" {
  description = "Comma-separated list of tags"
  type        = list(string)
  default     = []
}

variable "enable_archive" {
  description = "Set true to enable archive"
  type        = bool
  default     = "false"
}

variable "enable_platform_logs" {
  description = "Set true to enable platform logs"
  type        = bool
  default     = "false"
}

variable "enable_platform_metrics" {
  description = "Set true to enable platform metrics"
  type        = bool
  default     = "false"
}
