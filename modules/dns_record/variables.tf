##############################################################################
# Account Variables
##############################################################################

variable "ibmcloud_api_key" {
  description = "IBM Cloud API Key that will be used for authentication in scripts run in this module. Only required if certain options are required."
  type        = string
  sensitive   = true
  default     = null
}

variable "enable_bootstrap" {
  type        = bool
  default     = false
  description = "Bootstrap should be only used for better deployment performance"
}

##############################################################################
# DNS Variables
##############################################################################

variable "dns_instance_id" {
  type        = string
  default     = null
  description = "IBM Cloud HPC DNS service resource id."
}

variable "dns_zone_id" {
  type        = string
  default     = null
  description = "IBM Cloud DNS zone id."
}

variable "dns_records" {
  type = list(object({
    name  = string
    rdata = string
  }))
  default     = null
  description = "IBM Cloud HPC DNS record."
}
