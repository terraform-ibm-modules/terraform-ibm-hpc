# define variables
locals {
  #products = "scale"
  name   = "hpc"
  prefix = var.prefix
  tags   = [local.prefix, local.name]

  schematics_reserved_cidrs = [
    "169.44.0.0/14",
    "169.60.0.0/14",
    "158.175.0.0/16",
    "158.176.0.0/15",
    "141.125.0.0/16",
    "161.156.0.0/16",
    "149.81.0.0/16",
    "159.122.111.224/27",
    "150.238.230.128/27",
    "169.55.82.128/27"
  ]
  bastion_sg_variable_cidr = var.enable_deployer == false ? distinct(flatten([
    local.schematics_reserved_cidrs,
    var.allowed_cidr,
    var.network_cidr
  ])) : distinct(flatten([var.allowed_cidr, var.network_cidr]))

  enable_bastion  = var.enable_bastion || var.enable_deployer
  enable_deployer = var.enable_deployer

  bastion_fip = one(module.bastion_vsi[*]["fip_list"][0]["floating_ip"])

  bastion_node_name  = format("%s-%s", local.prefix, "bastion")
  deployer_node_name = format("%s-%s", local.prefix, "deployer")

  bastion_image_id  = data.ibm_is_image.bastion.id
  deployer_image_id = data.ibm_is_image.deployer.id

  bastion_ssh_keys = [for name in var.ssh_keys : data.ibm_is_ssh_key.bastion[name].id]

  # Scale static configs
  scale_cloud_deployer_path   = "/opt/IBM/ibm-spectrumscale-cloud-deploy"
  scale_cloud_infra_repo_url  = "https://github.com/IBM/ibm-spectrum-scale-install-infra"
  scale_cloud_infra_repo_name = "ibm-spectrum-scale-install-infra"
  scale_cloud_infra_repo_tag  = "ibmcloud_v2.6.0"

  # LSF static configs
  lsf_cloud_deployer_path = "/opt/ibm/lsf"

  # Region and Zone calculations
  region = join("-", slice(split("-", var.zones[0]), 0, 2))

  # Security group rules
  # TODO: Fix SG rules
  bastion_security_group_rules = flatten([
    [for cidr in local.bastion_sg_variable_cidr : {
      name      = format("allow-variable-inbound-%s", index(local.bastion_sg_variable_cidr, cidr) + 1)
      direction = "inbound"
      remote    = cidr
      # ssh port
      tcp = {
        port_min = 22
        port_max = 22
      }
    }],
    [for cidr in concat(local.bastion_sg_variable_cidr, ["0.0.0.0/0"]) : {
      name      = format("allow-variable-outbound-%s", index(concat(local.bastion_sg_variable_cidr, ["0.0.0.0/0"]), cidr) + 1)
      direction = "outbound"
      remote    = cidr
    }]
  ])

  # Derived configs
  # VPC
  resource_group_id = data.ibm_resource_group.itself.id

  # Subnets
  bastion_subnets = var.bastion_subnets
}

locals {
  vsi_interfaces     = ["eth0", "eth1"]
  compute_interfaces = local.vsi_interfaces[0]
  compute_dns_domain = var.dns_domain_names["compute"]

  management_instance_count     = sum(var.management_instances[*]["count"])
  static_compute_instance_count = sum(var.static_compute_instances[*]["count"])
  enable_compute                = local.management_instance_count > 0 || local.static_compute_instance_count > 0
}

