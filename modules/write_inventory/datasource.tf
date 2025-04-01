# New Code
data "ibm_is_instance_profile" "dynamic_worker_profile" {
  name = var.dynamic_compute_instances[0].profile
}

data "ibm_is_image" "dynamic_compute" {
  name = var.dynamic_compute_instances[0].image
}