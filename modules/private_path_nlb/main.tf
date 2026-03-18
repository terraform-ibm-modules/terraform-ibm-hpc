module "private_path_nlb" {
  source                             = "terraform-ibm-modules/vpc-private-path/ibm"
  version                            = "1.6.8"
  resource_group_id                  = var.resource_group_id
  tags                               = var.tags
  access_tags                        = var.access_tags
  subnet_id                          = var.subnet_id
  nlb_name                           = var.nlb_name
  nlb_backend_pools                  = var.nlb_backend_pools
  private_path_default_access_policy = var.private_path_default_access_policy
  private_path_service_endpoints     = var.private_path_service_endpoints
  private_path_zonal_affinity        = var.private_path_zonal_affinity
  private_path_name                  = var.private_path_name
  private_path_publish               = var.private_path_publish
  private_path_account_policies      = var.private_path_account_policies
}
