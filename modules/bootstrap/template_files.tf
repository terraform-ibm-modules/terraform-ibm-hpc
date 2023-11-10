data "template_file" "bootstrap_user_data" {
  template = file("${path.module}/templates/bootstrap_user_data.tpl")
  vars = {
    bastion_public_key_content     = var.bastion_public_key_content != null ? var.bastion_public_key_content : ""
  }
}
