# data "ibm_resource_group" "itself" {
#   name = var.resource_group
# }

data "ibm_is_image" "bootstrap" {
  name = local.bootstrap_image_name
}
