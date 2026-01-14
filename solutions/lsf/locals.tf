# locals needed for ibm provider
locals {
  # Region and Zone calculations
  region = join("-", slice(split("-", var.zones[0]), 0, 2))
}

locals {
  override_json_path = abspath("./override.json")
  override = {
    override = jsondecode(var.override && var.override_json_string == null ?
      (local.override_json_path == "" ? file("${path.root}/override.json") : file(local.override_json_path))
      :
    "{}")
    override_json_string = jsondecode(var.override_json_string == null ? "{}" : var.override_json_string)
  }
  override_type = var.override_json_string == null ? "override" : "override_json_string"
}

locals {
  config = {
    existing_resource_group                       = var.existing_resource_group
    remote_allowed_ips                            = var.remote_allowed_ips
    ssh_keys                                      = var.ssh_keys
    vpc_cluster_login_private_subnets_cidr_blocks = var.vpc_cluster_login_private_subnets_cidr_blocks
    vpc_cluster_private_subnets_cidr_blocks       = var.vpc_cluster_private_subnets_cidr_blocks
    compute_subnet_id                             = var.compute_subnet_id
    cos_instance_name                             = var.cos_instance_name
    dns_custom_resolver_id                        = var.dns_custom_resolver_id
    dns_instance_id                               = var.dns_instance_id
    dns_domain_name                               = var.dns_domain_name
    dynamic_compute_instances                     = var.dynamic_compute_instances
    bastion_instance                              = var.bastion_instance
    login_subnet_id                               = var.login_subnet_id
    deployer_instance                             = var.deployer_instance
    enable_cos_integration                        = var.enable_cos_integration
    enable_vpc_flow_logs                          = var.enable_vpc_flow_logs
    custom_file_shares                            = var.custom_file_shares
    storage_security_group_id                     = var.storage_security_group_id
    mtu_value                                     = var.mtu_value
    key_management                                = var.key_management
    management_instances                          = var.management_instances
    vpc_cidr                                      = var.vpc_cidr
    # placement_strategy                               = var.placement_strategy
    cluster_prefix                                   = var.cluster_prefix
    static_compute_instances                         = var.static_compute_instances
    vpc_name                                         = var.vpc_name
    kms_instance_name                                = var.kms_instance_name
    kms_key_name                                     = var.kms_key_name
    skip_iam_share_authorization_policy              = var.skip_iam_share_authorization_policy
    observability_atracker_enable                    = var.observability_atracker_enable
    observability_atracker_target_type               = var.observability_atracker_target_type
    observability_monitoring_enable                  = var.observability_monitoring_enable
    observability_logs_enable_for_management         = var.observability_logs_enable_for_management
    observability_logs_enable_for_compute            = var.observability_logs_enable_for_compute
    observability_enable_platform_logs               = var.observability_enable_platform_logs
    observability_enable_metrics_routing             = var.observability_enable_metrics_routing
    observability_logs_retention_period              = var.observability_logs_retention_period
    observability_monitoring_on_compute_nodes_enable = var.observability_monitoring_on_compute_nodes_enable
    observability_monitoring_plan                    = var.observability_monitoring_plan
    skip_flowlogs_s2s_auth_policy                    = var.skip_flowlogs_s2s_auth_policy
    skip_iam_block_storage_authorization_policy      = var.skip_iam_block_storage_authorization_policy
    skip_kms_s2s_auth_policy                         = var.skip_kms_s2s_auth_policy
    ibmcloud_api_key                                 = var.ibmcloud_api_key
    app_center_gui_password                          = var.app_center_gui_password
    lsf_version                                      = var.lsf_version
    enable_hyperthreading                            = var.enable_hyperthreading
    enable_ldap                                      = var.enable_ldap
    ldap_basedns                                     = var.ldap_basedns
    ldap_admin_password                              = var.ldap_admin_password
    ldap_user_name                                   = var.ldap_user_name
    ldap_user_password                               = var.ldap_user_password
    ldap_server                                      = var.ldap_server
    ldap_server_cert                                 = var.ldap_server_cert
    ldap_instance                                    = var.ldap_instance
    enable_dedicated_host                            = var.enable_dedicated_host
    existing_bastion_instance_name                   = var.existing_bastion_instance_name
    existing_bastion_instance_public_ip              = var.existing_bastion_instance_public_ip
    existing_bastion_security_group_id               = var.existing_bastion_security_group_id
    existing_bastion_ssh_private_key                 = var.existing_bastion_ssh_private_key
    login_instance                                   = var.login_instance
    vpn_enabled                                      = var.vpn_enabled
    sccwp_service_plan                               = var.sccwp_service_plan
    sccwp_enable                                     = var.sccwp_enable
    cspm_enabled                                     = var.cspm_enabled
    app_config_plan                                  = var.app_config_plan
    lsf_pay_per_use                                  = var.lsf_pay_per_use

  }
}

