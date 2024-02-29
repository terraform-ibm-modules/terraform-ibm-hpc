variable "enable_ldap" {}
variable "ldap_server" {}
variable "login_private_key" {}
variable "login_host" {}
variable "login_user" {}

// The resource is used to validate the existing LDAP server connection.
resource "null_resource" "validate_ldap_server_connection" {
  count = var.enable_ldap == true && var.ldap_server != "null" ? 1 : 0
  connection {
    type        = "ssh"
    user        = var.login_user
    private_key = var.login_private_key
    host        = var.login_host
  }
  provisioner "remote-exec" {
    inline = [
      "if openssl s_client -connect '${var.ldap_server}:389' </dev/null 2>/dev/null | grep -q 'CONNECTED'; then echo 'The connection to the existing LDAP server ${var.ldap_server} was successfully established.'; else echo 'The connection to the existing LDAP server ${var.ldap_server} failed, please establish it.'; exit 1; fi",
    ]
  }
}
