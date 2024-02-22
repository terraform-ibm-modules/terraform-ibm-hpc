# locals needed for landing_zone
locals {
  # Region and Zone calculations
  region = join("-", slice(split("-", var.zones[0]), 0, 2))
}

# locals needed for bootstrap
locals {
  # dependency: landing_zone -> bootstrap
  vpc_id                     = var.vpc == null ? one(module.landing_zone.vpc_id) : data.ibm_is_vpc.itself[0].id
  vpc_name                   = var.vpc == null ? one(module.landing_zone.vpc_name) : var.vpc
  bastion_subnets            = length(var.subnet_id) == 0 ? module.landing_zone.bastion_subnets : local.sorted_subnets
  public_gateways            = module.landing_zone.public_gateways
  kms_encryption_enabled     = var.key_management == "key_protect" ? true : false
  boot_volume_encryption_key = var.key_management == "key_protect" ? one(module.landing_zone.boot_volume_encryption_key)["crn"] : null
  existing_kms_instance_guid = var.key_management == "key_protect" ? module.landing_zone.key_management_guid : null
  # bastion_node_name   = format("%s-%s", var.prefix, "bastion")
  # bastion_fip_name = "${local.bastion_node_name}-001-fip"
  # Future use
  # skip_iam_authorization_policy = true
}

# locals needed for landing_zone_vsi
locals {
  # ssh_key_list = split(",", var.ssh_key_name)
  # ssh_key_id_list = [
  #   for name in local.ssh_key_list :
  #   data.ibm_is_ssh_key.ssh_key[name].id
  # ]
  # dependency: landing_zone -> bootstrap -> landing_zone_vsi
  bastion_security_group_id   = module.bootstrap.bastion_security_group_id
  bastion_public_key_content  = module.bootstrap.bastion_public_key_content
  bastion_private_key_content = module.bootstrap.bastion_private_key_content
  compute_private_key_content = module.landing_zone_vsi.compute_private_key_content

  # dependency: landing_zone -> landing_zone_vsi

  subnets_output = module.landing_zone.subnets

  sorted_subnets = length(var.subnet_id) != 0 ? [
    element(local.subnets_output, index(local.subnets_output[*].id, var.subnet_id[0])),
    element(local.subnets_output, index(local.subnets_output[*].id, var.subnet_id[1])),
    element(local.subnets_output, index(local.subnets_output[*].id, var.login_subnet_id))
  ] : []

  login_subnets    = length(var.subnet_id) == 0 ? module.landing_zone.login_subnets : local.sorted_subnets
  compute_subnets  = length(var.subnet_id) == 0 ? module.landing_zone.compute_subnets : local.sorted_subnets
  storage_subnets  = length(var.subnet_id) == 0 ? module.landing_zone.storage_subnets : local.sorted_subnets
  protocol_subnets = length(var.subnet_id) == 0 ? module.landing_zone.protocol_subnets : local.sorted_subnets

  #boot_volume_encryption_key = var.key_management != null ? one(module.landing_zone.boot_volume_encryption_key)["crn"] : null
  #skip_iam_authorization_policy = true
  #resource_group_id = data.ibm_resource_group.itself.id
  #vpc_id            = var.vpc == null ? module.landing_zone.vpc_id[0] : data.ibm_is_vpc.itself[0].id
  #vpc_crn           = var.vpc == null ? module.landing_zone.vpc_crn[0] : data.ibm_is_vpc.itself[0].crn
}

# locals needed for file-storage
locals {
  # dependency: landing_zone -> file-storage
  #vpc_id                        = var.vpc == null ? one(module.landing_zone.vpc_id) : var.vpc
  #boot_volume_encryption_key    = var.key_management != null ? one(module.landing_zone.boot_volume_encryption_key)["crn"] : null

  # dependency: landing_zone_vsi -> file-share
  compute_subnet_id         = local.compute_subnets[0].id
  compute_security_group_id = module.landing_zone_vsi.compute_sg_id
  management_instance_count = var.management_node_count
  # management_instance_count = sum(var.management_instances[*]["count"])
  default_share = local.management_instance_count > 0 ? [
    {
      mount_path = "/mnt/lsf"
      size       = 100
      iops       = 1000
    }
  ] : []

  # storage_instance_count = sum(var.storage_instances[*]["count"])
  total_shares = concat(local.default_share, var.file_shares)
  # total_shares = 10
  file_shares = [
    for count in range(length(local.total_shares)) :
    {
      name = format("%s-%s", var.prefix, element(split("/", local.total_shares[count]["mount_path"]), length(split("/", local.total_shares[count]["mount_path"])) - 1))
      size = local.total_shares[count]["size"]
      iops = local.total_shares[count]["iops"]
    }
  ]
}

