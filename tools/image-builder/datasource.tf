data "ibm_is_vpc" "existing_vpc" {
  count = var.vpc_name != null ? 1 : 0
  name  = var.vpc_name
}

data "ibm_is_vpc" "vpc" {
  name = local.vpc_name
  # Depends on creation of new VPC or look up of existing VPC based on value of var.vpc_name,
  depends_on = [module.landing_zone, data.ibm_is_vpc.existing_vpc]
}

data "ibm_is_subnet" "existing_subnet" {
  count      = (var.vpc_name != null && var.subnet_id != null) ? 1 : 0
  identifier = var.subnet_id
}

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

data "ibm_is_image" "packer" {
  name = "ibm-redhat-8-8-minimal-amd64-6"
}

data "ibm_is_ssh_key" "packer" {
  for_each = toset(var.ssh_keys)
  name     = each.key
}
