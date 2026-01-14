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

sed -i -e "s/^/no-port-forwarding,no-agent-forwarding,no-X11-forwarding,command=\"echo \'Login as the \\\\\"$USER\\\\\" user rather than \\\\\"root\\\\\".\';echo;sleep 5; exit 142\" /" /root/.ssh/authorized_keys

mkdir -p /home/$USER/.ssh
chmod 700 /home/$USER/.ssh
#input parameters
# Append the public keys to the USER's authorized_keys file
echo "${bastion_public_key_content}" >> /home/$USER/.ssh/authorized_keys
echo "${management_public_key_content}" >> /home/$USER/.ssh/authorized_keys
# Create the SSH config file to disable host key checking for all hosts
echo "Host *
    StrictHostKeyChecking no" > /home/$USER/.ssh/config
chmod 600 /home/$USER/.ssh/config
# Write the private key file for USER
echo "${management_private_key_content}" > /home/$USER/.ssh/id_rsa
chmod 600 /home/$USER/.ssh/id_rsa /home/$USER/.ssh/authorized_keys

# Network Configuration
RESOLV_CONF="/etc/resolv.conf"
BACKUP_FILE="/etc/resolv.conf.bkp"

# Optional: backup the interface config
echo "DOMAIN=${management_dns_domain}" >> "/etc/sysconfig/network-scripts/ifcfg-${management_interfaces}"
echo "MTU=${mtu_value}" >> "/etc/sysconfig/network-scripts/ifcfg-${management_interfaces}"
chage -I -1 -m 0 -M 99999 -E -1 -W 14 vpcuser
systemctl restart NetworkManager

make_editable() {
    if lsattr "$RESOLV_CONF" 2>/dev/null | grep -q 'i'; then
        chattr -i "$RESOLV_CONF"
    fi
}

make_immutable() {
    chattr +i "$RESOLV_CONF"
}

# Backup if not already
if [ ! -f "$BACKUP_FILE" ]; then
    cp "$RESOLV_CONF" "$BACKUP_FILE"
    echo "Backup created at $BACKUP_FILE"
fi

make_editable

# Modify or insert 'search' domain
if grep -q '^search ' "$RESOLV_CONF"; then
    sed -i "s/^search .*/search ${management_dns_domain}/" "$RESOLV_CONF"
else
    echo "search ${management_dns_domain}" >> "$RESOLV_CONF"
fi

make_immutable
echo "Updated $RESOLV_CONF with search domain '${management_dns_domain}' and locked file."
