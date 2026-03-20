#!/usr/bin/env bash

###############################################################################
# Initialization Script
#
# Purpose:
#   Perform system initialization, security hardening, networking setup,
#   and IBM Spectrum LSF configuration during instance provisioning.
#
# Description:
#   This script performs the following high-level tasks:
#     - Configures user access and password policies
#     - Applies SSH security restrictions and access controls
#     - Tunes system kernel and network performance parameters
#     - Updates network interface and DNS configurations
#     - Prepares and configures IBM Spectrum LSF environment
#     - Validates and updates cluster configuration dynamically
#     - Executes LSF host setup with retry mechanism
#     - Manages repository configuration and system dependencies
#     - Configures monitoring and observability components (metrics and logs)
#     - Manages system services and disables unused components
#
# Logging:
#   - All logs are written to: /tmp/init-script.log
#
# Notes:
#   - Intended to run during instance provisioning or first boot
#   - Designed to continue execution across non-critical failures
#   - Includes retry logic for critical setup steps
#   - Supports optional observability and monitoring configuration
###############################################################################

###############################################################################
# Script Variables
###############################################################################
LOGFILE="/tmp/init-script.log"
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

log "Initialization script started"

###############################################################################
# 1. Configure password policy
###############################################################################
log "Configuring password policy"

chage -I -1 -m 0 -M 99999 -E -1 -W 14 "$USER"
chage -I -1 -m 0 -M 99999 -E -1 -W 14 "$CLUSTER_USER"

###############################################################################
# 2. Update SSH access restrictions
###############################################################################
log "Updating SSH access restrictions"

if [ -f /root/.ssh/authorized_keys ]; then
    sed -i \
      -e "s|^|no-port-forwarding,no-agent-forwarding,no-X11-forwarding,command=\"echo 'Login as the \\\"$USER\\\" user rather than \\\"root\\\".';echo;sleep 5; exit 142\" |" \
      /root/.ssh/authorized_keys
else
    log "WARNING: Root authorized_keys file not found"
fi

###############################################################################
# 3. Apply system tuning
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
# 4. Configure network
###############################################################################
log "Updating network configuration"

IFCFG_FILE="/etc/sysconfig/network-scripts/ifcfg-${interface}"
ROUTE_FILE="/etc/sysconfig/network-scripts/route-${interface}"

touch "$IFCFG_FILE"
touch "$ROUTE_FILE"

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
# 5. Configure DNS settings
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
    log "Backup created at $BACKUP_FILE"
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
# 6. Configure SSH for user
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
# 7. Validate cluster configuration
###############################################################################
log "Validating cluster configuration"

