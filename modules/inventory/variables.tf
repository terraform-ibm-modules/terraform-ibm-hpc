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

# variable "fileshare_mount_path" {
#   description = "File share mount path"
#   type = object({
#     mount_path = string
#   })
#   default     = null
# }

variable "name_mount_path_map" {
  description = "File share mount path"
  #type        = list(string)
  default     = null
}

# variable "fileshare_mount_path" {
#   type = object({
#     mount_path = string
#   })
# }