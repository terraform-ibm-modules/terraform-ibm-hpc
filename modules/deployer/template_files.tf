data "template_file" "bastion_user_data" {
  template = file("${path.module}/templates/bastion_user_data.tpl")
  vars = {
    ssh_public_key_content = var.enable_deployer ? module.ssh_key[0].public_key_content : ""
  }
}

data "template_file" "deployer_user_data" {
  template = file("${path.module}/templates/deployer_user_data.tpl")
  vars = {
    bastion_public_key_content = var.enable_deployer ? module.ssh_key[0].public_key_content : ""
    compute_dns_domain         = var.enable_deployer ? local.compute_dns_domain : ""
    compute_interfaces         = var.enable_deployer ? local.compute_interfaces : ""
  }
}
