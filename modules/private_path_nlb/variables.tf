########################################################################################################################
# Input Variables
########################################################################################################################
variable "resource_group_id" {
  type        = string
  description = "The ID of the resource group where you want to create the service."
}

variable "tags" {
  type        = list(string)
  description = "Optional list of tags to be added to the private path service."
  default     = []
}

variable "access_tags" {
  type        = list(string)
  description = "A list of access tags to apply to the private path service created by the module, see https://cloud.ibm.com/docs/account?topic=account-access-tags-tutorial for more details."
  default     = []
}

##############################################################################
# VPC Variables
##############################################################################

variable "subnet_id" {
  description = "ID of subnet."
  type        = string
}

##############################################################################
# NLB Variables
##############################################################################

variable "nlb_name" {
  type        = string
  description = "The name of the private path network load balancer."
  default     = "pp-nlb"
}

variable "nlb_backend_pools" {
  type = list(object({
    pool_name                                = string
    pool_algorithm                           = optional(string, "round_robin")
    pool_health_delay                        = optional(number, 5)
    pool_health_retries                      = optional(number, 2)
    pool_health_timeout                      = optional(number, 2)
    pool_health_type                         = optional(string, "tcp")
    pool_health_monitor_url                  = optional(string, "/")
    pool_health_monitor_port                 = optional(number, 80)
    pool_member_port                         = optional(number)
    pool_member_instance_ids                 = optional(list(string), [])
    pool_member_reserved_ip_ids              = optional(list(string), [])
    pool_member_application_load_balancer_id = optional(string)
    listener_port                            = optional(number)
    listener_accept_proxy_protocol           = optional(bool, false)
  }))
  default     = []
  description = "A list describing backend pools for the private path network load balancer."
}

##############################################################################
# Private Path Variables
##############################################################################

variable "private_path_default_access_policy" {
  type        = string
  description = "The policy to use for bindings from accounts without an explicit account policy. The default policy is set to Review all requests. Supported options are `permit`, `deny`, or `review`."
  default     = "review"
}

variable "private_path_service_endpoints" {
  type        = list(string)
  description = "The list of name for the service endpoint where you want to connect your Private Path service. Enter a maximum number of 10 unique endpoint names for your service."
}

variable "private_path_zonal_affinity" {
  type        = bool
  description = "When enabled, the endpoint service preferentially permits connection requests from endpoints in the same zone. Without zonal affinity, requests are distributed to all instances in any zone."
  default     = false
}

variable "private_path_name" {
  type        = string
  description = "The name of the Private Path service for VPC."
}

variable "private_path_publish" {
  type        = bool
  description = "Set this variable to `true` to allows any account to request access to to the Private Path service. If need be, you can also unpublish where access is restricted to the account that created the Private Path service by setting this variable to `false`."
  default     = false
}

variable "private_path_account_policies" {
  type = list(object({
    account       = string
    access_policy = string
  }))
  description = "The account-specific connection request policies."
  default     = []
}
