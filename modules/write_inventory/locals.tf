localocals {
  vcpus                       = tonumber(data.ibm_is_instance_profile.dynamic_worker_profile.vcpu_count[0].value)
  ncores                      = tonumber(local.vcpus / 2)
  ncpus                       = tonumber(var.enable_hyperthreading ? local.vcpus : local.ncores)
  mem_in_mb                   = tonumber(data.ibm_is_instance_profile.dynamic_worker_profile.memory[0].value) * 1024
  rc_max_num                  = tonumber(var.dynamic_compute_instances[0].count)
  rc_profile                  = var.dynamic_compute_instances[0].profile
  image_id                    = data.ibm_is_image.dynamic_compute.id
}