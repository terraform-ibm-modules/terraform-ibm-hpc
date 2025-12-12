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
      compute  = try(var.enable_sec_interface_compute ? var.domain_names.storage : var.domain_names.compute, null)
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
      protocol_hosts: "storage"
      storage_hosts: "storage"
      storage_bms_hosts: "storage"
      storage_tb_hosts: "storage"
      storage_tb_bms_hosts: "storage"
      storage_mgmnt_hosts: "storage"
      compute_mgmnt_hosts: "compute"
      afm_hosts: "storage"
      afm_bms_hosts: "storage"
      protocol_bms_hosts: "storage"

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
        # Non-baremetal storage hosts
        [
          for host in flatten([
            values(local.normalize_hosts.storage_hosts),
            values(local.normalize_hosts.storage_tb_hosts),
            values(local.normalize_hosts.storage_mgmnt_hosts)
          ]) : "${host.name} ansible_ssh_private_key_file=${local.storage_private_key} storage_type=vsi colocate_protocol_instances=${var.colocate_protocol_instances} scale_protocol_node=${var.enable_protocol}"
        ],
        # baremetal storage hosts
        [
          for host in flatten([
            values(local.normalize_hosts.storage_bms_hosts),
            values(local.normalize_hosts.storage_tb_bms_hosts)
          ]) : "${host.name} id=${host.id} ansible_ssh_private_key_file=${local.storage_private_key} storage_type=baremetal scale_protocol_node=${var.enable_protocol} colocate_protocol_instances=${var.colocate_protocol_instances} bms_boot_drive_encryption=${var.bms_boot_drive_encryption}"
        ],
        # AFM hosts
        [
          for host in values(local.normalize_hosts.afm_hosts) :
          "${host.name} ansible_ssh_private_key_file=${local.storage_private_key} storage_type=vsi scale_protocol_node=false"
        ],
        # AFM BMS hosts
        [
          for host in values(local.normalize_hosts.afm_bms_hosts) :
          "${host.name} id=${host.id} ansible_ssh_private_key_file=${local.storage_private_key} storage_type=baremetal scale_protocol_node=false bms_boot_drive_encryption=${var.bms_boot_drive_encryption}"
        ],
        # Protocol hosts
        [
          for host in values(local.normalize_hosts.protocol_hosts) :
          "${host.name} ansible_ssh_private_key_file=${local.storage_private_key} storage_type=vsi scale_protocol_node=true colocate_protocol_instances=false"
        ],
        # Protocol BMS hosts
        [
          for host in values(local.normalize_hosts.protocol_bms_hosts) :
          "${host.name} id=${host.id} ansible_ssh_private_key_file=${local.storage_private_key} storage_type=baremetal scale_protocol_node=true colocate_protocol_instances=false bms_boot_drive_encryption=${var.bms_boot_drive_encryption}"
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
      protocol_hosts: "storage"
      storage_hosts: "storage"
      storage_bms_hosts: "storage"
      storage_tb_hosts: "storage"
      storage_tb_bms_hosts: "storage"
      storage_mgmnt_hosts: "storage"
      compute_mgmnt_hosts: "compute"
      afm_hosts: "storage"
      afm_bms_hosts: "storage"
      protocol_bms_hosts: "storage"

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


resource "local_file" "scale_baremetal_prerequisite_vars" {
  filename = local.scale_baremetal_prerequisite_vars
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
    mtu_value_storage         = local.mtu_value_storage
    mtu_value_protocol        = local.mtu_value_protocol
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

resource "local_file" "bms_ssh_check_playbook" {
  count    = var.scheduler == "Scale" ? 1 : 0
  content  = <<EOT
---
- name: Baremetal SSH Connectivity Check
  hosts: all
  gather_facts: false
  vars:
    check_interval: 10
    max_ssh_attempts: 10
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
              /usr/local/bin/ibmcloud is bm-stop {{ id }} --type hard --force --quiet
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
          retries: 10
          delay: 30

        - name: Show stop wait debug info
          ansible.builtin.debug:
            var: stop_wait.stdout_lines
          when: stop_wait is defined

        - name: Start server (local)
          ansible.builtin.shell: |
            /usr/local/bin/ibmcloud is bm-start {{ id }} --quiet
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
EOT
  filename = local.scale_baremetal_ssh_check_playbook_path
}

resource "local_file" "bms_bootdrive_playbook" {
  count    = var.scheduler == "Scale" ? 1 : 0
  content  = <<EOT
---
- name: Baremetal Bootdrive Encryption Post Setup
  hosts: all
  gather_facts: false
  vars:
    ansible_ssh_common_args: >-
      -o ConnectTimeout=20
      -o StrictHostKeyChecking=accept-new
      -o UserKnownHostsFile=/dev/null
      -o ServerAliveInterval=15
      -o ServerAliveCountMax=3

  tasks:
    # Main boot drive encryption tasks
    - name: Handle boot drive encryption for baremetal storage
      when:
        - bms_boot_drive_encryption | default(false)
        - storage_type | default("") == "baremetal"
        - "'mgmt' not in inventory_hostname"
      block:
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
EOT
  filename = local.scale_baremetal_bootdrive_playbook_path
}

resource "local_file" "scale_baremetal_prerequisite_playbook" {
  count    = var.scheduler == "Scale" && var.storage_type == "baremetal" ? 1 : 0
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

        - name: Set MTU to storage Interface
          lineinfile:
            path: "/etc/sysconfig/network-scripts/ifcfg-{{ storage_interface }}"
            line: "MTU={{ mtu_value_storage }}"
            create: yes

        - name: Update QUEUE_COUNT in iface-config
          replace:
            path: "/var/lib/cloud/scripts/per-boot/iface-config"
            regexp: "QUEUE_COUNT=3"
            replace: "QUEUE_COUNT=$(ethtool -l $iface | awk '/Combined:/ {print $2;exit}')"

        - name: Update vpcuser password expiration settings
          command: "chage -I -1 -m 0 -M 99999 -E -1 -W 14 vpcuser"

        # --- Hostname ---
        - name: Configure hostname with DNS domain
          hostname:
            name: "{{ ansible_hostname }}.{{ storage_domain }}"

        # --- Subscription registration ---
        - name: Check subscription status
          command: subscription-manager status
          register: subscription_status
          failed_when: false
          changed_when: false
          when: ansible_os_family == "RedHat"

        - name: Create subscription registration script
          copy:
            content: |
              #!/bin/bash
              PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
              argumentsFound=false
              FILE_DIR=/var/lib/cloud/instance/scripts/vendor
              file=$(grep -src -r -w 'REDHAT_CAPSULE_SERVER\|OS_INSTALL_CODE' "$FILE_DIR" | awk -F: '$2 != 0 {print $1}')
              echo "Processing $file..."
              if [ -f  "$file" ]; then
                  capsule=$(grep "REDHAT_CAPSULE_SERVER=" "$file" | cut -d\" -f2)
                  organization=$(grep "OS_REDHAT_ORG_NAME=" "$file" | cut -d\" -f2)
                  activationKey=$(grep "ACTIVATION_KEYS=" "$file" | cut -d\" -f2)
                  profileName=$(grep "PROFILENAME=" "$file" | cut -d\" -f2)
                  if [ ! -z "$capsule" ] && [ ! -z "$organization" ] && [ ! -z "$activationKey" ] && [ ! -z "$profileName" ]; then
                      argumentsFound=true
                  fi
              fi
              if [ "$argumentsFound" = false ]; then
                  if [ -z "$4" ]; then
                      echo "Please provide capsule hostname, organization, activation key and profile name"
                      exit 1
                  fi
                  capsule=$(echo "$1" | cut -d. -f1).adn.networklayer.com
                  organization=$2
                  activationKey=$3
                  profileName=$4
              fi
              echo "Cleaning metadata..."
              yum clean all
              echo "Unregistering system..."
              subscription-manager unregister || true
              subscription-manager clean || true
              echo "Removing any existing katello-ca RPMs..."
              rpm -qa | grep katello-ca | xargs rpm -e 2>/dev/null || true
              echo "Installing consumer RPM..."
              rpm -Uvh "http://$${capsule}/pub/katello-ca-consumer-latest.noarch.rpm" || true
              subscription-manager config --server.hostname="$${capsule}" || true
              subscription-manager config --rhsm.baseurl="https://$${capsule}/pulp/repos" || true
              if [ -f /etc/rhsm/facts/katello.facts ]; then
                  mv /etc/rhsm/facts/katello.facts "/etc/rhsm/facts/katello.facts.bak.$(date +%s)"
              fi
              echo "{\"network.hostname-override\":\"$${profileName}\"}" > /etc/rhsm/facts/katello.facts
              echo "Registering system..."
              subscription-manager register --org="$${organization}" --activationkey="$${activationKey}" --force
            dest: /tmp/register_rhel.sh
            mode: '0755'
          when:
            - ansible_os_family == "RedHat"
            - subscription_status.rc != 0 or "not registered" in subscription_status.stderr

        - name: Execute subscription registration script
          command: /bin/bash /tmp/register_rhel.sh
          args:
            warn: false
          register: registration_result
          failed_when: registration_result.rc != 0 and "This system is already registered" not in registration_result.stderr and "is already registered" not in registration_result.stderr
          when:
            - ansible_os_family == "RedHat"
            - subscription_status.rc != 0 or "not registered" in subscription_status.stderr

        - name: Clean up registration script
          file:
            path: /tmp/register_rhel.sh
            state: absent
          when: ansible_os_family == "RedHat"

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
          retries: 3
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

        - name: Check resolv.conf content
          ansible.builtin.slurp:
            src: /etc/resolv.conf
          register: resolv_content
          ignore_errors: yes

        - name: Backup resolv.conf if not NetworkManager managed
          ansible.builtin.copy:
            src: /etc/resolv.conf
            dest: "/tmp/resolv.conf.backup.{{ ansible_date_time.epoch }}"
            remote_src: yes
          register: backup_resolv
          when:
            - resolv_content.content is defined
            - '"# Generated by NetworkManager" not in (resolv_content.content | b64decode)'

        - name: Restart NetworkManager
          ansible.builtin.service:
            name: NetworkManager
            state: restarted

        - name: Restore resolv.conf if backup was taken
          ansible.builtin.copy:
            src: "{{ backup_resolv.dest }}"
            dest: /etc/resolv.conf
            remote_src: yes
          when:
            - backup_resolv is defined
            - backup_resolv.changed

      when:
        - storage_type | default("") == "baremetal"
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

        - name: Set MTU to protocol interface
          lineinfile:
            path: "/etc/sysconfig/network-scripts/ifcfg-{{ protocol_interface }}"
            line: "MTU={{ mtu_value_protocol }}"
            create: yes

        - name: Check resolv.conf content
          ansible.builtin.slurp:
            src: /etc/resolv.conf
          register: resolv_content
          ignore_errors: yes

        - name: Backup resolv.conf if not NetworkManager managed
          ansible.builtin.copy:
            src: /etc/resolv.conf
            dest: "/tmp/resolv.conf.backup.{{ ansible_date_time.epoch }}"
            remote_src: yes
          register: backup_resolv
          when:
            - resolv_content.content is defined
            - '"# Generated by NetworkManager" not in (resolv_content.content | b64decode)'

        - name: Restart NetworkManager
          ansible.builtin.service:
            name: NetworkManager
            state: restarted

        - name: Restore resolv.conf if backup was taken
          ansible.builtin.copy:
            src: "{{ backup_resolv.dest }}"
            dest: /etc/resolv.conf
            remote_src: yes
          when:
            - backup_resolv is defined
            - backup_resolv.changed

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
        - storage_type | default("") == "baremetal"
        - scale_protocol_node | default(false) | bool
EOT
  filename = local.scale_baremetal_prerequisite_playbook_path
}

resource "local_file" "scale_gpfs_restart_playbook" {
  count    = var.scheduler == "Scale" && var.scale_encryption_type == "key_protect" ? 1 : 0
  content  = <<EOT
- name: Ensure GPFS service is restarted properly
  hosts: scale_nodes
  become: yes
  tasks:
    - name: Check current status of GPFS service
      ansible.builtin.systemd:
        name: gpfs
        state: started
        enabled: yes
      register: gpfs_status

    - name: Display current GPFS status
      ansible.builtin.debug:
        msg: "GPFS service is currently {{ gpfs_status.state }}"

    - name: Restart GPFS service
      ansible.builtin.systemd:
        name: gpfs
        state: restarted
      register: restart_result

    - name: Verify GPFS service is running after restart
      ansible.builtin.systemd:
        name: gpfs
        state: started
      register: gpfs_final_status

    - name: Display restart results
      ansible.builtin.debug:
        msg: "GPFS service restart completed. Current status: {{ gpfs_final_status.state }}"
EOT
  filename = local.gpfs_restart_playbook_path
}

resource "local_file" "scale_cluster_health_refresh_playbook" {
  count    = var.scheduler == "Scale" ? 1 : 0
  content  = <<EOT
- name: Ensure GPFS service is restarted properly
  hosts: all
  become: yes
  tasks:

    - name: Refresh and check GPFS node health status
      ansible.builtin.shell: |
        /usr/lpp/mmfs/bin/mmhealth node show --refresh
      register: gpfs_health
      changed_when: false
      failed_when: gpfs_health.rc != 0

EOT
  filename = local.cluster_health_refresh_playbook_path
}

resource "time_sleep" "wait_for_servers_syncup" {
  triggers = {
    always = timestamp()
  }
  create_duration = "60s"
}
