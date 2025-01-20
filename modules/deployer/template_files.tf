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
    ibmcloud_api_key             = local.enable_bastion ? jsonencode(var.ibmcloud_api_key) : ""
    ibm_customer_number          = local.enable_bastion ? var.ibm_customer_number : ""
    resource_group               = local.enable_bastion ? var.resource_group : ""
    prefix                       = local.enable_bastion ? var.prefix : ""
    allowed_cidr                 = local.enable_bastion ? jsonencode(var.allowed_cidr) : "" 
    zones                        = local.enable_bastion ? jsonencode(var.zones) : ""
    enable_bastion               = local.enable_bastion ? local.enable_bastion : ""
    compute_ssh_keys             = local.enable_bastion ? jsonencode(var.compute_ssh_keys) : ""
    storage_ssh_keys             = local.enable_bastion ? jsonencode(var.storage_ssh_keys) : ""
    storage_instances            = local.enable_bastion ? jsonencode(var.storage_instances) : ""
    protocol_instances           = local.enable_bastion ? jsonencode(var.protocol_instances) : ""
    compute_instances            = local.enable_bastion ? jsonencode(var.static_compute_instances) : ""
    client_instances             = local.enable_bastion ? jsonencode(var.client_instances) : ""
    enable_cos_integration       = local.enable_bastion ? var.enable_cos_integration : ""
    enable_atracker              = local.enable_bastion ? var.enable_atracker : ""
    enable_vpc_flow_logs         = local.enable_bastion ? var.enable_vpc_flow_logs : ""
    key_management               = local.enable_bastion ? jsonencode(var.key_management) : ""
    vpc_id                       = local.enable_bastion ? var.vpc_id : ""
    storage_subnets              = local.enable_bastion ? jsonencode(var.storage_subnets) : ""
    protocol_subnets             = local.enable_bastion ? jsonencode(var.protocol_subnets) : ""
    compute_subnets              = local.enable_bastion ? jsonencode(var.compute_subnets) : ""
    client_subnets               = local.enable_bastion ? jsonencode(var.client_subnets) : ""
    bastion_fip                  = local.enable_bastion ? var.bastion_fip : ""
    dns_instance_id              = local.enable_bastion ? var.dns_instance_id : ""
    dns_custom_resolver_id       = local.enable_bastion ? var.dns_custom_resolver_id : ""
    dns_domain_names             = local.enable_bastion ? jsonencode(var.dns_domain_names) : ""
    vpc                          = local.enable_bastion ? var.vpc : ""
    resource_group_id            = local.enable_bastion ? jsonencode(var.resource_group_id) : ""
  }
}
