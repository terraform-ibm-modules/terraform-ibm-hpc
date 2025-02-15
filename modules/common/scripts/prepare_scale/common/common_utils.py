import os
import json
import pathlib
import sys
import re


class CommonUtils:

    @staticmethod
    def cleanup(target_file):
        """ Cleanup host inventory, group_vars """
        if os.path.exists(target_file):
            os.remove(target_file)

    @staticmethod
    def calculate_pagepool(nodeclass, memory):
        """ Calculate pagepool """
        memory = float(memory)
        if nodeclass == "computenodegrp":
            pagepool_gb = min(int((memory * 0.12) // 1 + 1), 16)
        elif nodeclass == "storageprotocolnodegrp":
            pagepool_gb = min(int((memory * 0.4) // 1), 256)
        else:
            pagepool_gb = min(int((memory * 0.25) // 1), 32)

        return "{}G".format(pagepool_gb)

    @staticmethod
    def calculate_maxStatCache(nodeclass, memory):
        """ Calculate maxStatCache """

        if nodeclass == "computenodegrp":
            maxStatCache = "256K"
        elif nodeclass in ["managementnodegrp", "storagedescnodegrp", "storagenodegrp"]:
            maxStatCache = "128K"
        else:
            maxStatCache = str(min(int(memory * 8), 512)) + "K"
        return maxStatCache

    @staticmethod
    def calculate_maxFilesToCache(nodeclass, memory):
        """ Calculate maxFilesToCache """

        if nodeclass == "computenodegrp":
            maxFilesToCache = "256K"
        elif nodeclass in ["managementnodegrp", "storagedescnodegrp", "storagenodegrp"]:
            maxFilesToCache = "128K"
        else:
            calFilesToCache = int(memory * 8)
            if calFilesToCache < 1024:
                maxFilesToCache = str(calFilesToCache) + "K"
            else:
                maxFilesToCache = str(
                    int(min((calFilesToCache / 1024), 3)) // 1) + "M"
        return maxFilesToCache

    @staticmethod
    def calculate_maxReceiverThreads(vcpus):
        """ Calculate maxReceiverThreads """
        maxReceiverThreads = int(vcpus)
        return maxReceiverThreads

    @staticmethod
    def calculate_maxMBpS(bandwidth):
        """ Calculate maxMBpS """
        maxMBpS = int(int(bandwidth) * 0.25)
        return maxMBpS
    
    @staticmethod
    def check_nodeclass(nodeclass):
        """Check nodeclass"""
        nodeclass_name = nodeclass
        return nodeclass_name

    @staticmethod
    def check_afm_values():
        """Check afm values"""
        afmHardMemThreshold = "40G"
        afm_config = {"afmHardMemThreshold": afmHardMemThreshold}
        return afm_config

    @classmethod
    def generate_nodeclass_config(cls, nodeclass, memory, vcpus, bandwidth):
        """ Populate all calculated params """
        check_nodeclass_name = cls.check_nodeclass(nodeclass)
        pagepool_details     = cls.calculate_pagepool(nodeclass, memory)
        maxStatCache_details = cls.calculate_maxStatCache(nodeclass, memory)
        maxFilesToCache      = cls.calculate_maxFilesToCache(nodeclass, memory)
        maxReceiverThreads   = cls.calculate_maxReceiverThreads(vcpus)
        maxMBpS              = cls.calculate_maxMBpS(bandwidth)
        cluster_tuneable_details = [{"nodeclass_name": check_nodeclass_name},{
            "pagepool": pagepool_details,
            "maxStatCache": maxStatCache_details,
            "maxFilesToCache": maxFilesToCache,
            "maxReceiverThreads": maxReceiverThreads,
            "maxMBpS": maxMBpS
        }]
        return cluster_tuneable_details

    @staticmethod
    def create_directory(target_directory):
        """ Create specified directory """
        pathlib.Path(target_directory).mkdir(parents=True, exist_ok=True)

    @staticmethod
    def read_json_file(json_path):
        """ Read inventory as json file """
        tf_inv = {}
        try:
            with open(json_path) as json_handler:
                try:
                    tf_inv = json.load(json_handler)
                except json.decoder.JSONDecodeError:
                    print("Provided terraform inventory file (%s) is not a valid "
                        "json." % json_path)
                    sys.exit(1)
        except OSError:
            print("Provided terraform inventory file (%s) does not exist." % json_path)
            sys.exit(1)

        return tf_inv

    @staticmethod
    def write_json_file(json_data, json_path):
        """ Write inventory to json file """
        with open(json_path, 'w') as json_handler:
            json.dump(json_data, json_handler, indent=4)

    @staticmethod
    def write_to_file(filepath, filecontent):
        """ Write to specified file """
        with open(filepath, "w") as file_handler:
            file_handler.write(filecontent)
    
    @staticmethod
    def prepare_ansible_playbook(hosts_config, cluster_config, cluster_key_file):
        """ Write to playbook """
        content = """---
    # Ensure provisioned VMs are up and Passwordless SSH setup
    # has been compleated and operational
    - name: Check passwordless SSH connection is setup
    hosts: {hosts_config}
    any_errors_fatal: true
    gather_facts: false
    connection: local
    tasks:
    - name: Check passwordless SSH on all scale inventory hosts
        shell: ssh {{{{ ansible_ssh_common_args }}}} -i {cluster_key_file} root@{{{{ inventory_hostname }}}} "echo PASSWDLESS_SSH_ENABLED"
        register: result
        until: result.stdout.find("PASSWDLESS_SSH_ENABLED") != -1
        retries: 240
        delay: 10
    # Validate Scale packages existence to skip node role
    - name: Check if Scale packages already installed on node
    hosts: scale_nodes
    gather_facts: false
    vars:
        scale_packages_installed: true
        scale_packages:
        - gpfs.base
        - gpfs.adv
        - gpfs.crypto
        - gpfs.docs
        - gpfs.gpl
        - gpfs.gskit
        - gpfs.gss.pmcollector
        - gpfs.gss.pmsensors
        - gpfs.gui
        - gpfs.java
    #      - gpfs.afm
    #      - gpfs.nfs-ganesha
    tasks:
    - name: Check if scale packages are already installed
        shell: rpm -q "{{{{ item }}}}"
        loop: "{{{{ scale_packages }}}}"
        register: scale_packages_check
        ignore_errors: true

    - name: Set scale packages installation variable
        set_fact:
        scale_packages_installed: false
        when:  item.rc != 0
        loop: "{{{{ scale_packages_check.results }}}}"
        ignore_errors: true

    # Install and config Spectrum Scale on nodes
    - hosts: {hosts_config}
    collections:
        - ibm.spectrum_scale
    any_errors_fatal: true
    vars:
        - scale_node_update_check: false
    pre_tasks:
        - include_vars: group_vars/{cluster_config}
    roles:
        - core_prepare
        - {{ role: core_install, when: "scale_packages_installed is false" }}
        - core_configure
    #    - gui_prepare
        - {{ role: gui_install, when: "scale_packages_installed is false" }}
        - gui_configure
        - gui_verify
        - perfmon_prepare
        - {{ role: perfmon_install, when: "scale_packages_installed is false" }}
        - perfmon_configure
        - perfmon_verify
        - {{ role: mrot_config, when: enable_mrot }}
        - {{ role: nfs_prepare, when: enable_ces }}
        - {{ role: nfs_install, when: "enable_ces and scale_packages_installed is false" }}
        - {{ role: nfs_ic_failover, when: enable_ces }}
        - {{ role: nfs_configure, when: enable_ces }}
        - {{ role: nfs_route_configure, when: enable_ces }}
        - {{ role: nfs_verify, when: enable_ces }}
        - {{ role: auth_prepare, when: enable_ces }}
        - {{ role: auth_configure, when: enable_ldap or enable_ces }}
        - {{ role: nfs_file_share, when: enable_ces }}
        - {{ role: afm_cos_prepare, when: enable_afm }}
        - {{ role: afm_cos_install, when: "enable_afm and scale_packages_installed is false" }}
        - {{ role: afm_cos_configure, when: enable_afm }}
        - {{ role: kp_encryption_prepare, when: "enable_key_protect and scale_cluster_type == 'storage'" }}
        - {{ role: kp_encryption_configure, when: enable_key_protect }}
        - {{ role: kp_encryption_apply, when: "enable_key_protect and scale_cluster_type == 'storage'" }}
    """.format(hosts_config=hosts_config, cluster_config=cluster_config,
            cluster_key_file=cluster_key_file)
        return content

    @staticmethod
    def prepare_packer_ansible_playbook(hosts_config, cluster_config):
        """ Write to playbook """
        content = """---
    # Install and config Spectrum Scale on nodes
    - hosts: {hosts_config}
    collections:
        - ibm.spectrum_scale
    any_errors_fatal: true
    pre_tasks:
        - include_vars: group_vars/{cluster_config}
    roles:
        - core_configure
        - gui_configure
        - gui_verify
        - perfmon_configure
        - perfmon_verify
    """.format(hosts_config=hosts_config, cluster_config=cluster_config)
        return content

    @staticmethod
    def prepare_nogui_ansible_playbook(hosts_config, cluster_config):
        """ Write to playbook """
        content = """---
    # Install and config Spectrum Scale on nodes
    - hosts: {hosts_config}
    collections:
        - ibm.spectrum_scale
    any_errors_fatal: true
    pre_tasks:
        - include_vars: group_vars/{cluster_config}
    roles:
        - core_prepare
        - core_install
        - core_configure
    """.format(hosts_config=hosts_config, cluster_config=cluster_config)
        return content

    @staticmethod
    def prepare_nogui_packer_ansible_playbook(hosts_config, cluster_config):
        """ Write to playbook """
        content = """---
    # Install and config Spectrum Scale on nodes
    - hosts: {hosts_config}
    collections:
        - ibm.spectrum_scale
    any_errors_fatal: true
    pre_tasks:
        - include_vars: group_vars/{cluster_config}
    roles:
        - core_configure
    """.format(hosts_config=hosts_config, cluster_config=cluster_config)
        return content

    @staticmethod
    def prepare_ansible_playbook_encryption_gklm():
        # Write to playbook
        content = """---
    # Encryption setup for the key servers
    - hosts: localhost
    collections:
        - ibm.spectrum_scale
    any_errors_fatal: true

    roles:
        - encryption_prepare
    """
        return content.format()

    @staticmethod
    def prepare_ansible_playbook_encryption_cluster(hosts_config):
        # Write to playbook
        content = """---
    # Enabling encryption on Storage Scale
    - hosts: {hosts_config}
    collections:
        - ibm.spectrum_scale
    any_errors_fatal: true

    roles:
        - encryption_configure
    """
        return content.format(hosts_config=hosts_config)
    
    @staticmethod
    def initialize_cluster_details(scale_version, cluster_name, cluster_type, username, password, scale_profile_path, scale_replica_config, enable_mrot,
                                enable_ces, enable_afm, enable_key_protect, storage_subnet_cidr, compute_subnet_cidr, protocol_gateway_ip, scale_remote_cluster_clustername,
                                scale_encryption_servers, scale_encryption_admin_password, scale_encryption_type, scale_encryption_enabled, filesystem_mountpoint, vpc_region, enable_ldap, ldap_basedns, ldap_server, ldap_admin_password, afm_cos_bucket_details, afm_config_details):
        """ Initialize cluster details.
        :args: scale_version (string), cluster_name (string),
            username (string), password (string), scale_profile_path (string),
            scale_replica_config (bool) ,scale_encryption_servers (list),  scale_encryption_ssh_key_file (string),
            scale_encryption_admin_password(string)
        """
        cluster_details = {}
        cluster_details['scale_version'] = scale_version
        cluster_details['scale_cluster_clustername'] = cluster_name
        cluster_details['scale_cluster_type'] = cluster_type
        cluster_details['scale_service_gui_start'] = "True"
        cluster_details['scale_gui_admin_user'] = username
        cluster_details['scale_gui_admin_password'] = password
        cluster_details['scale_gui_admin_role'] = "Administrator"
        cluster_details['scale_sync_replication_config'] = scale_replica_config
        cluster_details['scale_cluster_profile_name'] = str(
            pathlib.PurePath(scale_profile_path).stem)
        cluster_details['scale_cluster_profile_dir_path'] = str(
            pathlib.PurePath(scale_profile_path).parent)
        cluster_details['enable_mrot'] = enable_mrot
        cluster_details['enable_ces'] = enable_ces
        cluster_details['enable_afm'] = enable_afm
        cluster_details['enable_key_protect'] = enable_key_protect
        cluster_details['storage_subnet_cidr'] = storage_subnet_cidr
        cluster_details['compute_subnet_cidr'] = compute_subnet_cidr
        cluster_details['protocol_gateway_ip'] = protocol_gateway_ip
        cluster_details['scale_remote_cluster_clustername'] = scale_remote_cluster_clustername
        # Preparing list for Encryption Servers
        if scale_encryption_servers:
            cleaned_ip_string = scale_encryption_servers.strip(
                '[]').replace('\\"', '').split(',')
            # Remove extra double quotes around each IP address and create the final list
            formatted_ip_list = [ip.strip('"') for ip in cleaned_ip_string]
            cluster_details['scale_encryption_servers'] = formatted_ip_list
        else:
            cluster_details['scale_encryption_servers'] = []
        cluster_details['scale_encryption_admin_password'] = scale_encryption_admin_password
        cluster_details['scale_encryption_type'] = scale_encryption_type
        if scale_encryption_enabled == "true" and scale_encryption_type != "gklm":
            cluster_details['filesystem_mountpoint'] = filesystem_mountpoint
            cluster_details['vpc_region'] = vpc_region
        else:
            cluster_details['filesystem_mountpoint'] = ""
            cluster_details['vpc_region'] = ""
        cluster_details['enable_ldap'] = enable_ldap
        cluster_details['ldap_basedns'] = ldap_basedns
        cluster_details['ldap_server'] = ldap_server
        cluster_details['ldap_admin_password'] = ldap_admin_password
        cluster_details['scale_afm_cos_bucket_params'] = afm_cos_bucket_details
        cluster_details['scale_afm_cos_filesets_params'] = afm_config_details
        return cluster_details

    @staticmethod
    def get_host_format(node):
        """ Return host entries """
        host_format = f"{node['ip_addr']} scale_cluster_quorum={node['is_quorum']} scale_cluster_manager={node['is_manager']} scale_cluster_gui={node['is_gui']} scale_zimon_collector={node['is_collector']} is_nsd_server={node['is_nsd']} is_admin_node={node['is_admin']} ansible_user={node['user']} ansible_ssh_private_key_file={node['key_file']} ansible_python_interpreter=/usr/bin/python3 scale_nodeclass={node['class']} scale_daemon_nodename={node['daemon_nodename']} scale_protocol_node={node['scale_protocol_node']} scale_cluster_gateway={node['scale_cluster_gateway']}"
        return host_format

    @classmethod
    def initialize_node_details(cls, az_count, cls_type, compute_cluster_instance_names, storage_private_ips,
                                storage_cluster_instance_names, storage_nsd_server_instance_names, afm_cluster_instance_names,
                                protocol_cluster_instance_names, desc_private_ips, quorum_count,
                                user, key_file, tf_inv_path):
        """ Initialize node details for cluster definition.
        :args: az_count (int), cls_type (string), compute_private_ips (list),
            storage_private_ips (list), desc_private_ips (list),
            quorum_count (int), user (string), key_file (string)
        """
        manager_count = 2
        node_details, node = [], {}
        if cls_type == 'compute':
            total_compute_node = len(compute_cluster_instance_names)
            start_quorum_assign = quorum_count - 1
            for each_ip in compute_cluster_instance_names:
                each_name = each_ip.split('.')[0]
                if compute_cluster_instance_names.index(each_ip) <= (start_quorum_assign):
                    node = {'ip_addr': each_ip, 'is_quorum': True, 'is_manager': True,
                            'is_gui': False, 'is_collector': False, 'is_nsd': False,
                            'is_admin': True, 'user': user, 'key_file': key_file,
                            'class': "computenodegrp", 'daemon_nodename': each_name, 'scale_protocol_node': False, 'scale_cluster_gateway': False}
                # Scale Management node defination
                elif compute_cluster_instance_names.index(each_ip) == total_compute_node - 1:
                    node = {'ip_addr': each_ip, 'is_quorum': False, 'is_manager': False,
                            'is_gui': True, 'is_collector': True, 'is_nsd': False,
                            'is_admin': True, 'user': user, 'key_file': key_file,
                            'class': "managementnodegrp", 'daemon_nodename': each_name, 'scale_protocol_node': False, 'scale_cluster_gateway': False}
                    cls.write_json_file({'compute_cluster_gui_ip_address': each_ip},
                                    "%s/%s" % (str(pathlib.PurePath(tf_inv_path).parent),
                                            "compute_cluster_gui_details.json"))
                else:
                    # Non-quorum node defination
                    node = {'ip_addr': each_ip, 'is_quorum': False, 'is_manager': True,
                            'is_gui': False, 'is_collector': False, 'is_nsd': False,
                            'is_admin': True, 'user': user, 'key_file': key_file,
                            'class': "computenodegrp", 'daemon_nodename': each_name, 'scale_protocol_node': False, 'scale_cluster_gateway': False}
                node_details.append(cls.get_host_format(node))

        elif cls_type == 'storage':
            total_storage_node = len(storage_cluster_instance_names)
            start_quorum_assign = quorum_count - 1
            for each_ip in storage_cluster_instance_names:
                each_name = each_ip.split('.')[0]
                is_protocol = each_ip in protocol_cluster_instance_names
                is_nsd = each_name in storage_nsd_server_instance_names
                is_afm = each_ip in afm_cluster_instance_names
                if is_nsd:
                    if is_protocol:
                        nodeclass = "storageprotocolnodegrp"
                    else:
                        nodeclass = "storagenodegrp"
                else:
                    if is_protocol:
                        nodeclass = "protocolnodegrp"
                    elif is_afm:
                        nodeclass = "afmgatewaygrp"
                    else:
                        nodeclass = "managementnodegrp"
                if storage_cluster_instance_names.index(each_ip) < (start_quorum_assign):
                    node = {'ip_addr': each_ip, 'is_quorum': True, 'is_manager': True,
                            'is_gui': False, 'is_collector': False, 'is_nsd': is_nsd,
                            'is_admin': True, 'user': user, 'key_file': key_file,
                            'class': nodeclass, 'daemon_nodename': each_name, 'scale_protocol_node': is_protocol, 'scale_cluster_gateway': is_afm}
                # Tie-breaker node defination
                elif storage_cluster_instance_names.index(each_ip) == total_storage_node - 1:
                    node = {'ip_addr': each_ip, 'is_quorum': True, 'is_manager': False,
                            'is_gui': False, 'is_collector': False, 'is_nsd': True,
                            'is_admin': False, 'user': user, 'key_file': key_file,
                            'class': "storagedescnodegrp", 'daemon_nodename': each_name, 'scale_protocol_node': False, 'scale_cluster_gateway': False}
                # Scale Management node defination
                elif storage_cluster_instance_names.index(each_ip) == total_storage_node - 2:
                    node = {'ip_addr': each_ip, 'is_quorum': False, 'is_manager': False,
                            'is_gui': True, 'is_collector': True, 'is_nsd': False,
                            'is_admin': True, 'user': user, 'key_file': key_file,
                            'class': "managementnodegrp", 'daemon_nodename': each_name, 'scale_protocol_node': False, 'scale_cluster_gateway': False}
                    cls.write_json_file({'storage_cluster_gui_ip_address': each_ip},
                                    "%s/%s" % (str(pathlib.PurePath(tf_inv_path).parent),
                                            "storage_cluster_gui_details.json"))
                else:
                    # Non-quorum node defination
                    node = {'ip_addr': each_ip, 'is_quorum': False, 'is_manager': is_nsd,
                            'is_gui': False, 'is_collector': False, 'is_nsd': is_nsd,
                            'is_admin': is_nsd, 'user': user, 'key_file': key_file,
                            'class': nodeclass, 'daemon_nodename': each_name, 'scale_protocol_node': is_protocol, 'scale_cluster_gateway': is_afm}
                node_details.append(cls.get_host_format(node))

        elif cls_type == 'combined':
            for each_ip in desc_private_ips:
                node = {'ip_addr': each_ip, 'is_quorum': True, 'is_manager': False,
                        'is_gui': False, 'is_collector': False, 'is_nsd': True,
                        'is_admin': False, 'user': user, 'key_file': key_file,
                        'class': "computedescnodegrp"}
                node_details.append(cls.get_host_format(node))

            if az_count > 1:
                # Storage/NSD nodes to be quorum nodes (quorum_count - 2 as index starts from 0)
                start_quorum_assign = quorum_count - 2
            else:
                # Storage/NSD nodes to be quorum nodes (quorum_count - 1 as index starts from 0)
                start_quorum_assign = quorum_count - 1

            for each_ip in storage_cluster_instance_names:
                if storage_cluster_instance_names.index(each_ip) <= (start_quorum_assign) and \
                        storage_cluster_instance_names.index(each_ip) <= (manager_count - 1):
                    if storage_cluster_instance_names.index(each_ip) == 0:
                        node = {'ip_addr': each_ip, 'is_quorum': True, 'is_manager': True,
                                'is_gui': True, 'is_collector': True, 'is_nsd': True,
                                'is_admin': True, 'user': user, 'key_file': key_file,
                                'class': "storagenodegrp"}
                    elif storage_cluster_instance_names.index(each_ip) == 1:
                        node = {'ip_addr': each_ip, 'is_quorum': True, 'is_manager': True,
                                'is_gui': False, 'is_collector': True, 'is_nsd': True,
                                'is_admin': True, 'user': user, 'key_file': key_file,
                                'class': "storagenodegrp"}
                    else:
                        node = {'ip_addr': each_ip, 'is_quorum': True, 'is_manager': True,
                                'is_gui': False, 'is_collector': False, 'is_nsd': True,
                                'is_admin': True, 'user': user, 'key_file': key_file,
                                'class': "storagenodegrp"}
                elif storage_cluster_instance_names.index(each_ip) <= (start_quorum_assign) and \
                        storage_cluster_instance_names.index(each_ip) > (manager_count - 1):
                    node = {'ip_addr': each_ip, 'is_quorum': True, 'is_manager': False,
                            'is_gui': False, 'is_collector': False, 'is_nsd': True,
                            'is_admin': True, 'user': user, 'key_file': key_file,
                            'class': "storagenodegrp"}
                else:
                    node = {'ip_addr': each_ip, 'is_quorum': False, 'is_manager': False,
                            'is_gui': False, 'is_collector': False, 'is_nsd': True,
                            'is_admin': False, 'user': user, 'key_file': key_file,
                            'class': "storagenodegrp"}
                node_details.append(cls.get_host_format(node))

            if az_count > 1:
                if len(storage_private_ips) - len(desc_private_ips) >= quorum_count:
                    quorums_left = 0
                else:
                    quorums_left = quorum_count - \
                        len(storage_private_ips) - len(desc_private_ips)
            else:
                if len(storage_private_ips) > quorum_count:
                    quorums_left = 0
                else:
                    quorums_left = quorum_count - len(storage_private_ips)

            # Additional quorums assign to compute nodes
            if quorums_left > 0:
                for each_ip in compute_cluster_instance_names[0:quorums_left]:
                    node = {'ip_addr': each_ip, 'is_quorum': True, 'is_manager': False,
                            'is_gui': False, 'is_collector': False, 'is_nsd': False,
                            'is_admin': True, 'user': user, 'key_file': key_file,
                            'class': "computenodegrp"}
                    node_details.append(cls.get_host_format(node))
                for each_ip in compute_cluster_instance_names[quorums_left:]:
                    node = {'ip_addr': each_ip, 'is_quorum': False, 'is_manager': False,
                            'is_gui': False, 'is_collector': False, 'is_nsd': False,
                            'is_admin': False, 'user': user, 'key_file': key_file,
                            'class': "computenodegrp"}
                    node_details.append(cls.get_host_format(node))

            if quorums_left == 0:
                for each_ip in compute_cluster_instance_names:
                    node = {'ip_addr': each_ip, 'is_quorum': False, 'is_manager': False,
                            'is_gui': False, 'is_collector': False, 'is_nsd': False,
                            'is_admin': False, 'user': user, 'key_file': key_file,
                            'class': "computenodegrp"}
                    node_details.append(cls.get_host_format(node))
        return node_details

    @staticmethod
    def initialize_scale_config_details(list_nodclass_param_dict):
        """ Initialize scale cluster config details.
        :args: node_class (list), comp_nodeclass_config (dict), mgmt_nodeclass_config (dict), strg_desc_nodeclass_config (dict), strg_nodeclass_config (dict), proto_nodeclass_config (dict), strg_proto_nodeclass_config (dict)
        """
        scale_config = {}
        scale_config['scale_config'], scale_config['scale_cluster_config'] = [], {}

        for param_dicts in list_nodclass_param_dict:
            if param_dicts[1] != {}:
                scale_config['scale_config'].append({"nodeclass": list(param_dicts[0].values())[0], "params": [param_dicts[1]]})

        scale_config['scale_cluster_config']['ephemeral_port_range'] = "60000-61000"
        return scale_config

    @staticmethod
    def get_disks_list(az_count, disk_mapping, desc_disk_mapping, disk_type):
        """ Initialize disk list. """
        disks_list = []
        if disk_type == "locally-attached":
            failureGroup = 0
            for each_ip, disk_per_ip in disk_mapping.items():
                failureGroup = failureGroup + 1
                for each_disk in disk_per_ip:
                    disks_list.append({"device": each_disk,
                                    "failureGroup": failureGroup, "servers": each_ip,
                                    "usage": "dataAndMetadata", "pool": "system"})

        # Map storage nodes to failure groups based on AZ and subnet variations
        else:
            failure_group1, failure_group2 = [], []
            if az_count == 1:
                # Single AZ, just split list equally
                failure_group1 = [key for index, key in enumerate(disk_mapping) if index % 2 == 0]
                failure_group2 = [key for index, key in enumerate(disk_mapping) if index % 2 != 0]
            else:
                # Multi AZ, split based on subnet match
                subnet_pattern = re.compile(
                    r'\d{1,3}\.\d{1,3}\.(\d{1,3})\.\d{1,3}')
                subnet1A = subnet_pattern.findall(list(disk_mapping)[0])
                for each_ip in disk_mapping:
                    current_subnet = subnet_pattern.findall(each_ip)
                    if current_subnet[0] == subnet1A[0]:
                        failure_group1.append(each_ip)
                    else:
                        failure_group2.append(each_ip)

            storage_instances = []
            max_len = max(len(failure_group1), len(failure_group2))
            idx = 0
            while idx < max_len:
                if idx < len(failure_group1):
                    storage_instances.append(failure_group1[idx])

                if idx < len(failure_group2):
                    storage_instances.append(failure_group2[idx])

                idx = idx + 1

            for each_ip, disk_per_ip in disk_mapping.items():
                if each_ip in failure_group1:
                    for each_disk in disk_per_ip:
                        disks_list.append({"device": each_disk,
                                        "failureGroup": 1, "servers": each_ip,
                                        "usage": "dataAndMetadata", "pool": "system"})
                if each_ip in failure_group2:
                    for each_disk in disk_per_ip:
                        disks_list.append({"device": each_disk,
                                        "failureGroup": 2, "servers": each_ip,
                                        "usage": "dataAndMetadata", "pool": "system"})

            # Append "descOnly" disk details
            if len(desc_disk_mapping.keys()):
                disks_list.append({"device": list(desc_disk_mapping.values())[0][0],
                                "failureGroup": 3,
                                "servers": list(desc_disk_mapping.keys())[0],
                                "usage": "descOnly", "pool": "system"})
        return disks_list

    @staticmethod
    def initialize_scale_storage_details(az_count, fs_mount, block_size, disk_details, default_metadata_replicas, max_metadata_replicas, default_data_replicas, max_data_replicas, filesets):
        """ Initialize storage details.
        :args: az_count (int), fs_mount (string), block_size (string),
            disks_list (list), filesets (dictionary)
        """
        filesets_name_size = {
            key.split('/')[-1]: value for key, value in filesets.items()}

        storage = {}
        storage['scale_storage'] = []
        if not default_data_replicas:
            if az_count > 1:
                default_data_replicas = 2
                default_metadata_replicas = 2
            else:
                default_data_replicas = 1
                default_metadata_replicas = 2

        storage['scale_storage'].append({"filesystem": pathlib.PurePath(fs_mount).name,
                                        "blockSize": block_size,
                                        "defaultDataReplicas": default_data_replicas,
                                        "defaultMetadataReplicas": default_metadata_replicas,
                                        "maxDataReplicas": max_data_replicas,
                                        "maxMetadataReplicas": max_metadata_replicas,
                                        "automaticMountOption": "true",
                                        "defaultMountPoint": fs_mount,
                                        "disks": disk_details,
                                        "filesets": filesets_name_size})
        return storage

    @staticmethod
    def initialize_scale_ces_details(smb, nfs, object, export_ip_pool, filesystem, mountpoint, filesets, protocol_cluster_instance_names, enable_ces):
        """ Initialize ces details.
        :args: smb (bool), nfs (bool), object (bool),
            export_ip_pool (list), filesystem (string), mountpoint (string)
        """
        exports = []
        export_node_ip_map = []
        if enable_ces == "True":
            filesets_name_size = {
                key.split('/')[-1]: value for key, value in filesets.items()}
            exports = list(filesets_name_size.keys())

            # Creating map of CES nodes and it Ips
            export_node_ip_map = [{protocol_cluster_instance_name.split(
                '.')[0]: ip} for protocol_cluster_instance_name, ip in zip(protocol_cluster_instance_names, export_ip_pool)]

        ces = {
            "scale_protocols": {
                "nfs": nfs,
                "object": object,
                "smb": smb,
                "export_node_ip_map": export_node_ip_map,
                "filesystem": filesystem,
                "mountpoint": mountpoint,
                "exports": exports
            }
        }
        return ces