#!/bin/bash
if [ $# -ne 4 ]; then
  echo "usage: $0 {vpn_preshared_key} {NAME} {IP} {CIDR}"
  exit 1
fi
KEY=$1
NAME=$2
IP=$3
CIDR=$4
VPN_GATEWAY_ID=0717-6c1837f3-4f1b-4f77-94af-0d1a045cc8f0 # policy-based

SG=`ibmcloud is security-group-rules r006-3ab7df0c-0793-4b84-9b6b-936b5dff95c0 -output JSON | jq -r '.[] | select(.remote.cidr_block == "'$CIDR'")'.id`

ibmcloud is security-group-rule-delete r006-3ab7df0c-0793-4b84-9b6b-936b5dff95c0 $SG

NG=`ibmcloud is vpn-gateway-connections $VPN_GATEWAY_ID -output JSON | jq -r '.[] | select(.name == "'$NAME'")'.id`

ibmcloud is vpn-gateway-connection-delete $VPN_GATEWAY_ID $NG
