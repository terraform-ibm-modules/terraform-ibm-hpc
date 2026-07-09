locals {
  scripts_path            = replace(path.module, "ldap_configuration", "scripts")
  ansible_inv_script_path = format("%s/prepare_ldap_inv.py", local.scripts_path)
  ldap_private_key        = format("%s/ldap_key/id_rsa", var.clone_path)
  ldap_server             = jsonencode(var.ldap_server)
  ldap_inventory_path     = format("%s/%s/ldap_inventory.ini", var.clone_path, "ibm-spectrum-scale-install-infra")
  ldap_configure_playbook = format("%s/%s/ldap_configure_playbook.yaml", var.clone_path, "ibm-spectrum-scale-install-infra")
}
