#!/usr/bin/env bash

###############################################################################
# Initialization Script
#
# Purpose:
#   Perform system initialization and configuration during instance startup.
#
# Description:
#   This script performs the following high-level tasks:
#     - Applies user and security configurations
#     - Configures SSH access and restrictions
#     - Applies system and kernel tuning parameters
#     - Updates network and DNS settings
#     - Sets up user SSH keys and access
#     - Validates and updates application/cluster configuration
#     - Performs repository and environment configuration
#
# Logging:
#   - All execution logs are written to: /tmp/init-script.log
#
# Notes:
#   - Intended to run during instance provisioning or first boot
#   - Continues execution even if individual steps fail
#   - Intended for automated infrastructure environments
###############################################################################

###############################################################################
# Script Variables (Internal configuration used within this script)
###############################################################################
LOGFILE="/tmp/init-script.log"
USER="vpcuser"
REPO_ID="ansible-2-for-rhel-8-x86_64-rpms"
CLUSTER_USER="lsfadmin"
DEFAULT_CLUSTER_NAME="HPCCluster"
LSF_TOP="/opt/ibm/lsf"
LSF_CONF="$LSF_TOP/conf"
LSF_TOP_VERSION="$LSF_TOP/10.1"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOGFILE"
}

log "Initialization script started"

###############################################################################
# 1. Configure password policy for system users
###############################################################################

log "Configuring password policy"

chage -I -1 -m 0 -M 99999 -E -1 -W 14 "$USER"
chage -I -1 -m 0 -M 99999 -E -1 -W 14 "$CLUSTER_USER"

###############################################################################
# 2. Restrict direct root SSH access
###############################################################################

log "Updating SSH access restrictions"

if [ -f /root/.ssh/authorized_keys ]; then
    sed -i \
      -e "s|^|no-port-forwarding,no-agent-forwarding,no-X11-forwarding,command=\"echo 'Login as the \\\"$USER\\\" user rather than \\\"root\\\".';echo;sleep 5; exit 142\" |" \
      /root/.ssh/authorized_keys
else
    log "WARNING: /root/.ssh/authorized_keys file not found"
fi

###############################################################################
# 3. Apply kernel and network performance tuning (sysctl parameters)
###############################################################################

log "Applying system tuning parameters"

LSF_TUNABLES="/etc/sysctl.conf"

{
  echo "vm.overcommit_memory=1"
  echo "net.core.rmem_max=26214400"
  echo "net.core.rmem_default=26214400"
  echo "net.core.wmem_max=26214400"
  echo "net.core.wmem_default=26214400"
  echo "net.ipv4.tcp_fin_timeout=5"
  echo "net.core.somaxconn=8000"
} > "$LSF_TUNABLES"

echo 1 > /proc/sys/vm/overcommit_memory

sysctl -p "$LSF_TUNABLES"

###############################################################################
# 4. Configure network interface parameters
###############################################################################

log "Updating network configuration"

IFCFG_FILE="/etc/sysconfig/network-scripts/ifcfg-${interface}"
ROUTE_FILE="/etc/sysconfig/network-scripts/route-${interface}"

touch "$IFCFG_FILE"
touch "$ROUTE_FILE"

# Remove existing DOMAIN and MTU entries if present
sed -i '/^DOMAIN=/d' "$IFCFG_FILE"
sed -i '/^MTU=/d' "$IFCFG_FILE"

echo "DOMAIN=${dns_domain}" >> "$IFCFG_FILE"
echo "MTU=${mtu_value}" >> "$IFCFG_FILE"

gateway_ip="$(ip route show default | awk '{print $3}' | head -n 1)"

if [ -n "$gateway_ip" ]; then
    sed -i "\|^${rc_cidr_block} via .* dev ${interface}.*|d" "$ROUTE_FILE"
    echo "${rc_cidr_block} via $gateway_ip dev ${interface} metric 0 mtu ${mtu_value}" \
        >> "$ROUTE_FILE"
else
    log "WARNING: Default gateway could not be detected"
fi

systemctl restart NetworkManager

###############################################################################
# 5. Manage /etc/resolv.conf (update search domain and set immutable flag)
###############################################################################

log "Updating DNS configuration"

RESOLV_CONF="/etc/resolv.conf"
BACKUP_FILE="/etc/resolv.conf.bkp"

make_editable() {
    if lsattr "$RESOLV_CONF" 2>/dev/null | grep -q 'i'; then
        chattr -i "$RESOLV_CONF"
    fi
}

make_immutable() {
    chattr +i "$RESOLV_CONF"
}

if [ ! -f "$BACKUP_FILE" ]; then
    cp -p "$RESOLV_CONF" "$BACKUP_FILE"
    log "Backup of resolv.conf created at $BACKUP_FILE"
fi

make_editable

if grep -q '^search ' "$RESOLV_CONF"; then
    sed -i "s/^search .*/search ${dns_domain}/" "$RESOLV_CONF"
else
    echo "search ${dns_domain}" >> "$RESOLV_CONF"
fi

make_immutable

log "DNS configuration updated"

###############################################################################
# 6. Configure SSH access for the default user
###############################################################################

log "Setting up SSH configuration for user"

USER_HOME="/home/$USER"
SSH_DIR="$USER_HOME/.ssh"

mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"

echo "${bastion_public_key_content}" >> "$SSH_DIR/authorized_keys"
echo "${compute_public_key_content}" >> "$SSH_DIR/authorized_keys"

cat > "$SSH_DIR/config" <<EOF
Host *
    StrictHostKeyChecking no
EOF

echo "${compute_private_key_content}" > "$SSH_DIR/id_rsa"

chmod 600 \
    "$SSH_DIR/authorized_keys" \
    "$SSH_DIR/config" \
    "$SSH_DIR/id_rsa"

chown -R "$USER:$USER" "$SSH_DIR"

###############################################################################
# 7. Update LSF cluster name if required
###############################################################################

log "Validating cluster configuration"

if [ "$DEFAULT_CLUSTER_NAME" != "${cluster_prefix}" ]; then
    log "Updating cluster configuration"

    grep -rli "$DEFAULT_CLUSTER_NAME" $LSF_CONF/* \
        | xargs sed -i "s/$DEFAULT_CLUSTER_NAME/${cluster_prefix}/g" \
        >>"$LOGFILE" 2>&1

    for file in $(find $LSF_TOP -name "*$DEFAULT_CLUSTER_NAME*"); do
        log "Renaming file: $file"
        mv "$file" $(echo "$file" | sed -r "s/$DEFAULT_CLUSTER_NAME/${cluster_prefix}/g")
    done

    log "Cluster configuration update completed"
else
    log "No cluster configuration update required"
fi

rm -rf /opt/ibm/lsf/log/*

###############################################################################
# 8. Disable Ansible repository if it exists
###############################################################################

log "Checking repository configuration"

if yum repolist 2>/dev/null | grep -q "^$REPO_ID"; then
    log "Repository detected. Attempting to disable"

    for i in 1 2 3; do
        log "Attempt $i to disable repository"
        if subscription-manager repos --disable="$REPO_ID" >>"$LOGFILE" 2>&1; then
            break
        fi
        sleep 2
    done
else
    log "Repository not present"
fi

###############################################################################
# 9. Configure environment profiles for LSF
###############################################################################

echo "source $LSF_CONF/profile.lsf" >> /home/$CLUSTER_USER/.bashrc

log "Environment configuration updated"

###############################################################################
# 10. Script completion
###############################################################################

log "Initialization script completed"

# Reload environment for current session
source /home/$CLUSTER_USER/.bashrc
