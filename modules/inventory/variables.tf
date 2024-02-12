variable "hosts" {
  description = "Hosts"
  type        = list(string)
  default     = ["localhost"]
}

variable "user" {
  description = "user"
  type        = string
}

variable "server_name" {
  description = "server_name"
  type        = string
}

variable "inventory_path" {
  description = "Inventory file path"
  type        = string
  default     = "inventory.ini"
}
