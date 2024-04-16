module "compute_key" {
  count  = local.enable_compute ? 1 : 0
  source = "./../key"
  # private_key_path = "compute_id_rsa" #checkov:skip=CKV_SECRET_6
}

module "compute_sg" {
  count                        = local.enable_compute ? 1 : 0
  source                       = "terraform-ibm-modules/security-group/ibm"
  version                      = "2.6.0"
  add_ibm_cloud_internal_rules = true
  resource_group               = var.resource_group
  security_group_name          = format("%s-cluster-sg", local.prefix)
  security_group_rules         = local.compute_security_group_rules
  vpc_id                       = var.vpc_id
  tags                         = local.tags
}

module "nfs_storage_sg" {
  count                          = var.storage_security_group_id != null ? 1 : 0
  source                         = "terraform-ibm-modules/security-group/ibm"
  version                        = "2.6.0"
  resource_group                 = var.resource_group
  add_ibm_cloud_internal_rules   = true
  use_existing_security_group_id = true
  existing_security_group_id     = var.storage_security_group_id
  security_group_rules           = local.storage_nfs_security_group_rules
  vpc_id                         = var.vpc_id
}

module "management_vsi" {
  count = 1
  # count                       = length(var.management_instances)
  source         = "terraform-ibm-modules/landing-zone-vsi/ibm"
  version        = "4.0.0-rc5"
  vsi_per_subnet = 1
  # vsi_per_subnet              = var.management_instances[count.index]["count"]
  create_security_group         = false
  security_group                = null
  image_id                      = local.image_mapping_entry_found ? local.new_image_id : data.ibm_is_image.management[0].id
  machine_type                  = data.ibm_is_instance_profile.management_node.name
  prefix                        = format("%s-%s", local.management_node_name, count.index + 1)
  resource_group_id             = var.resource_group
  enable_floating_ip            = false
  security_group_ids            = module.compute_sg[*].security_group_id
  ssh_key_ids                   = local.management_ssh_keys
  subnets                       = [local.compute_subnets[0]]
  tags                          = local.tags
  user_data                     = "${data.template_file.management_user_data.rendered} ${file("${path.module}/templates/lsf_management.sh")}"
  vpc_id                        = var.vpc_id
  kms_encryption_enabled        = var.kms_encryption_enabled
  skip_iam_authorization_policy = local.skip_iam_authorization_policy
  boot_volume_encryption_key    = var.boot_volume_encryption_key

}

module "management_candidate_vsi" {
  count                         = var.management_node_count - 1
  source                        = "terraform-ibm-modules/landing-zone-vsi/ibm"
  version                       = "4.0.0-rc5"
  create_security_group         = false
  security_group                = null
  security_group_ids            = module.compute_sg[*].security_group_id
  vpc_id                        = var.vpc_id
  ssh_key_ids                   = local.management_ssh_keys
  subnets                       = [local.compute_subnets[0]]
  resource_group_id             = var.resource_group
  enable_floating_ip            = false
  user_data                     = "${data.template_file.management_user_data.rendered} ${file("${path.module}/templates/lsf_management.sh")}"
  kms_encryption_enabled        = var.kms_encryption_enabled
  skip_iam_authorization_policy = local.skip_iam_authorization_policy
  boot_volume_encryption_key    = var.boot_volume_encryption_key
  image_id                      = local.image_mapping_entry_found ? local.new_image_id : data.ibm_is_image.management[0].id
  prefix                        = format("%s-%s", local.management_node_name, count.index + 2)
  machine_type                  = data.ibm_is_instance_profile.management_node.name
  vsi_per_subnet                = 1
  tags                          = local.tags
}

module "login_vsi" {
  count                         = 1
  source                        = "terraform-ibm-modules/landing-zone-vsi/ibm"
  version                       = "4.0.0-rc5"
  vsi_per_subnet                = 1
  create_security_group         = false
  security_group                = null
  image_id                      = local.compute_image_mapping_entry_found ? local.new_compute_image_id : data.ibm_is_image.compute[0].id
  machine_type                  = var.login_node_instance_type
  prefix                        = local.login_node_name
  resource_group_id             = var.resource_group
  enable_floating_ip            = false
  security_group_ids            = [var.bastion_security_group_id]
  ssh_key_ids                   = local.bastion_ssh_keys
  subnets                       = length(var.bastion_subnets) == 3 ? [local.bastion_subnets[2]] : [local.bastion_subnets[0]]
  tags                          = local.tags
  user_data                     = "${data.template_file.login_user_data.rendered} ${file("${path.module}/templates/login_vsi.sh")}"
  vpc_id                        = var.vpc_id
  kms_encryption_enabled        = var.kms_encryption_enabled
  boot_volume_encryption_key    = var.boot_volume_encryption_key
  skip_iam_authorization_policy = local.skip_iam_authorization_policy
}

