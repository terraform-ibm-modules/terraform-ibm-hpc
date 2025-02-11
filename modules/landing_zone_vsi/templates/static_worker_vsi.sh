#!/bin/sh
# shellcheck disable=all
###################################################
# Copyright (C) IBM Corp. 2021 All Rights Reserved.
# Licensed under the Apache License v2.0
###################################################

logfile="/tmp/worker_vsi.log"
echo "START $(date '+%Y-%m-%d %H:%M:%S')" >> "$logfile"

# Local variable declaration
nfs_server_with_mount_path=${mount_path}
enable_ldap="${enable_ldap}"
ldap_server_ip="${ldap_server_ip}"
base_dn="${ldap_basedns}"
cluster_name=${cluster_name}
HostIP=$(hostname -I | awk '{print $1}')
HostName=$(hostname)
#ManagementHostNames=""
#for (( i=1; i<=management_node_count; i++ ))
#do
#  ManagementHostNames+=" ${cluster_prefix}-mgmt-$i"
#done

mgmt_hostname_primary="$management_hostname"
mgmt_hostnames="${management_hostname},${management_cand_hostnames}"
mgmt_hostnames="${mgmt_hostnames//,/ }" # replace commas with spaces
mgmt_hostnames="${mgmt_hostnames# }" # remove an initial space
mgmt_hostnames="${mgmt_hostnames% }" # remove a final space

# Setup Network configuration
# Change the MTU setting as this is required for setting mtu as 9000 for communication to happen between clusters
if grep -q "NAME=\"Red Hat Enterprise Linux\"" /etc/os-release; then
    # Replace the MTU value in the Netplan configuration
    echo "MTU=9000" >> "/etc/sysconfig/network-scripts/ifcfg-${network_interface}"
    echo "DOMAIN=\"${dns_domain}\"" >> "/etc/sysconfig/network-scripts/ifcfg-${network_interface}"
    # Change the MTU setting as 9000 at router level.
    gateway_ip=$(ip route | grep default | awk '{print $3}' | head -n 1)
    echo "${rc_cidr_block} via $gateway_ip dev ${network_interface} metric 0 mtu 9000" >> /etc/sysconfig/network-scripts/route-eth0
    systemctl restart NetworkManager
elif grep -q "NAME=\"Ubuntu\"" /etc/os-release; then
    net_int=$(basename /sys/class/net/en*)
    netplan_config="/etc/netplan/50-cloud-init.yaml"
    gateway_ip=$(ip route | grep default | awk '{print $3}' | head -n 1)
    cidr_range=$(ip route show | grep "kernel" | awk '{print $1}' | head -n 1)
    usermod -s /bin/bash lsfadmin
    # Replace the MTU value in the Netplan configuration
    if ! grep -qE "^[[:space:]]*mtu: 9000" $netplan_config; then
        echo "MTU 9000 Packages entries not found"
        # Append the MTU configuration to the Netplan file
        sudo sed -i '/'$net_int':/a\            mtu: 9000' $netplan_config
        sudo sed -i '/dhcp4: true/a \            nameservers:\n              search: ['$dns_domain']' $netplan_config
        sudo sed -i '/'$net_int':/a\            routes:\n              - to: '$cidr_range'\n                via: '$gateway_ip'\n                metric: 100\n                mtu: 9000' $netplan_config
        sudo netplan apply
        echo "MTU set to 9000 on Netplan."
    else
        echo "MTU entry already exists in Netplan. Skipping."
    fi
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
    echo "${server_path} ${client_path} nfs rw,sec=sys,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,_netdev 0 0" >> /etc/fstab
  else
    echo "Mount not found for ${server_path} on ${client_path} after $retries attempts." >> $logfile
    rm -rf "${client_path}"
  fi

  if [ "$success" = true ]; then
    return 0
  else
    return 1
  fi
}

# Setup LSF share
if [ -n "${nfs_server_with_mount_path}" ]; then
  echo "File share ${nfs_server_with_mount_path} found" >> $logfile
  nfs_client_mount_path="/mnt/lsf"
  rm -rf /opt/ibm/lsf/conf/
  rm -rf /opt/ibm/lsf/work/
  if mount_nfs_with_retries "${nfs_server_with_mount_path}" "${nfs_client_mount_path}"; then
    # Move stuff to shared fs
    for dir in conf work; do
      mv "${LSF_TOP}/$dir" "${nfs_client_mount_path}"
      ln -fs "${nfs_client_mount_path}/$dir" "${LSF_TOP}/$dir"
    done
    chown -R lsfadmin:root "${LSF_TOP}"
  else
    echo "Mount not found for ${nfs_server_with_mount_path}, Exiting !!" >> $logfile
    exit 1
  fi
