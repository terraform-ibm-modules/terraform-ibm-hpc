/*
    Write provisioned infrastructure details to JSON.
*/

resource "local_sensitive_file" "itself" {
  content = <<EOT
{
  "lsf_masters": ${jsonencode(var.lsf_masters)},
  "lsf_servers": ${jsonencode(var.lsf_servers)},
  "lsf_clients": ${jsonencode(var.lsf_clients)},
  "gui_hosts": ${jsonencode(var.gui_hosts)},
  "db_hosts": ${jsonencode(var.db_hosts)},
  "my_cluster_name": ${jsonencode(var.my_cluster_name)},
  "HA_shared_dir": ${jsonencode(var.ha_shared_dir)},
  "NFS_install_dir": ${jsonencode(var.nfs_install_dir)},
  "Enable_Monitoring": ${jsonencode(var.Enable_Monitoring)},
  "lsf_deployer_hostname": ${jsonencode(var.lsf_deployer_hostname)},
  "cloud_platform": ${var.cloud_platform},
  "resource_prefix": ${var.resource_prefix},
  "vpc_region": ${var.vpc_region},
  "vpc_availability_zones": ${var.vpc_availability_zones},
  "scale_version": ${var.scale_version},
  "compute_cluster_filesystem_mountpoint": ${var.compute_cluster_filesystem_mountpoint},
  "filesystem_block_size": ${var.filesystem_block_size},
  "compute_cluster_instance_ids": ${var.compute_cluster_instance_ids},
  "compute_cluster_instance_private_ips": ${var.compute_cluster_instance_private_ips},
  "compute_cluster_instance_private_dns_ip_map": ${var.compute_cluster_instance_private_dns_ip_map},
  "compute_cluster_instance_names": ${var.compute_cluster_instance_names},
  "storage_cluster_filesystem_mountpoint": ${var.storage_cluster_filesystem_mountpoint},
  "storage_cluster_instance_ids": ${var.storage_cluster_instance_ids},
  "storage_cluster_instance_private_ips": ${var.storage_cluster_instance_private_ips},
  "storage_cluster_with_data_volume_mapping": ${var.storage_cluster_with_data_volume_mapping},
  "storage_cluster_instance_private_dns_ip_map": ${var.storage_cluster_instance_private_dns_ip_map},
  "storage_cluster_desc_instance_ids": ${var.storage_cluster_desc_instance_ids},
  "storage_cluster_desc_instance_private_ips": ${var.storage_cluster_desc_instance_private_ips},
  "storage_cluster_desc_data_volume_mapping": ${var.storage_cluster_desc_data_volume_mapping},
  "storage_cluster_desc_instance_private_dns_ip_map": ${var.storage_cluster_desc_instance_private_dns_ip_map},
  "storage_cluster_instance_names": ${var.storage_cluster_instance_names},
  "storage_subnet_cidr": ${var.storage_subnet_cidr},
  "compute_subnet_cidr": ${var.compute_subnet_cidr},
  "scale_remote_cluster_clustername": ${var.scale_remote_cluster_clustername},
  "protocol_cluster_instance_names": ${var.protocol_cluster_instance_names},
  "client_cluster_instance_names": ${var.client_cluster_instance_names},
  "protocol_cluster_reserved_names": ${var.protocol_cluster_reserved_names},
  "smb": ${var.smb},
  "nfs": ${var.nfs},
  "object": ${var.object},
  "interface": ${var.interface},
  "export_ip_pool": ${var.export_ip_pool},
  "filesystem": ${var.filesystem},
  "mountpoint": ${var.mountpoint},
  "protocol_gateway_ip": ${var.protocol_gateway_ip},
  "filesets": ${var.filesets},
  "afm_cos_bucket_details": ${var.afm_cos_bucket_details},
  "afm_config_details": ${var.afm_config_details},
  "afm_cluster_instance_names": ${var.afm_cluster_instance_names},
  "filesystem_mountpoint": ${var.filesystem_mountpoint}
}
EOT
  filename = var.json_inventory_path
}

output "write_inventory_complete" {
  value      = true
  depends_on = [local_sensitive_file.itself]
}