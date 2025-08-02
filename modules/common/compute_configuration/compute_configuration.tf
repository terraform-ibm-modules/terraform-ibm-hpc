/*
    Excutes ansible playbook to install IBM Spectrum Scale compute cluster.
*/

resource "local_file" "create_compute_tuning_parameters" {
  count    = (tobool(var.turn_on) == true && tobool(var.write_inventory_complete) == true) ? 1 : 0
  content  = <<EOT
%cluster:
 numaMemoryInterleave=yes
 ignorePrefetchLUNCount=yes
 workerThreads=1024
 idleSocketTimeout=0
 maxblocksize=16M
 minMissedPingTimeout=60
 failureDetectionTime=60
 autoload=yes
 autoBuildGPL=yes
EOT
  filename = local.scale_tuning_config_path
}

resource "local_sensitive_file" "write_meta_private_key" {
  count           = (tobool(var.turn_on) == true && tobool(var.write_inventory_complete) == true) ? 1 : 0
  content         = var.meta_private_key
  filename        = local.compute_private_key
  file_permission = "0600"
}

resource "null_resource" "prepare_ansible_inventory_using_jumphost_connection" {
  count = (tobool(var.turn_on) == true && tobool(var.write_inventory_complete) == true && tobool(var.using_jumphost_connection) == true && tobool(var.scale_encryption_enabled) == false) ? 1 : 0
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = "python3 ${local.ansible_inv_script_path} --tf_inv_path ${var.inventory_path} --install_infra_path ${var.clone_path} --instance_private_key ${local.compute_private_key} --bastion_user ${var.bastion_user} --bastion_ip ${var.bastion_instance_public_ip} --bastion_ssh_private_key ${var.bastion_ssh_private_key} --using_packer_image ${var.using_packer_image} --using_rest_initialization ${var.using_rest_initialization} --gui_username ${var.compute_cluster_gui_username} --gui_password ${var.compute_cluster_gui_password} --enable_mrot_conf ${local.enable_mrot_conf} --enable_ces ${local.enable_ces} --enable_ldap ${var.enable_ldap} --ldap_basedns ${var.ldap_basedns} --ldap_server ${local.ldap_server} --ldap_admin_password ${var.ldap_admin_password} --comp_memory ${var.comp_memory} --comp_vcpus_count ${var.comp_vcpus_count} --comp_bandwidth ${var.comp_bandwidth} --enable_afm ${local.enable_afm}  --enable_key_protect ${local.enable_key_protect}"
  }
  depends_on = [local_file.create_compute_tuning_parameters, local_sensitive_file.write_meta_private_key]
  triggers = {
    build = timestamp()
  }
}

resource "null_resource" "prepare_ansible_inventory_using_jumphost_connection_encryption" {
  count = (tobool(var.turn_on) == true && tobool(var.write_inventory_complete) == true && tobool(var.using_jumphost_connection) == true && tobool(var.scale_encryption_enabled) == true) ? 1 : 0
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = "python3 ${local.ansible_inv_script_path} --tf_inv_path ${var.inventory_path} --install_infra_path ${var.clone_path} --instance_private_key ${local.compute_private_key} --bastion_user ${var.bastion_user} --bastion_ip ${var.bastion_instance_public_ip} --bastion_ssh_private_key ${var.bastion_ssh_private_key} --using_packer_image ${var.using_packer_image} --using_rest_initialization ${var.using_rest_initialization} --gui_username ${var.compute_cluster_gui_username} --gui_password ${var.compute_cluster_gui_password} --enable_mrot_conf ${local.enable_mrot_conf} --enable_ces ${local.enable_ces} --scale_encryption_enabled ${var.scale_encryption_enabled} --scale_encryption_servers ${local.scale_encryption_servers} --scale_encryption_admin_password ${var.scale_encryption_admin_password} --scale_encryption_type ${var.scale_encryption_type} --enable_ldap ${var.enable_ldap} --ldap_basedns ${var.ldap_basedns} --ldap_server ${local.ldap_server} --ldap_admin_password ${var.ldap_admin_password} --comp_memory ${var.comp_memory} --comp_vcpus_count ${var.comp_vcpus_count} --comp_bandwidth ${var.comp_bandwidth} --enable_afm ${local.enable_afm}  --enable_key_protect ${local.enable_key_protect}"
  }
  depends_on = [local_file.create_compute_tuning_parameters, local_sensitive_file.write_meta_private_key]
  triggers = {
    build = timestamp()
  }
}

