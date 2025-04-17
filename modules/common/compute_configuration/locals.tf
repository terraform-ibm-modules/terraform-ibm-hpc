locals {
  scripts_path             = replace(path.module, "compute_configuration", "scripts")
  ansible_inv_script_path  = var.inventory_format == "ini" ? format("%s/prepare_scale_inv_ini.py", local.scripts_path) : format("%s/prepare_scale_inv_json.py", local.scripts_path)
  wait_for_ssh_script_path = format("%s/wait_for_ssh_availability.py", local.scripts_path)
  scale_tuning_config_path = format("%s/%s", var.clone_path, "computesncparams.profile")
  compute_private_key      = format("%s/compute_key/id_rsa", var.clone_path) #tfsec:ignore:GEN002
  compute_inventory_path   = format("%s/%s/compute_inventory.ini", var.clone_path, "ibm-spectrum-scale-install-infra")
  compute_playbook_path    = format("%s/%s/compute_cloud_playbook.yaml", var.clone_path, "ibm-spectrum-scale-install-infra")
  scale_encryption_servers = jsonencode(var.scale_encryption_servers)
  enable_mrot_conf         = var.enable_mrot_conf ? "True" : "False"
  enable_ces               = var.enable_ces ? "True" : "False"
  enable_afm               = var.enable_afm ? "True" : "False"
  enable_key_protect       = var.enable_key_protect == "key_protect" ? "True" : "False"
}