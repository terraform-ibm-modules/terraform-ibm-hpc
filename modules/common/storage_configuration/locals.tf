locals {
  scripts_path                    = replace(path.module, "storage_configuration", "scripts")
  ansible_inv_script_path         = var.inventory_format == "ini" ? format("%s/prepare_scale_inv_ini.py", local.scripts_path) : format("%s/prepare_scale_inv_json.py", local.scripts_path)
  wait_for_ssh_script_path        = format("%s/wait_for_ssh_availability.py", local.scripts_path)
  scale_tuning_config_path        = format("%s/%s", var.clone_path, "storagesncparams.profile")
  storage_private_key             = format("%s/storage_key/id_rsa", var.clone_path) #tfsec:ignore:GEN002
  default_metadata_replicas       = var.default_metadata_replicas == null ? jsonencode("None") : jsonencode(var.default_metadata_replicas)
  default_data_replicas           = var.default_data_replicas == null ? jsonencode("None") : jsonencode(var.default_data_replicas)
  storage_inventory_path          = format("%s/%s/storage_inventory.ini", var.clone_path, "ibm-spectrum-scale-install-infra")
  storage_playbook_path           = format("%s/%s/storage_cloud_playbook.yaml", var.clone_path, "ibm-spectrum-scale-install-infra")
  scale_encryption_servers        = var.scale_encryption_enabled && var.scale_encryption_type == "gklm" ? jsonencode(var.scale_encryption_servers) : jsonencode("None")
  scale_encryption_admin_password = var.scale_encryption_enabled ? var.scale_encryption_admin_password : "None"
  ldap_server_cert_path           = format("%s/ldap_key/ldap_cacert.pem", var.clone_path)
  colocate_protocol_instances     = var.colocate_protocol_instances ? "True" : "False"
  is_colocate_protocol_subset     = var.is_colocate_protocol_subset ? "True" : "False"
  enable_mrot_conf                = var.enable_mrot_conf ? "True" : "False"
  enable_ces                      = var.enable_ces ? "True" : "False"
  enable_afm                      = var.enable_afm ? "True" : "False"
  enable_key_protect              = var.enable_key_protect == "key_protect" ? "True" : "False"
  ldap_server                     = jsonencode(var.ldap_server)
}
