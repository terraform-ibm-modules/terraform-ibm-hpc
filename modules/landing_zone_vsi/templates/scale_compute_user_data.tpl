#!/usr/bin/bash

###################################################
# Copyright (C) IBM Corp. 2023 All Rights Reserved.
# Licensed under the Apache License v2.0
###################################################

#!/usr/bin/env bash

exec > >(tee /var/log/ibm_spectrumscale_user-data.log)

sed -i -e "s/^/no-port-forwarding,no-agent-forwarding,no-X11-forwarding,command=\"echo \'Please client as the user \\\\\"$USER\\\\\" rather than the user \\\\\"root\\\\\".\';echo;sleep 5; exit 142\" /" /root/.ssh/authorized_keys

# input parameters
echo "${bastion_public_key_content}" >> ~/.ssh/authorized_keys
echo "${compute_public_key_content}" >> ~/.ssh/authorized_keys
echo "StrictHostKeyChecking no" >> ~/.ssh/config
echo "${compute_private_key_content}" > ~/.ssh/id_rsa
chmod 600 ~/.ssh/id_rsa

if grep -q "Red Hat" /etc/os-release
then
    USER=vpcuser
    REQ_PKG_INSTALLED=0
    if grep -q "platform:el9" /etc/os-release
    then
        PACKAGE_MGR=dnf
        package_list="python3 kernel-devel-$(uname -r) kernel-headers-$(uname -r) firewalld numactl make gcc-c++ elfutils-libelf-devel bind-utils iptables-nft nfs-utils elfutils elfutils-devel python3-dnf-plugin-versionlock"
    elif grep -q "platform:el8" /etc/os-release
    then
        PACKAGE_MGR=dnf
        package_list="python38 kernel-devel-$(uname -r) kernel-headers-$(uname -r) firewalld numactl jq make gcc-c++ elfutils-libelf-devel bind-utils iptables nfs-utils elfutils elfutils-devel python3-dnf-plugin-versionlock"
    else
        PACKAGE_MGR=yum
        package_list="python3 kernel-devel-$(uname -r) kernel-headers-$(uname -r) rsync firewalld numactl make gcc-c++ elfutils-libelf-devel bind-utils iptables nfs-utils elfutils elfutils-devel yum-plugin-versionlock"
    fi

    RETRY_LIMIT=5
    retry_count=0
    all_pkg_installed=1

    while [[ $all_pkg_installed -ne 0 && $retry_count -lt $RETRY_LIMIT ]]
    do
        # Install all required packages
        echo "INFO: Attempting to install packages"
        $PACKAGE_MGR install -y $package_list

        # Check to ensure packages are installed
        pkg_installed=0
        for pkg in $package_list
        do
            pkg_query=$($PACKAGE_MGR list installed $pkg)
            pkg_installed=$(($? + $pkg_installed))
        done
        if [[ $pkg_installed -ne 0 ]]
        then
            # The minimum required packages have not been installed.
            echo "WARN: Required packages not installed. Sleeping for 60 seconds and retrying..."
            touch /var/log/scale-rerun-package-install
            echo "INFO: Cleaning and repopulating repository data"
            $PACKAGE_MGR clean all
            $PACKAGE_MGR makecache
            sleep 60
        else
            all_pkg_installed=0
        fi
        retry_count=$(( $retry_count+1 ))
    done

elif grep -q "Ubuntu" /etc/os-release
then
    USER=ubuntu
fi

yum update --security -y
yum versionlock add $package_list
yum versionlock list
echo 'export PATH=$PATH:/usr/lpp/mmfs/bin' >> /root/.bashrc

echo "DOMAIN=${compute_dns_domain}" >> "/etc/sysconfig/network-scripts/ifcfg-${compute_interfaces}"
echo "MTU=9000" >> "/etc/sysconfig/network-scripts/ifcfg-${compute_interfaces}"
chage -I -1 -m 0 -M 99999 -E -1 -W 14 vpcuser
systemctl restart NetworkManager
hostnamectl set-hostname "$(hostname).${compute_dns_domain}"

systemctl stop firewalld
firewall-offline-cmd --zone=public --add-port=1191/tcp
firewall-offline-cmd --zone=public --add-port=60000-61000/tcp
firewall-offline-cmd --zone=public --add-port=47080/tcp
firewall-offline-cmd --zone=public --add-port=47080/udp
firewall-offline-cmd --zone=public --add-port=47443/tcp
firewall-offline-cmd --zone=public --add-port=47443/udp
firewall-offline-cmd --zone=public --add-port=4444/tcp
firewall-offline-cmd --zone=public --add-port=4444/udp
firewall-offline-cmd --zone=public --add-port=4739/udp
firewall-offline-cmd --zone=public --add-port=4739/tcp
firewall-offline-cmd --zone=public --add-port=9084/tcp
firewall-offline-cmd --zone=public --add-port=9085/tcp
firewall-offline-cmd --zone=public --add-service=http
firewall-offline-cmd --zone=public --add-service=https

systemctl start firewalld
systemctl enable firewalld

if [ "${enable_sec_interface_compute}" == true ]; then
    sec_interface=$(nmcli -t con show --active | grep eth1 | cut -d ':' -f 1)
    nmcli conn del "$sec_interface"
    nmcli con add type ethernet con-name eth1 ifname eth1
    echo "DOMAIN=\"${storage_dns_domain}\"" >> "/etc/sysconfig/network-scripts/ifcfg-${protocol_interfaces}"
    echo "MTU=9000" >> "/etc/sysconfig/network-scripts/ifcfg-${protocol_interfaces}"
    systemctl restart NetworkManager
fi
