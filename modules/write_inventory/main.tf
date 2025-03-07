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
  "dns_domain_names": ${jsonencode(var.dns_domain_names)},
  "compute_public_key_content": ${jsonencode(var.compute_public_key_content)},
  "compute_private_key_content": ${jsonencode(var.compute_private_key_content)},
  "enable_hyperthreading": ${jsonencode(var.enable_hyperthreading)},
  "ibmcloud_api_key": ${jsonencode(var.ibmcloud_api_key)},
  "vpc_id": ${jsonencode(var.vpc_id)},
  "vcpus": ${jsonencode(var.vcpus)},
  "rc_ncores": ${jsonencode(var.ncores)},
  "rc_ncpus": ${jsonencode(var.ncpus)},
  "rc_memInMB": ${jsonencode(var.memInMB)},
  "rc_maxNum": ${jsonencode(var.rc_maxNum)},
  "rc_profile": ${jsonencode(var.rc_profile)},
  "imageID": ${jsonencode(var.imageID)},
  "compute_subnet_id": ${jsonencode(var.compute_subnet_id)},
  "regionName": ${jsonencode(var.region)},
  "resource_group_id": ${jsonencode(var.resource_group_id)},
  "zoneName": ${jsonencode(var.zones)},
  "compute_ssh_keys_ids": ${jsonencode(var.compute_ssh_keys_ids)},
  "dynamic_compute_instances": ${jsonencode(var.dynamic_compute_instances)},
  "compute_subnets_cidr": ${jsonencode(var.compute_subnets_cidr)},
  "compute_security_group_id": ${jsonencode(var.compute_security_group_id)},
  "compute_subnet_crn": ${jsonencode(var.compute_subnet_crn)}
}
EOT
  filename = var.json_inventory_path
}

output "write_inventory_complete" {
  value      = true
  depends_on = [local_sensitive_file.itself]
}