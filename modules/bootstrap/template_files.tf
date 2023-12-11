data "template_file" "bootstrap_user_data" {
  template = file("${path.module}/templates/bootstrap_user_data.tpl")
  vars = {
    bastion_public_key_content = var.enable_bastion ? "" : (var.bastion_public_key_content != null ? var.bastion_public_key_content : "")
    remote_ansible_path        = var.enable_bastion ? "" : local.remote_ansible_path
    da_hpc_repo_tag            = var.enable_bastion ? "" : local.da_hpc_repo_tag
    da_hpc_repo_url            = var.enable_bastion ? "" : local.da_hpc_repo_url
    ibmcloud_api_key           = var.enable_bastion ? "" : var.ibmcloud_api_key
    resource_group             = var.enable_bastion ? "" : var.resource_group
    prefix                     = var.enable_bastion ? "" : var.prefix
    zones                      = var.enable_bastion ? "" : jsonencode(var.zones)
    compute_ssh_keys           = var.enable_bastion ? "" : jsonencode(var.compute_ssh_keys)
    login_ssh_keys             = var.enable_bastion ? "" : jsonencode(var.login_ssh_keys)
    storage_ssh_keys           = var.enable_bastion ? "" : jsonencode(var.storage_ssh_keys)
    vpc                        = var.enable_bastion ? "" : var.vpc
    compute_subnets            = var.enable_bastion ? "" : jsonencode(var.compute_subnets)
    login_subnets              = var.enable_bastion ? "" : jsonencode(var.login_subnets)
    storage_subnets            = var.enable_bastion ? "" : jsonencode(var.storage_subnets)
    protocol_subnets           = var.enable_bastion ? "" : jsonencode(var.protocol_subnets)
    boot_volume_encryption_key = var.enable_bastion ? "" : var.boot_volume_encryption_key
    bastion_security_group_id  = var.enable_bastion ? "" : one(var.security_group_ids)
    dns_instance_id            = var.enable_bastion ? "" : var.dns_instance_id
    dns_custom_resolver_id     = var.enable_bastion ? "" : var.dns_custom_resolver_id
    enable_bastion             = var.enable_bastion ? "" : var.enable_bastion
  }
}