module "ldap_vsi" {
  count = local.ldap_enable
  # count                       = length(var.management_instances)
  source                = "terraform-ibm-modules/landing-zone-vsi/ibm"
  version               = "4.0.0-rc5"
  vsi_per_subnet        = 1
  create_security_group = false
  security_group        = null
  image_id              = local.ldap_instance_image_id
  machine_type          = var.ldap_vsi_profile
  prefix                = local.ldap_node_name
  # prefix                      = count.index == 0 ? local.management_node_name : format("%s-%s", local.management_node_name, count.index)
  resource_group_id             = var.resource_group
  enable_floating_ip            = false
  security_group_ids            = module.compute_sg[*].security_group_id
  ssh_key_ids                   = local.management_ssh_keys
  subnets                       = [local.compute_subnets[0]]
  tags                          = local.tags
  user_data                     = var.enable_ldap == true && var.ldap_server == "null" ? "${data.template_file.ldap_user_data[0].rendered} ${file("${path.module}/templates/ldap_user_data.sh")}" : ""
  vpc_id                        = var.vpc_id
  kms_encryption_enabled        = var.kms_encryption_enabled
  skip_iam_authorization_policy = local.skip_iam_authorization_policy
  boot_volume_encryption_key    = var.boot_volume_encryption_key
  #placement_group_id           = var.placement_group_ids[(var.management_instances[count.index]["count"])%(length(var.placement_group_ids))]
}

module "generate_db_password" {
  count            = var.enable_app_center && var.app_center_high_availability ? 1 : 0
  source           = "../../modules/security/password"
  length           = 15
  special          = true
  override_special = "-_"
  min_numeric      = 1
}

module "ssh_key" {
  source = "./../key"
}

module "wait_management_vsi_booted" {
  source              = "./../../modules/null/remote_exec"
  cluster_host        = concat([var.management_private_ip])
  cluster_user        = var.cluster_user #"root"
  cluster_private_key = var.compute_private_key_content
  login_host          = var.bastion_fip
  login_user          = "ubuntu"
  login_private_key   = var.bastion_private_key_content
  command             = ["cloud-init status --wait;hostname;date;df;id"]
  depends_on = [
    module.management_vsi
  ]
}

module "wait_management_candidate_vsi_booted" {
  source              = "./../../modules/null/remote_exec"
  cluster_host        = concat(var.management_candidate_private_ips)
  cluster_user        = var.cluster_user #"root"
  cluster_private_key = var.compute_private_key_content
  login_host          = var.bastion_fip
  login_user          = "ubuntu"
  login_private_key   = var.bastion_private_key_content
  command             = ["cloud-init status --wait;hostname;date;df;id"]
  depends_on = [
    module.management_candidate_vsi
  ]
}

module "do_management_vsi_configuration" {
  source              = "./../../modules/null/remote_exec_script"
  cluster_host        = concat([var.management_private_ip])
  cluster_user        = var.cluster_user #"root"
  cluster_private_key = var.compute_private_key_content
  login_host          = var.bastion_fip
  login_user          = "ubuntu"
  login_private_key   = var.bastion_private_key_content
  payload_files       = ["${path.module}/configuration_steps/configure_management_vsi.sh", "${path.module}/configuration_steps/compute_user_data_fragment.sh"]
  payload_dirs        = []
  new_file_name       = "management_values"
  new_file_content    = data.template_file.management_values.rendered
  script_to_run       = "configure_management_vsi.sh"
  sudo_user           = "root"
  with_bash           = true
  depends_on = [
    module.wait_management_vsi_booted
  ]
}

module "do_management_candidate_vsi_configuration" {
  source              = "./../../modules/null/remote_exec_script"
  cluster_host        = concat(var.management_candidate_private_ips)
  cluster_user        = var.cluster_user #"root"
  cluster_private_key = var.compute_private_key_content
  login_host          = var.bastion_fip
  login_user          = "ubuntu"
  login_private_key   = var.bastion_private_key_content
  payload_files       = ["${path.module}/configuration_steps/configure_management_vsi.sh"]
  payload_dirs        = []
  new_file_name       = "management_values"
  new_file_content    = data.template_file.management_values.rendered
  script_to_run       = "configure_management_vsi.sh"
  sudo_user           = "root"
  with_bash           = true
  depends_on = [
    module.wait_management_candidate_vsi_booted
  ]
}
