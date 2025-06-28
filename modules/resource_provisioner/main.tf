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
      # Remove and re-clone the remote terraform path repo
      # "if [ -d ${local.remote_terraform_path} ]; then echo 'Removing existing repository at ${local.remote_terraform_path}' && sudo rm -rf ${local.remote_terraform_path}; fi",
      # "echo 'Cloning repository with tag: ${local.da_hpc_repo_tag}' && sudo git clone -b ${local.da_hpc_repo_tag} https://${var.github_token}@${local.da_hpc_repo_url} ${local.remote_terraform_path}",
      "if [ ! -d ${local.remote_terraform_path} ]; then echo 'Cloning repository with tag: ${local.da_hpc_repo_tag}' && sudo git clone -b ${local.da_hpc_repo_tag} https://${local.da_hpc_repo_url} ${local.remote_terraform_path}; fi",

      # Clone Spectrum Scale collection if it doesn't exist
      "if [ ! -d ${local.remote_ansible_path}/${local.scale_cloud_infra_repo_name}/collections/ansible_collections/ibm/spectrum_scale ]; then sudo git clone -b ${local.scale_cloud_infra_repo_tag} ${local.scale_cloud_infra_repo_url} ${local.remote_ansible_path}/${local.scale_cloud_infra_repo_name}/collections/ansible_collections/ibm/spectrum_scale; fi",

      # Ensure ansible-playbook is available
      "sudo ln -fs /usr/local/bin/ansible-playbook /usr/bin/ansible-playbook",

      # Copy inputs file
      "sudo cp ${local.remote_inputs_path} ${local.remote_terraform_path}",

      # Run Terraform init and apply
      "export TF_LOG=${var.TF_LOG} && sudo -E terraform -chdir=${local.remote_terraform_path} init && sudo -E terraform -chdir=${local.remote_terraform_path} apply -parallelism=${var.TF_PARALLELISM} -auto-approve -lock=false"
    ]
  }

  triggers = {
    always_run = timestamp()
  }
}

resource "null_resource" "ext_bastion_access" {
  count = var.enable_deployer && var.existing_bastion_instance_name != null ? 1 : 0

  connection {
    type        = "ssh"
    host        = var.bastion_fip
    user        = "ubuntu"
    private_key = var.bastion_private_key_content
    timeout     = "60m"
  }

  provisioner "remote-exec" {
    inline = [
      "echo 'Adding SSH Key to Existing Bastion Host'",
      sensitive("echo '${local.bastion_public_key_content}' >> /home/$(whoami)/.ssh/authorized_keys"),
    ]
  }
}

resource "null_resource" "fetch_host_details_from_deployer" {
  count = var.enable_deployer == true && var.scheduler == "LSF" ? 1 : 0

  provisioner "local-exec" {
    command = <<EOT
      ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
          -o ProxyCommand="ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ${local.ssh_key_file} ubuntu@${var.bastion_fip} -W %h:%p" \
          -i ${local.ssh_key_file} \
          vpcuser@${var.deployer_ip} \
          "sudo chmod 644 /opt/ibm/terraform-ibm-hpc/solutions/${local.products}/*.ini && sudo chown vpcuser:vpcuser /opt/ibm/terraform-ibm-hpc/solutions/${local.products}/*.ini"

      scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
          -o ProxyCommand="ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ${local.ssh_key_file} ubuntu@${var.bastion_fip} -W %h:%p" \
          -i ${local.ssh_key_file} \
          vpcuser@${var.deployer_ip}:/opt/ibm/terraform-ibm-hpc/solutions/${local.products}/*.ini \
          "${path.root}/../../solutions/${local.products}/"
    EOT
  }
  depends_on = [resource.null_resource.tf_resource_provisioner]
}

resource "null_resource" "cleanup_ini_files" {
  count = var.enable_deployer == true && var.scheduler == "LSF" ? 1 : 0

  triggers = {
    products = local.products
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<EOT
      echo "Cleaning up local .ini files..."
      rm -f "${path.root}/../../solutions/${self.triggers.products}/"*.ini
    EOT
  }
  depends_on = [null_resource.fetch_host_details_from_deployer]
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
      "export TF_LOG=${self.triggers.conn_terraform_log_level} && sudo -E terraform -chdir=${self.triggers.conn_remote_terraform_path} destroy -auto-approve -lock=false"
    ]
  }
}
