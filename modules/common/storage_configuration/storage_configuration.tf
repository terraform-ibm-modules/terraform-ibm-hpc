/*
    Executes ansible playbook to install IBM Spectrum Scale storage cluster.
*/

resource "local_file" "create_storage_tuning_parameters" {
  count    = (tobool(var.turn_on) == true && tobool(var.write_inventory_complete) == true) ? 1 : 0
  content  = <<EOT
%cluster:
 numaMemoryInterleave=yes
 ignorePrefetchLUNCount=yes
 workerThreads=1024
 restripeOnDiskFailure=yes
 unmountOnDiskFail=meta
 readReplicaPolicy=local
 nsdSmallThreadRatio=2
 nsdThreadsPerQueue=16
 nsdbufspace=70
 maxblocksize=16M
 maxTcpConnsPerNodeConn=2
 idleSocketTimeout=0
 minMissedPingTimeout=60
 failureDetectionTime=60
 autoload=yes
 autoBuildGPL=yes
 afmDIO=2
EOT
  filename = local.scale_tuning_config_path
}

resource "local_sensitive_file" "write_meta_private_key" {
  count           = (tobool(var.turn_on) == true && tobool(var.write_inventory_complete) == true) ? 1 : 0
  content         = var.meta_private_key
  filename        = local.storage_private_key
  file_permission = "0600"
}

resource "local_sensitive_file" "write_existing_ldap_cert" {
  count           = (tobool(var.turn_on) == true && var.ldap_server_cert != "null") ? 1 : 0
  content         = var.ldap_server_cert
  filename        = local.ldap_server_cert_path
  file_permission = "0600"
}

resource "time_sleep" "wait_300_seconds" {
  count           = (tobool(var.turn_on) == true && tobool(var.write_inventory_complete) == true) && var.storage_type == "baremetal" ? 1 : 0
  create_duration = "300s"
  depends_on      = [local_sensitive_file.write_meta_private_key]
}

resource "null_resource" "scale_baremetal_ssh_check_play" {
  count = (tobool(var.turn_on) == true && tobool(var.write_inventory_complete) == true && tobool(var.create_scale_cluster) == true) && var.storage_type == "baremetal" ? 1 : 0
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = "sudo ansible-playbook -f 50 -i ${local.scale_all_inventory} -l 'storage' -e @${local.scale_baremetal_prerequisite_vars} ${local.scale_baremetal_ssh_check_playbook_path}"
  }
  depends_on = [local_sensitive_file.write_meta_private_key, time_sleep.wait_300_seconds]
  triggers = {
    build = timestamp()
  }
}

resource "null_resource" "scale_host_play" {
  count = (tobool(var.turn_on) == true && tobool(var.write_inventory_complete) == true && tobool(var.create_scale_cluster) == true) ? 1 : 0
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = "sudo ansible-playbook -f 50 -i ${local.scale_all_inventory} -l 'storage' -e @${local.scale_cluster_hosts} -e @${local.domain_name_file} ${local.scale_hostentry_playbook_path}"
  }
  depends_on = [null_resource.scale_baremetal_ssh_check_play, time_sleep.wait_300_seconds]
  triggers = {
    build = timestamp()
  }
}

resource "null_resource" "scale_baremetal_bootdrive_play" {
  count = (tobool(var.turn_on) == true && tobool(var.write_inventory_complete) == true && tobool(var.create_scale_cluster) == true) && var.storage_type == "baremetal" && var.bms_boot_drive_encryption == true ? 1 : 0
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = "sudo ansible-playbook -f 50 -i ${local.scale_all_inventory} -l 'storage' -e @${local.scale_baremetal_prerequisite_vars} ${local.scale_baremetal_bootdrive_playbook_path}"
  }
  depends_on = [null_resource.scale_baremetal_ssh_check_play, null_resource.scale_host_play]
  triggers = {
    build = timestamp()
  }
}

resource "null_resource" "scale_baremetal_prerequisite_play" {
  count = (tobool(var.turn_on) == true && tobool(var.write_inventory_complete) == true && tobool(var.create_scale_cluster) == true) && var.storage_type == "baremetal" ? 1 : 0
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = "sudo ansible-playbook -f 50 -i ${local.scale_all_inventory} -l 'storage' -e @${local.scale_baremetal_prerequisite_vars} ${local.scale_baremetal_prerequisite_playbook_path}"
  }
  depends_on = [null_resource.scale_baremetal_ssh_check_play, null_resource.scale_host_play]
  triggers = {
    build = timestamp()
  }
}

