#!/bin/bash

logfile="/tmp/user_data.log"
echo "START $(date '+%Y-%m-%d %H:%M:%S')" >> $logfile

# Initialize variables
cluster_prefix="{{ my_cluster_name }}"
nfs_server_with_mount_path="{{ name_mount_path_map.lsf }}"
cloud_monitoring_access_key="{{ cloud_monitoring_access_key }}"
cloud_monitoring_ingestion_url="{{ cloud_monitoring_ingestion_url }}"
observability_monitoring_on_compute_nodes_enable="{{ monitoring_enable_for_compute }}"
observability_logs_enable_for_compute="{{ logs_enable_for_compute }}"
cloud_logs_ingress_private_endpoint="{{ cloud_logs_ingress_private_endpoint }}"
VPC_APIKEY_VALUE="{{ ibmcloud_api_key }}"
# custom_file_shares="{% for key, value in name_mount_path_map.items() if key != 'lsf' %}{{ value }}{% if not loop.last %} {% endif %}{% endfor %}"
# custom_mount_paths="{% for key in name_mount_path_map.keys() if key != 'lsf' %}{{ key }}{% if not loop.last %} {% endif %}{% endfor %}"
hyperthreading="{{ enable_hyperthreading }}"
ManagementHostNames="{{ lsf_masters | join(' ') }}"
# rc_cidr_block="{{ compute_subnets_cidr | first }}"
dns_domain="{{ dns_domain_names }}"
network_interface="eth0"

