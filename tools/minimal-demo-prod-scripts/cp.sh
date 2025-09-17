#!/usr/bin/env bash

source .env

REGION=$(echo "$ZONES" | cut -d'-' -f1-2)

if [ $# -eq 0 ]
  then
    echo "Pls provide cluster_prefix, i.e. cp.sh <prefix> <file> <dest=login|mgmt>"
    exit 1
fi

CURRENT_ACCOUNT_GUID=$(ibmcloud target --output json | jq -r '.account.guid')
if [ "$CURRENT_ACCOUNT_GUID" != "$ACCOUNT_GUID" ]
  then
    ibmcloud login -a cloud.ibm.com --apikey $API_KEY -r $REGION -g $RESOURCE_GROUP
fi

CURRENT_ACCOUNT_NAME=$(ibmcloud target --output json | jq -r '.account.name')
echo "target account $CURRENT_ACCOUNT_GUID"

CURRENT_REGION=$(ibmcloud target --output json | jq -r '.region.name')
if [ "$CURRENT_REGION" != "$REGION" ]
  then
    ibmcloud target -r $REGION
fi
echo "target region $REGION"

# ibmcloud is ip $1-bastion-001-fip --output json | jq -r '. | .address'
BASTION_IP=$(ibmcloud is ips | grep $1-bastion | grep 001-fip | awk '{print $2}')
echo "Bastion IP: $BASTION_IP"

# ibmcloud is instance $1-login-001 --output json | jq -r '. | .network_interfaces[0].primary_ip.address'
LOGIN_IP=$(ibmcloud is instances | grep $1-login | grep 001 | awk '{print $4}')
echo "Login IP:   $LOGIN_IP"

# ibmcloud is instance $1-mgmt-1-001 --output json | jq -r '. | .network_interfaces[0].primary_ip.address'
LSF_IP=$(ibmcloud is instances | grep $1-mgmt-1 | grep 001 | awk '{print $4}')
echo "LSF IP:   $LSF_IP"

if [ "$3" == "mgmt" ]
  then
    echo "copying $2 to LSF /mnt/vpcstorage/tools..."
    scp -o UserKnownHostsFile=/dev/null -o StrictHostKeychecking=no -o IdentitiesOnly=yes -J ubuntu@$BASTION_IP $2 lsfadmin@$LSF_IP:/mnt/vpcstorage/tools/$(basename $2)
else
    echo "copying $2 to LOGIN /home/lsfadmin..."
    scp -o UserKnownHostsFile=/dev/null -o StrictHostKeychecking=no -o IdentitiesOnly=yes -J ubuntu@$BASTION_IP $2 lsfadmin@$LOGIN_IP:/home/lsfadmin/$(basename $2)
fi
