#!/usr/bin/env bash

source .env

REGION=$(echo "$ZONES" | cut -d'-' -f1-2)

if [ $# -eq 0 ]
  then
    echo "Pls provide cluster_prefix, i.e. jump.sh <prefix>"
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

BASTION_IP=$(ibmcloud is ips | grep $1-bastion | grep 001-fip | awk '{print $2}')
echo "Bastion IP: $BASTION_IP"

LOGIN_IP=$(ibmcloud is instances | grep $1-login | grep 001 | awk '{print $4}')
echo "Login IP:   $LOGIN_IP"

LSF_IP=$(ibmcloud is instances | grep $1-mgmt-1 | grep 001 | awk '{print $4}')
echo "LSF IP:   $LSF_IP"

echo "Jumping to Login Node..."
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -J ubuntu@$BASTION_IP lsfadmin@$LOGIN_IP
