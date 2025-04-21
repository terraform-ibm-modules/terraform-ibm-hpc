module "compute_key" {
  count  = local.enable_compute ? 1 : 0
  source = "./../key"
  # private_key_path = "./../../modules/ansible-roles/compute_id_rsa" #checkov:skip=CKV_SECRET_6
}

resource "local_sensitive_file" "write_meta_private_key" {
  count           = local.enable_compute ? 1 : 0
  content         = (local.compute_private_key_content)
  filename        = var.enable_bastion ? "${path.root}/../../modules/ansible-roles/compute_id_rsa" : "${path.root}/modules/ansible-roles/compute_id_rsa"
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
  # private_key_path = var.enable_bastion ? "${path.root}/../../modules/ansible-roles/storage_id_rsa" : "${path.root}/modules/ansible-roles/storage_id_rsa" #checkov:skip=CKV_SECRET_6
}

module "client_sg" {
  count                        = local.enable_client ? 1 : 0
  source                       = "terraform-ibm-modules/security-group/ibm"
  version                      = "2.6.2"
  add_ibm_cloud_internal_rules = true
  resource_group               = local.resource_group_id
  security_group_name          = format("%s-client-sg", local.prefix)
  security_group_rules         = local.client_security_group_rules
  vpc_id                       = var.vpc_id
}

module "compute_sg" {
  count                        = local.enable_compute ? 1 : 0
  source                       = "terraform-ibm-modules/security-group/ibm"
  version                      = "2.6.2"
  add_ibm_cloud_internal_rules = true
  resource_group               = local.resource_group_id
  security_group_name          = format("%s-comp-sg", local.prefix)
  security_group_rules         = local.compute_security_group_rules
  vpc_id                       = var.vpc_id
}

module "storage_sg" {
  count                        = local.enable_storage ? 1 : 0
  source                       = "terraform-ibm-modules/security-group/ibm"
  version                      = "2.6.2"
  add_ibm_cloud_internal_rules = true
  resource_group               = local.resource_group_id
  security_group_name          = format("%s-strg-sg", local.prefix)
  security_group_rules         = local.storage_security_group_rules
  vpc_id                       = var.vpc_id
}

resource "ibm_is_security_group_rule" "add_comp_sg_bastion" {
  group     = var.bastion_security_group_id
  direction = "inbound"
  remote    = module.compute_sg[0].security_group_id
}

resource "ibm_is_security_group_rule" "add_comp_sg_comp" {
  group     = module.compute_sg[0].security_group_id
  direction = "inbound"
  remote    = module.compute_sg[0].security_group_id
}

resource "ibm_is_security_group_rule" "add_comp_sg_strg" {
  count     = local.enable_storage ? 1 : 0
  group     = module.storage_sg[0].security_group_id
  direction = "inbound"
  remote    = module.compute_sg[0].security_group_id
}

resource "ibm_is_security_group_rule" "add_strg_sg_comp" {
  count     = local.enable_storage ? 1 : 0
  group     = module.compute_sg[0].security_group_id
  direction = "inbound"
  remote    = module.storage_sg[0].security_group_id
}

resource "ibm_is_security_group_rule" "add_strg_sg_strg" {
  count     = local.enable_storage ? 1 : 0
  group     = module.storage_sg[0].security_group_id
  direction = "inbound"
  remote    = module.storage_sg[0].security_group_id
}

