# data "ibm_resource_group" "existing_resource_group" {
#   name = var.existing_resource_group
# }

data "ibm_is_image" "bastion" {
  name = var.bastion_image
}

data "ibm_is_image" "deployer" {
  name = var.deployer_image
}

data "ibm_is_ssh_key" "bastion" {
  for_each = toset(var.ssh_keys)
  name     = each.key
}

# Existing Bastion details
data "ibm_is_instance" "bastion_instance_name" {
  count = var.bastion_instance_name != null ? 1 : 0
  name  = var.bastion_instance_name
}
