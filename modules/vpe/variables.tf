########################################################################################################################
# Input Variables
########################################################################################################################
variable "resource_group_id" {
  type        = string
  description = "The ID of the resource group where you want to create the service."
}

##############################################################################
# VPC Variables
##############################################################################

variable "region" {
  description = "The region where VPC and services are deployed"
  type        = string
}

variable "prefix" {
  description = "The prefix that you would like to append to your resources. Value is only used if no value is passed for the `vpe_name` option in the `cloud_services` input variable."
  type        = string
}

variable "vpc_name" {
  description = "A label that can be used as a short name for virtual private endpoints. If `vpe_name` is not specified in the `cloud_services` or `cloud_service_by_crn` input variable lists, VPE names are created in the format `<prefix>-<vpc_name>-<service_name>`. The value that you specify for `vpc_name` must be known at Terraform plan time."
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC where the Endpoint Gateways will be created"
  type        = string
  default     = null
}

variable "subnet_zone_list" {
  description = "List of subnets in the VPC where gateways and reserved IPs will be provisioned. This value is intended to use the `subnet_zone_list` output from the Landing Zone VPC Subnet Module (https://github.com/terraform-ibm-modules/terraform-ibm-landing-zone-vpc) or from templates using that module for subnet creation."
  type = list(
    object({
      name = string
      id   = string
      zone = string
      cidr = optional(string)
    })
  )
  default = []
}

##############################################################################
# VPE Variables
##############################################################################

variable "security_group_ids" {
  description = "List of security group ids to attach to each endpoint gateway."
  type        = list(string)
  default     = null
}

variable "cloud_services" {
  description = "The list of cloud services used to create endpoint gateways. If `vpe_name` is not specified in the list, VPE names are created in the format `<prefix>-<vpc_name>-<service_name>`. The value that you specify for `vpc_name` must be known at Terraform plan time."
  type = set(object({
    service_name                 = string
    vpe_name                     = optional(string), # Full control on the VPE name. If not specified, the VPE name will be computed based on prefix, vpc name and service name.
    allow_dns_resolution_binding = optional(bool, false)
  }))
  default = []
  validation {
    error_message = "The service you're trying to add is not supported. For a list of supported services, see [VPE-enabled services](https://cloud.ibm.com/docs/vpc?topic=vpc-vpe-supported-services). You can add unsupported services in the `cloud_service_by_crn` variable."
    condition = length(var.cloud_services) == 0 ? true : length([
      for service in var.cloud_services :
      service.service_name if !contains([
        "account-management",
        "billing",
        "cloud-object-storage",
        "cloud-object-storage-config",
        "codeengine",
        "container-registry",
        "containers-kubernetes",
        "context-based-restrictions",
        "directlink",
        "dns-svcs",
        "enterprise",
        "global-search-tagging",
        "global-search",
        "global-tagging",
        "globalcatalog",
        "hs-crypto",
        "hs-crypto-cert-mgr",
        "hs-crypto-ep11",
        "hs-crypto-ep11-az1",
        "hs-crypto-ep11-az2",
        "hs-crypto-ep11-az3",
        "hs-crypto-kmip",
        "hs-crypto-tke",
        "iam-svcs",
        "is",
        "kms",
        "messaging",
        "resource-controller",
        "support-center",
        "transit",
        "user-management",
        "vmware",
        "ntp"
      ], service.service_name)
    ]) == 0
  }
}

variable "cloud_service_by_crn" {
  description = "The list of cloud service CRNs used to create endpoint gateways. Use this list to identify services that are not supported by service name in the `cloud_services` variable. For a list of supported services, see [VPE-enabled services](https://cloud.ibm.com/docs/vpc?topic=vpc-vpe-supported-services). If `service_name` is not specified, the CRN is used to find the name. If `vpe_name` is not specified in the list, VPE names are created in the format `<prefix>-<vpc_name>-<service_name>`. The value that you specify for `vpc_name` must be known at Terraform plan time."
  type = set(
    object({
      crn                          = string
      vpe_name                     = optional(string) # Full control on the VPE name. If not specified, the VPE name will be computed based on prefix, vpc name and service name.
      service_name                 = optional(string) # Name of the service used to compute the name of the VPE. If not specified, the service name will be obtained from the crn.
      allow_dns_resolution_binding = optional(bool, true)
    })
  )
  default = []
}

variable "service_endpoints" {
  description = "Service endpoints to use to create endpoint gateways. Can be `public`, or `private`."
  type        = string
  default     = "private"

  validation {
    error_message = "Service endpoints can only be `public` or `private`."
    condition     = contains(["public", "private"], var.service_endpoints)
  }
}

variable "reserved_ips" {
  description = "Map of existing reserved IP names and values. If you wish to create your reserved ips independently and not create new ones you can first run the `reserved-ips` submodule and then copy the output `reserved_ip_map` here."
  type = object({
    name = optional(string) # reserved ip name
  })
  default = {}
}

##############################################################################
