locals {
  proxyjump                        = var.enable_deployer ? "-o ProxyJump=ubuntu@${var.bastion_fip}" : ""
  common_config_playbook           = format("%s/common_config_playbook.yml", var.playbooks_path)
  pre_lsf_config_playbook          = format("%s/pre_lsf_config_playbook.yml", var.playbooks_path)
  login_node_playbook              = format("%s/login_node_configuration.yml", var.playbooks_path)
  lsf_post_config_playbook         = format("%s/lsf_post_config_playbook.yml", var.playbooks_path)
  ldap_server_inventory            = format("%s/ldap_server_inventory.ini", var.playbooks_path)
  configure_ldap_client            = format("%s/configure_ldap_client.yml", var.playbooks_path)
  prepare_ldap_server              = format("%s/prepare_ldap_server.yml", var.playbooks_path)
  deployer_hostentry_playbook_path = format("%s/deployer_host_entry_play.yml", var.playbooks_path)
  lsf_hostentry_playbook_path      = format("%s/lsf_host_entry_play.yml", var.playbooks_path)
  remove_hostentry_playbooks_path  = format("%s/remove_host_entry_play.yml", var.playbooks_path)
  lsf_prerequesite_playbook_path   = format("%s/lsf_prerequesite_play.yml", var.playbooks_path)
  deployer_host                    = jsonencode(var.deployer_host)
  mgmnt_hosts                      = jsonencode(var.mgmnt_hosts)
  comp_hosts                       = jsonencode(var.comp_hosts)
  login_host                       = jsonencode(var.login_host)
  # domain_name                      = var.domain_name
}

resource "local_file" "deployer_host_entry_play" {
  count    = var.inventory_path != null && var.scheduler == "LSF" ? 1 : 0
  content  = <<EOT
---
- name: Manage /etc/hosts with dynamic host-IP mappings
  hosts: localhost
  connection: local
  become: yes
  vars:
    mgmnt_hosts: '{}'
    comp_hosts: '{}'
    login_host: '{}'
    hosts_file: /etc/hosts

  pre_tasks:
    - name: Load cluster-specific variables
      ansible.builtin.include_vars:
        file: all.json

  tasks:
    - name: Parse and merge host mappings
      ansible.builtin.set_fact:
        all_hosts: >-
          {{ {} | combine(mgmnt_hosts | from_json, comp_hosts | from_json, login_host | from_json) }}

    - name: Invert mapping to ensure 1 hostname = 1 IP (latest IP kept)
      ansible.builtin.set_fact:
        hostname_map: >-
          {{
            all_hosts
            | dict2items
            | reverse
            | items2dict(key_name='value', value_name='key')
          }}

    - name: Generate managed block content
      ansible.builtin.set_fact:
        managed_block: |
          {% for hostname, ip in hostname_map.items() -%}
          {{ ip }} {{ hostname }} {{ hostname }}.{{ domain_name }}
          {% endfor %}

    - name: Update /etc/hosts with managed entries
      ansible.builtin.blockinfile:
        path: "{{ hosts_file }}"
        marker: "# === ANSIBLE MANAGED HOSTS {mark} ==="
        block: "{{ managed_block }}"

    - name: Insert Create folder and Ensure js.conf lines
      ansible.builtin.blockinfile:
        path: /opt/ibm/lsf_installer/playbook/roles/deploy-gui/tasks/configure_pm_common.yml
        marker: "# {mark} MANAGED BLOCK FOR PM_CONF_DIR"
        insertbefore: "^\\- name: Update JS_HOST"
        block: |
          {% raw %}
          - name: Create folder from PM_CONF_DIR variable
            file:
              path: "{{ PM_CONF_DIR }}"
              state: directory
              mode: '0755'
          - name: Ensure js.conf file exists
            file:
              path: "{{ PM_CONF_DIR }}/js.conf"
              state: touch
              mode: '0644'
          {% endraw %}
EOT
  filename = local.deployer_hostentry_playbook_path
}

resource "null_resource" "deploy_host_playbook" {
  count = var.inventory_path != null && var.scheduler == "LSF" ? 1 : 0
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = "sudo ansible-playbook -f 200 -e 'mgmnt_hosts=${local.mgmnt_hosts}' -e 'comp_hosts=${local.comp_hosts}' -e 'login_host=${local.login_host}' -e 'domain_name=${var.domain_name}' '${local.deployer_hostentry_playbook_path}'"
  }

  triggers = {
    build = timestamp()
  }
  depends_on = [local_file.deployer_host_entry_play]
}

