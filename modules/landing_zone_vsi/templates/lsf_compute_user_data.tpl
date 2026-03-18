#!/usr/bin/env bash

###############################################################################
# User Data Initialization Script
# Purpose:
#   Configure system, networking, security, and IBM Spectrum LSF
#   during instance initialization.
#
# Notes:
#   - Logs are written to /tmp/user_data.log
#   - Includes retry logic for LSF host setup
#   - Includes Observability setup
###############################################################################

###############################################################################
# Script Variables (Internal configuration used within this script)
###############################################################################
LOGFILE="/tmp/user_data.log"
USER="vpcuser"
REPO_ID="ansible-2-for-rhel-8-x86_64-rpms"
CLUSTER_USER="lsfadmin"
DEFAULT_CLUSTER_NAME="HPCCluster"
LSF_TOP="/opt/ibm/lsf"
LSF_CONF="$LSF_TOP/conf"
LSF_TOP_VERSION="$LSF_TOP/10.1"
HOSTNAME="$(hostname)"

###############################################################################
# Logging function
###############################################################################
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
# 3. Apply kernel and network performance tuning
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
# 5. Manage DNS configuration (/etc/resolv.conf)
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
# 6. Configure SSH access for default user
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
# 7. Update LSF cluster name if required
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


###############################################################################
# 8. Disable unnecessary yum repository
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
# 9. Configure LSF sudoers and run host setup with retry
###############################################################################

MAX_RETRIES=5
COUNT=1
SUCCESS=0

while [ $COUNT -le $MAX_RETRIES ]; do
  log "Attempt $COUNT: Running LSF hostsetup..."

  OUTPUT=$($LSF_TOP/10.1/install/hostsetup --top="$LSF_TOP" --boot="y" --start="y" --dynamic 2>&1)
  RC=$?

  echo "$OUTPUT" | while read line; do log "$line"; done

  if echo "$OUTPUT" | grep -q "LSF host setup is done"; then
    log "LSF hostsetup completed successfully on attempt $COUNT"
    SUCCESS=1
    break
  else
    log "LSF hostsetup FAILED on attempt $COUNT (rc=$RC)"
    COUNT=$((COUNT + 1))
    sleep 5
  fi
done

if [ $SUCCESS -ne 1 ]; then
  log "LSF hostsetup FAILED after $MAX_RETRIES attempts"
  exit 1
fi

rm -rf /opt/ibm/lsf/log/*

log "LSF daemon service (lsfd) configured and started"

###############################################################################
# 10. Configure LSF environment profiles
###############################################################################

echo "source $LSF_CONF/profile.lsf" >> /root/.bashrc
echo "source $LSF_CONF/profile.lsf" >> /home/$CLUSTER_USER/.bashrc

log "LSF environment profiles added to user shell configuration"

###############################################################################
# 11. Configure sysdig and cloud logs
###############################################################################

# this_hostname="$(hostname)"

if [ "${cloud_monitoring_access_key}" != "" ] && [ "${cloud_monitoring_ingestion_url}" != "" ]; then
  log "cloud_monitoring_access_key and cloud_monitoring_ingestion_url are provided"
  SYSDIG_CONFIG_FILE="/opt/draios/etc/dragent.yaml"

  #packages installation
  log "Writing sysdig config file"

  #sysdig config file
  log "Setting customerid access key"
  sed -i "s/==ACCESSKEY==/${cloud_monitoring_access_key}/g" $SYSDIG_CONFIG_FILE
  sed -i "s/==COLLECTOR==/${cloud_monitoring_ingestion_url}/g" $SYSDIG_CONFIG_FILE
  echo "tags: type:compute,lsf:true" >>$SYSDIG_CONFIG_FILE
else
  log "Skipping metrics agent configuration due to missing parameters"
fi

if [ "${observability_monitoring_on_compute_nodes_enable}" = true ]; then

  log "Restarting sysdig agent"
  systemctl enable dragent
  systemctl restart dragent
else
  log "Metrics agent start skipped since monitoring provisioning is not enabled"
fi

# Setting up the IBM Cloud Logs
if [ "${observability_logs_enable_for_compute}" = true ]; then
  log "observability_logs_enable_for_compute is true"
  sudo cp /opt/fluent-bit/bin/post-config.sh /opt/ibm
  cd /opt/ibm || exit

  cat <<EOL >/etc/fluent-bit/fluent-bit.conf
[SERVICE]
  Flush                   1
  Log_Level               info
  Daemon                  off
  Parsers_File            parsers.conf
  Plugins_File            plugins.conf
  HTTP_Server             On
  HTTP_Listen             0.0.0.0
  HTTP_Port               9001
  Health_Check            On
  HC_Errors_Count         1
  HC_Retry_Failure_Count  1
  HC_Period               30
  storage.path            /fluent-bit/cache
  storage.max_chunks_up   192
  storage.metrics         On

[INPUT]
  Name                syslog
  Path                /tmp/in_syslog
  Buffer_Chunk_Size   32000
  Buffer_Max_Size     64000
  Receive_Buffer_Size 512000

[INPUT]
  Name              tail
  Tag               *
  Path              /opt/ibm/lsf/log/*.log.*
  Path_Key          file
  Exclude_Path      /var/log/at/**
  DB                /opt/ibm/lsf/log/fluent-bit.DB
  Buffer_Chunk_Size 32KB
  Buffer_Max_Size   256KB
  Skip_Long_Lines   On
  Refresh_Interval  10
  storage.type      filesystem
  storage.pause_on_chunks_overlimit on

[FILTER]
  Name modify
  Match *
  Add subsystemName compute
  Add applicationName lsf
@INCLUDE outputs.conf
EOL
  log "Providing execution access to post-config.sh"
  sudo chmod +x post-config.sh
  sudo ./post-config.sh -h "${cloud_logs_ingress_private_endpoint}" -p "3443" -t "/logs/v1/singles" -a IAMAPIKey -k "${vpc_apikey_value}" --send-directly-to-icl -s true -i Production
  log "Adding INFO testing line to fluent-test.log.com"
  echo "INFO Testing IBM Cloud LSF Logs from compute: '$HOSTNAME'" | sudo tee -a /opt/ibm/lsf/log/fluent-test.log.com >/dev/null
  log "fluent-test.log.com has been successfully created"
else
  echo "Cloud Logs configuration skipped since observability logs for compute is not enabled"
fi

log "Completed sysdig and cloud logs configuration step"

###############################################################################
# 12. Script completion
###############################################################################
log "User-data initialization script completed successfully"

source /root/.bashrc
source /home/$CLUSTER_USER/.bashrc
