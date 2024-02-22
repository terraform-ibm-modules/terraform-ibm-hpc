#!/bin/bash

###################################################
# Copyright (C) IBM Corp. 2023 All Rights Reserved.
# Licensed under the Apache License v2.0
###################################################

###################################################
# Script Description:
# This script performs validation checks and actions on an IBM Cloud HPC cluster environment.
# It encompasses stopping and starting the sbd daemon, and submitting a job.
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
  fi
}

# Stop sbd daemon
echo "Stopping sbd daemon..."
bctrld stop sbd
sleep 60

# Check if sbd daemon was successfully stopped
checkString="unreach"
expectedCount=1
if [[ $(bhosts | grep -o "$checkString" | wc -l) -ne $expectedCount ]]; then
    echo "Operation failed: Failed to stop the sbd daemon on the management node"
    printf "bhosts value is:\n%s\n" "$(bhosts -w)"
    validation_failed=1
fi

# Main script
if timeout 480 sh -c '
    # Submit a job that will sleep for 10 seconds
    bsub -n 10 -R "select[cloudhpchost]" sleep 10;
    # Wait for the job to complete
    while bjobs | grep -Ew "PEND|RUN"; do
        echo "WAIT: Waiting for job to complete..."
        sleep 60;
    done;
    echo "PASS: Job is complete!";
'; then
    echo "PASS: Command completed within the allowed time..";
else
    echo "FAIL: Timeout occurred.";
    validation_failed=1
fi


# Start sbd daemon
echo "Starting sbd daemon..."
sudo su -l root -c 'bctrld start sbd'
sleep 60

# Check if sbd daemon was successfully started
checkString="unreach"
expectedCount=0
if [[ $(bhosts | grep -o "$checkString" | wc -l) -ne $expectedCount ]]; then
    echo "Operation failed: Failed to start the sbd daemon on the management node"
    printf "bhosts value is:\n%s\n" "$(bhosts -w)"
    validation_failed=1
fi

# Handle validation failures
if [ $validation_failed -eq 1 ]; then
  handle_validation_failure
  echo "FAIL: FailOver and Fail back Validation issues detected. Script execution failed."
  exit 1  # Failure
else
  echo "PASS: FailOver and Fail back validations passed successfully."
fi
