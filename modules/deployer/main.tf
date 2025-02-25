module "compute_key" {
  count            = local.enable_deployer && local.enable_compute ? 1 : 0
  source           = "./../key"
  private_key_path = var.enable_bastion ? "${path.root}/../../modules/ansible-roles/compute_id_rsa" : "${path.root}/modules/ansible-roles/compute_id_rsa" #checkov:skip=CKV_SECRET_6
}

module "ssh_key" {
  count            = local.enable_bastion ? 1 : 0
  source           = "./../key"
  private_key_path = "bastion_id_rsa" #checkov:skip=CKV_SECRET_6
}

module "bastion_sg" {
  count                        = local.enable_bastion ? 1 : 0
  source                       = "terraform-ibm-modules/security-group/ibm"
  version                      = "2.6.2"
  add_ibm_cloud_internal_rules = true
  resource_group               = local.resource_group_id
  security_group_name          = format("%s-bastion-sg", local.prefix)
  security_group_rules         = local.bastion_security_group_rules
  vpc_id                       = var.vpc_id
}

module "bastion_vsi" {
  count                         = var.enable_bastion ? 1 : 0
  source                        = "terraform-ibm-modules/landing-zone-vsi/ibm"
  version                       = "4.2.0"
  vsi_per_subnet                = 1
  create_security_group         = false
  security_group                = null
  image_id                      = local.bastion_image_id
  machine_type                  = var.bastion_instance_profile
  prefix                        = local.bastion_node_name
  resource_group_id             = local.resource_group_id
  enable_floating_ip            = true
  security_group_ids            = module.bastion_sg[*].security_group_id
  ssh_key_ids                   = local.bastion_ssh_keys
  subnets                       = local.bastion_subnets
  tags                          = local.tags
  user_data                     = data.template_file.bastion_user_data.rendered
  vpc_id                        = var.vpc_id
  kms_encryption_enabled        = var.kms_encryption_enabled
  skip_iam_authorization_policy = var.skip_iam_authorization_policy
  boot_volume_encryption_key    = var.boot_volume_encryption_key
  existing_kms_instance_guid    = var.existing_kms_instance_guid
}

module "deployer_vsi" {
  count                         = local.enable_deployer ? 1 : 0
  source                        = "terraform-ibm-modules/landing-zone-vsi/ibm"
  version                       = "4.2.0"
  vsi_per_subnet                = 1
  create_security_group         = false
  security_group                = null
  image_id                      = local.deployer_image_id
  machine_type                  = var.deployer_instance_profile
  prefix                        = local.deployer_node_name
  resource_group_id             = local.resource_group_id
  enable_floating_ip            = false
  security_group_ids            = module.bastion_sg[*].security_group_id
  ssh_key_ids                   = local.bastion_ssh_keys
  subnets                       = local.bastion_subnets
  tags                          = local.tags
  user_data                     = data.template_file.deployer_user_data.rendered
  vpc_id                        = var.vpc_id
  kms_encryption_enabled        = var.kms_encryption_enabled
  skip_iam_authorization_policy = var.enable_bastion ? true : false
  boot_volume_encryption_key    = var.boot_volume_encryption_key
  existing_kms_instance_guid    = var.existing_kms_instance_guid
}

