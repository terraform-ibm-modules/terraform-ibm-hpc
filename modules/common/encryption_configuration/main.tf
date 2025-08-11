
resource "local_sensitive_file" "write_meta_private_key" {
  count           = (tobool(var.turn_on) == true && var.scale_encryption_type == "gklm") ? 1 : 0
  content         = var.meta_private_key
  filename        = local.gklm_private_key
  file_permission = "0600"
}

resource "null_resource" "scale_host_play" {
  count = (tobool(var.turn_on) == true && tobool(var.create_scale_cluster) == true && var.scale_encryption_type == "gklm") ? 1 : 0
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = "sudo ansible-playbook -f 50 -i ${local.scale_all_inventory} -l 'gklm' -e @${local.scale_cluster_hosts} -e 'domain_names=${local.dns_names}' ${local.scale_hostentry_playbook_path}"
  }

  triggers = {
    build = timestamp()
  }
}

resource "null_resource" "perform_encryption_prepare" {
  count = (tobool(var.turn_on) == true && tobool(var.create_scale_cluster) == true && var.scale_encryption_type == "gklm") ? 1 : 0
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = "sudo /usr/local/bin/ansible-playbook -f 32 ${local.encryption_gklm_playbook} -e scale_cluster_clustername=${var.scale_cluster_clustername} -e ansible_ssh_private_key_file=${local.gklm_private_key} -e scale_encryption_admin_default_password=${var.scale_encryption_admin_default_password} -e scale_encryption_admin_password=${var.scale_encryption_admin_password} -e scale_encryption_admin_user=${var.scale_encryption_admin_username} -e '{\"scale_encryption_servers_list\": ${local.scale_encryption_servers}}'"
  }
  depends_on = [local_sensitive_file.write_meta_private_key]
  triggers = {
    build = timestamp()
  }
}

resource "null_resource" "perform_encryption_storage" {
  count = (tobool(var.turn_on) == true && tobool(var.storage_cluster_encryption) == true && tobool(var.storage_cluster_create_complete) == true && tobool(var.remote_mount_create_complete) == true && tobool(var.create_scale_cluster) == true && var.scale_encryption_type == "gklm") ? 1 : 0
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = "sudo /usr/local/bin/ansible-playbook -f 32 -i ${local.storage_inventory_path} ${local.encryption_cluster_playbook} -e '{\"scale_encryption_servers_dns\": ${local.scale_encryption_servers_dns}}'"
  }
  depends_on = [null_resource.perform_encryption_prepare]
  triggers = {
    build = timestamp()
  }
}

resource "null_resource" "perform_encryption_compute" {
  count = (tobool(var.turn_on) == true && tobool(var.compute_cluster_encryption) == true && tobool(var.compute_cluster_create_complete) == true && tobool(var.remote_mount_create_complete) == true && tobool(var.create_scale_cluster) == true && var.scale_encryption_type == "gklm") ? 1 : 0
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = "sudo /usr/local/bin/ansible-playbook -f 32 -i ${local.compute_inventory_path} ${local.encryption_cluster_playbook} -e '{\"scale_encryption_servers_dns\": ${local.scale_encryption_servers_dns}}'"
  }
  depends_on = [null_resource.perform_encryption_prepare, null_resource.perform_encryption_storage]
  triggers = {
    build = timestamp()
  }
}
