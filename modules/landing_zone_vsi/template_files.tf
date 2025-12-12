data "template_file" "ldap_user_data" {
  template = file("${path.module}/templates/ldap_user_data.tpl")
  vars = {
    bastion_public_key_content = var.bastion_public_key_content != null ? var.bastion_public_key_content : ""

    cluster_public_key_content = (
      var.scheduler == "LSF" && local.enable_compute ? try(local.compute_public_key_content, "") :
      var.scheduler == "Scale" && local.enable_storage ? try(local.storage_public_key_content, "") :
      ""
    )

    cluster_private_key_content = (
      var.scheduler == "LSF" && local.enable_compute ? try(local.compute_private_key_content, "") :
      var.scheduler == "Scale" && local.enable_storage ? try(local.storage_private_key_content, "") :
      ""
    )

    compute_interfaces = var.storage_type == "vsi" ? local.vsi_interfaces[0] : local.bms_interfaces[0]
    cluster_dns_domain = var.scheduler == "LSF" && local.enable_compute ? var.dns_domain_names["compute"] : "ldap.com"
  }
}

data "template_file" "client_user_data" {
  template = file("${path.module}/templates/client_user_data.tpl")
  vars = {
    bastion_public_key_content = var.bastion_public_key_content != null ? var.bastion_public_key_content : ""
    client_public_key_content  = local.enable_client ? local.client_public_key_content != null ? local.client_public_key_content : "" : ""
    client_private_key_content = local.enable_client ? local.client_private_key_content != null ? local.client_private_key_content : "" : ""
    client_interfaces          = local.vsi_interfaces[0]
    client_dns_domain          = local.enable_client ? var.dns_domain_names["client"] : ""
    client_instance_eth1_mtu   = var.protocol_instance_eth1_mtu
  }
}

data "template_file" "management_user_data" {
  template = file("${path.module}/templates/management_user_data.tpl")
  vars = {
    bastion_public_key_content     = var.bastion_public_key_content != null ? var.bastion_public_key_content : ""
    management_public_key_content  = local.enable_management ? local.compute_public_key_content != null ? local.compute_public_key_content : "" : ""
    management_private_key_content = local.enable_management ? local.compute_private_key_content != null ? local.compute_private_key_content : "" : ""
    management_interfaces          = var.storage_type == "vsi" ? local.vsi_interfaces[0] : local.bms_interfaces[0]
    management_dns_domain          = var.dns_domain_names["compute"]
    mtu_value                      = var.mtu_value
  }
}

data "template_file" "lsf_compute_user_data" {
  template = file("${path.module}/templates/lsf_compute_user_data.tpl")
  vars = {
    bastion_public_key_content     = var.bastion_public_key_content != null ? var.bastion_public_key_content : ""
    management_public_key_content  = local.enable_compute ? local.compute_public_key_content != null ? local.compute_public_key_content : "" : ""
    management_private_key_content = local.enable_compute ? local.compute_private_key_content != null ? local.compute_private_key_content : "" : ""
    management_interfaces          = var.storage_type == "vsi" ? local.vsi_interfaces[0] : local.bms_interfaces[0]
    management_dns_domain          = var.dns_domain_names["compute"]
    # TODO: Fix me
    dynamic_compute_instances = var.dynamic_compute_instances == null ? "" : ""
    mtu_value                 = var.mtu_value
  }
}

data "template_file" "login_user_data" {
  template = file("${path.module}/templates/login_user_data.tpl")
  vars = {
    bastion_public_key_content = var.bastion_public_key_content != null ? var.bastion_public_key_content : ""
    login_public_key_content   = local.enable_compute ? local.compute_public_key_content != null ? local.compute_public_key_content : "" : ""
    login_private_key_content  = local.enable_compute ? local.compute_private_key_content != null ? local.compute_private_key_content : "" : ""
    login_interfaces           = var.storage_type == "vsi" ? local.vsi_interfaces[0] : local.bms_interfaces[0]
    login_dns_domain           = var.dns_domain_names["compute"]
    scheduler                  = var.scheduler
    mtu_value                  = var.mtu_value
  }
}

