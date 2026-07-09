#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# Script Variables (Internal configuration used within this script)
###############################################################################
LOGFILE="/tmp/user_data.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOGFILE"
}

log "STARTING user-data initialization script"

###############################################################################
# 1. Detect OS and install required packages
###############################################################################

if grep -E -q "CentOS|Red Hat" /etc/os-release; then
    USER="vpcuser"
    yum install -y nc curl unzip jq
elif grep -q "Ubuntu" /etc/os-release; then
    USER="ubuntu"
    apt-get update -y
    apt-get install -y netcat curl unzip jq
else
    log "Unsupported OS detected"
    exit 1
fi

###############################################################################
# 2. Configure password aging policy
###############################################################################

log "Applying password aging policy for user: $USER"

chage -I -1 -m 0 -M 99999 -E -1 -W 14 "$USER"

###############################################################################
# 3. Restrict direct root SSH access
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
# 4. Configure network interface parameters (RHEL/CentOS only)
###############################################################################

if grep -E -q "CentOS|Red Hat" /etc/os-release; then
    log "Updating network interface configuration"

    IFCFG_FILE="/etc/sysconfig/network-scripts/ifcfg-${compute_interfaces}"
    ROUTE_FILE="/etc/sysconfig/network-scripts/route-${compute_interfaces}"

    touch "$IFCFG_FILE"
    touch "$ROUTE_FILE"

    sed -i '/^DOMAIN=/d' "$IFCFG_FILE"
    sed -i '/^MTU=/d' "$IFCFG_FILE"

    echo "DOMAIN=${compute_dns_domain}" >> "$IFCFG_FILE"
    echo "MTU=9000" >> "$IFCFG_FILE"

    systemctl restart NetworkManager
fi

###############################################################################
# 5. Configure SSH access for the default user
###############################################################################

log "Setting up SSH configuration for user $USER"

USER_HOME="/home/$USER"
SSH_DIR="$USER_HOME/.ssh"

mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"

touch "$SSH_DIR/authorized_keys"
touch "$SSH_DIR/config"

echo "${bastion_public_key_content}" >> "$SSH_DIR/authorized_keys"

cat > "$SSH_DIR/config" <<EOF
Host *
    StrictHostKeyChecking no
EOF

chmod 600 "$SSH_DIR/authorized_keys" "$SSH_DIR/config"

chown -R "$USER:$USER" "$SSH_DIR"

###############################################################################
# 6. Script completion
###############################################################################

log "User-data initialization script completed successfully"
