data "template_file" "client_user_data" {
  template = file("${path.module}/templates/client_user_data.tpl")
  vars = {
    bastion_public_key_content = var.bastion_public_key_content != null ? var.bastion_public_key_content : ""
    client_public_key_content  = local.enable_client ? module.compute_key[0].public_key_content : ""
    client_private_key_content = local.enable_client ? module.compute_key[0].private_key_content : ""
    client_interfaces          = var.storage_type == "scratch" ? local.vsi_interfaces[0] : local.bms_interfaces[0]
    client_dns_domain          = var.dns_domain_names["compute"]
  }
}

data "template_file" "management_user_data" {
  template = file("${path.module}/templates/management_user_data.tpl")
  vars = {
    bastion_public_key_content     = var.bastion_public_key_content != null ? var.bastion_public_key_content : ""
    management_public_key_content  = local.enable_management ? module.compute_key[0].public_key_content : ""
    management_private_key_content = local.enable_management ? module.compute_key[0].private_key_content : ""
    management_interfaces          = var.storage_type == "scratch" ? local.vsi_interfaces[0] : local.bms_interfaces[0]
    management_dns_domain          = var.dns_domain_names["compute"]
  }
}

data "template_file" "compute_user_data" {
  template = file("${path.module}/templates/compute_user_data.tpl")
  vars = {
    bastion_public_key_content  = var.bastion_public_key_content != null ? var.bastion_public_key_content : ""
    compute_public_key_content  = local.enable_compute ? module.compute_key[0].public_key_content : ""
    compute_private_key_content = local.enable_compute ? module.compute_key[0].private_key_content : ""
    compute_interfaces          = var.storage_type == "scratch" ? local.vsi_interfaces[0] : local.bms_interfaces[0]
    compute_dns_domain          = var.dns_domain_names["compute"]
    # TODO: Fix me
    dynamic_compute_instances = var.dynamic_compute_instances == null ? "" : ""
  }
}

data "template_file" "storage_user_data" {
  template = file("${path.module}/templates/storage_user_data.tpl")
  vars = {
    bastion_public_key_content  = var.bastion_public_key_content != null ? var.bastion_public_key_content : ""
    storage_public_key_content  = local.enable_storage ? module.storage_key[0].public_key_content : ""
    storage_private_key_content = local.enable_storage ? module.storage_key[0].private_key_content : ""
    storage_interfaces          = var.storage_type == "scratch" ? local.vsi_interfaces[0] : local.bms_interfaces[0]
    storage_dns_domain          = var.dns_domain_names["storage"]
  }
}

data "template_file" "protocol_user_data" {
  template = file("${path.module}/templates/protocol_user_data.tpl")
  vars = {
    bastion_public_key_content  = var.bastion_public_key_content != null ? var.bastion_public_key_content : ""
    storage_public_key_content  = local.enable_protocol ? module.storage_key[0].public_key_content : ""
    storage_private_key_content = local.enable_protocol ? module.storage_key[0].private_key_content : ""
    storage_interfaces          = var.storage_type == "scratch" ? local.vsi_interfaces[0] : local.bms_interfaces[0]
    protocol_interfaces         = var.storage_type == "scratch" ? local.vsi_interfaces[1] : local.bms_interfaces[1]
    storage_dns_domain          = var.dns_domain_names["storage"]
    protocol_dns_domain         = var.dns_domain_names["protocol"]
  }
}
