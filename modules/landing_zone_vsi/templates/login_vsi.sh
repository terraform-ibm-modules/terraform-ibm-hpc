#!/bin/sh
# shellcheck disable=all

###################################################
# Copyright (C) IBM Corp. 2023 All Rights Reserved.
# Licensed under the Apache License v2.0
###################################################

#variables

logfile="/tmp/user_data.log"

LSF_TOP="/opt/ibm/lsf"
LSF_CONF=$LSF_TOP/conf
LSF_HOSTS_FILE="/etc/hosts"

nfs_server_with_mount_path=${mount_path}
custom_mount_paths="${custom_mount_paths}"
custom_file_shares="${custom_file_shares}"

# Setup logs for user data
echo "START $(date '+%Y-%m-%d %H:%M:%S')" >> $logfile

# Disallow root login
sed -i -e "s/^/no-port-forwarding,no-agent-forwarding,no-X11-forwarding,command=\"echo \'Please login as the user \\\\\"lsfadmin or vpcuser\\\\\" rather than the user \\\\\"root\\\\\".\';echo;sleep 5; exit 142\" /" /root/.ssh/authorized_keys

# echo "DOMAIN=\"$dns_domain\"" >> "/etc/sysconfig/network-scripts/ifcfg-eth0"
echo "DOMAIN=\"$dns_domain\"" >> "/etc/sysconfig/network-scripts/ifcfg-${network_interface}"


# Setup lsfadmin user
# Updates the lsfadmin user as never expire
chage -I -1 -m 0 -M 99999 -E -1 -W 14 lsfadmin
# Setup ssh
lsfadmin_home_dir="/home/lsfadmin"
lsfadmin_ssh_dir="${lsfadmin_home_dir}/.ssh"
mkdir -p ${lsfadmin_ssh_dir}

# Change for RHEL / Ubuntu compute image.
if grep -q "NAME=\"Red Hat Enterprise Linux\"" /etc/os-release; then
  cp /home/vpcuser/.ssh/authorized_keys "${lsfadmin_ssh_dir}/authorized_keys"
elif grep -q "NAME=\"Ubuntu\"" /etc/os-release; then
  cp /home/ubuntu/.ssh/authorized_keys "${lsfadmin_ssh_dir}/authorized_keys"
  sudo cp /home/ubuntu/.profile "{$lsfadmin_home_dir}"
else
  echo "Provided OS distribution not match, provide either RHEL or Ubuntu" >> $logfile
fi

echo "${cluster_public_key_content}" >> "${lsfadmin_ssh_dir}/authorized_keys"
echo "${cluster_private_key_content}" >> "${lsfadmin_ssh_dir}/id_rsa"
echo "StrictHostKeyChecking no" >> "${lsfadmin_ssh_dir}/config"
chmod 600 "${lsfadmin_ssh_dir}/authorized_keys"
chmod 600 "${lsfadmin_ssh_dir}/id_rsa"
chmod 700 ${lsfadmin_ssh_dir}
chown -R lsfadmin:lsfadmin ${lsfadmin_ssh_dir}
echo "SSH key setup for lsfadmin user is completed" >> $logfile

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
        sudo sed -i '/'"$net_int"':/a\            mtu: 9000' $netplan_config
        sudo sed -i '/dhcp4: true/a \            nameservers:\n              search: ['"$dns_domain"']' $netplan_config
        sudo sed -i '/'"$net_int"':/a\            routes:\n              - to: '"$cidr_range"'\n                via: '"$gateway_ip"'\n                metric: 100\n                mtu: 9000' $netplan_config
        sudo netplan apply
        echo "MTU set to 9000 on Netplan."
    else
        echo "MTU entry already exists in Netplan. Skipping."
    fi
fi

# Setup root user
root_ssh_dir="/root/.ssh"
echo "${cluster_public_key_content}" >> $root_ssh_dir/authorized_keys
echo "StrictHostKeyChecking no" >> $root_ssh_dir/config
echo "cluster ssh key has been added to root user" >> $logfile

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
      ln -fs "${nfs_client_mount_path}/$dir" "${LSF_TOP}"
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

echo "source ${LSF_CONF}/profile.lsf" >> "${lsfadmin_home_dir}"/.bashrc
echo "source ${LSF_CONF}/profile.lsf" >> /root/.bashrc
echo "profile setup copy complete" >> $logfile

# Pause execution for 30 seconds
sleep 30

# Display the contents of /etc/resolv.conf before changes
echo "Contents of /etc/resolv.conf before changes:"
cat /etc/resolv.conf

