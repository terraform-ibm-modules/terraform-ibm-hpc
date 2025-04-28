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
echo "${management_public_key_content}" >> ~/.ssh/authorized_keys
echo "StrictHostKeyChecking no" >> ~/.ssh/config
echo "${management_private_key_content}" > ~/.ssh/id_rsa
chmod 600 ~/.ssh/id_rsa

# network setup
echo "DOMAIN=${management_dns_domain}" >> "/etc/sysconfig/network-scripts/ifcfg-${management_interfaces}"
echo "MTU=9000" >> "/etc/sysconfig/network-scripts/ifcfg-${management_interfaces}"
chage -I -1 -m 0 -M 99999 -E -1 -W 14 vpcuser
sleep 20
systemctl restart NetworkManager

RESOLV_CONF="/etc/resolv.conf"
BACKUP_FILE="/etc/resolv.conf.bkp"

# Helper function to safely modify /etc/resolv.conf
make_editable() {
    if lsattr "$RESOLV_CONF" 2>/dev/null | grep -q 'i'; then
        chattr -i "$RESOLV_CONF"
    fi
}

make_immutable() {
    chattr +i "$RESOLV_CONF"
}

# Main logic
echo "Checking if 'search ${management_dns_domain}' exists in $RESOLV_CONF..."
if ! grep -Fxq "search ${management_dns_domain}" "$RESOLV_CONF"; then
    echo "Domain not found, applying fix..."

    sleep 60

    # Backup only once if backup doesn't exist
    if [ ! -f "$BACKUP_FILE" ]; then
        cp "$RESOLV_CONF" "$BACKUP_FILE"
        echo "Backup created at $BACKUP_FILE"
    fi

    make_editable

    if grep -q '^search ' "$RESOLV_CONF"; then
        # Replace existing search line
        sed -i "s|^search .*|search ${management_dns_domain}|" "$RESOLV_CONF"
    else
        # Insert search line at the top
        sed -i "1i search ${management_dns_domain}" "$RESOLV_CONF"
    fi

    make_immutable
    echo "Updated $RESOLV_CONF with search domain."

    # Restart NetworkManager only if change was made
    if systemctl is-active --quiet NetworkManager; then
        systemctl restart NetworkManager
        echo "NetworkManager restarted."
    else
        echo "NetworkManager is not running."
    fi

else
    echo "Search domain already present, Updating $RESOLV_CONF has immutable."
    make_immutable
fi