module "management_vsi" {
  count                         = length(var.management_instances)
  source                        = "terraform-ibm-modules/landing-zone-vsi/ibm"
  version                       = "4.6.0"
  vsi_per_subnet                = var.management_instances[count.index]["count"]
  create_security_group         = false
  security_group                = null
  image_id                      = local.management_image_id[count.index]
  machine_type                  = var.management_instances[count.index]["profile"]
  prefix                        = count.index == 0 ? local.management_node_name : format("%s-%s", local.management_node_name, count.index)
  resource_group_id             = local.resource_group_id
  enable_floating_ip            = false
  security_group_ids            = module.compute_sg[*].security_group_id
  ssh_key_ids                   = local.management_ssh_keys
  subnets                       = local.compute_subnets
  tags                          = local.tags
  user_data                     = data.template_file.management_user_data.rendered
  vpc_id                        = var.vpc_id
  kms_encryption_enabled        = var.kms_encryption_enabled
  skip_iam_authorization_policy = local.skip_iam_authorization_policy
  boot_volume_encryption_key    = var.boot_volume_encryption_key
  placement_group_id            = var.placement_group_ids
  #placement_group_id = var.placement_group_ids[(var.management_instances[count.index]["count"])%(length(var.placement_group_ids))]
}

module "compute_vsi" {
  count                         = length(var.static_compute_instances)
  source                        = "terraform-ibm-modules/landing-zone-vsi/ibm"
  version                       = "4.6.0"
  vsi_per_subnet                = var.static_compute_instances[count.index]["count"]
  create_security_group         = false
  security_group                = null
  image_id                      = local.compute_image_id[count.index]
  machine_type                  = var.static_compute_instances[count.index]["profile"]
  prefix                        = count.index == 0 ? local.compute_node_name : format("%s-%s", local.compute_node_name, count.index)
  resource_group_id             = local.resource_group_id
  enable_floating_ip            = false
  security_group_ids            = module.compute_sg[*].security_group_id
  ssh_key_ids                   = local.compute_ssh_keys
  subnets                       = local.compute_subnets
  tags                          = local.tags
  user_data                     = data.template_file.compute_user_data.rendered
  vpc_id                        = var.vpc_id
  kms_encryption_enabled        = var.kms_encryption_enabled
  skip_iam_authorization_policy = local.skip_iam_authorization_policy
  boot_volume_encryption_key    = var.boot_volume_encryption_key
  placement_group_id            = var.placement_group_ids
  # secondary_allow_ip_spoofing     = true
  secondary_security_groups       = module.storage_sg[*].security_group_id
  secondary_subnets               = local.storage_subnets
  manage_reserved_ips             = var.enable_mrot_conf ? true : false
  primary_vni_additional_ip_count = var.static_compute_instances[count.index]["count"]
  #placement_group_id = var.placement_group_ids[(var.static_compute_instances[count.index]["count"])%(length(var.placement_group_ids))]
}

module "compute_cluster_management_vsi" {
  count                         = var.scheduler == "Scale" && local.enable_compute ? 1 : 0
  source                        = "terraform-ibm-modules/landing-zone-vsi/ibm"
  version                       = "4.6.0"
  vsi_per_subnet                = 1
  create_security_group         = false
  security_group                = null
  image_id                      = local.compute_image_id[count.index]
  machine_type                  = var.static_compute_instances[count.index]["profile"]
  prefix                        = count.index == 0 ? local.cpmoute_management_node_name : format("%s-%s", local.cpmoute_management_node_name, count.index)
  resource_group_id             = local.resource_group_id
  enable_floating_ip            = false
  security_group_ids            = module.compute_sg[*].security_group_id
  ssh_key_ids                   = local.compute_ssh_keys
  subnets                       = local.compute_subnets
  tags                          = local.tags
  user_data                     = data.template_file.compute_user_data.rendered
  vpc_id                        = var.vpc_id
  kms_encryption_enabled        = var.kms_encryption_enabled
  skip_iam_authorization_policy = local.skip_iam_authorization_policy
  boot_volume_encryption_key    = var.boot_volume_encryption_key
  placement_group_id            = var.placement_group_ids
  # secondary_allow_ip_spoofing     = true
  secondary_security_groups       = module.storage_sg[*].security_group_id
  secondary_subnets               = local.storage_subnets
  manage_reserved_ips             = var.enable_mrot_conf ? true : false
  primary_vni_additional_ip_count = var.static_compute_instances[count.index]["count"]
  #placement_group_id = var.placement_group_ids[(var.static_compute_instances[count.index]["count"])%(length(var.placement_group_ids))]
}

