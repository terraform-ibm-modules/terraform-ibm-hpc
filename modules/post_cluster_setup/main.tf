resource "null_resource" "encryption_master_replication_play" {
  count = (tobool(var.turn_on) == true && tobool(var.create_scale_cluster) == true && var.scale_encryption_type == "gklm") ? 1 : 0
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = "sudo /usr/local/bin/ansible-playbook -f 32 ${local.encryption_replication_playbook_path} -e ansible_user=vpcuser -e scale_encryption_admin_password=${var.scale_encryption_admin_password} -e scale_encryption_admin_user=${var.scale_encryption_admin_username} -e 'scale_encryption_servers_list=${local.scale_encryption_servers}'"

  }
  triggers = {
    build = timestamp()
  }
}

resource "null_resource" "refreshing_storage_scale_health_play" {
  count = (tobool(var.turn_on) == true && tobool(var.create_scale_cluster) == true && tobool(var.storage_turn_on) == true) ? 1 : 0
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = "sudo ansible-playbook -f 50 -i ${local.storage_inventory_path} ${local.cluster_health_refresh_playbook_path}"
  }
  triggers = {
    build = timestamp()
  }
}

resource "null_resource" "refreshing_compute_scale_health_play" {
  count = (tobool(var.turn_on) == true && tobool(var.create_scale_cluster) == true && tobool(var.compute_turn_on) == true) ? 1 : 0
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = "sudo ansible-playbook -f 50 -i ${local.compute_inventory_path} ${local.cluster_health_refresh_playbook_path}"
  }
  triggers = {
    build = timestamp()
  }
}

resource "null_resource" "remove_scale_host_entry_play" {
  count = (tobool(var.turn_on) == true && tobool(var.create_scale_cluster) == true) ? 1 : 0
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = "sudo ansible-playbook -f 50 -i ${local.scale_all_inventory} ${local.remove_hostentry_playbooks_path}"
  }
  triggers = {
    build = timestamp()
  }
}

resource "null_resource" "remove_deployer_host_entry_play" {
  count = (tobool(var.turn_on) == true && tobool(var.create_scale_cluster) == true) ? 1 : 0
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = "sudo ansible-playbook -f 50 -i localhost, -c local ${local.remove_hostentry_playbooks_path}"
  }
  triggers = {
    build = timestamp()
  }
  depends_on = [null_resource.remove_scale_host_entry_play]
}
