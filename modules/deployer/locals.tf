# define variables
locals {
  name   = var.scheduler == "LSF" ? "LSF" : (var.scheduler == "Scale" ? "Scale" : (var.scheduler == "HPCaaS" ? "HPCaaS" : (var.scheduler == "Symphony" ? "Symphony" : (var.scheduler == "Slurm" ? "Slurm" : ""))))
  prefix = var.prefix
  tags   = [local.prefix, local.name]
  region = join("-", slice(split("-", var.zones[0]), 0, 2))

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
  bastion_sg_variable_cidr = distinct(flatten([
    local.schematics_reserved_cidrs,
    var.allowed_cidr,
    var.cluster_cidr
  ]))

  enable_deployer = var.enable_deployer

  bastion_node_name  = format("%s-%s", local.prefix, "bastion")
  deployer_node_name = format("%s-%s", local.prefix, "deployer")

  bastion_image_id = data.ibm_is_image.bastion.id

  # deployer_image_id = data.ibm_is_image.deployer[0].id
  # Check whether an entry is found in the mapping file for the given deployer node image
  deployer_image_found_in_map = contains(keys(local.image_region_map), var.deployer_instance["image"])
  # If not found, assume the name is the id already (customer provided image)
  new_deployer_image_id = local.deployer_image_found_in_map ? local.image_region_map[var.deployer_instance["image"]][local.region] : "Image not found with the given name"

  bastion_ssh_keys = [for name in var.ssh_keys : data.ibm_is_ssh_key.bastion[name].id]

  # Scale static configs
  # scale_cloud_deployer_path   = "/opt/IBM/ibm-spectrumscale-cloud-deploy"
  # scale_cloud_infra_repo_url  = "https://github.com/IBM/ibm-spectrum-scale-install-infra"
  # scale_cloud_infra_repo_name = "ibm-spectrum-scale-install-infra"
  # scale_cloud_infra_repo_tag  = "ibmcloud_v2.6.0"

  # LSF static configs
  # lsf_cloud_deployer_path = "/opt/ibm/lsf"

  # Security group rules
  # TODO: Fix SG rules
  bastion_security_group_rules = flatten([
    [for cidr in local.bastion_sg_variable_cidr : {
      name      = format("allow-variable-inbound-%s", index(local.bastion_sg_variable_cidr, cidr) + 1)
      direction = "inbound"
      remote    = cidr
    }],

    # Conditional SG ID inbound rule (added only if condition is met)
    var.existing_bastion_security_group_id != null ? [{
      name      = "allow-sg-id-inbound"
      direction = "inbound"
      remote    = var.existing_bastion_security_group_id # The source security group ID
    }] : [],

    [for cidr in concat(local.bastion_sg_variable_cidr, ["0.0.0.0/0"]) : {
      name      = format("allow-variable-outbound-%s", index(concat(local.bastion_sg_variable_cidr, ["0.0.0.0/0"]), cidr) + 1)
      direction = "outbound"
      remote    = cidr
    }]
  ])

  # Derived configs
  # VPC
  # resource_group_id = data.ibm_resource_group.existing_resource_group.id

  # Subnets
  bastion_subnets              = var.bastion_subnets
  login_security_group_name_id = var.login_security_group_name != null ? data.ibm_is_security_group.login_security_group[*].id : []
}

locals {
  vsi_interfaces     = ["eth0", "eth1"]
  compute_interfaces = local.vsi_interfaces[0]
  compute_dns_domain = var.dns_domain_names["compute"]
}

locals {
  public_gateways_list = var.ext_vpc_name != null ? data.ibm_is_public_gateways.public_gateways[0].public_gateways : []
  zone_1_pgw_ids       = var.ext_vpc_name != null ? [for gateway in local.public_gateways_list : gateway.id if gateway.vpc == var.vpc_id && gateway.zone == var.zones[0]] : []
}