data "template_file" "scale_compute_user_data" {
  template = file("${path.module}/templates/scale_compute_user_data.tpl")
  vars = {
    bastion_public_key_content   = var.bastion_public_key_content != null ? var.bastion_public_key_content : ""
    compute_public_key_content   = local.enable_compute ? local.compute_public_key_content != null ? local.compute_public_key_content : "" : ""
    compute_private_key_content  = local.enable_compute ? local.compute_private_key_content != null ? local.compute_private_key_content : "" : ""
    compute_interfaces           = local.vsi_interfaces[0]
    compute_dns_domain           = local.enable_compute ? var.dns_domain_names["compute"] : ""
    storage_dns_domain           = local.enable_storage && local.enable_sec_interface_compute ? var.dns_domain_names["storage"] : ""
    protocol_interfaces          = local.vsi_interfaces[1]
    enable_sec_interface_compute = local.enable_sec_interface_compute
  }
}

data "template_file" "storage_user_data" {
  template = file("${path.module}/templates/storage_user_data.tpl")
  vars = {
    bastion_public_key_content   = var.bastion_public_key_content != null ? var.bastion_public_key_content : ""
    storage_public_key_content   = local.enable_storage ? module.storage_key[0].public_key_content : ""
    storage_private_key_content  = local.enable_storage ? module.storage_key[0].private_key_content : ""
    storage_interfaces           = local.vsi_interfaces[0]
    protocol_interfaces          = local.vsi_interfaces[1]
    storage_dns_domain           = local.enable_storage ? var.dns_domain_names["storage"] : ""
    storage_disk_type            = var.storage_type == "vsi" ? try(data.ibm_is_instance_profile.storage[0].disks[0].quantity[0].type, "") : ""
    protocol_dns_domain          = local.enable_protocol && var.colocate_protocol_instances ? var.dns_domain_names["protocol"] : ""
    enable_protocol              = local.enable_protocol && var.colocate_protocol_instances ? true : false
    vpc_region                   = local.enable_protocol && var.colocate_protocol_instances ? var.vpc_region : ""
    resource_group_id            = local.enable_protocol && var.colocate_protocol_instances ? var.resource_group : ""
    protocol_subnets             = local.enable_protocol && var.colocate_protocol_instances ? (length(local.protocol_subnets) > 0 ? local.protocol_subnets[0].id : "") : ""
    enable_sec_interface_storage = local.enable_sec_interface_storage
  }
}

data "template_file" "protocol_user_data" {
  template = file("${path.module}/templates/protocol_user_data.tpl")
  vars = {
    bastion_public_key_content  = var.bastion_public_key_content != null ? var.bastion_public_key_content : ""
    storage_public_key_content  = local.enable_protocol ? module.storage_key[0].public_key_content : ""
    storage_private_key_content = local.enable_protocol ? module.storage_key[0].private_key_content : ""
    storage_interfaces          = local.vsi_interfaces[0]
    protocol_interfaces         = local.vsi_interfaces[1]
    storage_dns_domain          = local.enable_storage ? var.dns_domain_names["storage"] : ""
    protocol_dns_domain         = local.enable_protocol ? var.dns_domain_names["protocol"] : ""
    vpc_region                  = var.vpc_region
    resource_group_id           = var.resource_group
    protocol_subnets            = local.enable_protocol ? (length(local.protocol_subnets) > 0 ? local.protocol_subnets[0].id : "") : ""
    protocol_instance_eth1_mtu  = var.protocol_instance_eth1_mtu

  }
}

data "template_file" "afm_user_data" {
  template = file("${path.module}/templates/afm_user_data.tpl")
  vars = {
    bastion_public_key_content  = var.bastion_public_key_content != null ? var.bastion_public_key_content : ""
    storage_public_key_content  = local.enable_storage ? module.storage_key[0].public_key_content : ""
    storage_private_key_content = local.enable_storage ? module.storage_key[0].private_key_content : ""
    storage_interfaces          = local.vsi_interfaces[0]
    storage_dns_domain          = local.enable_storage ? var.dns_domain_names["storage"] : ""
  }
}

data "template_file" "gklm_user_data" {
  template = file("${path.module}/templates/gklm_user_data.tpl")
  vars = {
    bastion_public_key_content  = var.bastion_public_key_content != null ? var.bastion_public_key_content : ""
    storage_public_key_content  = local.enable_storage ? module.storage_key[0].public_key_content : ""
    storage_private_key_content = local.enable_storage ? module.storage_key[0].private_key_content : ""
    domain_name                 = local.enable_storage ? var.dns_domain_names["gklm"] : ""
  }
}

