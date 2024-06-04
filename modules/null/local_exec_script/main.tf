resource "null_resource" "execute_local_script" {
  provisioner "local-exec" {
    command     = "${var.script_path} ${var.script_arguments}"
    environment = var.script_environment
  }
}
