# resource "local_sensitive_file" "itself" {
#   content  = join("\n", var.hosts,)
#   filename = var.inventory_path
# }

resource "local_sensitive_file" "itself" {
  content  = <<EOT
[all_nodes]
${join("\n", var.hosts)}

[management_nodes]
${join("\n", [for host in var.hosts : host if can(regex(".*-mgmt-.*", host))])}

[compute_nodes]
${join("\n", [for host in var.hosts : host if can(regex(".*-comp-.*", host))])}

[all:vars]
name_mount_path_map = {${join(",", [for k, v in var.name_mount_path_map : "\"${k}\": \"${v}\""])}}
logs_enable_for_management = ${var.logs_enable_for_management}
logs_enable_for_compute = ${var.logs_enable_for_compute}
cloud_logs_ingress_private_endpoint = ${var.cloud_logs_ingress_private_endpoint}
VPC_APIKEY_VALUE = ${var.VPC_APIKEY_VALUE}
EOT
  filename = var.inventory_path
}