variable "prefix" {
  description = "A unique identifier for resources. Must begin with a letter and end with a letter or number. This prefix will be prepended to any resources provisioned by this template. Prefixes must be 16 or fewer characters."
  type        = string

  validation {
    error_message = "Prefix must begin and end with a letter and contain only letters, numbers, and - characters."
    condition     = can(regex("^([A-z]|[a-z][-a-z0-9]*[a-z0-9])$", var.prefix))
  }
}

##############################################################################
# VPC Variables
##############################################################################
variable "vpc_name" {
  type        = string
  default     = null
  description = "Name of an existing VPC in which the cluster resources will be deployed. If no value is given, then a new VPC will be provisioned for the cluster. [Learn more](https://cloud.ibm.com/docs/vpc)"
}

variable "dns_zone_name" {
  description = "The name of the DNS zone to be created."
  default     = null
  type        = string

  validation {
    condition     = alltrue([var.dns_zone_name != null, var.dns_zone_name != ""])
    error_message = "dns_zone_name must not be null or empty when enable_hub is true and skip_custom_resolver_hub_creation is false."
  }

  validation {
    condition = var.dns_zone_name == null ? true : !contains([
      "ibm.com",
      "softlayer.com",
      "bluemix.net",
      "softlayer.local",
      "mybluemix.net",
      "networklayer.com",
      "ibmcloud.com",
      "pdnsibm.net",
      "appdomain.cloud",
      "compass.cobaltiron.com"
    ], var.dns_zone_name)

    error_message = "The specified DNS zone name is not permitted. Please choose a different domain name. [Learn more](https://cloud.ibm.com/docs/dns-svcs?topic=dns-svcs-managing-dns-zones&interface=ui#restricted-dns-zone-names)"
  }
}

variable "dns_records" {
  description = "List of DNS records to be created."
  type = list(object({
    name       = string
    type       = string
    ttl        = number
    rdata      = string
    preference = optional(number, null)
    service    = optional(string, null)
    protocol   = optional(string, null)
    priority   = optional(number, null)
    weight     = optional(number, null)
    port       = optional(number, null)
  }))
  default = []
  validation {
    condition     = length(var.dns_records) == 0 || alltrue([for record in var.dns_records != null ? var.dns_records : [] : (contains(["A", "AAAA", "CNAME", "MX", "PTR", "TXT", "SRV"], record.type))])
    error_message = "Invalid domain resource record type is provided."
  }

  validation {
    condition = length(var.dns_records) == 0 || alltrue([
      for record in var.dns_records == null ? [] : var.dns_records : (
        record.type != "SRV" || (
          record.protocol != null && record.port != null &&
          record.service != null && record.priority != null && record.weight != null
        )
      )
    ])
    error_message = "Invalid SRV record configuration. For 'SRV' records, 'protocol' , 'service', 'priority', 'port' and 'weight' values must be provided."
  }
  validation {
    condition = length(var.dns_records) == 0 || alltrue([
      for record in var.dns_records == null ? [] : var.dns_records : (
        record.type != "MX" || record.preference != null
      )
    ])
    error_message = "Invalid MX record configuration. For 'MX' records, value for 'preference' must be provided."
  }
}

variable "existing_dns_instance_id" {
  description = "Id of an existing dns instance in which the custom resolver is created. Only relevant if enable_hub is set to true."
  type        = string
  default     = null
}

variable "use_existing_dns_instance" {
  description = "Whether to use an existing dns instance. If true, existing_dns_instance_id must be set."
  type        = bool
  default     = false
}
