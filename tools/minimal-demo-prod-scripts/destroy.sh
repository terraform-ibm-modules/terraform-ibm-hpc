#!/usr/bin/env bash

source .env

REGION=$(echo "$ZONES" | cut -d'-' -f1-2)

if [ $# -eq 0 ]
  then
    echo "Pls provide cluster_prefix, i.e. destroy.sh <prefix>"
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

echo "finding schematics workspace..."
# Extract WORKSPACE_ID
WORKSPACE_ID=$(ibmcloud schematics workspace list --output json \
  | jq -r '.workspaces[] | select(.name=="'"$1"'") | .id')

ibmcloud schematics workspace get --id "$WORKSPACE_ID"

read -p "Do you want to destroy? (yes/no) " yn

case $yn in
       yes ) echo ok, we will proceed;;
       no ) echo exiting...;
               exit;;
       * ) echo invalid response;
               exit 1;;
esac

rm environment_values_$1.json

ibmcloud schematics destroy --id $WORKSPACE_ID -f
