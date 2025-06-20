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
