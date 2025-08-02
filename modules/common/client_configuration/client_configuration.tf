resource "local_sensitive_file" "write_client_meta_private_key" {
  count           = (tobool(var.turn_on) == true && tobool(var.write_inventory_complete) == true) ? 1 : 0
  content         = var.client_meta_private_key
  filename        = local.client_private_key
  file_permission = "0600"
}

resource "null_resource" "prepare_client_inventory_using_jumphost_connection" {
  count = (tobool(var.turn_on) == true && tobool(var.storage_cluster_create_complete) == true && tobool(var.using_jumphost_connection) == true && tobool(var.create_scale_cluster) == true) ? 1 : 0
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = "python3 ${local.ansible_inv_script_path} --client_tf_inv_path ${var.client_inventory_path} --install_infra_path ${var.clone_path} --instance_private_key ${local.client_private_key} --bastion_user ${var.bastion_user} --bastion_ip ${var.bastion_instance_public_ip} --bastion_ssh_private_key ${var.bastion_ssh_private_key} --enable_ldap ${var.enable_ldap} --ldap_basedns ${var.ldap_basedns} --ldap_server ${local.ldap_server} --ldap_admin_password ${var.ldap_admin_password}"
  }
  triggers = {
    build = timestamp()
  }
  depends_on = [resource.local_sensitive_file.write_client_meta_private_key]
}

resource "null_resource" "prepare_client_inventory" {
  count = (tobool(var.turn_on) == true && tobool(var.storage_cluster_create_complete) == true && tobool(var.using_jumphost_connection) == false && tobool(var.create_scale_cluster) == true) ? 1 : 0
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = "python3 ${local.ansible_inv_script_path} --client_tf_inv_path ${var.client_inventory_path} --install_infra_path ${var.clone_path} --instance_private_key ${local.client_private_key} --enable_ldap ${var.enable_ldap} --ldap_basedns ${var.ldap_basedns} --ldap_server ${local.ldap_server} --ldap_admin_password ${var.ldap_admin_password}"
  }
  triggers = {
    build = timestamp()
  }
  depends_on = [resource.local_sensitive_file.write_client_meta_private_key]
}

resource "null_resource" "perform_client_configuration" {
  count = (tobool(var.turn_on) == true && tobool(var.storage_cluster_create_complete) == true && tobool(var.create_scale_cluster) == true) ? 1 : 0
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = "sudo ansible-playbook -i ${local.client_inventory_path} ${local.client_playbook}"
  }
  triggers = {
    build = timestamp()
  }
  depends_on = [resource.local_sensitive_file.write_client_meta_private_key, resource.null_resource.prepare_client_inventory_using_jumphost_connection, resource.null_resource.prepare_client_inventory]
}
