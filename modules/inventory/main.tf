locals {
  ldap_server_inventory = format("%s/ldap_server_inventory.ini", var.playbooks_path)
}

resource "local_sensitive_file" "mount_path_file" {
  content  = <<EOT
[all_nodes]
${join("\n", var.hosts)}

[management_nodes]
${join("\n", [for host in var.hosts : host if can(regex(".*-mgmt-.*", host))])}
[compute_nodes]
${join("\n", [for host in var.hosts : host if can(regex(".*-comp-.*", host))])}

[all:vars]
scheduler = ${jsonencode(var.scheduler)}
name_mount_path_map = {${join(",", [for k, v in var.name_mount_path_map : "\"${k}\": \"${v}\""])}}
logs_enable_for_management = ${var.logs_enable_for_management}
logs_enable_for_compute = ${var.logs_enable_for_compute}
monitoring_enable_for_management = ${var.monitoring_enable_for_management}
monitoring_enable_for_compute = ${var.monitoring_enable_for_compute}
cloud_monitoring_access_key = ${var.cloud_monitoring_access_key}
cloud_monitoring_ingestion_url = ${var.cloud_monitoring_ingestion_url}
cloud_monitoring_prws_key = ${var.cloud_monitoring_prws_key}
cloud_monitoring_prws_url = ${var.cloud_monitoring_prws_url}
cloud_logs_ingress_private_endpoint = ${var.cloud_logs_ingress_private_endpoint}
ha_shared_dir            = ${var.ha_shared_dir}
prefix                   = ${var.prefix}
enable_ldap              = ${var.enable_ldap}
ldap_server              = ${jsonencode(var.ldap_server)}
ldap_basedns             = ${var.ldap_basedns}
ldap_admin_password      = ${var.ldap_admin_password}
ldap_server_cert         = ${replace(var.ldap_server_cert, "\n", "\\n")}
ldap_user_name           = ${var.ldap_user_name}
ldap_user_password       = ${var.ldap_user_password}
EOT
  filename = var.inventory_path
}

resource "local_sensitive_file" "ldap_ini" {
  count    = var.enable_ldap ? 1 : 0
  content  = <<EOT
[ldap_server_node]
${var.ldap_server}

[all:vars]
name_mount_path_map      = {}
ha_shared_dir            = ${var.ha_shared_dir}
prefix                   = ${var.prefix}
enable_ldap              = ${var.enable_ldap}
ldap_server              = ${var.ldap_server}
ldap_basedns             = ${var.ldap_basedns}
ldap_admin_password      = ${var.ldap_admin_password}
ldap_server_cert         = ${replace(var.ldap_server_cert, "\n", "\\n")}
ldap_user_name           = ${var.ldap_user_name}
ldap_user_password       = ${var.ldap_user_password}
EOT
  filename = local.ldap_server_inventory
}