module "storage_vsi" {
  count                         = length(var.storage_instances)
  source                        = "terraform-ibm-modules/landing-zone-vsi/ibm"
  version                       = "4.6.0"
  vsi_per_subnet                = var.storage_instances[count.index]["count"]
  create_security_group         = false
  security_group                = null
  image_id                      = local.storage_image_id[count.index]
  machine_type                  = var.storage_instances[count.index]["profile"]
  prefix                        = count.index == 0 ? local.storage_node_name : format("%s-%s", local.storage_node_name, count.index)
  resource_group_id             = local.resource_group_id
  enable_floating_ip            = false
  security_group_ids            = module.storage_sg[*].security_group_id
  ssh_key_ids                   = local.storage_ssh_keys
  subnets                       = local.storage_subnets
  tags                          = local.tags
  user_data                     = data.template_file.storage_user_data.rendered
  vpc_id                        = var.vpc_id
  block_storage_volumes         = local.enable_block_storage ? local.block_storage_volumes : []
  kms_encryption_enabled        = var.kms_encryption_enabled
  skip_iam_authorization_policy = local.skip_iam_authorization_policy
  boot_volume_encryption_key    = var.boot_volume_encryption_key
  placement_group_id            = var.placement_group_ids
  # secondary_allow_ip_spoofing     = true
  secondary_security_groups       = module.storage_sg[*].security_group_id
  secondary_subnets               = local.storage_subnets
  manage_reserved_ips             = var.enable_mrot_conf ? true : false
  primary_vni_additional_ip_count = var.storage_instances[count.index]["count"]
  # placement_group_id = var.placement_group_ids[(var.storage_instances[count.index]["count"])%(length(var.placement_group_ids))]
}


module "storage_cluster_management_vsi" {
  count                         = length(var.storage_instances)
  source                        = "terraform-ibm-modules/landing-zone-vsi/ibm"
  version                       = "4.6.0"
  vsi_per_subnet                = 1
  create_security_group         = false
  security_group                = null
  image_id                      = local.storage_image_id[count.index]
  machine_type                  = var.management_instances[count.index]["profile"]
  prefix                        = count.index == 0 ? local.storage_management_node_name : format("%s-%s", local.storage_management_node_name, count.index)
  resource_group_id             = local.resource_group_id
  enable_floating_ip            = false
  security_group_ids            = module.storage_sg[*].security_group_id
  ssh_key_ids                   = local.storage_ssh_keys
  subnets                       = local.storage_subnets
  tags                          = local.tags
  user_data                     = data.template_file.storage_user_data.rendered
  vpc_id                        = var.vpc_id
  block_storage_volumes         = local.enable_block_storage ? local.block_storage_volumes : []
  kms_encryption_enabled        = var.kms_encryption_enabled
  skip_iam_authorization_policy = local.skip_iam_authorization_policy
  boot_volume_encryption_key    = var.boot_volume_encryption_key
  placement_group_id            = var.placement_group_ids
  # secondary_allow_ip_spoofing     = true
  secondary_security_groups       = module.storage_sg[*].security_group_id
  secondary_subnets               = local.storage_subnets
  manage_reserved_ips             = var.enable_mrot_conf ? true : false
  primary_vni_additional_ip_count = var.storage_instances[count.index]["count"]
  # placement_group_id = var.placement_group_ids[(var.storage_instances[count.index]["count"])%(length(var.placement_group_ids))]
}

