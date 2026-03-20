locals {
  scale_all_inventory                  = format("%s/%s/scale_all_inventory.ini", var.clone_path, "ibm-spectrum-scale-install-infra")
  remove_hostentry_playbooks_path      = format("%s/%s/remove_host_entry_play.yml", var.clone_path, "ibm-spectrum-scale-install-infra")
  cluster_health_refresh_playbook_path = format("%s/%s/scale_cluster_health_refresh.yml", var.clone_path, "ibm-spectrum-scale-install-infra")
  encryption_replication_playbook_path = format("%s/%s/scale_encryption_replication.yml", var.clone_path, "ibm-spectrum-scale-install-infra")
  scale_encryption_servers             = jsonencode(var.scale_encryption_servers)
  storage_inventory_path               = format("%s/%s/storage_inventory.ini", var.clone_path, "ibm-spectrum-scale-install-infra")
  compute_inventory_path               = format("%s/%s/compute_inventory.ini", var.clone_path, "ibm-spectrum-scale-install-infra")
}
