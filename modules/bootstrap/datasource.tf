data "ibm_is_image" "bastion" {
  name = local.bastion_image_name
}

# data "ibm_is_image" "bootstrap" {
#   name = local.bootstrap_image_name
# }

data "ibm_is_ssh_key" "bastion" {
  for_each = toset(var.ssh_keys)
  name     = each.key
}

# Existing Bastion details
data "ibm_is_instance" "bastion_instance_name" {
  count = var.bastion_instance_name != null ? 1 : 0
  name  = var.bastion_instance_name
}
