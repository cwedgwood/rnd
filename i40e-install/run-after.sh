#!/bin/bash

modprobe i40e
v=$(cat /sys/module/i40e/version)
echo -en "\\ecRunning after ... version: $v.\n\n"
touch /tmp/i-ran.$v
pstree > /tmp/process-when-run.txt

#while : ; do
#    date
#    sleep 10
#done
exit 0
