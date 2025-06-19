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
echo "${login_public_key_content}" >> ~/.ssh/authorized_keys
echo "StrictHostKeyChecking no" >> ~/.ssh/config
echo "${login_private_key_content}" > ~/.ssh/id_rsa
chmod 600 ~/.ssh/id_rsa

# Network Configuration
RESOLV_CONF="/etc/resolv.conf"
BACKUP_FILE="/etc/resolv.conf.bkp"

# Optional: backup the interface config
echo "DOMAIN=${login_dns_domain}" >> "/etc/sysconfig/network-scripts/ifcfg-${login_interfaces}"
echo "MTU=9000" >> "/etc/sysconfig/network-scripts/ifcfg-${login_interfaces}"
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
    sed -i "s/^search .*/search ${login_dns_domain}/" "$RESOLV_CONF"
else
    echo "search ${login_dns_domain}" >> "$RESOLV_CONF"
fi

make_immutable
echo "Updated $RESOLV_CONF with search domain '${login_dns_domain}' and locked file."
