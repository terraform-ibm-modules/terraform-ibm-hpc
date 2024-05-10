# LSF prerequisites
LSF_TOP=/opt/ibm/lsf
LSF_CONF_PATH=/opt/ibm/lsf/conf
LSF_PACKAGES_PATH="provide the path to where the lsf latest packges are present"
sleep 180
LSF_PREREQS="python38 nfs-utils ed wget gcc-c++ elfutils-libelf-devel kernel-devel-$(uname -r) gcc-gfortran libgfortran libquadmath libmpc libquadmath-devel mpfr perl libnsl"
dnf install -y libnsl libnsl2 openldap-clients nss-pam-ldapd authselect sssd oddjob oddjob-mkhomedir
yum install -y $LSF_PREREQS
useradd lsfadmin
echo 'lsfadmin ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers
mkdir -p {LSF_TOP}
chmod -R 755 /opt
rm -f /usr/bin/python3
ln -s /usr/bin/python3.8 /usr/bin/python3
curl -fsSL https://clis.cloud.ibm.com/install/linux | sh
pip3 install ibm-vpc==0.10.0
pip3 install ibm-cloud-networking-services ibm-cloud-sdk-core selinux
ibmcloud plugin install vpc-infrastructure
ibmcloud plugin install DNS
chmod 755 -R /usr/local/lib/python3.8
chmod 755 -R /usr/local/lib64/python3.8
hostname lsfservers
echo 'provide the value of the entitlement check that is available on the lsf entitlement check file' > {LSF_PACKAGES_PATH}/ls.entitlement
echo 'provide the value of the entitlement check that is available on the lsf entitlement check file' > {LSF_PACKAGES_PATH}/lsf.entitlement

# Need a appropriate LSF latest packages, using the packages the below configures the lsf core installation
cd {LSF_PACKAGES_PATH} || exit
zcat lsf*lsfinstall_linux_x86_64.tar.Z | tar xvf -
cd lsf*_lsfinstall || exit
sed -e '/show_copyright/ s/^#*/#/' -i lsfinstall
cat <<EOT >> install.config
LSF_TOP="/opt/ibm/lsf"
LSF_ADMINS="lsfadmin"
LSF_CLUSTER_NAME="HPCCluster"
LSF_MASTER_LIST="lsfservers"
LSF_ENTITLEMENT_FILE="{LSF_PACKAGES_PATH}/lsf.entitlement"
CONFIGURATION_TEMPLATE="DEFAULT"
ENABLE_DYNAMIC_HOSTS="Y"
ENABLE_EGO="N"
ACCEPT_LICENSE="Y"
SILENT_INSTALL="Y"
LSF_SILENT_INSTALL_TARLIST="ALL"
EOT
bash lsfinstall -f install.config
echo $?
cat Install.log
echo "====================== LSF Setup Done====================="

# Removal of API keys
sed -i "s/^VPC_APIKEY=.*/VPC_APIKEY=/g" {LSF_CONF_PATH}/resource_connector/ibmcloudgen2/credentials
sed -i "s/^RESOURCE_RECORDS_APIKEY=.*/RESOURCE_RECORDS_APIKEY=/g" {LSF_CONF_PATH}/resource_connector/ibmcloudgen2/credentials

hostname lsfservers

# LSF worker (Resource connector) installation
cd {LSF_PACKAGES_PATH} || exit
cd lsf*_lsfinstall || exit
cat <<EOT >> server.config
LSF_TOP="/opt/ibm/lsf_worker"
LSF_ADMINS="lsfadmin"
LSF_ENTITLEMENT_FILE="{LSF_PACKAGES_PATH}/lsf.entitlement"
LSF_SERVER_HOSTS="lsfservers"
LSF_LOCAL_RESOURCES="[resource cloudhpchost]"
ACCEPT_LICENSE="Y"
SILENT_INSTALL="Y"
EOT
bash lsfinstall -s -f server.config
echo $?
cat Install.log
echo "====================== WORKER Setup Done====================="
rm -rf /opt/ibm/lsf_worker/10.1
ln -s /opt/ibm/lsf/10.1 /opt/ibm/lsf_worker
rm -rf /opt/ibm/lsf_worker/10.1
ln -s /opt/ibm/lsf/10.1 /opt/ibm/lsf_worker


# OpenMPI installation
cd {LSF_PACKAGES_PATH} || exit
wget https://download.open-mpi.org/release/open-mpi/v4.1/openmpi-4.1.0.tar.gz
tar -xvf openmpi-4.1.0.tar.gz
cd openmpi-4.1.0 || exit
ln -s /usr/lib64/libnsl.so.2.0.0 /usr/lib64/libnsl.so
export LANG=C
./configure --prefix='/usr/local/openmpi-4.1.0' --enable-mpi-thread-multiple --enable-shared --disable-static --enable-mpi-fortran=usempi --disable-libompitrace --enable-script-wrapper-compilers --enable-wrapper-rpath --enable-orterun-prefix-by-default --with-io-romio-flags=--with-file-system=nfs --with-lsf=/opt/ibm/lsf/10.1 --with-lsf-libdir=/opt/ibm/lsf/10.1/linux3.10-glibc2.17-x86_64/lib
make -j 32
make install
find /usr/local/openmpi-4.1.0/ -type d -exec chmod 775 {{}} \;
echo "====================== SetUp of oneMPI completed====================="

# Intel One API (hpckit) installation
tee > /etc/yum.repos.d/oneAPI.repo << EOF
[oneAPI]
name=Intel® oneAPI repository
baseurl=https://yum.repos.intel.com/oneapi
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://yum.repos.intel.com/intel-gpg-keys/GPG-PUB-KEY-INTEL-SW-PRODUCTS.PUB
EOF
ls /etc/yum.repos.d
yum install -y intel-basekit intel-hpckit
rpm -qa | grep "intel-hpckit\|intel-basekit"
rm -rf /etc/yum.repos.d/oneAPI.repo
ls /etc/yum.repos.d
echo "====================== SetUp of one API completed====================="

# Setting up access for the appropriate path
mv -f {LSF_PACKAGES_PATH}/*.entitlement /opt/ibm/lsf/conf
chown -R lsfadmin:root {LSF_CONF_PATH}

# Updating security check
yum update --security -y

# Sysdig Agent installation
echo "Installing Sysdig Agent"
curl -sL https://ibm.biz/install-sysdig-agent | sudo bash -s -- --access_key ==ACCESSKEY== --collector ==COLLECTOR== --collector_port 6443 --secure true --check_certificate false --additional_conf 'sysdig_capture_enabled: false\nremotefs: true\nfeature:\n mode: monitor_light'
systemctl stop dragent
systemctl disable dragent

# Cleanup of all the folders and unwanted ssh keys as part of security
rm -rf {LSF_PACKAGES_PATH}
rm -rf /home/vpcuser/.ssh/authorized_keys
rm -rf /home/vpcuser/.ssh/known_hosts
rm -rf /home/vpcuser/.ssh/id_rsa*
rm -rf /home/lsfadmin/.ssh/authorized_keys
rm -rf /home/lsfadmin/.ssh/known_hosts
rm -rf /home/lsfadmin/.ssh/id_rsa*
rm -rf /root/.ssh/authorized_keys
rm -rf /root/.ssh/known_hosts
rm -rf /root/.ssh/id_rsa*
systemctl stop syslog
rm -rf /var/log/messages
rm -rf /root/.bash_history
history -c