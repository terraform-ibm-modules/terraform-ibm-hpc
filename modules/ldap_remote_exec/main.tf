# Load and render the LDAP connection validation script template
data "template_file" "ldap_connection_script" {
  template = file("${path.module}/validate_ldap_connection.tpl")

  vars = {
    ldap_server = var.ldap_server
  }
}

# Resource to validate the LDAP server connection using remote-exec
resource "null_resource" "validate_ldap_server_connection" {
  connection {
    type                = "ssh"
    host                = var.deployer_ip
    user                = "vpcuser"
    private_key         = var.bastion_private_key_content
    bastion_host        = var.bastion_fip
    bastion_user        = "ubuntu"
    bastion_private_key = var.bastion_private_key_content
    timeout             = "60m"
  }

  provisioner "remote-exec" {
    inline = [
      data.template_file.ldap_connection_script.rendered
    ]
  }
}