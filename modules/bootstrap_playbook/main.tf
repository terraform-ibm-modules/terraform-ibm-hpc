resource "local_file" "bootstrap_create_playbook" {
  count    = var.inventory_path != null ? 1 : 0
  content  = <<EOT

- name: Creating Landing zone VSI's and executing respective playbooks
  hosts: all
  any_errors_fatal: true
  gather_facts: false
  connection: local
  tasks:
    - name: Check passwordless SSH on the bootstrap host
      shell: echo PASSWDLESS_SSH_ENABLED
      register: result
      until: result.stdout.find("PASSWDLESS_SSH_ENABLED") != -1
      retries: 60
      delay: 10

    - name: Install required packages
      become: yes    
      package:
        name: 
          - git
          - wget
          - unzip
        state: present
        use: yum

    - name: Download and install Terraform
      become: yes
      get_url:
        url: https://releases.hashicorp.com/terraform/1.5.4/terraform_1.5.4_linux_amd64.zip
        dest: /tmp/terraform.zip      

    - name: Unzip Terraform
      become: yes
      shell: unzip -o /tmp/terraform.zip -d /usr/bin
      args:
        executable: /bin/bash

    - name: Clone Git repository
      become: yes 
      git:
        repo: "{{ git_repository }}"
        dest: /opt/IBM/terraform-ibm-hpc
        force: yes  

    - name: Change to the Git repository directory
      become: yes
      shell: cd /opt/IBM/terraform-ibm-hpc
      args:
        executable: /bin/bash     

    - name: Run Terraform init
      become: yes
      shell: terraform init
      args:
        executable: /bin/bash
      register: init_result

    - name: Check Terraform init output
      debug:
        var: init_result.stdout
      when: init_result.rc == 0           

  vars:
    git_repository: "https://github.com/terraform-ibm-modules/terraform-ibm-hpc"
    ansible_ssh_common_args: >-
      -o ControlMaster=auto
      -o ControlPersist=30m
      -o UserKnownHostsFile=/dev/null
      -o StrictHostKeyChecking=no
      -o ProxyCommand="ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ${var.private_key_path} -J ubuntu@${var.bastion_fip} -W %h:%p root@{{ inventory_hostname }}"
EOT
  filename = var.playbook_path
}

resource "ansible_playbook" "bootstrap_playbook" {
  playbook   = var.playbook_path
  name       = "localhost"
  replayable = false
  verbosity  = 6
  extra_vars = {
    ansible_python_interpreter = "auto"
  }
  depends_on = [local_file.bootstrap_create_playbook]
}
