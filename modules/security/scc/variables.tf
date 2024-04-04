###############################################################
# Input variables
###############################################################

# Variable for IBM Cloud API Key
variable "ibmcloud_api_key" {
  type        = string
  description = "The IBM Cloud API Key"
  sensitive   = true
}

# Prefix to append to resources name
variable "prefix" {
  type        = string
  description = "Prefix to append to all resources created by this example"
  default     = "scc"
}

# Region
variable "location" {
  description = "Location where the resource is provisioned"
  type = string
  default = "us-south"
}

# Resource Group Name
variable "rg" {
  description = "Name of the resource group associated with the instance"
  type = string
  default = "default"
}

# List of Resource Tags"
variable "tags" {
  description = "Comma-separated list of tags"
  type = list(string)
  default = []
}

# Opt-In feature for SCC Instance
variable "scc_provision" {
  type        = bool
  default     = false
  description = "Flag to enable SCC instance creation. If true, an instance of SCC (Security and Compliance Center) will be created."
}

# SCC Instance Location
variable "scc_location" {
  type        = string
  default     = "us-south"
  description = "SCC Instance region (possible choices 'us-south', 'eu-de', 'ca-tor', 'eu-es')"
}

# SCC Instance Plan
variable "scc_plan" {
  type        = string
  default     = "security-compliance-center-standard-plan"
  description = "SCC Instance plan to be used"
}

# SCC Instance Profile
variable "scc_profile" {
  type        = string
  default     = "1c13d739-e09e-4bf4-8715-dd82e4498041"
  description = "Profile to be set on the SCC Instance (accepting empty, CIS and Financial Services profiles ID)"
}

# SCC Scope Environment
variable "scc_scope_environment" {
  type        = string
  default     = "ibm-cloud"
  description = "SCC Scope reference environment"
}

# SCC Attachment Description
variable "scc_attachment_description" {
  type        = string
  default     = "Attachment automatically created by IBM Cloud HPC"
  description = "Description of the SCC Attachment"
}

# SCC Attachment Schedule
variable "scc_attachment_schedule" {
  type        = string
  default     = "daily"
  description = "Schedule of the SCC Attachment"
}

# SCC Attachment Status
variable "scc_attachment_status" {
  type        = string
  default     = "enabled"
  description = "Status of the SCC Attachment"
}

# Event Notification Instance Plan
variable "event_notification_plan" {
  type        = string
  default     = "lite"
  description = "Event Notifications Instance plan to be used"
}

# Event Notification Instance Service Endpoints
variable "event_notification_service-endpoints" {
  type        = string
  default     = "public-and-private"
  description = "Event Notifications Service Endpoints to be used"
}
