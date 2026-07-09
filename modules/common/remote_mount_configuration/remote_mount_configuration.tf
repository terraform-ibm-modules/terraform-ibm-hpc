/*
    Executes ansible playbook to configure remote mount between IBM Spectrum Scale compute and storage cluster.
*/

resource "null_resource" "prepare_remote_mnt_inventory_using_jumphost_connection" {
  count = (tobool(var.turn_on) == true && tobool(var.compute_cluster_create_complete) == true && tobool(var.storage_cluster_create_complete) == true && tobool(var.using_jumphost_connection) == true && tobool(var.create_scale_cluster) == true) ? 1 : 0
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = "python3 ${local.ansible_inv_script_path} --compute_tf_inv_path ${var.compute_inventory_path} --compute_gui_inv_path ${var.compute_gui_inventory_path} --storage_tf_inv_path ${var.storage_inventory_path} --storage_gui_inv_path ${var.storage_gui_inventory_path} --install_infra_path ${var.clone_path} --instance_private_key ${local.compute_private_key} --using_rest_initialization ${var.using_rest_initialization} --bastion_user ${var.bastion_user} --bastion_ip ${var.bastion_instance_public_ip} --bastion_ssh_private_key ${var.bastion_ssh_private_key} --compute_cluster_gui_username ${var.compute_cluster_gui_username} --compute_cluster_gui_password ${var.compute_cluster_gui_password} --storage_cluster_gui_username ${var.storage_cluster_gui_username} --storage_cluster_gui_password ${var.storage_cluster_gui_password}"
  }
  triggers = {
    build = timestamp()
  }
}

resource "null_resource" "prepare_remote_mnt_inventory" {
  count = (tobool(var.turn_on) == true && tobool(var.compute_cluster_create_complete) == true && tobool(var.storage_cluster_create_complete) == true && tobool(var.using_jumphost_connection) == false && tobool(var.create_scale_cluster) == true) ? 1 : 0
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = "python3 ${local.ansible_inv_script_path} --compute_tf_inv_path ${var.compute_inventory_path} --compute_gui_inv_path ${var.compute_gui_inventory_path} --storage_tf_inv_path ${var.storage_inventory_path} --storage_gui_inv_path ${var.storage_gui_inventory_path} --install_infra_path ${var.clone_path} --instance_private_key ${local.compute_private_key} --using_rest_initialization ${var.using_rest_initialization} --compute_cluster_gui_username ${var.compute_cluster_gui_username} --compute_cluster_gui_password ${var.compute_cluster_gui_password} --storage_cluster_gui_username ${var.storage_cluster_gui_username} --storage_cluster_gui_password ${var.storage_cluster_gui_password}"
  }
  triggers = {
    build = timestamp()
  }
}

resource "time_sleep" "wait_for_gui_db_initialization" {
  count           = (tobool(var.turn_on) == true && tobool(var.storage_cluster_create_complete) == true && tobool(var.create_scale_cluster) == true) ? 1 : 0
  create_duration = "180s"
  depends_on      = [null_resource.prepare_remote_mnt_inventory, null_resource.prepare_remote_mnt_inventory_using_jumphost_connection]
}

resource "null_resource" "perform_scale_deployment" {
  count = (tobool(var.turn_on) == true && tobool(var.compute_cluster_create_complete) == true && tobool(var.storage_cluster_create_complete) == true && tobool(var.create_scale_cluster) == true) ? 1 : 0
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = "sudo ansible-playbook -i ${local.remote_mnt_inventory_path} -e ansible_python_interpreter=auto ${local.remote_mnt_playbook_path}"
  }
  depends_on = [time_sleep.wait_for_gui_db_initialization, null_resource.prepare_remote_mnt_inventory, null_resource.prepare_remote_mnt_inventory_using_jumphost_connection]
  triggers = {
    build = timestamp()
  }
}
