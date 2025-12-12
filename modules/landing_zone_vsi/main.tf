module "compute_key" {
  count  = local.enable_compute ? 1 : 0
  source = "./../key"
  # private_key_path = "./../../modules/ansible-roles/compute_id_rsa" #checkov:skip=CKV_SECRET_6
}

module "client_key" {
  count  = local.enable_client ? 1 : 0
  source = "./../key"
  # private_key_path = "./../../modules/ansible-roles/compute_id_rsa" #checkov:skip=CKV_SECRET_6
}

resource "null_resource" "entitlement_check" {
  count = var.scheduler == "Scale" && var.storage_type != "evaluation" ? 1 : 0
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = "sudo python3 /opt/IBM/cloud_entitlement/entitlement_check.py --products ${local.products} --icns ${var.ibm_customer_number}"
  }
  triggers = {
    build = timestamp()
  }
}

#Checks the Dedicated host profile and stops the build
resource "null_resource" "dedicated_host_validation" {
  count = var.enable_dedicated_host && length(var.static_compute_instances) > 0 && local.should_validate_profile ? 1 : 0

  provisioner "local-exec" {
    command     = <<EOT
      echo "ERROR: Invalid instance profile for available dedicated host detected:"
      echo "${join("\n", local.errors)}"
      echo ""
      echo "Available CURRENT dedicated host profiles:"
%{for p in local.current_dh_profiles~}
      echo " - ${p.name} (${p.family})"
%{endfor~}
      exit 1
    EOT
    interpreter = ["/bin/bash", "-c"]
  }
}

resource "local_sensitive_file" "write_meta_private_key" {
  count           = local.enable_compute ? 1 : 0
  content         = (local.compute_private_key_content)
  filename        = var.enable_deployer ? "${path.root}/../../modules/ansible-roles/compute_id_rsa" : "${path.root}/modules/ansible-roles/compute_id_rsa"
  file_permission = "0600"
}

resource "local_sensitive_file" "copy_compute_private_key_content" {
  count           = local.enable_compute ? 1 : 0
  content         = (local.compute_private_key_content)
  filename        = "/root/.ssh/id_rsa"
  file_permission = "0600"
}

resource "null_resource" "copy_compute_public_key_content" {
  count = local.enable_compute ? 1 : 0

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<EOT
      echo "StrictHostKeyChecking no" >> /root/.ssh/config
      echo "${local.compute_public_key_content}" >> /root/.ssh/authorized_keys
    EOT
  }

  triggers = {
    build = timestamp()
  }
}

module "storage_key" {
  count  = local.enable_storage ? 1 : 0
  source = "./../key"
  # private_key_path = var.enable_deployer ? "${path.root}/../../modules/ansible-roles/storage_id_rsa" : "${path.root}/modules/ansible-roles/storage_id_rsa" #checkov:skip=CKV_SECRET_6
}

module "client_sg" {
  count                        = local.enable_client && var.client_security_group_name == null ? 1 : 0
  source                       = "terraform-ibm-modules/security-group/ibm"
  version                      = "2.6.2"
  add_ibm_cloud_internal_rules = true
  resource_group               = var.resource_group
  security_group_name          = format("%s-client-sg", local.prefix)
  security_group_rules         = local.client_security_group_rules
  vpc_id                       = var.vpc_id
}

module "compute_sg" {
  count                        = local.enable_compute && var.compute_security_group_name == null ? 1 : 0
  source                       = "terraform-ibm-modules/security-group/ibm"
  version                      = "2.6.2"
  add_ibm_cloud_internal_rules = true
  resource_group               = var.resource_group
  security_group_name          = format("%s-comp-sg", local.prefix)
  security_group_rules         = local.compute_security_group_rules
  vpc_id                       = var.vpc_id
}

module "bastion_sg_existing" {
  count                          = var.login_security_group_name == null ? 1 : 0
  source                         = "terraform-ibm-modules/security-group/ibm"
  version                        = "2.6.2"
  resource_group                 = var.resource_group
  add_ibm_cloud_internal_rules   = false
  use_existing_security_group_id = true
  existing_security_group_id     = var.bastion_security_group_id
  security_group_rules           = local.bastion_security_group_update_rule
  vpc_id                         = var.vpc_id
}

