# To debug local values
/*
output "env_var" {
  value = local.env
}

output "landing_zone_data" {
  value = module.landing_zone[*]
}

output "vpc_data" {
  value = module.landing_zone[*].vpc_data
}

output "subnet_data" {
  value = module.landing_zone[*].subnet_data
}
*/

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
    } if strcontains(subnet["name"], "-hpc-bastion-subnet")
  ]
}

output "client_subnets" {
  description = "client subnets"
  value = [for subnet in flatten(module.landing_zone[*].subnet_data) : {
    name = subnet["name"]
    id   = subnet["id"]
    zone = subnet["zone"]
    cidr = subnet["cidr"]
    } if strcontains(subnet["name"], "-hpc-client-subnet")
  ]
}

output "compute_subnets" {
  description = "Compute subnets"
  value = [for subnet in flatten(module.landing_zone[*].subnet_data) : {
    name = subnet["name"]
    id   = subnet["id"]
    zone = subnet["zone"]
    cidr = subnet["cidr"]
    } if strcontains(subnet["name"], "-hpc-compute-subnet-zone-")
  ]
}

output "storage_subnets" {
  description = "Storage subnets"
  value = [for subnet in flatten(module.landing_zone[*].subnet_data) : {
    name = subnet["name"]
    id   = subnet["id"]
    zone = subnet["zone"]
    cidr = subnet["cidr"]
    } if strcontains(subnet["name"], "-hpc-storage-subnet-zone-")
  ]
}

output "protocol_subnets" {
  description = "Protocol subnets"
  value = [for subnet in flatten(module.landing_zone[*].subnet_data) : {
    name = subnet["name"]
    id   = subnet["id"]
    zone = subnet["zone"]
    cidr = subnet["cidr"]
    } if strcontains(subnet["name"], "-hpc-protocol-subnet-zone-")
  ]
}

output "subnets_crn" {
  description = "Subnets crn"
  value       = flatten(module.landing_zone[*].subnet_data[*]["crn"])
}

# TODO: Find a way to get CRN needed for VSI boot drive encryption
output "boot_volume_encryption_key" {
  description = "Boot volume encryption key"
  value       = var.key_management != null ? module.landing_zone[*].key_map[format("%s-vsi-key", var.prefix)] : null
}

output "key_management_guid" {
  description = "GUID for KMS instance"
  value       = var.key_management != null ? module.landing_zone[0].key_management_guid : null
}

# TODO: Observability data
