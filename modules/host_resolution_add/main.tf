resource "local_file" "scale_cluster_hosts" {
  filename = local.scale_cluster_hosts
  content = yamlencode({
    storage_hosts        = var.storage_hosts
    storage_mgmnt_hosts  = var.storage_mgmnt_hosts
    storage_tb_hosts     = var.storage_tb_hosts
    compute_hosts        = var.compute_hosts
    compute_mgmnt_hosts  = var.compute_mgmnt_hosts
    client_hosts         = var.client_hosts
    protocol_hosts       = var.protocol_hosts
    gklm_hosts           = var.gklm_hosts
    afm_hosts            = var.afm_hosts
    storage_bms_hosts    = var.storage_bms_hosts
    storage_tb_bms_hosts = var.storage_tb_bms_hosts
    protocol_bms_hosts   = var.protocol_bms_hosts
    afm_bms_hosts        = var.afm_bms_hosts
  })
}

resource "local_file" "domain_file" {
  filename = local.domain_name_file

  content = yamlencode({
    domain_names = {
      compute  = try(var.domain_names.compute, null)
      storage  = try(var.domain_names.storage, null)
      protocol = try(var.domain_names.protocol, null)
      client   = try(var.domain_names.client, null)
      gklm     = try(var.domain_names.gklm, null)
    }
  })
}

resource "local_file" "deployer_host_entry_playbook" {
  count    = var.scheduler == "Scale" ? 1 : 0
  content  = <<EOT
---
- name: Add host entries from custom YAML to /etc/hosts
  hosts: localhost
  gather_facts: no

  vars:
    all_host_groups:
      client_hosts: "client"
      compute_hosts: "compute"
      gklm_hosts: "gklm"
      protocol_hosts: "protocol"
      storage_hosts: "storage"
      storage_bms_hosts: "storage"
      storage_tb_hosts: "storage"
      storage_tb_bms_hosts: "storage"
      storage_mgmnt_hosts: "storage"
      compute_mgmnt_hosts: "compute"
      afm_hosts: "client"
      afm_bms_hosts: "client"
      protocol_bms_hosts: "protocol"

  tasks:

    - name: Initialize merged_hosts
      set_fact:
        merged_hosts: []

    - name: Collect hosts with domains
      set_fact:
        merged_hosts: "{{ merged_hosts + query('dict', lookup('vars', item.key, default={})) | map('combine', {'group': item.value}) | list }}"
      loop: "{{ all_host_groups | dict2items }}"

    - name: Generate /etc/hosts entries with group-specific domains
      blockinfile:
        path: /etc/hosts
        marker: "# === ANSIBLE MANAGED HOSTS {mark} ==="
        block: |
          {% for item in merged_hosts if item.value != {} %}
          {% set shortname = item.value.name | default(item.value) %}
          {% set fqdn = shortname + '.' + domain_names[item.group] %}
          {{ item.key }} {{ fqdn }} {{ shortname }}
          {% endfor %}
EOT
  filename = local.deployer_hostentry_playbook_path
}

resource "null_resource" "deploy_host_playbook" {
  count = var.scheduler == "Scale" ? 1 : 0
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = "sudo ansible-playbook -f 50 -e @${local.scale_cluster_hosts} -e @${local.domain_name_file} '${local.deployer_hostentry_playbook_path}'"
  }

  triggers = {
    build = timestamp()
  }
  depends_on = [local_file.scale_cluster_hosts, local_file.deployer_host_entry_playbook]
}

