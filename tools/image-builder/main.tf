module "landing_zone" {
  source                                 = "terraform-ibm-modules/landing-zone/ibm"
  version                                = "8.2.0"
  prefix                                 = local.prefix
  region                                 = local.region
  tags                                   = local.tags
  resource_groups                        = local.env.resource_groups
  network_cidr                           = local.env.network_cidr
  vpcs                                   = local.env.vpcs
  vpn_gateways                           = local.env.vpn_gateways
  enable_transit_gateway                 = local.env.enable_transit_gateway
  transit_gateway_resource_group         = local.env.transit_gateway_resource_group
  transit_gateway_connections            = local.env.transit_gateway_connections
  ssh_keys                               = local.env.ssh_keys
  vsi                                    = local.env.vsi
  security_groups                        = local.env.security_groups
  virtual_private_endpoints              = local.env.virtual_private_endpoints
  cos                                    = local.env.cos
  service_endpoints                      = local.env.service_endpoints
  key_management                         = local.env.key_management
  skip_kms_block_storage_s2s_auth_policy = local.env.skip_kms_block_storage_s2s_auth_policy
  atracker                               = local.env.atracker
  clusters                               = local.env.clusters
  wait_till                              = local.env.wait_till
  f5_vsi                                 = local.env.f5_vsi
  f5_template_data                       = local.env.f5_template_data
  appid                                  = local.env.appid
  teleport_config_data                   = local.env.teleport_config_data
  teleport_vsi                           = local.env.teleport_vsi
}

# # Code for Public Gateway attachment for the existing vpc and new subnets scenario

data "ibm_is_public_gateways" "public_gateways" {
}

locals {
  public_gateways_list = data.ibm_is_public_gateways.public_gateways.public_gateways
  zone_1_pgw_ids       = var.vpc_name != null ? [for gateway in local.public_gateways_list : gateway.id if gateway.vpc == local.vpc_id && gateway.zone == var.zones[0]] : []
}

resource "ibm_is_subnet_public_gateway_attachment" "zone_1_attachment" {
  count          = (var.vpc_name != null && var.subnet_id == null) ? 1 : 0
  subnet         = module.landing_zone.subnet_data[0].id
  public_gateway = length(local.zone_1_pgw_ids) > 0 ? local.zone_1_pgw_ids[0] : ""
}

resource "null_resource" "compress_and_encode_folder" {
  provisioner "local-exec" {
    command = <<EOT
      # Compress the compute folder into a .tar.gz archive
      tar -czf ./packer/hpcaas/compressed_compute.tar.gz ./packer/hpcaas/compute

      # Encode the archive to base64 format (macOS vs Linux handling)
      if [[ "$(uname)" == "Darwin" ]]; then
        base64 -i ./packer/hpcaas/compressed_compute.tar.gz -o ./packer/hpcaas/encoded_compute.txt
      else
        base64 ./packer/hpcaas/compressed_compute.tar.gz > ./packer/hpcaas/encoded_compute.txt
      fi
    EOT
  }
}

resource "null_resource" "delete_encoded_files" {
  provisioner "local-exec" {
    when    = destroy
    command = <<EOT
    # Deleting the compressed and encoded files on terraform destroy
    rm ${path.module}/packer/hpcaas/compressed_compute.tar.gz ${path.module}/packer/hpcaas/encoded_compute.txt
    EOT
  }
}

# Instead of using the file function, we read the file contents during the Terraform run.
data "local_file" "encoded_compute_content" {
  depends_on = [null_resource.compress_and_encode_folder, null_resource.delete_encoded_files]
  filename   = "${path.module}/packer/hpcaas/encoded_compute.txt"
}

module "packer_vsi" {
  source                        = "terraform-ibm-modules/landing-zone-vsi/ibm"
  version                       = "5.0.0"
  vsi_per_subnet                = 1
  image_id                      = local.packer_image_id
  machine_type                  = local.packer_machine_type
  prefix                        = local.packer_node_name
  resource_group_id             = local.packer_resource_groups["workload_rg"]
  enable_floating_ip            = var.enable_fip ? true : false
  create_security_group         = var.security_group_id == "" ? true : false
  security_group                = var.security_group_id == "" ? local.security_group : null
  security_group_ids            = var.security_group_id == "" ? [] : [var.security_group_id]
  ssh_key_ids                   = local.packer_ssh_keys
  subnets                       = local.packer_subnets
  tags                          = local.tags
  user_data                     = data.template_file.packer_user_data.rendered
  vpc_id                        = local.vpc_id
  kms_encryption_enabled        = local.kms_encryption_enabled
  skip_iam_authorization_policy = var.skip_iam_authorization_policy
  boot_volume_encryption_key    = local.boot_volume_encryption_key
  existing_kms_instance_guid    = local.existing_kms_instance_guid
  depends_on                    = [data.local_file.encoded_compute_content]
}
