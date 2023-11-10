# define variables
locals {
  #products = "scale"
  name   = "hpc"
  prefix = var.prefix
  tags   = [local.prefix, local.name]

  bootstrap_node_name = format("%s-%s", local.prefix, "bootstrap")
  bootstrap_image_name = "ibm-redhat-8-6-minimal-amd64-6"
  bootstrap_image_id = data.ibm_is_image.bootstrap.id

  # Region and Zone calculations
  region = join("-", slice(split("-", var.zones[0]), 0, 2))

  # Derived configs
  # VPC
  resource_group_id = data.ibm_resource_group.itself.id

  # Subnets
  bastion_subnets = var.bastion_subnets
}
