resource "null_resource" "tf_resource_provisioner" {
  count = var.enable_deployer == true ? 1 : 0
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

  provisioner "file" {
    source      = local.schematics_inputs_path
    destination = local.remote_inputs_path
  }

  provisioner "remote-exec" {
    inline = [
      "if [ ! -d ${local.remote_terraform_path} ]; then sudo git clone -b ${local.da_hpc_repo_tag} ${local.da_hpc_repo_url} ${local.remote_terraform_path}; fi",
      "if [ ! -d ${local.remote_ansible_path}/${local.scale_cloud_infra_repo_name}/collections/ansible_collections/ibm/spectrum_scale ]; then sudo git clone -b ${local.scale_cloud_infra_repo_tag} ${local.scale_cloud_infra_repo_url} ${local.remote_ansible_path}/${local.scale_cloud_infra_repo_name}/collections/ansible_collections/ibm/spectrum_scale; fi",
      "sudo ln -fs /usr/local/bin/ansible-playbook /usr/bin/ansible-playbook",
      "sudo cp ${local.remote_inputs_path} ${local.remote_terraform_path}",
      "export TF_LOG=${var.TF_LOG} && sudo -E terraform -chdir=${local.remote_terraform_path} init && sudo -E terraform -chdir=${local.remote_terraform_path} apply -parallelism=${var.TF_PARALLELISM} -auto-approve"
    ]
  }

  triggers = {
    always_run = timestamp()
  }
}

resource "null_resource" "fetch_host_details_from_deployer" {
  count = var.enable_deployer == true ? 1 : 0

  provisioner "local-exec" {
    command = <<EOT
      scp -o StrictHostKeyChecking=no -o ProxyJump=ubuntu@${var.bastion_fip} \
          -i ${local.ssh_key_file} \
          -r vpcuser@${var.deployer_ip}:/opt/ibm/terraform-ibm-hpc/modules/ansible-roles/host_details/* "${path.root}/../../modules/ansible-roles/host_details/"
    EOT
  }

  triggers = {
    always_run = timestamp()
  }
  depends_on = [ resource.null_resource.tf_resource_provisioner ]
}

resource "null_resource" "cluster_destroyer" {
  count = var.enable_deployer == true ? 1 : 0
  triggers = {
    conn_host                  = var.deployer_ip
    conn_private_key           = var.bastion_private_key_content
    conn_bastion_host          = var.bastion_fip
    conn_bastion_private_key   = var.bastion_private_key_content
    conn_ibmcloud_api_key      = var.ibmcloud_api_key
    conn_remote_terraform_path = local.remote_terraform_path
    conn_terraform_log_level   = var.TF_LOG
  }

  connection {
    type                = "ssh"
    host                = self.triggers.conn_host
    user                = "vpcuser"
    private_key         = self.triggers.conn_private_key
    bastion_host        = self.triggers.conn_bastion_host
    bastion_user        = "ubuntu"
    bastion_private_key = self.triggers.conn_bastion_private_key
    timeout             = "60m"
  }

  provisioner "remote-exec" {
    when       = destroy
    on_failure = fail
    inline = [
      "export TF_LOG=${self.triggers.conn_terraform_log_level} && sudo -E terraform -chdir=${self.triggers.conn_remote_terraform_path} destroy -auto-approve"
    ]
  }
}