resource "null_resource" "prepare_ansible_inventory" {
  count = (tobool(var.turn_on) == true && tobool(var.write_inventory_complete) == true && tobool(var.using_jumphost_connection) == false && tobool(var.scale_encryption_enabled) == false) ? 1 : 0
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = "python3 ${local.ansible_inv_script_path} --tf_inv_path ${var.inventory_path} --install_infra_path ${var.clone_path} --instance_private_key ${local.compute_private_key} --using_packer_image ${var.using_packer_image} --using_rest_initialization ${var.using_rest_initialization} --gui_username ${var.compute_cluster_gui_username} --gui_password ${var.compute_cluster_gui_password} --enable_mrot_conf ${local.enable_mrot_conf} --enable_ces ${local.enable_ces} --enable_ldap ${var.enable_ldap} --ldap_basedns ${var.ldap_basedns} --ldap_server ${local.ldap_server} --ldap_admin_password ${var.ldap_admin_password} --comp_memory ${var.comp_memory} --comp_vcpus_count ${var.comp_vcpus_count} --comp_bandwidth ${var.comp_bandwidth} --enable_afm ${local.enable_afm}  --enable_key_protect ${local.enable_key_protect}"
  }
  depends_on = [local_file.create_compute_tuning_parameters, local_sensitive_file.write_meta_private_key]
  triggers = {
    build = timestamp()
  }
}

resource "null_resource" "prepare_ansible_inventory_encryption" {
  count = (tobool(var.turn_on) == true && tobool(var.write_inventory_complete) == true && tobool(var.using_jumphost_connection) == false && tobool(var.scale_encryption_enabled) == true) ? 1 : 0
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = "python3 ${local.ansible_inv_script_path} --tf_inv_path ${var.inventory_path} --install_infra_path ${var.clone_path} --instance_private_key ${local.compute_private_key} --using_packer_image ${var.using_packer_image} --using_rest_initialization ${var.using_rest_initialization} --gui_username ${var.compute_cluster_gui_username} --gui_password ${var.compute_cluster_gui_password} --enable_mrot_conf ${local.enable_mrot_conf} --enable_ces ${local.enable_ces} --scale_encryption_enabled ${var.scale_encryption_enabled} --scale_encryption_servers ${local.scale_encryption_servers} --scale_encryption_admin_password ${var.scale_encryption_admin_password} --scale_encryption_type ${var.scale_encryption_type} --enable_ldap ${var.enable_ldap} --ldap_basedns ${var.ldap_basedns} --ldap_server ${local.ldap_server} --ldap_admin_password ${var.ldap_admin_password} --comp_memory ${var.comp_memory} --comp_vcpus_count ${var.comp_vcpus_count} --comp_bandwidth ${var.comp_bandwidth} --enable_afm ${local.enable_afm} --enable_key_protect ${local.enable_key_protect}"
  }
  depends_on = [local_file.create_compute_tuning_parameters, local_sensitive_file.write_meta_private_key]
  triggers = {
    build = timestamp()
  }
}

resource "null_resource" "wait_for_ssh_availability" {
  count = (tobool(var.turn_on) == true && tobool(var.write_inventory_complete) == true && tobool(var.create_scale_cluster) == true) ? 1 : 0
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = "python3 ${local.wait_for_ssh_script_path} --tf_inv_path ${var.inventory_path} --cluster_type compute"
  }
  depends_on = [null_resource.prepare_ansible_inventory, null_resource.prepare_ansible_inventory_using_jumphost_connection, null_resource.prepare_ansible_inventory_encryption, null_resource.prepare_ansible_inventory_using_jumphost_connection_encryption]
  triggers = {
    build = timestamp()
  }
}

resource "time_sleep" "wait_60_seconds" {
  count           = (tobool(var.turn_on) == true && tobool(var.write_inventory_complete) == true) ? 1 : 0
  create_duration = "60s"
  depends_on      = [null_resource.wait_for_ssh_availability]
}

resource "null_resource" "perform_scale_deployment" {
  count = (tobool(var.turn_on) == true && tobool(var.write_inventory_complete) == true && tobool(var.create_scale_cluster) == true) ? 1 : 0
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = "sudo ansible-playbook -f 32 -i ${local.compute_inventory_path} ${local.compute_playbook_path} --extra-vars \"scale_version=${var.scale_version}\" --extra-vars \"scale_install_directory_pkg_path=${var.spectrumscale_rpms_path}\""
  }
  depends_on = [time_sleep.wait_60_seconds, null_resource.wait_for_ssh_availability, null_resource.prepare_ansible_inventory, null_resource.prepare_ansible_inventory_using_jumphost_connection, null_resource.prepare_ansible_inventory_encryption, null_resource.prepare_ansible_inventory_using_jumphost_connection_encryption]
  triggers = {
    build = timestamp()
  }
}
