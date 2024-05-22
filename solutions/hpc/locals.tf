# locals needed for landing_zone
locals {
  # Region and Zone calculations
  region = join("-", slice(split("-", var.zones[0]), 0, 2))
}

# locals needed for bootstrap
locals {
  # dependency: landing_zone -> bootstrap
  vpc_id                     = var.vpc_name == "null" ? one(module.landing_zone.vpc_id) : data.ibm_is_vpc.itself[0].id
  bastion_subnets            = length(var.cluster_subnet_ids) == 0 ? module.landing_zone.bastion_subnets : local.sorted_subnets
  kms_encryption_enabled     = var.key_management == "key_protect" ? true : false
  boot_volume_encryption_key = var.key_management == "key_protect" ? one(module.landing_zone.boot_volume_encryption_key)["crn"] : null
  existing_kms_instance_guid = var.key_management == "key_protect" ? module.landing_zone.key_management_guid : null
  cluster_id                 = local.region == "eu-de" || local.region == "us-east" || local.region == "us-south" ? var.cluster_id : "HPC-LSF-1"
}

# locals needed for landing_zone_vsi
locals {
  bastion_security_group_id   = module.bootstrap.bastion_security_group_id
  bastion_public_key_content  = module.bootstrap.bastion_public_key_content
  bastion_private_key_content = module.bootstrap.bastion_private_key_content
  compute_private_key_content = module.landing_zone_vsi.compute_private_key_content

  # dependency: landing_zone -> landing_zone_vsi

  subnets_output = module.landing_zone.subnets

  sorted_subnets = length(var.cluster_subnet_ids) != 0 ? [
    element(local.subnets_output, index(local.subnets_output[*].id, var.cluster_subnet_ids[0])),
    element(local.subnets_output, index(local.subnets_output[*].id, var.login_subnet_id))
  ] : []

  sorted_compute_subnets = length(var.cluster_subnet_ids) == 0 ? [
    element(module.landing_zone.compute_subnets, index(module.landing_zone.compute_subnets[*].zone, var.zones[0]))
  ] : []


  compute_subnets = length(var.cluster_subnet_ids) == 0 ? local.sorted_compute_subnets : local.sorted_subnets
}

# locals needed for file-storage
locals {

  # dependency: landing_zone_vsi -> file-share
  compute_subnet_id         = local.compute_subnets[0].id
  compute_security_group_id = module.landing_zone_vsi.compute_sg_id
  management_instance_count = var.management_node_count
  default_share = local.management_instance_count > 0 ? [
    {
      mount_path = "/mnt/lsf"
      size       = 100
      iops       = 1000
    }
  ] : []

  vpc_file_share = [
    for share in var.custom_file_shares :
    {
      mount_path = share.mount_path
      size       = share.size
      iops       = share.iops
    }
    if share.size != null && share.iops != null
  ]

  total_shares = concat(local.default_share, local.vpc_file_share)

  # total_shares = 10
  file_shares = [
    for count in range(length(local.total_shares)) :
    {
      name = format("%s-%s", var.cluster_prefix, element(split("/", local.total_shares[count]["mount_path"]), length(split("/", local.total_shares[count]["mount_path"])) - 1))
      size = local.total_shares[count]["size"]
      iops = local.total_shares[count]["iops"]
    }
  ]
}

# locals needed for DNS
locals {
  # dependency: landing_zone -> DNS
  resource_groups = {
    service_rg  = var.resource_group == "null" ? module.landing_zone.resource_group_id[0]["service-rg"] : one(values(one(module.landing_zone.resource_group_id)))
    workload_rg = var.resource_group == "null" ? module.landing_zone.resource_group_id[0]["workload-rg"] : one(values(one(module.landing_zone.resource_group_id)))
  }
  vpc_crn = var.vpc_name == "null" ? one(module.landing_zone.vpc_crn) : one(data.ibm_is_vpc.itself[*].crn)
  # TODO: Fix existing subnet logic
  # subnets_crn         = module.landing_zone.subnets_crn
  compute_subnets_crn = length(var.cluster_subnet_ids) == 0 ? local.sorted_compute_subnets[*].crn : local.sorted_subnets[*].crn
}

