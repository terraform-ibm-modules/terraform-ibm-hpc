###########################################################################
locals {
  # (overridable) switch to enable extra outputs (debugging)
  print_extra_outputs = false

  # (overridable) switch to add the current (plan execution) IP to allowed CIDR list
  add_current_ip_to_allowed_cidr = false

  # (overridable) list of extra entries for allowed CIDR list
  remote_allowed_ips_extra = []
}

###########################################################################
# Local tweaks support
###########################################################################
# You can enable local tweaks files to customize your local deployment with things
# never intended to be included in the standard code.
# You can use override files to override some values of switches (see above)
# or you can force other values defined in the plan or include extra resources.
#
# See the directory "localtweak_examples" for more.


###########################################################################
###########################################################################
###########################################################################
# locals needed for landing_zone
locals {
  # Region and Zone calculations
  region = join("-", slice(split("-", var.zones[0]), 0, 2))
}

# locals needed for bootstrap
locals {
  # dependency: landing_zone -> bootstrap
  cos_data                   = module.landing_zone[0].cos_buckets_data
  vpc_id                     = var.vpc_name == null ? one(module.landing_zone[0].vpc_id) : data.ibm_is_vpc.itself[0].id
  vpc_cidr                   = join("", module.landing_zone[0].vpc_cidr)
  bastion_subnets            = length(var.cluster_subnet_ids) == 0 ? module.landing_zone[0].bastion_subnets : local.sorted_subnets
  kms_encryption_enabled     = var.key_management == "key_protect" ? true : false
  boot_volume_encryption_key = var.key_management == "key_protect" ? one(module.landing_zone[0].boot_volume_encryption_key)["crn"] : null
  existing_kms_instance_guid = var.key_management == "key_protect" ? module.landing_zone[0].key_management_guid : null
  #  cluster_id                 = local.region == "eu-de" || local.region == "us-east" || local.region == "us-south" ? var.cluster_id : "HPC-LSF-1"
  total_worker_node_count = sum([for node in var.worker_node_instance_type : node.count])
}

# locals needed for landing_zone_vsi
locals {
  bastion_security_group_id   = module.bootstrap[0].bastion_security_group_id
  bastion_public_key_content  = module.bootstrap[0].bastion_public_key_content
  bastion_private_key_content = module.bootstrap[0].bastion_private_key_content
  compute_private_key_content = module.landing_zone_vsi[0].compute_private_key_content

  # dependency: landing_zone -> landing_zone_vsi

  subnets_output = module.landing_zone[0].subnets

  sorted_subnets = length(var.cluster_subnet_ids) != 0 ? [
    element(local.subnets_output, index(local.subnets_output[*].id, var.cluster_subnet_ids[0])),
    element(local.subnets_output, index(local.subnets_output[*].id, var.login_subnet_id))
  ] : []

  sorted_compute_subnets = length(var.cluster_subnet_ids) == 0 ? [
    element(module.landing_zone[0].compute_subnets, index(module.landing_zone[0].compute_subnets[*].zone, var.zones[0]))
  ] : []


  compute_subnets = length(var.cluster_subnet_ids) == 0 ? local.sorted_compute_subnets : local.sorted_subnets
}

