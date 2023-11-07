data "template_file" "bastion_user_data" {
  template = file("${path.module}/templates/bastion_user_data.tpl")
  vars = {
    ssh_public_key_content = local.enable_bastion ? module.ssh_key[0].public_key_content : ""
  }
}

data "template_file" "bootstrap_user_data" {
  template = file("${path.module}/templates/bootstrap_user_data.tpl")
  vars = {
    bastion_public_key_content = local.enable_bastion ? module.ssh_key[0].public_key_content : ""
    remote_ansible_path = local.remote_ansible_path
    da_hpc_repo_tag = local.da_hpc_repo_tag
    da_hpc_repo_url = local.da_hpc_repo_url
    ibmcloud_api_key = var.ibmcloud_api_key
    resource_group = var.resource_group
    prefix = var.prefix
    zones = var.zones
    compute_ssh_keys = var.compute_ssh_keys
    login_ssh_keys = var.login_ssh_keys
    storage_ssh_keys = var.storage_ssh_keys
    allowed_cidr = var.allowed_cidr
  }
}
