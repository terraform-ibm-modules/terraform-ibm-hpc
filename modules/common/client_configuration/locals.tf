
locals {
  client_inventory_path   = format("%s/%s/client_inventory.ini", var.clone_path, "ibm-spectrum-scale-install-infra")
  client_playbook         = format("%s/%s/client_cloud_playbook.yaml", var.clone_path, "ibm-spectrum-scale-install-infra")
  scripts_path            = replace(path.module, "client_configuration", "scripts")
  ansible_inv_script_path = format("%s/prepare_client_inv.py", local.scripts_path)
  client_private_key      = format("%s/client_key/id_rsa", var.clone_path)
  ldap_server             = jsonencode(var.ldap_server)
}
