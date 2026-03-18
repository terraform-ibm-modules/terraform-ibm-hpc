#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# Script Variables (Internal configuration used within this script)
###############################################################################
LOGFILE="/tmp/user_data.log"
USER="vpcuser"   # Default system user for RHEL instances
REPO_ID="ansible-2-for-rhel-8-x86_64-rpms"
CLUSTER_USER="lsfadmin"
DEFAULT_CLUSTER_NAME="HPCCluster"
LSF_TOP="/opt/ibm/lsf"
LSF_CONF="$LSF_TOP/conf"
LSF_TOP_VERSION="$LSF_TOP/10.1"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOGFILE"
}

log "STARTING user-data initialization script"

###############################################################################
# 1. Configure password aging policy for system users
###############################################################################

log "Applying password aging policy for users: $USER and $CLUSTER_USER"

chage -I -1 -m 0 -M 99999 -E -1 -W 14 "$USER"
chage -I -1 -m 0 -M 99999 -E -1 -W 14 "$CLUSTER_USER"

###############################################################################
# 2. Restrict direct root SSH access
###############################################################################

log "Restricting root SSH login via authorized_keys"

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

log "Applying system-level kernel tuning parameters"

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

log "Updating network interface configuration"

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

log "Updating DNS search domain in /etc/resolv.conf"

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

log "/etc/resolv.conf updated and locked (immutable)"

###############################################################################
# 6. Configure SSH access for the default user
###############################################################################

log "Setting up SSH configuration for user $USER"

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
# 7. Update LSF cluster name if a custom cluster prefix is provided
###############################################################################

log "Checking whether cluster name update is required"

if [ "$DEFAULT_CLUSTER_NAME" != "${cluster_prefix}" ]; then
    log "Detected new cluster name: ${cluster_prefix}. Updating LSF configuration."

    log "Updating cluster name references inside $LSF_CONF"
    grep -rli "$DEFAULT_CLUSTER_NAME" $LSF_CONF/* \
        | xargs sed -i "s/$DEFAULT_CLUSTER_NAME/${cluster_prefix}/g" \
        >>"$LOGFILE" 2>&1

    for file in $(find $LSF_TOP -name "*$DEFAULT_CLUSTER_NAME*"); do
        log "Renaming file: $file"
        mv "$file" $(echo "$file" | sed -r "s/$DEFAULT_CLUSTER_NAME/${cluster_prefix}/g")
    done

    log "Cluster name update completed successfully"
else
    log "Cluster name update not required"
fi

rm -rf /opt/ibm/lsf/log/*

###############################################################################
# 8. Disable Ansible repository if it exists
###############################################################################

log "Checking if yum repository $REPO_ID is enabled"

if yum repolist 2>/dev/null | grep -q "^$REPO_ID"; then
    log "Repository $REPO_ID detected. Attempting to disable it."

    for i in 1 2 3; do
        log "Disable attempt $i for repository $REPO_ID"
        if subscription-manager repos --disable="$REPO_ID" >>"$LOGFILE" 2>&1; then
            break
        fi
        sleep 2
    done
else
    log "Repository $REPO_ID is not present"
fi

###############################################################################
# 9. Configure environment profiles for LSF
###############################################################################

echo "source $LSF_CONF/profile.lsf" >> /home/$CLUSTER_USER/.bashrc

log "LSF environment profiles added to user shell configuration"

###############################################################################
# 10. Script completion
###############################################################################

log "User-data initialization script completed successfully"



# Reload environment for current session
source /home/$CLUSTER_USER/.bashrc
