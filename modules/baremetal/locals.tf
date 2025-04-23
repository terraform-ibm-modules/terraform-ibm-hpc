# define variables
locals {
  name              = "hpc"
  prefix            = var.prefix
  storage_image_id  = data.ibm_is_image.storage[*].id
  storage_node_name = format("%s-%s", local.prefix, "strg")
  storage_subnets   = var.storage_subnets
  resource_group_id = data.ibm_resource_group.existing_resource_group.id
  tags              = [local.prefix, local.name]
  storage_ssh_keys  = [for name in var.storage_ssh_keys : data.ibm_is_ssh_key.storage[name].id]

  bms_interfaces = ["ens1", "ens2"]
  # TODO: explore (DA always keep it true)
  skip_iam_authorization_policy = true
  storage_server_count        = sum(var.storage_servers[*]["count"])
  enable_storage                = local.storage_server_count > 0

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
  ]
}
