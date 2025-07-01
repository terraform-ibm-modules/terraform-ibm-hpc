data "template_file" "storage_user_data" {
  template = file("${path.module}/templates/storage_user_data.tpl")
  vars = {
    bastion_public_key_content  = var.bastion_public_key_content != null ? var.bastion_public_key_content : ""
    storage_public_key_content  = var.storage_public_key_content
    storage_private_key_content = var.storage_private_key_content
    storage_interfaces          = local.bms_interfaces[0]
    storage_dns_domain          = var.dns_domain_names["storage"]
  }
}
