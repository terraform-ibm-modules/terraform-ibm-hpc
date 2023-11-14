data "template_file" "bootstrap_user_data" {
  template = file("${path.module}/templates/bootstrap_user_data.tpl")
  vars = {
    bastion_public_key_content     = var.bastion_public_key_content != null ? var.bastion_public_key_content : ""
    remote_ansible_path = local.remote_ansible_path
    da_hpc_repo_tag = local.da_hpc_repo_tag
    da_hpc_repo_url = local.da_hpc_repo_url
    ibmcloud_api_key = var.ibmcloud_api_key
    resource_group = var.resource_group
    prefix = var.prefix
    zones = jsonencode(var.zones)
    compute_ssh_keys = jsonencode(var.compute_ssh_keys)
    login_ssh_keys = jsonencode(var.login_ssh_keys)
    storage_ssh_keys = jsonencode(var.storage_ssh_keys)
  }
}
