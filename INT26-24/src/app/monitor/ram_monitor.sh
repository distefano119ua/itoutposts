#!/bin/bash

critical_ram_usage=85
timestamp=$(date '+[%Y-%m-%d %H:%M:%S]')
log_file="/app/logs/ram_monitor.log"

mkdir -p "$(dirname "$log_file")"

meminfo="/host/proc/meminfo"

total_kb=$(awk '/^MemTotal:/ {print $2}' "$meminfo")
available_kb=$(awk '/^MemAvailable:/ {print $2}' "$meminfo")

used_kb=$((total_kb - available_kb))
used_p=$((used_kb * 100 / total_kb))

used_gb=$(awk -v kb="$used_kb" 'BEGIN {printf "%.1f", kb / 1024 / 1024}')
total_gb=$(awk -v kb="$total_kb" 'BEGIN {printf "%.1f", kb / 1024 / 1024}')

ram_used_h="${used_gb}G/${total_gb}G used"

if [ "$used_p" -gt "$critical_ram_usage" ]; then
    echo "$timestamp WARNING: RAM usage at $used_p% ($ram_used_h)" >> "$log_file"
else
    echo "$timestamp INFO: RAM usage at $used_p% ($ram_used_h)" >> "$log_file"
fi