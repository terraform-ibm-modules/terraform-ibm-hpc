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
    compute_ssh_keys             = local.enable_bastion ? jsonencode(var.compute_ssh_keys) : ""
    storage_ssh_keys             = local.enable_bastion ? jsonencode(var.storage_ssh_keys) : ""
    storage_instances            = local.enable_bastion ? jsonencode(var.storage_instances) : ""
    management_instances         = local.enable_bastion ? jsonencode(var.management_instances) : ""
    protocol_instances           = local.enable_bastion ? jsonencode(var.protocol_instances) : ""
    compute_instances            = local.enable_bastion ? jsonencode(var.static_compute_instances) : ""
    client_instances             = local.enable_bastion ? jsonencode(var.client_instances) : ""
    enable_cos_integration       = local.enable_bastion ? var.enable_cos_integration : ""
    enable_atracker              = local.enable_bastion ? var.enable_atracker : ""
    enable_vpc_flow_logs         = local.enable_bastion ? var.enable_vpc_flow_logs : ""
    vpc_id                       = local.enable_bastion ? var.vpc_id : ""
    storage_subnets              = local.enable_bastion ? jsonencode(local.existing_storage_subnets) : ""
    protocol_subnets             = local.enable_bastion ? jsonencode(local.existing_protocol_subnets) : ""
    compute_subnets              = local.enable_bastion ? jsonencode(local.existing_compute_subnets) : ""
    client_subnets               = local.enable_bastion ? jsonencode(local.existing_client_subnets) : ""
    bastion_subnets              = local.enable_bastion ? jsonencode(local.existing_bastion_subnets) : ""
    bastion_fip                  = local.enable_bastion ? var.bastion_fip : ""
    vpc                          = local.enable_bastion ? var.vpc : ""
    compute_dns_domain           = local.enable_bastion ? local.compute_dns_domain : ""
    compute_interfaces           = local.enable_bastion ? local.compute_interfaces : ""
    dns_domain_names             = local.enable_bastion ? jsonencode(var.dns_domain_names) : ""

  }
}
