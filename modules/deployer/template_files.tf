data "template_file" "bastion_user_data" {
  template = file("${path.module}/templates/bastion_user_data.tpl")
  vars = {
    ssh_public_key_content = local.enable_bastion ? module.ssh_key[0].public_key_content : ""
  }
}

data "template_file" "deployer_user_data" {
  template = file("${path.module}/templates/deployer_user_data.tpl")
  vars = {
    bastion_public_key_content = local.enable_bastion ? module.ssh_key[0].public_key_content : ""
    compute_dns_domain         = local.enable_bastion ? local.compute_dns_domain : ""
    compute_interfaces         = local.enable_bastion ? local.compute_interfaces : ""
    # compute_public_key_content  = local.enable_bastion ? module.compute_key[0].public_key_content : ""
    # compute_private_key_content = local.enable_bastion ? module.compute_key[0].private_key_content : ""

  }
}
