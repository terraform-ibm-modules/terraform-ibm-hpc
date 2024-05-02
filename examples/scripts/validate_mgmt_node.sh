#!/bin/bash
# shellcheck disable=SC2026
###################################################
# Copyright (C) IBM Corp. 2023 All Rights Reserved.
# Licensed under the Apache License v2.0
###################################################

###################################################
# Script Description:
# This script performs validation checks and actions on an IBM Cloud HPC cluster environment.
# It involves various verification steps and validations, such as MTU configuration, IP route presence,
# file system mount checks, job submission on the management node, SSH interaction with dynamic nodes,
# and dynamic compute resource management. The script aims to ensure the health and proper functioning
# of the cluster infrastructure.
# If validation_failed is set to 1, it will destroy the dynamic compute resource and exit from the script with status code 1.
###################################################

# Set initial validation status
validation_failed=0

# Function to handle validation failures
handle_validation_failure() {
  echo "Validation issues detected. Script execution failed."
  # This step is necessary to handle cases where a dynamic node is not created,
  # and jobs remain in a pending state due to exceeding the timeout when job submission.
  # By using 'bkill', we ensure that any lingering jobs are properly terminated.
  bkill 0

  # gitWaiting for the dynamic node to disappear
  # We're waiting for 420 seconds (7 minutes), and later we'll check the status of the dynamic node using a while loop.
  # The maximum time for a dynamic node to be destroyed is 10 minutes.
  echo "Waiting 420 seconds for the dynamic node to be destroyed..."
  sleep 420;

  if timeout 720 bash -c '
    while bhosts -w | grep -q "ok"; do
        bhosts -w | grep "ok"
        echo "CHECKING: Waiting for dynamic node to disappear..."
        sleep 60
    done
  '; then
    echo "PASS: Dynamic node has disappeared!"
  else
    echo "FAIL: Timeout occurred while waiting for the dynamic node to disappear."
  fi
}

# Add timeout for submitting job and waiting
if timeout 480 bash -c '
  # Submit a job that will sleep for 10 seconds
  bsub -n 10 -R "select[cloudhpchost]" sleep 10
  # Wait
  echo "Waiting 180 seconds for the dynamic node to appear..."
  sleep 180
  # Wait for the job to complete
  while bjobs | grep -Ew "PEND|RUN"; do
    echo "WAIT: Waiting for the job to complete..."
    sleep 60
  done
'; then
  echo "PASS: Job executed successfully!"
else
  echo "TIMEOUT: The job execution and waiting exceeded the timeout."
  validation_failed=1
fi

# Check for the presence of required mount points on management node
echo "Checking presence of required mount points on the management node..."
count=$(df -h | grep -cw "/mnt/lsf\|/mnt/binaries\|/mnt/data")
if [ "$count" -ne 3 ]; then
  echo "FAIL: One or more required paths are not available on the management node."
  printf "File Mount value is:\n%s\n" "$(df -h)"
  validation_failed=1
fi

# Check MTU value for eth0 on management node
echo "Checking MTU value for eth0 on the management node..."
mtu_value=$(ip link show dev eth0 | awk '/mtu/ {print $5}')
if [ "$mtu_value" -ne 9000 ]; then
  echo "FAIL: MTU value for eth0 is not set to 9000 on the management node."
  printf "Current MTU value is: %s\n" "$mtu_value"
  validation_failed=1
else
  echo "PASS: MTU value for eth0 is set to 9000 on the management node."
fi

# Check for the presence of required routes in the routing table
echo "Checking presence of required routes in the routing table..."
if ip route show | grep -w '^default' && ip route | grep -w '^10.241.0.0/22' && ip route | grep -w 'eth0 proto static mtu 9000'; then
  echo "PASS: All required routes are available in the routing table."
else
  echo "FAIL: Required routes are not found in the routing table."
  validation_failed=1
fi

# Check if hyperthreading is supported
if grep -q '^flags.*\<ht\>' /proc/cpuinfo; then
    echo "Hyperthreading is supported"
else
    echo "Hyperthreading is not supported"
    validation_failed=1
fi

# Check for the presence of required mount points and logs on worker nodes
nodes=$(bhosts -w | awk "NR>1 && !/mgmt/ {print \$1}")
for node in $nodes; do
  ssh "$node" '
    # Check for the presence of required mount points on worker nodes
    count=$(df -h | grep -cw "/mnt/lsf\|/mnt/binaries\|/mnt/data")
    if [ "$count" -ne 3 ]; then
      echo "FAIL: One or more required paths are not available on worker $node."
      printf "File Mount value is:\n%s\n" "$(df -h)"
      validation_failed=1
    fi
    if ! grep -q "END" /tmp/user_data.log; then
      echo "FAIL: 'END' not found in user_data.log on worker $node."
      validation_failed=1
    fi
    mtu_worker=$(ip link show dev eth0 | awk "/mtu/ {print \$5}")
    if [ "$mtu_worker" -ne 9000 ]; then
      echo "FAIL: MTU value for eth0 is not set to 9000 on worker $node."
      printf "Current MTU value is: %s\n" "$mtu_worker"
      validation_failed=1
    fi
  '
done

if [ $validation_failed -eq 0 ]; then
  echo "Verify config [Submit jobs, IP Route, MTU, File Mount, SSH into dynamic nodes and validate MTU, File Mount] validated successfully."
fi

# Handle validation failures
if [ $validation_failed -eq 1 ]; then
  handle_validation_failure
  echo "FAIL: Verify Config Validation issues detected. Script execution failed."
  exit 1  # Failure
else
  echo "PASS: Verify Config validations passed successfully."
fi
