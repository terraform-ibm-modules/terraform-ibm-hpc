# define variables
locals {
  name   = var.scheduler == "LSF" ? "LSF" : (var.scheduler == null ? "Scale" : (var.scheduler == "HPCaaS" ? "HPCaaS" : (var.scheduler == "Symphony" ? "Symphony" : (var.scheduler == "Slurm" ? "Slurm" : ""))))
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

  bastion_node_name  = format("%s-%s", local.prefix, "bastion")
  deployer_node_name = format("%s-%s", local.prefix, "deployer")

  bastion_image_id  = data.ibm_is_image.bastion.id
  deployer_image_id = data.ibm_is_image.deployer.id

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
  resource_group_id = data.ibm_resource_group.existing_resource_group.id

  # Subnets
  bastion_subnets = var.bastion_subnets
}

locals {
  vsi_interfaces     = ["eth0", "eth1"]
  compute_interfaces = local.vsi_interfaces[0]
  compute_dns_domain = var.dns_domain_names["compute"]
}
