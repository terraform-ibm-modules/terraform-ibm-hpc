data "template_file" "bastion_user_data" {
  template = file("${path.module}/templates/bastion_user_data.tpl")
  vars = {
    ssh_public_key_content = module.ssh_key[0].public_key_content
  }
}
