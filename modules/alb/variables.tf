
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

variable "bastion_subnets" {
  type = list(object({
    name = string
    id   = string
    zone = string
    cidr = string
  }))
  default     = []
  description = "Subnets to launch the bastion host."
}

variable "create_load_balancer" {
  description = "True to create new Load Balancer."
  type        = bool
}

variable "vsi_ids" {
  type = list(
    object({
      id = string,
    })
  )
  description = "VSI data"
}

variable "alb_type" {
  description = "ALB type"
  type        = string
  default     = "private"
}

variable "alb_pools" {
  description = "List of Load Balancer Pools"
  type = list(object({
    name                     = string
    algorithm                = string
    protocol                 = string
    health_delay             = number
    health_retries           = number
    health_timeout           = number
    health_type              = string
    health_monitor_url       = string
    health_monitor_port      = number
    session_persistence_type = string
    lb_pool_members_port     = number
    lb_pool_listener = object({
      port                    = number
      protocol                = string
      idle_connection_timeout = number
    })
  }))
  default = [
    {
      name                     = "%s-alb-pool-8443"
      algorithm                = "round_robin"
      protocol                 = "https"
      health_delay             = 5
      health_retries           = 5
      health_timeout           = 2
      health_type              = "https"
      health_monitor_url       = "/platform/"
      health_monitor_port      = 8443
      session_persistence_type = "http_cookie"
      lb_pool_members_port     = 8443
      lb_pool_listener = {
        port                    = 8443
        protocol                = "https"
        idle_connection_timeout = 50
      }
    },
    {
      name                     = "%s-alb-pool-8444"
      algorithm                = "round_robin"
      protocol                 = "https"
      health_delay             = 5
      health_retries           = 5
      health_timeout           = 2
      health_type              = "https"
      health_monitor_url       = "/"
      health_monitor_port      = 8444
      session_persistence_type = "http_cookie"
      lb_pool_members_port     = 8444
      lb_pool_listener = {
        port                    = 8444
        protocol                = "https"
        idle_connection_timeout = 7200
      }
    },
    {
      name                     = "%s-alb-pool-6080"
      algorithm                = "round_robin"
      protocol                 = "https"
      health_delay             = 5
      health_retries           = 5
      health_timeout           = 2
      health_type              = "https"
      health_monitor_url       = "/"
      health_monitor_port      = 6080
      session_persistence_type = "http_cookie"
      lb_pool_members_port     = 6080
      lb_pool_listener = {
        port                    = 6080
        protocol                = "https"
        idle_connection_timeout = 50
      }
  }]
}