#!/bin/bash

###################################################
# Copyright (C) IBM Corp. 2023 All Rights Reserved.
# Licensed under the Apache License v2.0
###################################################

###################################################
# Script Description:
# This script performs validation checks and actions on an IBM Cloud HPC cluster environment.
# It waits for a dynamic compute resource to disappear, handling validation failures and terminating
# the script with status code 1 in case of issues. The script ensures the proper removal of the dynamic
# compute resource before exiting.
###################################################

validation_failed=0

# Function to handle validation failures
destroy_dynamic_compute_resources() {
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
        bhosts -w | grep "ok"
        echo "CHECKING: Waiting for dynamic node to disappear..."
        sleep 60
    done
  '; then
    echo "PASS: Dynamic node has disappeared!"
  else
    echo "FAIL: Timeout occurred while waiting for the dynamic node to disappear."
    validation_failed=1
  fi
}

destroy_dynamic_compute_resources

# Handle validation failures
if [ $validation_failed -eq 1 ]; then
  echo "FAIL: Dynamic compute node destruction validation issues detected. Script execution failed."
  exit 1  # Failure
else
  echo "PASS: Dynamic compute node destruction validations passed successfully."
fi
