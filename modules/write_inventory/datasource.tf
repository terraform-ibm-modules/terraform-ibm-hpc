# New Code
data "ibm_is_instance_profile" "dynamic_worker_profile" {
  name = var.dynamic_compute_instances[0].profile
}

data "ibm_is_image" "dynamic_compute" {
  name = var.dynamic_compute_instances[0].image
}

data "ibm_is_ssh_key" "compute_ssh_keys" {
  for_each = toset(local.compute_ssh_keys)
  name     = each.key
}

data "ibm_is_subnet" "compute_subnet_crn" {
  identifier = local.compute_subnet_id
}