locals {

  compute_public_key_contents  = one(module.compute_key[*].public_key_content)
  compute_private_key_contents = one(module.compute_key[*].private_key_content)

  bastion_public_key_content  = one(module.ssh_key[*].public_key_content)
  bastion_private_key_content = one(module.ssh_key[*].private_key_content)

  bastion_security_group_id = one(module.bastion_sg[*].security_group_id)

  deployer_hostname = var.enable_bastion ? flatten(module.deployer_vsi[*].list)[0].name : ""
  deployer_ip       = one(module.deployer_vsi[*]["list"][0]["ipv4_address"])
  # SSH key calculations
  # Combining the common ssh keys with host specific ssh keys
  storage_ssh_keys = distinct(concat(coalesce(var.storage_ssh_keys, []), coalesce(var.ssh_keys, [])))
  compute_ssh_keys = distinct(concat(coalesce(var.compute_ssh_keys, []), coalesce(var.ssh_keys, [])))

  # Existing subnets details
  # existing_compute_subnets = [
  #   for subnet in data.ibm_is_subnet.existing_compute_subnets :
  #   {
  #     cidr = subnet.ipv4_cidr_block
  #     id   = subnet.id
  #     name = subnet.name
  #     zone = subnet.zone
  #   }
  # ]

  # existing_storage_subnets = [
  #   for subnet in data.ibm_is_subnet.existing_storage_subnets :
  #   {
  #     cidr = subnet.ipv4_cidr_block
  #     id   = subnet.id
  #     name = subnet.name
  #     zone = subnet.zone
  #   }
  # ]

  # existing_protocol_subnets = [
  #   for subnet in data.ibm_is_subnet.existing_protocol_subnets :
  #   {
  #     cidr = subnet.ipv4_cidr_block
  #     id   = subnet.id
  #     name = subnet.name
  #     zone = subnet.zone
  #   }
  # ]

  # existing_client_subnets = [
  #   for subnet in data.ibm_is_subnet.existing_client_subnets :
  #   {
  #     cidr = subnet.ipv4_cidr_block
  #     id   = subnet.id
  #     name = subnet.name
  #     zone = subnet.zone
  #   }
  # ]

  # existing_bastion_subnets = [
  #   for subnet in data.ibm_is_subnet.existing_bastion_subnets :
  #   {
  #     cidr = subnet.ipv4_cidr_block
  #     id   = subnet.id
  #     name = subnet.name
  #     zone = subnet.zone
  #   }
  # ]

  # # dependency: landing_zone -> landing_zone_vsi
  # client_subnets   = var.vpc != null && var.client_subnets != null ? local.existing_client_subnets : module.landing_zone.client_subnets
  # compute_subnets  = var.vpc != null && var.compute_subnets != null ? local.existing_compute_subnets : module.landing_zone.compute_subnets
  # storage_subnets  = var.vpc != null && var.storage_subnets != null ? local.existing_storage_subnets : module.landing_zone.storage_subnets
  # protocol_subnets = var.vpc != null && var.protocol_subnets != null ? local.existing_protocol_subnets : module.landing_zone.protocol_subnets

  # storage_subnet  = [for subnet in var.storage_subnets : subnet.name]
  # protocol_subnet = [for subnet in var.protocol_subnets : subnet.name]
  # compute_subnet  = [for subnet in var.compute_subnets : subnet.name]
  # client_subnet   = [for subnet in var.client_subnets : subnet.name]
  # bastion_subnet  = [for subnet in var.bastion_subnets : subnet.name]

  #boot_volume_encryption_key = var.key_management != null ? one(module.landing_zone.boot_volume_encryption_key)["crn"] : null
  #skip_iam_authorization_policy = true
  #resource_group_id = data.ibm_resource_group.itself.id
  #vpc_id            = var.vpc == null ? module.landing_zone.vpc_id[0] : data.ibm_is_vpc.itself[0].id
  #vpc_crn           = var.vpc == null ? module.landing_zone.vpc_crn[0] : data.ibm_is_vpc.itself[0].crn
}


locals {
  schematics_inputs_path      = "/tmp/.schematics/solution_terraform.auto.tfvars.json"
  remote_inputs_path          = format("%s/terraform.tfvars.json", "/tmp")
  deployer_path               = "/opt/ibm"
  remote_terraform_path       = format("%s/terraform-ibm-hpc", local.deployer_path)
  remote_ansible_path         = format("%s/terraform-ibm-hpc", local.deployer_path)
  da_hpc_repo_url             = "https://github.com/terraform-ibm-modules/terraform-ibm-hpc.git"
  da_hpc_repo_tag             = "develop" ###### change it to main in future
  zones                       = jsonencode(var.zones)
  list_compute_ssh_keys       = jsonencode(local.compute_ssh_keys)
  list_storage_ssh_keys       = jsonencode(local.storage_ssh_keys)
  list_storage_instances      = jsonencode(var.storage_instances)
  list_management_instances   = jsonencode(var.management_instances)
  list_protocol_instances     = jsonencode(var.protocol_instances)
  list_compute_instances      = jsonencode(var.static_compute_instances)
  list_client_instances       = jsonencode(var.client_instances)
  allowed_cidr                = jsonencode(var.allowed_cidr)
  list_storage_subnets        = jsonencode(length(var.storage_subnets) == 0 ? null : var.storage_subnets)
  list_protocol_subnets       = jsonencode(length(var.protocol_subnets) == 0 ? null : var.protocol_subnets)
  list_compute_subnets        = jsonencode(length(var.compute_subnets) == 0 ? null : var.compute_subnets)
  list_client_subnets         = jsonencode(length(var.client_subnets) == 0 ? null : var.client_subnets)
  list_bastion_subnets        = jsonencode(length(var.bastion_subnets) == 0 ? null : var.bastion_subnets)
  dns_domain_names            = jsonencode(var.dns_domain_names)
  compute_public_key_content  = local.compute_public_key_contents != null ? jsonencode(base64encode(local.compute_public_key_contents)) : ""
  compute_private_key_content = local.compute_private_key_contents != null ? jsonencode(base64encode(local.compute_private_key_contents)) : ""
}