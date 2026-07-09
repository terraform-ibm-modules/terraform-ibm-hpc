locals {
  compute_inventory_path         = format("%s/%s/compute_inventory.ini", var.clone_path, "ibm-spectrum-scale-install-infra")
  storage_inventory_path         = format("%s/%s/storage_inventory.ini", var.clone_path, "ibm-spectrum-scale-install-infra")
  compute_kp_encryption_playbook = format("%s/%s/compute_kp_encryption_playbook.yaml", var.clone_path, "ibm-spectrum-scale-install-infra")
  storage_kp_encryption_playbook = format("%s/%s/storage_kp_encryption_playbook.yaml", var.clone_path, "ibm-spectrum-scale-install-infra")
  gpfs_restart_playbook_path     = format("%s/%s/scale_gpfs_restart.yml", var.clone_path, "ibm-spectrum-scale-install-infra")
}