module "storage_cluster_tie_breaker_vsi" {
  count                         = var.storage_type != "persistent" ? 1 : 0
  source                        = "terraform-ibm-modules/landing-zone-vsi/ibm"
  version                       = "4.6.0"
  vsi_per_subnet                = 1
  create_security_group         = false
  security_group                = null
  image_id                      = local.storage_image_id[count.index]
  machine_type                  = var.storage_instances[count.index]["profile"]
  prefix                        = format("%s-strg-tie", local.prefix)
  resource_group_id             = local.resource_group_id
  enable_floating_ip            = false
  security_group_ids            = module.storage_sg[*].security_group_id
  ssh_key_ids                   = local.storage_ssh_keys
  subnets                       = local.storage_subnets #[local.storage_subnets[0]]
  tags                          = local.tags
  user_data                     = data.template_file.storage_user_data.rendered
  vpc_id                        = var.vpc_id
  block_storage_volumes         = local.enable_block_storage ? local.block_storage_volumes : []
  kms_encryption_enabled        = var.kms_encryption_enabled
  skip_iam_authorization_policy = local.skip_iam_authorization_policy
  boot_volume_encryption_key    = var.boot_volume_encryption_key
  placement_group_id            = var.placement_group_ids
  # secondary_allow_ip_spoofing     = true
  secondary_security_groups       = module.storage_sg[*].security_group_id
  secondary_subnets               = local.storage_subnets
  manage_reserved_ips             = var.enable_mrot_conf ? true : false
  primary_vni_additional_ip_count = var.storage_instances[count.index]["count"]
  # placement_group_id              = var.placement_group_ids[(var.storage_instances[count.index]["count"])%(length(var.placement_group_ids))]
}

module "client_vsi" {
  count                         = length(var.client_instances)
  source                        = "terraform-ibm-modules/landing-zone-vsi/ibm"
  version                       = "4.6.0"
  vsi_per_subnet                = var.client_instances[count.index]["count"]
  create_security_group         = false
  security_group                = null
  image_id                      = local.client_image_id[count.index]
  machine_type                  = var.client_instances[count.index]["profile"]
  prefix                        = count.index == 0 ? local.client_node_name : format("%s-%s", local.client_node_name, count.index)
  resource_group_id             = local.resource_group_id
  enable_floating_ip            = false
  security_group_ids            = module.client_sg[*].security_group_id
  ssh_key_ids                   = local.client_ssh_keys
  subnets                       = local.client_subnets
  tags                          = local.tags
  user_data                     = data.template_file.client_user_data.rendered
  vpc_id                        = var.vpc_id
  kms_encryption_enabled        = var.kms_encryption_enabled
  skip_iam_authorization_policy = local.skip_iam_authorization_policy
  boot_volume_encryption_key    = var.boot_volume_encryption_key
}

module "protocol_vsi" {
  count                         = length(var.protocol_instances)
  source                        = "terraform-ibm-modules/landing-zone-vsi/ibm"
  version                       = "4.6.0"
  vsi_per_subnet                = var.protocol_instances[count.index]["count"]
  create_security_group         = false
  security_group                = null
  image_id                      = local.protocol_image_id[count.index]
  machine_type                  = var.protocol_instances[count.index]["profile"]
  prefix                        = count.index == 0 ? local.protocol_node_name : format("%s-%s", local.protocol_node_name, count.index)
  resource_group_id             = local.resource_group_id
  enable_floating_ip            = false
  security_group_ids            = module.storage_sg[*].security_group_id
  ssh_key_ids                   = local.protocol_ssh_keys
  subnets                       = local.storage_subnets
  tags                          = local.tags
  user_data                     = data.template_file.protocol_user_data.rendered
  vpc_id                        = var.vpc_id
  kms_encryption_enabled        = var.kms_encryption_enabled
  skip_iam_authorization_policy = local.skip_iam_authorization_policy
  boot_volume_encryption_key    = var.boot_volume_encryption_key
  # Bug: 5847 - LB profile & subnets are not configurable
  # load_balancers        = local.enable_load_balancer ? local.load_balancers : []
  secondary_allow_ip_spoofing     = true
  secondary_security_groups       = local.protocol_secondary_security_group
  secondary_subnets               = local.protocol_subnets
  placement_group_id              = var.placement_group_ids
  manage_reserved_ips             = true
  primary_vni_additional_ip_count = var.protocol_instances[count.index]["count"]
  # placement_group_id = var.placement_group_ids[(var.protocol_instances[count.index]["count"])%(length(var.placement_group_ids))]
}