data "template_file" "storage_bm_user_data" {
  template = file("${path.module}/templates/storage_bm_user_data.tpl")
  vars = {
    bastion_public_key_content  = var.bastion_public_key_content != null ? var.bastion_public_key_content : ""
    storage_public_key_content  = local.enable_storage ? module.storage_key[0].public_key_content : ""
    storage_private_key_content = local.enable_storage ? module.storage_key[0].private_key_content : ""
    storage_interfaces          = local.bms_interfaces[0]
    protocol_interfaces         = local.bms_interfaces[1]
    storage_dns_domain          = local.enable_storage ? var.dns_domain_names["storage"] : ""
    protocol_dns_domain         = local.enable_protocol && var.colocate_protocol_instances ? var.dns_domain_names["protocol"] : ""
    enable_protocol             = local.enable_protocol && var.colocate_protocol_instances ? true : false
    vpc_region                  = local.enable_protocol && var.colocate_protocol_instances ? var.vpc_region : ""
    resource_group_id           = local.enable_protocol && var.colocate_protocol_instances ? var.resource_group : ""
    protocol_subnets            = local.enable_protocol && var.colocate_protocol_instances ? (length(local.protocol_subnets) > 0 ? local.protocol_subnets[0].id : "") : ""
  }
}

data "template_file" "storage_bmtb_user_data" {
  template = file("${path.module}/templates/storage_bmtb_user_data.tpl")
  vars = {
    bastion_public_key_content  = var.bastion_public_key_content != null ? var.bastion_public_key_content : ""
    storage_public_key_content  = local.enable_storage ? module.storage_key[0].public_key_content : ""
    storage_private_key_content = local.enable_storage ? module.storage_key[0].private_key_content : ""
    storage_interfaces          = local.bms_interfaces[0]
    protocol_interfaces         = local.bms_interfaces[1]
    storage_dns_domain          = local.enable_storage ? var.dns_domain_names["storage"] : ""
    protocol_dns_domain         = local.enable_protocol && var.colocate_protocol_instances ? var.dns_domain_names["protocol"] : ""
    enable_protocol             = local.enable_protocol && var.colocate_protocol_instances ? true : false
    vpc_region                  = local.enable_protocol && var.colocate_protocol_instances ? var.vpc_region : ""
    resource_group_id           = local.enable_protocol && var.colocate_protocol_instances ? var.resource_group : ""
    protocol_subnets            = local.enable_protocol && var.colocate_protocol_instances ? (length(local.protocol_subnets) > 0 ? local.protocol_subnets[0].id : "") : ""
  }
}

data "template_file" "protocol_bm_user_data" {
  template = file("${path.module}/templates/protocol_bm_user_data.tpl")
  vars = {
    bastion_public_key_content  = var.bastion_public_key_content != null ? var.bastion_public_key_content : ""
    storage_public_key_content  = local.enable_protocol ? module.storage_key[0].public_key_content : ""
    storage_private_key_content = local.enable_protocol ? module.storage_key[0].private_key_content : ""
    storage_interfaces          = local.bms_interfaces[0]
    protocol_interfaces         = local.bms_interfaces[1]
    storage_dns_domain          = local.enable_storage ? var.dns_domain_names["storage"] : ""
    protocol_dns_domain         = local.enable_protocol ? var.dns_domain_names["protocol"] : ""
    vpc_region                  = var.vpc_region
    resource_group_id           = var.resource_group
    protocol_subnets            = local.enable_protocol ? (length(local.protocol_subnets) > 0 ? local.protocol_subnets[0].id : "") : ""
  }
}

data "template_file" "afm_bm_user_data" {
  template = file("${path.module}/templates/afm_bm_user_data.tpl")
  vars = {
    bastion_public_key_content  = var.bastion_public_key_content != null ? var.bastion_public_key_content : ""
    storage_public_key_content  = local.enable_afm ? module.storage_key[0].public_key_content : ""
    storage_private_key_content = local.enable_afm ? module.storage_key[0].private_key_content : ""
    storage_interfaces          = local.bms_interfaces[0]
    storage_dns_domain          = local.enable_afm ? var.dns_domain_names["storage"] : ""
  }
}
