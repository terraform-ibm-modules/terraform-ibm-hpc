variable "name" {
  description = "Name of the Database"
  type        = string
}

variable "mysql_version" {
  description = "MySQL version of the Database"
  type        = string
  default     = "8.0"
}

variable "region" {
  description = "The region where the database must be instantiated"
  type        = string
}

variable "admin_password" {
  description = "The administrator password"
  type        = string
}

variable "resource_group_id" {
  description = "Resource group ID"
  type        = string
  default     = null
}

variable "members" {
  description = "Number of members"
  type        = number
  default     = null
}

variable "memory" {
  description = "Ram in megabyte"
  type        = number
  default     = null
}

variable "disks" {
  description = "Rom in megabyte"
  type        = number
  default     = null
}

variable "vcpu" {
  description = "Number of cpu cores"
  type        = number
  default     = null
}

variable "host_flavour" {
  description = "Allocated host flavor per member."
  type        = string
  default     = null
}

variable "service_endpoints" {
  description = "The service endpoints"
  type        = string
  default     = "private"
}
