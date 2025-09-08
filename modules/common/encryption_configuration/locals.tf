locals {
  gklm_private_key              = format("%s/gklm_key/id_rsa", var.clone_path)
  scale_encryption_servers      = jsonencode(var.scale_encryption_servers)
  scale_encryption_servers_dns  = jsonencode(var.scale_encryption_servers_dns)
  compute_inventory_path        = format("%s/%s/compute_inventory.ini", var.clone_path, "ibm-spectrum-scale-install-infra")
  storage_inventory_path        = format("%s/%s/storage_inventory.ini", var.clone_path, "ibm-spectrum-scale-install-infra")
  encryption_gklm_playbook      = format("%s/%s/encryption_gklm_playbook.yaml", var.clone_path, "ibm-spectrum-scale-install-infra")
  encryption_cluster_playbook   = format("%s/%s/encryption_cluster_playbook.yaml", var.clone_path, "ibm-spectrum-scale-install-infra")
  scale_hostentry_playbook_path = format("%s/%s/scale_host_entry_play.yml", var.clone_path, "ibm-spectrum-scale-install-infra")
  scale_cluster_hosts           = format("%s/%s/scale_cluster_hosts.yml", var.clone_path, "ibm-spectrum-scale-install-infra")
  scale_all_inventory           = format("%s/%s/scale_all_inventory.ini", var.clone_path, "ibm-spectrum-scale-install-infra")
  domain_name_file              = format("%s/%s/domain_names.yml", var.clone_path, "ibm-spectrum-scale-install-infra")
}
