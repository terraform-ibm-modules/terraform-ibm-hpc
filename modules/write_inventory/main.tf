resource "null_resource" "cleanup_json_file" {
  provisioner "local-exec" {
    command = "if [ -f ${var.json_inventory_path} ]; then rm -f ${var.json_inventory_path}; fi"
  }
}

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
  "enable_hyperthreading": ${var.enable_hyperthreading},
  "ibmcloud_api_key": ${jsonencode(var.ibmcloud_api_key)},
  "compute_public_key_content": ${jsonencode(var.compute_public_key_content)},
  "compute_private_key_content": ${jsonencode(var.compute_private_key_content)},
  "vpc_id": ${jsonencode(var.vpc_id)},
  "vcpus": ${jsonencode(local.vcpus)},
  "rc_ncores": ${jsonencode(local.ncores)},
  "rc_ncpus": ${jsonencode(local.ncpus)},
  "rc_mem_in_mb": ${jsonencode(local.mem_in_mb)},
  "rc_max_num": ${jsonencode(local.rc_max_num)},
  "rc_profile": ${jsonencode(local.rc_profile)},
  "image_id": ${jsonencode(local.image_id)},
  "compute_subnet_id": ${jsonencode(var.compute_subnet_id)},
  "region_name": ${jsonencode(var.region)},
  "resource_group_id": ${jsonencode(var.resource_group_id)},
  "zone_name": ${jsonencode(var.zones)},
  "compute_ssh_keys_ids": ${jsonencode(var.compute_ssh_keys_ids)},
  "dynamic_compute_instances": ${jsonencode(var.dynamic_compute_instances)},
  "compute_subnets_cidr": ${jsonencode(var.compute_subnets_cidr)},
  "compute_security_group_id": ${jsonencode(var.compute_security_group_id)},
  "compute_subnet_crn": ${jsonencode(var.compute_subnet_crn)},
  "dns_domain_names": ${jsonencode(var.dns_domain_names)}
}
EOT
  filename = var.json_inventory_path
}
