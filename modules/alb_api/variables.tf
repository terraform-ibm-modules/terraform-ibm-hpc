variable "ibmcloud_api_key" {
  description = "IBM Cloud API Key that will be used for authentication in scripts run in this module. Only required if certain options are required."
  type        = string
  sensitive   = true
  default     = null
}

variable "region" {
  description = "The region where the ALB must be instantiated"
  type        = string
}

variable "resource_group_id" {
  description = "String describing resource groups to create or reference"
  type        = string
  default     = null
}

variable "prefix" {
  description = "A unique identifier for resources. Must begin with a letter and end with a letter or number. This prefix will be prepended to any resources provisioned by this template. Prefixes must be 16 or fewer characters."
  type        = string

  validation {
    error_message = "Prefix must begin and end with a letter and contain only letters, numbers, and - characters."
    condition     = can(regex("^([A-z]|[a-z][-a-z0-9]*[a-z0-9])$", var.prefix))
  }
}

variable "certificate_instance" {
  description = "Certificate instance CRN value. It's the CRN value of a certificate stored in the Secret Manager"
  type        = string
  default     = ""
}

variable "security_group_ids" {
  type        = list(string)
  description = "List of Security group IDs to allow File share access"
  default     = null
}

#variable "bastion_subnets" {
#  type = list(object({
#    name = string
#    id   = string
#    zone = string
#    cidr = string
#  }))
#  default     = []
#  description = "Subnets to launch the bastion host."
#}

variable "bastion_subnets" {
  type = list(string)
  description = "Subnet IDs to launch the bastion host."
  default = []
}

variable "create_load_balancer" {
  description = "True to create new Load Balancer."
  type        = bool
}

variable "vsi_ips" {
  type        = list(string)
  description = "VSI IPv4 addresses"
}