if [ "$DEFAULT_CLUSTER_NAME" != "${cluster_prefix}" ]; then
    log "Updating cluster configuration to new name: ${cluster_prefix}"

    grep -rli "$DEFAULT_CLUSTER_NAME" $LSF_CONF/* \
        | xargs sed -i "s/$DEFAULT_CLUSTER_NAME/${cluster_prefix}/g" \
        >>"$LOGFILE" 2>&1

    for file in $(find $LSF_TOP -name "*$DEFAULT_CLUSTER_NAME*"); do
        log "Renaming file: $file"
        mv "$file" $(echo "$file" | sed -r "s/$DEFAULT_CLUSTER_NAME/${cluster_prefix}/g")
    done

    log "Cluster configuration update completed"
else
    log "Cluster configuration unchanged"
fi

###############################################################################
# 8. Check repository configuration
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
# 9. Run LSF host setup with retry
###############################################################################
MAX_RETRIES=5
COUNT=1
SUCCESS=0

while [ $COUNT -le $MAX_RETRIES ]; do
  log "Attempt $COUNT: Running LSF host setup"

  OUTPUT=$($LSF_TOP/10.1/install/hostsetup --top="$LSF_TOP" --boot="y" --start="y" --dynamic 2>&1)
  RC=$?

  echo "$OUTPUT" | while read line; do log "$line"; done

  if echo "$OUTPUT" | grep -q "LSF host setup is done"; then
    log "LSF host setup completed successfully on attempt $COUNT"
    SUCCESS=1
    break
  else
    log "WARNING: LSF host setup failed on attempt $COUNT (rc=$RC)"
    COUNT=$((COUNT + 1))
    sleep 5
  fi
done

if [ $SUCCESS -ne 1 ]; then
  log "WARNING: LSF host setup failed after $MAX_RETRIES attempts"
  exit 1
fi

rm -rf /opt/ibm/lsf/log/*

log "LSF host setup completed"

###############################################################################
# 10. Configure LSF environment
###############################################################################

log "Updating environment configuration"
echo "source $LSF_CONF/profile.lsf" >> /root/.bashrc
echo "source $LSF_CONF/profile.lsf" >> /home/$CLUSTER_USER/.bashrc
echo "source /opt/ibm/lsfsuite/ext/profile.platform" >> /home/$CLUSTER_USER/.bashrc
echo "source /opt/ibm/lsfsuite/ext/profile.platform" >> /root/.bashrc

log "Environment configuration updated"

###############################################################################
# 11. Configure monitoring and logging components
###############################################################################

# this_hostname="$(hostname)"
# Ensure lsf_prometheus_exporter service to be executed after shared filesystem mount
log "Starting lsf_prometheus_exporter"
sed -i 's/After=network-online.target/After=network-online.target mnt-lsf.mount/g' /etc/systemd/system/lsf_prometheus_exporter.service
systemctl daemon-reload

# Enable LSF prometheus exporter
systemctl enable lsf_prometheus_exporter
systemctl restart lsf_prometheus_exporter

# Setting up the Metrics Agent
if [ "${observability_monitoring_enable}" = true ]; then
  log "observability_monitoring_enable is true"
  if [ "${cloud_monitoring_access_key}" != "" ] && [ "${cloud_monitoring_ingestion_url}" != "" ]; then
    log "cloud_monitoring_access_key and cloud_monitoring_ingestion_url are provided"
    SYSDIG_CONFIG_FILE="/opt/draios/etc/dragent.yaml"
    PROMETHEUS_CONFIG_FILE="/opt/prometheus/prometheus.yml"

    #packages installation
    log "Writing sysdig config file"

    #sysdig config file
    log "Setting customerid access key"
    sed -i "s/==ACCESSKEY==/${cloud_monitoring_access_key}/g" $SYSDIG_CONFIG_FILE
    sed -i "s/==COLLECTOR==/${cloud_monitoring_ingestion_url}/g" $SYSDIG_CONFIG_FILE
    echo "tags: type:management,lsf:true" >> $SYSDIG_CONFIG_FILE

    cat <<EOTF > $PROMETHEUS_CONFIG_FILE
global:
  scrape_interval: 60s # Set the scrape interval to every 15 seconds. Default is every 1 minute.
  evaluation_interval: 15s # Evaluate rules every 15 seconds. The default is every 1 minute.
  # scrape_timeout is set to the global default (10s).

scrape_configs:
  - job_name: "lsf_prometheus_exporter"
    static_configs:
      - targets: ["localhost:9405"]
remote_write:
- url: "${cloud_monitoring_prws_url}"
  authorization:
    credentials: "${cloud_monitoring_prws_key}"
EOTF
    log "Restarting prometheus"
    # Enable prometheus
    systemctl enable prometheus
    systemctl restart prometheus

    log "Restarting sysdig agent"
    systemctl enable dragent
    systemctl restart dragent
  else
    log "Skipping metrics agent configuration due to missing parameters"
  fi
else
  log "Metrics agent configuration skipped since monitoring provisioning is not enabled"
fi

# Setting up the IBM Cloud Logs
if [ "${observability_logs_enable_for_management}" = true ]; then

  log "Configuring cloud logs for management since observability logs for management is enabled"

  sudo cp /opt/fluent-bit/bin/post-config.sh /opt/ibm
  cd /opt/ibm || exit

  cat <<EOL > /etc/fluent-bit/fluent-bit.conf
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
  Add subsystemName management
  Add applicationName lsf
@INCLUDE outputs.conf
EOL
  log "Proving execution access to post-config.sh"
  sudo chmod +x post-config.sh
  sudo ./post-config.sh -h "${cloud_logs_ingress_private_endpoint}" -p "3443" -t "/logs/v1/singles" -a IAMAPIKey -k "${vpc_apikey_value}" --send-directly-to-icl -s true -i Production
  log "Adding INFO testing line to fluent-test.log.com"
  log "I am in host: '$HOSTNAME'"
  echo "INFO Testing IBM Cloud LSF Logs from management: '$HOSTNAME'" | sudo tee -a /opt/ibm/lsf/log/fluent-test.log.com >/dev/null
  log "fluent-test.log.com has been successfully created"
else
  log "Cloud Logs configuration skipped since observability logs for management is not enabled"
fi

log "Completed sysdig and cloud logs configuration step"

###############################################################################
# 12. Stop and disable unused services
###############################################################################

systemctl stop lwsd
systemctl disable lwsd

systemctl stop mariadb
systemctl disable mariadb

log "Stopping unused services"

###############################################################################
# 13. Script completion
###############################################################################
log "Initialization script completed"

source /root/.bashrc
source /home/$CLUSTER_USER/.bashrc
