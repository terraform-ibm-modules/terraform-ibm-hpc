#!/bin/sh
###################################################
# Copyright (C) IBM Corp. 2023 All Rights Reserved.
# Licensed under the Apache License v2.0
###################################################

# Useful variables that reference the main GUI and PERF Manager folders.
LSF_SUITE_TOP="/opt/ibm/lsfsuite"
LSF_SUITE_GUI="${LSF_SUITE_TOP}/ext/gui"
LSF_SUITE_GUI_CONF="${LSF_SUITE_GUI}/conf"
LSF_SUITE_PERF="${LSF_SUITE_TOP}/ext/perf"
LSF_SUITE_PERF_CONF="${LSF_SUITE_PERF}/conf"
LSF_SUITE_PERF_BIN="${LSF_SUITE_PERF}/1.2/bin"

db_certificate_file=${LSF_SUITE_GUI_CONF}/cert.pem

# Function that dump the ICD certificate in the $db_certificate_file
create_certificate() {
    # Dump the CA certificate in the ${db_certificate_file} file and set permissions
    echo ${db_certificate} | base64 -d > ${db_certificate_file}
    chown lsfadmin:lsfadmin ${db_certificate_file}
    chmod 644 ${db_certificate_file}

}

# Configures the GUI JDBC datasource file ${LSF_SUITE_PERF_CONF}/datasource.xml
# to reference the IBM Cloud Database (ICD) instance. If ${enable_app_center} and
# ${enable_high_availability} are both true, updates the connection string to
# point to the remote database service instead of the local MySQL server.
configure_icd_datasource() {
    local default_connection_string="jdbc:mariadb://localhost:3306/pac?useUnicode=true&amp;characterEncoding=UTF-8&amp;serverTimezone=GMT"
    local icd_connection_string="jdbc:mariadb://${db_hostname}:${db_port}/pac?useUnicode=true\&amp;characterEncoding=UTF-8\&amp;serverTimezone=GMT\&amp;requireSSL=true\&amp;useSSL=true\&amp;serverSslCert=${db_certificate_file}"

    # Change the connection string to use ICD
    sed -i "s!Connection=\"${default_connection_string}\"!Connection=\"${icd_connection_string}\"!" ${LSF_SUITE_PERF_CONF}/datasource.xml
    # Change the connection string to use ICD
    sed -i "s!Connection=\"${default_connection_string}\"!Connection=\"${icd_connection_string}\"!" ${LSF_SUITE_PERF_CONF}/datasource.xml
    # Change the Cipher algorithm to AES128 in the Datasource definition
    sed -i "s|Cipher=\".*\"|Cipher=\"aes128\"|" ${LSF_SUITE_PERF_CONF}/datasource.xml
    # Encrypt the Database user and password with AES128 Cipher. The encryptTool.sh script requires the setting of the JAVA_HOME
    db_user_aes128=$(source /opt/ibm/lsfsuite/ext/profile.platform; ${LSF_SUITE_PERF_BIN}/encryptTool.sh "${db_user}")
    db_password_aes128=$(source /opt/ibm/lsfsuite/ext/profile.platform; ${LSF_SUITE_PERF_BIN}/encryptTool.sh "${db_password}")
    # Change the username password in the Datasource definition
    sed -i "s|UserName=\".*\"|UserName=\"${db_user_aes128}\"|" ${LSF_SUITE_PERF_CONF}/datasource.xml
    sed -i "s|Password=\".*\"|Password=\"${db_password_aes128}\"|" ${LSF_SUITE_PERF_CONF}/datasource.xml
}

# Local variable declaration
logfile="/tmp/user_data.log"
nfs_server_with_mount_path=${mount_path}
HostIP=$(hostname -I | awk '{print $1}')
HostName=$(hostname)
enable_ldap="${enable_ldap}"
ldap_server_ip="${ldap_server_ip}"
base_dn="${ldap_basedns}"
ManagementHostNames=""
for (( i=1; i<=management_node_count; i++ ))
do
  ManagementHostNames+=" ${cluster_prefix}-mgmt-$i-001"
