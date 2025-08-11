data "ibm_resource_instance" "kms_instance" {
  count   = (var.key_management == "key_protect" && var.kms_instance_name != null) ? 1 : 0
  name    = var.kms_instance_name
  service = "kms"
}

data "ibm_kms_key" "kms_key" {
  count       = (var.key_management == "key_protect" && var.kms_key_name != null) ? 1 : 0
  instance_id = data.ibm_resource_instance.kms_instance[0].id
  key_name    = var.kms_key_name
}

data "ibm_is_vpc" "existing_vpc" {
  count = var.vpc_name != null ? 1 : 0
  name  = var.vpc_name
}

data "ibm_is_subnet" "subnet" {
  count      = (var.vpc_name != null && length(var.compute_subnet_id) > 0) ? 1 : 0
  identifier = var.compute_subnet_id
}

#############################################################################################################

#############################################################################################################

locals {
  exstng_cos_instance_bkt_hmc_key = var.scheduler == "Scale" ? [for details in var.afm_cos_config : details.cos_instance if(details.cos_instance != "" && details.bucket_name != "" && details.cos_service_cred_key != "")] : []
  exstng_cos_instance             = var.scheduler == "Scale" ? [for details in var.afm_cos_config : details.cos_instance if(details.cos_instance != "")] : []
}

data "ibm_resource_instance" "afm_cos_instances" {
  for_each = {
    for idx, value in local.exstng_cos_instance_bkt_hmc_key : idx => {
      total_cos_instance = element(local.exstng_cos_instance_bkt_hmc_key, idx)
    }
  }
  name    = each.value.total_cos_instance
  service = "cloud-object-storage"
}

locals {
  instnace_data     = [for key, value in data.ibm_resource_instance.afm_cos_instances : value]
  cos_instance_data = concat(flatten(module.landing_zone[*].cos_data), local.instnace_data)
  total_instance = [
    for item in local.cos_instance_data : {
      name                 = item.resource_name
      resource_instance_id = item.guid
    }
  ]
}

data "ibm_resource_instance" "exstng_cos_instances" {
  for_each = {
    for idx, value in local.exstng_cos_instance : idx => {
      total_cos_instance = element(local.exstng_cos_instance, idx)
    }
  }
  name    = each.value.total_cos_instance
  service = "cloud-object-storage"
}

locals {
  existing_instnace_data   = [for key, value in data.ibm_resource_instance.exstng_cos_instances : value]
  total_existing_instances = setsubtract(([for item in local.cos_instance_data : item.guid]), ([for item in local.existing_instnace_data : item.guid]))

  config_details = flatten([
    for instance in local.total_instance : [
      for config in var.afm_cos_config : {
        afm_fileset          = config.afm_fileset
        mode                 = config.mode
        resource_instance_id = instance.resource_instance_id
      } if config.cos_instance == instance.name
    ]
  ])
}

# Existing Bucket Data

locals {
  total_exstng_bucket_instance = var.scheduler == "Scale" ? [for bucket in var.afm_cos_config : bucket.cos_instance if(bucket.bucket_name != "")] : []

  total_exstng_bucket_name = var.scheduler == "Scale" ? [for bucket in var.afm_cos_config : bucket.bucket_name if(bucket.bucket_name != "")] : []

  total_exstng_bucket_region = var.scheduler == "Scale" ? [for bucket in var.afm_cos_config : bucket.bucket_region if(bucket.bucket_name != "")] : []

  total_exstng_bucket_type = var.scheduler == "Scale" ? [for bucket in var.afm_cos_config : bucket.bucket_type if(bucket.bucket_name != "")] : []
}

data "ibm_resource_instance" "afm_exstng_bucket_cos_instance" {
  for_each = {
    for idx, value in local.total_exstng_bucket_instance : idx => {
      total_cos_instance = element(local.total_exstng_bucket_instance, idx)
    }
  }
  name    = each.value.total_cos_instance
  service = "cloud-object-storage"
}

data "ibm_cos_bucket" "afm_exstng_cos_buckets" {
  for_each = {
    for idx, value in local.total_exstng_bucket_instance : idx => {
      bucket_name          = element(local.total_exstng_bucket_name, idx)
      resource_instance_id = element(flatten([for instance in data.ibm_resource_instance.afm_exstng_bucket_cos_instance : instance[*].id]), idx)
      bucket_region        = element(local.total_exstng_bucket_region, idx)
      bucket_type          = element(local.total_exstng_bucket_type, idx)
    }
  }
  bucket_name          = each.value.bucket_name
  resource_instance_id = each.value.resource_instance_id
  bucket_region        = each.value.bucket_region
  bucket_type          = each.value.bucket_type
  depends_on           = [data.ibm_resource_instance.afm_exstng_bucket_cos_instance]
}

