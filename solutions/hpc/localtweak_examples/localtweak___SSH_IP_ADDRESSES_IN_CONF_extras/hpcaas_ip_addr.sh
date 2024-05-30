#!/bin/bash

prefix="$1"
iptype="$2"
ipvalue="$3"

if [ "$iptype" == "fip" ]; then
  ip="$ipvalue"
  sed -i -e "s/  Hostname .* # $prefix fip/  Hostname $ip # $prefix fip/g" ~/.ssh/config.d/hpcaas.conf
elif [ "$iptype" == "login" ]; then
  ip="$ipvalue"
  sed -i -e "s/  Hostname .* # $prefix iplogin/  Hostname $ip # $prefix iplogin/g" ~/.ssh/config.d/hpcaas.conf
elif [ "$iptype" == "mgmt" ]; then
  ip1="$ipvalue"
  sed -i -e "s/  Hostname .* # $prefix ip1/  Hostname $ip1 # $prefix ip1/g" ~/.ssh/config.d/hpcaas.conf
elif [ "$iptype" == "mgmt_candidate" ]; then
  ips="$ipvalue"
  ip2="${ips%,*}"
  ip3="${ips#*,}"
  sed -i -e "s/  Hostname .* # $prefix ip2/  Hostname $ip2 # $prefix ip2/g" ~/.ssh/config.d/hpcaas.conf
  sed -i -e "s/  Hostname .* # $prefix ip3/  Hostname $ip3 # $prefix ip3/g" ~/.ssh/config.d/hpcaas.conf
fi
