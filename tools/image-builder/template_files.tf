data "template_file" "packer_user_data" {
  template = file("${path.module}/templates/packer_user_data.tpl")
  vars = {
    ibm_api_key       = var.ibmcloud_api_key
    vpc_region        = local.region
    vpc_subnet_id     = (var.vpc_name != null && var.subnet_id != null) ? var.subnet_id : local.landing_zone_subnet_output[0].id
    resource_group_id = local.packer_resource_groups["workload_rg"]
    source_image_name = var.source_image_name # Source_image_name_from_images_of_VPC
    image_name        = var.image_name        # image_name_for_newly_created_custom_image
    install_sysdig    = var.install_sysdig
    security_group_id = var.security_group_id
    encoded_content   = data.local_file.encoded_compute_content.content
    target_dir        = "/var"
  }
}