module "nfs_storage_sg" {
  count                          = var.storage_security_group_id != "" ? 1 : 0
  source                         = "terraform-ibm-modules/security-group/ibm"
  version                        = "2.6.2"
  resource_group                 = var.resource_group
  add_ibm_cloud_internal_rules   = true
  use_existing_security_group_id = true
  existing_security_group_id     = var.storage_security_group_id
  security_group_rules           = local.storage_nfs_security_group_rules
  vpc_id                         = var.vpc_id
}

module "storage_sg" {
  count                        = local.enable_storage && var.storage_security_group_name == null ? 1 : 0
  source                       = "terraform-ibm-modules/security-group/ibm"
  version                      = "2.6.2"
  add_ibm_cloud_internal_rules = true
  resource_group               = var.resource_group
  security_group_name          = format("%s-strg-sg", local.prefix)
  security_group_rules         = local.storage_security_group_rules
  vpc_id                       = var.vpc_id
}

module "login_vsi" {
  count                         = var.scheduler == "LSF" ? 1 : 0
  source                        = "terraform-ibm-modules/landing-zone-vsi/ibm"
  version                       = "5.13.0"
  vsi_per_subnet                = 1
  create_security_group         = false
  security_group                = null
  image_id                      = local.login_image_found_in_map ? local.new_login_image_id : data.ibm_is_image.login_vsi_image[0].id
  machine_type                  = var.login_instance[count.index]["profile"]
  prefix                        = local.login_node_name
  resource_group_id             = var.resource_group
  enable_floating_ip            = false
  security_group_ids            = module.compute_sg[*].security_group_id
  ssh_key_ids                   = local.ssh_keys
  subnets                       = length(var.bastion_subnets) == 2 ? [var.bastion_subnets[1]] : [var.bastion_subnets[0]]
  tags                          = local.tags
  user_data                     = data.template_file.login_user_data.rendered
  vpc_id                        = var.vpc_id
  kms_encryption_enabled        = var.kms_encryption_enabled
  skip_iam_authorization_policy = local.skip_iam_authorization_policy
  boot_volume_encryption_key    = var.boot_volume_encryption_key
  boot_volume_size              = local.boot_volume_size
  boot_volume_profile           = local.boot_volume_profile
  boot_volume_iops              = local.boot_volume_iops
  placement_group_id            = var.placement_group_ids
  #placement_group_id = var.placement_group_ids[(var.management_instances[count.index]["count"])%(length(var.placement_group_ids))]
}

module "management_vsi" {
  count                         = length(var.management_instances)
  source                        = "terraform-ibm-modules/landing-zone-vsi/ibm"
  version                       = "5.13.0"
  vsi_per_subnet                = var.management_instances[count.index]["count"]
  create_security_group         = false
  security_group                = null
  catalog_offering              = var.scheduler != "Scale" && var.lsf_pay_per_use ? local.catalog_offering : null
  image_id                      = var.scheduler != "Scale" && var.lsf_pay_per_use ? null : (local.image_mapping_entry_found ? local.new_image_id : data.ibm_is_image.management_stock_image[0].id)
  machine_type                  = var.management_instances[count.index]["profile"]
  prefix                        = format("%s-%s", local.management_node_name, count.index + 1)
  resource_group_id             = var.resource_group
  enable_floating_ip            = false
  security_group_ids            = module.compute_sg[*].security_group_id
  ssh_key_ids                   = local.ssh_keys
  subnets                       = local.compute_subnet_id
  tags                          = local.tags
  user_data                     = data.template_file.management_user_data.rendered
  vpc_id                        = var.vpc_id
  kms_encryption_enabled        = var.kms_encryption_enabled
  skip_iam_authorization_policy = local.skip_iam_authorization_policy
  boot_volume_encryption_key    = var.boot_volume_encryption_key
  boot_volume_size              = local.boot_volume_size
  boot_volume_profile           = local.boot_volume_profile
  boot_volume_iops              = local.boot_volume_iops
  placement_group_id            = var.placement_group_ids
}

