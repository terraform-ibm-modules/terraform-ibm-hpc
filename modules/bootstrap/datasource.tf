data "ibm_is_image" "bastion" {
  name = local.bastion_image_name
}

# Existing Bastion details
data "ibm_is_instance" "bastion_instance_name" {
  count = var.bastion_instance_name != null ? 1 : 0
  name  = var.bastion_instance_name
}
