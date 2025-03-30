output "write_inventory_complete" {
  description = "Write Inventory Complete"
  value       = true
  depends_on  = [local_sensitive_file.infra_details_to_json]
}

output "compute_dns_name" {
  value = var.compute_dns_name
}

output "test_json" {
  value = jsonencode({
    lsf_masters           = var.lsf_masters,
    lsf_servers           = var.lsf_servers,
    lsf_clients           = var.lsf_clients,
    gui_hosts             = var.gui_hosts,
    db_hosts              = var.db_hosts,
    my_cluster_name       = var.my_cluster_name,
    HA_shared_dir         = var.ha_shared_dir,
    NFS_install_dir       = var.nfs_install_dir,
    Enable_Monitoring     = var.enable_monitoring,
    lsf_deployer_hostname = var.lsf_deployer_hostname,
    compute_dns_name      = var.compute_dns_name
  })
}
