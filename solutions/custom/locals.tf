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
    deployer_instance                             = var.deployer_instance
    ssh_keys                                      = var.ssh_keys
    vpc_cluster_login_private_subnets_cidr_blocks = var.vpc_cluster_login_private_subnets_cidr_blocks
    compute_gui_password                          = var.compute_gui_password
    compute_gui_username                          = var.compute_gui_username
    vpc_cluster_private_subnets_cidr_blocks       = var.vpc_cluster_private_subnets_cidr_blocks
    cos_instance_name                             = var.cos_instance_name
    dns_custom_resolver_id                        = var.dns_custom_resolver_id
    dns_instance_id                               = var.dns_instance_id
    dns_domain_names                              = var.dns_domain_names
    dynamic_compute_instances                     = var.dynamic_compute_instances
    enable_atracker                               = var.enable_atracker
    # enable_bastion                                = var.enable_bastion
    enable_cos_integration   = var.enable_cos_integration
    enable_vpc_flow_logs     = var.enable_vpc_flow_logs
    custom_file_shares       = var.custom_file_shares
    hpcs_instance_name       = var.hpcs_instance_name
    key_management           = var.key_management
    client_instances         = var.client_instances
    client_subnets_cidr      = var.client_subnets_cidr
    management_instances     = var.management_instances
    vpc_cidr                 = var.vpc_cidr
    placement_strategy       = var.placement_strategy
    cluster_prefix           = var.cluster_prefix
    protocol_instances       = var.protocol_instances
    protocol_subnets_cidr    = var.protocol_subnets_cidr
    static_compute_instances = var.static_compute_instances
    storage_gui_password     = var.storage_gui_password
    storage_gui_username     = var.storage_gui_username
    storage_instances        = var.storage_instances
    storage_subnets_cidr     = var.storage_subnets_cidr
    vpc_name                 = var.vpc_name
  }
}

# Compile Environment for Config output
locals {
  env = {
    existing_resource_group                       = lookup(local.override[local.override_type], "existing_resource_group", local.config.existing_resource_group)
    remote_allowed_ips                            = lookup(local.override[local.override_type], "remote_allowed_ips", local.config.remote_allowed_ips)
    deployer_instance                             = lookup(local.override[local.override_type], "deployer_instance", local.config.deployer_instance)
    ssh_keys                                      = lookup(local.override[local.override_type], "ssh_keys", local.config.ssh_keys)
    vpc_cluster_login_private_subnets_cidr_blocks = lookup(local.override[local.override_type], "vpc_cluster_login_private_subnets_cidr_blocks", local.config.vpc_cluster_login_private_subnets_cidr_blocks)
    compute_gui_password                          = lookup(local.override[local.override_type], "compute_gui_password", local.config.compute_gui_password)
    compute_gui_username                          = lookup(local.override[local.override_type], "compute_gui_username", local.config.compute_gui_username)
    vpc_cluster_private_subnets_cidr_blocks       = lookup(local.override[local.override_type], "vpc_cluster_private_subnets_cidr_blocks", local.config.vpc_cluster_private_subnets_cidr_blocks)
    cos_instance_name                             = lookup(local.override[local.override_type], "cos_instance_name", local.config.cos_instance_name)
    dns_custom_resolver_id                        = lookup(local.override[local.override_type], "dns_custom_resolver_id", local.config.dns_custom_resolver_id)
    dns_instance_id                               = lookup(local.override[local.override_type], "dns_instance_id", local.config.dns_instance_id)
    dns_domain_names                              = lookup(local.override[local.override_type], "dns_domain_names", local.config.dns_domain_names)
    dynamic_compute_instances                     = lookup(local.override[local.override_type], "dynamic_compute_instances", local.config.dynamic_compute_instances)
    enable_atracker                               = lookup(local.override[local.override_type], "enable_atracker", local.config.enable_atracker)
    # enable_bastion                                = lookup(local.override[local.override_type], "enable_bastion", local.config.enable_bastion)
    enable_cos_integration   = lookup(local.override[local.override_type], "enable_cos_integration", local.config.enable_cos_integration)
    enable_vpc_flow_logs     = lookup(local.override[local.override_type], "enable_vpc_flow_logs", local.config.enable_vpc_flow_logs)
    custom_file_shares       = lookup(local.override[local.override_type], "custom_file_shares", local.config.custom_file_shares)
    hpcs_instance_name       = lookup(local.override[local.override_type], "hpcs_instance_name", local.config.hpcs_instance_name)
    key_management           = lookup(local.override[local.override_type], "key_management", local.config.key_management)
    client_instances         = lookup(local.override[local.override_type], "client_instances", local.config.client_instances)
    client_subnets_cidr      = lookup(local.override[local.override_type], "client_subnets_cidr", local.config.client_subnets_cidr)
    management_instances     = lookup(local.override[local.override_type], "management_instances", local.config.management_instances)
    vpc_cidr                 = lookup(local.override[local.override_type], "vpc_cidr", local.config.vpc_cidr)
    placement_strategy       = lookup(local.override[local.override_type], "placement_strategy", local.config.placement_strategy)
    cluster_prefix           = lookup(local.override[local.override_type], "cluster_prefix", local.config.cluster_prefix)
    protocol_instances       = lookup(local.override[local.override_type], "protocol_instances", local.config.protocol_instances)
    protocol_subnets_cidr    = lookup(local.override[local.override_type], "protocol_subnets_cidr", local.config.protocol_subnets_cidr)
    static_compute_instances = lookup(local.override[local.override_type], "static_compute_instances", local.config.static_compute_instances)
    storage_gui_password     = lookup(local.override[local.override_type], "storage_gui_password", local.config.storage_gui_password)
    storage_gui_username     = lookup(local.override[local.override_type], "storage_gui_username", local.config.storage_gui_username)
    storage_instances        = lookup(local.override[local.override_type], "storage_instances", local.config.storage_instances)
    storage_subnets_cidr     = lookup(local.override[local.override_type], "storage_subnets_cidr", local.config.storage_subnets_cidr)
    vpc_name                 = lookup(local.override[local.override_type], "vpc_name", local.config.vpc_name)
  }
}