module "compute_vsi" {
  count                         = length(var.static_compute_instances)
  source                        = "terraform-ibm-modules/landing-zone-vsi/ibm"
  version                       = "5.13.0"
  vsi_per_subnet                = var.static_compute_instances[count.index]["count"]
  create_security_group         = false
  security_group                = null
  catalog_offering              = var.scheduler != "Scale" && var.lsf_pay_per_use ? local.catalog_offering : null
  image_id                      = var.scheduler != "Scale" && var.lsf_pay_per_use ? null : (var.scheduler == "LSF" ? (local.compute_image_found_in_map ? local.new_compute_image_id : data.ibm_is_image.compute_stock_image[0].id) : (var.storage_type != "evaluation" ? (local.scale_compute_image_found_in_map ? local.scale_compute_image_id : data.ibm_is_image.scale_compute_stock_image[0].id) : local.evaluation_image_id))
  machine_type                  = var.static_compute_instances[count.index]["profile"]
  prefix                        = format("%s-%s", local.compute_node_name, count.index + 1)
  resource_group_id             = var.resource_group
  enable_floating_ip            = false
  security_group_ids            = var.compute_security_group_name == null ? module.compute_sg[*].security_group_id : local.compute_security_group_name_id
  ssh_key_ids                   = local.ssh_keys
  subnets                       = local.compute_subnet_id
  tags                          = local.tags
  user_data                     = var.scheduler == "Scale" ? data.template_file.scale_compute_user_data.rendered : data.template_file.lsf_compute_user_data.rendered
  vpc_id                        = var.vpc_id
  kms_encryption_enabled        = var.kms_encryption_enabled
  skip_iam_authorization_policy = local.skip_iam_authorization_policy
  boot_volume_encryption_key    = var.boot_volume_encryption_key
  boot_volume_size              = local.boot_volume_size
  boot_volume_profile           = local.boot_volume_profile
  boot_volume_iops              = local.boot_volume_iops
  placement_group_id            = var.enable_dedicated_host ? null : var.placement_group_ids
  enable_dedicated_host         = var.enable_dedicated_host
  dedicated_host_id             = var.enable_dedicated_host && length(var.static_compute_instances) > 0 ? local.dedicated_host_map[var.static_compute_instances[count.index]["profile"]] : null
  secondary_security_groups     = local.enable_sec_interface_compute ? local.storage_secondary_security_group : []
  secondary_subnets             = local.enable_sec_interface_compute ? local.storage_subnets : []
  manage_reserved_ips           = local.enable_sec_interface_compute ? true : false
  depends_on                    = [module.dedicated_host, null_resource.dedicated_host_validation]
}

module "compute_cluster_management_vsi" {
  count                         = var.scheduler == "Scale" && local.enable_compute ? 1 : 0
  source                        = "terraform-ibm-modules/landing-zone-vsi/ibm"
  version                       = "5.13.0"
  vsi_per_subnet                = 1
  create_security_group         = false
  security_group                = null
  image_id                      = var.storage_type != "evaluation" ? (local.scale_compute_image_found_in_map ? local.scale_compute_image_id : data.ibm_is_image.scale_compute_stock_image[0].id) : local.evaluation_image_id
  machine_type                  = var.scale_management_vsi_profile
  prefix                        = count.index == 0 ? local.compute_management_node_name : format("%s-%s", local.compute_management_node_name, count.index)
  resource_group_id             = var.resource_group
  enable_floating_ip            = false
  security_group_ids            = var.compute_security_group_name == null ? module.compute_sg[*].security_group_id : local.compute_security_group_name_id
  ssh_key_ids                   = local.ssh_keys
  subnets                       = local.compute_subnet_id
  tags                          = local.tags
  user_data                     = data.template_file.scale_compute_user_data.rendered
  vpc_id                        = var.vpc_id
  kms_encryption_enabled        = var.kms_encryption_enabled
  skip_iam_authorization_policy = local.skip_iam_authorization_policy
  boot_volume_size              = local.boot_volume_size
  boot_volume_profile           = local.boot_volume_profile
  boot_volume_iops              = local.boot_volume_iops
  boot_volume_encryption_key    = var.boot_volume_encryption_key
  placement_group_id            = var.placement_group_ids
  secondary_security_groups     = local.enable_sec_interface_compute ? local.storage_secondary_security_group : []
  secondary_subnets             = local.enable_sec_interface_compute ? local.storage_subnets : []
  manage_reserved_ips           = local.enable_sec_interface_compute ? true : false
}

