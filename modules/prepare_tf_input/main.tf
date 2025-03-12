resource "local_sensitive_file" "prepare_tf_input" {
  count    = var.enable_deployer == true ? 1 : 0
  content  = <<EOT
{
  "ibmcloud_api_key": "${var.ibmcloud_api_key}",
  "existing_resource_group": "${var.resource_group}",
  "prefix": "${var.prefix}",
  "zones": ${local.zones},
  "enable_landing_zone": false,
  "enable_deployer": false,
  "enable_bastion": false,
  "bastion_fip": "${var.bastion_fip}",
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
  "vpc_name": "${var.vpc}",
  "vpc_id": "${var.vpc_id}",
  "storage_subnets": ${local.list_storage_subnets},
  "protocol_subnets": ${local.list_protocol_subnets},
  "compute_subnets": ${local.list_compute_subnets},
  "client_subnets": ${local.list_client_subnets},
  "bastion_subnets": ${local.list_bastion_subnets},
  "dns_domain_names": ${local.dns_domain_names},
  "bastion_security_group_id": "${var.bastion_security_group_id}",
  "deployer_hostname": "${var.deployer_hostname}",
  "deployer_ip": "${var.deployer_ip}"
}
EOT
  filename = local.schematics_inputs_path
}