module "afm_vsi" {
  count                         = length(var.afm_instances)
  source                        = "terraform-ibm-modules/landing-zone-vsi/ibm"
  version                       = "4.6.0"
  vsi_per_subnet                = var.afm_instances[count.index]["count"]
  create_security_group         = false
  security_group                = null
  image_id                      = local.afm_image_id[count.index]
  machine_type                  = var.afm_instances[count.index]["profile"]
  prefix                        = count.index == 0 ? local.afm_node_name : format("%s-%s", local.afm_node_name, count.index)
  resource_group_id             = local.resource_group_id
  enable_floating_ip            = false
  security_group_ids            = module.storage_sg[*].security_group_id
  ssh_key_ids                   = local.storage_ssh_keys
  subnets                       = local.storage_subnets
  tags                          = local.tags
  user_data                     = data.template_file.afm_user_data.rendered
  vpc_id                        = var.vpc_id
  kms_encryption_enabled        = var.kms_encryption_enabled
  skip_iam_authorization_policy = local.skip_iam_authorization_policy
  boot_volume_encryption_key    = var.boot_volume_encryption_key
  # manage_reserved_ips             = true
  # primary_vni_additional_ip_count = var.afm_instances[count.index]["count"]
}

module "gklm_vsi" {
  count                         = var.scale_encryption_enabled == true && var.scale_encryption_type == "gklm" ? 1 : 0
  source                        = "terraform-ibm-modules/landing-zone-vsi/ibm"
  version                       = "4.6.0"
  vsi_per_subnet                = var.gklm_instances[count.index]["count"]
  create_security_group         = false
  security_group                = null
  image_id                      = local.gklm_image_id[count.index]
  machine_type                  = var.gklm_instances[count.index]["profile"]
  prefix                        = count.index == 0 ? local.gklm_node_name : format("%s-%s", local.gklm_node_name, count.index)
  resource_group_id             = local.resource_group_id
  enable_floating_ip            = false
  security_group_ids            = module.storage_sg[*].security_group_id
  ssh_key_ids                   = local.gklm_ssh_keys
  subnets                       = local.storage_subnets
  tags                          = local.tags
  user_data                     = data.template_file.gklm_user_data.rendered
  vpc_id                        = var.vpc_id
  kms_encryption_enabled        = var.kms_encryption_enabled
  skip_iam_authorization_policy = local.skip_iam_authorization_policy
  boot_volume_encryption_key    = var.boot_volume_encryption_key
}

module "ldap_vsi" {
  count                         = var.enable_ldap == true && var.ldap_server == null ? 1 : 0
  source                        = "terraform-ibm-modules/landing-zone-vsi/ibm"
  version                       = "4.6.0"
  vsi_per_subnet                = 1
  create_security_group         = false
  security_group                = null
  image_id                      = local.ldap_image_id[count.index]
  machine_type                  = var.ldap_instances[count.index]["profile"]
  prefix                        = local.ldap_node_name
  resource_group_id             = local.resource_group_id
  enable_floating_ip            = false
  security_group_ids            = module.storage_sg[*].security_group_id
  ssh_key_ids                   = local.ldap_ssh_keys
  subnets                       = [local.storage_subnets[0]]
  tags                          = local.tags
  user_data                     = data.template_file.ldap_user_data.rendered
  vpc_id                        = var.vpc_id
  block_storage_volumes         = local.enable_block_storage ? local.block_storage_volumes : []
  kms_encryption_enabled        = var.kms_encryption_enabled
  skip_iam_authorization_policy = local.skip_iam_authorization_policy
  boot_volume_encryption_key    = var.boot_volume_encryption_key
  placement_group_id            = var.placement_group_ids
  #placement_group_id = var.placement_group_ids[(var.storage_instances[count.index]["count"])%(length(var.placement_group_ids))]
}