resource "local_file" "lsf_host_entry_playbook" {
  count    = var.inventory_path != null && var.scheduler == "LSF" ? 1 : 0
  content  = <<EOT
# Adding Host entries to all LSF Mangement and Compute nodes

- name: Check passwordless SSH connection is setup
  hosts: all
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

    - name: Wait for SSH (retry 5x)
      ansible.builtin.wait_for:
        port: 22
        host: [all_nodes]
        timeout: 60
        delay: 10
      retries: 5
      until: true
      delegate_to: localhost
      ignore_errors: yes

    - name: Check passwordless SSH on all scale inventory hosts
      shell: echo PASSWDLESS_SSH_ENABLED
      register: result
      until: result.stdout.find("PASSWDLESS_SSH_ENABLED") != -1
      retries: 60
      delay: 10

- name: Manage /etc/hosts with dynamic host-IP mappings
  hosts: all
  become: yes
  vars:
    mgmnt_hosts: '{}'
    comp_hosts: '{}'
    login_host: '{}'
    deployer_host: '{}'
    hosts_file: /etc/hosts

  pre_tasks:
    - name: Load cluster-specific variables
      ansible.builtin.include_vars:
        file: all.json

  tasks:
    - name: Parse and merge host mappings
      ansible.builtin.set_fact:
        all_hosts: >-
          {{ {} | combine(mgmnt_hosts | from_json, comp_hosts | from_json, login_host | from_json, deployer_host | from_json) }}

    - name: Invert mapping to ensure 1 hostname = 1 IP (latest IP kept)
      ansible.builtin.set_fact:
        hostname_map: >-
          {{
            all_hosts
            | dict2items
            | reverse
            | items2dict(key_name='value', value_name='key')
          }}

    - name: Generate managed block content
      ansible.builtin.set_fact:
        managed_block: |
          {% for hostname, ip in hostname_map.items() -%}
          {{ ip }} {{ hostname }} {{ hostname }}.{{ domain_name }}
          {% endfor %}

    - name: Update /etc/hosts with managed entries
      ansible.builtin.blockinfile:
        path: "{{ hosts_file }}"
        marker: "# === ANSIBLE MANAGED HOSTS {mark} ==="
        block: "{{ managed_block }}"
EOT
  filename = local.lsf_hostentry_playbook_path
}

resource "null_resource" "lsf_host_play" {
  count = var.inventory_path != null && var.scheduler == "LSF" ? 1 : 0
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = "sudo ansible-playbook -f 50 -e 'deployer_host=${local.deployer_host}' -e 'mgmnt_hosts=${local.mgmnt_hosts}' -e 'comp_hosts=${local.comp_hosts}' -e 'login_host=${local.login_host}' -e 'domain_name=${var.domain_name}' -i ${var.inventory_path} '${local.lsf_hostentry_playbook_path}'"
  }

  triggers = {
    build = timestamp()
  }
  depends_on = [null_resource.deploy_host_playbook, local_file.lsf_host_entry_playbook]
}

resource "local_file" "create_common_config_playbook" {
  count    = var.inventory_path != null && var.scheduler == "LSF" ? 1 : 0
  content  = <<EOT
# Ensure provisioned VMs are up and Passwordless SSH setup has been established

- name: Prerequisite Configuration
  hosts: all
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
     - { role: vpc_fileshare_config }
     - { role: lsf_prereq_config }
EOT
  filename = local.common_config_playbook
}

resource "null_resource" "run_common_config_playbook" {
  count = var.inventory_path != null && var.scheduler == "LSF" ? 1 : 0
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = "sudo ansible-playbook -f 200 -i ${var.inventory_path} ${local.common_config_playbook}"
  }
  triggers = {
    build = timestamp()
  }
  depends_on = [local_file.create_common_config_playbook, null_resource.lsf_host_play]
}

resource "local_file" "create_pre_lsf_config_playbook" {
  count    = var.inventory_path != null && var.scheduler == "LSF" ? 1 : 0
  content  = <<EOT
# Ensure provisioned VMs are up and Passwordless SSH setup has been established

- name: Prerequisite Configuration
  hosts: [mgmt_compute_nodes]
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
     - { role: lsf_template_config }
EOT
  filename = local.pre_lsf_config_playbook
}

resource "null_resource" "run_pre_lsf_config_playbook" {
  count = var.inventory_path != null && var.scheduler == "LSF" ? 1 : 0
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = "sudo ansible-playbook -f 200 -i ${var.inventory_path} ${local.pre_lsf_config_playbook}"
  }
  triggers = {
    build = timestamp()
  }
  depends_on = [local_file.create_pre_lsf_config_playbook, null_resource.run_common_config_playbook]
}