module "storage_vsi" {
  count                         = var.scheduler == "Scale" ? (length(var.storage_instances) > 0 && var.storage_type != "baremetal" ? 1 : 0) : 0
  source                        = "terraform-ibm-modules/landing-zone-vsi/ibm"
  version                       = "5.13.0"
  vsi_per_subnet                = var.storage_instances[count.index]["count"]
  create_security_group         = false
  security_group                = null
  image_id                      = var.storage_type != "evaluation" ? (local.scale_storage_image_found_in_map ? local.new_storage_image_id : data.ibm_is_image.storage_vsi[0].id) : local.evaluation_image_id
  machine_type                  = var.storage_instances[count.index]["profile"]
  prefix                        = count.index == 0 ? local.storage_node_name : format("%s-%s", local.storage_node_name, count.index)
  resource_group_id             = var.resource_group
  enable_floating_ip            = false
  security_group_ids            = var.storage_security_group_name == null ? module.storage_sg[*].security_group_id : local.storage_security_group_name_id
  ssh_key_ids                   = local.ssh_keys
  subnets                       = local.storage_subnets
  tags                          = local.tags
  user_data                     = data.template_file.storage_user_data.rendered
  vpc_id                        = var.vpc_id
  block_storage_volumes         = local.enable_block_storage ? local.block_storage_volumes : []
  kms_encryption_enabled        = var.kms_encryption_enabled
  skip_iam_authorization_policy = local.skip_iam_authorization_policy
  boot_volume_size              = local.boot_volume_size
  boot_volume_profile           = local.boot_volume_profile
  boot_volume_iops              = local.boot_volume_iops
  boot_volume_encryption_key    = var.boot_volume_encryption_key
  placement_group_id            = var.placement_group_ids
  secondary_allow_ip_spoofing   = local.enable_protocol && var.colocate_protocol_instances ? true : false
  secondary_security_groups     = local.enable_sec_interface_storage ? local.storage_secondary_security_group : (local.enable_protocol && var.colocate_protocol_instances) ? local.protocol_secondary_security_group : []
  secondary_subnets             = local.enable_sec_interface_storage ? local.storage_subnets : local.enable_protocol && var.colocate_protocol_instances ? local.protocol_subnets : []
  manage_reserved_ips           = local.enable_sec_interface_storage || (local.enable_protocol && var.colocate_protocol_instances) ? true : false
  depends_on                    = [resource.null_resource.entitlement_check]
}


module "storage_cluster_management_vsi" {
  count                         = var.scheduler == "Scale" ? length(var.storage_instances) : 0
  source                        = "terraform-ibm-modules/landing-zone-vsi/ibm"
  version                       = "5.13.0"
  vsi_per_subnet                = 1
  create_security_group         = false
  security_group                = null
  image_id                      = var.storage_type != "evaluation" ? (local.scale_storage_image_found_in_map ? local.new_storage_image_id : data.ibm_is_image.storage_vsi[0].id) : local.evaluation_image_id
  machine_type                  = var.scale_management_vsi_profile
  prefix                        = count.index == 0 ? local.storage_management_node_name : format("%s-%s", local.storage_management_node_name, count.index)
  resource_group_id             = var.resource_group
  enable_floating_ip            = false
  security_group_ids            = var.storage_security_group_name == null ? module.storage_sg[*].security_group_id : local.storage_security_group_name_id
  ssh_key_ids                   = local.ssh_keys
  subnets                       = local.storage_subnets
  tags                          = local.tags
  user_data                     = data.template_file.storage_user_data.rendered
  vpc_id                        = var.vpc_id
  kms_encryption_enabled        = var.kms_encryption_enabled
  skip_iam_authorization_policy = local.skip_iam_authorization_policy
  boot_volume_size              = local.boot_volume_size
  boot_volume_profile           = local.boot_volume_profile
  boot_volume_iops              = local.boot_volume_iops
  boot_volume_encryption_key    = var.boot_volume_encryption_key
  placement_group_id            = var.placement_group_ids
  secondary_security_groups     = local.enable_sec_interface_storage ? local.storage_secondary_security_group : []
  secondary_subnets             = local.enable_sec_interface_storage ? local.storage_subnets : []
  manage_reserved_ips           = local.enable_sec_interface_storage ? true : false
}

