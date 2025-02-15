import yaml
from common.common_utils import CommonUtils

class GroupVars(CommonUtils):

    @staticmethod
    def group_vars_directory(ARGUMENTS):
        # Step-6: Create group_vars directory
        CommonUtils.create_directory("%s/%s/%s" % (ARGUMENTS.install_infra_path,
                                    "ibm-spectrum-scale-install-infra",
                                    "group_vars"))
    @staticmethod 
    def create_group_vars(ARGUMENTS, TF, cluster_type, scale_config):
        # Step-7: Create group_vars
        with open("%s/%s/%s/%s" % (ARGUMENTS.install_infra_path,
                                "ibm-spectrum-scale-install-infra",
                                "group_vars",
                                "%s_cluster_config.yaml" % cluster_type), 'w') as groupvar:
            yaml.dump(scale_config, groupvar, default_flow_style=False)
        if ARGUMENTS.verbose:
            print("group_vars content:\n%s" % yaml.dump(
                scale_config, default_flow_style=False))

        if cluster_type in ['storage', 'combined']:
            disks_list = CommonUtils.get_disks_list(len(TF['vpc_availability_zones']),
                                        TF['storage_cluster_with_data_volume_mapping'],
                                        TF['storage_cluster_desc_data_volume_mapping'],
                                        ARGUMENTS.disk_type)
            scale_storage = CommonUtils.initialize_scale_storage_details(len(TF['vpc_availability_zones']),
                                                            TF['storage_cluster_filesystem_mountpoint'],
                                                            TF['filesystem_block_size'],
                                                            disks_list, int(ARGUMENTS.default_metadata_replicas), int(
                                                                ARGUMENTS.max_metadata_replicas),
                                                            int(ARGUMENTS.default_data_replicas), int(ARGUMENTS.max_data_replicas), TF['filesets'])
            scale_protocols = CommonUtils.initialize_scale_ces_details(TF['smb'],
                                                        TF['nfs'],
                                                        TF['object'],
                                                        TF['export_ip_pool'],
                                                        TF['filesystem'],
                                                        TF['mountpoint'],
                                                        TF['filesets'],
                                                        TF['protocol_cluster_instance_names'],
                                                        ARGUMENTS.enable_ces)
            scale_storage_cluster = {
                'scale_protocols': scale_protocols['scale_protocols'],
                'scale_storage': scale_storage['scale_storage']
            }
            with open("%s/%s/%s/%s" % (ARGUMENTS.install_infra_path,
                                    "ibm-spectrum-scale-install-infra",
                                    "group_vars",
                                    "%s_cluster_config.yaml" % cluster_type), 'a') as groupvar:
                yaml.dump(scale_storage_cluster, groupvar,
                        default_flow_style=False)
            if ARGUMENTS.verbose:
                print("group_vars content:\n%s" % yaml.dump(
                    scale_storage_cluster, default_flow_style=False))