resource "local_file" "lsf_prerequesite_playbook" {
  count    = var.inventory_path != null && var.scheduler == "LSF" && var.enable_dedicated_host ? 1 : 0
  content  = <<EOT
---
- name: Install bc package on RHEL 8/9 hosts
  hosts: all
  become: yes
  vars:
    rpm_urls:
      "8": "https://vault.centos.org/8-stream/BaseOS/x86_64/os/Packages/bc-1.07.1-5.el8.x86_64.rpm"
      "9": "https://mirror.stream.centos.org/9-stream/BaseOS/x86_64/os/Packages/bc-1.07.1-14.el9.x86_64.rpm"
  tasks:
    - name: Check if bc is already installed
      command: rpm -q bc
      register: bc_check
      ignore_errors: yes
      changed_when: false
      failed_when: false
    - name: Get OS major version
      set_fact:
        os_major_version: "{{ ansible_distribution_major_version }}"
    - name: Download bc rpm if not installed
      get_url:
        url: "{{ rpm_urls[os_major_version | string] }}"
        dest: /tmp/bc.rpm
        mode: '0644'
      when: bc_check.rc != 0
    - name: Install bc rpm (GPG check disabled)
      yum:
        name: /tmp/bc.rpm
        state: present
        disable_gpg_check: true
      when: bc_check.rc != 0
    - name: Clean up rpm file
      file:
        path: /tmp/bc.rpm
        state: absent
      when: bc_check.rc != 0
    - name: Confirm bc is installed
      debug:
        msg: "bc installed successfully or already present"
EOT
  filename = local.lsf_prerequesite_playbook_path
}

resource "null_resource" "lsf_prerequesite_play" {
  count = var.inventory_path != null && var.scheduler == "LSF" && var.enable_dedicated_host ? 1 : 0
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = "sudo ansible-playbook -f 50 -i ${var.inventory_path} '${local.lsf_prerequesite_playbook_path}'"
  }

  triggers = {
    build = timestamp()
  }
  depends_on = [null_resource.run_pre_lsf_config_playbook, local_file.lsf_prerequesite_playbook]
}

resource "null_resource" "run_lsf_playbooks" {
  count = var.inventory_path != null && var.scheduler == "LSF" ? 0 : 0

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<EOT
      sudo ansible-playbook -f 200 -i /opt/ibm/lsf_installer/playbook/lsf-inventory /opt/ibm/lsf_installer/playbook/lsf-config-test.yml &&
      sudo ansible-playbook -f 200 -i /opt/ibm/lsf_installer/playbook/lsf-inventory /opt/ibm/lsf_installer/playbook/lsf-predeploy-test.yml &&
      sudo ansible-playbook -f 200 -i /opt/ibm/lsf_installer/playbook/lsf-inventory /opt/ibm/lsf_installer/playbook/lsf-deploy.yml
    EOT
  }

  triggers = {
    build = timestamp()
  }

  depends_on = [null_resource.lsf_prerequesite_play]
}

resource "local_file" "create_playbook_for_mgmt_config" {
  count    = var.inventory_path != null && var.scheduler == "LSF" ? 1 : 0
  content  = <<EOT
- name: Prerequisite Configuration
  hosts: [mgmt_compute_nodes]
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
     - { role: lsf_mgmt_config }
EOT
  filename = var.lsf_mgmt_playbooks_path
}


resource "null_resource" "run_playbook_for_mgmt_config" {
  count = var.inventory_path != null && var.scheduler == "LSF" ? 0 : 0
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = "sudo ansible-playbook -f 200 -i ${var.inventory_path} ${var.lsf_mgmt_playbooks_path}"
  }
  triggers = {
    build = timestamp()
  }
  depends_on = [local_file.create_playbook_for_mgmt_config, null_resource.run_lsf_playbooks]
}

resource "local_file" "create_playbook_for_login_node_config" {
  count    = var.inventory_path != null && var.scheduler == "LSF" ? 1 : 0
  content  = <<EOT
- name: Prerequisite Configuration
  hosts: [login_node]
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
     - { role: lsf_login_config }
EOT
  filename = local.login_node_playbook
}


resource "null_resource" "run_playbook_for_login_node_config" {
  count = var.inventory_path != null && var.scheduler == "LSF" ? 0 : 0
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = "sudo ansible-playbook -f 200 -i ${var.inventory_path} ${local.login_node_playbook}"
  }
  triggers = {
    build = timestamp()
  }
  depends_on = [local_file.create_playbook_for_mgmt_config, null_resource.run_lsf_playbooks]
}

