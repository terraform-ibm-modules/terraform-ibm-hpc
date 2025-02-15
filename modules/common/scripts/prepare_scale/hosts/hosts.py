import configparser
from common.common_utils import CommonUtils

class Hosts(CommonUtils):

    @staticmethod
    def create_hosts(ARGUMENTS, TF, cluster_type, quorum_count, gui_username, gui_password, profile_path, replica_config):
        # Step-5: Create hosts
        config = configparser.ConfigParser(allow_no_value=True)
        node_details = CommonUtils.initialize_node_details(len(TF['vpc_availability_zones']), cluster_type,
                                            TF['compute_cluster_instance_names'],
                                            TF['storage_cluster_instance_private_ips'],
                                            TF['storage_cluster_instance_names'],
                                            list(TF["storage_cluster_with_data_volume_mapping"].keys()),
                                            TF["afm_cluster_instance_names"],
                                            TF['protocol_cluster_instance_names'],
                                            TF['storage_cluster_desc_instance_private_ips'],
                                            quorum_count, "root", ARGUMENTS.instance_private_key, ARGUMENTS.tf_inv_path)
        node_template = ""
        for each_entry in node_details:
            if ARGUMENTS.bastion_ssh_private_key is None:
                each_entry = each_entry + " " + "ansible_ssh_common_args="""
                node_template = node_template + each_entry + "\n"
            else:
                proxy_command = f"ssh -p 22 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -W %h:%p {ARGUMENTS.bastion_user}@{ARGUMENTS.bastion_ip} -i {ARGUMENTS.bastion_ssh_private_key}"
                each_entry = each_entry + " " + \
                    "ansible_ssh_common_args='-o ControlMaster=auto -o ControlPersist=30m -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o ProxyCommand=\"" + proxy_command + "\"'"
                node_template = node_template + each_entry + "\n"

        if TF['resource_prefix']:
            cluster_name = TF['resource_prefix']
        else:
            cluster_name = "%s.%s" % ("spectrum-scale", cluster_type)

        config['all:vars'] = CommonUtils.initialize_cluster_details(TF['scale_version'],
                                                        cluster_name,
                                                        cluster_type,
                                                        gui_username,
                                                        gui_password,
                                                        profile_path,
                                                        replica_config,
                                                        ARGUMENTS.enable_mrot_conf,
                                                        ARGUMENTS.enable_ces,
                                                        ARGUMENTS.enable_afm,
                                                        ARGUMENTS.enable_key_protect,
                                                        TF['storage_subnet_cidr'],
                                                        TF['compute_subnet_cidr'],
                                                        TF['protocol_gateway_ip'],
                                                        TF['scale_remote_cluster_clustername'],
                                                        ARGUMENTS.scale_encryption_servers,
                                                        ARGUMENTS.scale_encryption_admin_password,
                                                        ARGUMENTS.scale_encryption_type,
                                                        ARGUMENTS.scale_encryption_enabled,
                                                        TF['filesystem_mountpoint'],
                                                        TF['vpc_region'],
                                                        ARGUMENTS.enable_ldap,
                                                        ARGUMENTS.ldap_basedns,
                                                        ARGUMENTS.ldap_server,
                                                        ARGUMENTS.ldap_admin_password,
                                                        TF['afm_cos_bucket_details'],
                                                        TF['afm_config_details'])
        with open("%s/%s/%s_inventory.ini" % (ARGUMENTS.install_infra_path,
                                            "ibm-spectrum-scale-install-infra",
                                            cluster_type), 'w') as configfile:
            configfile.write('[scale_nodes]' + "\n")
            configfile.write(node_template)
            config.write(configfile)

        if ARGUMENTS.verbose:
            config.read("%s/%s/%s_inventory.ini" % (ARGUMENTS.install_infra_path,
                                                    "ibm-spectrum-scale-install-infra",
                                                    cluster_type))
            print("Content of %s/%s/%s_inventory.ini" % (ARGUMENTS.install_infra_path,
                                                        "ibm-spectrum-scale-install-infra",
                                                        cluster_type))
            print('[scale_nodes]')
            print(node_template)
            print('[all:vars]')
            for each_key in config['all:vars']:
                print("%s: %s" % (each_key, config.get('all:vars', each_key)))