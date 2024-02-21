# define variables
locals {
  # Future use
  # products       = "scale"
  name           = "hpc"
  prefix         = var.prefix
  tags           = [local.prefix, local.name]
  vsi_interfaces = ["eth0", "eth1"]
  bms_interfaces = ["ens1", "ens2"]
  # TODO: explore (DA always keep it true)
  skip_iam_authorization_policy = true

///It is for spectrum storage
  # block_storage_volumes = [for volume in var.nsd_details : {
  #   name           = format("nsd-%s", index(var.nsd_details, volume) + 1)
  #   profile        = volume["profile"]
  #   capacity       = volume["capacity"]
  #   iops           = volume["iops"]
  #   resource_group = var.resource_group
  #   # TODO: Encryption
  #   # encryption_key =
  # }]
  # TODO: Update the LB configurable
  # Bug: 5847 - LB profile & subnets are not configurable
  /*
  load_balancers = [{
    name              = "hpc"
    type              = "private"
    listener_port     = 80
    listener_protocol = "http"
    connection_limit  = 10
    algorithm         = "round_robin"
    protocol          = "http"
    health_delay      = 60
    health_retries    = 5
    health_timeout    = 30
    health_type       = "http"
    pool_member_port  = 80
  }]
  */
  management_instance_count = var.management_node_count
  # management_instance_count     = sum(var.management_instances[*]["count"])
  # storage_instance_count        = sum(var.storage_instances[*]["count"])
  # protocol_instance_count       = sum(var.protocol_instances[*]["count"])
  # static_compute_instance_count = sum(var.static_compute_instances[*]["count"])

  # enable_login      = local.management_instance_count > 0
  # enable_management = local.management_instance_count > 0
  # enable_compute    = local.management_instance_count > 0 || local.static_compute_instance_count > 0 || local.protocol_instance_count > 0
  # enable_storage    = local.storage_instance_count > 0
  # TODO: Fix the logic
  enable_block_storage = var.storage_type == "scratch" ? true : false
  # enable_protocol      = local.storage_instance_count > 0 && local.protocol_instance_count > 0
  # Future use
  # TODO: Fix the logic
  # enable_load_balancer = false
  enable_compute            = true
  enable_management         = true
  ldap_node_name            = format("%s-%s", local.prefix, "ldap")
  login_node_name           = format("%s-%s", local.prefix, "login")
  management_node_name      = format("%s-%s", local.prefix, "mgmt")
  compute_node_name         = format("%s-%s", local.prefix, "comp")
  storage_node_name         = format("%s-%s", local.prefix, "strg")
  protocol_node_name        = format("%s-%s", local.prefix, "proto")

  # Future use
  /*
  management_instance_count     = sum(var.management_instances[*]["count"])
  management_instance_profile   = flatten([for item in var.management_instances: [
    for count in range(item["count"]) : var.management_instances[index(var.management_instances, item)]["profile"]
  ]])
  static_compute_instance_count = sum(var.static_compute_instances[*]["count"])
  storage_instance_count        = sum(var.storage_instances[*]["count"])
  protocol_instance_count       = sum(var.protocol_instances[*]["count"])
  */

  # Future use
  /*
  login_image_name      = var.login_image_name
  management_image_name = var.management_image_name
  compute_image_name    = var.compute_image_name
  storage_image_name    = var.storage_image_name
  protocol_image_name   = var.storage_image_name
  */

  #management_image_id = data.ibm_is_image.management[0].id

  # login_image_id    = data.ibm_is_image.login.id
  #compute_image_id  = data.ibm_is_image.compute[0].id
  # storage_image_id  = data.ibm_is_image.storage.id
  # protocol_image_id = data.ibm_is_image.storage.id

  # storage_ssh_keys    = [for name in var.storage_ssh_keys : data.ibm_is_ssh_key.storage[name].id]
  compute_ssh_keys    = [for name in var.compute_ssh_keys : data.ibm_is_ssh_key.compute[name].id]
  # login_ssh_keys      = [for name in var.login_ssh_keys : data.ibm_is_ssh_key.login[name].id]
  management_ssh_keys = local.compute_ssh_keys
  # protocol_ssh_keys   = local.storage_ssh_keys
  sagar = var.enable_ldap == true && var.ldap_server == "null" ? 1 : 0

  # Future use
  /*
  # Scale static configs
  scale_cloud_deployer_path     = "/opt/IBM/ibm-spectrumscale-cloud-deploy"
  scale_cloud_install_repo_url  = "https://github.com/IBM/ibm-spectrum-scale-cloud-install"
  scale_cloud_install_repo_name = "ibm-spectrum-scale-cloud-install"
  scale_cloud_install_branch    = "5.1.8.1"
  scale_cloud_infra_repo_url    = "https://github.com/IBM/ibm-spectrum-scale-install-infra"
  scale_cloud_infra_repo_name   = "ibm-spectrum-scale-install-infra"
  scale_cloud_infra_repo_tag    = "v2.7.0"
  */

  # Region and Zone calculations
  region = join("-", slice(split("-", var.zones[0]), 0, 2))

  # TODO: DNS configs

  # Security group rules
  login_security_group_rules = [
    {
      name      = "allow-all-bastion"
      direction = "inbound"
      remote    = var.bastion_security_group_id
    },
    {
      name      = "allow-all-compute"
      direction = "inbound"
      remote    = module.compute_sg[0].security_group_id
    },
    {
      name      = "allow-all-bastion"
      direction = "outbound"
      remote    = var.bastion_security_group_id
    },
    {
      name      = "allow-all-compute"
      direction = "outbound"
      remote    = module.compute_sg[0].security_group_id
    }
  ]
  # TODO: Compute & storage can't be added due to SG rule limitation
  /* [ERROR] Error while creating Security Group Rule Exceeded limit of remote rules per security group
  (the limit is 5 remote rules per security group)*/

  compute_security_group_rules = [
    {
      name      = "allow-all-bastion"
      direction = "inbound"
      remote    = var.bastion_security_group_id
    },
    {
      name      = "allow-port-22"
      direction = "inbound"
      remote    = var.bastion_security_group_id
      tcp = {
        port_min = 22
        port_max = 22
      }
    },
    # {
    #   name      = "allow-all-login"
    #   direction = "inbound"
    #   remote    = module.login_sg[0].security_group_id
    # },
    {
      name      = "allow-all-compute"
      direction = "inbound"
      remote    = module.compute_sg[0].security_group_id
    },
    {
      name      = "allow-all-compute-0"
      direction = "inbound"
      remote    = local.compute_subnets[0].cidr
      tcp = {
        port_min = 2049
        port_max = 2049
      }
    },
    {
      name      = "allow-all-compute-1"
      direction = "inbound"
      remote    = local.compute_subnets[1].cidr
      tcp = {
        port_min = 2049
        port_max = 2049
      }
    },
    {
      name      = "allow-all-bastion"
      direction = "outbound"
      remote    = var.bastion_security_group_id
    },
    # {
    #   name      = "allow-all-login"
    #   direction = "outbound"
    #   remote    = module.login_sg[0].security_group_id
    # },
    {
      name      = "allow-all-compute-0"
      direction = "outbound"
      remote    = local.compute_subnets[0].cidr
      tcp = {
        port_min = 2049
        port_max = 2049
      }
    },
    {
      name      = "allow-all-compute-1"
      direction = "outbound"
      remote    = local.compute_subnets[1].cidr
      tcp = {
        port_min = 2049
        port_max = 2049
      }
    },
    {
      name      = "allow-all-outbound"
      direction = "outbound"
      remote    = "0.0.0.0/0"
    },
  ]
  storage_security_group_rules = [
    {
      name      = "allow-all-bastion"
      direction = "inbound"
      remote    = var.bastion_security_group_id
    },
    {
      name      = "allow-all-compute"
      direction = "inbound"
      remote    = module.compute_sg[0].security_group_id
    },
    {
      name      = "allow-all-bastion"
      direction = "outbound"
      remote    = var.bastion_security_group_id
    },
    {
      name      = "allow-all-compute"
      direction = "outbound"
      remote    = module.compute_sg[0].security_group_id
  }]

  # Derived configs
  # VPC
  # resource_group_id = data.ibm_resource_group.itself.id

  # Subnets
  # TODO: Multi-zone multi-vNIC VSIs deployment support (bug #https://github.ibm.com/GoldenEye/issues/issues/5830)
  # Findings: Singe zone multi-vNICs VSIs deployment & multi-zone single vNIC VSIs deployment are supported.
  # login_subnets    = var.login_subnets
  compute_subnets  = var.compute_subnets
  # storage_subnets  = var.storage_subnets
  # protocol_subnets = var.protocol_subnets

  # Sagar code changes

  image_mapping_entry_found = contains(keys(local.image_region_map), var.management_image_name)
  new_image_id              = local.image_mapping_entry_found ? lookup(lookup(local.image_region_map, var.management_image_name), local.region) : "Image not found with the given name"

  // Check whether an entry is found in the mapping file for the given compute node image
  compute_image_mapping_entry_found = contains(keys(local.image_region_map), var.compute_image_name)
  new_compute_image_id              = local.compute_image_mapping_entry_found ? lookup(lookup(local.image_region_map, var.compute_image_name), local.region) : "Image not found with the given name"

  #subnet_list = values(data.ibm_is_subnet.compute)
  compute_node_max_count = 500
  rc_maxNum              = local.compute_node_max_count

  bastion_subnets = var.bastion_subnets
  bastion_ssh_keys = [for name in var.ssh_keys : data.ibm_is_ssh_key.bastion[name].id]
  #ldap_server                  = var.enable_ldap == true && var.ldap_server == "null" ? var.ldap_primary_ip[0] : var.ldap_server
  ldap_server                  = var.enable_ldap == true && var.ldap_server == "null" ? length(module.ldap_vsi) > 0 ? var.ldap_primary_ip[0] : null : var.ldap_server
  ldap_instance_image_id       = var.enable_ldap == true && var.ldap_server == "null" ? data.ibm_is_image.ldap_vsi_image[0].id : "null"
  ldap_server_status           = var.enable_ldap == true && var.ldap_server == "null" ? false : true

  #ldap_server                  = var.enable_ldap == true && var.ldap_server == "null" ? module.ldap_vsi[0].primary_network_interface_address : var.ldap_server
  us-east = "https://hpc-api.us-east.codeengine.cloud.ibm.com/v2"
  eu-de   = "https://hpc-api.eu-de.codeengine.cloud.ibm.com/v2"
  # Security Groups
  # protocol_secondary_security_group = [for subnet in local.protocol_subnets :
  #   {
  #     security_group_id = one(module.compute_sg[*].security_group_id)
  #     interface_name    = subnet["name"]
  #   }
  # ]
}

###########################################################################
# IBM Cloud Dababase for MySQL database local variables
###########################################################################
locals {
  db_name="pac"
  db_user="pacuser"
}
