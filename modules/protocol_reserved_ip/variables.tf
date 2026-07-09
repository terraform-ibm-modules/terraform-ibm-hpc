variable "total_reserved_ips" {
  type        = number
  description = "Total number of reserved ips."
}

variable "subnet_id" {
  type        = list(string)
  description = "Protocol subnet id."
}

variable "name" {
  type        = string
  description = "Name of reserved ips."
}

variable "protocol_domain" {
  type        = string
  description = "Protocol DNS service id."
}

variable "protocol_dns_service_id" {
  type        = string
  description = "Protocol domain name."
}

variable "protocol_dns_zone_id" {
  type        = string
  description = "Protocol DNS zone id."
}

variable "enable_private_path_nlb" {
  type        = bool
  description = "Enable private path network load balancer for providing CES (NFS) storage."
}
