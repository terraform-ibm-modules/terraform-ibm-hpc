module "lsf" {
  source                                           = "./../.."
  scheduler                                        = "LSF"
  ibm_customer_number                              = var.ibm_customer_number
  zones                                            = [var.zone]
  allowed_cidr                                     = var.allowed_cidr
  prefix                                           = local.env.prefix
  ssh_keys                                         = local.env.ssh_keys
  resource_group                                   = local.env.resource_group
  bastion_ssh_keys                                 = local.env.bastion_ssh_keys
  bastion_subnets_cidr                             = [local.env.bastion_subnets_cidr]
  compute_gui_password                             = local.env.compute_gui_password
  compute_gui_username                             = local.env.compute_gui_username
  compute_ssh_keys                                 = local.env.compute_ssh_keys
  compute_subnets_cidr                             = [local.env.compute_subnets_cidr]
  cos_instance_name                                = local.env.cos_instance_name
  dns_custom_resolver_id                           = local.env.dns_custom_resolver_id
  dns_instance_id                                  = local.env.dns_instance_id
  dns_domain_names                                 = local.env.dns_domain_names
  dynamic_compute_instances                        = local.env.dynamic_compute_instances
  enable_atracker                                  = local.env.enable_atracker
  enable_bastion                                   = local.env.enable_bastion
  bastion_image                                    = local.env.bastion_image
  bastion_instance_profile                         = local.env.bastion_instance_profile
  enable_deployer                                  = local.env.enable_deployer
  deployer_image                                   = local.env.deployer_image
  deployer_instance_profile                        = local.env.deployer_instance_profile
  enable_cos_integration                           = local.env.enable_cos_integration
  enable_vpc_flow_logs                             = local.env.enable_vpc_flow_logs
  enable_vpn                                       = local.env.enable_vpn
  file_shares                                      = local.env.file_shares
  hpcs_instance_name                               = local.env.hpcs_instance_name
  key_management                                   = local.env.key_management
  client_instances                                 = local.env.client_instances
  client_ssh_keys                                  = local.env.client_ssh_keys
  client_subnets_cidr                              = [local.env.client_subnets_cidr]
  management_instances                             = local.env.management_instances
  network_cidr                                     = local.env.network_cidr
  placement_strategy                               = local.env.placement_strategy
  protocol_instances                               = local.env.protocol_instances
  protocol_subnets_cidr                            = [local.env.protocol_subnets_cidr]
  static_compute_instances                         = local.env.static_compute_instances
  storage_gui_password                             = local.env.storage_gui_password
  storage_gui_username                             = local.env.storage_gui_username
  storage_instances                                = local.env.storage_instances
  storage_ssh_keys                                 = local.env.storage_ssh_keys
  storage_subnets_cidr                             = [local.env.storage_subnets_cidr]
  vpc                                              = local.env.vpc
  vpn_peer_address                                 = local.env.vpn_peer_address
  vpn_peer_cidr                                    = local.env.vpn_peer_cidr
  vpn_preshared_key                                = local.env.vpn_preshared_key
  kms_instance_name                                = local.env.kms_instance_name
  kms_key_name                                     = local.env.kms_key_name
  observability_atracker_enable                    = local.env.observability_atracker_enable
  observability_atracker_target_type               = local.env.observability_atracker_target_type
  observability_monitoring_enable                  = local.env.observability_monitoring_enable
  observability_logs_enable_for_management         = local.env.observability_logs_enable_for_management
  observability_logs_enable_for_compute            = local.env.observability_logs_enable_for_compute
  observability_enable_platform_logs               = local.env.observability_enable_platform_logs
  observability_enable_metrics_routing             = local.env.observability_enable_metrics_routing
  observability_logs_retention_period              = local.env.observability_logs_retention_period
  observability_monitoring_on_compute_nodes_enable = local.env.observability_monitoring_on_compute_nodes_enable
  observability_monitoring_plan                    = local.env.observability_monitoring_plan
  scc_enable                                       = local.env.scc_enable
  scc_profile                                      = local.env.scc_profile
  scc_profile_version                              = local.env.scc_profile_version
  scc_location                                     = local.env.scc_location
  scc_event_notification_plan                      = local.env.scc_event_notification_plan
}
