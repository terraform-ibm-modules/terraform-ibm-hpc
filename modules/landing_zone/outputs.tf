output "resource_group_id" {
  description = "Resource group ID"
  value       = module.landing_zone[*].resource_group_data
}

output "vpc_name" {
  description = "VPC name"
  value       = module.landing_zone[*].vpc_data[0].vpc_name
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.landing_zone[*].vpc_data[0].vpc_id
}

output "vpc_cidr" {
  description = "To fetch the vpc cidr"
  value       = module.landing_zone[*].vpc_data[0].cidr_blocks[0]
}

output "vpc_crn" {
  description = "VPC CRN"
  value       = module.landing_zone[*].vpc_data[0].vpc_crn
}

output "bastion_subnets" {
  description = "Bastion subnets"
  value = [for subnet in flatten(module.landing_zone[*].subnet_data) : {
    name = subnet["name"]
    id   = subnet["id"]
    zone = subnet["zone"]
    cidr = subnet["cidr"]
    } if strcontains(subnet["name"], "-${local.name}-bastion-subnet")
  ]
}

output "client_subnets" {
  description = "client subnets"
  value = [for subnet in flatten(module.landing_zone[*].subnet_data) : {
    name = subnet["name"]
    id   = subnet["id"]
    zone = subnet["zone"]
    cidr = subnet["cidr"]
    } if strcontains(subnet["name"], "-${local.name}-client-subnet")
  ]
}

output "compute_subnets" {
  description = "Compute subnets"
  value = [for subnet in flatten(module.landing_zone[*].subnet_data) : {
    name = subnet["name"]
    id   = subnet["id"]
    zone = subnet["zone"]
    cidr = subnet["cidr"]
    } if strcontains(subnet["name"], "-${local.name}-compute-subnet-zone-")
  ]
}

output "storage_subnets" {
  description = "Storage subnets"
  value = [for subnet in flatten(module.landing_zone[*].subnet_data) : {
    name = subnet["name"]
    id   = subnet["id"]
    zone = subnet["zone"]
    cidr = subnet["cidr"]
    } if strcontains(subnet["name"], "-${local.name}-storage-subnet-zone-")
  ]
}

output "protocol_subnets" {
  description = "Protocol subnets"
  value = [for subnet in flatten(module.landing_zone[*].subnet_data) : {
    name = subnet["name"]
    id   = subnet["id"]
    zone = subnet["zone"]
    cidr = subnet["cidr"]
    } if strcontains(subnet["name"], "-${local.name}-protocol-subnet-zone-")
  ]
}

output "subnets_crn" {
  description = "Subnets crn"
  value       = flatten(module.landing_zone[*].subnet_data[*]["crn"])
}

# TODO: Find a way to get CRN needed for VSI boot drive encryption
output "boot_volume_encryption_key" {
  description = "Boot volume encryption key"
  value       = var.key_management == "key_protect" ? (var.kms_key_name == null ? module.landing_zone[*].key_map[format("%s-vsi-key", var.prefix)] : module.landing_zone[*].key_map[var.kms_key_name]) : null
}

output "key_management_guid" {
  description = "GUID for KMS instance"
  value       = var.enable_landing_zone ? var.key_management != null || (var.scale_encryption_enabled && var.scale_encryption_type == "key_protect" && var.key_protect_instance_id == null) ? module.landing_zone[0].key_management_guid : null : null
}

output "cos_buckets_data" {
  description = "COS buckets data"
  value       = flatten(module.landing_zone[*].cos_bucket_data)
}

output "cos_instance_crns" {
  description = "CRN of the COS instance created by Landing Zone Module"
  value       = flatten(module.landing_zone[*].cos_data[*].crn)
}

output "cos_buckets_names" {
  description = "List of names for COS buckets created"
  value       = flatten(module.landing_zone[*].cos_bucket_names)
}

output "cos_data" {
  description = "COS buckets data"
  value       = flatten(module.landing_zone[*].cos_data)
}

output "hmac_key_data" {
  description = "COS hmac data"
  value       = var.enable_landing_zone ? [for key in flatten(module.landing_zone[*].cos_key_credentials_map)[0] : key] : []
}

output "cos_names" {
  description = "List of Cloud Object Storage instance names"
  value       = flatten(module.landing_zone[*].cos_names)
}

output "scale_afm_bucket_config_details" {
  description = "Scale AFM COS Bucket and Configuration Details"
  value       = local.scale_afm_bucket_config_details
}

output "scale_afm_cos_hmac_key_params" {
  description = "Scale AFM COS HMAC Key Details"
  value       = local.scale_afm_cos_hmac_key_params
}

# TODO: Observability data