# locals needed for file-storage
locals {

  # dependency: landing_zone_vsi -> file-share
  compute_subnet_id         = local.compute_subnets[0].id
  compute_security_group_id = module.landing_zone_vsi[0].compute_sg_id
  management_instance_count = var.management_node_count

  valid_lsf_shares = [
    for share in var.custom_file_shares :
    {
      mount_path = "/mnt/lsf"
      nfs_share  = share.nfs_share
    }
    if share.mount_path == "/mnt/lsf" && share.nfs_share != "" && share.nfs_share != null
  ]

  valid_default_vpc_share = [
    for share in var.custom_file_shares :
    {
      mount_path = "/mnt/lsf"
      size       = share.size
      iops       = share.size
    }
    if share.mount_path == "/mnt/lsf" && share.size != null && share.iops != null
  ]

  default_share = local.management_instance_count > 0 && length(local.valid_lsf_shares) == 0 && length(local.valid_default_vpc_share) == 0 ? [
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
    if share.size != null && share.iops != null && share.mount_path != "/mnt/lsf"
  ]

  total_shares = concat(length(local.valid_default_vpc_share) == 1 ? local.valid_default_vpc_share : local.default_share, local.vpc_file_share)

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
    service_rg  = var.existing_resource_group == "null" ? module.landing_zone[0].resource_group_id[0]["${var.cluster_prefix}-service-rg"] : one(values(one(module.landing_zone[0].resource_group_id)))
    workload_rg = var.existing_resource_group == "null" ? module.landing_zone[0].resource_group_id[0]["${var.cluster_prefix}-workload-rg"] : one(values(one(module.landing_zone[0].resource_group_id)))
  }
  vpc_crn = var.vpc_name == null ? one(module.landing_zone[0].vpc_crn) : one(data.ibm_is_vpc.itself[*].crn)
  # TODO: Fix existing subnet logic
  # subnets_crn         = module.landing_zone.subnets_crn
  compute_subnets_crn = length(var.cluster_subnet_ids) == 0 ? local.sorted_compute_subnets[*].crn : local.sorted_subnets[*].crn
}

