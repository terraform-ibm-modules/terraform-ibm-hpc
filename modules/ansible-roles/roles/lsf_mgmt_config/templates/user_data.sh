#!/bin/bash

logfile="/tmp/user_data.log"
echo "START $(date '+%Y-%m-%d %H:%M:%S')" >>$logfile

# Initialize variables
cluster_prefix="{{ prefix }}"
default_cluster_name="myCluster"
nfs_server_with_mount_path="{{ mount_paths_map['/mnt/lsf'] }}"
cloud_monitoring_access_key="{{ cloud_monitoring_access_key }}"
cloud_monitoring_ingestion_url="{{ cloud_monitoring_ingestion_url }}"
observability_monitoring_on_compute_nodes_enable="{{ monitoring_enable_for_compute }}"
observability_logs_enable_for_compute="{{ logs_enable_for_compute }}"
cloud_logs_ingress_private_endpoint="{{ cloud_logs_ingress_private_endpoint }}"
VPC_APIKEY_VALUE="{{ ibmcloud_api_key }}"
custom_file_shares="{% for key, value in mount_paths_map.items() if key != '/mnt/lsf' %}{{ value }}{% if not loop.last %} {% endif %}{% endfor %}"
custom_mount_paths="{% for key in mount_paths_map.keys() if key != '/mnt/lsf' %}{{ key }}{% if not loop.last %} {% endif %}{% endfor %}"
hyperthreading="{{ enable_hyperthreading }}"
ManagementHostNames="{{ lsf_masters | join(' ') }}"
dns_domain="{{ dns_domain_names }}"
network_interface="eth0"

# LDAP
enable_ldap="{{ enable_ldap }}"
ldap_server="{{ ldap_server }}"
ldap_basedns="{{ ldap_basedns }}"

