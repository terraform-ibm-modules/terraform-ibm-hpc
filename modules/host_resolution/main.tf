locals {
  deployer_hostentry_playbook_path = format("%s/%s/deployer_host_entry_play.yml", var.clone_path, "ibm-spectrum-scale-install-infra")
  scale_hostentry_playbook_path    = format("%s/%s/scale_host_entry_play.yml", var.clone_path, "ibm-spectrum-scale-install-infra")
  scale_cluster_hosts              = format("%s/%s/scale_cluster_hosts.yml", var.clone_path, "ibm-spectrum-scale-install-infra")
  scale_all_inventory              = format("%s/%s/scale_all_inventory.ini", var.clone_path, "ibm-spectrum-scale-install-infra")
  remove_hostentry_playbooks_path  = format("%s/%s/remove_host_entry_play.yml", var.clone_path, "ibm-spectrum-scale-install-infra")
  dns_names                        = jsonencode(var.domain_names)
  }

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
    ldap_hosts           = var.ldap_hosts
    storage_bms_hosts    = var.storage_bms_hosts
    storage_tb_bms_hosts = var.storage_tb_bms_hosts
    protocol_bms_hosts   = var.protocol_bms_hosts
    afm_bms_hosts        = var.afm_bms_hosts
  })
}

resource "local_file" "deployer_host_entry_playbook" {
  count    = var.scheduler == "Scale" ? 1 : 0
  content  = <<EOT
---
- name: Manage /etc/hosts with dynamic host-IP mappings
  hosts: localhost
  connection: local
  become: yes
  vars:
    storage_hosts: "{}"
    storage_mgmnt_hosts: "{}"
    storage_tb_hosts: "{}"
    compute_hosts: "{}"
    compute_mgmnt_hosts: "{}"
    client_hosts: "{}"
    protocol_hosts: "{}"
    gklm_hosts: "{}"
    afm_hosts: "{}"
    ldap_hosts: "{}"
    storage_bms_hosts: "{}"
    storage_tb_bms_hosts: "{}"
    protocol_bms_hosts: "{}"
    afm_bms_hosts: "{}"
    domain_names: "{}"
    hosts_file: /etc/hosts

  tasks:
    - name: Parse and merge host mappings
      ansible.builtin.set_fact:
        all_hosts: >-
          {{ {} | combine(
              storage_hosts,
              storage_mgmnt_hosts,
              storage_tb_hosts,
              compute_hosts,
              compute_mgmnt_hosts,
              client_hosts,
              protocol_hosts,
              gklm_hosts,
              afm_hosts,
              ldap_hosts,
              storage_bms_hosts,
              storage_tb_bms_hosts,
              protocol_bms_hosts,
              afm_bms_hosts
            ) }}

    - name: Invert mapping to ensure 1 hostname = 1 IP (latest IP kept)
      ansible.builtin.set_fact:
        hostname_map: >-
          {{
            all_hosts
            | dict2items
            | reverse
            | items2dict(key_name='value', value_name='key')
          }}

    - name: Decode domain_names JSON string
      ansible.builtin.set_fact:
        domain_map: "{{ domain_names | from_json }}"

    - name: Generate managed block content
      ansible.builtin.set_fact:
        managed_block: |
          {% set compute = compute_hosts -%}
          {% set compute_mgmnt = compute_mgmnt_hosts -%}
          {% set storage = storage_hosts -%}
          {% set storage_mgmnt = storage_mgmnt_hosts -%}
          {% set storage_tb = storage_tb_hosts -%}
          {% set protocol = protocol_hosts -%}
          {% set client = client_hosts -%}
          {% set gklm = gklm_hosts -%}
          {% set storage_bms = storage_bms_hosts -%}
          {% set storage_tb_bms = storage_tb_bms_hosts -%}
          {% set protocol_bms = protocol_bms_hosts -%}
          {% set afm_bms = afm_bms_hosts -%}
          {% for hostname, ip in hostname_map.items() -%}
          {%   if ip in compute or ip in compute_mgmnt -%}
          {%     set domain = domain_map['compute'] -%}
          {%   elif ip in storage or ip in storage_mgmnt or ip in storage_bms or ip in storage_tb or ip in storage_tb_bms or ip in afm_bms -%}
          {%     set domain = domain_map['storage'] -%}
          {%   elif ip in protocol or ip in protocol_bms -%}
          {%     set domain = domain_map['protocol'] -%}
          {%   elif ip in client -%}
          {%     set domain = domain_map['client'] -%}
          {%   elif ip in gklm -%}
          {%     set domain = domain_map['gklm'] -%}
          {%   else -%}
          {%     set domain = 'localdomain' -%}
          {%   endif -%}
          {{ "%-15s %s %s.%s" | format(ip, hostname, hostname, domain) }}
          {% endfor %}

    - name: Update /etc/hosts with managed entries
      ansible.builtin.blockinfile:
        path: "{{ hosts_file }}"
        marker: "# === ANSIBLE MANAGED HOSTS {mark} ==="
        block: "{{ managed_block }}"
EOT
  filename = local.deployer_hostentry_playbook_path
}