resource "local_file" "create_playbook_for_post_deploy_config" {
  count    = var.inventory_path != null && var.scheduler == "LSF" ? 1 : 0
  content  = <<EOT
- name: Prerequisite Configuration
  hosts: all
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
     - { role: lsf_post_config }
EOT
  filename = local.lsf_post_config_playbook
}


resource "null_resource" "run_playbook_post_deploy_config" {
  count = var.inventory_path != null && var.scheduler == "LSF" ? 0 : 0
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = "sudo ansible-playbook -f 200 -i ${var.inventory_path} ${local.lsf_post_config_playbook}"
  }
  triggers = {
    build = timestamp()
  }
  depends_on = [local_file.create_playbook_for_post_deploy_config, null_resource.run_playbook_for_mgmt_config, null_resource.run_playbook_for_login_node_config]
}

resource "local_file" "prepare_ldap_server_playbook" {
  count    = local.ldap_server_inventory != null && var.enable_ldap && var.ldap_server == "null" && var.scheduler == "LSF" ? 1 : 0
  content  = <<EOT
- name: LDAP Server Configuration
  hosts: [ldap_server_node]
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
    - { role: ldap_server_prepare }
EOT
  filename = local.prepare_ldap_server
}

resource "null_resource" "configure_ldap_server_playbook" {
  count = local.ldap_server_inventory != null && var.enable_ldap && var.ldap_server == "null" && var.scheduler == "LSF" ? 1 : 0

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = "sudo ansible-playbook -i ${local.ldap_server_inventory} ${local.prepare_ldap_server}"
  }
  triggers = {
    build = timestamp()
  }
  depends_on = [local_file.prepare_ldap_server_playbook]
}

resource "local_file" "prepare_ldap_client_playbook" {
  count    = var.inventory_path != null && var.enable_ldap && var.scheduler == "LSF" ? 1 : 0
  content  = <<EOT
- name: LDAP Server Configuration
  hosts: all
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
    - { role: ldap_client_config }
EOT
  filename = local.configure_ldap_client
}

resource "null_resource" "run_ldap_client_playbooks" {
  count = var.inventory_path != null && var.enable_ldap && var.scheduler == "LSF" ? 1 : 0

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = "sudo ansible-playbook -f 200 -i ${var.inventory_path} ${local.configure_ldap_client}"
  }
  triggers = {
    build = timestamp()
  }
  depends_on = [local_file.prepare_ldap_client_playbook, null_resource.configure_ldap_server_playbook, null_resource.run_playbook_for_mgmt_config]
}

resource "null_resource" "export_api" {
  count = (var.cloudlogs_provision && var.scheduler == "LSF") || var.scheduler == "Scale" ? 1 : 0
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
  count    = var.inventory_path != null && var.observability_provision && var.scheduler == "LSF" ? 1 : 0
  content  = <<EOT
- name: Cloud Logs Configuration
  hosts: [mgmt_compute_nodes]
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
  hosts: [mgmt_compute_nodes]
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
  count = var.inventory_path != null && var.observability_provision && var.scheduler == "LSF" ? 1 : 0

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = "sudo ansible-playbook -f 200 -i ${var.inventory_path} ${var.observability_playbook_path}"
  }
  triggers = {
    build = timestamp()
  }
  depends_on = [null_resource.export_api]
}

resource "local_file" "remove_host_entry_playbook" {
  count    = var.inventory_path != null && var.scheduler == "LSF" ? 1 : 0
  content  = <<EOT
---
- name: Remove managed host entries from /etc/hosts
  hosts: all
  connection: local
  become: yes
  vars:
    hosts_file: /etc/hosts

  tasks:
    - name: Remove managed block from /etc/hosts
      ansible.builtin.blockinfile:
        path: "{{ hosts_file }}"
        marker: "# === ANSIBLE MANAGED HOSTS {mark} ==="
        state: absent
EOT
  filename = local.remove_hostentry_playbooks_path
}


resource "null_resource" "remove_host_entry_play" {
  count = var.inventory_path != null && var.scheduler == "LSF" ? 0 : 0
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = "sudo ansible-playbook -i ${var.inventory_path} ${local.remove_hostentry_playbooks_path}"
  }
  triggers = {
    build = timestamp()
  }
  depends_on = [local_file.remove_host_entry_playbook, null_resource.run_playbook_for_mgmt_config, null_resource.run_ldap_client_playbooks]
}
