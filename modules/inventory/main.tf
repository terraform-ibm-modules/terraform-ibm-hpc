# resource "local_sensitive_file" "itself" {
#   content  = join("\n", var.hosts,)
#   filename = var.inventory_path
# }

resource "local_sensitive_file" "itself" {
  content  = <<EOT
[lsf_nodes]
${join("\n", var.hosts)}

[all:vars]
name_mount_path_map = {${join(",", [for k, v in var.name_mount_path_map : "\"${k}\": \"${v}\""])}}
EOT
  filename = var.inventory_path
}

# resource "local_sensitive_file" "itself" {
#   content  = <<EOT
# [lsf_nodes]
# ${join("\n", var.hosts)}

# [all:vars]
# name_mount_path_map = {
# ${join("\n", [for k, v in var.name_mount_path_map : "    \"${k}\" = \"${v}\""])}
#   }
# EOT
#   filename = var.inventory_path
# }

# variable "write_inventory" {}

# resource "local_sensitive_file" "itself" {
#   content  = <<EOT
# {
#     "cloud_platform": ${join("\n", var.hosts)},
#     "resource_prefix": ${var.resource_prefix}
# }
# EOT
#   filename = var.inventory_path
# }

# output "write_inventory_complete" {
#   value      = true
#   depends_on = [local_sensitive_file.itself]
# }
