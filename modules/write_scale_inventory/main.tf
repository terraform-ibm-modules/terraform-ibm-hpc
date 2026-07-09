/*
    Write provisioned infrastructure details to JSON.
*/

resource "local_sensitive_file" "itself" {
  content  = <<EOT
{
  "cloud_platform": ${var.cloud_platform},
  "resource_prefix": ${var.resource_prefix},
  "vpc_region": ${var.vpc_region},
  "vpc_availability_zones": ${local.vpc_availability_zones},
  "scale_version": ${var.scale_version},
  "bastion_user": ${var.bastion_user},
  "bastion_instance_id": ${var.bastion_instance_id},
  "bastion_instance_public_ip": ${var.bastion_instance_public_ip},
  "compute_cluster_filesystem_mountpoint": ${var.compute_cluster_filesystem_mountpoint},
  "filesystem_block_size": ${var.filesystem_block_size},
  "compute_cluster_instance_ids": ${local.compute_cluster_instance_ids},
  "compute_cluster_instance_private_ips": ${local.compute_cluster_instance_private_ips},
  "compute_cluster_instance_private_dns_ip_map": ${local.compute_cluster_instance_private_dns_ip_map},
  "compute_cluster_instance_names": ${local.compute_cluster_instance_names},
  "storage_cluster_filesystem_mountpoint": ${var.storage_cluster_filesystem_mountpoint},
  "storage_cluster_instance_ids": ${local.storage_cluster_instance_ids},
  "storage_cluster_instance_private_ips": ${local.storage_cluster_instance_private_ips},
  "storage_cluster_instance_names": ${local.storage_cluster_instance_names},
  "storage_cluster_with_data_volume_mapping": ${local.storage_cluster_with_data_volume_mapping},
  "storage_cluster_instance_private_dns_ip_map": ${local.storage_cluster_instance_private_dns_ip_map},
  "storage_cluster_desc_instance_ids": ${local.storage_cluster_desc_instance_ids},
  "storage_cluster_desc_instance_private_ips": ${local.storage_cluster_desc_instance_private_ips},
  "storage_cluster_desc_data_volume_mapping": ${local.storage_cluster_desc_data_volume_mapping},
  "storage_cluster_desc_instance_private_dns_ip_map": ${local.storage_cluster_desc_instance_private_dns_ip_map},
  "storage_subnet_cidr": ${var.storage_subnet_cidr},
  "compute_subnet_cidr": ${var.compute_subnet_cidr},
  "scale_remote_cluster_clustername": ${var.scale_remote_cluster_clustername},
  "protocol_cluster_instance_names": ${local.protocol_cluster_instance_names},
  "client_cluster_instance_names": ${local.client_cluster_instance_names},
  "protocol_cluster_reserved_names": ${local.protocol_cluster_reserved_names},
  "smb": ${var.smb},
  "nfs": ${var.nfs},
  "object": ${var.object},
  "interface": ${local.interface},
  "export_ip_pool": ${local.export_ip_pool},
  "filesystem": ${var.filesystem},
  "mountpoint": ${var.mountpoint},
  "protocol_gateway_ip": ${var.protocol_gateway_ip},
  "filesets": ${local.filesets},
  "afm_cos_bucket_details": ${local.afm_cos_bucket_details},
  "afm_config_details": ${local.afm_config_details},
  "afm_cluster_instance_names": ${local.afm_cluster_instance_names},
  "filesystem_mountpoint": ${var.filesystem_mountpoint},
  "boot_volume_disk_grow": ${var.boot_volume_disk_grow},
  "block_volume_disk_grow": ${var.block_volume_disk_grow}
}
EOT
  filename = var.json_inventory_path
}
