########################################################################################################################
# Dedicated Host Module
########################################################################################################################

module "dedicated_host" {
  source  = "terraform-ibm-modules/dedicated-host/ibm"
  version = "2.0.0"
  dedicated_hosts = [
    {
      host_group_name     = "${var.prefix}-dhgroup"
      existing_host_group = var.existing_host_group
      resource_group_id   = var.resource_group_id
      class               = var.class
      family              = var.family
      zone                = var.zone[0]
      resource_tags       = var.resource_tags
      dedicated_host = [
        {
          name    = "${var.prefix}-dhhost"
          profile = var.profile
        }
      ]
    }
  ]
}