# locals needed for DNS
locals {
  # dependency: landing_zone -> DNS
  # resource_group_id = one(values(one(module.landing_zone.resource_group_id)))
  resource_groups = {
    # management_rg = var.resource_group == null ? module.landing_zone.resource_group_id[0]["management-rg"] : one(values(one(module.landing_zone.resource_group_id)))
    service_rg  = var.resource_group == null ? module.landing_zone.resource_group_id[0]["service-rg"] : one(values(one(module.landing_zone.resource_group_id)))
    workload_rg = var.resource_group == null ? module.landing_zone.resource_group_id[0]["workload-rg"] : one(values(one(module.landing_zone.resource_group_id)))
  }
  vpc_crn = var.vpc == null ? one(module.landing_zone.vpc_crn) : one(data.ibm_is_vpc.itself[*].crn)
  # TODO: Fix existing subnet logic
  #subnets_crn       = var.vpc == null ? module.landing_zone.subnets_crn : ###
  #subnets           = flatten([local.compute_subnets, local.storage_subnets, local.protocol_subnets])
  #subnets_crns      = data.ibm_is_subnet.itself[*].crn
  subnets_crn         = module.landing_zone.subnets_crn
  compute_subnets_crn = length(var.subnet_id) == 0 ? module.landing_zone.compute_subnets[*].crn : local.sorted_subnets[*].crn
  #boot_volume_encryption_key    = var.key_management != null ? one(module.landing_zone.boot_volume_encryption_key)["crn"] : null

  # dependency: landing_zone_vsi -> file-share
}

# locals needed for dns-records
locals {
  # dependency: dns -> dns-records
  dns_instance_id = module.dns.dns_instance_id
  compute_dns_zone_id = one(flatten([
    for dns_zone in module.dns.dns_zone_maps : values(dns_zone) if one(keys(dns_zone)) == var.dns_domain_names["compute"]
  ]))
  /*  storage_dns_zone_id = one(flatten([
    for dns_zone in module.dns.dns_zone_maps : values(dns_zone) if one(keys(dns_zone)) == var.dns_domain_names["storage"]
  ]))
  protocol_dns_zone_id = one(flatten([
    for dns_zone in module.dns.dns_zone_maps : values(dns_zone) if one(keys(dns_zone)) == var.dns_domain_names["protocol"]
  ]))*/

  # dependency: landing_zone_vsi -> dns-records
  # compute_instances         = flatten([module.landing_zone_vsi.management_vsi_data, module.landing_zone_vsi.compute_vsi_data])
  compute_instances = flatten([module.landing_zone_vsi.management_vsi_data])
  #compute_instances         = flatten([module.landing_zone_vsi.management_vsi_data, module.landing_zone_vsi.management_candidate_vsi_data])
  # management_instances_data = flatten([module.landing_zone_vsi.management_vsi_data])

  management_private_ip = local.compute_instances[0]["ipv4_address"]

  management_candidate_vsi_data    = flatten([module.landing_zone_vsi.management_candidate_vsi_data])
  management_candidate_private_ips = local.management_candidate_vsi_data[*]["ipv4_address"]

  login_vsi_data    = flatten([module.landing_zone_vsi.login_vsi_data])
  login_private_ips = local.login_vsi_data[*]["ipv4_address"]

  ldap_vsi_data    = flatten([module.landing_zone_vsi.ldap_vsi_data])
  ldap_private_ips = local.ldap_vsi_data[*]["ipv4_address"]
  # storage_instances         = flatten([module.landing_zone_vsi.storage_vsi_data, module.landing_zone_vsi.protocol_vsi_data])
  # protocol_instances        = flatten([module.landing_zone_vsi.protocol_vsi_data])

  compute_dns_records = [
    for instance in local.compute_instances :
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

  # storage_dns_records = [
  #   for instance in local.storage_instances :
  #   {
  #     name  = instance["name"]
  #     rdata = instance["ipv4_address"]
  #   }
  # ]
  # protocol_dns_records = [
  #   for instance in local.protocol_instances :
  #   {
  #     name  = instance["name"]
  #     rdata = instance["ipv4_address"]
  #   }
  # ]
}

# locals needed for inventory
locals {
  compute_hosts = concat(local.compute_instances[*]["ipv4_address"], local.management_candidate_vsi_data[*]["ipv4_address"])
  # storage_hosts          = local.storage_instances[*]["ipv4_address"]
  compute_inventory_path = "compute.ini"
  bastion_inventory_path = "bastion.ini"
  login_inventory_path   = "login.ini"
  ldap_inventory_path    = "ldap.ini"

  bastion_host = var.enable_fip ? [local.bastion_fip, local.bastion_primary_ip] : [local.bastion_primary_ip]
  login_host   = local.login_private_ips
  ldap_host    = local.ldap_private_ips
  # storage_inventory_path = "storage.ini"
}

# locals needed for playbook
locals {
  cluster_user             = "lsfadmin"
  login_user               = "vpcuser"
  ldap_user                = "ubuntu"
  bastion_primary_ip       = module.bootstrap.bastion_primary_ip
  bastion_fip              = module.bootstrap.bastion_fip
  bastion_fip_id           = module.bootstrap.bastion_fip_id
  compute_private_key_path = "compute_id_rsa" #checkov:skip=CKV_SECRET_6
  storage_private_key_path = "storage_id_rsa" #checkov:skip=CKV_SECRET_6
  # compute_playbook_path    = "compute_ssh.yaml"
  # storage_playbook_path    = "storage_ssh.yaml"
}

locals {
  share_path = module.file_storage.mount_path_1
}

###########################################################################
# IBM Cloud Dababase for MySQL local variables
###########################################################################
locals {
  db_plan              = "standard"
  db_service_endpoints = "private"
}
