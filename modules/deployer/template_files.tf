data "template_file" "bastion_user_data" {
  template = file("${path.module}/templates/bastion_user_data.tpl")
  vars = {
    ssh_public_key_content = local.enable_bastion ? module.ssh_key[0].public_key_content : ""
  }
}

data "template_file" "deployer_user_data" {
  template = file("${path.module}/templates/deployer_user_data.tpl")
  vars = {
    bastion_public_key_content   = local.enable_bastion ? module.ssh_key[0].public_key_content : ""
    remote_ansible_path          = local.enable_bastion ? local.remote_ansible_path : ""
    da_hpc_repo_tag              = local.enable_bastion ? local.da_hpc_repo_tag : ""
    da_hpc_repo_url              = local.enable_bastion ? local.da_hpc_repo_url : ""
    ibmcloud_api_key             = local.enable_bastion ? var.ibmcloud_api_key : ""
    ibm_customer_number          = local.enable_bastion ? var.ibm_customer_number : ""
    resource_group               = local.enable_bastion ? var.resource_group : ""
    prefix                       = local.enable_bastion ? var.prefix : ""
    allowed_cidr                 = local.enable_bastion ? jsonencode(var.allowed_cidr) : "" 
    zones                        = local.enable_bastion ? jsonencode(var.zones) : ""
    enable_bastion               = local.enable_bastion ? local.enable_bastion : ""
  }
}
