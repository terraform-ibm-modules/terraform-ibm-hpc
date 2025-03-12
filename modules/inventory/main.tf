# resource "local_sensitive_file" "mount_path_file" {
#   content  = join("\n", var.hosts,)
#   filename = var.inventory_path
# }

resource "local_sensitive_file" "mount_path_file" {
  content  = <<EOT
[all_nodes]
${join("\n", var.hosts)}
[all:vars]
name_mount_path_map = {${join(",", [for k, v in var.name_mount_path_map : "\"${k}\": \"${v}\""])}}
EOT
  filename = var.inventory_path
}
