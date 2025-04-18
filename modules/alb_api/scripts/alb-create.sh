#!/bin/bash
# shellcheck disable=all

# inputs we assume to get:
# - bastion_subnet_id
# - certificate_instance
# - pool_ips (comma separated)
# - prefix
# - resource_group_id
# - security_group_ids (comma separated)

# Ensure jq is installed on the remote host
if ! command -v jq &>/dev/null; then
  echo "[INFO] jq not found, installing..."
  if [ -f /etc/debian_version ]; then
    sudo apt-get update && sudo apt-get install -y jq || { echo "Failed to install jq"; exit 1; }
  elif [ -f /etc/redhat-release ]; then
    sudo yum install -y jq || sudo dnf install -y jq || { echo "Failed to install jq"; exit 1; }
  else
    echo "[ERROR] Unsupported OS for jq install. Please install manually."
    exit 1
  fi
fi

debug=true # "true" or "false"

exec 111>&1 >&2 # use fd 111 later to emit json, other output goes to stderr

$debug && echo "CREATE $(date +%Y%m%dT%H%M%S.%N)" >>debug_shell_log.txt

$debug && sort -z /proc/self/environ|tr \\0 \\n >debug_shell_create_env.txt

# json input from stdin; nothing really expected, input values come from env variables when creating
in="$(cat)"
$debug && echo >debug_shell_create_in.txt "in=<<<$in>>>"


# Going to build the complex json request for the ALB creation.
# Many pieces have to be customized, duplicated and finally merged together.

# pieces
jreq="$(cat <<EOF
{
  "resource_group": {
    "id": "REPLACEME_resource_group_id"
  },
  "name": "REPLACEME_name",
  "is_public": false,
  "subnets": [
    {
      "id": "REPLACEME_bastion_subnet_id"
    }
  ],
  "listeners": [REPLACEME_listeners],
  "pools": [REPLACEME_pools],
  "route_mode": false,
  "security_groups": [REPLACEME_security_group_ids]
}
EOF
)"
template_listener='
    {
      "protocol": "https",
      "port": REPLACEME_port,
      "idle_connection_timeout": REPLACEME_idle_connection_timeout,
      "default_pool": {
        "name": "REPLACEME_name"
      },
      "certificate_instance": {
        "crn": "REPLACEME_certificate_instance"
      },
      "accept_proxy_protocol": false
    }
'
template_pool='
    {
      "name": "REPLACEME_name",
      "protocol": "https",
      "algorithm": "round_robin",
      "health_monitor": {
        "type": "https",
        "delay": 5,
        "max_retries": 5,
        "timeout": 2,
        "url_path": "REPLACEME_url_path",
        "port": REPLACEME_port
      },
      "session_persistence": {
        "type": "http_cookie"
      },
      "proxy_protocol": "disabled",
      "members": [REPLACEME_members]
    }
'
template_member='{"target": {"address": "REPLACEME_address"}, "port": REPLACEME_port}'
template_security_group_id='{"id": "REPLACEME_security_group_id"}'

# Inject values into the json request

jreq="${jreq//REPLACEME_resource_group_id/$resource_group_id}"
jreq="${jreq//REPLACEME_name/${prefix}-alb-api}"
jreq="${jreq//REPLACEME_bastion_subnet_id/$bastion_subnet_id}"

# listeners
ls=""
for port in 8443 6080 8444; do
  l="$template_listener"
  l="${l/REPLACEME_port/$port}"
  if [ $port -eq 8444 ]; then
    l="${l/REPLACEME_idle_connection_timeout/7200}"
  else
    l="${l/REPLACEME_idle_connection_timeout/50}"
  fi
  l="${l/REPLACEME_name/${prefix}-alb-pool-$port}"
  l="${l/REPLACEME_certificate_instance/${certificate_instance}}"
  ls+="${l},"
done
ls="${ls%,}"
jreq="${jreq//REPLACEME_listeners/$ls}"

