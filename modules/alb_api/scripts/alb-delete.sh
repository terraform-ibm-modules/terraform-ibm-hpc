#!/bin/bash
# shellcheck disable=all

debug=true # "true" or "false"

exec 111>&1 >&2 # use fd 111 later to emit json, other output goes to stderr

$debug && echo "DELETE $(date +%Y%m%dT%H%M%S.%N)" >>debug_shell_log.txt

$debug && sort -z /proc/self/environ|tr \\0 \\n >debug_shell_delete_env.txt

# json input from stdin; we get the "id" of the LB here
in=$(cat)
$debug && echo >debug_shell_delete_in.txt "in=<<<$in>>>"

lbid="$(jq -r .id <<<"$in")"

# rough sanity check
if [ "${#lbid}" -lt 10 ]; then
  echo "failed to get a LB id"
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

# Step 2. Delete the LB.

out="$(curl -X DELETE "https://${region}.iaas.cloud.ibm.com/v1/load_balancers/$lbid?version=2024-04-25&generation=2" \
            -H "Authorization: Bearer $iam_token")"
$debug && echo "$out"

# Step 3. Finally wait for the LB to really disappear.

max_wait_seconds=$((15*60))
start_at="$(date +%s)"
while true; do
  now="$(date +%s)"
  if [ "$now" -gt "$((start_at+max_wait_seconds))" ]; then
    echo "timeout waiting for LB deletion"
    exit 1
  fi

  out="$(curl -X GET "https://${region}.iaas.cloud.ibm.com/v1/load_balancers/$lbid?version=2024-04-25&generation=2" \
              -H "Authorization: Bearer $iam_token")"
  status="$(jq -r '.provisioning_status' <<<"$out")"
  error="$(jq -r '.errors[].code' <<<"$out" )"
  $debug && echo "$(date -Is) $status"
  $debug && echo "$(date -Is) $error"

  if [ "$error" == "load_balancer_not_found" ]; then
    echo "LB successfully deleted"
    break
  elif [ "$status" == "delete_pending" ]; then
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

# All done, no output has to be generated.

exit 0
