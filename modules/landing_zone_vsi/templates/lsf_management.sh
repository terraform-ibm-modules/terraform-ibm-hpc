#!/bin/bash
# shellcheck disable=all
###################################################
# Copyright (C) IBM Corp. 2023 All Rights Reserved.
# Licensed under the Apache License v2.0
###################################################

# Local variable declaration
logfile="/tmp/user_data.log"

# Setup logs for user data
echo "START $(date '+%Y-%m-%d %H:%M:%S')" >> $logfile

echo "umask=$(umask)"  >> $logfile

# Disallow root login
sed -i -e "s/^/no-port-forwarding,no-agent-forwarding,no-X11-forwarding,command=\"echo \'Please login as the user \\\\\"lsfadmin or vpcuser\\\\\" rather than the user \\\\\"root\\\\\".\';echo;sleep 5; exit 142\" /" /root/.ssh/authorized_keys

# Setup Network configuration
# Change the MTU setting as this is required for setting mtu as 9000 for communication to happen between clusters
echo "MTU=9000" >> "/etc/sysconfig/network-scripts/ifcfg-${network_interface}"
echo "DOMAIN=\"$dns_domain\"" >> "/etc/sysconfig/network-scripts/ifcfg-${network_interface}"

# Change the MTU setting as 9000 at router level.
gateway_ip=$(ip route | grep default | awk '{print $3}' | head -n 1)
echo "${rc_cidr_block} via $gateway_ip dev ${network_interface} metric 0 mtu 9000" >> /etc/sysconfig/network-scripts/route-${network_interface}

systemctl restart NetworkManager

echo 1 > /proc/sys/vm/overcommit_memory # tt reports many failures of memory allocation at fork(). why?
{
  echo 'vm.overcommit_memory=1'
  echo 'net.core.rmem_max=26214400'
  echo 'net.core.rmem_default=26214400'
  echo 'net.core.wmem_max=26214400'
  echo 'net.core.wmem_default=26214400'
  echo 'net.ipv4.tcp_fin_timeout = 5'
  echo 'net.core.somaxconn = 8000'
} > /etc/sysctl.conf
sysctl -p /etc/sysctl.conf

if [ ! "$hyperthreading" == true ]; then
  for vcpu in $(cat /sys/devices/system/cpu/cpu*/topology/thread_siblings_list | cut -s -d- -f2 | cut -d- -f2 | uniq); do
    echo 0 > /sys/devices/system/cpu/cpu"$vcpu"/online
  done
fi

# Setup lsfadmin user
# Updates the lsfadmin user as never expire
chage -I -1 -m 0 -M 99999 -E -1 -W 14 lsfadmin
# Setup ssh
lsfadmin_home_dir="/home/lsfadmin"
lsfadmin_ssh_dir="${lsfadmin_home_dir}/.ssh"
mkdir -p ${lsfadmin_ssh_dir}
cp /home/vpcuser/.ssh/authorized_keys "${lsfadmin_ssh_dir}/authorized_keys"
echo "${cluster_public_key_content}" >> "${lsfadmin_ssh_dir}/authorized_keys"
echo "${cluster_private_key_content}" >> "${lsfadmin_ssh_dir}/id_rsa"
echo "StrictHostKeyChecking no" >> "${lsfadmin_ssh_dir}/config"
chmod 600 "${lsfadmin_ssh_dir}/authorized_keys"
chmod 600 "${lsfadmin_ssh_dir}/id_rsa"
chmod 700 ${lsfadmin_ssh_dir}
chown -R lsfadmin:lsfadmin ${lsfadmin_ssh_dir}
echo "SSH key setup for lsfadmin user is completed" >> $logfile

# Setup root user
root_ssh_dir="/root/.ssh"
echo "${cluster_public_key_content}" >> $root_ssh_dir/authorized_keys
echo "StrictHostKeyChecking no" >> $root_ssh_dir/config
echo "cluster ssh key has been added to root user" >> $logfile