module "storage_cluster_tie_breaker_vsi" {
  count                         = var.scheduler == "Scale" ? (var.storage_type != "baremetal" ? 1 : 0) : 0
  source                        = "terraform-ibm-modules/landing-zone-vsi/ibm"
  version                       = "5.13.0"
  vsi_per_subnet                = 1
  create_security_group         = false
  security_group                = null
  image_id                      = var.storage_type != "evaluation" ? (local.scale_storage_image_found_in_map ? local.new_storage_image_id : data.ibm_is_image.storage_vsi[0].id) : local.evaluation_image_id
  machine_type                  = var.storage_instances[count.index]["profile"]
  prefix                        = format("%s-strg-tie", local.prefix)
  resource_group_id             = var.resource_group
  enable_floating_ip            = false
  security_group_ids            = var.storage_security_group_name == null ? module.storage_sg[*].security_group_id : local.storage_security_group_name_id
  ssh_key_ids                   = local.ssh_keys
  subnets                       = local.storage_subnets
  tags                          = local.tags
  user_data                     = data.template_file.storage_user_data.rendered
  vpc_id                        = var.vpc_id
  block_storage_volumes         = local.enable_block_storage ? local.block_storage_volumes : []
  kms_encryption_enabled        = var.kms_encryption_enabled
  skip_iam_authorization_policy = local.skip_iam_authorization_policy
  boot_volume_size              = local.boot_volume_size
  boot_volume_profile           = local.boot_volume_profile
  boot_volume_iops              = local.boot_volume_iops
  boot_volume_encryption_key    = var.boot_volume_encryption_key
  placement_group_id            = var.placement_group_ids
  secondary_security_groups     = local.enable_sec_interface_storage ? local.storage_secondary_security_group : []
  secondary_subnets             = local.enable_sec_interface_storage ? local.storage_subnets : []
  manage_reserved_ips           = local.enable_sec_interface_storage ? true : false
  depends_on                    = [resource.null_resource.entitlement_check]
}

module "client_vsi" {
  count                         = var.scheduler == "Scale" ? length(var.client_instances) : 0
  source                        = "terraform-ibm-modules/landing-zone-vsi/ibm"
  version                       = "5.13.0"
  vsi_per_subnet                = var.client_instances[count.index]["count"]
  create_security_group         = false
  security_group                = null
  image_id                      = data.ibm_is_image.client[0].id
  machine_type                  = var.client_instances[count.index]["profile"]
  prefix                        = count.index == 0 ? local.client_node_name : format("%s-%s", local.client_node_name, count.index)
  resource_group_id             = var.resource_group
  enable_floating_ip            = false
  security_group_ids            = var.client_security_group_name == null ? module.client_sg[*].security_group_id : local.client_security_group_name_id
  ssh_key_ids                   = local.ssh_keys
  subnets                       = local.client_subnets
  tags                          = local.tags
  user_data                     = data.template_file.client_user_data.rendered
  vpc_id                        = var.vpc_id
  kms_encryption_enabled        = var.kms_encryption_enabled
  skip_iam_authorization_policy = local.skip_iam_authorization_policy
  boot_volume_encryption_key    = var.boot_volume_encryption_key
  boot_volume_size              = local.boot_volume_size
  boot_volume_profile           = local.boot_volume_profile
  boot_volume_iops              = local.boot_volume_iops
}

