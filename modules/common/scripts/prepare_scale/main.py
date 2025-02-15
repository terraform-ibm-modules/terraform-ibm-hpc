import argparse
import sys
import json
from common.common_utils import CommonUtils
from scale.scale_utils import ScaleClusters
from playbooks.playbooks import Playbooks
from hosts.hosts import Hosts
from groupvars.groupvars import GroupVars


if __name__ == "__main__":
    PARSER = argparse.ArgumentParser(description='Convert terraform inventory '
                                                 'to ansible inventory format '
                                                 'install and configuration.')
    PARSER.add_argument('--tf_inv_path', required=True,
                        help='Terraform inventory file path')
    PARSER.add_argument('--install_infra_path', required=True,
                        help='Spectrum Scale install infra clone parent path')
    PARSER.add_argument('--instance_private_key', required=True,
                        help='Spectrum Scale instances SSH private key path')
    PARSER.add_argument('--bastion_user',
                        help='Bastion OS Login username')
    PARSER.add_argument('--bastion_ip',
                        help='Bastion SSH public ip address')
    PARSER.add_argument('--bastion_ssh_private_key',
                        help='Bastion SSH private key path')
    PARSER.add_argument('--memory_size', help='Instance memory size')
    PARSER.add_argument('--max_pagepool_gb', help='maximum pagepool size in GB',
                        default=1)
    PARSER.add_argument('--disk_type', help='Disk type')
    PARSER.add_argument('--default_data_replicas',
                        help='Value for default data replica')
    PARSER.add_argument('--max_data_replicas',
                        help='Value for max data replica')
    PARSER.add_argument('--default_metadata_replicas',
                        help='Value for default metadata replica')
    PARSER.add_argument('--max_metadata_replicas',
                        help='Value for max metadata replica')
    PARSER.add_argument('--using_packer_image', help='skips gpfs rpm copy')
    PARSER.add_argument('--using_rest_initialization',
                        help='skips gui configuration')
    PARSER.add_argument('--gui_username', required=True,
                        help='Spectrum Scale GUI username')
    PARSER.add_argument('--gui_password', required=True,
                        help='Spectrum Scale GUI password')
    PARSER.add_argument('--enable_mrot_conf', required=True,
                        help='Configure MROT and Logical Subnet')
    PARSER.add_argument('--enable_ces', required=True,
                        help='Configure CES on protocol nodes')
    PARSER.add_argument('--verbose', action='store_true',
                        help='print log messages')
    PARSER.add_argument('--scale_encryption_servers', help='List of key servers for encryption',
                        default=[])
    PARSER.add_argument('--scale_encryption_admin_password', help='Admin Password for the Key server',
                        default="null")
    PARSER.add_argument('--scale_encryption_type', help='Encryption type should be either GKLM or Key_Protect',
                        default="null")
    PARSER.add_argument('--scale_encryption_enabled', help='Enabling encryption feature',
                        default=False)
    PARSER.add_argument('--enable_ldap', help='Enabling the LDAP',
                        default=False)
    PARSER.add_argument('--ldap_basedns', help='Base domain of ldap',
                        default="null")
    PARSER.add_argument('--ldap_server', help='LDAP Server IP',
                        default="null")
    PARSER.add_argument('--ldap_admin_password', help='LDAP Admin Password',
                        default="null")
    PARSER.add_argument("--colocate_protocol_cluster_instances", help="It checks if colocation is enabled",
                        default=False)
    PARSER.add_argument("--is_colocate_protocol_subset", help="It checks if protocol node count is less than storage NSD node count",
                        default=False)
    PARSER.add_argument("--comp_memory", help="Compute node memory",
                        default=32)
    PARSER.add_argument("--comp_vcpus_count", help="Compute node vcpus count",
                        default=8)
    PARSER.add_argument("--comp_bandwidth", help="Compute node bandwidth",
                        default=16000)
    PARSER.add_argument("--mgmt_memory", help="Management node memory",
                        default=32)
    PARSER.add_argument("--mgmt_vcpus_count", help="Management node vcpus count",
                        default=8)
    PARSER.add_argument("--mgmt_bandwidth", help="Management node bandwidth",
                        default=16000)
    PARSER.add_argument("--strg_desc_memory",
                        help="Tie breaker node memory", default=32)
    PARSER.add_argument("--strg_desc_vcpus_count", help="Tie breaker node vcpus count",
                        default=8)
    PARSER.add_argument("--strg_desc_bandwidth", help="Tie breaker node bandwidth",
                        default=16000)
    PARSER.add_argument("--strg_memory", help="Storage NDS node memory",
                        default=32)
    PARSER.add_argument("--strg_vcpus_count", help="Storage NDS node vcpuscount",
                        default=8)
    PARSER.add_argument("--strg_bandwidth", help="Storage NDS node bandwidth",
                        default=16000)
    PARSER.add_argument("--proto_memory", help="Protocol node memory",
                        default=32)
    PARSER.add_argument("--proto_vcpus_count", help="Protocol node vcpus count",
                        default=8)
    PARSER.add_argument("--proto_bandwidth", help="Protocol node bandwidth",
                        default=16000)
    PARSER.add_argument("--strg_proto_memory", help="Storage protocol node memory",
                        default=32)
    PARSER.add_argument("--strg_proto_vcpus_count", help="Storage protocol node vcpus count",
                        default=8)
    PARSER.add_argument("--strg_proto_bandwidth", help="Storage protocol node bandwidth",
                        default=16000)
    PARSER.add_argument('--enable_afm', help='enable AFM',
                        default="null")
    PARSER.add_argument("--afm_memory", help="AFM node memory",
                        default=32)
    PARSER.add_argument("--afm_vcpus_count", help="AFM node vcpus count",
                        default=8)
    PARSER.add_argument("--afm_bandwidth", help="AFM node bandwidth",
                        default=16000)
    PARSER.add_argument('--enable_key_protect', help='enable key protect',
                        default="null")
    ARGUMENTS = PARSER.parse_args()

    cluster_type, gui_username, gui_password = None, None, None
    profile_path, replica_config, scale_config = None, None, {}
    # Step-1: Read the inventory file
    TF = CommonUtils.read_json_file(ARGUMENTS.tf_inv_path)
    if ARGUMENTS.verbose:
        print("Parsed terraform output: %s" % json.dumps(TF, indent=4))
    
    # Step-2: Identify the cluster type
    if len(TF['storage_cluster_instance_private_ips']) == 0 and \
            len(TF['compute_cluster_instance_private_ips']) > 0:
        cluster_type, scale_config, gui_username, gui_password, profile_path, replica_config = ScaleClusters.compute_cluster(ARGUMENTS)
    
    elif len(TF['compute_cluster_instance_private_ips']) == 0 and \
            len(TF['storage_cluster_instance_private_ips']) > 0 and \
            len(TF['vpc_availability_zones']) == 1:
        cluster_type, scale_config, gui_username, gui_password, profile_path, replica_config = ScaleClusters.single_az_storage_cluster(ARGUMENTS, TF)

    elif len(TF['compute_cluster_instance_private_ips']) == 0 and \
            len(TF['storage_cluster_instance_private_ips']) > 0 and \
            len(TF['vpc_availability_zones']) > 1 and \
            len(TF['storage_cluster_desc_instance_private_ips']) > 0:
        cluster_type, scale_config, gui_username, gui_password, profile_path, replica_config = ScaleClusters.multiple_az_storage_cluster(ARGUMENTS, TF)
    else:
        cluster_type, scale_config, gui_username, gui_password, profile_path, replica_config = ScaleClusters.combined_cluster(ARGUMENTS, TF)

    # Step-3: Identify if tie breaker needs to be counted for storage
    quorum_count = ScaleClusters.tie_breaker_count_storage(ARGUMENTS, TF)

    # Step-4: Create playbook
    Playbooks.normal_playbook(ARGUMENTS, cluster_type)

    # Step-4.1: Create Encryption playbook
    Playbooks.encryption_playbook(ARGUMENTS)

    # Step-5: Create hosts
    Hosts.create_hosts(ARGUMENTS, TF, cluster_type, quorum_count, gui_username, gui_password, profile_path, replica_config)

    # Step-6: Create group_vars directory
    GroupVars.group_vars_directory(ARGUMENTS)

    # Step-7: Create group_vars
    GroupVars.create_group_vars(ARGUMENTS, TF, cluster_type, scale_config)