resource "null_resource" "deploy_host_playbook" {
  count = var.scheduler == "Scale" ? 1 : 0
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = "sudo ansible-playbook -f 50 -e @${local.scale_cluster_hosts} -e 'domain_names=${local.dns_names}' '${local.deployer_hostentry_playbook_path}'"
   }

  triggers = {
    build = timestamp()
  }
  depends_on = [local_file.scale_cluster_hosts ,local_file.deployer_host_entry_playbook]
}

resource "local_file" "ansible_inventory" {
  count    = var.scheduler == "Scale" ? 1 : 0
  filename = local.scale_all_inventory

  content = join("\n", compact(flatten([
    # Storage Section (ONLY storage hosts)
    length(compact(flatten([
      values(try(var.storage_hosts, {})),
      values(try(var.storage_tb_hosts, {})),
      values(try(var.storage_bms_hosts, {})),
      values(try(var.storage_tb_bms_hosts, {})),
      values(try(var.storage_mgmnt_hosts, {})),
      values(try(var.afm_bms_hosts, {})),
      values(try(var.afm_hosts, {})),
      values(try(var.protocol_bms_hosts, {})),    
      values(try(var.protocol_hosts, {}))
    ]))) > 0 ? [
      "[storage]",
      join("\n", compact(flatten([
      values(try(var.storage_hosts, {})),
      values(try(var.storage_tb_hosts, {})),
      values(try(var.storage_bms_hosts, {})),
      values(try(var.storage_tb_bms_hosts, {})),
      values(try(var.storage_mgmnt_hosts, {})),
      values(try(var.afm_bms_hosts, {})),
      values(try(var.afm_hosts, {})),
      values(try(var.protocol_bms_hosts, {})),    
      values(try(var.protocol_hosts, {}))
      ]))),
      ""
    ] : [],

    # Storage Section (ONLY storage hosts)
    length(compact(flatten([
      join("\n", values(var.compute_hosts)),
      join("\n", values(var.compute_mgmnt_hosts))
    ]))) > 0 ? [
      "[compute]",
      join("\n", compact(flatten([
      join("\n", values(var.compute_hosts)),
      join("\n", values(var.compute_mgmnt_hosts))
      ]))),
      ""
    ] : [],

    # Client Section
    length(try(var.client_hosts, {})) > 0 ? [
      "[client]",
      join("\n", values(var.client_hosts))
    ] : [],

    # GKLM Section
    length(try(var.gklm_hosts, {})) > 0 ? [
      "[gklm]",
      join("\n", values(var.gklm_hosts))
    ] : [],

    # LDAP Section
    length(try(var.ldap_hosts, {})) > 0 ? [
      "[ldap]",
      join("\n", values(var.ldap_hosts))
    ] : []

  ])))
}

