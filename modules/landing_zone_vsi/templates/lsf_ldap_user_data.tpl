#!/usr/bin/env bash

###############################################################################
# Initialization Script
#
# Purpose:
#   Configure basic user access and SSH security during instance initialization.
#
# Description:
#   This script performs the following tasks:
#     - Applies password policy settings for the specified user
#     - Restricts direct root SSH access via authorized_keys
#     - Configures SSH keys and access for the cluster/user account
#     - Updates SSH daemon configuration to disable root login
#
# Logging:
#   - Logs are written to: /tmp/init-script.log
#
# Notes:
#   - Intended to run during instance provisioning or first boot
#   - Designed to continue execution even if individual steps fail
#   - Focused on access control and SSH security configuration
###############################################################################

###############################################################################
# Script Variables
###############################################################################

CLUSTER_USER="ubuntu"
LOGFILE="/tmp/init-script.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOGFILE"
}

log "Initialization script started"

###############################################################################
# 1. Configure user password policy
###############################################################################

if id "$CLUSTER_USER" &>/dev/null; then
    log "Configuring password policy for user: $CLUSTER_USER"
    chage -I -1 -m 0 -M 99999 -E -1 -W 14 "$CLUSTER_USER" || log "WARNING: Failed to apply password policy"
else
    log "WARNING: User $CLUSTER_USER not found"
fi

###############################################################################
# 2. Update root SSH authorized_keys restrictions
###############################################################################

log "Updating root SSH access restrictions"

if [ -f /root/.ssh/authorized_keys ]; then
    sed -i \
      -e "s|^|no-port-forwarding,no-agent-forwarding,no-X11-forwarding,command=\"echo 'Login as the \\\"$CLUSTER_USER\\\" user rather than \\\"root\\\".';echo;sleep 5; exit 142\" |" \
      /root/.ssh/authorized_keys || log "WARNING: Failed to update root authorized_keys"
else
    log "WARNING: Root authorized_keys file not found"
fi

###############################################################################
# 3. Configure SSH access for cluster user
###############################################################################

log "Setting up SSH configuration for user: $CLUSTER_USER"

mkdir -p /home/$CLUSTER_USER/.ssh || log "WARNING: Failed to create .ssh directory"
chmod 700 /home/$CLUSTER_USER/.ssh

cat <<EOF >> /home/$CLUSTER_USER/.ssh/authorized_keys
${cluster_public_key_content}
EOF

cat <<EOF > /home/$CLUSTER_USER/.ssh/id_rsa
${cluster_private_key_content}
EOF

cat <<EOF > /home/$CLUSTER_USER/.ssh/config
Host *
    StrictHostKeyChecking no
EOF

chmod 600 /home/$CLUSTER_USER/.ssh/config
chmod 600 /home/$CLUSTER_USER/.ssh/id_rsa
chmod 600 /home/$CLUSTER_USER/.ssh/authorized_keys

chown -R $CLUSTER_USER:$CLUSTER_USER /home/$CLUSTER_USER/.ssh || log "WARNING: Failed to set ownership"

###############################################################################
# 4. Disable root SSH login
###############################################################################

log "Disabling direct root SSH login"

sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config || \
    log "WARNING: Failed to update sshd_config"

systemctl restart ssh || systemctl restart sshd || \
    log "WARNING: Failed to restart SSH service"

###############################################################################
# 5. Completion
###############################################################################

log "Initialization script completed"
