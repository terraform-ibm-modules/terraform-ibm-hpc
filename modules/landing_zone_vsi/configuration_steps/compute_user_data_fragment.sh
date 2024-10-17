#!/bin/bash
# shellcheck disable=all

if [ "$compute_user_data_vars_ok" != "1" ]; then
  echo 2>&1 "fatal: vars block is missing"
  exit 1
fi

echo "Logging initial env variables" >> $logfile
env|sort >> $logfile

# Disallow root login
sed -i -e "s/^/no-port-forwarding,no-agent-forwarding,no-X11-forwarding,command=\"echo \'Please login as the user \\\"lsfadmin or vpcuser\\\" rather than the user \\\"root\\\".\';echo;sleep 5; exit 142\" /" /root/.ssh/authorized_keys

# Updates the lsfadmin user as never expire
chage -I -1 -m 0 -M 99999 -E -1 -W 14 lsfadmin

# Setup Hostname
HostIP=$(hostname -I | awk '{print $1}')
hostname=${cluster_prefix}-${HostIP//./-}
hostnamectl set-hostname "$hostname"

echo "START $(date '+%Y-%m-%d %H:%M:%S')" >> $logfile

# Setup Network configuration
# Change the MTU setting as this is required for setting mtu as 9000 for communication to happen between clusters
if grep -q "NAME=\"Red Hat Enterprise Linux\"" /etc/os-release; then
    # Replace the MTU value in the Netplan configuration
    echo "MTU=9000" >> "/etc/sysconfig/network-scripts/ifcfg-${network_interface}"
    echo "DOMAIN=\"${dns_domain}\"" >> "/etc/sysconfig/network-scripts/ifcfg-${network_interface}"
    # Change the MTU setting as 9000 at router level.
    gateway_ip=$(ip route | grep default | awk '{print $3}' | head -n 1)
    cidr_range=$(ip route show | grep "kernel" | awk '{print $1}' | head -n 1)
    echo "$cidr_range via $gateway_ip dev ${network_interface} metric 0 mtu 9000" >> /etc/sysconfig/network-scripts/route-eth0
    # Restart the Network Manager.
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
        sudo sed -i '/'"$net_int"':/a\            mtu: 9000' $netplan_config
        sudo sed -i "/dhcp4: true/a \            nameservers:\n              search: [$dns_domain]" $netplan_config
        sudo sed -i '/'"$net_int"':/a\            routes:\n              - to: '"$cidr_range"'\n                via: '"$gateway_ip"'\n                metric: 100\n                mtu: 9000' $netplan_config
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
    chmod 777 "${client_path}"
    echo "${server_path} ${client_path} nfs rw,sec=sys,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,_netdev 0 0" >> /etc/fstab
  else
    echo "Mount not found for ${server_path} on ${client_path} after $retries attempts." >> $logfile
    rm -rf "${client_path}"
  fi

  # Convert success to numeric for return
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
  if mount_nfs_with_retries "${nfs_server_with_mount_path}" "${nfs_client_mount_path}"; then
    # Move stuff to shared fs
    for dir in conf work das_staging_area; do
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

# Setup Custom file shares
echo "Setting custom file shares." >> $logfile
if [ -n "${custom_file_shares}" ]; then
  echo "Custom file share ${custom_file_shares} found" >> $logfile
  file_share_array=(${custom_file_shares})
  mount_path_array=(${custom_mount_paths})
  length=${#file_share_array[@]}

  for (( i=0; i<length; i++ )); do
    mount_nfs_with_retries "${file_share_array[$i]}" "${mount_path_array[$i]}"
  done
fi
echo "Setting custom file shares is completed." >> $logfile

# Setup LSF environment variables
LSF_TOP="/opt/ibm/lsf_worker"
LSF_TOP_VERSION=10.1
LSF_CONF=$LSF_TOP/conf
LSF_CONF_FILE=$LSF_CONF/lsf.conf
LSF_HOSTS_FILE=$LSF_CONF/hosts
. $LSF_CONF/profile.lsf                       # WARNING: this may unset LSF_TOP and LSF_VERSION
echo "Logging env variables" >> $logfile
env | sort >> $logfile

# Defining ncpus based on hyper-threading
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
echo "EGO_DEFINE_NCPUS=${ego_define_ncpus}" >> $LSF_CONF_FILE

# Update lsf configuration
echo 'LSB_MC_DISABLE_HOST_LOOKUP=Y' >> $LSF_CONF_FILE
echo "LSF_RSH=\"ssh -o 'PasswordAuthentication no' -o 'StrictHostKeyChecking no'\"" >> $LSF_CONF_FILE
sed -i "s/LSF_SERVER_HOSTS=.*/LSF_SERVER_HOSTS=\"$ManagementHostNames\"/g" $LSF_CONF_FILE

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

# Setup ssh
lsfadmin_home_dir="/home/lsfadmin"
lsfadmin_ssh_dir="${lsfadmin_home_dir}/.ssh"
mkdir -p $lsfadmin_ssh_dir
if grep -q "NAME=\"Red Hat Enterprise Linux\"" /etc/os-release; then
  cp /home/vpcuser/.ssh/authorized_keys $lsfadmin_ssh_dir/authorized_keys
else
  cp /home/ubuntu/.ssh/authorized_keys "${lsfadmin_ssh_dir}/authorized_keys"
  sudo cp /home/ubuntu/.profile $lsfadmin_home_dir
fi
echo "${lsf_public_key}" >> $lsfadmin_ssh_dir/authorized_keys
echo "StrictHostKeyChecking no" >> $lsfadmin_ssh_dir/config
chmod 600 $lsfadmin_ssh_dir/authorized_keys
chmod 700 $lsfadmin_ssh_dir
chown -R lsfadmin:lsfadmin $lsfadmin_ssh_dir
echo "SSH key setup for lsfadmin user is completed" >> $logfile
echo "source ${LSF_CONF}/profile.lsf" >> $lsfadmin_home_dir/.bashrc
echo "source /opt/intel/oneapi/setvars.sh >> /dev/null" >> $lsfadmin_home_dir/.bashrc
echo "Setting up LSF env variables for lasfadmin user is completed" >> $logfile

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
cat /opt/ibm/lsf/conf/hosts >> /etc/hosts

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

#update lsf client ip address to LSF_HOSTS_FILE
echo "$login_ip_address $login_hostname" >> $LSF_HOSTS_FILE
# Startup lsf daemons
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

echo "END $(date '+%Y-%m-%d %H:%M:%S')" >> "$logfile"
