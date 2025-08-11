locals {
  scale_all_inventory             = format("%s/%s/scale_all_inventory.ini", var.clone_path, "ibm-spectrum-scale-install-infra")
  remove_hostentry_playbooks_path = format("%s/%s/remove_host_entry_play.yml", var.clone_path, "ibm-spectrum-scale-install-infra")
}
