resource "local_sensitive_file" "prepare_tf_input" {
  count    = var.enable_deployer == true ? 1 : 0
  content  = <<EOT
{
  "ibmcloud_api_key": "${var.ibmcloud_api_key}",
  "existing_resource_group": "${var.existing_resource_group}",
  "prefix": "${var.prefix}",
  "zones": ${local.zones},
  "enable_landing_zone": false,
  "enable_deployer": false,
  "enable_bastion": false,
  "compute_ssh_keys": ${local.list_compute_ssh_keys},
  "storage_ssh_keys": ${local.list_storage_ssh_keys},
  "storage_instances": ${local.list_storage_instances},
  "management_instances": ${local.list_management_instances},
  "protocol_instances": ${local.list_protocol_instances},
  "ibm_customer_number": "${var.ibm_customer_number}",
  "static_compute_instances": ${local.list_compute_instances},
  "dynamic_compute_instances": ${local.dynamic_compute_instances},
  "client_instances": ${local.list_client_instances},
  "enable_cos_integration": ${var.enable_cos_integration},
  "enable_atracker": ${var.enable_atracker},
  "enable_vpc_flow_logs": ${var.enable_vpc_flow_logs},
  "allowed_cidr": ${local.allowed_cidr},
  "vpc_name": "${var.vpc_name}",
  "storage_subnets": ${local.list_storage_subnets},
  "protocol_subnets": ${local.list_protocol_subnets},
  "compute_subnets": ${local.list_compute_subnets},
  "client_subnets": ${local.list_client_subnets},
  "bastion_subnets": ${local.list_bastion_subnets},
  "dns_domain_names": ${local.dns_domain_names},
  "bastion_security_group_id": "${var.bastion_security_group_id}",
  "deployer_hostname": "${var.deployer_hostname}",
  "deployer_ip": "${var.deployer_ip}",
  "enable_hyperthreading": ${var.enable_hyperthreading},
  "enable_ldap": ${var.enable_ldap},
  "ldap_vsi_profile": ${jsonencode(var.ldap_vsi_profile)},
  "ldap_vsi_osimage_name": ${jsonencode(var.ldap_vsi_osimage_name)},
  "ldap_basedns": ${jsonencode(var.ldap_basedns)},
  "ldap_admin_password": ${jsonencode(var.ldap_admin_password)},
  "ldap_user_name": ${jsonencode(var.ldap_user_name)},
  "ldap_user_password": ${jsonencode(var.ldap_user_password)},
  "ldap_server": ${jsonencode(var.ldap_server)},
  "ldap_server_cert": ${jsonencode(var.ldap_server_cert)},
  "scc_enable": ${var.scc_enable},
  "scc_profile": "${var.scc_profile}",
  "scc_location": "${var.scc_location}",
  "scc_cos_bucket": "${var.scc_cos_bucket}",
  "scc_cos_instance_crn": "${var.scc_cos_instance_crn}",
  "scc_event_notification_plan": "${var.scc_event_notification_plan}",
  "cloud_logs_data_bucket": ${var.cloud_logs_data_bucket},
  "cloud_metrics_data_bucket": ${var.cloud_metrics_data_bucket},
  "observability_logs_enable_for_management": ${var.observability_logs_enable_for_management},
  "observability_logs_enable_for_compute": ${var.observability_logs_enable_for_compute},
  "observability_enable_platform_logs": ${var.observability_enable_platform_logs},
  "observability_monitoring_enable": ${var.observability_monitoring_enable},
  "observability_monitoring_plan": "${var.observability_monitoring_plan}",
  "observability_logs_retention_period": ${var.observability_logs_retention_period},
  "observability_monitoring_on_compute_nodes_enable": ${var.observability_monitoring_on_compute_nodes_enable},
  "observability_enable_metrics_routing": ${var.observability_enable_metrics_routing},
  "observability_atracker_enable": ${var.observability_atracker_enable},
  "observability_atracker_target_type": "${var.observability_atracker_target_type}"
}
EOT
  filename = local.schematics_inputs_path
}
