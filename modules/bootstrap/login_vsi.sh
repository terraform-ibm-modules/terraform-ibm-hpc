#!/bin/sh
###################################################
# Copyright (C) IBM Corp. 2023 All Rights Reserved.
# Licensed under the Apache License v2.0
###################################################

#variables

logfile="/tmp/user_data.log"

LSF_TOP="/opt/ibm/lsf"
LSF_CONF=$LSF_TOP/conf

nfs_server_with_mount_path=${mount_path}


# Setup logs for user data
echo "START $(date '+%Y-%m-%d %H:%M:%S')" >> $logfile

# Disallow root login
sed -i -e "s/^/no-port-forwarding,no-agent-forwarding,no-X11-forwarding,command=\"echo \'Please login as the user \\\\\"lsfadmin or vpcuser\\\\\" rather than the user \\\\\"root\\\\\".\';echo;sleep 5; exit 142\" /" /root/.ssh/authorized_keys

# echo "DOMAIN=\"$dns_domain\"" >> "/etc/sysconfig/network-scripts/ifcfg-eth0"
echo "DOMAIN=\"$dns_domain\"" >> "/etc/sysconfig/network-scripts/ifcfg-${network_interface}"


# Setup lsfadmin user
# Updates the lsfadmin user as never expire
chage -I -1 -m 0 -M 99999 -E -1 -W 14 lsfadmin
# Setup ssh
lsfadmin_home_dir="/home/lsfadmin"
lsfadmin_ssh_dir="${lsfadmin_home_dir}/.ssh"
mkdir -p ${lsfadmin_ssh_dir}

# Change for RHEL / Ubuntu compute image.
if grep -q "NAME=\"Red Hat Enterprise Linux\"" /etc/os-release; then
  cp /home/vpcuser/.ssh/authorized_keys "${lsfadmin_ssh_dir}/authorized_keys"
elif grep -q "NAME=\"Ubuntu\"" /etc/os-release; then
  cp /home/ubuntu/.ssh/authorized_keys "${lsfadmin_ssh_dir}/authorized_keys"
  sudo cp /home/ubuntu/.profile "{$lsfadmin_home_dir}"
else
  echo "Provided OS distribution not match, provide either RHEL or Ubuntu" >> $logfile
fi

# Setup Network configuration
# Change the MTU setting as this is required for setting mtu as 9000 for communication to happen between clusters
if grep -q "NAME=\"Red Hat Enterprise Linux\"" /etc/os-release; then
    # Replace the MTU value in the Netplan configuration
    echo "MTU=9000" >> "/etc/sysconfig/network-scripts/ifcfg-${network_interface}"
    echo "DOMAIN=\"${dns_domain}\"" >> "/etc/sysconfig/network-scripts/ifcfg-${network_interface}"
    # Change the MTU setting as 9000 at router level.
    gateway_ip=$(ip route | grep default | awk '{print $3}' | head -n 1)
    echo "${rc_cidr_block} via $gateway_ip dev ${network_interface} metric 0 mtu 9000" >> /etc/sysconfig/network-scripts/route-eth0
    systemctl restart NetworkManager
elif grep -q "NAME=\"Ubuntu\"" /etc/os-release; then
    net_int=$(basename /sys/class/net/en*)
    netplan_config="/etc/netplan/50-cloud-init.yaml"
    gateway_ip=$(ip route | grep default | awk '{print $3}' | head -n 1)
    cidr_range=$(ip route show | grep "kernel" | awk '{print $1}' | head -n 1)
    usermod -s /bin/bash lsfadmin
    # Replace the MTU value in the Netplan configuration
    if ! grep -qE "^[[:space:]]*mtu: 9000" $netplan_config; then
        echo "MTU 9000 Packages entries not found"
        # Append the MTU configuration to the Netplan file
        sudo sed -i '/'$net_int':/a\            mtu: 9000' $netplan_config
        sudo sed -i '/dhcp4: true/a \            nameservers:\n              search: ['$dns_domain']' $netplan_config
        sudo sed -i '/'$net_int':/a\            routes:\n              - to: '$cidr_range'\n                via: '$gateway_ip'\n                metric: 100\n                mtu: 9000' $netplan_config
        sudo netplan apply
        echo "MTU set to 9000 on Netplan."
    else
        echo "MTU entry already exists in Netplan. Skipping."
    fi
fi

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

# Setup LSF
echo "Setting LSF share." >> $logfile
# Setup file share
if [ -n "${nfs_server_with_mount_path}" ]; then
  echo "File share ${nfs_server_with_mount_path} found" >> $logfile
  nfs_client_mount_path="/mnt/lsf"
  rm -rf "${nfs_client_mount_path}"
  rm -rf /opt/ibm/lsf/conf/
  rm -rf /opt/ibm/lsf/work/
  mkdir -p "${nfs_client_mount_path}"
  # Mount LSF TOP
  mount -t nfs4 -o sec=sys,vers=4.1 "$nfs_server_with_mount_path" "$nfs_client_mount_path" >> $logfile
  # Verify mount
  if mount | grep "$nfs_client_mount_path"; then
    echo "Mount found" >> $logfile
  else
    echo "No mount found, exiting!" >> $logfile
    exit 1
  fi
  # Update mount to fstab for automount
  echo "$nfs_server_with_mount_path $nfs_client_mount_path nfs rw,sec=sys,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,_netdev 0 0 " >> /etc/fstab
  for dir in conf work; do
    mv "${LSF_TOP}/$dir" "${nfs_client_mount_path}"
    ln -fs "${nfs_client_mount_path}/$dir" "${LSF_TOP}"
    chown -R lsfadmin:root "${LSF_TOP}"
  done
