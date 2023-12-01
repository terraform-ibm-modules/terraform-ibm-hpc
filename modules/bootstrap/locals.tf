# define variables
locals {
  #products = "scale"
  name   = "hpc"
  prefix = var.prefix
  tags   = [local.prefix, local.name]

  bootstrap_node_name = format("%s-%s", local.prefix, "bootstrap")
  bootstrap_image_name = "ibm-redhat-8-6-minimal-amd64-6" # ubuntu image -> ibm-ubuntu-22-04-3-minimal-amd64-1
  bootstrap_image_id = data.ibm_is_image.bootstrap.id

  # Region and Zone calculations
  region = join("-", slice(split("-", var.zones[0]), 0, 2))

  # Derived configs
  # VPC
  resource_group_id = data.ibm_resource_group.itself.id

  # Subnets
  bastion_subnets = var.bastion_subnets

  bootstrap_path                = "/opt/IBM"
  remote_ansible_path           = format("%s/terraform-ibm-hpc", local.bootstrap_path)
  da_hpc_repo_url               = "https://github.com/terraform-ibm-modules/terraform-ibm-hpc"
  da_hpc_repo_tag               = "bootstrap_userdata" ###### change it to main in future
}
