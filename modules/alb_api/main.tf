provider "shell" {
  environment = {
  }
  interpreter        = ["/bin/bash", "-c"]
  enable_parallelism = false
}

resource "shell_script" "alb_api" {
  count = var.create_load_balancer ? 1 : 0
  lifecycle_commands {
    create = "scripts/alb-create.sh"
    # read   = "scripts/alb-read.sh"
    # update = "scripts/alb-update.sh"
    delete = "scripts/alb-delete.sh"
  }
  working_directory = path.module
  # interpreter = ["/bin/bash", "-c"]
  sensitive_environment = {
    ibmcloud_api_key = var.ibmcloud_api_key
  }
  environment = {
    region               = var.region
    resource_group_id    = var.resource_group_id
    prefix               = var.prefix
    bastion_subnet_id    = var.bastion_subnets[0].id
    certificate_instance = var.certificate_instance
    firstip              = var.vsi_ips[0]
    pool_ips             = join(",", var.vsi_ips[*])
    security_group_ids   = join(",", var.security_group_ids[*])
  }
  triggers = {
    # We actually always do delete/create, since "update" is not implemented.
    # when_value_changed = var.region
    # ...
  }
}
