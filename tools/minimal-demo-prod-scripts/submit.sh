#!/usr/bin/env bash

# Sample Job Submission
# ---------------------
# This example submits a simple LSF job that:
#   - Requests 8 cores (-n 8)
#   - Runs the command: sleep 30
#
# You can modify the command (e.g., sleep 30) or job options (-n 8)
# to suit your own workload requirements.

CMD="bsub -n 8 sleep 30"
echo "Running: $CMD"
$CMD
