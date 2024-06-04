data "template_file" "ldap_connection_script" {
  template = file("${path.module}/validate_ldap_connection.tpl")
  vars = {
    ldap_server = var.ldap_server
  }
}

# The resource is used to validate the existing LDAP server connection.
resource "null_resource" "validate_ldap_server_connection" {
  count = var.enable_ldap == true && var.ldap_server != "null" ? 1 : 0
  connection {
    type        = "ssh"
    user        = var.login_user
    private_key = var.login_private_key
    host        = var.login_host
  }
  provisioner "remote-exec" {
    inline = [data.template_file.ldap_connection_script.rendered]
  }
}
