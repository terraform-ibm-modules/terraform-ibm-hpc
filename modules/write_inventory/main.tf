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
  "enable_hyperthreading": ${jsonencode(var.enable_hyperthreading)},
  "dns_domain_names":${jsonencode(var.dns_domain_names.compute)},
  "ibmcloud_api_key":${jsonencode(var.ibmcloud_api_key)},
  "vcpus":${jsonencode(var.vcpus)},
  "ncores":${jsonencode(var.ncores)},
  "ncpus":${jsonencode(var.ncpus)},
  "memInMB":${jsonencode(var.memInMB)},
  "rc_maxNum":${jsonencode(var.rc_maxNum)},
  "rc_profile":${jsonencode(var.rc_profile)},
  "imageID":${jsonencode(var.imageID)},
  "compute_subnet_id":${jsonencode(var.compute_subnet_id)},
  "region":${jsonencode(var.region)},
  "resource_group_id":${jsonencode(var.resource_group_id)},
  "zones":${jsonencode(var.zones)},
  "compute_ssh_keys_ids":${jsonencode(var.compute_ssh_keys_ids)},
  "dynamic_compute_instances":${jsonencode(var.dynamic_compute_instances)},
  "compute_subnets_cidr": ${jsonencode(var.compute_subnets_cidr)}
}
EOT
  filename = var.json_inventory_path
}

output "write_inventory_complete" {
  value      = true
  depends_on = [local_sensitive_file.itself]
}