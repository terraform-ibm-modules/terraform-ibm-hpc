#!/bin/bash
# shellcheck disable=all

###################################################
# Copyright (C) IBM Corp. 2023 All Rights Reserved.
# Licensed under the Apache License v2.0
###################################################

USER=ubuntu
BASE_DN="${ldap_basedns}"
LDAP_DIR="/opt"
LDAP_ADMIN_PASSWORD="${ldap_admin_password}"
LDAP_GROUP="${cluster_prefix}"
LDAP_USER="${ldap_user}"
LDAP_USER_PASSWORD="${ldap_user_password}"
nfs_server_with_mount_path=${mount_path}
logfile="/tmp/user_data.log"

sed -i -e "s/^/no-port-forwarding,no-agent-forwarding,no-X11-forwarding,command=\"echo \'Please login as the user \\\\\"$USER\\\\\" rather than the user \\\\\"root\\\\\".\';echo;sleep 5; exit 142\" /" /root/.ssh/authorized_keys

#input parameters
ssh_public_key_content="${ssh_public_key_content}"
echo "${ssh_public_key_content}" >> home/$USER/.ssh/authorized_keys
echo "StrictHostKeyChecking no" >> /home/$USER/.ssh/config

# Installing Required softwares
apt-get update -y
apt-get install gnutls-bin ssl-cert nfs-common -y

# Setup Network configuration
# Change the MTU setting as this is required for setting mtu as 9000 for communication to happen between clusters
if grep -q "NAME=\"Ubuntu\"" /etc/os-release; then
    net_int=$(basename /sys/class/net/en*)
    netplan_config="/etc/netplan/50-cloud-init.yaml"
    gateway_ip=$(ip route | grep default | awk '{print $3}' | head -n 1)
    cidr_range=$(ip route show | grep "kernel" | awk '{print $1}' | head -n 1)
    usermod -s /bin/bash ubuntu
    # Replace the MTU value in the Netplan configuration
    if ! grep -qE "^[[:space:]]*mtu: 9000" $netplan_config; then
        echo "MTU 9000 Packages entries not found"
        # Append the MTU configuration to the Netplan file
        sudo sed -i '/'"$net_int"':/a\            mtu: 9000' $netplan_config
        sudo sed -i '/dhcp4: true/a \            nameservers:\n              search: ['"$dns_domain"']' $netplan_config
        sudo sed -i '/'"$net_int"':/a\            routes:\n              - to: '"$cidr_range"'\n                via: '"$gateway_ip"'\n                metric: 100\n                mtu: 9000' $netplan_config
        sudo netplan apply
        echo "MTU set to 9000 on Netplan." >> $logfile
    else
        echo "MTU entry already exists in Netplan. Skipping." >> $logfile
    fi
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
    mkdir -p "$nfs_client_mount_path/openldap"
  else
    echo "Mount not found for ${nfs_server_with_mount_path}, Exiting !!" >> $logfile
    exit 1
  fi
else
  echo "No NFS server mount path provided, Exiting !!" >> $logfile
  exit 1
fi
echo "Setting LSF share is completed." >> $logfile

#Installing LDAP
export DEBIAN_FRONTEND='non-interactive'
echo -e "slapd slapd/root_password password ${LDAP_ADMIN_PASSWORD}" |debconf-set-selections
echo -e "slapd slapd/root_password_again password ${LDAP_ADMIN_PASSWORD}" |debconf-set-selections
apt-get install -y slapd ldap-utils

echo -e "slapd slapd/internal/adminpw password ${LDAP_ADMIN_PASSWORD}" |debconf-set-selections
echo -e "slapd slapd/internal/generated_adminpw password ${LDAP_ADMIN_PASSWORD}" |debconf-set-selections
echo -e "slapd slapd/password2 password ${LDAP_ADMIN_PASSWORD}" |debconf-set-selections
echo -e "slapd slapd/password1 password ${LDAP_ADMIN_PASSWORD}" |debconf-set-selections
echo -e "slapd slapd/domain string ${BASE_DN}" |debconf-set-selections
echo -e "slapd shared/organization string ${BASE_DN}" |debconf-set-selections
echo -e "slapd slapd/purge_database boolean false" |debconf-set-selections
echo -e "slapd slapd/move_old_database boolean true" |debconf-set-selections
echo -e "slapd slapd/no_configuration boolean false" |debconf-set-selections
dpkg-reconfigure slapd
echo "BASE   dc=${BASE_DN%%.*},dc=${BASE_DN#*.}" >> /etc/ldap/ldap.conf
echo "URI    ldap://localhost" >> /etc/ldap/ldap.conf
systemctl restart slapd
systemctl enable slapd
echo "LDAP server installtion completed" >> $logfile

