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
  # Region and Zone calculations
  region = join("-", slice(split("-", var.zones[0]), 0, 2))

  # Check whether an entry is found in the mapping file for the given management node image
  image_mapping_entry_found = contains(keys(local.image_region_map), var.management_instances[0]["image"])
  new_image_id              = local.image_mapping_entry_found ? local.image_region_map[var.management_instances[0]["image"]][local.region] : "Image not found with the given name"

  # Check whether an entry is found in the mapping file for the given compute node image
  compute_image_found_in_map = contains(keys(local.image_region_map), var.static_compute_instances[0]["image"])
  # If not found, assume the name is the id already (customer provided image)
  new_compute_image_id    = local.compute_image_found_in_map ? local.image_region_map[var.static_compute_instances[0]["image"]][local.region] : "Image not found with the given name"

  products                      = var.scheduler == "Scale" ? "scale" : "lsf"
  block_storage_volumes = [for volume in coalesce(var.nsd_details, []) : {
    name           = format("nsd-%s", index(var.nsd_details, volume) + 1)
    profile        = volume["profile"]
    capacity       = volume["capacity"]
    iops           = volume["iops"]
    resource_group = local.resource_group_id
    # TODO: Encryption
    # encryption_key =
  }]
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

  client_instance_count         = sum(var.client_instances[*]["count"])
  management_instance_count     = sum(var.management_instances[*]["count"])
  storage_instance_count        = sum(var.storage_instances[*]["count"])
  protocol_instance_count       = sum(var.protocol_instances[*]["count"])
  static_compute_instance_count = sum(var.static_compute_instances[*]["count"])

  enable_client     = local.client_instance_count > 0
  enable_management = local.management_instance_count > 0
  enable_compute    = local.management_instance_count > 0 || local.static_compute_instance_count > 0
  enable_storage    = local.storage_instance_count > 0
  enable_protocol   = local.storage_instance_count > 0 && local.protocol_instance_count > 0
  # TODO: Fix the logic
  enable_block_storage = var.storage_type == "scratch" ? true : false

  # Future use
  # TODO: Fix the logic
  # enable_load_balancer = false

  client_node_name             = format("%s-%s", local.prefix, "client")
  management_node_name         = format("%s-%s", local.prefix, "mgmt")
  compute_node_name            = format("%s-%s", local.prefix, "comp")
  storage_node_name            = format("%s-%s", local.prefix, "strg")
  protocol_node_name           = format("%s-%s", local.prefix, "proto")
  storage_management_node_name = format("%s-%s", local.prefix, "strg-mgmt")
  ldap_node_name               = format("%s-%s", local.prefix, "ldap")
  afm_node_name                = format("%s-%s", local.prefix, "afm")
  gklm_node_name               = format("%s-%s", local.prefix, "gklm")
  cpmoute_management_node_name = format("%s-%s", local.prefix, "comp-mgmt")

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
  client_image_name     = var.client_image_name
  management_image_name = var.management_image_name
  compute_image_name    = var.compute_image_name
  storage_image_name    = var.storage_image_name
  protocol_image_name   = var.storage_image_name
  */

  management_image_id = data.ibm_is_image.management_stock_image[*].id
  client_image_id     = data.ibm_is_image.client[*].id
  compute_image_id    = data.ibm_is_image.compute_stock_image[*].id
  storage_image_id    = data.ibm_is_image.storage[*].id
  protocol_image_id   = data.ibm_is_image.storage[*].id
  ldap_image_id       = data.ibm_is_image.ldap_vsi_image[*].id
  afm_image_id        = data.ibm_is_image.afm[*].id
  gklm_image_id       = data.ibm_is_image.gklm[*].id

  storage_ssh_keys    = [for name in var.storage_ssh_keys : data.ibm_is_ssh_key.storage[name].id]
  compute_ssh_keys    = [for name in var.compute_ssh_keys : data.ibm_is_ssh_key.compute[name].id]
  client_ssh_keys     = [for name in var.client_ssh_keys : data.ibm_is_ssh_key.client[name].id]
  ldap_ssh_keys       = [for name in var.ldap_instance_key_pair : data.ibm_is_ssh_key.ldap[name].id]
  gklm_ssh_keys       = [for name in var.gklm_instance_key_pair : data.ibm_is_ssh_key.gklm[name].id]
  management_ssh_keys = local.compute_ssh_keys
  protocol_ssh_keys   = local.storage_ssh_keys

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
  # region = join("-", slice(split("-", var.zones[0]), 0, 2))

  # TODO: DNS configs
  # Security group rules
  # client_security_group = local.enable_client ? module.client_sg[0].security_group_id : null
  # compute_security_group = local.enable_compute ? module.compute_sg[0].security_group_id : null
  # storage_security_group = local.enable_storage ? module.storage_sg[0].security_group_id : null

  # client_security_group_remote  = compact([var.bastion_security_group_id])
  # compute_security_group_remote = compact([var.bastion_security_group_id])
  # storage_security_group_remote = compact([var.bastion_security_group_id])

  # client_security_group_rules = flatten([
  #   [for sg in local.client_security_group_remote : {
  #     name      = format("allow-variable-inbound-%s", index(local.client_security_group_remote, sg) + 1)
  #     direction = "inbound"
  #     remote    = sg
  #   }],
  #   [for sg in local.client_security_group_remote : {
  #     name      = format("allow-variable-outbound-%s", index(local.client_security_group_remote, sg) + 1)
  #     direction = "outbound"
  #     remote    = sg
  #   }]
  # ])

  # compute_security_group_rules = flatten([
  #   [for sg in local.compute_security_group_remote : {
  #     name      = format("allow-variable-inbound-%s", index(local.compute_security_group_remote, sg) + 1)
  #     direction = "inbound"
  #     remote    = sg
  #   }],
  #   [for sg in local.compute_security_group_remote : {
  #     name      = format("allow-variable-outbound-%s", index(local.compute_security_group_remote, sg) + 1)
  #     direction = "outbound"
  #     remote    = sg
  #   }]
  # ])

  # storage_security_group_rules = flatten([
  #   [for sg in local.storage_security_group_remote : {
  #     name      = format("allow-variable-inbound-%s", index(local.storage_security_group_remote, sg) + 1)
  #     direction = "inbound"
  #     remote    = sg
  #   }],
  #   [for sg in local.storage_security_group_remote : {
  #     name      = format("allow-variable-outbound-%s", index(local.storage_security_group_remote, sg) + 1)
  #     direction = "outbound"
  #     remote    = sg
  #   }]
  # ])


  client_security_group_rules = [
    {
      name      = "allow-all-bastion-in"
      direction = "inbound"
      remote    = var.bastion_security_group_id
    },
    /*
    {
      name      = "allow-all-compute"
      direction = "inbound"
      remote    = module.compute_sg[0].security_group_id
    },
    */
    {
      name      = "allow-all-bastion-out"
      direction = "outbound"
      remote    = var.bastion_security_group_id
    },
    /*
    {
      name      = "allow-all-compute"
      direction = "outbound"
      remote    = module.compute_sg[0].security_group_id
    }
    */
  ]
  # TODO: Compute & storage can't be added due to SG rule limitation
  /* [ERROR] Error while creating Security Group Rule Exceeded limit of remote rules per security group
  (the limit is 5 remote rules per security group)*/

  compute_security_group_rules = [
    {
      name      = "allow-all-bastion-in"
      direction = "inbound"
      remote    = var.bastion_security_group_id
    },
    /*
    {
      name      = "allow-all-client-in"
      direction = "inbound"
      remote    = module.client_sg[0].security_group_id
    },
    */
    /*
    {
      name      = "allow-all-bastion-out"
      direction = "outbound"
      remote    = var.bastion_security_group_id
    },
    */
    /*
    {
      name      = "allow-all-client-out"
      direction = "outbound"
      remote    = module.client_sg[0].security_group_id
    }
    */
    {
      name      = "allow-all-compute-in"
      direction = "inbound"
      remote    = "0.0.0.0/0"
    },
    {
      name      = "allow-all-compute-out"
      direction = "outbound"
      remote    = "0.0.0.0/0"
    }
  ]
  storage_security_group_rules = [
    {
      name      = "allow-all-bastion-in"
      direction = "inbound"
      remote    = var.bastion_security_group_id
    },
    /*
    {
      name      = "allow-all-compute-in"
      direction = "inbound"
      remote    = module.compute_sg[0].security_group_id
    },
    */
    {
      name      = "allow-all-bastion-out"
      direction = "outbound"
      remote    = var.bastion_security_group_id
    },
    {
      name      = "allow-all-storage-out"
      direction = "outbound"
      remote    = "0.0.0.0/0"
    }
    /*
    {
      name      = "allow-all-compute-out"
      direction = "outbound"
      remote    = module.compute_sg[0].security_group_id
    }
    */
  ]


  # Derived configs
  # VPC
  resource_group_id = data.ibm_resource_group.existing_resource_group.id

  # Subnets
  # TODO: Multi-zone multi-vNIC VSIs deployment support (bug #https://github.ibm.com/GoldenEye/issues/issues/5830)
  # Findings: Singe zone multi-vNICs VSIs deployment & multi-zone single vNIC VSIs deployment are supported.
  client_subnets   = var.client_subnets
  compute_subnets  = var.compute_subnets
  storage_subnets  = var.storage_subnets
  protocol_subnets = var.protocol_subnets

  compute_public_key_content  = one(module.compute_key[*].public_key_content)
  compute_private_key_content = one(module.compute_key[*].private_key_content)

  # Security Groups
  protocol_secondary_security_group = [for subnet in local.protocol_subnets :
    {
      security_group_id = one(module.compute_sg[*].security_group_id)
      interface_name    = subnet["name"]
    }
  ]

  # ldap_instance_image_id = var.enable_ldap == true && var.ldap_server == "null" ? data.ibm_is_image.ldap_vsi_image[0].id : "null"
}
