variable "hosts" {
  description = "Hosts"
  type        = list(string)
  default     = ["localhost"]
}

variable "inventory_path" {
  description = "Inventory file path"
  type        = string
  default     = "inventory.ini"
}

variable "enable_bootstrap" {
  type        = bool
  default     = false
  description = "Bootstrap should be only used for better deployment performance"
}