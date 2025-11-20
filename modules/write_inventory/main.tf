# Write provisioned infrastructure details to JSON.
resource "local_sensitive_file" "infra_details_to_json" {
  content  = <<EOT
{
  "lsf_masters": ${jsonencode(var.lsf_masters)},
  "lsf_servers": ${jsonencode(var.lsf_servers)},
  "lsf_clients": ${jsonencode(var.lsf_clients)},
  "gui_hosts": ${jsonencode(var.gui_hosts)},
  "db_hosts": ${jsonencode(var.db_hosts)},
  "login_host": ${jsonencode(var.login_host)},
  "prefix": ${jsonencode(var.prefix)},
  "HA_shared_dir": ${jsonencode(var.ha_shared_dir)},
  "NFS_install_dir": ${jsonencode(var.nfs_install_dir)},
  "Enable_Monitoring": ${jsonencode(var.enable_monitoring)},
  "lsf_deployer_hostname": ${jsonencode(var.lsf_deployer_hostname)},
  "dns_domain_names": ${jsonencode(var.dns_domain_names["compute"])},
  "enable_hyperthreading": ${var.enable_hyperthreading},
  "ibmcloud_api_key": "${var.ibmcloud_api_key}",
  "app_center_gui_password": "${var.app_center_gui_password}",
  "lsf_version": "${var.lsf_version}",
  "compute_public_key_content": ${jsonencode(var.compute_public_key_content)},
  "compute_private_key_content": ${jsonencode(var.compute_private_key_content)},
  "vpc_id": "${var.vpc_id}",
  "vcpus": "${local.vcpus}",
  "rc_ncores": ${local.ncores},
  "rc_ncpus": ${local.ncpus},
  "rc_mem_in_mb": ${local.mem_in_mb},
  "rc_max_num": ${local.rc_max_num},
  "rc_profile": "${local.rc_profile}",
  "image_id": "${local.image_id}",
  "compute_subnet_id": "${var.compute_subnet_id}",
  "region_name": "${var.region}",
  "resource_group_id": "${var.resource_group_id}",
  "zone_name": ${jsonencode(var.zones)},
  "compute_ssh_keys_ids": ${jsonencode(var.compute_ssh_keys_ids)},
  "dynamic_compute_instances": ${jsonencode(var.dynamic_compute_instances)},
  "compute_subnets_cidr": ${jsonencode(var.compute_subnets_cidr)},
  "compute_security_group_id": ${jsonencode(var.compute_security_group_id)},
  "compute_subnet_crn": "${var.compute_subnet_crn}",
  "boot_volume_encryption_key": ${local.boot_volume_encryption_key},
  "lsf_pay_per_use": ${var.lsf_pay_per_use},
  "catalog_offering": ${jsonencode(local.catalog_offering)}
}
EOT
  filename = var.json_inventory_path
}
