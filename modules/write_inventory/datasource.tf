data "ibm_is_instance_profile" "dynamic_worker_profile" {
  name = var.dynamic_compute_instances[0].profile
}

data "ibm_is_image" "dynamic_compute" {
  count = local.compute_image_found_in_map ? 0 : 1
  name  = var.dynamic_compute_instances[0].image
}
