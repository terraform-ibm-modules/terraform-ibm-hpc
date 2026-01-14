#!/usr/bin/bash

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
        package_list="python3 kernel-devel-$(uname -r) kernel-headers-$(uname -r) firewalld numactl make gcc-c++ elfutils-libelf-devel bind-utils iptables nfs-utils elfutils elfutils-devel yum-plugin-versionlock"
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
yum versionlock $package_list
yum versionlock list
echo 'export PATH=$PATH:/usr/lpp/mmfs/bin' >> /home/$USER/.bashrc
echo 'export PATH=$PATH:/usr/lpp/mmfs/bin' >> /root/.bashrc

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

echo "DOMAIN=${storage_dns_domain}" >> "/etc/sysconfig/network-scripts/ifcfg-${storage_interfaces}"
echo "MTU=9000" >> "/etc/sysconfig/network-scripts/ifcfg-${storage_interfaces}"
chage -I -1 -m 0 -M 99999 -E -1 -W 14 vpcuser
systemctl restart NetworkManager
hostnamectl set-hostname "$(hostname).${storage_dns_domain}"

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

if [ "${enable_sec_interface_storage}" == true ]; then
    sec_interface=$(nmcli -t con show --active | grep eth1 | cut -d ':' -f 1)
    nmcli conn del "$sec_interface"
    nmcli con add type ethernet con-name eth1 ifname eth1
    echo "DOMAIN=\"${storage_dns_domain}\"" >> "/etc/sysconfig/network-scripts/ifcfg-${protocol_interfaces}"
    echo "MTU=9000" >> "/etc/sysconfig/network-scripts/ifcfg-${protocol_interfaces}"
    # Wait until eth1 gets an IP
    while ! ip -4 addr show eth1 | grep -q "inet "; do sleep 1; done

    ETH1_IP=$(ip -4 addr show eth1 | awk '/inet /{print $2}' | cut -d/ -f1)
    GW="$(echo $ETH1_IP | awk -F. '{print $1"."$2"."$3".1"}')"

    ip rule add from $ETH1_IP table 101
    ip route add default via $GW dev eth1 table 101

    systemctl restart NetworkManager
fi

if [ "${enable_protocol}" == true ]; then
    sec_interface=$(nmcli -t con show --active | grep eth1 | cut -d ':' -f 1)
    nmcli conn del "$sec_interface"
    nmcli con add type ethernet con-name eth1 ifname eth1
    echo "DOMAIN=${protocol_dns_domain}" >> "/etc/sysconfig/network-scripts/ifcfg-${protocol_interfaces}"
    echo "MTU=9000" >> "/etc/sysconfig/network-scripts/ifcfg-${protocol_interfaces}"
    systemctl restart NetworkManager
    ###### TODO: Fix Me ######
    echo "IC_REGION=${vpc_region}" >> /etc/environment
    echo "IC_SUBNET=${protocol_subnets}" >> /etc/environment
    echo "IC_RG=${resource_group_id}" >> /etc/environment
fi
