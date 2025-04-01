locals {
  proxyjump = var.enable_bastion ? "-o ProxyJump=ubuntu@${var.bastion_fip}" : ""
}

resource "local_file" "create_playbook" {
  count    = var.inventory_path != null ? 1 : 0
  content  = <<EOT
# Ensure provisioned VMs are up and Passwordless SSH setup has been established

- name: Check passwordless SSH connection is setup
  hosts: [all_nodes]
  any_errors_fatal: true
  gather_facts: false
  vars:
    ansible_ssh_common_args: >
      ${local.proxyjump}
      -o ControlMaster=auto
      -o ControlPersist=30m
      -o UserKnownHostsFile=/dev/null
      -o StrictHostKeyChecking=no
    ansible_user: root
    ansible_ssh_private_key_file: ${var.private_key_path}
  tasks:
    - name: Check passwordless SSH on all scale inventory hosts
      shell: echo PASSWDLESS_SSH_ENABLED
      register: result
      until: result.stdout.find("PASSWDLESS_SSH_ENABLED") != -1
      retries: 60
      delay: 10

- name: Prerequisite Configuration
  hosts: [all_nodes]
  any_errors_fatal: true
  gather_facts: false
  vars:
    ansible_ssh_common_args: >
      ${local.proxyjump}
      -o ControlMaster=auto
      -o ControlPersist=30m
      -o UserKnownHostsFile=/dev/null
      -o StrictHostKeyChecking=no
    ansible_user: root
    ansible_ssh_private_key_file: ${var.private_key_path}
  pre_tasks:
    - name: Load cluster-specific variables
      include_vars: all.json
  roles:
     - vpc_fileshare_configure
     - lsf
EOT
  filename = var.playbook_path
}

resource "null_resource" "run_playbook" {
  count = var.inventory_path != null ? 1 : 0
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = "ansible-playbook -f 50 -i ${var.inventory_path} ${var.playbook_path}"
  }
  triggers = {
    build = timestamp()
  }
  depends_on = [local_file.create_playbook]
}

resource "null_resource" "run_lsf_playbooks" {
  count = var.inventory_path != null ? 1 : 0

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<EOT
      sudo ansible-playbook -f 50 -i /opt/ibm/lsf_installer/playbook/lsf-inventory /opt/ibm/lsf_installer/playbook/lsf-config-test.yml &&
      sudo ansible-playbook -f 50 -i /opt/ibm/lsf_installer/playbook/lsf-inventory /opt/ibm/lsf_installer/playbook/lsf-predeploy-test.yml &&
      sudo ansible-playbook -f 50 -i /opt/ibm/lsf_installer/playbook/lsf-inventory /opt/ibm/lsf_installer/playbook/lsf-deploy.yml
    EOT
  }

  triggers = {
    build = timestamp()
  }

  depends_on = [null_resource.run_playbook]
}

resource "null_resource" "export_api" {
  count = var.inventory_path != null && var.observability_provision ? 1 : 0
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<EOT
      export VPC_API_KEY="${var.ibmcloud_api_key}"
      echo "$VPC_API_KEY" | tee /opt/ibm/temp_file.txt
    EOT
  }
  triggers = {
    build = timestamp()
  }
  depends_on = [null_resource.run_lsf_playbooks]
}

resource "local_file" "create_observability_playbook" {
  count    = var.inventory_path != null && var.observability_provision ? 1 : 0
  content  = <<EOT
- name: Cloud Logs Configuration
  hosts: [all_nodes]
  any_errors_fatal: true
  gather_facts: true
  vars:
    ansible_ssh_common_args: >
      ${local.proxyjump}
      -o ControlMaster=auto
      -o ControlPersist=30m
      -o UserKnownHostsFile=/dev/null
      -o StrictHostKeyChecking=no
    ansible_user: root
    ansible_ssh_private_key_file: ${var.private_key_path}
  roles:
    - { role: cloudlogs, tags: ["cloud_logs"] }

- name: Cloud Monitoring Configuration
  hosts: [all_nodes]
  any_errors_fatal: true
  gather_facts: true
  vars:
    ansible_ssh_common_args: >
      ${local.proxyjump}
      -o ControlMaster=auto
      -o ControlPersist=30m
      -o UserKnownHostsFile=/dev/null
      -o StrictHostKeyChecking=no
    ansible_user: root
    ansible_ssh_private_key_file: ${var.private_key_path}
  roles:
    - { role: cloudmonitoring, tags: ["cloud_monitoring"] }
EOT
  filename = var.observability_playbook_path
}

resource "null_resource" "run_observability_playbooks" {
  count = var.inventory_path != null && var.observability_provision ? 1 : 0

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = "ansible-playbook -f 50 -i ${var.inventory_path} ${var.observability_playbook_path}"
  }
  triggers = {
    build = timestamp()
  }
  depends_on = [null_resource.export_api]
}
