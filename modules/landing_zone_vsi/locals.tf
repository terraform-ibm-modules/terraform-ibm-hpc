# define variables
locals {
  name           = "hpc"
  prefix         = var.prefix
  tags           = [local.prefix, local.name]
  vsi_interfaces = ["eth0", "eth1"]
  # TODO: explore (DA always keep it true)
  skip_iam_authorization_policy = true
  enable_compute                = true
  enable_management             = true
  ldap_node_name                = format("%s-%s", local.prefix, "ldap")
  login_node_name               = format("%s-%s", local.prefix, "login")
  management_node_name          = format("%s-%s", local.prefix, "mgmt")
  compute_ssh_keys              = [for name in var.compute_ssh_keys : data.ibm_is_ssh_key.compute[name].id]
  management_ssh_keys           = local.compute_ssh_keys
  ldap_enable                   = var.enable_ldap == true && var.ldap_server == "null" ? 1 : 0

  # Region and Zone calculations
  region = join("-", slice(split("-", var.zones[0]), 0, 2))
  # # TODO: Compute & storage can't be added due to SG rule limitation
  /* [ERROR] Error while creating Security Group Rule Exceeded limit of remote rules per security group
  (the limit is 5 remote rules per security group)*/

  compute_security_group_rules = [
    {
      name      = "allow-all-bastion-inbound"
      direction = "inbound"
      remote    = var.bastion_security_group_id
    },
    {
      name      = "allow-port-22-inbound"
      direction = "inbound"
      remote    = var.bastion_security_group_id
      tcp = {
        port_min = 22
        port_max = 22
      }
    },
    {
      name      = "allow-all-compute-inbound"
      direction = "inbound"
      remote    = module.compute_sg[0].security_group_id_for_ref
    },
    {
      name      = "allow-all-compute-0-inbound"
      direction = "inbound"
      remote    = local.compute_subnets[0].cidr
      tcp = {
        port_min = 2049
        port_max = 2049
      }
    },
    {
      name      = "allow-all-storage-inbound"
      direction = "inbound"
      remote    = var.storage_security_group_id != null ? var.storage_security_group_id : module.compute_sg[0].security_group_id_for_ref
    },
    {
      name      = "allow-all-bastion-outbound"
      direction = "outbound"
      remote    = var.bastion_security_group_id
    },
    {
      name      = "allow-all-compute-0-outbound"
      direction = "outbound"
      remote    = local.compute_subnets[0].cidr
      tcp = {
        port_min = 2049
        port_max = 2049
      }
    },
    {
      name      = "allow-all-outbound-outbound"
      direction = "outbound"
      remote    = "0.0.0.0/0"
    },
  ]

  storage_nfs_security_group_rules = [
    {
      name      = "allow-all-hpcaas-compute-sg"
      direction = "inbound"
      remote    = module.compute_sg[0].security_group_id
    }
  ]

  # LDAP security group rule for Cluster
  ldap_security_group_rule_for_cluster = [
    {
      name      = "inbound-rule-for-ldap-node-connection"
      direction = "inbound"
      remote    = var.ldap_server
      tcp = {
        port_min = 389
        port_max = 389
      }
    }
  ]

  # Subnets
  # TODO: Multi-zone multi-vNIC VSIs deployment support (bug #https://github.ibm.com/GoldenEye/issues/issues/5830)
  # Findings: Singe zone multi-vNICs VSIs deployment & multi-zone single vNIC VSIs deployment are supported.
  compute_subnets = var.compute_subnets

  # Check whether an entry is found in the mapping file for the given management node image
  image_mapping_entry_found = contains(keys(local.image_region_map), var.management_image_name)
  new_image_id              = local.image_mapping_entry_found ? local.image_region_map[var.management_image_name][local.region] : "Image not found with the given name"

  # Check whether an entry is found in the mapping file for the given compute node image
  compute_image_found_in_map = contains(keys(local.image_region_map), var.compute_image_name)
  # If not found, assume the name is the id already (customer provided image)
  new_compute_image_id    = local.compute_image_found_in_map ? local.image_region_map[var.compute_image_name][local.region] : var.compute_image_name
  compute_image_from_data = !local.compute_image_found_in_map && !startswith(local.new_compute_image_id, "crn:")

  # Check whether an entry is found in the mapping file for the given login node image
  login_image_mapping_entry_found = contains(keys(local.image_region_map), var.login_image_name)
  new_login_image_id              = local.login_image_mapping_entry_found ? local.image_region_map[var.login_image_name][local.region] : "Image not found with the given name"

  compute_node_max_count = 500
  rc_max_num             = local.compute_node_max_count

  bastion_subnets        = var.bastion_subnets
  bastion_ssh_keys       = [for name in var.ssh_keys : data.ibm_is_ssh_key.bastion[name].id]
  ldap_server            = var.enable_ldap == true && var.ldap_server == "null" ? length(module.ldap_vsi) > 0 ? var.ldap_primary_ip[0] : null : var.ldap_server
  ldap_instance_image_id = var.enable_ldap == true && var.ldap_server == "null" ? data.ibm_is_image.ldap_vsi_image[0].id : "null"

  # The below logic is needed to point the API endpoints for the dynanic host creation
  us_east  = "https://api.us-east.codeengine.cloud.ibm.com/v2beta"
  eu_de    = "https://api.eu-de.codeengine.cloud.ibm.com/v2beta"
  us_south = "https://api.us-south.codeengine.cloud.ibm.com/v2beta"
}

###########################################################################
# IBM Cloud Dababase for MySQL database local variables
###########################################################################
locals {
  db_name = "pac"
  db_user = "pacuser"
}

## Differentiating VPC File Share and NFS share
locals {
  nfs_file_share = [
    for share in var.mount_path :
    {
      mount_path = share.mount_path
      nfs_share  = share.nfs_share
    }
    if share.nfs_share != null && share.nfs_share != ""
  ]

  vpc_file_share = [
    for share in var.mount_path :
    {
      mount_path = share.mount_path
      size       = share.size
      iops       = share.iops
    }
    if share.size != null && share.iops != null
  ]
}
