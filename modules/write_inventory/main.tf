# Write provisioned infrastructure details to JSON.
resource "local_sensitive_file" "infra_details_to_json" {
  content  = <<EOT
{
  "lsf_masters": ${jsonencode(var.lsf_masters)},
  "lsf_servers": ${jsonencode(var.lsf_servers)},
  "lsf_clients": ${jsonencode(var.lsf_clients)},
  "gui_hosts": ${jsonencode(var.gui_hosts)},
  "db_hosts": ${jsonencode(var.db_hosts)},
  "my_cluster_name": ${jsonencode(var.my_cluster_name)},
  "HA_shared_dir": ${jsonencode(var.ha_shared_dir)},
  "NFS_install_dir": ${jsonencode(var.nfs_install_dir)},
  "Enable_Monitoring": ${jsonencode(var.enable_monitoring)},
  "lsf_deployer_hostname": ${jsonencode(var.lsf_deployer_hostname)},
  "compute_dns_name": ${jsonencode(var.compute_dns_name)}
}
EOT
  filename = var.json_inventory_path
}
