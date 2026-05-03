#!/bin/bash

critical_disk_usage=80
timestamp=$(date '+[%Y-%m-%d %H:%M:%S]')
log_file="/app/logs/disk_monitor.log"

mkdir -p "$(dirname "$log_file")"

disk_usage=$(df -h /host | awk 'NR==2 {gsub("%","",$5); print $5}')

if [ $disk_usage -gt $critical_disk_usage ]; then
        echo "$timestamp WARNING: Disk usage at $disk_usage%" >> "$log_file"
else
        echo "$timestamp INFO: Disk usage at $disk_usage%" >> "$log_file"
fi