resource "null_resource" "prepare_ansible_inventory_using_jumphost_connection" {
  count = (tobool(var.turn_on) == true && tobool(var.write_inventory_complete) == true && tobool(var.using_jumphost_connection) == true && tobool(var.scale_encryption_enabled) == false) && var.bastion_instance_public_ip != null && var.bastion_ssh_private_key != null ? 1 : 0
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = "python3 ${local.ansible_inv_script_path} --tf_inv_path ${var.inventory_path} --install_infra_path ${var.clone_path} --instance_private_key ${local.storage_private_key} --bastion_user ${var.bastion_user} --bastion_ip ${var.bastion_instance_public_ip} --bastion_ssh_private_key ${var.bastion_ssh_private_key} --disk_type ${var.disk_type} --default_metadata_replicas ${local.default_metadata_replicas} --max_metadata_replicas ${var.max_metadata_replicas} --default_data_replicas ${local.default_data_replicas}  --max_data_replicas ${var.max_data_replicas} --using_packer_image ${var.using_packer_image} --using_rest_initialization ${var.using_rest_initialization} --gui_username ${var.storage_cluster_gui_username} --gui_password ${var.storage_cluster_gui_password} --enable_mrot_conf ${local.enable_mrot_conf}  --enable_ces ${local.enable_ces} --enable_ldap ${var.enable_ldap} --ldap_basedns ${var.ldap_basedns} --ldap_server ${local.ldap_server} --ldap_admin_password ${var.ldap_admin_password} --mgmt_memory ${var.mgmt_memory} --mgmt_vcpus_count ${var.mgmt_vcpus_count} --mgmt_bandwidth ${var.mgmt_bandwidth} --strg_desc_memory ${var.strg_desc_memory} --strg_desc_vcpus_count ${var.strg_desc_vcpus_count} --strg_desc_bandwidth ${var.strg_desc_bandwidth} --strg_memory ${var.strg_memory} --strg_vcpus_count ${var.strg_vcpus_count} --strg_bandwidth ${var.strg_bandwidth} --proto_memory ${var.proto_memory} --proto_vcpus_count ${var.proto_vcpus_count} --proto_bandwidth ${var.proto_bandwidth} --strg_proto_memory ${var.strg_proto_memory} --strg_proto_vcpus_count ${var.strg_proto_vcpus_count} --strg_proto_bandwidth ${var.strg_proto_bandwidth} --colocate_protocol_instances ${local.colocate_protocol_instances} --is_colocate_protocol_subset ${local.is_colocate_protocol_subset}  --enable_afm ${local.enable_afm} --afm_memory ${var.afm_memory} --afm_vcpus_count ${var.afm_vcpus_count} --afm_bandwidth ${var.afm_bandwidth} --enable_key_protect ${local.enable_key_protect}"
  }
  depends_on = [local_file.create_storage_tuning_parameters, local_sensitive_file.write_meta_private_key]
  triggers = {
    build = timestamp()
  }
}

resource "null_resource" "prepare_ansible_inventory_using_jumphost_connection_encryption" {
  count = (tobool(var.turn_on) == true && tobool(var.write_inventory_complete) == true && tobool(var.using_jumphost_connection) == true && tobool(var.scale_encryption_enabled) == true) && var.bastion_instance_public_ip != null && var.bastion_ssh_private_key != null ? 1 : 0
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = "python3 ${local.ansible_inv_script_path} --tf_inv_path ${var.inventory_path} --install_infra_path ${var.clone_path} --instance_private_key ${local.storage_private_key} --bastion_user ${var.bastion_user} --bastion_ip ${var.bastion_instance_public_ip} --bastion_ssh_private_key ${var.bastion_ssh_private_key} --disk_type ${var.disk_type} --default_metadata_replicas ${local.default_metadata_replicas} --max_metadata_replicas ${var.max_metadata_replicas} --default_data_replicas ${local.default_data_replicas}  --max_data_replicas ${var.max_data_replicas} --using_packer_image ${var.using_packer_image} --using_rest_initialization ${var.using_rest_initialization} --gui_username ${var.storage_cluster_gui_username} --gui_password ${var.storage_cluster_gui_password} --enable_mrot_conf ${local.enable_mrot_conf}  --enable_ces ${local.enable_ces} --scale_encryption_enabled ${var.scale_encryption_enabled} --scale_encryption_servers ${local.scale_encryption_servers} --scale_encryption_admin_password ${local.scale_encryption_admin_password} --scale_encryption_type ${var.scale_encryption_type} --enable_ldap ${var.enable_ldap} --ldap_basedns ${var.ldap_basedns} --ldap_server ${local.ldap_server} --ldap_admin_password ${var.ldap_admin_password} --mgmt_memory ${var.mgmt_memory} --mgmt_vcpus_count ${var.mgmt_vcpus_count} --mgmt_bandwidth ${var.mgmt_bandwidth} --strg_desc_memory ${var.strg_desc_memory} --strg_desc_vcpus_count ${var.strg_desc_vcpus_count} --strg_desc_bandwidth ${var.strg_desc_bandwidth} --strg_memory ${var.strg_memory} --strg_vcpus_count ${var.strg_vcpus_count} --strg_bandwidth ${var.strg_bandwidth} --proto_memory ${var.proto_memory} --proto_vcpus_count ${var.proto_vcpus_count} --proto_bandwidth ${var.proto_bandwidth} --strg_proto_memory ${var.strg_proto_memory} --strg_proto_vcpus_count ${var.strg_proto_vcpus_count} --strg_proto_bandwidth ${var.strg_proto_bandwidth} --colocate_protocol_instances ${local.colocate_protocol_instances} --is_colocate_protocol_subset ${local.is_colocate_protocol_subset} --enable_afm ${local.enable_afm} --afm_memory ${var.afm_memory} --afm_vcpus_count ${var.afm_vcpus_count} --afm_bandwidth ${var.afm_bandwidth} --enable_key_protect ${local.enable_key_protect}"
  }
  depends_on = [local_file.create_storage_tuning_parameters, local_sensitive_file.write_meta_private_key]
  triggers = {
    build = timestamp()
  }
}