# Setup Hostname
HostIP=$(hostname -I | awk '{print $1}')
hostname=${cluster_prefix}-${HostIP//./-}
hostnamectl set-hostname "${hostname}"
systemctl stop firewalld
systemctl disable firewalld

# Setup vpcuser to login
if grep -E -q "CentOS|Red Hat" /etc/os-release
then
    USER=vpcuser
elif grep -q "Ubuntu" /etc/os-release
then
    USER=ubuntu
fi
sed -i -e "s/^/no-port-forwarding,no-agent-forwarding,no-X11-forwarding,command=\"echo \'Please login as the user \\\\\"$USER\\\\\" rather than the user \\\\\"root\\\\\".\';echo;sleep 5; exit 142\" /" /root/.ssh/authorized_keys

# Make lsfadmin and vpcuser set to newer expire
chage -I -1 -m 0 -M 99999 -E -1 -W 14 "${USER}"
chage -I -1 -m 0 -M 99999 -E -1 -W 14 lsfadmin

# Setup Network configuration
if grep -q "NAME=\"Red Hat Enterprise Linux" /etc/os-release; then
    echo "MTU=9000" >> "/etc/sysconfig/network-scripts/ifcfg-${network_interface}"
    echo "DOMAIN=${dns_domain}" >> "/etc/sysconfig/network-scripts/ifcfg-${network_interface}"
    gateway_ip=$(ip route | grep default | awk '{print $3}' | head -n 1)
    cidr_range=$(ip route show | grep "kernel" | awk '{print $1}' | head -n 1)
    echo "$cidr_range via $gateway_ip dev ${network_interface} metric 0 mtu 9000" >> /etc/sysconfig/network-scripts/route-${network_interface}
    systemctl restart NetworkManager
fi

# Setup VPC FileShare | NFS Mount
LSF_TOP="/opt/ibm/lsf"
echo "Initiating LSF share mount" >> $logfile

# Function to attempt NFS mount with retries
mount_nfs_with_retries() {
  local server_path=$1
  local client_path=$2
  local retries=5
  local success=false

  rm -rf "${client_path}"
  mkdir -p "${client_path}"

  for (( j=0; j<retries; j++ )); do
    mount -t nfs -o sec=sys "$server_path" "$client_path" -v >> $logfile
    if mount | grep -q "${client_path}"; then
      echo "Mount successful for ${server_path} on ${client_path}" >> $logfile
      success=true
      break
    else
      echo "Attempt $((j+1)) of $retries failed for ${server_path} on ${client_path}" >> $logfile
      sleep 2
    fi
  done

  if [ "$success" = true ]; then
    chmod 777 "${client_path}"
    echo "${server_path} ${client_path} nfs rw,sec=sys,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,_netdev 0 0" >> /etc/fstab
  else
    echo "Mount not found for ${server_path} on ${client_path} after $retries attempts." >> $logfile
    rm -rf "${client_path}"
  fi
}

# Setup LSF share
if [ -n "${nfs_server_with_mount_path}" ]; then
  echo "File share ${nfs_server_with_mount_path} found" >> $logfile
  nfs_client_mount_path="/mnt/lsf"
  if mount_nfs_with_retries "${nfs_server_with_mount_path}" "${nfs_client_mount_path}"; then
    for dir in conf work; do
      rm -rf "${LSF_TOP:?}/$dir"
      ln -fs "${nfs_client_mount_path}/shared/lsf/$dir" "${LSF_TOP}/$dir"
    done
    chown -R lsfadmin:root "${LSF_TOP}"
  else
    echo "Mount not found for ${nfs_server_with_mount_path}, Exiting !!" >> $logfile
    exit 1
  fi
fi
echo "Setting LSF share is completed." >> $logfile

# Setup SSH
SSH_DIR="/home/lsfadmin/.ssh"
mkdir -p "$SSH_DIR"
cp /home/vpcuser/.ssh/authorized_keys "$SSH_DIR/authorized_keys"
cat /mnt/lsf/shared/ssh/id_rsa.pub >> "$SSH_DIR/authorized_keys"
cp /mnt/lsf/shared/ssh/id_rsa "$SSH_DIR/id_rsa"
echo "StrictHostKeyChecking no" >> "$SSH_DIR/config"
chmod 600 "$SSH_DIR/authorized_keys"
chmod 400 "$SSH_DIR/id_rsa"
chmod 700 "$SSH_DIR"
chown -R lsfadmin:lsfadmin "$SSH_DIR"

# Setup LSF environment variables
LSF_TOP="/opt/ibm/lsf_worker"
LSF_TOP_VERSION=10.1
LSF_CONF=$LSF_TOP/conf
LSF_CONF_FILE=$LSF_CONF/lsf.conf
{
  . "$LSF_CONF/profile.lsf"
  echo "Logging environment variables"
  env
} >> "$logfile"
echo "source ${LSF_CONF}/profile.lsf" >> ~/.bashrc
source "$HOME/.bashrc"

# DNS Setup
echo "search ${dns_domain}" >> /etc/resolv.conf

# Defining ncpus based on hyper-threading
if [ "$hyperthreading" == "True" ]; then
  ego_define_ncpus="threads"
else
  ego_define_ncpus="cores"
  cat << 'EOT' > /root/lsf_hyperthreading
#!/bin/sh
for vcpu in $(cat /sys/devices/system/cpu/cpu*/topology/thread_siblings_list | cut -s -d- -f2 | cut -d- -f2 | uniq); do
    echo "0" > "/sys/devices/system/cpu/cpu"$vcpu"/online"
done
EOT
  chmod 755 /root/lsf_hyperthreading
  command="/root/lsf_hyperthreading"
  sh $command && (crontab -l 2>/dev/null; echo "@reboot $command") | crontab -
fi
echo "EGO_DEFINE_NCPUS=${ego_define_ncpus}" >> $LSF_CONF_FILE

cat /opt/ibm/lsf/conf/hosts >> /etc/hosts

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
} >> "$LSF_TUNABLES"
sudo sysctl -p $LSF_TUNABLES

# Update lsf configuration
echo 'LSB_MC_DISABLE_HOST_LOOKUP=Y' >> $LSF_CONF_FILE
echo "LSF_RSH=\"ssh -o 'PasswordAuthentication no' -o 'StrictHostKeyChecking no'\"" >> $LSF_CONF_FILE
sed -i "s/LSF_SERVER_HOSTS=.*/LSF_SERVER_HOSTS=\"$ManagementHostNames\"/g" $LSF_CONF_FILE
sed -i "s/LSF_ENABLE_EGO=N/LSF_ENABLE_EGO=Y/g" $LSF_CONF_FILE