resource "local_file" "ansible_inventory" {
  count    = var.scheduler == "Scale" ? 1 : 0
  filename = local.scale_all_inventory

  content = join("\n", compact(flatten([

    # STORAGE
    length(flatten([
      values(local.normalize_hosts.storage_hosts),
      values(local.normalize_hosts.storage_tb_hosts),
      values(local.normalize_hosts.storage_bms_hosts),
      values(local.normalize_hosts.storage_tb_bms_hosts),
      values(local.normalize_hosts.storage_mgmnt_hosts),
      values(local.normalize_hosts.afm_bms_hosts),
      values(local.normalize_hosts.afm_hosts),
      values(local.normalize_hosts.protocol_bms_hosts),
      values(local.normalize_hosts.protocol_hosts),
      ])) > 0 ? [
      "[storage]",
      join("\n", flatten([
        # Non-persistent storage hosts
        [
          for host in flatten([
            values(local.normalize_hosts.storage_hosts),
            values(local.normalize_hosts.storage_tb_hosts),
            values(local.normalize_hosts.storage_mgmnt_hosts),
            values(local.normalize_hosts.afm_hosts),
            values(local.normalize_hosts.protocol_hosts)
          ]) : "${host.name} ansible_ssh_private_key_file=${local.storage_private_key} storage_type=scratch"
        ],
        # Persistent storage hosts
        [
          for host in flatten([
            values(local.normalize_hosts.storage_bms_hosts),
            values(local.normalize_hosts.storage_tb_bms_hosts),
            values(local.normalize_hosts.afm_bms_hosts)
          ]) : "${host.name} id=${host.id} ansible_ssh_private_key_file=${local.storage_private_key} storage_type=persistent bms_boot_drive_encryption=${var.bms_boot_drive_encryption}"
        ],
        # Protocol BMS hosts
        [
          for host in values(local.normalize_hosts.protocol_bms_hosts) :
          "${host.name} id=${host.id} ansible_ssh_private_key_file=${local.storage_private_key} storage_type=persistent scale_protocol_node=true bms_boot_drive_encryption=${var.bms_boot_drive_encryption}"
        ]
      ])),
      ""
    ] : [],

    # COMPUTE
    length(flatten([
      values(local.normalize_hosts.compute_hosts),
      values(local.normalize_hosts.compute_mgmnt_hosts)
      ])) > 0 ? [
      "[compute]",
      join("\n", [
        for host in flatten([
          values(local.normalize_hosts.compute_hosts),
          values(local.normalize_hosts.compute_mgmnt_hosts)
        ]) : "${host.name} ansible_ssh_private_key_file=${local.compute_private_key}"
      ]),
      ""
    ] : [],

    # CLIENT
    length(values(local.normalize_hosts.client_hosts)) > 0 ? [
      "[client]",
      join("\n", [
        for host in values(local.normalize_hosts.client_hosts) :
        "${host.name} ansible_ssh_private_key_file=${local.client_private_key}"
      ]),
      ""
    ] : [],

    # GKLM
    length(values(local.normalize_hosts.gklm_hosts)) > 0 ? [
      "[gklm]",
      join("\n", [
        for host in values(local.normalize_hosts.gklm_hosts) :
        "${host.name} ansible_ssh_private_key_file=${local.gklm_private_key}"
      ]),
      ""
    ] : []

  ])))
}

resource "local_file" "scale_host_entry_playbook" {
  count    = var.scheduler == "Scale" ? 1 : 0
  content  = <<EOT
---
- name: Ensure all hosts are reachable via SSH and manage /etc/hosts
  hosts: all
  become: yes
  gather_facts: no

  vars:
    all_host_groups:
      client_hosts: "client"
      compute_hosts: "compute"
      gklm_hosts: "gklm"
      protocol_hosts: "protocol"
      storage_hosts: "storage"
      storage_bms_hosts: "storage"
      storage_tb_hosts: "storage"
      storage_tb_bms_hosts: "storage"
      storage_mgmnt_hosts: "storage"
      compute_mgmnt_hosts: "compute"
      afm_hosts: "client"
      afm_bms_hosts: "client"
      protocol_bms_hosts: "protocol"

  tasks:

    - name: Initialize merged_hosts
      set_fact:
        merged_hosts: []

    - name: Collect hosts with domains
      set_fact:
        merged_hosts: "{{ merged_hosts + query('dict', lookup('vars', item.key, default={})) | map('combine', {'group': item.value}) | list }}"
      loop: "{{ all_host_groups | dict2items }}"

    - name: Generate /etc/hosts entries with group-specific domains
      blockinfile:
        path: /etc/hosts
        marker: "# === ANSIBLE MANAGED HOSTS {mark} ==="
        block: |
          {% for item in merged_hosts if item.value != {} %}
          {% set shortname = item.value.name | default(item.value) %}
          {% set fqdn = shortname + '.' + domain_names[item.group] %}
          {{ item.key }} {{ fqdn }} {{ shortname }}
          {% endfor %}
EOT
  filename = local.scale_hostentry_playbook_path
}


