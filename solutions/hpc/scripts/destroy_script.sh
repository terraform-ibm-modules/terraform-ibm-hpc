#!/bin/bash

badmin qclose all
bkill -u all
while true; do
    if (bhosts -o status) | grep ok; then
        sleep 1m
    else
        sleep 2m
        exit 0
    fi
done
