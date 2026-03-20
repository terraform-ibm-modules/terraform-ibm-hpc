#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# Script Variables
###############################################################################
LOGFILE="/tmp/user_data.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOGFILE"
}

log "STARTING user-data initialization script"

###############################################################################
# 1. Detect operating system and set default user
###############################################################################

if grep -E -q "CentOS|Red Hat" /etc/os-release; then
    USER="vpcuser"
elif grep -q "Ubuntu" /etc/os-release; then
    USER="ubuntu"
else
    log "Unsupported operating system detected"
    exit 1
fi

###############################################################################
# 2. Restrict direct root SSH access
###############################################################################

log "Restricting root SSH login via authorized_keys"

if [ -f /root/.ssh/authorized_keys ]; then
    sed -i \
    -e "s/^/no-port-forwarding,no-agent-forwarding,no-X11-forwarding,command=\"echo \'Please login as the user \\\\\\\"$USER\\\\\\\" rather than the user \\\\\\\"root\\\\\\\".\';echo;sleep 5; exit 142\" /" \
    /root/.ssh/authorized_keys
else
    log "WARNING: /root/.ssh/authorized_keys file not found"
fi

###############################################################################
# 3. Configure SSH access for default user
###############################################################################

log "Configuring SSH access for user $USER"

USER_HOME="/home/$USER"
SSH_DIR="$USER_HOME/.ssh"

mkdir -p "$SSH_DIR"

echo "${ssh_public_key_content}" >> "$SSH_DIR/authorized_keys"
echo "StrictHostKeyChecking no" >> "$SSH_DIR/config"

chmod 700 "$SSH_DIR"
chmod 600 "$SSH_DIR/authorized_keys" "$SSH_DIR/config"

chown -R "$USER:$USER" "$SSH_DIR"

###############################################################################
# 4. Script completion
###############################################################################

log "User-data initialization script completed successfully"