# TODO: Understand usage
# Support rc_account resource to enable RC_ACCOUNT policy
if [ -n "${rc_account}" ]; then
sed -i "s/\(LSF_LOCAL_RESOURCES=.*\)\"/\1 [resourcemap ${rc_account}*rc_account]\"/" $LSF_CONF_FILE
echo "Update LSF_LOCAL_RESOURCES lsf.conf successfully, add [resourcemap ${rc_account}*rc_account]"
fi

# Add additional local resources if needed
instance_id=$(dmidecode | grep Family | cut -d ' ' -f 2 |head -1)
if [ -n "$instance_id" ]; then
  sed -i "s/\(LSF_LOCAL_RESOURCES=.*\)\"/\1 [resourcemap $instance_id*instanceID]\"/" $LSF_CONF_FILE
  echo "Update LSF_LOCAL_RESOURCES in $LSF_CONF_FILE successfully, add [resourcemap ${instance_id}*instanceID]"
else
  echo "Can not get instance ID" >> $logfile
fi

echo 'LSF_STARTUP_USERS="lsfadmin"' | sudo tee -a /etc/lsf1.sudoers
echo "LSF_STARTUP_PATH=$LSF_TOP_VERSION/linux3.10-glibc2.17-x86_64/etc/" | sudo tee -a /etc/lsf.sudoers
chmod 600 /etc/lsf.sudoers
ls -l /etc/lsf.sudoers

cd /opt/ibm/lsf_worker/10.1/linux3.10-glibc2.17-x86_64/etc/ || exit
sed -i "s|/opt/ibm/lsf/|/opt/ibm/lsf_worker/|g" lsf_daemons
cd - || exit

sudo /opt/ibm/lsf_worker/10.1/install/hostsetup --top="/opt/ibm/lsf_worker" --setuid | sudo tee -a "$logfile"
/opt/ibm/lsf_worker/10.1/install/hostsetup --top="/opt/ibm/lsf_worker" --boot="y" --start="y" --dynamic >> "$logfile" 2>&1

# Setting up the Cloud Monitoring Agent
if [ "$cloud_monitoring_access_key" != "" ] && [ "$cloud_monitoring_ingestion_url" != "" ]; then

    SYSDIG_CONFIG_FILE="/opt/draios/etc/dragent.yaml"

    #packages installation
    echo "Writing sysdig config file" >> "$logfile"

    #sysdig config file
    echo "Setting customerid access key" >> "$logfile"
    sed -i "s/==ACCESSKEY==/$cloud_monitoring_access_key/g" $SYSDIG_CONFIG_FILE
    sed -i "s/==COLLECTOR==/$cloud_monitoring_ingestion_url/g" $SYSDIG_CONFIG_FILE
    echo "tags: type:compute,lsf:true" >> $SYSDIG_CONFIG_FILE
else
    echo "Skipping metrics agent configuration due to missing parameters" >> "$logfile"
fi

if [ "$observability_monitoring_on_compute_nodes_enable" = true ]; then

    echo "Restarting sysdig agent" >> "$logfile"
    systemctl enable dragent
    systemctl restart dragent
  else
    echo "Metrics agent start skipped since monitoring provisioning is not enabled" >> "$logfile"
fi

# Setting up the IBM Cloud Logs
if [ "$observability_logs_enable_for_compute" = true ]; then

  echo "Configuring cloud logs for compute since observability logs for compute is enabled"
  sudo cp /root/post-config.sh /opt/ibm
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
  Path              /opt/ibm/lsf_worker/log/*.log.*
  Path_Key          file
  Exclude_Path      /var/log/at/**
  DB                /opt/ibm/lsf_worker/log/fluent-bit.DB
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
  echo "INFO Testing IBM Cloud LSF Logs from compute: $hostname" | sudo tee -a /opt/ibm/lsf_worker/log/test.log.com > /dev/null
  sudo logger -u /tmp/in_syslog my_ident my_syslog_test_message_from_compute:"$hostname"
else
  echo "Cloud Logs configuration skipped since observability logs for compute is not enabled"
fi

echo "END $(date '+%Y-%m-%d %H:%M:%S')" >> "$logfile"
