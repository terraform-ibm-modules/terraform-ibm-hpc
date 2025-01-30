#!/usr/bin/bash

###################################################
# Copyright (C) IBM Corp. 2023 All Rights Reserved.
# Licensed under the Apache License v2.0
###################################################

#!/usr/bin/env bash
if grep -E -q "CentOS|Red Hat" /etc/os-release
then
    USER=vpcuser
elif grep -q "Ubuntu" /etc/os-release
then
    USER=ubuntu
fi
sed -i -e "s/^/no-port-forwarding,no-agent-forwarding,no-X11-forwarding,command=\"echo \'Please login as the user \\\\\"$USER\\\\\" rather than the user \\\\\"root\\\\\".\';echo;sleep 5; exit 142\" /" /root/.ssh/authorized_keys
chage -I -1 -m 0 -M 99999 -E -1 -W 14 vpcuser
systemctl restart NetworkManager

# input parameters
echo "${bastion_public_key_content}" >> /home/$USER/.ssh/authorized_keys
echo "StrictHostKeyChecking no" >> /home/$USER/.ssh/config

# setup env
# TODO: Conditional installation (python3, terraform & ansible)
if grep -E -q "CentOS|Red Hat" /etc/os-release
then
    # TODO: Terraform Repo access
    #yum install -y yum-utils
    #yum-config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo
    #if (which terraform); then echo "Terraform exists, skipping the installation"; else (yum install -y terraform
    if (which python3); then echo "Python3 exists, skipping the installation"; else (yum install -y python38); fi
    if (which ansible-playbook); then echo "Ansible exists, skipping the installation"; else (yum install -y ansible); fi
elif grep -q "Ubuntu" /etc/os-release
then
    apt update
    # TODO: Terraform Repo access
    #apt-get update && sudo apt-get install -y gnupg software-properties-common
    #wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | tee /usr/share/keyrings/hashicorp-archive-keyring.gpg
    #gpg --no-default-keyring --keyring /usr/share/keyrings/hashicorp-archive-keyring.gpg --fingerprint
    apt install software-properties-common
    apt-add-repository --yes --update ppa:ansible/ansible
    if (which python3); then echo "Python3 exists, skipping the installation"; else (apt install python38); fi
    if (which ansible-playbook); then echo "Ansible exists, skipping the installation"; else (apt install ansible); fi
fi

dnf install -y git unzip wget python3-dnf-plugin-versionlock bind-utils
# dnf update --security -y
# dnf versionlock list
# dnf versionlock add git unzip wget python3-dnf-plugin-versionlock bind-utils
# dnf versionlock list
wget https://releases.hashicorp.com/terraform/1.5.7/terraform_1.5.7_linux_amd64.zip
unzip terraform_1.5.7_linux_amd64.zip
rm -rf terraform_1.5.7_linux_amd64.zip
mv terraform /usr/bin

# TODO: run terraform
if [ ${enable_bastion} = true ]; then
    if [ ! -d ${remote_ansible_path} ]; then 
        sudo git clone -b ${da_hpc_repo_tag} ${da_hpc_repo_url} ${remote_ansible_path} 
    fi
    sudo -E terraform -chdir=${remote_ansible_path} init && sudo -E terraform -chdir=${remote_ansible_path} apply -auto-approve \
        -var 'ibmcloud_api_key=${ibmcloud_api_key}' \
        -var 'resource_group=${resource_group}' \
        -var 'prefix=${prefix}' \
        -var 'zones=${zones}' \
        -var 'enable_landing_zone=false' \
        -var 'enable_deployer=false' \
        -var 'enable_bastion=false' \
        -var 'bastion_fip=${bastion_fip}' \
        -var 'compute_ssh_keys=${compute_ssh_keys}' \
        -var 'storage_ssh_keys=${storage_ssh_keys}' \
        -var 'storage_instances=${storage_instances}' \
        -var 'management_instances=${management_instances}' \
        -var 'protocol_instances=${protocol_instances}' \
        -var 'ibm_customer_number=${ibm_customer_number}' \
        -var 'static_compute_instances=${compute_instances}' \
        -var 'client_instances=${client_instances}' \
        -var 'enable_cos_integration=${enable_cos_integration}' \
        -var 'enable_atracker=${enable_atracker}' \
        -var 'enable_vpc_flow_logs=${enable_vpc_flow_logs}' \
        -var 'allowed_cidr=${allowed_cidr}' \
        -var 'vpc_id=${vpc_id}' \
        -var 'vpc=${vpc}' \
        -var 'storage_subnets=${storage_subnets}' \
        -var 'protocol_subnets=${protocol_subnets}' \
        -var 'compute_subnets=${compute_subnets}' \
        -var 'client_subnets=${client_subnets}' \
        -var 'bastion_subnets=${bastion_subnets}'
fi