module "protocol_vsi" {
  count                         = var.scheduler == "Scale" ? ((local.enable_protocol && var.colocate_protocol_instances == false && local.ces_server_type == false) ? 1 : 0) : 0
  source                        = "terraform-ibm-modules/landing-zone-vsi/ibm"
  version                       = "5.13.0"
  vsi_per_subnet                = var.protocol_instances[count.index]["count"]
  create_security_group         = false
  security_group                = null
  image_id                      = var.storage_type != "evaluation" ? (local.scale_storage_image_found_in_map ? local.new_storage_image_id : data.ibm_is_image.storage_vsi[0].id) : local.evaluation_image_id
  machine_type                  = var.protocol_instances[count.index]["profile"]
  prefix                        = count.index == 0 ? local.protocol_node_name : format("%s-%s", local.protocol_node_name, count.index)
  resource_group_id             = var.resource_group
  enable_floating_ip            = false
  security_group_ids            = var.storage_security_group_name == null ? module.storage_sg[*].security_group_id : local.storage_security_group_name_id
  ssh_key_ids                   = local.ssh_keys
  subnets                       = local.storage_subnets
  tags                          = local.tags
  user_data                     = data.template_file.protocol_user_data.rendered
  vpc_id                        = var.vpc_id
  kms_encryption_enabled        = var.kms_encryption_enabled
  skip_iam_authorization_policy = local.skip_iam_authorization_policy
  boot_volume_encryption_key    = var.boot_volume_encryption_key
  boot_volume_size              = local.boot_volume_size
  boot_volume_profile           = local.boot_volume_profile
  boot_volume_iops              = local.boot_volume_iops
  # Bug: 5847 - LB profile & subnets are not configurable
  # load_balancers        = local.enable_load_balancer ? local.load_balancers : []
  secondary_allow_ip_spoofing = true
  secondary_security_groups   = local.protocol_secondary_security_group
  secondary_subnets           = local.protocol_subnets
  manage_reserved_ips         = true
  depends_on                  = [resource.null_resource.entitlement_check]
}

module "afm_vsi" {
  count                         = var.scheduler == "Scale" ? ((local.afm_server_type == false && local.enable_afm) ? 1 : 0) : 0
  source                        = "terraform-ibm-modules/landing-zone-vsi/ibm"
  version                       = "5.13.0"
  vsi_per_subnet                = var.afm_instances[count.index]["count"]
  create_security_group         = false
  security_group                = null
  image_id                      = var.storage_type != "evaluation" ? (local.scale_storage_image_found_in_map ? local.new_storage_image_id : data.ibm_is_image.storage_vsi[0].id) : local.evaluation_image_id
  machine_type                  = var.afm_instances[count.index]["profile"]
  prefix                        = count.index == 0 ? local.afm_node_name : format("%s-%s", local.afm_node_name, count.index)
  resource_group_id             = var.resource_group
  enable_floating_ip            = false
  security_group_ids            = var.storage_security_group_name == null ? module.storage_sg[*].security_group_id : local.storage_security_group_name_id
  ssh_key_ids                   = local.ssh_keys
  subnets                       = local.storage_subnets
  tags                          = local.tags
  user_data                     = data.template_file.afm_user_data.rendered
  vpc_id                        = var.vpc_id
  kms_encryption_enabled        = var.kms_encryption_enabled
  skip_iam_authorization_policy = local.skip_iam_authorization_policy
  boot_volume_encryption_key    = var.boot_volume_encryption_key
  boot_volume_size              = local.boot_volume_size
  boot_volume_profile           = local.boot_volume_profile
  boot_volume_iops              = local.boot_volume_iops
  depends_on                    = [resource.null_resource.entitlement_check]
}