resource "null_resource" "prepare_ansible_inventory" {
  count = (tobool(var.turn_on) == true && tobool(var.write_inventory_complete) == true && tobool(var.using_jumphost_connection) == false && tobool(var.scale_encryption_enabled) == false) ? 1 : 0
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = "python3 ${local.ansible_inv_script_path} --tf_inv_path ${var.inventory_path} --install_infra_path ${var.clone_path} --instance_private_key ${local.storage_private_key} --disk_type ${var.disk_type} --default_metadata_replicas ${local.default_metadata_replicas} --max_metadata_replicas ${var.max_metadata_replicas} --default_data_replicas ${local.default_data_replicas}  --max_data_replicas ${var.max_data_replicas} --using_packer_image ${var.using_packer_image} --using_rest_initialization ${var.using_rest_initialization} --gui_username ${var.storage_cluster_gui_username} --gui_password ${var.storage_cluster_gui_password} --enable_mrot_conf ${local.enable_mrot_conf}  --enable_ces ${local.enable_ces} --enable_ldap ${var.enable_ldap} --ldap_basedns ${var.ldap_basedns} --ldap_server ${local.ldap_server} --ldap_admin_password ${var.ldap_admin_password} --mgmt_memory ${var.mgmt_memory} --mgmt_vcpus_count ${var.mgmt_vcpus_count} --mgmt_bandwidth ${var.mgmt_bandwidth} --strg_desc_memory ${var.strg_desc_memory} --strg_desc_vcpus_count ${var.strg_desc_vcpus_count} --strg_desc_bandwidth ${var.strg_desc_bandwidth} --strg_memory ${var.strg_memory} --strg_vcpus_count ${var.strg_vcpus_count} --strg_bandwidth ${var.strg_bandwidth} --proto_memory ${var.proto_memory} --proto_vcpus_count ${var.proto_vcpus_count} --proto_bandwidth ${var.proto_bandwidth} --strg_proto_memory ${var.strg_proto_memory} --strg_proto_vcpus_count ${var.strg_proto_vcpus_count} --strg_proto_bandwidth ${var.strg_proto_bandwidth} --mgmt_memory ${var.mgmt_memory} --mgmt_vcpus_count ${var.mgmt_vcpus_count} --mgmt_bandwidth ${var.mgmt_bandwidth} --strg_desc_memory ${var.strg_desc_memory} --strg_desc_vcpus_count ${var.strg_desc_vcpus_count} --strg_desc_bandwidth ${var.strg_desc_bandwidth} --strg_memory ${var.strg_memory} --strg_vcpus_count ${var.strg_vcpus_count} --strg_bandwidth ${var.strg_bandwidth} --proto_memory ${var.proto_memory} --proto_vcpus_count ${var.proto_vcpus_count} --proto_bandwidth ${var.proto_bandwidth} --strg_proto_memory ${var.strg_proto_memory} --strg_proto_vcpus_count ${var.strg_proto_vcpus_count} --strg_proto_bandwidth ${var.strg_proto_bandwidth} --colocate_protocol_instances ${local.colocate_protocol_instances} --is_colocate_protocol_subset ${local.is_colocate_protocol_subset} --enable_afm ${local.enable_afm} --afm_memory ${var.afm_memory} --afm_vcpus_count ${var.afm_vcpus_count} --afm_bandwidth ${var.afm_bandwidth} --enable_key_protect ${local.enable_key_protect}"
  }
  depends_on = [local_file.create_storage_tuning_parameters, local_sensitive_file.write_meta_private_key]
  triggers = {
    build = timestamp()
  }
}

