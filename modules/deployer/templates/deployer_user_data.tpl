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
sed -i -e "s/^/no-port-forwarding,no-agent-forwarding,no-X11-forwarding,command=\"echo \'Please login as the user \\\\\"$USER\\\\\" rather than the user \\\\\"root\\\\\".\';echo;sleep 5; exit 142\" /" /root/.ssh/authorized_keys
echo "DOMAIN=${compute_dns_domain}" >> "/etc/sysconfig/network-scripts/ifcfg-${compute_interfaces}"
echo "MTU=9000" >> "/etc/sysconfig/network-scripts/ifcfg-${compute_interfaces}"
chage -I -1 -m 0 -M 99999 -E -1 -W 14 vpcuser
sleep 10
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
echo "Checking if 'search ${compute_dns_domain}' exists in $RESOLV_CONF..."
if ! grep -Fxq "search ${compute_dns_domain}" "$RESOLV_CONF"; then
    echo "Domain not found, applying fix..."

    # Backup only once if backup doesn't exist
    if [ ! -f "$BACKUP_FILE" ]; then
        cp "$RESOLV_CONF" "$BACKUP_FILE"
        echo "Backup created at $BACKUP_FILE"
    fi

    make_editable

    if grep -q '^search ' "$RESOLV_CONF"; then
        # Replace existing search line
        sed -i "s|^search .*|search ${compute_dns_domain}|" "$RESOLV_CONF"
    else
        # Insert search line at the top
        sed -i "1i search ${compute_dns_domain}" "$RESOLV_CONF"
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
    echo "Search domain already present, no changes made."
fi

# input parameters
echo "${bastion_public_key_content}" >> /home/$USER/.ssh/authorized_keys
echo "StrictHostKeyChecking no" >> /home/$USER/.ssh/config
echo "StrictHostKeyChecking no" >> ~/.ssh/config

# # setup env
# # TODO: Conditional installation (python3, terraform & ansible)
# if grep -E -q "CentOS|Red Hat" /etc/os-release
# then
#     # TODO: Terraform Repo access
#     #yum install -y yum-utils
#     #yum-config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo
#     #if (which terraform); then echo "Terraform exists, skipping the installation"; else (yum install -y terraform
#     if (which python3); then echo "Python3 exists, skipping the installation"; else (yum install -y python38); fi
#     if (which ansible-playbook); then echo "Ansible exists, skipping the installation"; else (yum install -y ansible); fi
# elif grep -q "Ubuntu" /etc/os-release
# then
#     apt update
#     # TODO: Terraform Repo access
#     #apt-get update && sudo apt-get install -y gnupg software-properties-common
#     #wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | tee /usr/share/keyrings/hashicorp-archive-keyring.gpg
#     #gpg --no-default-keyring --keyring /usr/share/keyrings/hashicorp-archive-keyring.gpg --fingerprint
#     apt install software-properties-common
#     apt-add-repository --yes --update ppa:ansible/ansible
#     if (which python3); then echo "Python3 exists, skipping the installation"; else (apt install python38); fi
#     if (which ansible-playbook); then echo "Ansible exists, skipping the installation"; else (apt install ansible); fi
# fi

# TODO: run terraform