# Generate SSL cert and Configure with OpenLDAP server
certtool --generate-privkey --sec-param High --outfile /etc/ssl/private/ldap_cakey.pem

# Create CA template file
cat <<EOF > /etc/ssl/ca.info
cn = ${LDAP_GROUP}
ca
cert_signing_key
expiration_days = 3650
EOF

# Generate a self-signed CA certificate
certtool --generate-self-signed \
--load-privkey /etc/ssl/private/ldap_cakey.pem \
--template /etc/ssl/ca.info \
--outfile /usr/local/share/ca-certificates/ldap_cacert.pem

# Update CA certificates and copy the generated CA certificate to /etc/ssl/certs/
update-ca-certificates
cp -r /usr/local/share/ca-certificates/ldap_cacert.pem /etc/ssl/certs/
cp -r /usr/local/share/ca-certificates/ldap_cacert.pem "$nfs_client_mount_path/openldap"
chmod -R 777 "$nfs_client_mount_path/openldap"

# Generate a private key for the LDAP server
certtool --generate-privkey --sec-param High --outfile /etc/ssl/private/ldapserver_slapd_key.pem

# Create LDAP server certificate template
cat <<EOF > /etc/ssl/ldapserver.info
organization = ${LDAP_GROUP}
cn = localhost
tls_www_server
encryption_key
signing_key
expiration_days = 3650
EOF

# Generate a certificate for the LDAP server signed by the CA
certtool --generate-certificate \
--load-privkey /etc/ssl/private/ldapserver_slapd_key.pem \
--load-ca-certificate /etc/ssl/certs/ldap_cacert.pem \
--load-ca-privkey /etc/ssl/private/ldap_cakey.pem \
--template /etc/ssl/ldapserver.info \
--outfile /etc/ssl/certs/ldapserver_slapd_cert.pem

# Set proper permissions for the LDAP server private key
chgrp openldap /etc/ssl/private/ldapserver_slapd_key.pem
chmod 0640 /etc/ssl/private/ldapserver_slapd_key.pem
gpasswd -a openldap ssl-cert

sleep 2

# Restart slapd service to apply changes
systemctl restart slapd.service

# Create LDIF file for configuring TLS in LDAP
cat <<EOF > /etc/ssl/certinfo.ldif
dn: cn=config
add: olcTLSCACertificateFile
olcTLSCACertificateFile: /etc/ssl/certs/ldap_cacert.pem
-
add: olcTLSCertificateFile
olcTLSCertificateFile: /etc/ssl/certs/ldapserver_slapd_cert.pem
-
add: olcTLSCertificateKeyFile
olcTLSCertificateKeyFile: /etc/ssl/private/ldapserver_slapd_key.pem
EOF

# Apply TLS configuration using ldapmodify
ldapmodify -Y EXTERNAL -H ldapi:/// -f /etc/ssl/certinfo.ldif

# Update slapd service to listen on ldaps:// as well
sed -i 's\SLAPD_SERVICES="ldap:/// ldapi:///"\SLAPD_SERVICES="ldap:/// ldapi:/// ldaps:///"\g' /etc/default/slapd

sleep 2