# Setup Hostname
HostIP=$(hostname -I | awk '{print $1}')
hostname=${cluster_prefix}-${HostIP//./-}
hostnamectl set-hostname "${hostname}"

# Setup vpcuser to login
if grep -E -q "CentOS|Red Hat" /etc/os-release; then
  USER=vpcuser
elif grep -q "Ubuntu" /etc/os-release; then
  USER=ubuntu
fi
sed -i -e "s/^/no-port-forwarding,no-agent-forwarding,no-X11-forwarding,command=\"echo \'Please login as the user \\\\\"$USER\\\\\" rather than the user \\\\\"root\\\\\".\';echo;sleep 5; exit 142\" /" /root/.ssh/authorized_keys

# Make lsfadmin and vpcuser set to newer expire
chage -I -1 -m 0 -M 99999 -E -1 -W 14 "${USER}"
chage -I -1 -m 0 -M 99999 -E -1 -W 14 lsfadmin

# Setup Network configuration
if grep -q "NAME=\"Red Hat Enterprise Linux" /etc/os-release; then
  echo "MTU=9000" >>"/etc/sysconfig/network-scripts/ifcfg-${network_interface}"
  echo "DOMAIN=${dns_domain}" >>"/etc/sysconfig/network-scripts/ifcfg-${network_interface}"
  gateway_ip=$(ip route | grep default | awk '{print $3}' | head -n 1)
  cidr_range=$(ip route show | grep "kernel" | awk '{print $1}' | head -n 1)
  echo "$cidr_range via $gateway_ip dev ${network_interface} metric 0 mtu 9000" >>/etc/sysconfig/network-scripts/route-${network_interface}
  systemctl restart NetworkManager
fi

# Function to attempt NFS mount with retries
mount_nfs_with_retries() {
  local server_path=$1
  local client_path=$2
  local retries=5
  local success=false

  rm -rf "${client_path}"
  mkdir -p "${client_path}"

  for ((j = 0; j < retries; j++)); do
    mount -t nfs -o sec=sys "$server_path" "$client_path" -v >>$logfile
    if mount | grep -q "${client_path}"; then
      echo "Mount successful for ${server_path} on ${client_path}" >>$logfile
      success=true
      break
    else
      echo "Attempt $((j + 1)) of $retries failed for ${server_path} on ${client_path}" >>$logfile
      sleep 2
    fi
  done

  if [ "$success" = true ]; then
    chmod 777 "${client_path}"
    echo "${server_path} ${client_path} nfs rw,sec=sys,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,_netdev 0 0" >>/etc/fstab
  else
    echo "Mount not found for ${server_path} on ${client_path} after $retries attempts." >>$logfile
    rm -rf "${client_path}"
  fi
}

# Setup LSF share
if [ -n "${nfs_server_with_mount_path}" ]; then
  echo "File share ${nfs_server_with_mount_path} found" >>$logfile
  nfs_client_mount_path="/mnt/lsf"
  if mount_nfs_with_retries "${nfs_server_with_mount_path}" "${nfs_client_mount_path}"; then
    echo "Mount completed successfully with ${nfs_client_mount_path}" >>$logfile
  else
    echo "Mount not found for ${nfs_server_with_mount_path}, Exiting !!" >>$logfile
    exit 1
  fi
fi
echo "Setting LSF share is completed." >>$logfile

echo '{% raw %}'
# Setup Custom file shares
echo "Setting custom file shares." >>"$logfile"
if [ -n "${custom_file_shares}" ]; then
  echo "Custom file share ${custom_file_shares} found" >>"$logfile"
  read -ra file_share_array <<<"${custom_file_shares}"
  read -ra mount_path_array <<<"${custom_mount_paths}"
  length=${#file_share_array[@]}

  for ((i = 0; i < length; i++)); do
    mount_nfs_with_retries "${file_share_array[$i]}" "${mount_path_array[$i]}"
  done
fi
echo "Setting custom file shares is completed." >>"$logfile"
echo '{% endraw %}'

# Setup SSH
LDAP_DIR="/home/lsfadmin"
SSH_DIR="$LDAP_DIR/.ssh"
mkdir -p "$SSH_DIR"
cp /home/vpcuser/.ssh/authorized_keys "$SSH_DIR/authorized_keys"
cat "{{ ha_shared_dir }}/ssh/id_rsa.pub" >>"$SSH_DIR/authorized_keys"
cp "{{ ha_shared_dir }}/ssh/id_rsa" "$SSH_DIR/id_rsa"
echo "StrictHostKeyChecking no" >>"$SSH_DIR/config"
chmod 600 "$SSH_DIR/authorized_keys"
chmod 400 "$SSH_DIR/id_rsa"
chmod 700 "$SSH_DIR"
chown -R lsfadmin:lsfadmin "$SSH_DIR"

# Setup LSF environment variables
LSF_TOP="/opt/ibm/lsfsuite/lsf"
LSF_CONF="$LSF_TOP/conf"
LSF_WORK="$LSF_TOP/work"
LSF_CONF_FILE="$LSF_CONF/lsf.conf"
LSF_LOGS="/opt/ibm/lsflogs"
SHARED_HOSTS="/mnt/lsf/lsf/conf/hosts"
LSF_HOSTS_FILE="${LSF_CONF}/hosts"
SYSTEM_HOSTS_FILE="/etc/hosts"

# Create a logs folder
mkdir -p $LSF_LOGS
chown -R lsfadmin $LSF_LOGS
chown -R 755 $LSF_LOGS

# Append the line only if the exact search line is not already present
if ! grep -Fxq "search ${dns_domain}" /etc/resolv.conf; then
  echo "search ${dns_domain}" >>/etc/resolv.conf
  echo "Appended DNS entry: search ${dns_domain}" >>"$logfile"
else
  echo "DNS entry 'search ${dns_domain}' is already present." >>"$logfile"
fi

# Check if source file exists
if [[ -f "$SHARED_HOSTS" ]]; then
  cp -p "$SHARED_HOSTS" "$LSF_HOSTS_FILE"
  cp -p "$SHARED_HOSTS" "$SYSTEM_HOSTS_FILE"
else
  echo "Error: Source file '$SHARED_HOSTS' does not exist." >&2 >>"$logfile"
  exit 1
fi

# Apply system tuning parameters
LSF_TUNABLES="/etc/sysctl.conf"
{
  echo 'vm.overcommit_memory=1'
  echo 'net.core.rmem_max=26214400'
  echo 'net.core.rmem_default=26214400'
  echo 'net.core.wmem_max=26214400'
  echo 'net.core.wmem_default=26214400'
  echo 'net.ipv4.tcp_fin_timeout = 5'
  echo 'net.core.somaxconn = 8000'
} >>"$LSF_TUNABLES"
sudo sysctl -p $LSF_TUNABLES

# Defining ncpus based on hyper-threading
if [ "$hyperthreading" == "True" ]; then
  ego_define_ncpus="threads"
else
  ego_define_ncpus="cores"
  cat <<'EOT' >/root/lsf_hyperthreading
#!/bin/sh
for vcpu in $(cat /sys/devices/system/cpu/cpu*/topology/thread_siblings_list | cut -s -d- -f2 | cut -d- -f2 | uniq); do
    echo "0" > "/sys/devices/system/cpu/cpu"$vcpu"/online"
done
EOT
  chmod 755 /root/lsf_hyperthreading
  command="/root/lsf_hyperthreading"
  sh $command && (
    crontab -l 2>/dev/null
    echo "@reboot $command"
  ) | crontab -
fi
echo "EGO_DEFINE_NCPUS=${ego_define_ncpus}" >>$LSF_CONF_FILE

# Main Configuration for Dynamic Nodes
sed -i 's|^LSF_LOGDIR=.*|LSF_LOGDIR="/opt/ibm/lsflogs"|' $LSF_CONF_FILE
sed -i '/^lsfservers/d' "$LSF_CONF/lsf.cluster.$cluster_prefix"
grep -rli "$default_cluster_name" $LSF_CONF/* | xargs sed -i "s/$default_cluster_name/$cluster_prefix/g"
mv $LSF_WORK/$default_cluster_name $LSF_WORK/"$cluster_prefix"
find "$LSF_TOP" -name "*$default_cluster_name*" -print0 | while IFS= read -r -d '' file; do
  new_file=$(echo "$file" | sed -r "s/$default_cluster_name/$cluster_prefix/g")
  mv "$file" "$new_file"
done
grep -rli 'lsfservers' $LSF_CONF/* | xargs sed -i "s/lsfservers/${ManagementHostNames}/g"

cat <<EOF >>$LSF_CONF_FILE
LSF_SERVER_HOSTS="${ManagementHostNames}"
LSF_ADDON_HOSTS="$(echo "$ManagementHostNames" | awk '{print $1}')"
LSF_GET_CONF=lim
LSF_GPU_AUTOCONFIG=Y
LSB_GPU_NEW_SYNTAX=extend
EOF

# Support rc_account resource to enable RC_ACCOUNT policy
sed -i '$ a LSF_LOCAL_RESOURCES=\"[resource icgen2host]\"' $LSF_CONF_FILE
echo "Update LSF_LOCAL_RESOURCES lsf.conf successfully, add [resourcemap ${rc_account}*rc_account]" >> "$logfile"

# Support for multiprofiles for the Job submission
sed -i "s/\(LSF_LOCAL_RESOURCES=.*\)\"/\1 [resourcemap ${rc_account}*rc_account]\"/" $LSF_CONF_FILE
echo "update LSF_LOCAL_RESOURCES lsf.conf successfully, add [resourcemap ${pricing}*family]" >> "$logfile"

# Add additional local resources if needed
instance_id=$(dmidecode | grep Family | cut -d ' ' -f 2 |head -1)
if [ -n "$instance_id" ]; then
  sed -i "s/\(LSF_LOCAL_RESOURCES=.*\)\"/\1 [resourcemap ${instance_id}\*instanceID]\"/" "$LSF_CONF_FILE"
  echo "Update LSF_LOCAL_RESOURCES in $LSF_CONF_FILE successfully, add [resourcemap ${instance_id}*instanceID]" >> "$logfile"
else
  echo "Can not get instance ID" >> $logfile
fi

# source profile.lsf
echo "source ${LSF_CONF}/profile.lsf" >>~/.bashrc
echo "source ${LSF_CONF}/profile.lsf" >>"$LDAP_DIR"/.bashrc
source "$HOME/.bashrc"
source "$LDAP_DIR/.bashrc"

chown -R lsfadmin $LSF_TOP
chown -R lsfadmin $LSF_WORK

# Restart the lsfd servive
service lsfd stop && sleep 2 && service lsfd start
sleep 10

# Setting up the LDAP configuration
if [ "$enable_ldap" = "true" ]; then

  # Detect if the operating system is RHEL or Rocky Linux
  if grep -q "NAME=\"Red Hat Enterprise Linux\"" /etc/os-release || grep -q "NAME=\"Rocky Linux\"" /etc/os-release; then

    # Detect RHEL or Rocky version
    version=$(grep -oE 'release [0-9]+' /etc/redhat-release | awk '{print $2}')

    # Proceed if the detected version is either 8 or 9
    if [ "$version" == "8" ] || [ "$version" == "9" ]; then
      echo "Detected as RHEL or Rocky $version. Proceeding with LDAP client configuration..." >>$logfile

      # Enable password authentication for SSH by modifying the configuration file
      sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
      systemctl restart sshd

      # Check if the SSL certificate file exists, then copy it to the correct location
      # Retry finding SSL certificate with a maximum of 5 attempts and 5 seconds sleep between retries
      for attempt in {1..5}; do
        if [ -f "{{ ha_shared_dir }}/openldap/ldap_cacert.pem" ]; then
          echo "LDAP SSL cert found under {{ ha_shared_dir }}/openldap/ldap_cacert.pem path" >>$logfile
          mkdir -p /etc/openldap/certs/
          cp -pr "{{ ha_shared_dir }}/openldap/ldap_cacert.pem" "/etc/openldap/certs/ldap_cacert.pem"
          break
        else
          echo "SSL cert not found on attempt $attempt. Retrying in 5 seconds..." >>$logfile
          sleep 5
        fi
      done
      # Exit if the SSL certificate is still not found after 5 attempts
      [ -f "{{ ha_shared_dir }}/openldap/ldap_cacert.pem" ] || {
        echo "SSL cert not found after 5 attempts. Exiting." >>$logfile
        exit 1
      }

      # Create and configure the SSSD configuration file for LDAP integration
      cat <<EOF >/etc/sssd/sssd.conf
[sssd]
config_file_version = 2
services = nss, pam, autofs
domains = default

[nss]
homedir_substring = /home

[pam]

[domain/default]
id_provider = ldap
autofs_provider = ldap
auth_provider = ldap
chpass_provider = ldap
ldap_uri = ldap://${ldap_server}
ldap_search_base = dc=${ldap_basedns%%.*},dc=${ldap_basedns#*.}
ldap_id_use_start_tls = True
ldap_tls_cacertdir = /etc/openldap/certs
cache_credentials = True
ldap_tls_reqcert = allow
EOF

      # Secure the SSSD configuration file by setting appropriate permissions
      chmod 600 /etc/sssd/sssd.conf
      chown root:root /etc/sssd/sssd.conf

      # Create and configure the OpenLDAP configuration file for TLS
      cat <<EOF >/etc/openldap/ldap.conf
BASE dc=${ldap_basedns%%.*},dc=${ldap_basedns#*.}
URI ldap://${ldap_server}
TLS_CACERT /etc/openldap/certs/ldap_cacert.pem
TLS_CACERTDIR /etc/openldap/certs
EOF

      # Rehash certificates in the OpenLDAP directory to ensure proper recognition
      openssl rehash /etc/openldap/certs

      # Apply the SSSD and home directory creation configuration using authselect
      authselect select sssd with-mkhomedir --force

      # Enable and start the SSSD and oddjobd services for user authentication and home directory management
      systemctl enable --now sssd oddjobd

      # Restart both services to apply the configuration
      systemctl restart sssd oddjobd

      # Validate the LDAP configuration by performing a test search using ldapsearch
      if ldapsearch -x -H ldap://"${ldap_server}"/ -b "dc=${ldap_basedns%%.*},dc=${ldap_basedns#*.}" >/dev/null; then
        echo "LDAP configuration completed successfully!" >>$logfile
      else
        echo "LDAP configuration failed! Exiting." >>$logfile
        exit 1
      fi

      # Ensure LSF commands are available to all users by adding the profile to bashrc
      echo ". ${LSF_CONF}/profile.lsf" >>/etc/bashrc
      source /etc/bashrc

    else
      echo "This script is intended for RHEL and Rocky Linux 8 or 9. Detected version: $version. Exiting." >>$logfile
      exit 1
    fi
  fi
else
  echo "Skipping LDAP Client configuration as it is not enabled." >>$logfile
fi

# Setting up the Cloud Monitoring Agent
if [ "$cloud_monitoring_access_key" != "" ] && [ "$cloud_monitoring_ingestion_url" != "" ]; then

  SYSDIG_CONFIG_FILE="/opt/draios/etc/dragent.yaml"

  #packages installation
  echo "Writing sysdig config file" >>"$logfile"

  #sysdig config file
  echo "Setting customerid access key" >>"$logfile"
  sed -i "s/==ACCESSKEY==/$cloud_monitoring_access_key/g" $SYSDIG_CONFIG_FILE
  sed -i "s/==COLLECTOR==/$cloud_monitoring_ingestion_url/g" $SYSDIG_CONFIG_FILE
  echo "tags: type:compute,lsf:true" >>$SYSDIG_CONFIG_FILE
else
  echo "Skipping metrics agent configuration due to missing parameters" >>"$logfile"
fi

if [ "$observability_monitoring_on_compute_nodes_enable" = true ]; then

  echo "Restarting sysdig agent" >>"$logfile"
  systemctl enable dragent
  systemctl restart dragent
else
  echo "Metrics agent start skipped since monitoring provisioning is not enabled" >>"$logfile"
fi

# Setting up the IBM Cloud Logs
if [ "$observability_logs_enable_for_compute" = true ]; then

  echo "Configuring cloud logs for compute since observability logs for compute is enabled"
  sudo cp /root/post-config.sh /opt/ibm
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
  Path              /opt/ibm/lsflogs/*.log.*
  Path_Key          file
  Exclude_Path      /var/log/at/**
  DB                /opt/ibm/lsflogs/fluent-bit.DB
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

@INCLUDE output-logs-router-agent.conf
EOL

  sudo chmod +x post-config.sh
  sudo ./post-config.sh -h "$cloud_logs_ingress_private_endpoint" -p "3443" -t "/logs/v1/singles" -a IAMAPIKey -k "$VPC_APIKEY_VALUE" --send-directly-to-icl -s true -i Production
  echo "INFO Testing IBM Cloud LSF Logs from compute: $hostname" | sudo tee -a /opt/ibm/lsflogs/test.log.com >/dev/null
  sudo logger -u /tmp/in_syslog my_ident my_syslog_test_message_from_compute:"$hostname"
else
  echo "Cloud Logs configuration skipped since observability logs for compute is not enabled"
fi

echo "COMPLETED $(date '+%Y-%m-%d %H:%M:%S')" >>$logfile