# Existing Hmac Key Data

locals {
  total_exstng_hmac_key_instance = var.scheduler == "Scale" ? [for key in var.afm_cos_config : key.cos_instance if(key.cos_service_cred_key != "")] : []
  total_exstng_hmac_key_name     = var.scheduler == "Scale" ? [for key in var.afm_cos_config : key.cos_service_cred_key if(key.cos_service_cred_key != "")] : []
}

data "ibm_resource_instance" "afm_exstng_hmac_key_cos_instance" {
  for_each = {
    for idx, value in local.total_exstng_hmac_key_instance : idx => {
      total_cos_instance = element(local.total_exstng_hmac_key_instance, idx)
    }
  }
  name    = each.value.total_cos_instance
  service = "cloud-object-storage"
}

data "ibm_resource_key" "afm_exstng_cos_hmac_keys" {
  for_each = {
    for idx, value in local.total_exstng_hmac_key_instance : idx => {
      hmac_key             = element(local.total_exstng_hmac_key_name, idx)
      resource_instance_id = element(flatten([for instance in data.ibm_resource_instance.afm_exstng_hmac_key_cos_instance : instance[*].id]), idx)
    }
  }
  name                 = each.value.hmac_key
  resource_instance_id = each.value.resource_instance_id
  depends_on           = [data.ibm_resource_instance.afm_exstng_hmac_key_cos_instance]
}

locals {
  # Final Bucket Data
  existing_buckets   = [for num, bucket in data.ibm_cos_bucket.afm_exstng_cos_buckets : bucket]
  total_buckets_data = concat(local.existing_buckets, flatten(module.landing_zone[*].cos_bucket_data))
  total_buckets = [
    for item in local.total_buckets_data : {
      endpoint             = item.s3_endpoint_direct
      bucket               = item.bucket_name
      resource_instance_id = split(":", item.resource_instance_id)[7]
    }
  ]

  newly_created_instance_bucket = [
    for item in local.total_buckets : {
      endpoint             = item.endpoint
      bucket               = item.bucket
      resource_instance_id = item.resource_instance_id
    } if item.resource_instance_id == (var.enable_landing_zone && local.enable_afm ? tolist(local.total_existing_instances)[0] : "")
  ]

  afm_config_details_0 = flatten([
    for bucket in local.total_buckets : [
      for config in local.config_details : {
        bucket     = bucket.bucket
        fileset    = config.afm_fileset
        filesystem = local.filesystem
        mode       = config.mode
        endpoint   = "https://${bucket.endpoint}"
      } if bucket.resource_instance_id == config.resource_instance_id
    ]
  ])

  afm_config_details_1 = [
    for i in range(length(local.newly_created_instance_bucket)) : {
      bucket     = local.newly_created_instance_bucket[i].bucket
      endpoint   = "https://${local.newly_created_instance_bucket[i].endpoint}"
      fileset    = local.new_instance_bucket_hmac[i].afm_fileset
      filesystem = local.filesystem
      mode       = local.new_instance_bucket_hmac[i].mode
    }
  ]

  scale_afm_bucket_config_details = concat(local.afm_config_details_0, local.afm_config_details_1)

  # Final Hmac Key Data
  existing_hmac_keys = [
    for item in [for num, keys in([for key in [for num, keys in data.ibm_resource_key.afm_exstng_cos_hmac_keys : keys] : key]) : keys] : {
      credentials          = item.credentials
      credentials_json     = item.credentials_json
      resource_instance_id = split(":", item.id)[7]
      name                 = item.name
    }
  ]

  new_hmac_keys = [
    for item in [for num, keys in((var.enable_landing_zone ? [for key in flatten(module.landing_zone[*].cos_key_credentials_map)[0] : key] : [])) : keys] : {
      credentials          = item.credentials
      credentials_json     = item.credentials_json
      resource_instance_id = split(":", item.id)[7]
      name                 = item.name
    }
  ]
  total_hmac_keys = concat(local.existing_hmac_keys, local.new_hmac_keys)

  scale_afm_cos_hmac_key_params = flatten([
    for key in local.total_hmac_keys : [
      for bucket in local.total_buckets : {
        akey   = key.credentials["cos_hmac_keys.access_key_id"]
        bucket = bucket.bucket
        skey   = key.credentials["cos_hmac_keys.secret_access_key"]
      } if key.resource_instance_id == bucket.resource_instance_id
    ]
  ])
}