#  Update /etc/ldap/ldap.conf
cat <<EOF > /etc/ldap/ldap.conf
BASE   dc=${BASE_DN%%.*},dc=${BASE_DN#*.}
URI    ldap://localhost
TLS_CACERT /etc/ssl/certs/ldap_cacert.pem
TLS_REQCERT allow
EOF

# Restart slapd service to apply changes
systemctl restart slapd.service
echo "SSL creation complted" >> $logfile

#LDAP Operations
check_and_create_ldap_ou() {
    local ou_name="$1"
    local ldif_file="${LDAP_DIR}/ou${ou_name}.ldif"
    local search_result=""

    echo "dn: ou=${ou_name},dc=${BASE_DN%%.*},dc=${BASE_DN#*.}
objectClass: organizationalUnit
ou: ${ou_name}" > "${ldif_file}"

    ldapsearch -x -D "cn=admin,dc=${BASE_DN%%.*},dc=${BASE_DN#*.}" -w "${LDAP_ADMIN_PASSWORD}" -b "ou=${ou_name},dc=${BASE_DN%%.*},dc=${BASE_DN#*.}" "objectClass=organizationalUnit" > /dev/null 2>&1
    search_result=$?

    [ ${search_result} -eq 32 ] && echo "${ou_name}OUNotFound" || echo "${ou_name}OUFound"
}

# LDAP | Server People OU Check and Create
ldap_people_ou_search=$(check_and_create_ldap_ou People)
[ "${ldap_people_ou_search}" == "PeopleOUNotFound" ] && ldapadd -x -D "cn=admin,dc=${BASE_DN%%.*},dc=${BASE_DN#*.}" -w "${LDAP_ADMIN_PASSWORD}" -f "${LDAP_DIR}/ouPeople.ldif"
[ "${ldap_people_ou_search}" == "PeopleOUFound" ] && echo "LDAP OU 'People' already exists. Skipping."

# LDAP | Server Groups OU Check and Create
ldap_groups_ou_search=$(check_and_create_ldap_ou Groups)
[ "${ldap_groups_ou_search}" == "GroupsOUNotFound" ] && ldapadd -x -D "cn=admin,dc=${BASE_DN%%.*},dc=${BASE_DN#*.}" -w "${LDAP_ADMIN_PASSWORD}" -f "${LDAP_DIR}/ouGroups.ldif"
[ "${ldap_groups_ou_search}" == "GroupsOUFound" ] && echo "LDAP OU 'Groups' already exists. Skipping."

# Creating LDAP Group on the LDAP Server

# LDAP | Group File
echo "dn: cn=${LDAP_GROUP},ou=Groups,dc=${BASE_DN%%.*},dc=${BASE_DN#*.}
objectClass: posixGroup
cn: ${LDAP_GROUP}
gidNumber: 5000" > "${LDAP_DIR}/group.ldif"

# LDAP Group Search
ldap_group_dn="cn=${LDAP_GROUP},ou=Groups,dc=${BASE_DN%%.*},dc=${BASE_DN#*.}"
ldap_group_search_result=$(ldapsearch -x -D "cn=admin,dc=${BASE_DN%%.*},dc=${BASE_DN#*.}" -w "${LDAP_ADMIN_PASSWORD}" -b "${ldap_group_dn}" "(cn=${LDAP_GROUP})" 2>&1)

# Check if LDAP Group exists
if echo "${ldap_group_search_result}" | grep -q "dn: ${ldap_group_dn},"
then
    echo "LDAP Group '${LDAP_GROUP}' already exists. Skipping." >> $logfile
    ldap_group_search="GroupFound"
else
    echo "LDAP Group '${LDAP_GROUP}' not found. Creating..." >> $logfile
    ldapadd -x -D "cn=admin,dc=${BASE_DN%%.*},dc=${BASE_DN#*.}" -w "${LDAP_ADMIN_PASSWORD}" -f "${LDAP_DIR}/group.ldif"
    ldap_group_search="GroupNotFound"
fi

# Creating LDAP User on the LDAP Server

# Generate LDAP Password Hash
ldap_hashed_password=$(slappasswd -s "${LDAP_USER_PASSWORD}")

# LDAP | User File
echo "dn: uid=${LDAP_USER},ou=People,dc=${BASE_DN%%.*},dc=${BASE_DN#*.}
objectClass: inetOrgPerson
objectClass: posixAccount
objectClass: shadowAccount
uid: ${LDAP_USER}
sn: ${LDAP_USER}
givenName: ${LDAP_USER}
cn: ${LDAP_USER}
displayName: ${LDAP_USER}
uidNumber: 10000
gidNumber: 5000
userPassword: ${ldap_hashed_password}
gecos: ${LDAP_USER}
loginShell: /bin/bash
homeDirectory: /home/${LDAP_USER}" > "${LDAP_DIR}/users.ldif"

# LDAP User Search
ldap_user_dn="uid=${LDAP_USER},ou=People,dc=${BASE_DN%%.*},dc=${BASE_DN#*.}"
ldap_user_search_result=$(ldapsearch -x -D "cn=admin,dc=${BASE_DN%%.*},dc=${BASE_DN#*.}" -w "${LDAP_ADMIN_PASSWORD}" -b "${ldap_user_dn}" uid cn 2>&1)

# Check if LDAP User exists
if echo "${ldap_user_search_result}" | grep -q "dn: ${ldap_user_dn},"
then
    echo "LDAP User '${LDAP_USER}' already exists. Skipping." >> $logfile
    ldap_user_search="UserFound"
else
    echo "LDAP User '${LDAP_USER}' not found. Creating..." >> $logfile
    ldapadd -x -D "cn=admin,dc=${BASE_DN%%.*},dc=${BASE_DN#*.}" -w "${LDAP_ADMIN_PASSWORD}" -f "${LDAP_DIR}/users.ldif"
    ldap_user_search="UserNotFound"
fi
echo "User and Group creation complted" >> $logfile

# Attempt to unmount the VPC share
if umount -l "${nfs_client_mount_path}";
then
    echo "Unmounted ${nfs_client_mount_path} successfully." >> $logfile
else
    echo "Failed to unmount ${nfs_client_mount_path}." >> $logfile
    exit 1
fi