resource "null_resource" "prepare_ansible_inventory_encryption" {
  count = (tobool(var.turn_on) == true && tobool(var.write_inventory_complete) == true && tobool(var.using_jumphost_connection) == false && tobool(var.scale_encryption_enabled) == true) ? 1 : 0
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = "python3 ${local.ansible_inv_script_path} --tf_inv_path ${var.inventory_path} --install_infra_path ${var.clone_path} --instance_private_key ${local.storage_private_key} --disk_type ${var.disk_type} --default_metadata_replicas ${local.default_metadata_replicas} --max_metadata_replicas ${var.max_metadata_replicas} --default_data_replicas ${local.default_data_replicas}  --max_data_replicas ${var.max_data_replicas} --using_packer_image ${var.using_packer_image} --using_rest_initialization ${var.using_rest_initialization} --gui_username ${var.storage_cluster_gui_username} --gui_password ${var.storage_cluster_gui_password} --enable_mrot_conf ${local.enable_mrot_conf}  --enable_ces ${local.enable_ces} --scale_encryption_enabled ${var.scale_encryption_enabled} --scale_encryption_servers ${local.scale_encryption_servers} --scale_encryption_admin_password ${local.scale_encryption_admin_password} --scale_encryption_type ${var.scale_encryption_type} --enable_ldap ${var.enable_ldap} --ldap_basedns ${var.ldap_basedns} --ldap_server ${local.ldap_server} --ldap_admin_password ${var.ldap_admin_password} --mgmt_memory ${var.mgmt_memory} --mgmt_vcpus_count ${var.mgmt_vcpus_count} --mgmt_bandwidth ${var.mgmt_bandwidth} --strg_desc_memory ${var.strg_desc_memory} --strg_desc_vcpus_count ${var.strg_desc_vcpus_count} --strg_desc_bandwidth ${var.strg_desc_bandwidth} --strg_memory ${var.strg_memory} --strg_vcpus_count ${var.strg_vcpus_count} --strg_bandwidth ${var.strg_bandwidth} --proto_memory ${var.proto_memory} --proto_vcpus_count ${var.proto_vcpus_count} --proto_bandwidth ${var.proto_bandwidth} --strg_proto_memory ${var.strg_proto_memory} --strg_proto_vcpus_count ${var.strg_proto_vcpus_count} --strg_proto_bandwidth ${var.strg_proto_bandwidth} --colocate_protocol_instances ${local.colocate_protocol_instances} --is_colocate_protocol_subset ${local.is_colocate_protocol_subset} --enable_afm ${local.enable_afm} --afm_memory ${var.afm_memory} --afm_vcpus_count ${var.afm_vcpus_count} --afm_bandwidth ${var.afm_bandwidth} --enable_key_protect ${local.enable_key_protect}"
  }
  depends_on = [local_file.create_storage_tuning_parameters, local_sensitive_file.write_meta_private_key]
  triggers = {
    build = timestamp()
  }
}

resource "null_resource" "wait_for_ssh_availability" {
  count = (tobool(var.turn_on) == true && tobool(var.write_inventory_complete) == true && tobool(var.create_scale_cluster) == true) ? 1 : 0
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = "python3 ${local.wait_for_ssh_script_path} --tf_inv_path ${var.inventory_path} --cluster_type storage"
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
    command     = "sudo ansible-playbook -f 32 -i ${local.storage_inventory_path} ${local.storage_playbook_path} --extra-vars \"scale_version=${var.scale_version}\" --extra-vars \"scale_install_directory_pkg_path=${var.spectrumscale_rpms_path}\""
  }
  depends_on = [null_resource.scale_host_play, null_resource.scale_baremetal_prerequisite_play, null_resource.scale_baremetal_bootdrive_play, time_sleep.wait_60_seconds, null_resource.wait_for_ssh_availability, null_resource.prepare_ansible_inventory, null_resource.prepare_ansible_inventory_using_jumphost_connection, null_resource.prepare_ansible_inventory, null_resource.prepare_ansible_inventory_using_jumphost_connection]
  triggers = {
    build = timestamp()
  }
}

resource "null_resource" "perform_disk_grow_and_nsd_add" {
  count = (var.block_volume_disk_grow || var.boot_volume_disk_grow) ? 1 : 0
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command = join(" && ", compact([
      var.boot_volume_disk_grow ? "sudo ansible-playbook -f 32 -i ${local.storage_inventory_path} ${local.storage_boot_disk_grow_playbook_path}" : "",
      var.block_volume_disk_grow ? "sudo ansible-playbook -f 32 -i ${local.storage_inventory_path} ${local.storage_block_disk_grow_and_nsd_add_playbook_path}" : ""
    ]))
  }
  depends_on = [null_resource.perform_scale_deployment]
  triggers = {
    build = timestamp()
  }
}