# Display the updated contents of /etc/resolv.conf
echo "Contents of /etc/resolv.conf after changes:" >> $logfile
cat /etc/resolv.conf
#python3 -c "import ipaddress; print('\n'.join([str(ip) + ' ${cluster_prefix}-' + str(ip).replace('.', '-') for ip in ipaddress.IPv4Network('${rc_cidr_block_1}')]) + '\n' + '\n'.join([str(ip) + ' ${cluster_prefix}-' + str(ip).replace('.', '-') for ip in ipaddress.IPv4Network('${rc_cidr_block_2}')]))" >> "$LSF_HOSTS_FILE"

#Hostname resolution - login node to management nodes
echo "Pausing for 300 seconds to configure hostname name resolution..." >> $logfile
sleep 300
ls /mnt/lsf
ls -ltr /mnt/lsf
cp /mnt/lsf/conf/hosts /etc/hosts

# Ldap Configuration:
enable_ldap="${enable_ldap}"
ldap_server_ip="${ldap_server_ip}"
base_dn="${ldap_basedns}"

# Setting up the LDAP configuration
if [ "$enable_ldap" = "true" ]; then

    # Detect if the operating system is RHEL or Rocky Linux
    if grep -q "NAME=\"Red Hat Enterprise Linux\"" /etc/os-release || grep -q "NAME=\"Rocky Linux\"" /etc/os-release; then

        # Extract and store the major version of the operating system (8 or 9)
        version=$(grep -oE 'release [0-9]+' /etc/redhat-release | awk '{print $2}')

        # Proceed if the detected version is either 8 or 9
        if [ "$version" == "8" ] || [ "$version" == "9" ]; then
            echo "Detected as RHEL or Rocky $version. Proceeding with LDAP client configuration..." >> $logfile

            # Enable password authentication for SSH by modifying the configuration file
            sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
            systemctl restart sshd

            # Check if the SSL certificate file exists, then copy it to the correct location
            # Retry finding SSL certificate with a maximum of 100 attempts and 5 seconds sleep between retries
            for attempt in {1..100}; do
                if [ -f "/mnt/lsf/openldap/ldap_cacert.pem" ]; then
                    echo "LDAP SSL cert found under /mnt/lsf/openldap/ldap_cacert.pem path" >> $logfile
                    mkdir -p /etc/openldap/certs
                    cp -pr /mnt/lsf/openldap/ldap_cacert.pem /etc/openldap/certs/ldap_cacert.pem
                    break
                else
                    echo "SSL cert not found on attempt $attempt. Retrying in 5 seconds..." >> $logfile
                    sleep 5
                fi
            done
            # Exit if the SSL certificate is still not found after 100 attempts
            [ -f "/mnt/lsf/openldap/ldap_cacert.pem" ] || { echo "SSL cert not found after 100 attempts. Exiting." >> $logfile; exit 1; }

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
            echo "Restarting OpenLDAP SSSD service." >> $logfile
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

        echo "Detected as Ubuntu. Proceeding with LDAP client configuration..." >> $logfile

        # Allow password authentication for SSH in two configuration files, then restart the SSH service
        sudo sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
        sudo sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config.d/50-cloudimg-settings.conf
        sudo systemctl restart ssh

        # Add configuration for automatic home directory creation to the PAM session configuration file
        sudo sed -i '$ i\session required pam_mkhomedir.so skel=/etc/skel umask=0022\' /etc/pam.d/common-session

        # Check if the SSL certificate file exists, then copy it to the correct location
        # Retry finding SSL certificate with a maximum of 100 attempts and 5 seconds sleep between retries
        for attempt in {1..100}; do
            if [ -f "/mnt/lsf/openldap/ldap_cacert.pem" ]; then
                echo "LDAP SSL cert found under /mnt/lsf/openldap/ldap_cacert.pem path" >> $logfile
                mkdir -p /etc/ldap/certs
                cp -pr /mnt/lsf/openldap/ldap_cacert.pem /etc/ldap/certs/ldap_cacert.pem
                break
            else
                echo "SSL cert not found on attempt $attempt. Retrying in 5 seconds..." >> $logfile
                sleep 5
            fi
        done
        # Exit if the SSL certificate is still not found after 100 attempts
        [ -f "/mnt/lsf/openldap/ldap_cacert.pem" ] || { echo "SSL cert not found after 100 attempts. Exiting." >> $logfile; exit 1; }

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
        echo "Restarting OpenLDAP SSSD service." >> $logfile
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
