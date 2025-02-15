import pathlib
from common.common_utils import CommonUtils

class ScaleClusters(CommonUtils):

    @staticmethod
    def compute_cluster(ARGUMENTS):
        cluster_type = "compute"
        CommonUtils.cleanup("%s/%s/%s_inventory.ini" % (ARGUMENTS.install_infra_path,
                                            "ibm-spectrum-scale-install-infra",
                                            cluster_type))
        CommonUtils.cleanup("%s/%s_cluster_gui_details.json" % (str(pathlib.PurePath(ARGUMENTS.tf_inv_path).parent),
                                                    cluster_type))
        CommonUtils.cleanup("/%s/%s/%s_cloud_playbook.yaml" % (ARGUMENTS.install_infra_path,
                                                   "ibm-spectrum-scale-install-infra",
                                                   cluster_type))
        CommonUtils.cleanup("%s/%s/%s/%s" % (ARGUMENTS.install_infra_path,
                                 "ibm-spectrum-scale-install-infra",
                                 "group_vars", "%s_cluster_config.yaml" % cluster_type))
        gui_username = ARGUMENTS.gui_username
        gui_password = ARGUMENTS.gui_password
        profile_path = "%s/computesncparams" % ARGUMENTS.install_infra_path
        replica_config = False
        computenodegrp = CommonUtils.generate_nodeclass_config(
            "computenodegrp", ARGUMENTS.comp_memory, ARGUMENTS.comp_vcpus_count, ARGUMENTS.comp_bandwidth)
        managementnodegrp = CommonUtils.generate_nodeclass_config(
            "managementnodegrp", ARGUMENTS.mgmt_memory, ARGUMENTS.mgmt_vcpus_count, ARGUMENTS.strg_bandwidth)
        scale_config = CommonUtils.initialize_scale_config_details(
            [computenodegrp, managementnodegrp])
        
        return cluster_type, scale_config, gui_username, gui_password, profile_path, replica_config
        
        
    @staticmethod
    def single_az_storage_cluster(ARGUMENTS, TF):
        # single az storage cluster
        cluster_type = "storage"
        CommonUtils.cleanup("%s/%s/%s_inventory.ini" % (ARGUMENTS.install_infra_path,
                                            "ibm-spectrum-scale-install-infra",
                                            cluster_type))
        CommonUtils.cleanup("%s/%s_cluster_gui_details.json" % (str(pathlib.PurePath(ARGUMENTS.tf_inv_path).parent),
                                                    cluster_type))
        CommonUtils.cleanup("/%s/%s/%s_cloud_playbook.yaml" % (ARGUMENTS.install_infra_path,
                                                   "ibm-spectrum-scale-install-infra",
                                                   cluster_type))
        CommonUtils.cleanup("%s/%s/%s/%s" % (ARGUMENTS.install_infra_path,
                                 "ibm-spectrum-scale-install-infra",
                                 "group_vars", "%s_cluster_config.yaml" % cluster_type))
        gui_username = ARGUMENTS.gui_username
        gui_password = ARGUMENTS.gui_password
        profile_path = "%s/storagesncparams" % ARGUMENTS.install_infra_path
        replica_config = bool(len(TF['vpc_availability_zones']) > 1)

        managementnodegrp = CommonUtils.generate_nodeclass_config(
            "managementnodegrp", ARGUMENTS.mgmt_memory, ARGUMENTS.mgmt_vcpus_count, ARGUMENTS.strg_bandwidth)
        storagedescnodegrp = CommonUtils.generate_nodeclass_config(
            "storagedescnodegrp", ARGUMENTS.strg_desc_memory, ARGUMENTS.strg_desc_vcpus_count, ARGUMENTS.strg_bandwidth)
        storagenodegrp = CommonUtils.generate_nodeclass_config(
            "storagenodegrp", ARGUMENTS.strg_memory, ARGUMENTS.strg_vcpus_count, ARGUMENTS.strg_bandwidth)
        protocolnodegrp = CommonUtils.generate_nodeclass_config(
            "protocolnodegrp", ARGUMENTS.proto_memory, ARGUMENTS.proto_vcpus_count, ARGUMENTS.strg_bandwidth)
        storageprotocolnodegrp = CommonUtils.generate_nodeclass_config(
            "storageprotocolnodegrp", ARGUMENTS.strg_proto_memory, ARGUMENTS.strg_proto_vcpus_count, ARGUMENTS.strg_proto_bandwidth)
        afmgatewaygrp = CommonUtils.generate_nodeclass_config(
            "afmgatewaygrp", ARGUMENTS.afm_memory, ARGUMENTS.afm_vcpus_count, ARGUMENTS.afm_bandwidth)
        afmgatewaygrp[1].update(CommonUtils.check_afm_values())
        
        nodeclassgrp = [storagedescnodegrp, managementnodegrp]
        if ARGUMENTS.enable_ces == "True":
            if ARGUMENTS.colocate_protocol_cluster_instances == "True":
                if ARGUMENTS.is_colocate_protocol_subset == "True":
                    nodeclassgrp.append(storagenodegrp)
                nodeclassgrp.append(storageprotocolnodegrp)
            else:
                nodeclassgrp.append(storagenodegrp)
                nodeclassgrp.append(protocolnodegrp)
        else:
            nodeclassgrp.append(storagenodegrp)
        if ARGUMENTS.enable_afm == "True":
            nodeclassgrp.append(afmgatewaygrp)
        scale_config = CommonUtils.initialize_scale_config_details(nodeclassgrp)

        return cluster_type, scale_config, gui_username, gui_password, profile_path, replica_config

    @staticmethod
    def multiple_az_storage_cluster(ARGUMENTS, TF):
        # multi az storage cluster
        cluster_type = "storage"
        CommonUtils.cleanup("%s/%s/%s_inventory.ini" % (ARGUMENTS.install_infra_path,
                                            "ibm-spectrum-scale-install-infra",
                                            cluster_type))
        CommonUtils.cleanup("%s/%s_cluster_gui_details.json" % (str(pathlib.PurePath(ARGUMENTS.tf_inv_path).parent),
                                                    cluster_type))
        CommonUtils.cleanup("/%s/%s/%s_cloud_playbook.yaml" % (ARGUMENTS.install_infra_path,
                                                   "ibm-spectrum-scale-install-infra",
                                                   cluster_type))
        CommonUtils.cleanup("%s/%s/%s/%s" % (ARGUMENTS.install_infra_path,
                                 "ibm-spectrum-scale-install-infra",
                                 "group_vars", "%s_cluster_config.yaml" % cluster_type))
        gui_username = ARGUMENTS.gui_username
        gui_password = ARGUMENTS.gui_password
        profile_path = "%s/storagesncparams" % ARGUMENTS.install_infra_path
        replica_config = bool(len(TF['vpc_availability_zones']) > 1)

        managementnodegrp = CommonUtils.generate_nodeclass_config(
            "managementnodegrp", ARGUMENTS.mgmt_memory, ARGUMENTS.mgmt_vcpus_count, ARGUMENTS.strg_bandwidth)
        storagedescnodegrp = CommonUtils.generate_nodeclass_config(
            "storagedescnodegrp", ARGUMENTS.strg_desc_memory, ARGUMENTS.strg_desc_vcpus_count, ARGUMENTS.strg_bandwidth)
        storagenodegrp = CommonUtils.generate_nodeclass_config(
            "storagenodegrp", ARGUMENTS.strg_memory, ARGUMENTS.strg_vcpus_count, ARGUMENTS.strg_bandwidth)
        protocolnodegrp = CommonUtils.generate_nodeclass_config(
            "protocolnodegrp", ARGUMENTS.proto_memory, ARGUMENTS.proto_vcpus_count, ARGUMENTS.strg_bandwidth)
        storageprotocolnodegrp = CommonUtils.generate_nodeclass_config(
            "storageprotocolnodegrp", ARGUMENTS.strg_proto_memory, ARGUMENTS.strg_proto_vcpus_count, ARGUMENTS.strg_proto_bandwidth)
        afmgatewaygrp =CommonUtils.generate_nodeclass_config(
            "afmgatewaygrp", ARGUMENTS.afm_memory, ARGUMENTS.afm_vcpus_count, ARGUMENTS.afm_bandwidth)
        afmgatewaygrp[1].update(CommonUtils.check_afm_values())

        nodeclassgrp = [storagedescnodegrp, managementnodegrp]
        if ARGUMENTS.enable_ces == "True":
            if ARGUMENTS.colocate_protocol_cluster_instances == "True":
                if ARGUMENTS.is_colocate_protocol_subset == "True":
                    nodeclassgrp.append(storagenodegrp)
                nodeclassgrp.append(storageprotocolnodegrp)
            else:
                nodeclassgrp.append(storagenodegrp)
                nodeclassgrp.append(protocolnodegrp)
        else:
            nodeclassgrp.append(storagenodegrp)
        if ARGUMENTS.enable_afm == "True":
            nodeclassgrp.append(afmgatewaygrp)
        scale_config = CommonUtils.initialize_scale_config_details(nodeclassgrp)

        return cluster_type, scale_config, gui_username, gui_password, profile_path, replica_config

    @staticmethod
    def combined_cluster(ARGUMENTS, TF):
        cluster_type = "combined"
        CommonUtils.cleanup("%s/%s/%s_inventory.ini" % (ARGUMENTS.install_infra_path,
                                            "ibm-spectrum-scale-install-infra",
                                            cluster_type))
        CommonUtils.cleanup("/%s/%s/%s_cloud_playbook.yaml" % (ARGUMENTS.install_infra_path,
                                                   "ibm-spectrum-scale-install-infra",
                                                   cluster_type))
        CommonUtils.cleanup("%s/%s/%s/%s" % (ARGUMENTS.install_infra_path,
                                 "ibm-spectrum-scale-install-infra",
                                 "group_vars", "%s_cluster_config.yaml" % cluster_type))
        gui_username = ARGUMENTS.gui_username
        gui_password = ARGUMENTS.gui_password
        profile_path = "%s/scalesncparams" % ARGUMENTS.install_infra_path
        replica_config = bool(len(TF['vpc_availability_zones']) > 1)

        computenodegrp = CommonUtils.generate_nodeclass_config(
            "computenodegrp", ARGUMENTS.comp_memory, ARGUMENTS.comp_vcpus_count, ARGUMENTS.comp_bandwidth)
        managementnodegrp = CommonUtils.generate_nodeclass_config(
            "managementnodegrp", ARGUMENTS.mgmt_memory, ARGUMENTS.mgmt_vcpus_count, ARGUMENTS.strg_bandwidth)
        storagedescnodegrp = CommonUtils.generate_nodeclass_config(
            "storagedescnodegrp", ARGUMENTS.strg_desc_memory, ARGUMENTS.strg_desc_vcpus_count, ARGUMENTS.strg_bandwidth)
        storagenodegrp = CommonUtils.generate_nodeclass_config(
            "storagenodegrp", ARGUMENTS.strg_memory, ARGUMENTS.strg_vcpus_count, ARGUMENTS.strg_bandwidth)
        protocolnodegrp = CommonUtils.generate_nodeclass_config(
            "protocolnodegrp", ARGUMENTS.proto_memory, ARGUMENTS.proto_vcpus_count, ARGUMENTS.strg_bandwidth)
        storageprotocolnodegrp = CommonUtils.generate_nodeclass_config(
            "storageprotocolnodegrp", ARGUMENTS.strg_proto_memory, ARGUMENTS.strg_proto_vcpus_count, ARGUMENTS.strg_proto_bandwidth)
        afmgatewaygrp =CommonUtils.generate_nodeclass_config(
            "afmgatewaygrp", ARGUMENTS.afm_memory, ARGUMENTS.afm_vcpus_count, ARGUMENTS.afm_bandwidth)
        afmgatewaygrp[1].update(CommonUtils.check_afm_values())

        if len(TF['vpc_availability_zones']) == 1:
            nodeclassgrp = [storagedescnodegrp, managementnodegrp, computenodegrp]
            if ARGUMENTS.enable_ces == "True":
                if ARGUMENTS.colocate_protocol_cluster_instances == "True":
                    if ARGUMENTS.is_colocate_protocol_subset == "True":
                        nodeclassgrp.append(storagenodegrp)
                    nodeclassgrp.append(storageprotocolnodegrp)
                else:
                    nodeclassgrp.append(storagenodegrp)
                    nodeclassgrp.append(protocolnodegrp)
            else:
                nodeclassgrp.append(storagenodegrp)
            if ARGUMENTS.enable_afm == "True":
                nodeclassgrp.append(afmgatewaygrp)
            scale_config = CommonUtils.initialize_scale_config_details(nodeclassgrp)
        else:
            nodeclassgrp = [storagedescnodegrp, managementnodegrp, computenodegrp]
            if ARGUMENTS.enable_ces == "True":
                if ARGUMENTS.colocate_protocol_cluster_instances == "True":
                    if ARGUMENTS.is_colocate_protocol_subset == "True":
                        nodeclassgrp.append(storagenodegrp)
                    nodeclassgrp.append(storageprotocolnodegrp)
                else:
                    nodeclassgrp.append(storagenodegrp)
                    nodeclassgrp.append(protocolnodegrp)
            else:
                nodeclassgrp.append(storagenodegrp)
            if ARGUMENTS.enable_afm == "True":
                nodeclassgrp.append(afmgatewaygrp)
            scale_config = CommonUtils.initialize_scale_config_details(nodeclassgrp)

        return cluster_type, scale_config, gui_username, gui_password, profile_path, replica_config

    @staticmethod
    def tie_breaker_count_storage(ARGUMENTS, TF):
        # Step-3: Identify if tie breaker needs to be counted for storage
        if len(TF['vpc_availability_zones']) > 1:
            total_node_count = len(TF['compute_cluster_instance_private_ips']) + \
                len(TF['storage_cluster_desc_instance_private_ips']) + \
                len(TF['storage_cluster_instance_private_ips'])
        else:
            total_node_count = len(TF['compute_cluster_instance_private_ips']) + \
                len(TF['storage_cluster_instance_private_ips'])

        if ARGUMENTS.verbose:
            print("Total node count: ", total_node_count)

        # Determine total number of quorum, manager nodes to be in the cluster
        # manager designates the node as part of the pool of nodes from which
        # file system managers and token managers are selected.
        quorum_count = 0
        if total_node_count < 4:
            quorum_count = total_node_count
        elif 4 <= total_node_count < 10:
            quorum_count = 3
        elif 10 <= total_node_count < 19:
            quorum_count = 5
        else:
            quorum_count = 7

        if ARGUMENTS.verbose:
            print("Total quorum count: ", quorum_count)
        return quorum_count