# locals needed for dns-records
locals {
  # dependency: dns -> dns-records
  dns_instance_id = module.dns.dns_instance_id
  compute_dns_zone_id = one(flatten([
    for dns_zone in module.dns.dns_zone_maps : values(dns_zone) if one(keys(dns_zone)) == var.dns_domain_name["compute"]
  ]))


  # dependency: landing_zone_vsi -> dns-records
  management_vsi_data   = flatten(module.landing_zone_vsi[0].management_vsi_data)
  management_private_ip = local.management_vsi_data[0]["ipv4_address"]
  management_hostname   = local.management_vsi_data[0]["name"]

  management_candidate_vsi_data    = flatten(module.landing_zone_vsi[0].management_candidate_vsi_data)
  management_candidate_private_ips = local.management_candidate_vsi_data[*]["ipv4_address"]
  management_candidate_hostnames   = local.management_candidate_vsi_data[*]["name"]

  login_vsi_data    = flatten(module.landing_zone_vsi[0].login_vsi_data)
  login_private_ips = local.login_vsi_data[*]["ipv4_address"]
  login_hostnames   = local.login_vsi_data[*]["name"]

  ldap_vsi_data    = flatten(module.landing_zone_vsi[0].ldap_vsi_data)
  ldap_private_ips = local.ldap_vsi_data[*]["ipv4_address"]
  ldap_hostnames   = local.ldap_vsi_data[*]["name"]

  worker_vsi_data    = flatten(module.landing_zone_vsi[0].worker_vsi_data)
  worker_private_ips = local.worker_vsi_data[*]["ipv4_address"]

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
  worker_vsi_dns_records = [
    for instance in local.worker_vsi_data :
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
  worker_inventory_path  = "worker.ini"

  bastion_host = local.bastion_instance_public_ip != null ? [local.bastion_instance_public_ip] : var.enable_fip ? [local.bastion_fip, local.bastion_primary_ip] : [local.bastion_primary_ip, ""]
  login_host   = local.login_private_ips
  ldap_host    = local.ldap_private_ips
  worker_host  = local.worker_private_ips

  cloud_logs_ingress_private_endpoint = module.cloud_monitoring_instance_creation.cloud_logs_ingress_private_endpoint
}

# locals needed for playbook
locals {
  cluster_user       = "lsfadmin"
  login_user         = "ubuntu"
  ldap_user          = "ubuntu"
  bastion_primary_ip = module.bootstrap[0].bastion_primary_ip
  bastion_fip        = module.bootstrap[0].bastion_fip[0]
  bastion_fip_id     = module.bootstrap[0].bastion_fip_id
  no_addr_prefix     = true
}

locals {
  share_path = length(local.valid_lsf_shares) > 0 ? join(", ", local.valid_lsf_shares[*].nfs_share) : module.file_storage.mount_path_1
}

###########################################################################
# IBM Cloud Dababase for MySQL local variables
###########################################################################
locals {
  mysql_version        = "8.0"
  db_service_endpoints = "private"
  db_template          = [3, 12288, 122880, 3, "multitenant"]
}

###########################################################################
# IBM Application Load Balancer variables
###########################################################################

locals {
  # alb_created_by_api:
  # - true -> use ibmcloud API
  # - false -> use ibmcloud terraform provider (not recommended, dramatically slower)
  alb_created_by_api = true
  alb_hostname       = local.alb_created_by_api ? module.alb_api.alb_hostname : module.alb.alb_hostname
}

locals {
  vsi_management_ids = [
    for instance in concat(local.management_vsi_data, local.management_candidate_vsi_data) :
    {
      id = instance["id"]
    }
  ]
}

# locals needed for ssh connection
locals {
  ssh_forward_host = (var.app_center_high_availability ? "pac.${var.dns_domain_name.compute}" : local.management_private_ip)
  ssh_forwards     = "-L 8443:${local.ssh_forward_host}:8443 -L 6080:${local.ssh_forward_host}:6080 -L 8444:${local.ssh_forward_host}:8444"
  ssh_jump_host    = local.bastion_instance_public_ip != null ? local.bastion_instance_public_ip : var.enable_fip ? module.bootstrap[0].bastion_fip[0] : module.bootstrap[0].bastion_primary_ip
  ssh_jump_option  = "-J ubuntu@${local.ssh_jump_host}"
  ssh_cmd          = "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ServerAliveInterval=5 -o ServerAliveCountMax=1 ${local.ssh_forwards} ${local.ssh_jump_option} lsfadmin@${join(",", local.login_private_ips)}"
}

# Existing bastion Variables
locals {
  # bastion_instance_name      = var.bastion_instance_name != null ? var.bastion_instance_name : null
  bastion_instance_public_ip = var.existing_bastion_instance_name != null ? var.existing_bastion_instance_public_ip : null
  # bastion_security_group_id  = var.bastion_instance_name != null ? var.bastion_security_group_id : module.bootstrap.bastion_security_group_id
  bastion_ssh_private_key = var.existing_bastion_instance_name != null ? var.existing_bastion_ssh_private_key : null
  bastion_instance_status = var.existing_bastion_instance_name != null ? false : true
  existing_subnet_cidrs   = var.vpc_name != null && length(var.cluster_subnet_ids) == 1 ? [data.ibm_is_subnet.existing_subnet[0].ipv4_cidr_block, data.ibm_is_subnet.existing_login_subnet[0].ipv4_cidr_block, local.vpc_cidr] : []
}

####################################################
# The code below does some internal processing of variables and locals
# (e.g. concatenating lists).

locals {
  allowed_cidr = concat(var.remote_allowed_ips, local.remote_allowed_ips_extra, local.add_current_ip_to_allowed_cidr ? module.my_ip.my_cidr : [])
}

locals {
  profile_str = split("-", var.worker_node_instance_type[0].instance_type)
  dh_profiles = var.enable_dedicated_host ? [
    for p in data.ibm_is_dedicated_host_profiles.worker[0].profiles : p if p.class == local.profile_str[0]
  ] : []
  dh_profile_index = length(local.dh_profiles) == 0 ? "Profile class ${local.profile_str[0]} for dedicated hosts does not exist in ${local.region}.Check available class with `ibmcloud target -r ${local.region}; ibmcloud is dedicated-host-profiles` and retry with another worker_node_instance_type." : 0
  dh_profile       = var.enable_dedicated_host ? local.dh_profiles[local.dh_profile_index] : null
}
