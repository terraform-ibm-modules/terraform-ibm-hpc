locals {
  name                        = "lsf"
  tags                        = [var.prefix, local.name]
  ldap_node_name              = format("%s-%s", var.prefix, "ldap")
  ldap_instance_image_id      = var.enable_ldap == true && var.ldap_server == "null" ? data.ibm_is_image.ldap_vsi_image[0].id : "null"
  compute_ssh_keys            = [for name in var.compute_ssh_keys : data.ibm_is_ssh_key.compute[name].id]
}