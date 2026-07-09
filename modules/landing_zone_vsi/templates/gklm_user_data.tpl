#!/bin/bash

###################################################
# Copyright (C) IBM Corp. 2023 All Rights Reserved.
# Licensed under the Apache License v2.0
###################################################

#!/usr/bin/env bash
exec > >(tee /var/log/ibm_spectrumscale_user-data.log)
if grep -q "Red Hat" /etc/os-release
then
    USER=vpcuser
elif grep -q "Ubuntu" /etc/os-release
then
    USER=ubuntu
fi
sed -i '/no-port-forwarding,no-agent-forwarding,no-X11-forwarding,command=/d' /home/$USER/.ssh/authorized_keys

# input parameters
# Configure SSH
# Create the .ssh directory for USER with correct permissions
mkdir -p /home/$USER/.ssh
chmod 700 /home/$USER/.ssh

# Append the public keys to the USER's authorized_keys file
echo "${storage_public_key_content}" >> /home/$USER/.ssh/authorized_keys
echo "${storage_public_key_content}" >> /root/.ssh/authorized_keys
echo "${bastion_public_key_content}" >> /home/$USER/.ssh/authorized_keys

# Create the SSH config file to disable host key checking for all hosts
echo "Host *
    StrictHostKeyChecking no" > /home/$USER/.ssh/config
echo "Host *
    StrictHostKeyChecking no" > /root/.ssh/config
chmod 600 /home/$USER/.ssh/config /root/.ssh/config

# Write the private key file for USER
echo "${storage_private_key_content}" > /home/$USER/.ssh/id_rsa
echo "${storage_private_key_content}" > /root/.ssh/id_rsa
chmod 600 /home/$USER/.ssh/id_rsa /home/$USER/.ssh/authorized_keys /root/.ssh/id_rsa /root/.ssh/authorized_keys

# CRITICAL: Change ownership of everything to the USER
chown -R $USER:$USER /home/$USER/.ssh

# Add user to the 'sudo' group
groupadd gpfs
usermod -aG gpfs $USER

# #Permission for the sudoers file
# chmod 0440 /etc/sudoers.d/gpfs_sudo_wrapper

sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
#Restarting the SSH Service
systemctl restart sshd

echo "###########################################################################################" >> /etc/motd
echo "#                 You have logged in to a VSI (Virtual Server Instance).                  #" >> /etc/motd
echo "#                                                                                         #" >> /etc/motd
echo "#   - A VSI Server provides temporary, ephemeral storage available only                   #" >> /etc/motd
echo "#     for the duration of the virtual servers runtime.                                    #" >> /etc/motd
echo "#   - Data on the root volume is unrecoverable after instance shutdown, disruptive        #" >> /etc/motd
echo "#     maintenance, or hardware failure unless detached.                                   #" >> /etc/motd
echo "#                                                                                         #" >> /etc/motd
echo "# Refer: https://cloud.ibm.com/docs/vpc?group=virtual-servers                             #" >> /etc/motd
echo "###########################################################################################" >> /etc/motd

echo "0 $(hostname).${domain_name} 0" > /home/klmdb42/sqllib/db2nodes.cfg
systemctl start db2c_klmdb42.service
sleep 10
systemctl status db2c_klmdb42.service
sleep 10

hostnamectl set-hostname "$(hostname).${domain_name}"
reboot
