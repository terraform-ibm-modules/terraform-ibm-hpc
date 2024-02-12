#!/bin/bash

###################################################
# Copyright (C) IBM Corp. 2023 All Rights Reserved.
# Licensed under the Apache License v2.0
###################################################

###################################################
# Script Description:
# This script performs validation checks and actions on an IBM Cloud HPC cluster environment.
# It includes restarting LSF daemons and checking node status
# If validation_failed is set to 1, it will destroy the dynamic compute resource and exiting from the script with status code 1.
###################################################

# Set initial validation status
validation_failed=0
timeout_duration=120 # Timeout duration in seconds (2 minutes)


# Function to handle validation failures
handle_validation_failure() {
  echo "Validation issues detected. Script execution failed."
  # This step is necessary to handle cases where a dynamic node is not created, 
  # and jobs remain in a pending state due to exceeding the timeout when job submission.
  # By using 'bkill', we ensure that any lingering jobs are properly terminated.
  bkill 0

  # Waiting for the dynamic node to disappear
  # We're waiting for 420 seconds (7 minutes), and later we'll check the status of the dynamic node using a while loop.
  # The maximum time for a dynamic node to be destroyed is 10 minutes.
  echo "Waiting 420 seconds for the dynamic node to be destroyed..."
  sleep 420;

  if timeout 720 bash -c '
    while bhosts -w | grep -q "ok"; do
        bhosts -w | grep "ok";
        echo "CHECKING: Waiting for dynamic node to disappear...";
        sleep 60;
    done;
  '; then
    echo "PASS: Dynamic node has disappeared!";
  else
    echo "FAIL: Timeout occurred while waiting for dynamic node to disappear.";
  fi
}


# Restart LSF daemons
echo "Restart LSF daemons..."
if sudo su -l root -c 'lsf_daemons restart'; then
    echo "LSF daemons restarted successfully."
else
    echo "FAIL: lsf_daemons restart failed"
    validation_failed=1
fi

# Check LSF status with a timeout
check_command="timeout $timeout_duration bhosts"
startOut=$($check_command)
printf "bhosts value is:\n%s\n" "$startOut"
if [[ ! $startOut == *"LSF is down"* ]]; then
    echo "PASS: LSF is up and running."
else
    echo "FAIL: LSF is not up after $timeout_duration seconds."
    validation_failed=1
fi


# Add timeout for submitting job and waiting
if timeout 480 bash -c '
  # Submit a job that will sleep for 10 seconds
  bsub -n 10 -R "select[cloudhpchost]" sleep 10
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


# Handle validation failures
if [ $validation_failed -eq 1 ]; then
  handle_validation_failure
  echo "FAIL: Daemons-restart Validation issues detected. Script execution failed."
  exit 1  # Failure
else
  echo "PASS: Daemons-restart validations passed successfully."
fi