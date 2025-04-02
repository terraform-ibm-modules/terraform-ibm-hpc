#!/usr/bin/bash

###################################################
# Copyright (C) IBM Corp. 2023 All Rights Reserved.
# Licensed under the Apache License v2.0
###################################################

#!/usr/bin/env bash

# input parameters
echo "${bastion_public_key_content}" >> ~/.ssh/authorized_keys
echo "${compute_public_key_content}" >> ~/.ssh/authorized_keys
echo "StrictHostKeyChecking no" >> ~/.ssh/config
echo "${compute_private_key_content}" > ~/.ssh/id_rsa
chmod 600 ~/.ssh/id_rsa

# network setup
echo "DOMAIN=${compute_dns_domain}" >> "/etc/sysconfig/network-scripts/ifcfg-${compute_interfaces}"
echo "MTU=9000" >> "/etc/sysconfig/network-scripts/ifcfg-${compute_interfaces}"
chage -I -1 -m 0 -M 99999 -E -1 -W 14 vpcuser
sleep 10
systemctl restart NetworkManager