# pools
ps=""
for port in 8443 6080 8444; do
  p="$template_pool"
  p="${p/REPLACEME_name/${prefix}-alb-pool-$port}"
  p="${p/REPLACEME_port/$port}"
  if [ $port -eq 8443 ]; then
    p="${p/REPLACEME_url_path/\/platform\/}"
  else
    p="${p/REPLACEME_url_path/\/}"
  fi
  ms=""
  IFS=',' read -r -a ips <<<"$pool_ips"
  if [ $port -eq 8444 ]; then
      m="$template_member"
      m="${m/REPLACEME_address/$firstip}"
      m="${m/REPLACEME_port/$port}"
      ms+="$m,"
  else
    for ip in "${ips[@]}"; do
      m="$template_member"
      m="${m/REPLACEME_address/$ip}"
      m="${m/REPLACEME_port/$port}"
      ms+="$m,"
    done
  fi
  ms="${ms%,}"
  p="${p//REPLACEME_members/$ms}"
  ps+="$p,"
done
ps="${ps%,}"
jreq="${jreq//REPLACEME_pools/$ps}"

# security group ids
sgis=""
IFS=',' read -r -a ids <<<"$security_group_ids"
for id in "${ids[@]}"; do
  sgi="${template_security_group_id}"
  sgi="${sgi/REPLACEME_security_group_id/$id}"
  sgis+="${sgi},"
done
sgis="${sgis%,}"
jreq="${jreq//REPLACEME_security_group_ids/$sgis}"


# The JSON request is now ready,
# jq will validate it as well-formed and re-indent the JSON.

jreq="$(jq <<<"$jreq")"

$debug && echo "jreq=>>>$jreq<<<"

# rough sanity check
if [ "${#jreq}" -lt 100 ]; then
  echo "failed to create the JSON request"
  exit 1
fi

# Step 1. Get a IAM token.

out="$(curl -X POST 'https://iam.cloud.ibm.com/identity/token' \
            -H 'Content-Type: application/x-www-form-urlencoded' \
            -d "grant_type=urn:ibm:params:oauth:grant-type:apikey&apikey=${ibmcloud_api_key}")"
$debug && echo "$out"
iam_token="$(jq -r '.access_token' <<<"$out")"
$debug && echo "$iam_token"

# rough sanity check
if [ "${#iam_token}" -lt 100 ]; then
  echo "failed to get a IAM token"
  exit 1
fi

# Step 2. Create the LB.

out="$(curl -X POST "https://${region}.iaas.cloud.ibm.com/v1/load_balancers?version=2024-04-25&generation=2" \
            -H "Authorization: Bearer $iam_token" \
            -H 'Content-Type: application/json' \
            -H 'accept: application/json' \
            -d "$jreq")"
$debug && echo "$out"
lbid="$(jq -r '.id' <<<"$out")"
$debug && echo "$lbid"

# rough sanity check
if [ "${#lbid}" -lt 10 ]; then
  echo "failed to get a LB id"
  exit 1
fi

# Other interesting outputs can be collected.

name="$(jq -r '.name' <<<"$out")"
hostname="$(jq -r '.hostname' <<<"$out")"
crn="$(jq -r '.crn' <<<"$out")"
href="$(jq -r '.href' <<<"$out")"


# Step 3. Finally wait for the LB to be really running.

max_wait_seconds=$((20*60))
start_at="$(date +%s)"
while true; do
  now="$(date +%s)"
  if [ "$now" -gt "$((start_at+max_wait_seconds))" ]; then
    echo "timeout waiting for LB creation"
    exit 1
  fi

  out="$(curl -X GET "https://${region}.iaas.cloud.ibm.com/v1/load_balancers/$lbid?version=2024-04-25&generation=2" \
              -H "Authorization: Bearer $iam_token")"
  status="$(jq -r '.provisioning_status' <<<"$out")"
  error="$(jq -r '.errors[].code' <<<"$out" )"
  $debug && echo "$(date -Is) $status"
  $debug && echo "$(date -Is) $error"

  if [ "$status" == "active" ]; then
    echo "LB successfully created"
    break
  elif [ "$status" == "create_pending" ]; then
    delay=5
  else # this also handles connection problems
    delay=4
  fi

  echo "waiting $delay seconds"
  sleep $delay
done
# Note possibile status we can get:
# - create_pending
# - active
# - delete_pending
# Or a specific error if LB is not existent (.errors[].code)
# - load_balancer_not_found

# All done, prepare final output including interesting values to consume.

res="$(cat <<EOF
{
  "id": "$lbid",
  "name": "$name",
  "hostname": "$hostname",
  "crn": "$crn",
  "href": "$href"
}
EOF
)"

$debug && echo "$res"

# Emit the output
echo >&111 "$res"

exit 0
