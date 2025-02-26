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
  gather_facts: True
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
     - network_config
EOT
  filename = var.playbook_path
}

resource "null_resource" "run_playbook" {
  count = var.inventory_path != null ? 1 : 0
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = "ansible-playbook -i ${var.inventory_path} ${var.playbook_path}"
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
    command = <<EOT
      sudo ansible-playbook -i /opt/ibm/lsf_installer/playbook/lsf-inventory /opt/ibm/lsf_installer/playbook/lsf-config-test.yml &&
      sudo ansible-playbook -i /opt/ibm/lsf_installer/playbook/lsf-inventory /opt/ibm/lsf_installer/playbook/lsf-predeploy-test.yml &&
      sudo ansible-playbook -i /opt/ibm/lsf_installer/playbook/lsf-inventory /opt/ibm/lsf_installer/playbook/lsf-deploy.yml
    EOT
  }

  triggers = {
    build = timestamp()
  }

  depends_on = [null_resource.run_playbook]
}

resource "local_file" "create_playbook_for_management" {
  count    = var.inventory_path != null && var.enable_lsf ? 1 : 0
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
  gather_facts: True
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
     - lsf_server_config
EOT
  filename = "/opt/ibm/terraform-ibm-hpc/modules/ansible-roles/management_config.yml"
}

resource "null_resource" "run_playbook_management" {
  count = var.inventory_path != null && var.enable_lsf ? 1 : 0
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = "ansible-playbook -i ${var.inventory_path} '/opt/ibm/terraform-ibm-hpc/modules/ansible-roles/management_config.yml'"
  }
  triggers = {
    build = timestamp()
  }
  depends_on = [local_file.create_playbook]
}


resource "local_file" "create_playbook_for_management_configure" {
  count    = var.inventory_path != null && var.enable_lsf ? 1 : 0
  content  = <<EOT
# Ensure provisioned VMs are up and Passwordless SSH setup has been established

- name: Check passwordless SSH connection is setup
  hosts: "{{ groups['all_nodes'][0] }}"
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
  hosts: "{{ groups['all_nodes'][0] }}"
  any_errors_fatal: true
  gather_facts: True
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
     - lsf_mgmt_config
EOT
  filename = "/opt/ibm/terraform-ibm-hpc/modules/ansible-roles/management_server_config.yml"
}

resource "null_resource" "run_playbook_management_configure" {
  count = var.inventory_path != null && var.enable_lsf ? 1 : 0
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = "ansible-playbook -i ${var.inventory_path} '/opt/ibm/terraform-ibm-hpc/modules/ansible-roles/management_server_config.yml'"
  }
  triggers = {
    build = timestamp()
  }
  depends_on = [local_file.create_playbook]
}
