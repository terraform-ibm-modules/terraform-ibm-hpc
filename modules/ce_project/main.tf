provider "shell" {
  sensitive_environment = {
    IBM_CLOUD_API_KEY = var.ibmcloud_api_key
  }
  interpreter        = ["/bin/bash", "-c"]
  enable_parallelism = false
}

resource "shell_script" "ce_project" {
  count = var.solution == "hpc" ? 1 : 0
  lifecycle_commands {
    create = "scripts/create-update-ce-project.sh"
    update = "scripts/create-update-ce-project.sh"
    delete = "scripts/delete-ce-project.sh"
  }
  working_directory = path.module
  sensitive_environment = {
    RESERVATION_ID = var.reservation_id
  }
  environment = {
    REGION            = var.region
    RESOURCE_GROUP_ID = var.resource_group_id
  }
  triggers = {
    # We actually always do delete/create, since "update" is not implemented.
    # when_value_changed = var.region
    # ...
  }
}

resource "null_resource" "print_ce_project_logs" {
  count = var.solution == "hpc" ? 1 : 0
  provisioner "local-exec" {
    command     = "echo \"$LOG_OUTPUT\" | sed 's/\\(\\[[0-9]\\{8\\} [0-9]\\{2\\}:[0-9]\\{2\\}:[0-9]\\{2\\}\\]\\)/\\n\\1/g'"
    working_dir = path.module
    environment = {
      LOG_OUTPUT = shell_script.ce_project[0].output["logs"]
    }
  }
}
