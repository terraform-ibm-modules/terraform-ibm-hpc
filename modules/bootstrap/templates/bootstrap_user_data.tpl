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

# TODO: run terraform

sudo yum install -y git
sudo yum install -y wget
sudo wget https://releases.hashicorp.com/terraform/1.5.4/terraform_1.5.4_linux_amd64.zip
sudo yum install -y unzip
sudo unzip terraform_1.5.4_linux_amd64.zip -d /usr/bin
if [ ! -d ${remote_ansible_path} ]; then sudo git clone -b ${da_hpc_repo_tag} ${da_hpc_repo_url} ${remote_ansible_path}; fi

sudo -E terraform -chdir=${remote_ansible_path} init && sudo -E terraform -chdir=${remote_ansible_path} apply -auto-approve \
    -var 'resource_group=${resource_group}' \
    -var 'prefix=${prefix}' \
    -var 'zones=${zones}' \
    -var 'compute_ssh_keys=${compute_ssh_keys}' \
    -var 'login_ssh_keys=${login_ssh_keys}' \
    -var 'storage_ssh_keys=${storage_ssh_keys}' \
    -var 'vpc=${vpc}' \
    -var 'compute_subnets=${compute_subnets}' \
    -var 'login_subnets=${login_subnets}' \
    -var 'storage_subnets=${storage_subnets}' \
    -var 'protocol_subnets=${protocol_subnets}' \
    -var 'bastion_security_group_id=${bastion_security_group_id}' \
    -var 'bastion_public_key_content=${bastion_public_key_content}' \
    -var 'bastion_ssh_keys=[]' \
    -var 'enable_bootstrap=false' \
    -var 'enable_bastion=false' \
    -var 'boot_volume_encryption_key=${boot_volume_encryption_key}' \
    -var 'dns_instance_id=${dns_instance_id}' \
    -var 'dns_custom_resolver_id=${dns_custom_resolver_id}' \
    -var 'enable_landing_zone=false' \
    -var 'ibmcloud_api_key=${ibmcloud_api_key}'