done
# Space at the beginning of the list must be removed, otherwise the Application Center WEBUI doesn't work 
# properly in HA. In fact, if LSF_ADDON_HOSTS property has the list of the nodes with a space at the beginning
# the PAC - LSF interaction has issues.
ManagementHostNames=${ManagementHostNames# }
LSF_TOP="/opt/ibm/lsf"
LSF_CONF="$LSF_TOP/conf"
LSF_HOSTS_FILE="$LSF_CONF/hosts"
LSF_TOP_VERSION="$LSF_TOP/10.1"

# Setup logs for user data
echo "START $(date '+%Y-%m-%d %H:%M:%S')" >> $logfile

# Disallow root login
sed -i -e "s/^/no-port-forwarding,no-agent-forwarding,no-X11-forwarding,command=\"echo \'Please login as the user \\\\\"lsfadmin or vpcuser\\\\\" rather than the user \\\\\"root\\\\\".\';echo;sleep 5; exit 142\" /" /root/.ssh/authorized_keys

# Setup Network configuration
# Change the MTU setting as this is required for setting mtu as 9000 for communication to happen between clusters
echo "MTU=9000" >> "/etc/sysconfig/network-scripts/ifcfg-${network_interface}"
echo "DOMAIN=\"$dns_domain\"" >> "/etc/sysconfig/network-scripts/ifcfg-${network_interface}"

# Change the MTU setting as 9000 at router level.
gateway_ip=$(ip route | grep default | awk '{print $3}' | head -n 1)
echo "${rc_cidr_block} via $gateway_ip dev ${network_interface} metric 0 mtu 9000" >> /etc/sysconfig/network-scripts/route-eth0

systemctl restart NetworkManager

echo 1 > /proc/sys/vm/overcommit_memory # tt reports many failures of memory allocation at fork(). why?
echo 'vm.overcommit_memory=1' > /etc/sysctl.conf
echo 'net.core.rmem_max=26214400' >> /etc/sysctl.conf
echo 'net.core.rmem_default=26214400' >> /etc/sysctl.conf
echo 'net.core.wmem_max=26214400' >> /etc/sysctl.conf
echo 'net.core.wmem_default=26214400' >> /etc/sysctl.conf
echo 'net.ipv4.tcp_fin_timeout = 5' >> /etc/sysctl.conf
echo 'net.core.somaxconn = 8000' >> /etc/sysctl.conf
sudo sysctl -p /etc/sysctl.conf

if [ ! "$hyperthreading" == true ]; then
  for vcpu in $(cat /sys/devices/system/cpu/cpu*/topology/thread_siblings_list | cut -s -d- -f2 | cut -d- -f2 | uniq); do
    echo 0 > /sys/devices/system/cpu/cpu"$vcpu"/online
  done
fi

# Setup LSF
echo "Setting LSF configuration is completed." >> $logfile
echo "Setting LSF share" >> $logfile
# Setup file share
if [ -n "${nfs_server_with_mount_path}" ]; then
  echo "File share ${nfs_server_with_mount_path} found" >> $logfile
  nfs_client_mount_path="/mnt/lsf"
  rm -rf "${nfs_client_mount_path}"
  mkdir -p "${nfs_client_mount_path}"
  # Mount LSF TOP
  mount -t nfs4 -o sec=sys,vers=4.1 "$nfs_server_with_mount_path" "$nfs_client_mount_path" >> $logfile
  # Verify mount
  if mount | grep "$nfs_client_mount_path"; then
    echo "Mount found" >> $logfile
  else
    echo "No mount found, exiting!" >> $logfile
    exit 1
  fi
  # Update mount to fstab for automount
  echo "$nfs_server_with_mount_path $nfs_client_mount_path nfs rw,sec=sys,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,_netdev 0 0 " >> /etc/fstab
  for dir in conf work das_staging_area; do
    rm -rf "${LSF_TOP}/$dir"
    ln -fs "${nfs_client_mount_path}/$dir" "${LSF_TOP}"
    chown -R lsfadmin:root "${LSF_TOP}"
  done
else
  echo "No mount point value found, exiting!" >> $logfile
  exit 1
fi
echo "Setting LSF share is completed." >> $logfile

# Setup Custom file shares
echo "Setting custom file shares." >> $logfile
# Setup file share
if [ -n "${custom_file_shares}" ]; then
  echo "Custom file share ${custom_file_shares} found" >> $logfile
  file_share_array=(${custom_file_shares})
  mount_path_array=(${custom_mount_paths})
  length=${#file_share_array[@]}
  for (( i=0; i<length; i++ ))
  do
    rm -rf "${mount_path_array[$i]}"
    mkdir -p "${mount_path_array[$i]}"
    # Mount LSF TOP
    mount -t nfs4 -o sec=sys,vers=4.1 "${file_share_array[$i]}" "${mount_path_array[$i]}" >> $logfile
    # Verify mount
    if mount | grep "${file_share_array[$i]}"; then
      echo "Mount found" >> $logfile
    else
      echo "No mount found" >> $logfile
    fi
    # Update permission to 777 for all users to access
    chmod 777 ${mount_path_array[$i]}
    # Update mount to fstab for automount
    echo "${file_share_array[$i]} ${mount_path_array[$i]} nfs rw,sec=sys,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,_netdev 0 0 " >> /etc/fstab
  done
fi
echo "Setting custom file shares is completed." >> $logfile

# Setup password less SSH
while [ ! -f  "$LSF_HOSTS_FILE" ]; do
  echo "Waiting for cluster configuration created by management node to be shared." >> $logfile
  sleep 5s
done

# Update the entry  to LSF_HOSTS_FILE
sed -i "s/^$HostIP .*/$HostIP $HostName/g" $LSF_HOSTS_FILE
for hostname in $ManagementHostNames; do
  while ! grep "$hostname" "$LSF_HOSTS_FILE"; do
    echo "Waiting for $hostname to be added to LSF host file" >> $logfile
    sleep 5
  done
done
cat $LSF_HOSTS_FILE >> /etc/hosts
# Startup lsf daemons
. $LSF_TOP/conf/profile.lsf
echo "Setting up LSF env is completed" >> $logfile
lsf_daemons start &
sleep 5
lsf_daemons status >> $logfile
echo "END $(date '+%Y-%m-%d %H:%M:%S')" >> $logfile

# Setup lsfadmin user
# Updates the lsfadmin user as never expire
chage -I -1 -m 0 -M 99999 -E -1 -W 14 lsfadmin
# Setup ssh
lsfadmin_home_dir="/home/lsfadmin"
lsfadmin_ssh_dir="${lsfadmin_home_dir}/.ssh"
mkdir -p ${lsfadmin_ssh_dir}
cp /home/vpcuser/.ssh/authorized_keys "${lsfadmin_ssh_dir}/authorized_keys"
echo "${cluster_public_key_content}" >> "${lsfadmin_ssh_dir}/authorized_keys"
echo "${cluster_private_key_content}" >> "${lsfadmin_ssh_dir}/id_rsa"
echo "StrictHostKeyChecking no" >> "${lsfadmin_ssh_dir}/config"
chmod 600 "${lsfadmin_ssh_dir}/authorized_keys"
chmod 600 "${lsfadmin_ssh_dir}/id_rsa"
chmod 700 ${lsfadmin_ssh_dir}
chown -R lsfadmin:lsfadmin ${lsfadmin_ssh_dir}
echo "SSH key setup for lsfadmin user is completed" >> $logfile
echo "source ${LSF_CONF}/profile.lsf" >> "${lsfadmin_home_dir}"/.bashrc

# Setup root user
root_ssh_dir="/root/.ssh"
echo "${cluster_public_key_content}" >> $root_ssh_dir/authorized_keys
echo "StrictHostKeyChecking no" >> $root_ssh_dir/config
echo "cluster ssh key has been added to root user" >> $logfile
echo "source ${LSF_CONF}/profile.lsf" >> /root/.bashrc

# Create lsf.sudoers file to support single lsfstartup and lsfrestart command from management node
cat <<EOT > "/etc/lsf.sudoers"
LSF_STARTUP_USERS="lsfadmin"
LSF_STARTUP_PATH=$LSF_TOP_VERSION/linux3.10-glibc2.17-x86_64/etc/
EOT
chmod 600 /etc/lsf.sudoers
ls -l /etc/lsf.sudoers
sudo /opt/ibm/lsf/10.1/install/hostsetup --top="/opt/ibm/lsf/" --setuid
echo "Added LSF administrators to start LSF daemons" >> $logfile

# Setting up the Application Center
if [ "$enable_app_center" = true ] && [ "${enable_high_availability}" = true ];
then
    if rpm -q lsf-appcenter
    then
        echo "Application center packages are found..." >> $logfile
        echo ${app_center_gui_pwd} | sudo passwd --stdin lsfadmin
        sed -i '$i\\ALLOW_EVENT_TYPE=JOB_NEW JOB_STATUS JOB_FINISH2 JOB_START JOB_EXECUTE JOB_EXT_MSG JOB_SIGNAL JOB_REQUEUE JOB_MODIFY2 JOB_SWITCH METRIC_LOG' $LSF_ENVDIR/lsbatch/"$cluster_name"/configdir/lsb.params
        sed -i 's/NEWJOB_REFRESH=y/NEWJOB_REFRESH=Y/g' $LSF_ENVDIR/lsbatch/"$cluster_name"/configdir/lsb.params
        sed -i 's/NoVNCProxyHost=.*/NoVNCProxyHost=localhost/g' /opt/ibm/lsfsuite/ext/gui/conf/pmc.conf
        create_certificate
        configure_icd_datasource
        echo 'source /opt/ibm/lsfsuite/ext/profile.platform' >> ~/.bashrc
        echo 'source /opt/ibm/lsfsuite/ext/profile.platform' >> "${lsfadmin_home_dir}"/.bashrc
        source ~/.bashrc
        sudo rm -rf /opt/ibm/lsfsuite/ext/gui/3.0/bin/novnc.pem
        perfadmin start all; sleep 5;  pmcadmin stop; sleep 160; pmcadmin start; sleep 5; pmcadmin list >> $logfile
        appcenter_status=$(pmcadmin list | grep "WEBGUI" | awk '{print $2}')
        if [ "$appcenter_status" = "STARTED" ]; then
            echo "Application Center installation completed..." >> $logfile
        else
            echo "Application Center installation failed..." >> $logfile
        fi
    fi
else
	  echo 'Application Center installation skipped...' >> $logfile
fi

# TODO: Understand how lsf should work after reboot, need better cron job
if [ "$enable_app_center" = "true" ] && [ "${enable_high_availability}" = "true" ]; then 
    (crontab -l 2>/dev/null; echo "@reboot sleep 30 && source ~/.bashrc && lsf_daemons start && lsf_daemons status && perfadmin start all && sleep 5 && pmcadmin start") | crontab -; 
else 
    (crontab -l 2>/dev/null; echo "@reboot sleep 30 && source ~/.bashrc && lsf_daemons start && lsf_daemons status") | crontab -; 
fi

# Setting up the LDAP configuration
if [ "$enable_ldap" = "true" ]; then

    # Detect RHEL version
    rhel_version=$(grep -oE 'release [0-9]+' /etc/redhat-release | awk '{print $2}')

    if [ "$rhel_version" == "8" ]; then
        echo "Detected RHEL 8. Proceeding with LDAP client configuration...." >> "$logfile"

        # Allow Password authentication
        sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
        systemctl restart sshd

        # Configure LDAP authentication
        authconfig --enableldap --enableldapauth \
                    --ldapserver=ldap://${ldap_server_ip} \
                    --ldapbasedn="dc=${base_dn%%.*},dc=${base_dn#*.}" \
                    --enablemkhomedir --update

        # Check the exit status of the authconfig command
        if [ $? -eq 0 ]; then
            echo "LDAP Authentication enabled successfully." >> "$logfile"
        else
            echo "Failed to enable LDAP and LDAP Authentication." >> "$logfile"
            exit 1
        fi

        # Update LDAP Client configurations in nsswitch.conf
        sed -i -e 's/^passwd:.*$/passwd: files ldap/' \
               -e 's/^shadow:.*$/shadow: files ldap/' \
               -e 's/^group:.*$/group: files ldap/' /etc/nsswitch.conf

        # Update PAM configuration files
        sed -i -e '/^auth/d' /etc/pam.d/password-auth
        sed -i -e '/^auth/d' /etc/pam.d/system-auth

        auth_line="\nauth        required      pam_env.so\n\
auth        sufficient    pam_unix.so nullok try_first_pass\n\
auth        requisite     pam_succeed_if.so uid >= 1000 quiet_success\n\
auth        sufficient    pam_ldap.so use_first_pass\n\
auth        required      pam_deny.so"

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

        # Enable nslcd and nscd service
        systemctl enable nslcd
        systemctl enable nscd

        # Validate the LDAP configuration
        if ldapsearch -x -H ldap://${ldap_server_ip}/ -b "dc=${base_dn%%.*},dc=${base_dn#*.}" > /dev/null; then
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
fi