module "gklm_vsi" {
  count                         = var.scheduler == "Scale" ? (var.scale_encryption_enabled == true && var.scale_encryption_type == "gklm" ? 1 : 0) : 0
  source                        = "terraform-ibm-modules/landing-zone-vsi/ibm"
  version                       = "5.13.0"
  vsi_per_subnet                = var.gklm_instances[count.index]["count"]
  create_security_group         = false
  security_group                = null
  image_id                      = local.scale_encryption_image_mapping_entry_found ? local.scale_encryption_image_id : data.ibm_is_image.gklm[0].id
  machine_type                  = var.gklm_instances[count.index]["profile"]
  prefix                        = count.index == 0 ? local.gklm_node_name : format("%s-%s", local.gklm_node_name, count.index)
  resource_group_id             = var.resource_group
  enable_floating_ip            = false
  security_group_ids            = var.gklm_security_group_name == null ? module.storage_sg[*].security_group_id : local.gklm_security_group_name_id
  ssh_key_ids                   = local.ssh_keys
  subnets                       = local.storage_subnets
  tags                          = local.tags
  user_data                     = data.template_file.gklm_user_data.rendered
  vpc_id                        = var.vpc_id
  kms_encryption_enabled        = var.kms_encryption_enabled
  skip_iam_authorization_policy = local.skip_iam_authorization_policy
  boot_volume_encryption_key    = var.boot_volume_encryption_key
  boot_volume_size              = local.boot_volume_size
  boot_volume_profile           = local.boot_volume_profile
  boot_volume_iops              = local.boot_volume_iops
}

module "ldap_vsi" {
  count                         = var.enable_ldap == true && var.ldap_server == "null" ? 1 : 0
  source                        = "terraform-ibm-modules/landing-zone-vsi/ibm"
  version                       = "5.13.0"
  vsi_per_subnet                = 1
  create_security_group         = false
  security_group                = null
  image_id                      = local.ldap_image_id[count.index]
  machine_type                  = var.ldap_instances[count.index]["profile"]
  prefix                        = local.ldap_node_name
  resource_group_id             = var.resource_group
  enable_floating_ip            = false
  security_group_ids            = local.products == "lsf" ? module.compute_sg[*].security_group_id : (var.ldap_security_group_name == null ? module.storage_sg[*].security_group_id : local.ldap_security_group_name_id)
  ssh_key_ids                   = local.ssh_keys
  subnets                       = local.products == "lsf" ? local.compute_subnet_id : [local.storage_subnets[0]]
  tags                          = local.tags
  user_data                     = data.template_file.ldap_user_data.rendered
  vpc_id                        = var.vpc_id
  kms_encryption_enabled        = var.kms_encryption_enabled
  skip_iam_authorization_policy = local.skip_iam_authorization_policy
  boot_volume_encryption_key    = var.boot_volume_encryption_key
  boot_volume_size              = local.boot_volume_size
  boot_volume_profile           = local.boot_volume_profile
  boot_volume_iops              = local.boot_volume_iops
  placement_group_id            = var.placement_group_ids
  #placement_group_id = var.placement_group_ids[(var.storage_instances[count.index]["count"])%(length(var.placement_group_ids))]
}

########################################################################
###                        Dedicated Host                            ###
########################################################################
module "dedicated_host" {
  for_each            = var.enable_dedicated_host ? local.dedicated_host_config : {}
  source              = "../dedicated_host"
  prefix              = var.prefix
  zone                = var.zones
  existing_host_group = false
  class               = each.value.class
  profile             = each.value.profile
  family              = each.value.family
  resource_group_id   = var.resource_group
  depends_on          = [null_resource.dedicated_host_validation]
}

########################################################################
###                        Baremetal Module                          ###
########################################################################

module "storage_baremetal" {
  count                        = length(var.storage_servers) > 0 && var.storage_type == "baremetal" ? 1 : 0
  source                       = "../baremetal"
  existing_resource_group      = var.resource_group
  image_id                     = local.storage_bare_metal_image_mapping_entry_found ? local.storage_bare_metal_image_id : data.ibm_is_image.baremetal_storage[0].id
  prefix                       = format("%s-%s", local.storage_node_name, substr(local.storage_subnets[count.index].id, length(local.storage_subnets[count.index].id) - 4, 4))
  storage_subnets              = [for subnet in local.storage_subnets : subnet.id]
  storage_ssh_keys             = local.ssh_keys
  storage_servers              = var.storage_servers
  security_group_ids           = module.storage_sg[*].security_group_id
  user_data                    = var.bms_boot_drive_encryption == false ? data.template_file.storage_bm_user_data.rendered : templatefile("${path.module}/templates/storage_bootdrive_user_data/cloud_init.yml", local.user_data_vars)
  secondary_vni_enabled        = local.enable_protocol && var.colocate_protocol_instances ? true : false
  protocol_subnets             = local.enable_protocol && var.colocate_protocol_instances ? local.protocol_subnets : []
  secondary_security_group_ids = local.enable_protocol && var.colocate_protocol_instances ? module.storage_sg[*].security_group_id : []
  #  manage_reserved_ips           = local.enable_protocol && var.colocate_protocol_instances ? true : false
  sapphire_rapids_profile_check = local.sapphire_rapids_profile_check
}

