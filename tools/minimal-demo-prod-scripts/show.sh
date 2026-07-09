#!/usr/bin/env bash

source .env

REGION=$(echo "$ZONES" | cut -d'-' -f1-2)

if [ $# -eq 0 ]
  then
    echo "Pls provide cluster_prefix, i.e. show.sh <prefix>"
    exit 1
fi

CURRENT_ACCOUNT_GUID=$(ibmcloud target --output json | jq -r '.account.guid')
if [ "$CURRENT_ACCOUNT_GUID" != "$ACCOUNT_GUID" ]
  then
    ibmcloud login -a cloud.ibm.com --apikey "$API_KEY" -r "$REGION" -g "$RESOURCE_GROUP"
fi

echo "target account $CURRENT_ACCOUNT_GUID"

CURRENT_REGION=$(ibmcloud target --output json | jq -r '.region.name')
if [ "$CURRENT_REGION" != "$REGION" ]
  then
    ibmcloud target -r "$REGION"
fi
echo "target region $REGION"

echo "finding schematics workspace..."
WORKSPACE_ID=$(ibmcloud schematics workspace list | grep "$1" | awk '{ print $2 }')

ibmcloud schematics workspace get --id "$WORKSPACE_ID"
