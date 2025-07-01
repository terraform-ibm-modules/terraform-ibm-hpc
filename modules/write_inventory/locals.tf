locals {
  region                     = join("-", slice(split("-", var.zones[0]), 0, 2))
  vcpus                      = tonumber(data.ibm_is_instance_profile.dynamic_worker_profile.vcpu_count[0].value)
  ncores                     = tonumber(local.vcpus / 2)
  ncpus                      = tonumber(var.enable_hyperthreading ? local.vcpus : local.ncores)
  mem_in_mb                  = tonumber(data.ibm_is_instance_profile.dynamic_worker_profile.memory[0].value) * 1024
  rc_max_num                 = tonumber(var.dynamic_compute_instances[0].count)
  rc_profile                 = var.dynamic_compute_instances[0].profile
  boot_volume_encryption_key = jsonencode(var.kms_encryption_enabled ? var.boot_volume_encryption_key : null)
  compute_image_found_in_map = contains(keys(local.image_region_map), var.dynamic_compute_instances[0]["image"])
  new_compute_image_id       = local.compute_image_found_in_map ? local.image_region_map[var.dynamic_compute_instances[0]["image"]][local.region] : "Image not found with the given name"
  image_id                   = local.compute_image_found_in_map ? local.new_compute_image_id : data.ibm_is_image.dynamic_compute[0].id
}