# Compile Environment for Config output
locals {
  env = {
    existing_resource_group                       = lookup(local.override[local.override_type], "existing_resource_group", local.config.existing_resource_group)
    remote_allowed_ips                            = lookup(local.override[local.override_type], "remote_allowed_ips", local.config.remote_allowed_ips)
    ssh_keys                                      = lookup(local.override[local.override_type], "ssh_keys", local.config.ssh_keys)
    vpc_cluster_login_private_subnets_cidr_blocks = lookup(local.override[local.override_type], "vpc_cluster_login_private_subnets_cidr_blocks", local.config.vpc_cluster_login_private_subnets_cidr_blocks)
    login_subnet_id                               = lookup(local.override[local.override_type], "login_subnet_id", local.config.login_subnet_id)
    vpc_cluster_private_subnets_cidr_blocks       = lookup(local.override[local.override_type], "vpc_cluster_private_subnets_cidr_blocks", local.config.vpc_cluster_private_subnets_cidr_blocks)
    compute_subnet_id                             = lookup(local.override[local.override_type], "compute_subnet_id", local.config.compute_subnet_id)
    cos_instance_name                             = lookup(local.override[local.override_type], "cos_instance_name", local.config.cos_instance_name)
    dns_custom_resolver_id                        = lookup(local.override[local.override_type], "dns_custom_resolver_id", local.config.dns_custom_resolver_id)
    dns_instance_id                               = lookup(local.override[local.override_type], "dns_instance_id", local.config.dns_instance_id)
    dns_domain_name                               = lookup(local.override[local.override_type], "dns_domain_name", local.config.dns_domain_name)
    dynamic_compute_instances                     = lookup(local.override[local.override_type], "dynamic_compute_instances", local.config.dynamic_compute_instances)
    bastion_instance                              = lookup(local.override[local.override_type], "bastion_instance", local.config.bastion_instance)
    deployer_instance                             = lookup(local.override[local.override_type], "deployer_instance", local.config.deployer_instance)
    enable_cos_integration                        = lookup(local.override[local.override_type], "enable_cos_integration", local.config.enable_cos_integration)
    enable_vpc_flow_logs                          = lookup(local.override[local.override_type], "enable_vpc_flow_logs", local.config.enable_vpc_flow_logs)
    custom_file_shares                            = lookup(local.override[local.override_type], "custom_file_shares", local.config.custom_file_shares)
    storage_security_group_id                     = lookup(local.override[local.override_type], "storage_security_group_id", local.config.storage_security_group_id)
    mtu_value                                     = lookup(local.override[local.override_type], "mtu_value", local.config.mtu_value)
    key_management                                = lookup(local.override[local.override_type], "key_management", local.config.key_management)
    management_instances                          = lookup(local.override[local.override_type], "management_instances", local.config.management_instances)
    vpc_cidr                                      = lookup(local.override[local.override_type], "vpc_cidr", local.config.vpc_cidr)
    # placement_strategy                               = lookup(local.override[local.override_type], "placement_strategy", local.config.placement_strategy)
    cluster_prefix                                   = lookup(local.override[local.override_type], "cluster_prefix", local.config.cluster_prefix)
    static_compute_instances                         = lookup(local.override[local.override_type], "static_compute_instances", local.config.static_compute_instances)
    vpc_name                                         = lookup(local.override[local.override_type], "vpc_name", local.config.vpc_name)
    kms_instance_name                                = lookup(local.override[local.override_type], "kms_instance_name", local.config.kms_instance_name)
    kms_key_name                                     = lookup(local.override[local.override_type], "kms_key_name", local.config.kms_key_name)
    skip_iam_share_authorization_policy              = lookup(local.override[local.override_type], "skip_iam_share_authorization_policy", local.config.skip_iam_share_authorization_policy)
    observability_atracker_enable                    = lookup(local.override[local.override_type], "observability_atracker_enable", local.config.observability_atracker_enable)
    observability_atracker_target_type               = lookup(local.override[local.override_type], "observability_atracker_target_type", local.config.observability_atracker_target_type)
    observability_monitoring_enable                  = lookup(local.override[local.override_type], "observability_monitoring_enable", local.config.observability_monitoring_enable)
    observability_logs_enable_for_management         = lookup(local.override[local.override_type], "observability_logs_enable_for_management", local.config.observability_logs_enable_for_management)
    observability_logs_enable_for_compute            = lookup(local.override[local.override_type], "observability_logs_enable_for_compute", local.config.observability_logs_enable_for_compute)
    observability_enable_platform_logs               = lookup(local.override[local.override_type], "observability_enable_platform_logs", local.config.observability_enable_platform_logs)
    observability_enable_metrics_routing             = lookup(local.override[local.override_type], "observability_enable_metrics_routing", local.config.observability_enable_metrics_routing)
    observability_logs_retention_period              = lookup(local.override[local.override_type], "observability_logs_retention_period", local.config.observability_logs_retention_period)
    observability_monitoring_on_compute_nodes_enable = lookup(local.override[local.override_type], "observability_monitoring_on_compute_nodes_enable", local.config.observability_monitoring_on_compute_nodes_enable)
    observability_monitoring_plan                    = lookup(local.override[local.override_type], "observability_monitoring_plan", local.config.observability_monitoring_plan)
    skip_flowlogs_s2s_auth_policy                    = lookup(local.override[local.override_type], "skip_flowlogs_s2s_auth_policy", local.config.skip_flowlogs_s2s_auth_policy)
    skip_iam_block_storage_authorization_policy      = lookup(local.override[local.override_type], "skip_iam_block_storage_authorization_policy", local.config.skip_iam_block_storage_authorization_policy)
    skip_kms_s2s_auth_policy                         = lookup(local.override[local.override_type], "skip_kms_s2s_auth_policy", local.config.skip_kms_s2s_auth_policy)
    ibmcloud_api_key                                 = lookup(local.override[local.override_type], "ibmcloud_api_key", local.config.ibmcloud_api_key)
    app_center_gui_password                          = lookup(local.override[local.override_type], "app_center_gui_password", local.config.app_center_gui_password)
    lsf_version                                      = lookup(local.override[local.override_type], "lsf_version", local.config.lsf_version)
    enable_hyperthreading                            = lookup(local.override[local.override_type], "enable_hyperthreading", local.config.enable_hyperthreading)
    enable_ldap                                      = lookup(local.override[local.override_type], "enable_ldap", local.config.enable_ldap)
    vpn_enabled                                      = lookup(local.override[local.override_type], "vpn_enabled", local.config.vpn_enabled)
    ldap_basedns                                     = lookup(local.override[local.override_type], "ldap_basedns", local.config.ldap_basedns)
    ldap_admin_password                              = lookup(local.override[local.override_type], "ldap_admin_password", local.config.ldap_admin_password)
    ldap_user_name                                   = lookup(local.override[local.override_type], "ldap_user_name", local.config.ldap_user_name)
    ldap_user_password                               = lookup(local.override[local.override_type], "ldap_user_password", local.config.ldap_user_password)
    ldap_server                                      = lookup(local.override[local.override_type], "ldap_server", local.config.ldap_server)
    ldap_server_cert                                 = lookup(local.override[local.override_type], "ldap_server_cert", local.config.ldap_server_cert)
    ldap_instance                                    = lookup(local.override[local.override_type], "ldap_instance", local.config.ldap_instance)
    enable_dedicated_host                            = lookup(local.override[local.override_type], "enable_dedicated_host", local.config.enable_dedicated_host)
    existing_bastion_instance_name                   = lookup(local.override[local.override_type], "existing_bastion_instance_name", local.config.existing_bastion_instance_name)
    existing_bastion_instance_public_ip              = lookup(local.override[local.override_type], "existing_bastion_instance_public_ip", local.config.existing_bastion_instance_public_ip)
    existing_bastion_security_group_id               = lookup(local.override[local.override_type], "existing_bastion_security_group_id", local.config.existing_bastion_security_group_id)
    existing_bastion_ssh_private_key                 = lookup(local.override[local.override_type], "existing_bastion_ssh_private_key", local.config.existing_bastion_ssh_private_key)
    login_instance                                   = lookup(local.override[local.override_type], "login_instance", local.config.login_instance)
    sccwp_enable                                     = lookup(local.override[local.override_type], "scc_wp_enable", local.config.sccwp_enable)
    cspm_enable                                      = lookup(local.override[local.override_type], "cspm_enable", local.config.cspm_enabled)
    sccwp_service_plan                               = lookup(local.override[local.override_type], "scc_wp_service_plan", local.config.sccwp_service_plan)
    app_config_plan                                  = lookup(local.override[local.override_type], "app_config_plan", local.config.app_config_plan)
    lsf_pay_per_use                                  = lookup(local.override[local.override_type], "lsf_pay_per_use", local.config.lsf_pay_per_use)
    # client_instances                                 = lookup(local.override[local.override_type], "client_instances", local.config.client_instances)
    # client_subnets_cidr                              = lookup(local.override[local.override_type], "client_subnets_cidr", local.config.client_subnets_cidr)
  }
}
locals {
  custom_fileshare_iops_range = [
    [10, 39, 100, 1000],
    [40, 79, 100, 2000],
    [80, 99, 100, 4000],
    [100, 499, 100, 6000],
    [500, 999, 100, 10000],
    [1000, 1999, 100, 20000],
    [2000, 3999, 200, 40000],
    [4000, 7999, 300, 40000],
    [8000, 15999, 500, 64000],
    [16000, 32000, 2000, 96000]
  ]
}
