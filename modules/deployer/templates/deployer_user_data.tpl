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
