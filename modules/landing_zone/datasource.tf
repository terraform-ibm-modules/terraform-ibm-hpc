data "ibm_resource_instance" "kms_instance" {
    count    = (var.key_management == "key_protect" && var.kms_instance_name != null) ? 1 : 0
    name     = var.kms_instance_name
    service  = "kms"
}

data "ibm_kms_key" "kms_key" {
    count =  (var.key_management == "key_protect" && var.kms_key_name != null) ? 1 : 0
    instance_id = data.ibm_resource_instance.kms_instance[0].id
    key_name = var.kms_key_name
}

data "ibm_is_vpc" "itself" {
  count = var.vpc == null ? 0 : 1
  name  = var.vpc
}

data "ibm_is_subnet" "subnet" {
  count = (var.vpc != null && length(var.subnet_id) > 0) ? 2 : 0
  identifier = var.subnet_id[count.index]
}

# data "ibm_is_subnet" "selected_subnets" {
#   for_each = toset(var.subnet_id)
#   identifier = each.value
# }

# locals {
#   subnet_info = {
#     for subnet_id, subnet_data in data.ibm_is_subnet.selected_subnets : subnet_data.zone => subnet_data.public_gateway != "" ? false : true
#   }
# }

# output "use_public_gateways" {
#   value = local.use_public_gateways_existing_subnet
# }

# output "map" {
#   value = local.subnet_info
#   # value = contains(keys(local.subnet_info), "2")
# }