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
  catalog_offering = {
    version_crn = "crn:v1:bluemix:public:globalcatalog-collection:global::1082e7d2-5e2f-0a11-a3bc-f88a8e1931fc:version:61e655c5-40b6-4b68-a6ab-e6c77a457fce-global/e08b9ca5-699c-4779-8369-1a0c1ed54b30-global"
    plan_crn    = "crn:v1:bluemix:public:globalcatalog-collection:global::1082e7d2-5e2f-0a11-a3bc-f88a8e1931fc:plan:sw.1082e7d2-5e2f-0a11-a3bc-f88a8e1931fc.d114e7ab-4f7e-40c4-98cc-f0c000cbf3a7-global"
  }
}
