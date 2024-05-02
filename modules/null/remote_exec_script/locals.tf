locals {
  command_1     = "sh -c  \"cd /tmp && ${var.with_bash ? "bash " : ""}${var.script_to_run}\""
  final_command = "${var.sudo_user != "" ? "sudo -i -u ${var.sudo_user} -- " : ""}${local.command_1}"
}