resource "local_file" "scale_host_entry_playbook" {
  count    = var.scheduler == "Scale" ? 1 : 0
  content  = <<EOT
---
- name: Manage /etc/hosts with dynamic host-IP mappings
  hosts: all
  become: yes
  vars:
    storage_hosts: "{}"
    storage_mgmnt_hosts: "{}"
    storage_tb_hosts: "{}"
    compute_hosts: "{}"
    compute_mgmnt_hosts: "{}"
    client_hosts: "{}"
    protocol_hosts: "{}"
    gklm_hosts: "{}"
    afm_hosts: "{}"
    ldap_hosts: "{}"
    storage_bms_hosts: "{}"
    storage_tb_bms_hosts: "{}"
    protocol_bms_hosts: "{}"
    afm_bms_hosts: "{}"
    domain_names: "{}"
    hosts_file: /etc/hosts

  tasks:
    - name: Parse and merge host mappings
      ansible.builtin.set_fact:
        all_hosts: >-
          {{ {} | combine(
              storage_hosts,
              storage_mgmnt_hosts,
              storage_tb_hosts,
              compute_hosts,
              compute_mgmnt_hosts,
              client_hosts,
              protocol_hosts,
              gklm_hosts,
              afm_hosts,
              ldap_hosts,
              storage_bms_hosts,
              storage_tb_bms_hosts,
              protocol_bms_hosts,
              afm_bms_hosts
            ) }}

    - name: Invert mapping to ensure 1 hostname = 1 IP (latest IP kept)
      ansible.builtin.set_fact:
        hostname_map: >-
          {{
            all_hosts
            | dict2items
            | reverse
            | items2dict(key_name='value', value_name='key')
          }}

    - name: Decode domain_names JSON string
      ansible.builtin.set_fact:
        domain_map: "{{ domain_names | from_json }}"

    - name: Generate managed block content
      ansible.builtin.set_fact:
        managed_block: |
          {% set compute = compute_hosts -%}
          {% set compute_mgmnt = compute_mgmnt_hosts -%}
          {% set storage = storage_hosts -%}
          {% set storage_mgmnt = storage_mgmnt_hosts -%}
          {% set storage_tb = storage_tb_hosts -%}
          {% set protocol = protocol_hosts -%}
          {% set client = client_hosts -%}
          {% set gklm = gklm_hosts -%}
          {% set storage_bms = storage_bms_hosts -%}
          {% set storage_tb_bms = storage_tb_bms_hosts -%}
          {% set protocol_bms = protocol_bms_hosts -%}
          {% set afm_bms = afm_bms_hosts -%}
          {% for ip, hostname in all_hosts.items() -%}
          {%   if ip in compute or ip in compute_mgmnt -%}
          {%     set domain = domain_map['compute'] -%}
          {%   elif ip in storage or ip in storage_mgmnt or ip in storage_bms or ip in storage_tb or ip in storage_tb_bms or ip in afm_bms -%}
          {%     set domain = domain_map['storage'] -%}
          {%   elif ip in protocol or ip in protocol_bms -%}
          {%     set domain = domain_map['protocol'] -%}
          {%   elif ip in client -%}
          {%     set domain = domain_map['client'] -%}
          {%   elif ip in gklm -%}
          {%     set domain = domain_map['gklm'] -%}
          {%   else -%}
          {%     set domain = domain_map.get('default', 'localdomain') -%}
          {%   endif -%}
          {{ "%-15s %s %s.%s" | format(ip, hostname, hostname, domain) }}
          {% endfor %}

    - name: Update /etc/hosts with managed entries
      ansible.builtin.blockinfile:
        path: "{{ hosts_file }}"
        marker: "# === ANSIBLE MANAGED HOSTS {mark} ==="
        block: "{{ managed_block }}"
EOT
  filename = local.scale_hostentry_playbook_path
}

resource "local_file" "remove_host_entry_playbook" {
  count = var.scheduler == "Scale" ? 1 : 0
  content  = <<EOT
---
- name: Removung host entries managed by Ansible
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