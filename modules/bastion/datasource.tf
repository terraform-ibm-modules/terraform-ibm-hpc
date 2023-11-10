data "ibm_resource_group" "itself" {
  name = var.resource_group
}

data "ibm_is_image" "bastion" {
  name = local.bastion_image_name
}

data "ibm_is_ssh_key" "bastion" {
  for_each = toset(var.ssh_keys)
  name     = each.key
}
