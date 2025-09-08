#!/bin/bash

###################################################
# Copyright (C) IBM Corp. 2023 All Rights Reserved.
# Licensed under the Apache License v2.0
###################################################

# Setup logging
exec > >(tee /var/log/ibm_spectrumscale_user-data.log)
exec 2>&1
set -e

# Configure SSH
mkdir -p ~/.ssh
chmod 700 ~/.ssh
echo "${storage_public_key_content}" >> ~/.ssh/authorized_keys
echo "${bastion_public_key_content}" >> ~/.ssh/authorized_keys
echo "StrictHostKeyChecking no" >> ~/.ssh/config
echo "${storage_private_key_content}" > ~/.ssh/id_rsa
chmod 600 ~/.ssh/id_rsa ~/.ssh/authorized_keys
ethtool -L eth0 combined 16

# Banner configuration
echo "###########################################################################################" >> /etc/motd
echo "# You have logged in to AFM BareMetal Server.                                         #" >> /etc/motd
echo "#                                                                                         #" >> /etc/motd
echo "# Refer: https://cloud.ibm.com/docs/vpc?topic=vpc-bare-metal-servers-storage              #" >> /etc/motd
echo "###########################################################################################" >> /etc/motd

# Create completion marker
touch /var/user_data_complete
echo "User data script completed successfully at $(date)"
