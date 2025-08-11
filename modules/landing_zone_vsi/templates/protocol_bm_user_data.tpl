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

# Banner configuration
echo "###########################################################################################" >> /etc/motd
echo "# You have logged in to Protocol BareMetal Server.                                         #" >> /etc/motd
echo "#                                                                                         #" >> /etc/motd
echo "# Refer: https://cloud.ibm.com/docs/vpc?topic=vpc-bare-metal-servers-storage              #" >> /etc/motd
echo "###########################################################################################" >> /etc/motd

# Network configuration
echo "DOMAIN=${storage_dns_domain}" >> "/etc/sysconfig/network-scripts/ifcfg-${storage_interfaces}"
echo "MTU=9000" >> "/etc/sysconfig/network-scripts/ifcfg-${storage_interfaces}"
sed -i "s#QUEUE_COUNT=3#QUEUE_COUNT=\$(ethtool -l \$iface | awk '\$1 ~ /Combined:/ {print \$2;exit}')#g" /var/lib/cloud/scripts/per-boot/iface-config
ethtool -L eth0 combined 16
chage -I -1 -m 0 -M 99999 -E -1 -W 14 vpcuser

# Configure hostname
hostnamectl set-hostname "$(hostname).${storage_dns_domain}"

# Protocol-specific configuration
sec_interface=$(nmcli -t con show --active | grep eth1 | cut -d ':' -f 1)
nmcli conn del "$sec_interface"
nmcli con add type ethernet con-name eth1 ifname eth1
echo "DOMAIN=${protocol_dns_domain}" >> "/etc/sysconfig/network-scripts/ifcfg-${protocol_interfaces}"
echo "MTU=9000" >> "/etc/sysconfig/network-scripts/ifcfg-${protocol_interfaces}"

# === Check for Pensando NIC (vendor 1dd8) and reboot if missing ===
NIC_WAIT_RETRIES=5
NIC_WAIT_DELAY=10
NIC_VENDOR_ID="1dd8"

for i in $(seq 1 $NIC_WAIT_RETRIES); do
    if lspci -nn | grep -q "$NIC_VENDOR_ID"; then
        echo "Pensando NIC detected (attempt $i)."
        break
    else
        echo "Pensando NIC not detected (attempt $i/$NIC_WAIT_RETRIES)..."
        sleep $NIC_WAIT_DELAY
    fi
done

if ! lspci -nn | grep -q "$NIC_VENDOR_ID"; then
    echo "Pensando NIC still not detected after $NIC_WAIT_RETRIES attempts. Rebooting..."
    sleep 10
    reboot
fi
# === End NIC check ===

# Determine OS and install packages
if grep -q "Red Hat" /etc/os-release; then
    USER=vpcuser
    PACKAGE_MGR=dnf

    if grep -q "platform:el9" /etc/os-release; then
        subscription-manager repos --enable=rhel-9-for-x86_64-supplementary-eus-rpms || \
            echo "WARNING: Failed to enable supplementary repo"
        package_list="python3 kernel-devel-$(uname -r) kernel-headers-$(uname -r) firewalld numactl make gcc-c++ elfutils-libelf-devel bind-utils iptables-nft nfs-utils elfutils elfutils-devel python3-dnf-plugin-versionlock"
    elif grep -q "platform:el8" /etc/os-release; then
        package_list="python38 kernel-devel-$(uname -r) kernel-headers-$(uname -r) firewalld numactl jq make gcc-c++ elfutils-libelf-devel bind-utils iptables nfs-utils elfutils elfutils-devel python3-dnf-plugin-versionlock"
    fi

    RETRY_LIMIT=2
    retry_count=0
    while [ $retry_count -lt $RETRY_LIMIT ]; do
        echo "INFO: Attempt $(($retry_count + 1)) to install packages..."
        $PACKAGE_MGR install -y $package_list && break

        echo "WARN: Some packages failed. Retrying after 60 seconds..."
        touch /var/log/scale-rerun-package-install
        $PACKAGE_MGR clean all
        $PACKAGE_MGR makecache
        sleep 10
        retry_count=$((retry_count + 1))
    done

    echo "INFO: Verifying package installation..."
    for pkg in $package_list; do
        if ! $PACKAGE_MGR list installed $pkg >/dev/null 2>&1; then
            echo "WARNING: Package $pkg is missing after retries."
        fi
    done

    yum update --security -y || echo "WARNING: yum update failed"
    yum versionlock add $package_list || echo "WARNING: versionlock add failed"
    yum versionlock list || echo "WARNING: versionlock list failed"
    echo 'export PATH=$PATH:/usr/lpp/mmfs/bin' >> /root/.bashrc

elif grep -q "Ubuntu" /etc/os-release; then
    USER=ubuntu
fi

# Firewall configuration
systemctl stop firewalld
firewall-offline-cmd --zone=public --add-port=1191/tcp
firewall-offline-cmd --zone=public --add-port=4444/tcp
firewall-offline-cmd --zone=public --add-port=4444/udp
firewall-offline-cmd --zone=public --add-port=4739/udp
firewall-offline-cmd --zone=public --add-port=4739/tcp
firewall-offline-cmd --zone=public --add-port=9084/tcp
firewall-offline-cmd --zone=public --add-port=9085/tcp
firewall-offline-cmd --zone=public --add-service=http
firewall-offline-cmd --zone=public --add-service=https
firewall-offline-cmd --zone=public --add-port=2049/tcp
firewall-offline-cmd --zone=public --add-port=2049/udp
firewall-offline-cmd --zone=public --add-port=111/tcp
firewall-offline-cmd --zone=public --add-port=111/udp
firewall-offline-cmd --zone=public --add-port=30000-61000/tcp
firewall-offline-cmd --zone=public --add-port=30000-61000/udp
systemctl start firewalld
systemctl enable firewalld

# Restart services
systemctl restart NetworkManager
systemctl restart sshd

# Protocol environment variables
echo "export IC_REGION=${vpc_region}" >> /root/.bashrc
echo "export IC_SUBNET=${protocol_subnets}" >> /root/.bashrc
echo "export IC_RG=${resource_group_id}" >> /root/.bashrc

for service in sshd NetworkManager firewalld; do
    while ! systemctl is-active --quiet $service; do
        echo "Waiting for $service to start..."
        systemctl restart $service
        sleep 5
    done
done

# Create completion marker
touch /var/user_data_complete
echo "User data script completed successfully at $(date)"
