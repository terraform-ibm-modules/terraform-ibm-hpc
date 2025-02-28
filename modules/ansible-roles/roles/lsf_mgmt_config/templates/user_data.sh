#!/bin/bash

logfile="/tmp/user_data.log"
echo "START $(date '+%Y-%m-%d %H:%M:%S')" >> $logfile

# Initialize variables
cluster_prefix="{{ my_cluster_name }}"
nfs_server_with_mount_path="nfs server path"
custom_file_shares="custom file share"
custom_mount_paths="custom file share path"
hyperthreading="{{ enable_hyperthreading }}"
ManagementHostNames="{{ lsf_masters | join(',') }}"
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
  nfs_client_mount_path="/mnt/lsf"
  if mount_nfs_with_retries "${nfs_server_with_mount_path}" "${nfs_client_mount_path}"; then
    for dir in conf work; do
      rm -rf "${LSF_TOP}/$dir"
      ln -fs "${nfs_client_mount_path}/$dir" "${LSF_TOP}/$dir"
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
chmod 600 /home/lsfadmin/.ssh/authorized_keys
chmod 700 /home/lsfadmin/.ssh
chown -R lsfadmin:lsfadmin /home/lsfadmin/.ssh

# Setup LSF environment variables
LSF_CONF="/opt/ibm/lsf_worker/conf"
echo "source ${LSF_CONF}/profile.lsf" >> ~/.bashrc
source ~/.bashrc

# Define ncpus based on hyper-threading
if [ "$hyperthreading" == true ]; then
  ego_define_ncpus="threads"
else
  ego_define_ncpus="cores"
  for vcpu in $(cat /sys/devices/system/cpu/cpu*/topology/thread_siblings_list | cut -s -d- -f2 | uniq); do
    echo 0 > /sys/devices/system/cpu/cpu"$vcpu"/online
  done
fi
echo "EGO_DEFINE_NCPUS=${ego_define_ncpus}" >> $LSF_CONF/lsf.conf

# Apply system tuning parameters
echo 'vm.overcommit_memory=1' >> /etc/sysctl.conf
echo 'net.core.rmem_max=26214400' >> /etc/sysctl.conf
echo 'net.ipv4.tcp_fin_timeout=5' >> /etc/sysctl.conf
sysctl -p

echo "END $(date '+%Y-%m-%d %H:%M:%S')" >> $logfile