resource "local_sensitive_file" "prepare_tf_input" {
  count    = var.enable_deployer == true ? 1 : 0
  content  = <<EOT
{
  "ibmcloud_api_key": "${var.ibmcloud_api_key}",
  "resource_group": "${var.resource_group}",
  "prefix": "${var.prefix}",
  "zones": ${local.zones},
  "enable_landing_zone": false,
  "enable_deployer": false,
  "enable_bastion": false,
  "bastion_fip": "${local.bastion_fip}",
  "compute_ssh_keys": ${local.list_compute_ssh_keys},
  "storage_ssh_keys": ${local.list_storage_ssh_keys},
  "storage_instances": ${local.list_storage_instances},
  "management_instances": ${local.list_management_instances},
  "protocol_instances": ${local.list_protocol_instances},
  "ibm_customer_number": "${var.ibm_customer_number}",
  "static_compute_instances": ${local.list_compute_instances},
  "client_instances": ${local.list_client_instances},
  "enable_cos_integration": ${var.enable_cos_integration},
  "enable_atracker": ${var.enable_atracker},
  "enable_vpc_flow_logs": ${var.enable_vpc_flow_logs},
  "allowed_cidr": ${local.allowed_cidr},
  "vpc_id": "${var.vpc_id}",
  "vpc": "${var.vpc}",
  "storage_subnets": ${local.list_storage_subnets},
  "protocol_subnets": ${local.list_protocol_subnets},
  "compute_subnets": ${local.list_compute_subnets},
  "client_subnets": ${local.list_client_subnets},
  "bastion_subnets": ${local.list_bastion_subnets},
  "dns_domain_names": ${local.dns_domain_names},
  "compute_public_key_content": ${local.compute_public_key_content},
  "compute_private_key_content": ${local.compute_private_key_content},
  "bastion_security_group_id": "${local.bastion_security_group_id}",
  "deployer_hostname": "${local.deployer_hostname}",
  "deployer_ip": "${local.deployer_ip}"
}    
EOT
  filename = local.schematics_inputs_path
}


resource "null_resource" "tf_resource_provisioner" {
  count = var.enable_deployer == true ? 1 : 0
  connection {
    type                = "ssh"
    host                = flatten(module.deployer_vsi[*].list)[0].ipv4_address
    user                = "vpcuser"
    private_key         = local.bastion_private_key_content
    bastion_host        = local.bastion_fip
    bastion_user        = "ubuntu"
    bastion_private_key = local.bastion_private_key_content
    timeout             = "60m"
  }

  provisioner "file" {
    source      = local.schematics_inputs_path
    destination = local.remote_inputs_path
  }

  provisioner "remote-exec" {
    inline = [
      "if [ ! -d ${local.remote_terraform_path} ]; then sudo git clone -b ${local.da_hpc_repo_tag} ${local.da_hpc_repo_url} ${local.remote_terraform_path}; fi",
      "sudo ln -fs /usr/local/bin/ansible-playbook /usr/bin/ansible-playbook",
      "sudo cp ${local.remote_inputs_path} ${local.remote_terraform_path}",
      "export TF_LOG=${var.TF_LOG} && sudo -E terraform -chdir=${local.remote_terraform_path} init && sudo -E terraform -chdir=${local.remote_terraform_path} apply -parallelism=${var.TF_PARALLELISM} -auto-approve"
    ]
  }

  triggers = {
    always_run = timestamp()
  }

  depends_on = [
    module.deployer_vsi,
    local_sensitive_file.prepare_tf_input
  ]
}

resource "null_resource" "cluster_destroyer" {
  count = var.enable_deployer == true ? 1 : 0
  triggers = {
    conn_host                  = flatten(module.deployer_vsi[*].list)[0].ipv4_address
    conn_private_key           = local.bastion_private_key_content
    conn_bastion_host          = local.bastion_fip
    conn_bastion_private_key   = local.bastion_private_key_content
    conn_ibmcloud_api_key      = var.ibmcloud_api_key
    conn_remote_terraform_path = local.remote_terraform_path
    conn_terraform_log_level   = var.TF_LOG
  }

  connection {
    type                = "ssh"
    host                = self.triggers.conn_host
    user                = "vpcuser"
    private_key         = self.triggers.conn_private_key
    bastion_host        = self.triggers.conn_bastion_host
    bastion_user        = "ubuntu"
    bastion_private_key = self.triggers.conn_bastion_private_key
    timeout             = "60m"
  }

  provisioner "remote-exec" {
    when       = destroy
    on_failure = fail
    inline = [
      "export TF_LOG=${self.triggers.conn_terraform_log_level} && sudo -E terraform -chdir=${self.triggers.conn_remote_terraform_path} destroy -auto-approve"
    ]
  }
}
