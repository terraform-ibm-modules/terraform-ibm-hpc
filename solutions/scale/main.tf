module "scale" {
  source                                        = "./../.."
  scheduler                                     = "Scale"
  ibm_customer_number                           = var.ibm_customer_number
  zones                                         = var.zones
  remote_allowed_ips                            = var.remote_allowed_ips
  cluster_prefix                                = local.env.cluster_prefix
  ssh_keys                                      = local.env.ssh_keys
  existing_resource_group                       = local.env.existing_resource_group
  vpc_cluster_login_private_subnets_cidr_blocks = local.env.vpc_cluster_login_private_subnets_cidr_blocks
  vpc_cluster_private_subnets_cidr_blocks       = local.env.vpc_cluster_private_subnets_cidr_blocks
  cos_instance_name                             = local.env.cos_instance_name
  dns_custom_resolver_id                        = local.env.dns_custom_resolver_id
  dns_instance_id                               = local.env.dns_instance_id
  dns_domain_names                              = local.env.dns_domain_names
  enable_atracker                               = local.env.enable_atracker
  # enable_bastion                                   = local.env.enable_bastion
  bastion_instance                                 = local.env.bastion_instance
  deployer_instance                                = local.env.deployer_instance
  enable_cos_integration                           = local.env.enable_cos_integration
  enable_vpc_flow_logs                             = local.env.enable_vpc_flow_logs
  key_management                                   = local.env.key_management
  client_instances                                 = local.env.client_instances
  vpc_cidr                                         = local.env.vpc_cidr
  placement_strategy                               = local.env.placement_strategy
  protocol_instances                               = local.env.protocol_instances
  protocol_subnets_cidr                            = [local.env.protocol_subnets_cidr]
  colocate_protocol_instances                      = local.env.colocate_protocol_instances
  static_compute_instances                         = local.env.compute_instances
  storage_instances                                = local.env.storage_instances
  storage_servers                                  = local.env.storage_servers
  storage_subnets_cidr                             = [local.env.storage_subnets_cidr]
  vpc_name                                         = local.env.vpc_name
  compute_gui_password                             = local.env.compute_gui_password
  compute_gui_username                             = local.env.compute_gui_username
  storage_gui_password                             = local.env.storage_gui_password
  storage_gui_username                             = local.env.storage_gui_username
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
  skip_flowlogs_s2s_auth_policy                    = local.env.skip_flowlogs_s2s_auth_policy
  skip_kms_s2s_auth_policy                         = local.env.skip_kms_s2s_auth_policy
  skip_iam_block_storage_authorization_policy      = local.env.skip_iam_block_storage_authorization_policy
  ibmcloud_api_key                                 = local.env.ibmcloud_api_key
  afm_instances                                    = local.env.afm_instances
  afm_cos_config                                   = local.env.afm_cos_config
  enable_ldap                                      = local.env.enable_ldap
  ldap_basedns                                     = local.env.ldap_basedns
  ldap_admin_password                              = local.env.ldap_admin_password
  ldap_user_name                                   = local.env.ldap_user_name
  ldap_user_password                               = local.env.ldap_user_password
  ldap_server                                      = local.env.ldap_server
  ldap_server_cert                                 = local.env.ldap_server_cert
  ldap_instance                                    = local.env.ldap_instance
  scale_encryption_enabled                         = local.env.scale_encryption_enabled
  scale_encryption_type                            = local.env.scale_encryption_type
  gklm_instance_key_pair                           = local.env.gklm_instance_key_pair
  gklm_instances                                   = local.env.gklm_instances
  storage_type                                     = local.env.storage_type
  scale_encryption_admin_password                  = local.env.scale_encryption_admin_password
  filesystem_config                                = local.env.filesystem_config
  existing_bastion_instance_name                   = local.env.existing_bastion_instance_name
  existing_bastion_instance_public_ip              = local.env.existing_bastion_instance_public_ip
  existing_bastion_security_group_id               = local.env.existing_bastion_security_group_id
  existing_bastion_ssh_private_key                 = local.env.existing_bastion_ssh_private_key
  client_subnets_cidr                              = [local.env.client_subnets_cidr]
  # hpcs_instance_name                               = local.env.hpcs_instance_name
  # scale_encryption_admin_username         = local.env.scale_encryption_admin_username
  # scale_encryption_admin_default_password = local.env.scale_encryption_admin_default_password
}
