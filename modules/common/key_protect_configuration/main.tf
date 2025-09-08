resource "null_resource" "perform_encryption_storage" {
  count = (tobool(var.turn_on) == true && tobool(var.storage_cluster_encryption) == true && tobool(var.storage_cluster_create_complete) == true && tobool(var.remote_mount_create_complete) == true && tobool(var.create_scale_cluster) == true && var.scale_encryption_type == "key_protect") ? 1 : 0
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = "sudo /usr/local/bin/ansible-playbook -f 32 -i ${local.storage_inventory_path} ${local.storage_kp_encryption_playbook}"
  }
}

resource "null_resource" "perform_encryption_compute" {
  count = (tobool(var.turn_on) == true && tobool(var.compute_cluster_encryption) == true && tobool(var.compute_cluster_create_complete) == true && tobool(var.remote_mount_create_complete) == true && tobool(var.create_scale_cluster) == true && var.scale_encryption_type == "key_protect") ? 1 : 0
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = "sudo /usr/local/bin/ansible-playbook -f 32 -i ${local.compute_inventory_path} ${local.compute_kp_encryption_playbook}"
  }
}

resource "null_resource" "perform_encryption_gpfs_restart" {
  count = (tobool(var.turn_on) == true && tobool(var.compute_cluster_encryption) == true && tobool(var.compute_cluster_create_complete) == true && tobool(var.remote_mount_create_complete) == true && tobool(var.create_scale_cluster) == true && var.scale_encryption_type == "key_protect") ? 1 : 0
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = "sudo /usr/local/bin/ansible-playbook -f 32 -i ${local.compute_inventory_path} ${local.gpfs_restart_playbook_path}"
  }
  depends_on = [null_resource.perform_encryption_compute]
}