# locals needed for dns-records
locals {
  # dependency: dns -> dns-records
  dns_instance_id = module.dns.dns_instance_id
  compute_dns_zone_id = one(flatten([
    for dns_zone in module.dns.dns_zone_maps : values(dns_zone) if one(keys(dns_zone)) == var.dns_domain_names["compute"]
  ]))


  # dependency: landing_zone_vsi -> dns-records
  management_vsi_data   = flatten(module.landing_zone_vsi.management_vsi_data)
  management_private_ip = local.management_vsi_data[0]["ipv4_address"]
  #management_hostname   = local.management_vsi_data[0]["name"]

  management_candidate_vsi_data    = flatten(module.landing_zone_vsi.management_candidate_vsi_data)
  management_candidate_private_ips = local.management_candidate_vsi_data[*]["ipv4_address"]
  #management_candidate_hostnames   = local.management_candidate_vsi_data[*]["name"]

  login_vsi_data    = flatten(module.landing_zone_vsi.login_vsi_data)
  login_private_ips = local.login_vsi_data[*]["ipv4_address"]
  #login_hostnames   = local.login_vsi_data[*]["name"]

  ldap_vsi_data    = flatten(module.landing_zone_vsi.ldap_vsi_data)
  ldap_private_ips = local.ldap_vsi_data[*]["ipv4_address"]
  #ldap_hostnames   = local.ldap_vsi_data[*]["name"]

  compute_dns_records = [
    for instance in local.management_vsi_data :
    {
      name  = instance["name"]
      rdata = instance["ipv4_address"]
    }
  ]
  mgmt_candidate_dns_records = [
    for instance in local.management_candidate_vsi_data :
    {
      name  = instance["name"]
      rdata = instance["ipv4_address"]
    }
  ]
  login_vsi_dns_records = [
    for instance in local.login_vsi_data :
    {
      name  = instance["name"]
      rdata = instance["ipv4_address"]
    }
  ]
  ldap_vsi_dns_records = [
    for instance in local.ldap_vsi_data :
    {
      name  = instance["name"]
      rdata = instance["ipv4_address"]
    }
  ]
}

# locals needed for inventory
locals {
  compute_hosts          = concat(local.management_vsi_data[*]["ipv4_address"], local.management_candidate_vsi_data[*]["ipv4_address"])
  compute_inventory_path = "compute.ini"
  bastion_inventory_path = "bastion.ini"
  login_inventory_path   = "login.ini"
  ldap_inventory_path    = "ldap.ini"

  bastion_host = local.bastion_instance_public_ip != null ? [local.bastion_instance_public_ip] : var.enable_fip ? [local.bastion_fip, local.bastion_primary_ip] : [local.bastion_primary_ip, ""]
  login_host   = local.login_private_ips
  ldap_host    = local.ldap_private_ips
}

# locals needed for playbook
locals {
  cluster_user       = "lsfadmin"
  login_user         = "ubuntu"
  ldap_user          = "ubuntu"
  bastion_primary_ip = module.bootstrap.bastion_primary_ip
  bastion_fip        = module.bootstrap.bastion_fip[0]
  bastion_fip_id     = module.bootstrap.bastion_fip_id
  no_addr_prefix     = true
}

locals {
  share_path = module.file_storage.mount_path_1
}

###########################################################################
# IBM Cloud Dababase for MySQL local variables
###########################################################################
locals {
  mysql_version        = "8.0"
  db_service_endpoints = "private"
  db_template          = [3, 12288, 122880, 3]
}

###########################################################################
# IBM Application Load Balancer variables
###########################################################################

locals {
  alb_hostname = module.alb.alb_hostname
}

locals {
  vsi_management_ids = [
    for instance in concat(local.management_candidate_vsi_data, local.management_vsi_data) :
    {
      id = instance["id"]
    }
  ]
}

# locals needed for ssh connection
locals {
  ssh_forward_host = (var.app_center_high_availability ? "pac.${var.dns_domain_names.compute}" : "localhost")
  ssh_forwards     = "-L 8443:${local.ssh_forward_host}:8443 -L 6080:${local.ssh_forward_host}:6080"
  ssh_jump_host    = local.bastion_instance_public_ip != null ? local.bastion_instance_public_ip : var.enable_fip ? module.bootstrap.bastion_fip[0] : module.bootstrap.bastion_primary_ip
  ssh_jump_option  = "-J ubuntu@${local.ssh_jump_host}"
  ssh_host         = var.app_center_high_availability ? local.login_private_ips[0] : local.management_private_ip
  ssh_cmd          = "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ServerAliveInterval=5 -o ServerAliveCountMax=1 ${local.ssh_forwards} ${local.ssh_jump_option} lsfadmin@${local.ssh_host}"
}

# Existing bastion Variables
locals {
  bastion_instance_name      = var.bastion_instance_name != "null" ? var.bastion_instance_name : null
  bastion_instance_public_ip = var.bastion_instance_name != "null" ? var.bastion_instance_public_ip : null
  # bastion_security_group_id  = var.bastion_instance_name != "null" ? var.bastion_security_group_id : module.bootstrap.bastion_security_group_id
  bastion_ssh_private_key = var.bastion_instance_name != "null" ? var.bastion_ssh_private_key : null
  bastion_instance_status = var.bastion_instance_name != "null" ? false : true

  # NFS Mount security group
  storage_security_group_id = var.storage_security_group_id != "null" ? var.storage_security_group_id : null

  existing_subnet_cidrs = var.vpc_name != "null" && length(var.cluster_subnet_ids) == 1 ? [data.ibm_is_subnet.existing_subnet[0].ipv4_cidr_block, data.ibm_is_subnet.existing_login_subnet[0].ipv4_cidr_block] : []
}