else
  echo "No mount point value found, exiting!" >> $logfile
  exit 1
fi
echo "Setting LSF share is completed." >> $logfile

echo "source ${LSF_CONF}/profile.lsf" >> "${lsfadmin_home_dir}"/.bashrc
echo "source ${LSF_CONF}/profile.lsf" >> /root/.bashrc
echo "profile setup copy complete" >> $logfile

# Ldap Configuration:
enable_ldap="${enable_ldap}"
ldap_server_ip="${ldap_server_ip}"
base_dn="${ldap_basedns}"
ldap_logfile=/tmp/ldap_integration.log

# Configure login node with ldap enabled
if [ "$enable_ldap" = "true" ]; then
    # Detect the operating system
    if grep -q "NAME=\"Red Hat Enterprise Linux\"" /etc/os-release; then
        # Detect RHEL version
        rhel_version=$(grep -oE 'release [0-9]+' /etc/redhat-release | awk '{print $2}')
        # Check if RHEL version is 8
        if [ "$rhel_version" == "8" ]; then
            echo "Detected RHEL 8. Proceeding with LDAP client packages installation..." >> $ldap_logfile
            # Enable SSSD and SSSD Authentication
            authconfig --enablesssd --enablesssdauth --update
            if [ $? -eq 0 ]; then
                echo "SSSD and SSSD Authentication enabled successfully." >> $ldap_logfile
            else
                echo "Failed to enable SSSD and SSSD Authentication." >> $ldap_logfile
                exit 1
            fi
            # Select SSSD Authentication Configuration (for RHEL 8)
            authselect select sssd
            if [ $? -eq 0 ]; then
                echo "SSSD Authentication configuration selected successfully." >> $ldap_logfile
            else
                echo "Failed to select SSSD Authentication configuration." >> $ldap_logfile
                exit 1
            fi
            # LDAP Conf Update with LDAP_SERVER and BASE_DN
            cat <<EOF > /etc/openldap/ldap.conf
# {mark} Ansible Managed Content
URI ldap://${ldap_server_ip}
BASE dc=${base_dn%%.*},dc=${base_dn#*.}
EOF
            # SSSD Conf Update
            cat <<EOF > /etc/sssd/sssd.conf
[domain/default]
autofs_provider = ldap
cache_credentials = True
ldap_search_base = dc=${base_dn%%.*},dc=${base_dn#*.}
id_provider = ldap
auth_provider = ldap
chpass_provider = ldap
ldap_uri = ldap://${ldap_server_ip}
enumerate = true
access_provider = simple
ldap_id_use_start_tls = false
ldap_tls_reqcert = never
[sssd]
services = nss, pam, autofs
domains = default
[nss]
homedir_substring = /home
EOF
            # SSSD Permission set
            chmod 0600 /etc/sssd/sssd.conf
            # Restart SSSD
            systemctl restart sssd

            # Enable SSSD and ODDJOB at boot
            systemctl enable sssd oddjobd.service

            # Enable authselect feature with-mkhomedir
            authselect enable-feature with-mkhomedir

            # Restart ODDJOB and SSHD Services
            systemctl restart oddjobd.service sshd

            # Make LSF commands available for every user.
            echo ". ${LSF_CONF}/profile.lsf" >> /etc/bashrc
            source /etc/bashrc

            echo "LDAP Client configuration completed" >> $ldap_logfile
        else
            echo "This script is designed for RHEL 8. Detected RHEL version: $rhel_version. Exiting." >> $ldap_logfile
            exit 1
        fi
    elif grep -q "NAME=\"Ubuntu\"" /etc/os-release; then

        echo "Detected as Ubuntu. Proceeding with LDAP client packages installation..." >> $ldap_logfile

        # Configure SSSD for LDAP
        cat <<EOF > /etc/sssd/sssd.conf
[domain/default]
autofs_provider = ldap
cache_credentials = True
ldap_search_base = dc=${base_dn%%.*},dc=${base_dn#*.}
id_provider = ldap
auth_provider = ldap
chpass_provider = ldap
ldap_uri = ldap://${ldap_server_ip}
enumerate = true
access_provider = simple
ldap_id_use_start_tls = false
ldap_tls_reqcert = never
[sssd]
services = nss, pam, autofs
domains = default
[nss]
homedir_substring = /home
EOF

        # Enable auto create home directory
        echo "session required pam_mkhomedir.so skel=/etc/skel/ umask=0022" >> /etc/pam.d/common-session

        # Set appropriate permissions for SSSD configuration
        chmod 0600 /etc/sssd/sssd.conf

        # Enable SSSD
        systemctl enable sssd

        # Restart SSSD
        systemctl restart sssd

        # Make LSF commands available for every user.
        echo ". ${LSF_CONF}/profile.lsf" >> /etc/bash.bashrc
        source /etc/bash.bashrc

        echo "LDAP client configuration completed successfully on Ubuntu server." >> $ldap_logfile
    else
        echo "This script is designed for Ubuntu 22 and installation is not supporting. Exiting." >> $ldap_logfile
    fi
else
    echo "LDAP integration is not enabled. Exiting." >> $ldap_logfile
fi