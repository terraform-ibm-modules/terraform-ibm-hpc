data "ibm_resource_group" "existing_resource_group" {
  count = var.enable_deployer == false && var.enable_sccwp ? 1 : 0
  name  = var.resource_group_name
}
