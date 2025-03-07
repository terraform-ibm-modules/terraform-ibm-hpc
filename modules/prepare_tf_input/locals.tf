locals {
  schematics_inputs_path      = "/tmp/.schematics/solution_terraform.auto.tfvars.json"
  remote_inputs_path          = format("%s/terraform.tfvars.json", "/tmp")
  deployer_path               = "/opt/ibm"
  remote_terraform_path       = format("%s/terraform-ibm-hpc", local.deployer_path)
  remote_ansible_path         = format("%s/terraform-ibm-hpc", local.deployer_path)
  da_hpc_repo_url             = "https://github.com/terraform-ibm-modules/terraform-ibm-hpc.git"
  da_hpc_repo_tag             = "pr-199" ###### change it to main in future
  zones                       = jsonencode(var.zones)
  list_compute_ssh_keys       = jsonencode(var.compute_ssh_keys)
  list_storage_ssh_keys       = jsonencode(var.storage_ssh_keys)
  list_storage_instances      = jsonencode(var.storage_instances)
  list_management_instances   = jsonencode(var.management_instances)
  list_protocol_instances     = jsonencode(var.protocol_instances)
  list_compute_instances      = jsonencode(var.static_compute_instances)
  list_client_instances       = jsonencode(var.client_instances)
  allowed_cidr                = jsonencode(var.allowed_cidr)
  list_storage_subnets        = jsonencode(length(var.storage_subnets) == 0 ? null : var.storage_subnets)
  list_protocol_subnets       = jsonencode(length(var.protocol_subnets) == 0 ? null : var.protocol_subnets)
  list_compute_subnets        = jsonencode(length(var.compute_subnets) == 0 ? null : var.compute_subnets)
  list_client_subnets         = jsonencode(length(var.client_subnets) == 0 ? null : var.client_subnets)
  list_bastion_subnets        = jsonencode(length(var.bastion_subnets) == 0 ? null : var.bastion_subnets)
  dns_domain_names            = jsonencode(var.dns_domain_names)
  compute_public_key_content  = var.compute_public_key_content != null ? jsonencode(base64encode(var.compute_public_key_content)) : ""
  compute_private_key_content = var.compute_private_key_content != null ? jsonencode(base64encode(var.compute_private_key_content)) : ""
}
