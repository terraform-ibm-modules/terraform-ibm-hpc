locals {
  scripts_path              = replace(path.module, "remote_mount_configuration", "scripts")
  ansible_inv_script_path   = format("%s/prepare_remote_mount_inv.py", local.scripts_path)
  compute_private_key       = format("%s/compute_key/id_rsa", var.clone_path) #tfsec:ignore:GEN002
  remote_mnt_inventory_path = format("%s/%s/remote_mount_inventory.ini", var.clone_path, "ibm-spectrum-scale-install-infra")
  remote_mnt_playbook_path  = format("%s/%s/remote_mount_cloud_playbook.yaml", var.clone_path, "ibm-spectrum-scale-install-infra")
}
