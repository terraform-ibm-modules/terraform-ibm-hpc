data "template_file" "packer_user_data" {
  template = file("${path.module}/templates/packer_user_data.tpl")
  vars = {
    ibm_api_key              = var.ibmcloud_api_key
    vpc_region               = local.region
    vpc_id                   = local.vpc_id
    vpc_subnet_id            = (var.vpc_name != null && var.subnet_id != null) ? var.subnet_id : local.landing_zone_subnet_output[0].id
    resource_group_id        = local.packer_resource_groups["workload_rg"]
    source_image_name        = var.source_image_name # Source_image_name_from_images_of_VPC
    image_name               = var.image_name        # image_name_for_newly_created_custom_image
    install_sysdig           = var.install_sysdig
    security_group_id        = var.security_group_id
    encoded_compute          = data.local_file.encoded_compute_content.content
    target_dir               = "/var"
    prefix                   = var.prefix
    cluster_id               = var.cluster_id
    reservation_id           = var.reservation_id
    catalog_validate_ssh_key = var.ssh_keys[0]
    zones                    = join(",", var.zones)
    resource_group           = var.resource_group
    private_catalog_id       = var.private_catalog_id
    solution                 = var.solution
    ibm_customer_number      = var.ibm_customer_number
  }
}