else
  echo "No NFS server mount path provided, Exiting !!" >> $logfile
  exit 1
fi
echo "Setting LSF share is completed." >> $logfile

# Setup Custom file shares
echo "Setting custom file shares." >> $logfile
if [ -n "${custom_file_shares}" ]; then
  echo "Custom file share ${custom_file_shares} found" >> $logfile
  file_share_array=(${custom_file_shares})
  mount_path_array=(${custom_mount_paths})
  length=${#file_share_array[@]}

  for (( i=0; i<length; i++ )); do
    mount_nfs_with_retries "${file_share_array[$i]}" "${mount_path_array[$i]}"
    chmod 777 "${mount_path_array[$i]}"
  done
fi
echo "Setting custom file shares is completed." >> $logfile

# Setup LSF environment variables
LSF_TOP="/opt/ibm/lsf_worker"
LSF_TOP_VERSION=10.1
LSF_CONF="$LSF_TOP/conf"
LSF_CONF_FILE="$LSF_CONF/lsf.conf"
LSF_HOSTS_FILE="/opt/ibm/lsf/conf/hosts"
. "$LSF_CONF/profile.lsf"
echo "Logging env variables" >> "$logfile"
env | sort >> "$logfile"

# Update lsf configuration
echo 'LSB_MC_DISABLE_HOST_LOOKUP=Y' >> $LSF_CONF_FILE
echo "LSF_RSH=\"ssh -o 'PasswordAuthentication no' -o 'StrictHostKeyChecking no'\"" >> $LSF_CONF_FILE
sed -i "s/LSF_SERVER_HOSTS=.*/LSF_SERVER_HOSTS=\"$mgmt_hostnames\"/g" $LSF_CONF_FILE

# Update the entry  to LSF_HOSTS_FILE
#sed -i "s/^$HostIP .*/$HostIP $HostName/g" /opt/ibm/lsf/conf/hosts
#if grep -q "^$HostIP" "$LSF_HOSTS_FILE"; then
#  sed -i "s/^$HostIP .*/$HostIP $HostName/g" "$LSF_HOSTS_FILE"
#else
#  echo "$HostIP $HostName" >> "$LSF_HOSTS_FILE"
#fi
#echo "$HostIP $HostName" >> "$LSF_HOSTS_FILE"

MAX_RETRIES=5
count=0

# Loop to attempt the update until successful or max retries reached
for ((i=1; i<=MAX_RETRIES; i++)); do
  # Attempt to update the entry
  sed -i "s/^$HostIP .*/$HostIP $HostName/g" "$LSF_HOSTS_FILE"

  # Validate if the update was successful
  if grep -q "^$HostIP $HostName" "$LSF_HOSTS_FILE"; then
    echo "Successfully updated $HostIP $HostName in $LSF_HOSTS_FILE."
    break
  else
    echo "Attempt $i: Update failed, retrying..."
    sleep 5
  fi

  # Check if max retries reached
  if [ "$i" -eq "$MAX_RETRIES" ]; then
    echo "Failed to update $HostIP $HostName in $LSF_HOSTS_FILE after $MAX_RETRIES attempts."
    exit 1
  fi
done

for hostname in $mgmt_hostnames; do
  while ! grep "$hostname" "/opt/ibm/lsf/conf/hosts"; do
    echo "Waiting for $hostname to be added to LSF host file" >> $logfile
    sleep 5
  done
done

# TODO: Understand usage
# Support rc_account resource to enable RC_ACCOUNT policy
if [ -n "${rc_account}" ]; then
  sed -i "s/\(LSF_LOCAL_RESOURCES=.*\)\"/\1 [resourcemap ${rc_account}*rc_account]\"/" $LSF_CONF_FILE
  echo "Update LSF_LOCAL_RESOURCES lsf.conf successfully, add [resourcemap ${rc_account}*rc_account]" >> $logfile
fi
# Support for multiprofiles for the Job submission
if [ -n "${family}" ]; then
  sed -i "s/\(LSF_LOCAL_RESOURCES=.*\)\"/\1 [resourcemap ${family}*family]\"/" $LSF_CONF_FILE
  echo "update LSF_LOCAL_RESOURCES lsf.conf successfully, add [resourcemap ${pricing}*family]" >> $logfile
fi
# Add additional local resources if needed
instance_id=$(dmidecode | grep Family | cut -d ' ' -f 2 |head -1)
if [ -n "$instance_id" ]; then
  sed -i "s/\(LSF_LOCAL_RESOURCES=.*\)\"/\1 [resourcemap $instance_id*instanceID]\"/" $LSF_CONF_FILE
  echo "Update LSF_LOCAL_RESOURCES in $LSF_CONF_FILE successfully, add [resourcemap ${instance_id}*instanceID]" >> $logfile
else
  echo "Can not get instance ID" >> $logfile
fi

# Defining ncpus based on hyper-threading
echo "$hyperthreading"
if [ "$hyperthreading" == true ]; then
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
echo "EGO_DEFINE_NCPUS=${ego_define_ncpus}" >> "$LSF_CONF_FILE"

#Update LSF Tuning on dynamic hosts
LSF_TUNABLES="etc/sysctl.conf"
echo 'vm.overcommit_memory=1' >> $LSF_TUNABLES
echo 'net.core.rmem_max=26214400' >> $LSF_TUNABLES
echo 'net.core.rmem_default=26214400' >> $LSF_TUNABLES
echo 'net.core.wmem_max=26214400' >> $LSF_TUNABLES
echo 'net.core.wmem_default=26214400' >> $LSF_TUNABLES
echo 'net.ipv4.tcp_fin_timeout = 5' >> $LSF_TUNABLES
echo 'net.core.somaxconn = 8000' >> $LSF_TUNABLES
sudo sysctl -p $LSF_TUNABLES

# Setup lsfadmin user
# Updates the lsfadmin user as never expire
chage -I -1 -m 0 -M 99999 -E -1 -W 14 lsfadmin
# Setup ssh
lsfadmin_home_dir="/home/lsfadmin"
lsfadmin_ssh_dir="${lsfadmin_home_dir}/.ssh"
mkdir -p ${lsfadmin_ssh_dir}
if grep -q "NAME=\"Red Hat Enterprise Linux\"" /etc/os-release; then
  sudo cp /home/vpcuser/.ssh/authorized_keys "${lsfadmin_ssh_dir}/authorized_keys"
else
  cp /home/ubuntu/.ssh/authorized_keys "${lsfadmin_ssh_dir}/authorized_keys"
  sudo cp /home/ubuntu/.profile /home/lsfadmin
fi
cp /home/vpcuser/.ssh/authorized_keys "${lsfadmin_ssh_dir}/authorized_keys"
echo "${cluster_public_key_content}" >> "${lsfadmin_ssh_dir}/authorized_keys"
echo "${cluster_private_key_content}" >> "${lsfadmin_ssh_dir}/id_rsa"
echo "StrictHostKeyChecking no" >> "${lsfadmin_ssh_dir}/config"
chmod 600 "${lsfadmin_ssh_dir}/authorized_keys"
chmod 600 "${lsfadmin_ssh_dir}/id_rsa"
chmod 700 ${lsfadmin_ssh_dir}
chown -R lsfadmin:lsfadmin ${lsfadmin_ssh_dir}
echo "SSH key setup for lsfadmin user is completed" >> $logfile

# Setup root user
root_ssh_dir="/root/.ssh"
echo "${cluster_public_key_content}" >> $root_ssh_dir/authorized_keys
echo "StrictHostKeyChecking no" >> $root_ssh_dir/config
echo "cluster ssh key has been added to root user" >> $logfile


# Create lsf.sudoers file to support single lsfstartup and lsfrestart command from management node
echo 'LSF_STARTUP_USERS="lsfadmin"' | sudo tee -a /etc/lsf1.sudoers
echo "LSF_STARTUP_PATH=$LSF_TOP_VERSION/linux3.10-glibc2.17-x86_64/etc/" | sudo tee -a /etc/lsf.sudoers
chmod 600 /etc/lsf.sudoers
ls -l /etc/lsf.sudoers

# Change LSF_CONF= value in lsf_daemons
cd /opt/ibm/lsf_worker/10.1/linux3.10-glibc2.17-x86_64/etc/
sed -i "s|/opt/ibm/lsf/|/opt/ibm/lsf_worker/|g" lsf_daemons
cd -

sudo ${LSF_TOP}/10.1/install/hostsetup --top="${LSF_TOP}" --setuid    ### WARNING: LSF_TOP may be unset here
echo "Added LSF administrators to start LSF daemons" >> $logfile

# Install LSF as a service and start up
/opt/ibm/lsf_worker/10.1/install/hostsetup --top="/opt/ibm/lsf_worker" --boot="y" --start="y" --dynamic 2>&1 >> $logfile
systemctl status lsfd
cat /opt/ibm/lsf/conf/hosts >> /etc/hosts

lsfadmin_home_dir="/home/lsfadmin"
echo "source ${LSF_CONF}/profile.lsf" >> /root/.bashrc
echo "source ${LSF_CONF}/profile.lsf" >> "${lsfadmin_home_dir}"/.bashrc

#
## Create lsf.sudoers file to support single lsfstartup and lsfrestart command from management node
#cat <<EOT > "/etc/lsf.sudoers"
#LSF_STARTUP_USERS="lsfadmin"
#LSF_STARTUP_PATH=$LSF_TOP_VERSION/linux3.10-glibc2.17-x86_64/etc/
#EOT
#chmod 600 /etc/lsf.sudoers
#ls -l /etc/lsf.sudoers
#
#$LSF_TOP_VERSION/install/hostsetup --top="$LSF_TOP" --setuid
#echo "Added LSF administrators to start LSF daemons"
#
#lsfadmin_home_dir="/home/lsfadmin"
#echo "source ${LSF_CONF}/profile.lsf" >> /root/.bashrc
#echo "source ${LSF_CONF}/profile.lsf" >> "${lsfadmin_home_dir}"/.bashrc
## Setup ssh
#
#
## Setup lsfadmin user
## Updates the lsfadmin user as never expire
#chage -I -1 -m 0 -M 99999 -E -1 -W 14 lsfadmin
## Setup ssh
#lsfadmin_home_dir="/home/lsfadmin"
#lsfadmin_ssh_dir="${lsfadmin_home_dir}/.ssh"
#mkdir -p ${lsfadmin_ssh_dir}
#if grep -q "NAME=\"Red Hat Enterprise Linux\"" /etc/os-release; then
#  sudo cp /home/vpcuser/.ssh/authorized_keys "${lsfadmin_ssh_dir}/authorized_keys"
#else
#  cp /home/ubuntu/.ssh/authorized_keys "${lsfadmin_ssh_dir}/authorized_keys"
#  sudo cp /home/ubuntu/.profile /home/lsfadmin
#fi
#cp /home/vpcuser/.ssh/authorized_keys "${lsfadmin_ssh_dir}/authorized_keys"
#echo "${cluster_public_key_content}" >> "${lsfadmin_ssh_dir}/authorized_keys"
#echo "${cluster_private_key_content}" >> "${lsfadmin_ssh_dir}/id_rsa"
#echo "StrictHostKeyChecking no" >> "${lsfadmin_ssh_dir}/config"
#chmod 600 "${lsfadmin_ssh_dir}/authorized_keys"
#chmod 600 "${lsfadmin_ssh_dir}/id_rsa"
#chmod 700 ${lsfadmin_ssh_dir}
#chown -R lsfadmin:lsfadmin ${lsfadmin_ssh_dir}
#echo "SSH key setup for lsfadmin user is completed" >> $logfile
#
## Setup root user
#root_ssh_dir="/root/.ssh"
#echo "${cluster_public_key_content}" >> $root_ssh_dir/authorized_keys
#echo "StrictHostKeyChecking no" >> $root_ssh_dir/config
#echo "cluster ssh key has been added to root user" >> $logfile
#
## Update LSF Tunables
#LSF_TUNABLES="/etc/sysctl.conf"
#echo "1" > /proc/sys/vm/overcommit_memory
#echo 'vm.overcommit_memory=1' > "$LSF_TUNABLES"
#echo 'net.core.rmem_max=26214400' >> "$LSF_TUNABLES"
#echo 'net.core.rmem_default=26214400' >> "$LSF_TUNABLES"
#echo 'net.core.wmem_max=26214400' >> "$LSF_TUNABLES"
#echo 'net.core.wmem_default=26214400' >> "$LSF_TUNABLES"
#echo 'net.ipv4.tcp_fin_timeout = 5' >> "$LSF_TUNABLES"
#echo 'net.core.somaxconn = 8000' >> "$LSF_TUNABLES"
#sysctl -p "$LSF_TUNABLES"
#
## Defining ncpus based on hyper-threading
#echo "$hyperthreading"
#if [ "$hyperthreading" == true ]; then
#  ego_define_ncpus="threads"
#else
#  ego_define_ncpus="cores"
#  cat << 'EOT' > /root/lsf_hyperthreading
##!/bin/sh
#for vcpu in $(cat /sys/devices/system/cpu/cpu*/topology/thread_siblings_list | cut -s -d- -f2 | cut -d- -f2 | uniq); do
#    echo "0" > "/sys/devices/system/cpu/cpu"$vcpu"/online"
#done
#EOT
#  chmod 755 /root/lsf_hyperthreading
#  command="/root/lsf_hyperthreading"
#  sh $command && (crontab -l 2>/dev/null; echo "@reboot $command") | crontab -
#fi
#echo "EGO_DEFINE_NCPUS=${ego_define_ncpus}" >> "$LSF_CONF_FILE"
#
## Update lsf configuration
#echo 'LSB_MC_DISABLE_HOST_LOOKUP=Y' >> "$LSF_CONF_FILE"
#sed -i "s/LSF_LOCAL_RESOURCES/#LSF_LOCAL_RESOURCES/"  "$LSF_CONF_FILE"
#echo "LSF_RSH=\"ssh -o 'PasswordAuthentication no' -o 'StrictHostKeyChecking no'\"" >> "$LSF_CONF_FILE"
##sed -i "s/LSF_SERVER_HOSTS=.*/LSF_SERVER_HOSTS=\"$ManagementHostNames\"/g" "$LSF_CONF_FILE"
#echo "LSF_SERVER_HOSTS=\"$mgmt_hostnames\"" >> "$LSF_CONF_FILE"
#
#cat << EOF > /etc/profile.d/lsf.sh
#ls /opt/ibm/lsf_worker/conf/lsf.conf > /dev/null 2> /dev/null < /dev/null &
##usleep 10000
#PID=\$!
#if kill -0 \$PID 2> /dev/null; then
#  # lsf.conf is not accessible
#  kill -KILL \$PID 2> /dev/null > /dev/null
#  wait \$PID
#else
#  source /opt/ibm/lsf_worker/conf/profile.lsf
#fi
#PATHs=\`echo "\$PATH" | sed -e 's/:/\n/g'\`
#for path in /usr/local/bin /usr/bin /usr/local/sbin /usr/sbin; do
#  PATHs=\`echo "\$PATHs" | grep -v \$path\`
#done
#export PATH=/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin:\`echo "\$PATHs" | paste -s -d :\`
#EOF
#
##sed -i "s/^$HostIP .*/$HostIP $HostName/g" /opt/ibm/lsf/conf/hosts
##for hostname in $mgmt_hostnames; do
##  while ! grep "$hostname" "$LSF_HOSTS_FILE"; do
##    echo "Waiting for $hostname to be added to LSF host file"
##    sleep 5
##  done
##  echo "$hostname found in LSF host file"
##done
##cat $LSF_HOSTS_FILE >> /etc/hosts
#
## Create lsf.sudoers file to support single lsfstartup and lsfrestart command from management node
## Create lsf.sudoers file to support single lsfstartup and lsfrestart command from management node
#echo 'LSF_STARTUP_USERS="lsfadmin"' | sudo tee -a /etc/lsf1.sudoers
#echo "LSF_STARTUP_PATH=$LSF_TOP_VERSION/linux3.10-glibc2.17-x86_64/etc/" | sudo tee -a /etc/lsf.sudoers
#chmod 600 /etc/lsf.sudoers
#ls -l /etc/lsf.sudoers
#
## Change LSF_CONF= value in lsf_daemons
#cd /opt/ibm/lsf_worker/10.1/linux3.10-glibc2.17-x86_64/etc/
#sed -i "s|/opt/ibm/lsf/|/opt/ibm/lsf_worker/|g" lsf_daemons
#cd -
#
#sudo /opt/ibm/lsf/10.1/install/hostsetup --top="${LSF_TOP}" --setuid    ### WARNING: LSF_TOP may be unset here
#echo "Added LSF administrators to start LSF daemons" >> $logfile
#
## Install LSF as a service and start up
#/opt/ibm/lsf_worker/10.1/install/hostsetup --top="/opt/ibm/lsf_worker" --boot="y" --start="y" --dynamic 2>&1 >> $logfile
#systemctl status lsfd
#cat /opt/ibm/lsf/conf/hosts >> /etc/hosts


# Setting up the LDAP configuration
# Setting up the LDAP configuration
if [ "$enable_ldap" = "true" ]; then

    # Detect if the operating system is RHEL or Rocky Linux
    if grep -q "NAME=\"Red Hat Enterprise Linux\"" /etc/os-release || grep -q "NAME=\"Rocky Linux\"" /etc/os-release; then

        # Detect RHEL or Rocky version
        version=$(grep -oE 'release [0-9]+' /etc/redhat-release | awk '{print $2}')

        # Proceed if the detected version is either 8 or 9
        if [ "$version" == "8" ] || [ "$version" == "9" ]; then
            echo "Detected as RHEL or Rocky $version. Proceeding with LDAP client configuration..." >> $logfile

            # Enable password authentication for SSH by modifying the configuration file
            sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
            systemctl restart sshd

            # Check if the SSL certificate file exists, then copy it to the correct location
            # Retry finding SSL certificate with a maximum of 5 attempts and 5 seconds sleep between retries
            for attempt in {1..5}; do
                if [ -f "/mnt/lsf/openldap/ldap_cacert.pem" ]; then
                    echo "LDAP SSL cert found under /mnt/lsf/openldap/ldap_cacert.pem path" >> $logfile
                    mkdir -p /etc/openldap/certs/
                    cp -pr /mnt/lsf/openldap/ldap_cacert.pem /etc/openldap/certs/ldap_cacert.pem
                    break
                else
                    echo "SSL cert not found on attempt $attempt. Retrying in 5 seconds..." >> $logfile
                    sleep 5
                fi
            done
            # Exit if the SSL certificate is still not found after 5 attempts
            [ -f "/mnt/lsf/openldap/ldap_cacert.pem" ] || { echo "SSL cert not found after 5 attempts. Exiting." >> $logfile; exit 1; }


            # Create and configure the SSSD configuration file for LDAP integration
            cat <<EOF > /etc/sssd/sssd.conf
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
ldap_uri = ldap://${ldap_server_ip}
ldap_search_base = dc=${base_dn%%.*},dc=${base_dn#*.}
ldap_id_use_start_tls = True
ldap_tls_cacertdir = /etc/openldap/certs
cache_credentials = True
ldap_tls_reqcert = allow
EOF

            # Secure the SSSD configuration file by setting appropriate permissions
            chmod 600 /etc/sssd/sssd.conf
            chown root:root /etc/sssd/sssd.conf

            # Create and configure the OpenLDAP configuration file for TLS
            cat <<EOF > /etc/openldap/ldap.conf
BASE dc=${base_dn%%.*},dc=${base_dn#*.}
URI ldap://${ldap_server_ip}
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
            if ldapsearch -x -H ldap://"${ldap_server_ip}"/ -b "dc=${base_dn%%.*},dc=${base_dn#*.}" > /dev/null; then
                echo "LDAP configuration completed successfully!" >> $logfile
            else
                echo "LDAP configuration failed! Exiting." >> $logfile
                exit 1
            fi

            # Ensure LSF commands are available to all users by adding the profile to bashrc
            echo ". ${LSF_CONF}/profile.lsf" >> /etc/bashrc
            source /etc/bashrc

        else
            echo "This script is intended for RHEL and Rocky Linux 8 or 9. Detected version: $version. Exiting." >> $logfile
            exit 1
        fi

    # Detect if the operating system is Ubuntu
    elif grep -q "NAME=\"Ubuntu\"" /etc/os-release; then
        # Log detected OS
        echo "Detected as Ubuntu. Proceeding with LDAP client configuration..." >> $logfile

        # Allow password authentication for SSH in two configuration files, then restart the SSH service
        sudo sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
        sudo sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config.d/50-cloudimg-settings.conf
        sudo systemctl restart ssh

        # Add configuration for automatic home directory creation to the PAM session configuration file
        sudo sed -i '$ i\session required pam_mkhomedir.so skel=/etc/skel umask=0022\' /etc/pam.d/common-session

        # Check if the SSL certificate file exists, then copy it to the correct location
        # Retry finding SSL certificate with a maximum of 5 attempts and 5 seconds sleep between retries
        for attempt in {1..5}; do
            if [ -f "/mnt/lsf/openldap/ldap_cacert.pem" ]; then
                mkdir -p /etc/ldap/certs/
                echo "LDAP SSL cert found under /mnt/lsf/openldap/ldap_cacert.pem path" >> $logfile
                cp -pr /mnt/lsf/openldap/ldap_cacert.pem /etc/ldap/certs/ldap_cacert.pem
                break
            else
                echo "SSL cert not found on attempt $attempt. Retrying in 5 seconds..." >> $logfile
                sleep 5
            fi
        done
        # Exit if the SSL certificate is still not found after 5 attempts
        [ -f "/mnt/lsf/openldap/ldap_cacert.pem" ] || { echo "SSL cert not found after 5 attempts. Exiting." >> $logfile; exit 1; }

        # Create and configure the SSSD configuration file for LDAP integration on Ubuntu
        cat <<EOF > /etc/sssd/sssd.conf
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
ldap_uri = ldap://${ldap_server_ip}
ldap_search_base = dc=${base_dn%%.*},dc=${base_dn#*.}
ldap_id_use_start_tls = True
ldap_tls_cacertdir = /etc/ldap/certs
cache_credentials = True
ldap_tls_reqcert = allow
EOF

        # Secure the SSSD configuration file by setting appropriate permissions
        sudo chmod 600 /etc/sssd/sssd.conf
        sudo chown root:root /etc/sssd/sssd.conf

        # Create and configure the OpenLDAP configuration file for TLS on Ubuntu
        cat <<EOF > /etc/ldap/ldap.conf
BASE dc=${base_dn%%.*},dc=${base_dn#*.}
URI ldap://${ldap_server_ip}
TLS_CACERT /etc/ldap/certs/ldap_cacert.pem
TLS_CACERTDIR /etc/ldap/certs
EOF

        # Rehash certificates in the OpenLDAP directory to ensure proper recognition
        openssl rehash /etc/ldap/certs

        # Enable and start the SSSD and oddjobd services for user authentication and home directory management
        sudo systemctl enable --now sssd oddjobd &&  sudo systemctl restart sssd oddjobd

        # Ensure LSF commands are available to all users by adding the profile to bash.bashrc
        echo ". ${LSF_CONF}/profile.lsf" >> /etc/bash.bashrc
        source /etc/bash.bashrc

        # Validate the LDAP configuration by checking the status of the SSSD service
        if sudo systemctl is-active --quiet sssd; then
            echo "LDAP client configuration completed successfully!" >> $logfile
        else
            echo "LDAP client configuration failed! Exiting." >> $logfile
            exit 1
        fi

    else
        echo "This script is designed for RHEL, Rocky Linux, or Ubuntu. Unsupported OS detected. Exiting." >> $logfile
        exit 1
    fi
fi

systemctl status lsfd >> "$logfile"

# Setting up the Metrics Agent

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
  cd /opt/ibm

  cat <<EOL > /etc/fluent-bit/fluent-bit.conf
[SERVICE]
  Flush                   1
  Log_Level               info
  Daemon                  off
  Parsers_File            parsers.conf
  Plugins_File            plugins.conf
  HTTP_Server             On
  HTTP_Listen             0.0.0.0
  HTTP_Port               9090
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
  Path              /opt/ibm/lsf_worker/log/*.log
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
  sudo ./post-config.sh -h $cloud_logs_ingress_private_endpoint -p "3443" -t "/logs/v1/singles" -a IAMAPIKey -k $VPC_APIKEY_VALUE --send-directly-to-icl -s true -i Production
  sudo echo "2024-10-16T14:31:16+0000 INFO Testing IBM Cloud LSF Logs from compute: $HostName" >> /opt/ibm/lsf_worker/log/test.log
  sudo logger -u /tmp/in_syslog my_ident my_syslog_test_message_from_compute:$HostName

else
  echo "Cloud Logs configuration skipped since observability logs for compute is not enabled"
fi

echo "END $(date '+%Y-%m-%d %H:%M:%S')" >> "$logfile"
