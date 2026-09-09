resource "null_resource" "tf_resource_provisioner" {
  count = var.enable_deployer == true ? 1 : 0

  # 1. LOGIN AND CHECK/START THE NODE (Securely)
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]

    environment = {
      IBMCLOUD_API_KEY       = var.ibmcloud_api_key
      IBMCLOUD_VERSION_CHECK = "false" # Prevents update prompts from messing with standard output
      IBMCLOUD_HOME          = "/tmp/ibmcloud_workspace"
    }

    command = <<-EOT
      mkdir -p /tmp/ibmcloud_workspace
      echo "Logging into IBM Cloud securely..."
      if ibmcloud plugin show vpc-infrastructure &>/dev/null; then
        echo "✅ vpc-infrastructure plugin is already active and healthy."
      else
        echo "⚠️ Plugin missing or unregistered. Performing clean installation..."
        rm -rf /tmp/ibmcloud_workspace/.bluemix/plugins/vpc-infrastructure
        ibmcloud plugin install vpc-infrastructure -f
      fi
      ibmcloud login -r ${var.region} -q

      echo "Checking status for instance: ${var.deployer_instance_id}..."
      # Added 'tr' to ensure the status string is strictly lowercase for safe Bash comparison
      STATUS=$(ibmcloud is instance ${var.deployer_instance_id} | grep -i "^Status" | awk '{print $2}' | tr '[:upper:]' '[:lower:]')

      echo "Current status is: $STATUS"

      if [ "$STATUS" == "running" ]; then
        echo "✅ Instance is already running. Skipping start command."
      elif [ "$STATUS" == "stopped" ]; then
        echo "⏳ Instance is stopped. Starting it now..."
        ibmcloud is instance-start ${var.deployer_instance_id}
      else
        echo "⚠️ Instance is in transition state: $STATUS. Forcing start command..."
        ibmcloud is instance-start ${var.deployer_instance_id} --force || echo "Command failed or ignored."
      fi
    EOT
  }

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

  # Copy backend file
  provisioner "file" {
    source      = local.backend_inputs_path
    destination = local.remote_backend_path
  }

  # Copy tfvars file
  provisioner "file" {
    source      = local.schematics_inputs_path
    destination = local.remote_inputs_path
  }

  provisioner "remote-exec" {
    inline = [
      <<-EOT
      sudo rm -f /tmp/tf_env.sh
      sudo rm -f /tmp/tf_apply_exit_code
      sudo bash -c 'cat > /tmp/tf_env.sh <<EOF
  export AWS_ACCESS_KEY_ID="${local.safe_hmac_params[0].akey}"
  export AWS_SECRET_ACCESS_KEY="${local.safe_hmac_params[0].skey}"
  EOF'
      sudo chmod 600 /tmp/tf_env.sh
      EOT
    ]
  }

  provisioner "remote-exec" {
    inline = [
      # Conditionally clone "terraform-ibm-hpc" repository from TIM
      "if [ -f ${local.remote_terraform_path} ]; then sudo rm -f ${local.remote_terraform_path}; fi && if [ ! -d ${local.remote_terraform_path} ]; then echo 'Cloning repository with tag: ${local.da_hpc_repo_tag}' && sudo git clone -b ${local.da_hpc_repo_tag} https://${local.da_hpc_repo_url} ${local.remote_terraform_path}; fi",
      # Clone Spectrum Scale collection if it doesn't exist
      "if [ \"${var.scheduler}\" = \"Scale\" ]; then if [ ! -d ${local.remote_ansible_path}/${local.scale_cloud_infra_repo_name}/collections/ansible_collections/ibm/spectrum_scale ]; then sudo git clone -b ${local.scale_cloud_infra_repo_tag} ${local.scale_cloud_infra_repo_url} ${local.remote_ansible_path}/${local.scale_cloud_infra_repo_name}/collections/ansible_collections/ibm/spectrum_scale; fi; fi",
      # Ensure ansible-playbook is available
      "sudo ln -fs /usr/local/bin/ansible-playbook /usr/bin/ansible-playbook",
      # Copy backend file
      "sudo cp ${local.remote_backend_path} ${local.remote_terraform_path}",
      # Copy inputs file
      "sudo cp ${local.remote_inputs_path} ${local.remote_terraform_path}",
      "if [ ! -f /usr/local/bin/aws ]; then echo 'Installing AWS CLI for RHEL...'; curl -s \"https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip\" -o \"/tmp/awscliv2.zip\"; sudo yum install -y -q unzip; cd /tmp && unzip -q awscliv2.zip && sudo ./aws/install; rm -rf /tmp/awscliv2.zip /tmp/aws; fi",
      "echo 'Uploading tfvars backup to IBM COS to be used for destroy later...'",
      "sudo bash -c 'source /tmp/tf_env.sh && /usr/local/bin/aws --endpoint-url=https://s3.${local.safe_state_bucket_region}.cloud-object-storage.appdomain.cloud s3 cp ${local.remote_inputs_path} s3://${local.safe_state_bucket}/${var.cluster_prefix}/terraform.tfvars.json'",
      # Run Terraform init and apply
      "sudo bash -c 'source /tmp/tf_env.sh && export TF_LOG=\"${var.TF_LOG}\" && terraform -chdir=${local.remote_terraform_path} init'",
      "sudo bash -c 'source /tmp/tf_env.sh && export TF_LOG=\"${var.TF_LOG}\" && terraform -chdir=${local.remote_terraform_path} apply -parallelism=${var.TF_PARALLELISM} -auto-approve -lock=false; EXIT_CODE=$?; echo \"Terraform apply exit code: $EXIT_CODE\"; echo $EXIT_CODE | sudo tee /tmp/tf_apply_exit_code > /dev/null; exit 0'",
      "sudo bash -c 'if [ -f ${local.remote_terraform_path}/modules/ansible-roles/all.json ]; then source /tmp/tf_env.sh && /usr/local/bin/aws --endpoint-url=https://s3.${local.safe_state_bucket_region}.cloud-object-storage.appdomain.cloud s3 cp ${local.remote_terraform_path}/modules/ansible-roles/all.json s3://${local.safe_state_bucket}/${var.cluster_prefix}/all.json; else echo \"all.json not found, skipping upload.\"; fi'"
    ]
  }

  provisioner "remote-exec" {
    inline = [
      "if [ \"${var.debug_mode}\" = \"true\" ]; then",
      "  echo 'Debug mode detected: Skipping cleanup of sensitive files for debugging.'",
      "else",
      "  sudo rm -f /tmp/tf_env.sh",
      "  sudo rm -f /tmp/terraform_*.sh",
      "  echo 'Starting cleanup ...'",
      "  echo 'Deleting ${local.remote_inputs_path}'",
      "  sudo rm -f ${local.remote_inputs_path}",
      "  echo 'Deleting ${local.remote_terraform_path}/terraform.tfvars.json'",
      "  sudo rm -f ${local.remote_terraform_path}/terraform.tfvars.json",
      "  echo 'Deleting ${local.remote_terraform_path}/modules/ansible-roles/all.json'",
      "  sudo rm -f ${local.remote_terraform_path}/modules/ansible-roles/all.json",
      "  echo 'Securely shredding unencrypted SSH keys from disk...'",
      "  sudo find ${local.deployer_path} -type f -name '*id_rsa' -exec shred -u {} \\;",
      "  echo 'Cleanup finished'",
      "fi"
    ]
  }

  provisioner "remote-exec" {
    inline = [
      "EXIT_CODE=$( [ -f /tmp/tf_apply_exit_code ] && cat /tmp/tf_apply_exit_code || echo 1 )",
      "echo \"Terraform apply exit code: $EXIT_CODE\"",
      "if [ \"$EXIT_CODE\" -ne 0 ]; then echo '❌ Terraform apply failed'; exit 1; else echo '✅ Terraform apply succeeded'; fi"
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
  count = var.enable_deployer == true ? 1 : 0

  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    command = <<EOT
      ssh -o StrictHostKeyChecking=no -o ControlMaster=no -o UserKnownHostsFile=/dev/null \
          -o ProxyCommand="ssh -o StrictHostKeyChecking=no -o ControlMaster=no -o UserKnownHostsFile=/dev/null -i ${local.ssh_key_file} ubuntu@${var.bastion_fip} -W ${var.deployer_ip}:22" \
          -i ${local.ssh_key_file} \
          vpcuser@${var.deployer_ip} \
          "sudo chmod 644 /opt/ibm/terraform-ibm-hpc/solutions/${local.products}/*.ini && sudo chown vpcuser:vpcuser /opt/ibm/terraform-ibm-hpc/solutions/${local.products}/*.ini"

      scp -o StrictHostKeyChecking=no -o ControlMaster=no -o UserKnownHostsFile=/dev/null \
          -o ProxyCommand="ssh -o StrictHostKeyChecking=no -o ControlMaster=no -o UserKnownHostsFile=/dev/null -i ${local.ssh_key_file} ubuntu@${var.bastion_fip} -W ${var.deployer_ip}:22" \
          -i ${local.ssh_key_file} \
          vpcuser@${var.deployer_ip}:/opt/ibm/terraform-ibm-hpc/solutions/${local.products}/*.ini \
          "${path.root}/../../solutions/${local.products}/"
    EOT
    quiet   = true
  }
  depends_on = [resource.null_resource.tf_resource_provisioner]
}

resource "null_resource" "stop_deployer_node" {
  count = var.enable_deployer == true ? 1 : 0

  # This ensures the stop command runs on EVERY terraform apply
  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]

    environment = {
      IBMCLOUD_API_KEY       = var.ibmcloud_api_key
      IBMCLOUD_VERSION_CHECK = "false"
      IBMCLOUD_HOME          = "/tmp/ibmcloud_workspace"
    }

    command = <<-EOT
      mkdir -p /tmp/ibmcloud_workspace
      echo "All tasks complete! Logging in to stop the instance..."
      if ibmcloud plugin show vpc-infrastructure &>/dev/null; then
        echo "✅ vpc-infrastructure plugin is already active and healthy."
      else
        echo "⚠️ Plugin missing or unregistered. Performing clean installation..."
        rm -rf /tmp/ibmcloud_workspace/.bluemix/plugins/vpc-infrastructure
        ibmcloud plugin install vpc-infrastructure -f
      fi
      ibmcloud login -r ${var.region} -q

      echo "🛑 Stopping the deployer node..."
      ibmcloud is instance-stop ${var.deployer_instance_id} --force
    EOT
  }

  # CRITICAL: This tells Terraform to wait until the fetch is completely finished before stopping the node
  depends_on = [
    null_resource.tf_resource_provisioner,
    null_resource.fetch_host_details_from_deployer
  ]
}

resource "null_resource" "cleanup_ini_files" {
  count = var.enable_deployer == true ? 1 : 0

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
    conn_remote_inputs_path    = local.remote_inputs_path
    conn_terraform_log_level   = var.TF_LOG
    aws_access_key_id          = local.safe_hmac_params[0].akey
    aws_secret_access_key      = local.safe_hmac_params[0].skey
    conn_region                = var.region
    conn_deployer_instance_id  = var.deployer_instance_id
    conn_state_bucket          = local.safe_state_bucket
    conn_state_bucket_region   = local.safe_state_bucket_region
    conn_cluster_prefix        = var.cluster_prefix
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

  # 1. WAKE UP THE DEPLOYER NODE FOR DESTROY
  provisioner "local-exec" {
    when        = destroy
    interpreter = ["/bin/bash", "-c"]

    environment = {
      IBMCLOUD_API_KEY       = self.triggers.conn_ibmcloud_api_key
      IBMCLOUD_VERSION_CHECK = "false"
      IBMCLOUD_HOME          = "/tmp/ibmcloud_workspace"
    }

    command = <<-EOT
      mkdir -p /tmp/ibmcloud_workspace
      echo "Logging into IBM Cloud securely for destroy..."
      if ibmcloud plugin show vpc-infrastructure &>/dev/null; then
        echo "✅ vpc-infrastructure plugin is already active and healthy."
      else
        echo "⚠️ Plugin missing or unregistered. Performing clean installation..."
        rm -rf /tmp/ibmcloud_workspace/.bluemix/plugins/vpc-infrastructure
        ibmcloud plugin install vpc-infrastructure -f
      fi
      ibmcloud login -r ${self.triggers.conn_region} -q

      echo "Checking status for instance: ${self.triggers.conn_deployer_instance_id}..."
      STATUS=$(ibmcloud is instance ${self.triggers.conn_deployer_instance_id} | grep -i "^Status" | awk '{print $2}' | tr '[:upper:]' '[:lower:]')

      echo "Current status is: $STATUS"

      if [ "$STATUS" == "running" ]; then
        echo "✅ Instance is already running. Proceeding with destroy operations."
      elif [ "$STATUS" == "stopped" ]; then
        echo "⏳ Instance is stopped. Waking it up so we can SSH in..."
        ibmcloud is instance-start ${self.triggers.conn_deployer_instance_id}
      else
        echo "⚠️ Instance is in transition state: $STATUS. Forcing start command..."
        ibmcloud is instance-start ${self.triggers.conn_deployer_instance_id} --force || echo "Command failed or ignored."
      fi
    EOT
  }

  provisioner "remote-exec" {
    when = destroy
    inline = [
      <<-EOT
      sudo rm -f /tmp/tf_env.sh
      sudo rm -f /tmp/tf_destroy_exit_code
      sudo bash -c 'cat > /tmp/tf_env.sh <<EOF
  export AWS_ACCESS_KEY_ID="${self.triggers.aws_access_key_id}"
  export AWS_SECRET_ACCESS_KEY="${self.triggers.aws_secret_access_key}"
  EOF'
      sudo chmod 600 /tmp/tf_env.sh
      EOT
    ]
  }

  provisioner "remote-exec" {
    when = destroy
    inline = [
      "if [ ! -f /usr/local/bin/aws ]; then echo 'Installing AWS CLI for RHEL...'; curl -s \"https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip\" -o \"/tmp/awscliv2.zip\"; sudo yum install -y -q unzip; cd /tmp && unzip -q awscliv2.zip && sudo ./aws/install; rm -rf /tmp/awscliv2.zip /tmp/aws; fi",
      "sudo bash -c 'source /tmp/tf_env.sh && /usr/local/bin/aws --endpoint-url=https://s3.${self.triggers.conn_state_bucket_region}.cloud-object-storage.appdomain.cloud s3 cp s3://${self.triggers.conn_state_bucket}/${self.triggers.conn_cluster_prefix}/terraform.tfvars.json ${self.triggers.conn_remote_terraform_path}/terraform.tfvars.json'",
      "sudo bash -c 'if [ -d \"${self.triggers.conn_remote_terraform_path}\" ]; then source /tmp/tf_env.sh && export TF_LOG=\"${self.triggers.conn_terraform_log_level}\" && terraform -chdir=${self.triggers.conn_remote_terraform_path} destroy -auto-approve -lock=false; EXIT_CODE=$?; else echo \"Skipping destroy because ${self.triggers.conn_remote_terraform_path} is not a directory.\"; EXIT_CODE=0; fi; echo \"Terraform destroy exit code: $EXIT_CODE\"; echo $EXIT_CODE | sudo tee /tmp/tf_destroy_exit_code > /dev/null; exit 0'"
    ]
  }

  provisioner "remote-exec" {
    when = destroy
    inline = [
      "sudo rm -f /tmp/tf_env.sh",
      "sudo rm -f /tmp/terraform_*.sh",
      "echo 'Starting cleanup of tfvars files...'",
      "echo 'Deleting ${self.triggers.conn_remote_inputs_path}'",
      "sudo rm -f ${self.triggers.conn_remote_inputs_path}",
      "echo 'Deleting ${self.triggers.conn_remote_terraform_path}/terraform.tfvars.json'",
      "sudo rm -f ${self.triggers.conn_remote_terraform_path}/terraform.tfvars.json",
      "echo 'Cleanup finished'"
    ]
  }

  provisioner "remote-exec" {
    when = destroy
    inline = [
      "EXIT_CODE=$( [ -f /tmp/tf_destroy_exit_code ] && cat /tmp/tf_destroy_exit_code || echo 1 )",
      "echo \"Terraform destroy exit code: $EXIT_CODE\"",
      "if [ \"$EXIT_CODE\" -ne 0 ]; then echo '❌ Terraform destroy failed'; exit 1; else echo '✅ Terraform destroy succeeded'; fi"
    ]
  }
}
