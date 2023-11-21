data "template_file" "bootstrap_user_data" {
  template = file("${path.module}/templates/bootstrap_user_data.tpl")
  vars = {
    bastion_public_key_content = var.bastion_public_key_content != null ? var.bastion_public_key_content : ""
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
    vpc = var.vpc
    compute_subnets = jsonencode(var.compute_subnets)
    login_subnets = jsonencode(var.login_subnets)
    storage_subnets = jsonencode(var.storage_subnets)
    protocol_subnets = jsonencode(var.protocol_subnets)
    boot_volume_encryption_key = var.boot_volume_encryption_key
    bastion_security_group_id = one(var.security_group_ids)
    dns_instance_id = var.dns_instance_id
    dns_custom_resolver_id = var.dns_custom_resolver_id
  }
}
