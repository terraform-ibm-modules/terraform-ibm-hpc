# data "ibm_resource_group" "existing_resource_group" {
#   name = var.existing_resource_group
# }

data "ibm_is_image" "bastion" {
  name = var.bastion_instance["image"]
}

data "ibm_is_image" "deployer" {
  count = local.deployer_image_found_in_map ? 0 : 1
  name  = var.deployer_instance["image"]
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

#Existing Public Gateway attachment
data "ibm_is_public_gateways" "public_gateways" {
  count = var.ext_vpc_name != null ? 1 : 0
}
