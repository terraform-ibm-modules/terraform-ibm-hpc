# resource "local_sensitive_file" "prepare_scale_vsi_input" {
#   content = <<EOT
# {
#     "resource_group_id": "${local.resource_group_id}",
#     "resource_prefix": "${var.prefix}",
# }
# EOT
#   filename          = local.schematics_inputs_path
# }