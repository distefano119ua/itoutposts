#!/bin/bash

critical_ram_usage=85
timestamp=$(date '+[%Y-%m-%d %H:%M:%S]')
ram_used_h=$(free -m | awk '/^Mem:/ {printf "%.1fG/%.0fG used", $3/1024, $2/1024}')
log_file="/var/log/monitor/ram_monitor.log"

read total used < <(free -m | awk '/^Mem:/ {print $2, $3}')

used_p=$(($used/($total/100)))

if [ $used_p -gt $critical_ram_usage ]; then
        echo "$timestamp WARNING: RAM usage at $used_p% ($ram_used_h)" >> "$log_file"
else
        echo "$timestamp INFO: RAM usage at $used_p% ($ram_used_h)"
fi
