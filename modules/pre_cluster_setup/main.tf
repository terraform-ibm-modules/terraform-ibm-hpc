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
    ppnlb_hosts          = var.ppnlb_hosts
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
      ppnlb    = try(var.domain_names.ppnlb, null)
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
      ppnlb_hosts: "ppnlb"

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
          ]) : "${host.name} ansible_ssh_private_key_file=${local.storage_private_key} ansible_user=vpcuser storage_type=vsi colocate_protocol_instances=${var.colocate_protocol_instances} scale_protocol_node=${var.enable_protocol}"
        ],
        # baremetal storage hosts
        [
          for host in flatten([
            values(local.normalize_hosts.storage_bms_hosts),
            values(local.normalize_hosts.storage_tb_bms_hosts)
          ]) : "${host.name} id=${host.id} ansible_ssh_private_key_file=${local.storage_private_key} ansible_user=vpcuser storage_type=baremetal scale_protocol_node=${var.enable_protocol} colocate_protocol_instances=${var.colocate_protocol_instances} bms_boot_drive_encryption=${var.bms_boot_drive_encryption}"
        ],
        # AFM hosts
        [
          for host in values(local.normalize_hosts.afm_hosts) :
          "${host.name} ansible_ssh_private_key_file=${local.storage_private_key} ansible_user=vpcuser storage_type=vsi scale_protocol_node=false"
        ],
        # AFM BMS hosts
        [
          for host in values(local.normalize_hosts.afm_bms_hosts) :
          "${host.name} id=${host.id} ansible_ssh_private_key_file=${local.storage_private_key} ansible_user=vpcuser storage_type=baremetal scale_protocol_node=false bms_boot_drive_encryption=${var.bms_boot_drive_encryption}"
        ],
        # Protocol hosts
        [
          for host in values(local.normalize_hosts.protocol_hosts) :
          "${host.name} ansible_ssh_private_key_file=${local.storage_private_key} ansible_user=vpcuser storage_type=vsi scale_protocol_node=true colocate_protocol_instances=false"
        ],
        # Protocol BMS hosts
        [
          for host in values(local.normalize_hosts.protocol_bms_hosts) :
          "${host.name} id=${host.id} ansible_ssh_private_key_file=${local.storage_private_key} ansible_user=vpcuser storage_type=baremetal scale_protocol_node=true colocate_protocol_instances=false bms_boot_drive_encryption=${var.bms_boot_drive_encryption}"
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
        ]) : "${host.name} ansible_ssh_private_key_file=${local.compute_private_key} ansible_user=vpcuser"
      ]),
      ""
    ] : [],

    # CLIENT
    length(values(local.normalize_hosts.client_hosts)) > 0 ? [
      "[client]",
      join("\n", [
        for host in values(local.normalize_hosts.client_hosts) :
        "${host.name} ansible_ssh_private_key_file=${local.client_private_key} ansible_user=vpcuser"
      ]),
      ""
    ] : [],

    # GKLM
    length(values(local.normalize_hosts.gklm_hosts)) > 0 ? [
      "[gklm]",
      join("\n", [
        for host in values(local.normalize_hosts.gklm_hosts) :
        "${host.name} ansible_ssh_private_key_file=${local.gklm_private_key} ansible_user=vpcuser"
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
      ppnlb_hosts: "ppnlb"

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

        - name: Add GPFS bin path to User bashrc
          lineinfile:
            path: "/home/vpcuser/.bashrc"
            line: "export PATH=$PATH:/usr/lpp/mmfs/bin"

        - name: Add GPFS bin path to Root User bashrc
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

        # IBM Cloud VPC RHEL9 base images pre-mask rpcbind and nfs-server.
        # Unmask both before enabling. nfs-server is unmasked for completeness
        # but not enabled — Scale CES uses nfs-ganesha, not kernel nfsd.
        # rpcbind.socket must be enabled so mmces service start NFS can
        # register with portmapper.
        - name: Unmask rpcbind and nfs-server (RHEL9 VPC images pre-mask these)
          ansible.builtin.systemd:
            name: "{{ item }}"
            masked: false
          loop:
            - rpcbind.service
            - rpcbind.socket
            - nfs-server.service
          when: ansible_distribution_major_version == "9" and ansible_os_family == "RedHat"

        - name: Enable and start rpcbind.socket
          ansible.builtin.systemd:
            name: rpcbind.socket
            state: started
            enabled: true
          when: ansible_distribution_major_version == "9" and ansible_os_family == "RedHat"

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

        - name: Add IC_REGION to User bashrc
          lineinfile:
            path: "/etc/environment"
            line: "export IC_REGION={{ vpc_region }}"

        - name: Add IC_SUBNET to User bashrc
          lineinfile:
            path: "/etc/environment"
            line: "export IC_SUBNET={{ protocol_subnet }}"

        - name: Add IC_RG to User bashrc
          lineinfile:
            path: "/etc/environment"
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
- name: GPFS Restripe and Health Check
  hosts: "{{ groups['scale_nodes'][0] }}"
  become: yes

  tasks:

    # ==================================================
    # Task 0: Collect GPFS health for all nodes
    # ==================================================

    - name: Check GPFS node health (all nodes)
      ansible.builtin.command:
        cmd: /usr/lpp/mmfs/bin/mmhealth node show -a
      register: health_output
      changed_when: false

    - name: Extract nodes with unmounted filesystem (fs1)
      ansible.builtin.set_fact:
        unmounted_fs_nodes: >-
          {{
            health_output.stdout
            | default('')
            | split('\n\n')
            | select('search', 'FILESYSTEM\\s+DEGRADED')
            | select('search', 'unmounted_fs_check\\(fs1\\)')
            | map('regex_search', 'Node name:\\s+([^\\s]+)', '\\1')
            | select('string')
            | list
          }}

    - name: Detect ill-unbalanced filesystem
      ansible.builtin.set_fact:
        ill_unbalanced_fs: >-
          {{
            'ill_unbalanced_fs'
            in (health_output.stdout | default(''))
          }}

    - name: Detect nodes with no_disk_space_warn alert
      ansible.builtin.set_fact:
        no_disk_space_warn_nodes: >-
          {{
            health_output.stdout
            | default('')
            | split('\n\n')
            | select('search', 'no_disk_space_warn')
            | map('regex_search', 'Node name:\\s+([^\\s]+)', '\\1')
            | select('string')
            | list
          }}

    - name: Extract filesystem name | Find existing filesystem
      ansible.builtin.shell:
        cmd: >
          /usr/lpp/mmfs/bin/mmlsfs all -Y |
          grep -v HEADER |
          cut -d ':' -f 7 |
          uniq
      register: scale_storage_existing_fs
      changed_when: false
      failed_when: false

    - name: Show detected health issues
      ansible.builtin.debug:
        msg:
          unmounted_fs_nodes: "{{ unmounted_fs_nodes }}"
          ill_unbalanced_fs: "{{ ill_unbalanced_fs }}"
          no_disk_space_warn_nodes: "{{ no_disk_space_warn_nodes }}"
          filesystem_name: "{{ scale_storage_existing_fs.stdout | default('') | trim }}"


    # ==================================================
    # Task 1: Restart nodes with unmounted filesystem
    # ==================================================

    - name: Shutdown nodes with unmounted filesystem
      ansible.builtin.command:
        cmd: "/usr/lpp/mmfs/bin/mmshutdown -N {{ item }}"
      loop: "{{ unmounted_fs_nodes }}"
      when:
        - unmounted_fs_nodes | length > 0

    - name: Wait for node shutdown to complete
      ansible.builtin.command:
        cmd: "/usr/lpp/mmfs/bin/mmgetstate -N {{ item }}"
      register: shutdown_state
      until:
        - shutdown_state.stdout is defined
        - shutdown_state.stdout is search("down")
      retries: 20
      delay: 30
      loop: "{{ unmounted_fs_nodes }}"
      when:
        - unmounted_fs_nodes | length > 0

    - name: Startup nodes after shutdown
      ansible.builtin.command:
        cmd: "/usr/lpp/mmfs/bin/mmstartup -N {{ item }}"
      loop: "{{ unmounted_fs_nodes }}"
      when:
        - unmounted_fs_nodes | length > 0


    # ==================================================
    # Task 2: Resolve no_disk_space_warn alerts
    # ==================================================

    - name: Resolve no_disk_space_warn alerts
      ansible.builtin.command:
        cmd: >
          /usr/lpp/mmfs/bin/mmhealth event resolve
          no_disk_space_warn
          {{ scale_storage_existing_fs.stdout | default('') | trim }}
      register: resolve_output
      changed_when: >-
        'successfully resolved'
        in (resolve_output.stdout | default(''))
      failed_when: false
      when:
        - no_disk_space_warn_nodes | length > 0
        - (scale_storage_existing_fs.stdout | default('') | trim) != ""

    - name: Show resolve command output
      ansible.builtin.debug:
        var: resolve_output
      when:
        - resolve_output is defined


    # ==================================================
    # Task 3: Restripe filesystem
    # ==================================================

    - name: Execute mmrestripefs command
      ansible.builtin.command:
        cmd: >
          /usr/lpp/mmfs/bin/mmrestripefs
          {{ scale_storage_existing_fs.stdout | default('') | trim }}
          -b
      register: restripe_output

      # mmrestripefs was successfully executed
      changed_when: restripe_output.rc == 0

      # Treat "File system is busy" as a non-fatal condition
      failed_when:
        - restripe_output.rc != 0
        - "'File system is busy' not in (restripe_output.stderr | default(''))"

      when:
        - ill_unbalanced_fs
        - (scale_storage_existing_fs.stdout | default('') | trim) != ""

    - name: Show restripe output
      ansible.builtin.debug:
        var: restripe_output
      when:
        - restripe_output is defined


    # ==================================================
    # Task 4: Final GPFS health refresh
    # ==================================================

    - name: Refresh GPFS health after remediation
      ansible.builtin.command:
        cmd: /usr/lpp/mmfs/bin/mmhealth node show --refresh
      changed_when: false

    - name: Display GPFS health status
      ansible.builtin.debug:
        msg: >-
          GPFS Health Check Completed:
          {{ health_output.stdout_lines | default([]) }}
EOT
  filename = local.cluster_health_refresh_playbook_path
}


resource "local_file" "scale_encryption_replication_playbook" {
  count    = var.scheduler == "Scale" ? 1 : 0
  content  = <<EOT
---
- name: Execute master replication task only
  hosts: localhost
  become: yes
  collections:
    - ibm.spectrum_scale
  any_errors_fatal: true

  vars:
    scale_encryption_servers: "{{ scale_encryption_servers_list }}"
    scale_encryption_ssh_key_file: "/dev/null"

  tasks:
    - name: Executing Replication on Slave from key Servers
      ansible.builtin.include_role:
        name: encryption_prepare
        tasks_from: initiate_master_replication.yml
      loop: "{{ scale_encryption_servers[1:] }}"
      loop_control:
        loop_var: server
EOT
  filename = local.encryption_replication_playbook_path
}

resource "local_file" "remove_security_outbound_rule_playbook" {
  count    = var.scheduler == "Scale" ? 1 : 0
  content  = <<EOT
---
- name: Remove outbound security group rule
  hosts: localhost
  gather_facts: true

  vars:
    region: "{{ region }}"
    resource_group: "{{ resource_group }}"
    api_key: "{{ lookup('env', 'IBMCLOUD_API_KEY') }}"
    entries: "{{ (sg_entries is string) | ternary(sg_entries | from_json, sg_entries) if sg_entries is defined else [{'sg_id': sg_id, 'rule_name': 'storage-allow-all-outbound'}] }}"

  tasks:
    - name: Check if IBM Cloud IS plugin is installed
      shell: ibmcloud plugin list | grep -i "infrastructure-service" || true
      register: plugin_check
      changed_when: false

    - name: Install IBM Cloud IS plugin if missing
      shell: ibmcloud plugin install infrastructure-service -f
      when: plugin_check.stdout == ""
      register: plugin_install

    - name: Ensure plugin is ready (wait a moment)
      pause:
        seconds: 2
      when: plugin_install is changed

    - name: Login to IBM Cloud
      shell: ibmcloud login --apikey "{{ api_key }}" -r "{{ region }}" -g "{{ resource_group }}"
      no_log: true
      when: api_key != ""
      register: login_result
      ignore_errors: yes

    - name: Abort if login failed
      fail:
        msg: "IBM Cloud login failed. Please check IBMCLOUD_API_KEY environment variable."
      when:
        - api_key != ""
        - login_result is defined
        - login_result.rc is defined
        - login_result.rc != 0

    - name: Check if already logged in (if no API key)
      shell: ibmcloud target
      register: target_check
      changed_when: false
      failed_when: false
      when: api_key == ""

    - name: Abort if not logged in
      fail:
        msg: "Not logged in to IBM Cloud. Set IBMCLOUD_API_KEY environment variable."
      when:
        - api_key == ""
        - target_check is defined
        - target_check.rc != 0

    - name: Process rule deletion for each security group entry
      include_tasks:
        file: "{{ playbook_dir }}/remove_sg_rule_item.yml"
      loop: "{{ entries }}"
      loop_control:
        loop_var: current_entry
EOT
  filename = local.remove_security_outbound_rule_playbook_path
}

resource "local_file" "remove_sg_rule_item" {
  count    = var.scheduler == "Scale" ? 1 : 0
  content  = <<EOT
---
- name: "Get security group details for {{ current_entry.sg_id }}"
  shell: >
    ibmcloud is security-group {{ current_entry.sg_id }} --output JSON
  register: sg_details
  changed_when: false

- name: "Find rule ID for {{ current_entry.rule_name }}"
  set_fact:
    rule_id: >-
      {{
        (
          ((sg_details.stdout | from_json).rules | default([]))
          | selectattr('name', 'defined')
          | selectattr('name', 'equalto', current_entry.rule_name)
          | map(attribute='id')
          | first
        ) | default('')
      }}

- name: "Show rule ID for {{ current_entry.rule_name }}"
  debug:
    var: rule_id

- name: "Delete rule {{ current_entry.rule_name }}"
  shell: >
    ibmcloud is security-group-rule-delete {{ current_entry.sg_id }} {{ rule_id }} -f
  when: rule_id != ""
  register: delete_result

- name: "Confirm deletion for {{ current_entry.rule_name }}"
  debug:
    msg: "Rule '{{ current_entry.rule_name }}' deleted successfully from {{ current_entry.sg_id }}"
  when: delete_result is defined and delete_result.rc is defined and delete_result.rc == 0
EOT
  filename = format("%s/%s/remove_sg_rule_item.yml", var.clone_path, "ibm-spectrum-scale-install-infra")
}

resource "local_file" "ensure_security_outbound_rule_playbook" {
  count    = var.scheduler == "Scale" ? 1 : 0
  content  = <<EOT
---
- name: Ensure outbound 0.0.0.0/0 security group rule exists
  hosts: localhost
  gather_facts: true

  vars:
    region: "{{ region }}"
    resource_group: "{{ resource_group }}"
    security_group_ids_list: "{{ sg_ids.split(',') | select('truthy') | list }}"
    api_key: "{{ lookup('env', 'IBMCLOUD_API_KEY') }}"

  tasks:
    - name: End play if no security group IDs are provided
      meta: end_play
      when: security_group_ids_list | length == 0

    - name: Check if IBM Cloud IS plugin is installed
      shell: ibmcloud plugin list | grep -i "infrastructure-service" || true
      register: plugin_check
      changed_when: false

    - name: Install IBM Cloud IS plugin if missing
      shell: ibmcloud plugin install infrastructure-service -f
      when: plugin_check.stdout == ""
      register: plugin_install

    - name: Ensure plugin is ready (wait a moment)
      pause:
        seconds: 2
      when: plugin_install is changed

    - name: Login to IBM Cloud
      shell: ibmcloud login --apikey "{{ api_key }}" -r "{{ region }}" -g "{{ resource_group }}"
      no_log: true
      when: api_key != ""
      register: login_result
      ignore_errors: yes

    - name: Abort if login failed
      fail:
        msg: "IBM Cloud login failed. Please check IBMCLOUD_API_KEY environment variable."
      when:
        - api_key != ""
        - login_result is defined
        - login_result.rc is defined
        - login_result.rc != 0

    - name: Check if already logged in (if no API key)
      shell: ibmcloud target
      register: target_check
      changed_when: false
      failed_when: false
      when: api_key == ""

    - name: Abort if not logged in
      fail:
        msg: "Not logged in to IBM Cloud. Set IBMCLOUD_API_KEY environment variable."
      when:
        - api_key == ""
        - target_check is defined
        - target_check.rc != 0

    - name: Process each security group
      include_tasks:
        file: "{{ playbook_dir }}/ensure_sg_rule_item.yml"
      loop: "{{ security_group_ids_list }}"
      loop_control:
        loop_var: current_sg_id
EOT
  filename = local.ensure_security_outbound_rule_playbook_path
}

resource "local_file" "ensure_sg_rule_item" {
  count    = var.scheduler == "Scale" ? 1 : 0
  content  = <<EOT
---
- name: "Get security group details for {{ current_sg_id }}"
  shell: >
    ibmcloud is security-group {{ current_sg_id }} --output JSON
  register: sg_details
  changed_when: false

- name: "Check for existing outbound 0.0.0.0/0 rule in {{ current_sg_id }}"
  set_fact:
    has_outbound_all_rule: >-
      {{
        ((sg_details.stdout | from_json).rules | default([]))
        | selectattr('direction', 'defined')
        | selectattr('direction', 'equalto', 'outbound')
        | selectattr('remote.cidr_block', 'defined')
        | selectattr('remote.cidr_block', 'equalto', '0.0.0.0/0')
        | list
        | length > 0
      }}

- name: "Status of 0.0.0.0/0 outbound rule for {{ current_sg_id }}"
  debug:
    msg: "Security group {{ current_sg_id }} has outbound 0.0.0.0/0 rule: {{ has_outbound_all_rule }}"

- name: "Add outbound 0.0.0.0/0 rule to {{ current_sg_id }}"
  shell: >
    ibmcloud is security-group-rule-add {{ current_sg_id }} outbound all --remote 0.0.0.0/0 --name storage-allow-all-outbound
  when: not (has_outbound_all_rule | bool)
  register: add_rule_result

- name: "Confirm addition of rule to {{ current_sg_id }}"
  debug:
    msg: "Added outbound 0.0.0.0/0 rule 'storage-allow-all-outbound' to {{ current_sg_id }}"
  when: add_rule_result is defined and add_rule_result.rc is defined and add_rule_result.rc == 0
EOT
  filename = format("%s/%s/ensure_sg_rule_item.yml", var.clone_path, "ibm-spectrum-scale-install-infra")
}

resource "null_resource" "ensure_security_outbound_rule_play" {
  count = var.scheduler == "Scale" && anytrue([
    var.storage_security_group_name != null,
    var.compute_security_group_name != null,
    var.client_security_group_name != null,
    var.gklm_security_group_name != null,
    var.ldap_security_group_name != null,
    var.login_security_group_name != null
  ]) ? 1 : 0

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = "sudo -E ansible-playbook -f 50 -i localhost, -c local -e sg_ids=${join(",", local.target_security_group_ids)} -e region=${var.vpc_region} -e resource_group=${var.resource_group} ${local.ensure_security_outbound_rule_playbook_path}"

    environment = {
      IBMCLOUD_API_KEY = var.ibmcloud_api_key
    }
  }

  triggers = {
    build = timestamp()
  }

  depends_on = [
    local_file.ensure_security_outbound_rule_playbook,
    local_file.ensure_sg_rule_item
  ]
}

resource "time_sleep" "wait_for_servers_syncup" {
  triggers = {
    always = timestamp()
  }
  create_duration = "180s"
}

resource "local_file" "scale_observability_prerequisite_vars" {
  filename        = local.scale_observability_prerequisite_vars
  file_permission = "0600" # Locks down read/write to the owner only
  content = yamlencode({
    # Cloud Monitoring Variables
    monitoring_enabled             = var.observability_monitoring_enable
    bridge_version                 = "9.0.0"
    api_key_name                   = "grafana_bridge_key"
    bridge_basic_auth_user         = "svc_osprey_scraper"
    cloud_monitoring_access_key    = var.cloud_monitoring_access_key
    cloud_monitoring_ingestion_url = var.cloud_monitoring_ingestion_url

    # SCC Workload Protection Variables
    sccwp_enabled            = var.enable_sccwp
    sccwp_api_endpoint       = var.sccwp_api_endpoint
    sccwp_access_key         = var.sccwp_access_key
    sccwp_ingestion_endpoint = var.sccwp_ingestion_endpoint
  })
}

resource "local_file" "scale_grafana_bridge_automation_playbook" {
  count    = var.scheduler == "Scale" ? 1 : 0
  content  = <<EOT
---
- name: Deploy IBM Storage Scale Bridge & Sysdig Agent
  hosts: scale_nodes
  become: yes
  tasks:

    # =========================================================================
    # 0. PREREQUISITE CHECK (EXITS GRACEFULLY IF SCC and Monitoring BOTH ARE DISABLED)
    # =========================================================================
    - name: Notify user that installation is skipped
      ansible.builtin.debug:
        msg: "Both Monitoring and SCC Workload Protection are disabled. Skipping installation."
      when: not (monitoring_enabled | default(false) | bool) and not (sccwp_enabled | default(false) | bool)

    - name: Halt playbook execution if no features are enabled
      ansible.builtin.meta: end_play
      when: not (monitoring_enabled | default(false) | bool) and not (sccwp_enabled | default(false) | bool)

    - name: Notify user that installation is proceeding
      ansible.builtin.debug:
        msg: "Proceeding with Agent installation (Monitoring: {{ monitoring_enabled | default(false) }}, SCC: {{ sccwp_enabled | default(false) }})."

    # ==================================================================================
    # THE GRAFANA BRIDGE BLOCK (ONLY RUNS ON MANAGEMENT NODES if MONITORING IS ENABLED)
    # ==================================================================================
    - name: Deploy Grafana Bridge on management nodes
      block:
        # =========================================================================
        # 1. DEPENDENCIES & DIRECTORIES
        # =========================================================================
        - name: Install Python 3.12
          ansible.builtin.dnf:
            name: python312
            state: present

        - name: Download and install pip for Python 3.12
          ansible.builtin.shell: |
            curl -sS https://bootstrap.pypa.io/get-pip.py -o /tmp/get-pip.py
            /usr/bin/python3.12 /tmp/get-pip.py
          args:
            creates: /usr/local/bin/pip3.12

        - name: Create required directories
          ansible.builtin.file:
            path: "{{ item }}"
            state: directory
            mode: '0755'
          loop:
            - /opt/IBM
            - /var/log/ibm_bridge_for_grafana
            - /etc/bridge_ssl/certs

        # =========================================================================
        # 2. DOWNLOAD & EXTRACT BRIDGE
        # =========================================================================
        - name: Download and extract Grafana Bridge archive
          ansible.builtin.unarchive:
            src: "https://github.com/IBM/ibm-spectrum-scale-bridge-for-grafana/archive/refs/tags/v{{ bridge_version }}.tar.gz"
            dest: /opt/IBM
            remote_src: yes
            creates: "/opt/IBM/ibm-spectrum-scale-bridge-for-grafana-{{ bridge_version }}"

        - name: Install Python requirements via pip3.12
          ansible.builtin.pip:
            requirements: /opt/IBM/ibm-spectrum-scale-bridge-for-grafana-{{ bridge_version }}/requirements.txt
            executable: /usr/local/bin/pip3.12

        # =========================================================================
        # 3. SECURITY & CERTIFICATES
        # =========================================================================
        - name: Generate self-signed SSL Certificates silently
          ansible.builtin.command: >
            openssl req -x509 -nodes -days 365 -newkey rsa:2048
            -subj "/C=IN/ST=State/L=City/O=IBM/OU=Storage/CN=grafana-bridge"
            -keyout /etc/bridge_ssl/certs/privkey.pem
            -out /etc/bridge_ssl/certs/cert.pem
          args:
            creates: /etc/bridge_ssl/certs/cert.pem

        # =========================================================================
        # 4. STORAGE SCALE API KEY EXTRACTION
        # =========================================================================
        - name: Generate Storage Scale API Key in cluster
          ansible.builtin.command: /usr/lpp/mmfs/bin/mmperfmon config add --apiKey {{ api_key_name }}
          register: create_key
          failed_when:
            - create_key.rc != 0
            - "'already defined' not in create_key.stderr"
          changed_when: create_key.rc == 0

        - name: Wait 5 seconds for CCR propagation
          ansible.builtin.pause:
            seconds: 5
          when: create_key.changed

        - name: Fetch and parse the API Key Value safely
          ansible.builtin.shell: |
            /usr/lpp/mmfs/bin/mmperfmon config show --apiKey {{ api_key_name }}
          register: mmperfmon_output
          changed_when: false

        - name: Extract key from JSON output
          set_fact:
            extracted_api_key: "{{ (mmperfmon_output.stdout | from_json).key }}"

        # =========================================================================
        # 5. DYNAMIC PASSWORD GENERATION (IDEMPOTENT)
        # =========================================================================
        - name: Check if config.ini already exists
          ansible.builtin.stat:
            path: /opt/IBM/ibm-spectrum-scale-bridge-for-grafana-{{ bridge_version }}/source/config.ini
          register: config_stat

        - name: Extract existing password if present
          ansible.builtin.shell: |
            sed -n 's/^password = //p' /opt/IBM/ibm-spectrum-scale-bridge-for-grafana-{{ bridge_version }}/source/config.ini
          register: existing_b64
          when: config_stat.stat.exists
          changed_when: false

        - name: Set existing or generate new random password
          ansible.builtin.set_fact:
            # We add | trim to the end of both the extraction and the generator
            bridge_pass_raw: >-
              {% if config_stat.stat.exists and existing_b64.stdout != '' %}
              {{ existing_b64.stdout }}
              {% else %}
              {{ lookup('password', '/dev/null chars=ascii_letters,digits length=15') | b64encode }}
              {% endif %}

        - name: Forcefully strip ALL whitespace from password
          ansible.builtin.set_fact:
            clean_bridge_pass: "{{ bridge_pass_raw | replace(' ', '') | replace('\n', '') }}"

        # =========================================================================
        # 6. CONFIGURATION FILES & SYSTEMD
        # =========================================================================
        - name: Deploy declarative config.ini over default package file
          ansible.builtin.copy:
            dest: "/opt/IBM/ibm-spectrum-scale-bridge-for-grafana-{{ bridge_version }}/source/config.ini"
            mode: '0644'
            backup: yes
            content: |
              [opentsdb_plugin]
              port = 8443

              [prometheues_exporter_plugin]
              prometheus = 9250
              promBindIp = 0.0.0.0
              rawCounters = True

              [connection]
              protocol = https

              [basic_auth]
              enabled = True
              username = {{ bridge_basic_auth_user }}
              password = {{ clean_bridge_pass }}

              [tls]
              # Directory path of tls key and cert file location
              tlsKeyPath = /etc/bridge_ssl/certs

              # Name of tls private key file
              tlsKeyFile = privkey.pem

              # Name of tls certificate file
              tlsCertFile = cert.pem

              [server]
              server = localhost
              serverPort = 9980
              retryDelay = 60
              apiKeyName = {{ api_key_name }}
              apiKeyValue = {{ extracted_api_key }}
              caCertPath = False

              [query]
              includeDiskData = no

              [logging]
              # Directory where the bridge can store logs
              logPath = /var/log/ibm_bridge_for_grafana

              # log level 5 (TRACE) 10 (DEBUG), 15 (MOREINFO), 20 (INFO), 30 (WARN),
              # 40 (ERROR) (Default: 15)
              logLevel = 15

              # Log file name (Default: zserver.log)
              # Comment out this setting, if you wish to print out the trace messages directly on the command line
              logFile = zserver.log
          notify: Restart Grafana Bridge

        - name: Deploy Grafana Bridge Systemd Service File
          ansible.builtin.copy:
            dest: /etc/systemd/system/grafana-bridge.service
            content: |
              [Unit]
              Description=IBM Storage Scale bridge for Grafana
              After=multi-user.target

              [Service]
              Type=simple
              Restart=on-failure
              WorkingDirectory=/opt/IBM/ibm-spectrum-scale-bridge-for-grafana-{{ bridge_version }}
              ExecStart=/usr/bin/python3.12 -u /opt/IBM/ibm-spectrum-scale-bridge-for-grafana-{{ bridge_version }}/source/zimonGrafanaIntf.py --configFile /opt/IBM/ibm-spectrum-scale-bridge-for-grafana-{{ bridge_version }}/source/config.ini

              StandardOutput=journal+console
              StandardError=journal+console
              SyslogIdentifier=grafana-bridge

              [Install]
              WantedBy=multi-user.target
          notify: Restart Grafana Bridge

        - name: Ensure Grafana Bridge service is enabled and running
          ansible.builtin.systemd:
            name: grafana-bridge.service
            state: started
            enabled: yes
            daemon_reload: yes

      when: (scale_nodeclass == "managementnodegrp") and (monitoring_enabled | default(false) | bool)

    # =========================================================================
    # 7. UNIFIED SYSDIG AGENT (METRICS & SECURITY - RUNS ON ALL NODES)
    # =========================================================================

    - name: Check if Sysdig Agent binary exists
      ansible.builtin.stat:
        path: /opt/draios/bin/dragent
      register: sysdig_binary

    - name: Install Sysdig Agent via IBM Cloud Script (Dynamic Credentials)
      ansible.builtin.shell: |
        curl -sL https://ibm.biz/install-sysdig-agent | sudo bash -s -- \
          --access_key {% if monitoring_enabled | default(false) | bool %}{{ cloud_monitoring_access_key }}{% else %}{{ sccwp_access_key }}{% endif %} \
          --collector {% if monitoring_enabled | default(false) | bool %}{{ cloud_monitoring_ingestion_url }}{% else %}{{ sccwp_ingestion_endpoint }}{% endif %} \
          --collector_port 6443 \
          --secure true \
          --check_certificate false
      when: not sysdig_binary.stat.exists

    - name: Configure dragent.yaml (Unified Agent Config)
      ansible.builtin.copy:
        dest: /opt/draios/etc/dragent.yaml
        content: |
          # -----------------------------------------------------
          # Global Credentials (Fallback Logic Handled via Jinja)
          # -----------------------------------------------------
          customerid: "{% if monitoring_enabled | default(false) | bool %}{{ cloud_monitoring_access_key }}{% else %}{{ sccwp_access_key }}{% endif %}"
          collector: "{% if monitoring_enabled | default(false) | bool %}{{ cloud_monitoring_ingestion_url }}{% else %}{{ sccwp_ingestion_endpoint }}{% endif %}"
          collector_port: 6443
          ssl: true
          ssl_verify_certificate: false
          tags: "cluster:ibm_storage_scale,nodeclass:{{ scale_nodeclass }}"
          sysdig_capture_enabled: false
          remotefs: true
          # ----------------------------------------------------
          # IBM Cloud Monitoring Integration
          # ----------------------------------------------------
          prometheus:
            enabled: {{ 'true' if (monitoring_enabled | default(false) | bool) else 'false' }}
            yaml_dir: /opt/draios/etc/promscrape.yaml.d
          # ----------------------------------------------------
          # SCC Workload Protection (Security)
          # ----------------------------------------------------
          sysdig_api_endpoint: "{{ sccwp_api_endpoint | default('') }}"
          host_scanner:
            enabled: {{ 'true' if (sccwp_enabled | default(false) | bool) else 'false' }}
            scan_on_start: {{ 'true' if (sccwp_enabled | default(false) | bool) else 'false' }}
          kspm_analyzer:
            enabled: {{ 'true' if (sccwp_enabled | default(false) | bool) else 'false' }}
      notify: Restart Sysdig Agent

    - name: Ensure Sysdig Agent is enabled and running
      ansible.builtin.systemd:
        name: dragent
        state: started
        enabled: yes

    # =========================================================================
    # 8. FETCH AND INJECT PROMETHEUS SCRAPE CONFIGURATION (MANAGEMENT ONLY)
    # =========================================================================

    - name: Configure Prometheus Scraping for Grafana Bridge
      block:
        - name: Ensure custom Prometheus scrape directory exists
          ansible.builtin.file:
            path: /opt/draios/etc/promscrape.yaml.d
            state: directory
            mode: '0755'

        - name: Wait for Grafana Bridge API to become responsive
          ansible.builtin.wait_for:
            port: 9250
            delay: 5
            timeout: 60
            host: 127.0.0.1

        - name: Fetch auto-generated prometheus.yml from Grafana Bridge
          ansible.builtin.uri:
            url: https://127.0.0.1:9250/prometheus.yml
            method: GET
            user: "{{ bridge_basic_auth_user }}"
            password: "{{ clean_bridge_pass }}"
            force_basic_auth: yes
            validate_certs: no
            return_content: yes
          register: bridge_prom_config
          until: bridge_prom_config.status == 200
          retries: 5
          delay: 5

        - name: Save raw config to a temporary staging file
          ansible.builtin.copy:
            dest: /tmp/staged_scale_bridge.yaml
            content: "scrape_configs:{{ (bridge_prom_config.content.split('scrape_configs:')[1]).split('storage:')[0] | regex_replace('password: .*', 'password: ' ~ clean_bridge_pass) }}"
            mode: '0644'
          changed_when: false # Suppress changes for the temp file

        - name: Clean GPFSPDDisk from staged config
          ansible.builtin.replace:
            path: /tmp/staged_scale_bridge.yaml
            regexp: '(?m)^- basic_auth:\n(?:[ \t]+.*\n)*?[ \t]+job_name: GPFSPDDisk\n(?:[ \t]+.*\n)*'
            replace: ''
          changed_when: false # Suppress changes for the temp file

        - name: Inject final cleaned configuration to Sysdig
          ansible.builtin.copy:
            src: /tmp/staged_scale_bridge.yaml
            dest: /opt/draios/etc/promscrape.yaml.d/scale_bridge.yaml
            remote_src: yes
            mode: '0644'
          notify: Restart Sysdig Agent

      when: (scale_nodeclass == "managementnodegrp") and (monitoring_enabled | default(false) | bool)

  handlers:
    - name: Restart Grafana Bridge
      ansible.builtin.systemd:
        name: grafana-bridge.service
        state: restarted

    - name: Restart Sysdig Agent
      ansible.builtin.systemd:
        name: dragent
        state: restarted
EOT
  filename = local.grafana_bridge_automation_playbook_path
}