resource "local_file" "scale_baremetal_prerequesite_vars" {
  filename = local.scale_baremetal_prerequesite_vars
  content = yamlencode({
    storage_interface         = var.storage_interface
    protocol_interface        = var.protocol_interface
    enable_protocol           = var.enable_protocol
    vpc_region                = var.vpc_region
    resource_group            = var.resource_group
    protocol_subnet           = var.protocol_subnets
    storage_domain            = local.storage_domain
    protocol_domain           = local.protocol_domain
    ibmcloud_api_key          = var.ibmcloud_api_key
    bms_boot_drive_encryption = var.bms_boot_drive_encryption
    storage_type              = var.storage_type
  })
}

resource "local_file" "remove_host_entry_playbook" {
  count    = var.scheduler == "Scale" ? 1 : 0
  content  = <<EOT
---
- name: Removing host entries managed by Ansible
  hosts: all
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

resource "local_file" "bms_bootdrive_playbook" {
  count    = var.scheduler == "Scale" ? 1 : 0
  content  = <<EOT
---
- name: Baremetal Bootdrive Encryption Post Setup
  hosts: all
  gather_facts: false
  vars:
    check_interval: 10
    max_ssh_attempts: 3
    ssh_retry_delay: 30
    post_reboot_wait: 600
    ansible_ssh_common_args: >-
      -o ConnectTimeout=20
      -o StrictHostKeyChecking=accept-new
      -o UserKnownHostsFile=/dev/null
      -o ServerAliveInterval=15
      -o ServerAliveCountMax=3

  tasks:
    # Verify required variables are set
    - name: Validate required variables
      block:
        - name: Check for IBM Cloud API key
          ansible.builtin.fail:
            msg: "ibmcloud_api_key is not defined"
          when: ibmcloud_api_key is not defined

        - name: Check for resource group
          ansible.builtin.fail:
            msg: "resource_group is not defined"
          when: resource_group is not defined

        - name: Check for VPC region
          ansible.builtin.fail:
            msg: "vpc_region is not defined"
          when: vpc_region is not defined

    # Install and configure IBM Cloud CLI on localhost (control node)
    - name: Ensure IBM Cloud CLI is installed on localhost
      delegate_to: localhost
      run_once: true
      block:
        - name: Check if IBM Cloud CLI is already installed
          ansible.builtin.shell: |
            set -o pipefail
            /usr/local/bin/ibmcloud --version 2>/dev/null || echo "NOT_INSTALLED"
          register: ibmcloud_check
          changed_when: false

        - name: Install prerequisites (curl)
          ansible.builtin.package:
            name: curl
            state: present
          when: "'NOT_INSTALLED' in ibmcloud_check.stdout"

        - name: Download and install IBM Cloud CLI
          ansible.builtin.shell: |
            curl -fsSL https://clis.cloud.ibm.com/install/linux | sh
            # Explicitly add to PATH for current session
            export PATH=/usr/local/bin:$PATH
            /usr/local/bin/ibmcloud plugin install infrastructure-service
          args:
            executable: /bin/bash
          register: ibmcloud_install
          changed_when: "'Install complete' in ibmcloud_install.stdout"
          when: "'NOT_INSTALLED' in ibmcloud_check.stdout"

        - name: Update system PATH
          ansible.builtin.lineinfile:
            path: /etc/environment
            line: 'PATH="/usr/local/bin:$PATH"'
            regexp: '^PATH='
            state: present
          when: "'NOT_INSTALLED' in ibmcloud_check.stdout"

        - name: Verify IBM Cloud CLI installation
          ansible.builtin.shell: |
            export PATH=/usr/local/bin:$PATH
            /usr/local/bin/ibmcloud --version
          register: ibmcloud_version
          changed_when: false

        - name: Display IBM Cloud CLI version
          ansible.builtin.debug:
            msg: "IBM Cloud CLI version: {{ ibmcloud_version.stdout }}"

    # Main boot drive encryption tasks
    - name: Handle boot drive encryption for persistent storage
      when:
        - bms_boot_drive_encryption | default(false)
        - storage_type | default("") == "persistent"
        - "'mgmt' not in inventory_hostname"
      block:
        # Connection verification
        - name: Attempt SSH connection
          ansible.builtin.wait_for:
            port: 22
            host: "{{ inventory_hostname }}"
            timeout: 20
            delay: 5
            connect_timeout: 20
          register: ssh_check
          until: ssh_check is success
          retries: "{{ max_ssh_attempts }}"
          delay: "{{ ssh_retry_delay }}"
          ignore_errors: true
          delegate_to: localhost
          changed_when: false

        - name: Check SSH port status
          ansible.builtin.shell: |
            nc -zv -w 5 "{{ inventory_hostname }}" 22 && echo "OPEN" || echo "CLOSED"
          register: port_check
          ignore_errors: true
          changed_when: false
          delegate_to: localhost
          when: ssh_check is failed

        - name: Debug connection status
          ansible.builtin.debug:
            msg: |
              Server: {{ inventory_hostname }}
              SSH Status: {{ ssh_check | default('undefined') }}
              Port Status: {{ port_check.stdout | default('undefined') }}
              Server ID: {{ id | default('undefined') }}
          when: ssh_check is failed

        # Server recovery for unresponsive systems
        - name: Recover unresponsive server (via IBM Cloud CLI)
          block:
            - name: Login to IBM Cloud (local)
              ansible.builtin.shell: |
                /usr/local/bin/ibmcloud logout || true
                /usr/local/bin/ibmcloud login --apikey "{{ ibmcloud_api_key }}" -q
                /usr/local/bin/ibmcloud target -g "{{ resource_group }}" -r "{{ vpc_region }}"
              args:
                executable: /bin/bash
              delegate_to: localhost
              changed_when: false

            - name: Get current server status (local)
              ansible.builtin.shell: |
                /usr/local/bin/ibmcloud is bm {{ id }} --output JSON | jq -r '.status'
              args:
                executable: /bin/bash
              register: current_status
              delegate_to: localhost
              changed_when: false

            - name: Stop server if not already stopped (local)
              ansible.builtin.shell: |
                status=$(/usr/local/bin/ibmcloud is bm {{ id }} --output JSON | jq -r '.status')
                if [ "$status" != "stopped" ]; then
                  /usr/local/bin/ibmcloud is bm-stop {{ id }} --type hard --force --no-wait
                fi
              args:
                executable: /bin/bash
              async: 300
              poll: 0
              delegate_to: localhost

            - name: Wait for server to stop
              ansible.builtin.shell: |
                # Set timeout to 15 minutes (900 seconds)
                end_time=$(( $(date +%s) + 900 ))
                while [ $(date +%s) -lt $end_time ]; do
                  # Get status with full path and proper error handling
                  status=$(/usr/local/bin/ibmcloud is bm {{ id }} --output JSON 2>/dev/null | jq -r '.status' || echo "ERROR")

                  # Exit immediately if stopped
                  if [ "$status" == "stopped" ]; then
                    exit 0
                  fi

                  # Log current status
                  echo "Current status: $status"
                  sleep 30
                done

                # If we get here, timeout was reached
                echo "Timeout waiting for server to stop"
                exit 1
              args:
                executable: /bin/bash
              register: stop_wait
              delegate_to: localhost
              changed_when: false
              until: stop_wait.rc == 0
              retries: 3
              delay: 30

            - name: Show stop wait debug info
              ansible.builtin.debug:
                var: stop_wait.stdout_lines
              when: stop_wait is defined

            - name: Start server (local)
              ansible.builtin.shell: |
                /usr/local/bin/ibmcloud is bm-start {{ id }} --no-wait
              args:
                executable: /bin/bash
              async: 300
              poll: 0
              delegate_to: localhost

            - name: Wait for server to come online
              ansible.builtin.wait_for:
                port: 22
                host: "{{ inventory_hostname }}"
                timeout: 900
                delay: 30
                connect_timeout: 30
              delegate_to: localhost

          when:
            - ssh_check is failed
            - port_check.stdout is defined
            - "'CLOSED' in port_check.stdout"

        # Post-recovery verification
        - name: Verify encryption setup
          block:
            - name: Check for encrypted drives
              ansible.builtin.command: lsblk -o NAME,FSTYPE,MOUNTPOINT
              register: lsblk_output
              changed_when: false

            - name: Debug storage configuration
              ansible.builtin.debug:
                var: lsblk_output.stdout_lines

            - name: Restart NetworkManager
              ansible.builtin.service:
                name: NetworkManager
                state: restarted
              async: 60
              poll: 0

            - name: Verify NetworkManager status
              ansible.builtin.service:
                name: NetworkManager
                state: started
              changed_when: false

          when: ssh_check is success

        - name: Fail if still unresponsive
          ansible.builtin.fail:
            msg: |
              Server {{ inventory_hostname }} remains unresponsive after recovery attempts
              Last SSH Status: {{ ssh_check | default('undefined') }}
              Last Port Status: {{ port_check.stdout | default('undefined') }}
              Server Status: {{ current_status.stdout | default('undefined') }}
          when:
            - ssh_check is failed
            - port_check.stdout is defined
            - "'OPEN' in port_check.stdout"

      rescue:
        - name: Handle encryption setup failure
          ansible.builtin.fail:
            msg: |
              Critical failure during encryption setup for {{ inventory_hostname }}
              Error details:
              SSH Status: {{ ssh_check | default('undefined') }}
              Port Status: {{ port_check.stdout | default('undefined') }}
              Server Status: {{ current_status.stdout | default('undefined') }}
              IBM Cloud CLI Version: {{ ibmcloud_version.stdout | default('undefined') }}
EOT
  filename = local.scale_baremetal_bootdrive_playbook_path
}

resource "local_file" "scale_baremetal_prerequesite_playbook" {
  count    = var.scheduler == "Scale" && var.storage_type == "persistent" ? 1 : 0
  content  = <<EOT
---
- name: Configure network, packages, and firewall
  hosts: all
  become: true

  tasks:
    - block:
        # --- Network configuration ---
        - name: Add DOMAIN to network interface config
          lineinfile:
            path: "/etc/sysconfig/network-scripts/ifcfg-{{ storage_interface }}"
            line: "DOMAIN={{ storage_domain }}"
            create: yes

        - name: Set MTU to 9000
          lineinfile:
            path: "/etc/sysconfig/network-scripts/ifcfg-{{ storage_interface }}"
            line: "MTU=9000"
            create: yes

        - name: Update QUEUE_COUNT in iface-config
          replace:
            path: "/var/lib/cloud/scripts/per-boot/iface-config"
            regexp: "QUEUE_COUNT=3"
            replace: "QUEUE_COUNT=$(ethtool -l $iface | awk '/Combined:/ {print $2;exit}')"

        - name: Set eth0 combined queues to 16
          command: "ethtool -L eth0 combined 16"

        - name: Update vpcuser password expiration settings
          command: "chage -I -1 -m 0 -M 99999 -E -1 -W 14 vpcuser"

        # --- Hostname ---
        - name: Configure hostname with DNS domain
          hostname:
            name: "{{ ansible_hostname }}.{{ storage_domain }}"

        # --- OS detection and package installation ---
        - name: Gather OS facts
          ansible.builtin.setup:
            filter: "ansible_distribution*"

        - name: Set RHEL vars
          set_fact:
            package_mgr: "dnf"
            package_list: >-
              {% if 'RedHat' in ansible_distribution %}
                {% if '9' in ansible_distribution_version %}
                  python3 kernel-devel-{{ ansible_kernel }} kernel-headers-{{ ansible_kernel }} firewalld numactl make gcc-c++ elfutils-libelf-devel bind-utils iptables-nft nfs-utils elfutils elfutils-devel python3-dnf-plugin-versionlock
                {% else %}
                  python38 kernel-devel-{{ ansible_kernel }} kernel-headers-{{ ansible_kernel }} firewalld numactl jq make gcc-c++ elfutils-libelf-devel bind-utils iptables nfs-utils elfutils elfutils-devel python3-dnf-plugin-versionlock
                {% endif %}
              {% else %}
                ""
              {% endif %}
          when: ansible_os_family == "RedHat"

        - name: Enable RHEL 9 supplementary repo
          command: "subscription-manager repos --enable=rhel-9-for-x86_64-supplementary-eus-rpms"
          ignore_errors: yes
          when: ansible_distribution_major_version == "9" and ansible_os_family == "RedHat"

        - name: Install required packages
          yum:
            name: "{{ package_list.split() }}"
            state: present
          register: package_install
          until: package_install is succeeded
          retries: 2
          delay: 10
          when: package_list != ""

        - name: Security update
          yum:
            name: "*"
            security: yes
            state: latest
          ignore_errors: yes
          when: ansible_os_family == "RedHat"

        - name: Version lock packages
          command: "yum versionlock add {{ package_list }}"
          ignore_errors: yes
          when: ansible_os_family == "RedHat"

        - name: Add GPFS bin path to root bashrc
          lineinfile:
            path: "/root/.bashrc"
            line: "export PATH=$PATH:/usr/lpp/mmfs/bin"

        # --- Firewall ---
        - name: Stop firewalld
          service:
            name: "firewalld"
            state: stopped

        - name: Configure firewall ports and services (permanent)
          firewalld:
            port: "{{ item.port }}/{{ item.proto }}"
            permanent: true
            state: enabled
          loop:
            - { port: 1191, proto: tcp }
            - { port: 4444, proto: tcp }
            - { port: 4444, proto: udp }
            - { port: 4739, proto: udp }
            - { port: 4739, proto: tcp }
            - { port: 9084, proto: tcp }
            - { port: 9085, proto: tcp }
            - { port: 2049, proto: tcp }
            - { port: 2049, proto: udp }
            - { port: 111, proto: tcp }
            - { port: 111, proto: udp }
            - { port: 30000-61000, proto: tcp }
            - { port: 30000-61000, proto: udp }

        - name: Enable HTTP/HTTPS services (permanent)
          firewalld:
            service: "{{ item }}"
            permanent: true
            state: enabled
          loop:
            - "http"
            - "https"

        - name: Start and enable firewalld
          service:
            name: "firewalld"
            state: started
            enabled: true

      when:
        - storage_type | default("") == "persistent"
        - "'mgmt' not in inventory_hostname"

    # Protocol-specific configuration
    - block:
            # --- Hostname ---
        - name: Configure hostname with DNS domain
          hostname:
            name: "{{ ansible_hostname }}.{{ protocol_domain }}"

        - name: Remove existing eth1 connection
          shell: |
            sec_interface=$(nmcli -t con show --active | grep eth1 | cut -d ':' -f 1)
            nmcli conn del "$sec_interface"
          ignore_errors: yes

        - name: Add eth1 ethernet connection
          command: nmcli con add type ethernet con-name eth1 ifname eth1

        - name: Add DOMAIN to protocol interface config
          lineinfile:
            path: "/etc/sysconfig/network-scripts/ifcfg-{{ protocol_interface }}"
            line: "DOMAIN={{ protocol_domain }}"
            create: yes

        - name: Set MTU to 9000 for protocol interface
          lineinfile:
            path: "/etc/sysconfig/network-scripts/ifcfg-{{ protocol_interface }}"
            line: "MTU=9000"
            create: yes

        - name: Add IC_REGION to root bashrc
          lineinfile:
            path: "/root/.bashrc"
            line: "export IC_REGION={{ vpc_region }}"

        - name: Add IC_SUBNET to root bashrc
          lineinfile:
            path: "/root/.bashrc"
            line: "export IC_SUBNET={{ protocol_subnet }}"

        - name: Add IC_RG to root bashrc
          lineinfile:
            path: "/root/.bashrc"
            line: "export IC_RG={{ resource_group }}"
      when:
        - storage_type | default("") == "persistent"
        - scale_protocol_node | default(false) | bool

EOT
  filename = local.scale_baremetal_prerequesite_playbook_path
}
