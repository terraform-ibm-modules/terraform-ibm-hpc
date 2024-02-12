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

ibmcloud target -r us-south
ibmcloud is vpn-gateway-connection-create ${NAME} ${VPN_GATEWAY_ID} ${IP} ${KEY} --local-cidr 10.0.10.0/24 --peer-cidr ${CIDR}
ibmcloud is security-group-rule-add r006-3ab7df0c-0793-4b84-9b6b-936b5dff95c0 inbound all --remote ${CIDR}
