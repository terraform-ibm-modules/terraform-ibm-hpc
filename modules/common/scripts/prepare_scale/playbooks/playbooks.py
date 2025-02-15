from common.common_utils import CommonUtils


class Playbooks(CommonUtils):

    @staticmethod
    def normal_playbook(ARGUMENTS, cluster_type):
        # Step-4: Create playbook
        if ARGUMENTS.using_packer_image == "false" and ARGUMENTS.using_rest_initialization == "true":
            playbook_content = CommonUtils.prepare_ansible_playbook(
                "scale_nodes", "%s_cluster_config.yaml" % cluster_type,
                ARGUMENTS.instance_private_key)
            CommonUtils.write_to_file("/%s/%s/%s_cloud_playbook.yaml" % (ARGUMENTS.install_infra_path,
                                                            "ibm-spectrum-scale-install-infra",
                                                            cluster_type), playbook_content)
        elif ARGUMENTS.using_packer_image == "true" and ARGUMENTS.using_rest_initialization == "true":
            playbook_content = CommonUtils.prepare_packer_ansible_playbook(
                "scale_nodes", "%s_cluster_config.yaml" % cluster_type)
            CommonUtils.write_to_file("/%s/%s/%s_cloud_playbook.yaml" % (ARGUMENTS.install_infra_path,
                                                            "ibm-spectrum-scale-install-infra",
                                                            cluster_type), playbook_content)
        elif ARGUMENTS.using_packer_image == "false" and ARGUMENTS.using_rest_initialization == "false":
            playbook_content = CommonUtils.prepare_nogui_ansible_playbook(
                "scale_nodes", "%s_cluster_config.yaml" % cluster_type)
            CommonUtils.write_to_file("/%s/%s/%s_cloud_playbook.yaml" % (ARGUMENTS.install_infra_path,
                                                            "ibm-spectrum-scale-install-infra",
                                                            cluster_type), playbook_content)
        elif ARGUMENTS.using_packer_image == "true" and ARGUMENTS.using_rest_initialization == "false":
            playbook_content = CommonUtils.prepare_nogui_packer_ansible_playbook(
                "scale_nodes", "%s_cluster_config.yaml" % cluster_type)
            CommonUtils.write_to_file("/%s/%s/%s_cloud_playbook.yaml" % (ARGUMENTS.install_infra_path,
                                                            "ibm-spectrum-scale-install-infra",
                                                            cluster_type), playbook_content)
        if ARGUMENTS.verbose:
            print("Content of ansible playbook:\n", playbook_content)
        
    @staticmethod
    def encryption_playbook(ARGUMENTS):
        # Step-4.1: Create Encryption playbook
        if ARGUMENTS.scale_encryption_enabled == "true" and ARGUMENTS.scale_encryption_type == "gklm":
            encryption_playbook_content = CommonUtils.prepare_ansible_playbook_encryption_gklm()
            CommonUtils.write_to_file("%s/%s/encryption_gklm_playbook.yaml" % (ARGUMENTS.install_infra_path,
                                                                "ibm-spectrum-scale-install-infra"), encryption_playbook_content)
            encryption_playbook_content = CommonUtils.prepare_ansible_playbook_encryption_cluster(
                "scale_nodes")
            CommonUtils.write_to_file("%s/%s/encryption_cluster_playbook.yaml" % (ARGUMENTS.install_infra_path,
                                                                    "ibm-spectrum-scale-install-infra"), encryption_playbook_content)
        if ARGUMENTS.verbose:
            print("Content of ansible playbook for encryption:\n",
                encryption_playbook_content)
        