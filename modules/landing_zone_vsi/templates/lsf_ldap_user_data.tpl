#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# Script Variables
###############################################################################

CLUSTER_USER="ubuntu"
LOGFILE="/tmp/user-data.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOGFILE"
}

log "STARTING user-data initialization script"

###############################################################################
# 1. Configure password aging policy
###############################################################################

if id "$CLUSTER_USER" &>/dev/null; then
    log "Applying password aging policy for user: $CLUSTER_USER"
    chage -I -1 -m 0 -M 99999 -E -1 -W 14 "$CLUSTER_USER"
else
    log "WARNING: user $CLUSTER_USER does not exist"
fi

###############################################################################
# 2. Restrict root SSH login
###############################################################################

log "Restricting root SSH login via authorized_keys"

if [ -f /root/.ssh/authorized_keys ]; then
    sed -i \
      -e "s|^|no-port-forwarding,no-agent-forwarding,no-X11-forwarding,command=\"echo 'Login as the \\\"$CLUSTER_USER\\\" user rather than \\\"root\\\".';echo;sleep 5; exit 142\" |" \
      /root/.ssh/authorized_keys
else
    log "WARNING: /root/.ssh/authorized_keys file not found"
fi

###############################################################################
# 3. Configure SSH keys for cluster user
###############################################################################

log "Configuring SSH keys for $CLUSTER_USER"

mkdir -p /home/$CLUSTER_USER/.ssh
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

chown -R $CLUSTER_USER:$CLUSTER_USER /home/$CLUSTER_USER/.ssh

###############################################################################
# 4. Disable root SSH login
###############################################################################

log "Disabling root SSH login"

sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config

systemctl restart ssh || systemctl restart sshd

###############################################################################
# 5. Script completion
###############################################################################

log "User-data initialization script completed successfully"
