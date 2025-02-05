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
sed -i -e "s/^/no-port-forwarding,no-agent-forwarding,no-X11-forwarding,command=\"echo \'Please client as the user \\\\\"$USER\\\\\" rather than the user \\\\\"root\\\\\".\';echo;sleep 5; exit 142\" /" /root/.ssh/authorized_keys

# input parameters
echo "${bastion_public_key_content}" >> ~/.ssh/authorized_keys
echo "${management_public_key_content}" | base64 --decode >> ~/.ssh/authorized_keys
echo "StrictHostKeyChecking no" >> ~/.ssh/config
echo "${management_private_key_content}" | base64 --decode > ~/.ssh/id_rsa
chmod 600 ~/.ssh/id_rsa

# network setup
echo "DOMAIN=${management_dns_domain}" >> "/etc/sysconfig/network-scripts/ifcfg-${management_interfaces}"
echo "MTU=9000" >> "/etc/sysconfig/network-scripts/ifcfg-${management_interfaces}"
chage -I -1 -m 0 -M 99999 -E -1 -W 14 vpcuser
sleep 120
systemctl restart NetworkManager
