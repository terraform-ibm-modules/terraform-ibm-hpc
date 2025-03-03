#!/bin/bash

logfile="/tmp/user_data.log"
echo "START $(date '+%Y-%m-%d %H:%M:%S')" >> $logfile

# Initialize variables
cluster_prefix="{{ my_cluster_name }}"
nfs_server_with_mount_path="{{ name_mount_path_map.lsf }}"
custom_file_shares="{% for key, value in name_mount_path_map.items() if key != 'lsf' %}{{ value }}{% if not loop.last %} {% endif %}{% endfor %}"
custom_mount_paths="{% for key in name_mount_path_map.keys() if key != 'lsf' %}{{ key }}{% if not loop.last %} {% endif %}{% endfor %}"
hyperthreading="{{ enable_hyperthreading }}"
ManagementHostNames="{{ lsf_masters | join(' ') }}"
rc_cidr_block="{{ compute_subnets_cidr | first }}"
dns_domain="{{ dns_domain_names }}"
network_interface="eth0"

# Setup Hostname
HostIP=$(hostname -I | awk '{print $1}')
hostname=${cluster_prefix}-${HostIP//./-}
hostnamectl set-hostname $hostname
systemctl stop firewalld
systemctl disable firewalld

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
  nfs_client_mount_path="/mnt/lsf/shared"
  if mount_nfs_with_retries "${nfs_server_with_mount_path}" "${nfs_client_mount_path}"; then
    for dir in conf work; do
      rm -rf "${LSF_TOP}/$dir"
      ln -fs "${nfs_client_mount_path}/lsf/$dir" "${LSF_TOP}/$dir"
    done
    chown -R lsfadmin:root "${LSF_TOP}"
  else
    echo "Mount not found for ${nfs_server_with_mount_path}, Exiting !!" >> $logfile
    exit 1
  fi
fi
echo "Setting LSF share is completed." >> $logfile

# Setup SSH
mkdir -p /home/lsfadmin/.ssh
cp /home/vpcuser/.ssh/authorized_keys /home/lsfadmin/.ssh/authorized_keys
cat /mnt/lsf/shared/ssh/id_rsa.pub >> /home/lsfadmin/.ssh/authorized_keys
cp /mnt/lsf/shared/ssh/id_rsa /home/lsfadmin/.ssh/id_rsa
echo "StrictHostKeyChecking no" >>  /home/lsfadmin/.ssh/config
chmod 600  /home/lsfadmin/.ssh/authorized_keys
chmod 400 /home/lsfadmin/.ssh/id_rsa
chmod 700  /home/lsfadmin/.ssh
chown -R lsfadmin:lsfadmin /home/lsfadmin/.ssh

# Setup LSF environment variables
LSF_TOP="/opt/ibm/lsf_worker"
LSF_TOP_VERSION=10.1
LSF_CONF=$LSF_TOP/conf
LSF_CONF_FILE=$LSF_CONF/lsf.conf
LSF_HOSTS_FILE=${LSF_CONF}/hosts
. $LSF_CONF/profile.lsf >> $logfile
echo "Logging env variables" >> $logfile
env >> $logfile
echo "source ${LSF_CONF}/profile.lsf" >> ~/.bashrc
source ~/.bashrc

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
echo 'vm.overcommit_memory=1' >> $LSF_TUNABLES
echo 'net.core.rmem_max=26214400' >> $LSF_TUNABLES
echo 'net.core.rmem_default=26214400' >> $LSF_TUNABLES
echo 'net.core.wmem_max=26214400' >> $LSF_TUNABLES
echo 'net.core.wmem_default=26214400' >> $LSF_TUNABLES
echo 'net.ipv4.tcp_fin_timeout = 5' >> $LSF_TUNABLES
echo 'net.core.somaxconn = 8000' >> $LSF_TUNABLES
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

cd /opt/ibm/lsf_worker/10.1/linux3.10-glibc2.17-x86_64/etc/
sed -i "s|/opt/ibm/lsf/|/opt/ibm/lsf_worker/|g" lsf_daemons
cd -

sudo /opt/ibm/lsf_worker/10.1/install/hostsetup --top="/opt/ibm/lsf_worker" --setuid >> $logfile
/opt/ibm/lsf_worker/10.1/install/hostsetup --top="/opt/ibm/lsf_worker" --boot="y" --start="y" --dynamic 2>&1 >> $logfile

echo "END $(date '+%Y-%m-%d %H:%M:%S')" >> $logfile