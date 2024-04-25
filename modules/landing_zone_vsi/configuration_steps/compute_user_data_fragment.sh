#!/bin/bash
# shellcheck disable=all

if [ "$compute_user_data_vars_ok" != "1" ]; then
  echo 2>&1 "fatal: vars block is missing"
  exit 1
fi

echo "Logging initial env variables" >> "$logfile"
env|sort >> "$logfile"

# Disallow root login
sed -i -e "s/^/no-port-forwarding,no-agent-forwarding,no-X11-forwarding,command=\"echo \'Please login as the user \\\"lsfadmin or vpcuser\\\" rather than the user \\\"root\\\".\';echo;sleep 5; exit 142\" /" /root/.ssh/authorized_keys

# Updates the lsfadmin user as never expire
chage -I -1 -m 0 -M 99999 -E -1 -W 14 lsfadmin

# Setup Hostname
HostIP=$(hostname -I | awk '{print $1}')
hostname=${cluster_prefix}-${HostIP//./-}
hostnamectl set-hostname "$hostname"

echo "START $(date '+%Y-%m-%d %H:%M:%S')" >> "$logfile"

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

# TODO: Conditional NFS mount
LSF_TOP="/opt/ibm/lsf"
# Setup file share
if [ -n "${nfs_server_with_mount_path}" ]; then
  echo "File share ${nfs_server_with_mount_path} found" >> "$logfile"
  nfs_client_mount_path="/mnt/lsf"
  rm -rf "${nfs_client_mount_path}"
  mkdir -p "${nfs_client_mount_path}"
  # Mount LSF TOP
  mount -t nfs4 -o sec=sys,vers=4.1 "$nfs_server_with_mount_path" "$nfs_client_mount_path" >> "$logfile"
  # Verify mount
  if mount | grep "$nfs_client_mount_path"; then
    echo "Mount found" >> "$logfile"
  else
    echo "No mount found, exiting!" >> "$logfile"
    exit 1
  fi
  # Update mount to fstab for automount
  echo "$nfs_server_with_mount_path $nfs_client_mount_path nfs rw,sec=sys,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,_netdev 0 0 " >> /etc/fstab
  for dir in conf work das_staging_area; do
    rm -rf "${LSF_TOP}/$dir" # this local data can go away
    ln -fs "${nfs_client_mount_path}/$dir" "${LSF_TOP}" # we link from shared fs
    chown -R lsfadmin:root "${LSF_TOP}"
  done
fi
echo "Setting LSF share is completed." >> "$logfile"

# Setup Custom file shares
echo "Setting custom file shares." >> "$logfile"
# Setup file share
if [ -n "${custom_file_shares}" ]; then
  echo "Custom file share ${custom_file_shares} found" >> "$logfile"
  file_share_array=(${custom_file_shares})
  mount_path_array=(${custom_mount_paths})
  length=${#file_share_array[@]}
  for (( i=0; i<length; i++ ))
  do
    rm -rf "${mount_path_array[$i]}"
    mkdir -p "${mount_path_array[$i]}"
    # Mount LSF TOP
    mount -t nfs4 -o sec=sys,vers=4.1 "${file_share_array[$i]}" "${mount_path_array[$i]}" >> "$logfile"
    # Verify mount
    if mount | grep "${file_share_array[$i]}"; then
      echo "Mount found" >> "$logfile"
    else
      echo "No mount found" >> "$logfile"
    fi
    # Update permission to 777 for all users to access
    chmod 777 "${mount_path_array[$i]}"
    # Update mount to fstab for automount
    echo "${file_share_array[$i]} ${mount_path_array[$i]} nfs rw,sec=sys,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,_netdev 0 0 " >> /etc/fstab
  done
fi
echo "Setting custom file shares is completed." >> "$logfile"

# Setup LSF environment variables
LSF_TOP="/opt/ibm/lsf_worker"
LSF_TOP_VERSION=10.1
LSF_CONF=$LSF_TOP/conf
LSF_CONF_FILE=$LSF_CONF/lsf.conf
LSF_HOSTS_FILE=$LSF_CONF/hosts
. $LSF_CONF/profile.lsf                       # WARNING: this may unset LSF_TOP and LSF_VERSION
echo "Logging env variables" >> "$logfile"
env | sort >> "$logfile"

# Defining ncpus based on hyper-threading
if [ "$hyperthreading" == true ]; then
  ego_define_ncpus="threads"
else
  ego_define_ncpus="cores"
  for vcpu in $(cat /sys/devices/system/cpu/cpu*/topology/thread_siblings_list | cut -s -d- -f2 | cut -d- -f2 | uniq); do
    echo 0 > /sys/devices/system/cpu/cpu"$vcpu"/online
  done
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
  echo "Update LSF_LOCAL_RESOURCES lsf.conf successfully, add [resourcemap ${rc_account}*rc_account]" >> "$logfile"
fi
# Support for multiprofiles for the Job submission
if [ -n "${family}" ]; then
  sed -i "s/\(LSF_LOCAL_RESOURCES=.*\)\"/\1 [resourcemap ${family}*family]\"/" $LSF_CONF_FILE
  echo "update LSF_LOCAL_RESOURCES lsf.conf successfully, add [resourcemap ${pricing}*family]" >> "$logfile"
fi
# Add additional local resources if needed
instance_id=$(dmidecode | grep Family | cut -d ' ' -f 2 |head -1)
if [ -n "$instance_id" ]; then
  sed -i "s/\(LSF_LOCAL_RESOURCES=.*\)\"/\1 [resourcemap $instance_id*instanceID]\"/" $LSF_CONF_FILE
  echo "Update LSF_LOCAL_RESOURCES in $LSF_CONF_FILE successfully, add [resourcemap ${instance_id}*instanceID]" >> "$logfile"
else
  echo "Can not get instance ID" >> "$logfile"
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
echo "SSH key setup for lsfadmin user is completed" >> "$logfile"
echo "source ${LSF_CONF}/profile.lsf" >> $lsfadmin_home_dir/.bashrc
echo "source /opt/intel/oneapi/setvars.sh >> /dev/null" >> $lsfadmin_home_dir/.bashrc
echo "Setting up LSF env variables for lasfadmin user is completed" >> "$logfile"

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
echo "Added LSF administrators to start LSF daemons" >> "$logfile"

# Install LSF as a service and start up
/opt/ibm/lsf_worker/10.1/install/hostsetup --top="/opt/ibm/lsf_worker" --boot="y" --start="y" --dynamic 2>&1 >> "$logfile"
cat /opt/ibm/lsf/conf/hosts >> /etc/hosts

# Setting up the LDAP configuration
if [ "$enable_ldap" = "true" ]; then

    # Detect the operating system
    if grep -q "NAME=\"Red Hat Enterprise Linux\"" /etc/os-release; then

        # Detect RHEL version
        rhel_version=$(grep -oE 'release [0-9]+' /etc/redhat-release | awk '{print $2}')

        if [ "$rhel_version" == "8" ]; then
            echo "Detected RHEL 8. Proceeding with LDAP client configuration...." >> "$logfile"

            # Allow Password authentication
            sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
            systemctl restart sshd

            # Configure LDAP authentication
            authconfig --enableldap --enableldapauth                         --ldapserver=ldap://"${ldap_server_ip}"                        --ldapbasedn="dc=${base_dn%%.*},dc=${base_dn#*.}"                         --enablemkhomedir --update

            # Check the exit status of the authconfig command
            if [ $? -eq 0 ]; then
                echo "LDAP Authentication enabled successfully." >> "$logfile"
            else
                echo "Failed to enable LDAP and LDAP Authentication." >> "$logfile"
                exit 1
            fi

            # Update LDAP Client configurations in nsswitch.conf
            sed -i -e 's/^passwd:.*$/passwd: files ldap/'                 -e 's/^shadow:.*$/shadow: files ldap/'                 -e 's/^group:.*$/group: files ldap/' /etc/nsswitch.conf # pragma: allowlist secret

            # Update PAM configuration files
            sed -i -e '/^auth/d' /etc/pam.d/password-auth
            sed -i -e '/^auth/d' /etc/pam.d/system-auth

            auth_line="\nauth        required      pam_env.so\nauth        sufficient    pam_unix.so nullok try_first_pass\nauth        requisite     pam_succeed_if.so uid >= 1000 quiet_success\nauth        sufficient    pam_ldap.so use_first_pass\nauth        required      pam_deny.so"

            echo -e "$auth_line" | tee -a /etc/pam.d/password-auth /etc/pam.d/system-auth

            # Copy 'password-auth' settings to 'sshd'
            cat /etc/pam.d/password-auth > /etc/pam.d/sshd

            # Configure nslcd
            cat <<EOF > /etc/nslcd.conf
uid nslcd
gid ldap
uri ldap://${ldap_server_ip}/
base dc=${base_dn%%.*},dc=${base_dn#*.}
EOF

            # Restart nslcd and nscd service
            systemctl restart nslcd
            systemctl restart nscd

            # Validate the LDAP configuration
            if ldapsearch -x -H ldap://"${ldap_server_ip}"/ -b "dc=${base_dn%%.*},dc=${base_dn#*.}" > /dev/null; then
                echo "LDAP configuration completed successfully !!" >> "$logfile"
            else
                echo "LDAP configuration failed !!" >> "$logfile"
                exit 1
            fi

            # Make LSF commands available for every user.
            echo ". ${LSF_CONF}/profile.lsf" >> /etc/bashrc
            source /etc/bashrc
        else
            echo "This script is designed for RHEL 8. Detected RHEL version: $rhel_version. Exiting." >> "$logfile"
            exit 1
        fi

    elif grep -q "NAME=\"Ubuntu\"" /etc/os-release; then

        echo "Detected as Ubuntu. Proceeding with LDAP client configuration..." >> "$logfile"

        # Update package repositories
        sudo apt update -y

        # Required LDAP client packages
        export UTILITYS="ldap-utils libpam-ldap libnss-ldap nscd nslcd"

        # Update SSH configuration to allow password authentication
        sudo sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
        sudo sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config.d/50-cloudimg-settings.conf
        sudo systemctl restart ssh

        # Create preseed file for LDAP configuration
        cat > debconf-ldap-preseed.txt <<EOF
ldap-auth-config    ldap-auth-config/ldapns/ldap-server    string    ${ldap_server_ip}
ldap-auth-config    ldap-auth-config/ldapns/base-dn    string     dc=${base_dn%%.*},dc=${base_dn#*.}
ldap-auth-config    ldap-auth-config/ldapns/ldap_version    select    3
ldap-auth-config    ldap-auth-config/dbrootlogin    boolean    false
ldap-auth-config    ldap-auth-config/dblogin    boolean    false
nslcd   nslcd/ldap-uris string  ${ldap_server_ip}
nslcd   nslcd/ldap-base string  dc=${base_dn%%.*},dc=${base_dn#*.}
EOF

        # Check if the preseed file exists
        if [ -f debconf-ldap-preseed.txt ]; then

            # Apply preseed selections
            cat debconf-ldap-preseed.txt | debconf-set-selections

            # Install LDAP client packages
            sudo apt-get install -y "${UTILITYS}"

            sleep 2

            # Add session configuration to create home directories
            sudo sed -i '$ i\session required pam_mkhomedir.so skel=/etc/skel umask=0022\' /etc/pam.d/common-session

            # Update nsswitch.conf
            sudo sed -i 's/^passwd:.*$/passwd: compat systemd ldap/' /etc/nsswitch.conf # pragma: allowlist secret
            sudo sed -i 's/^group:.*$/group: compat systemd ldap/' /etc/nsswitch.conf
            sudo sed -i 's/^shadow:.*$/shadow: compat/' /etc/nsswitch.conf

            # Update common-password PAM configuration
            sudo sed -i 's/pam_ldap.so use_authtok/pam_ldap.so/' /etc/pam.d/common-password

            # Make LSF commands available for every user.
            echo ". ${LSF_CONF}/profile.lsf" >> /etc/bash.bashrc
            source /etc/bash.bashrc

            # Restart nslcd and nscd service
            systemctl restart nslcd
            systemctl restart nscd

            # Enable nslcd and nscd service
            systemctl enable nslcd
            systemctl enable nscd

            # Validate the LDAP client service status
            if sudo systemctl is-active --quiet nscd; then
                echo "LDAP client configuration completed successfully !!"
            else
                echo "LDAP client configuration failed. nscd service is not running."
                exit 1
            fi
        else
            echo -e "debconf-ldap-preseed.txt Not found. Skipping LDAP client configuration."
        fi
    else
        echo "This script is designed for Ubuntu 22, and installation is not supported. Exiting." >> "$logfile"
    fi
fi


#update lsf client ip address to LSF_HOSTS_FILE
echo "$login_ip_address $login_hostname" >> $LSF_HOSTS_FILE
# Startup lsf daemons
systemctl status lsfd >> "$logfile"

# Setting up the Metrics Agent
if [ "$enable_compute_node_monitoring" = true ]; then

  if [ "$cloud_monitoring_access_key" != "" ] && [ "$cloud_monitoring_ingestion_url" != "" ]; then

    SYSDIG_CONFIG_FILE="/opt/draios/etc/dragent.yaml"

    #packages installation
    echo "Writing sysdig config file" >> "$logfile"

    #sysdig config file
    echo "Setting customerid access key" >> "$logfile"
    sed -i "s/==ACCESSKEY==/$cloud_monitoring_access_key/g" $SYSDIG_CONFIG_FILE
    sed -i "s/==COLLECTOR==/$cloud_monitoring_ingestion_url/g" $SYSDIG_CONFIG_FILE
    echo "tags: type:compute,lsf:true" >> $SYSDIG_CONFIG_FILE

    echo "Restarting sysdig agent" >> "$logfile"
    systemctl enable dragent
    systemctl restart dragent
  else
    echo "Skipping metrics agent configuration due to missing parameters" >> "$logfile"
  fi
  else
    echo "Metrics agent configuration skipped since monitoring provisioning is not enabled" >> "$logfile"
fi

echo "END $(date '+%Y-%m-%d %H:%M:%S')" >> "$logfile"