module "storage_baremetal_tie_breaker" {
  count                         = length(var.storage_servers) > 0 && var.storage_type == "baremetal" ? 1 : 0
  source                        = "../baremetal"
  existing_resource_group       = var.resource_group
  image_id                      = local.storage_bare_metal_image_mapping_entry_found ? local.storage_bare_metal_image_id : data.ibm_is_image.baremetal_storage[0].id
  prefix                        = format("%s-%s", local.storage_tie_breaker_node_name, substr(local.storage_subnets[count.index].id, length(local.storage_subnets[count.index].id) - 4, 4))
  storage_subnets               = [for subnet in local.storage_subnets : subnet.id]
  storage_ssh_keys              = local.ssh_keys
  storage_servers               = local.tie_breaker_bm_server
  security_group_ids            = module.storage_sg[*].security_group_id
  user_data                     = var.bms_boot_drive_encryption == false ? data.template_file.storage_bmtb_user_data.rendered : templatefile("${path.module}/templates/storage_tb_bootdrive_user_data/cloud_init.yml", local.user_data_vars)
  secondary_vni_enabled         = false
  protocol_subnets              = local.protocol_subnets
  secondary_security_group_ids  = []
  sapphire_rapids_profile_check = local.sapphire_rapids_profile_check
}

module "protocol_baremetal_server" {
  count                         = (var.colocate_protocol_instances == false && local.ces_server_type == true && local.enable_protocol) ? 1 : 0
  source                        = "../baremetal"
  existing_resource_group       = var.resource_group
  image_id                      = local.storage_bare_metal_image_mapping_entry_found ? local.storage_bare_metal_image_id : data.ibm_is_image.baremetal_storage[0].id
  prefix                        = format("%s-%s", local.protocol_node_name, substr(local.protocol_subnets[count.index].id, length(local.protocol_subnets[count.index].id) - 4, 4))
  storage_subnets               = [for subnet in local.storage_subnets : subnet.id]
  storage_ssh_keys              = local.ssh_keys
  storage_servers               = var.protocol_instances
  security_group_ids            = module.storage_sg[*].security_group_id
  user_data                     = var.bms_boot_drive_encryption == false ? data.template_file.protocol_bm_user_data.rendered : templatefile("${path.module}/templates/protocol_bootdrive_user_data/cloud_init.yml", local.user_data_vars)
  secondary_vni_enabled         = true
  protocol_subnets              = local.protocol_subnets
  secondary_security_group_ids  = module.storage_sg[*].security_group_id
  sapphire_rapids_profile_check = local.sapphire_rapids_profile_check
}

module "afm_baremetal_server" {
  count                         = (local.afm_server_type == true && local.enable_afm) ? 1 : 0
  source                        = "../baremetal"
  existing_resource_group       = var.resource_group
  image_id                      = local.storage_bare_metal_image_mapping_entry_found ? local.storage_bare_metal_image_id : data.ibm_is_image.baremetal_storage[0].id
  prefix                        = format("%s-%s", local.afm_node_name, substr(local.storage_subnets[count.index].id, length(local.storage_subnets[count.index].id) - 4, 4))
  storage_subnets               = [for subnet in local.storage_subnets : subnet.id]
  storage_ssh_keys              = local.ssh_keys
  storage_servers               = var.afm_instances
  security_group_ids            = module.storage_sg[*].security_group_id
  user_data                     = var.bms_boot_drive_encryption == false ? data.template_file.afm_bm_user_data.rendered : templatefile("${path.module}/templates/afm_bootdrive_user_data/cloud_init.yml", local.user_data_vars)
  secondary_vni_enabled         = false
  protocol_subnets              = local.protocol_subnets
  secondary_security_group_ids  = []
  sapphire_rapids_profile_check = local.sapphire_rapids_profile_check
}
