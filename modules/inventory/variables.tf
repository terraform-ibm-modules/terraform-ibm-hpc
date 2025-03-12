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

# tflint-ignore: all
variable "name_mount_path_map" {
  description = "File share mount path"
  #type        = list(string)
  default = null
}
