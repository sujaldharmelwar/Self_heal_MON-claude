#!/bin/bash

####################################################
# diagnostics.sh
# Root Cause Analysis for nginx
####################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/../config/monitor.conf"
source "$SCRIPT_DIR/logger.sh"

####################################################
# Collect Information
####################################################

SERVICE_STATE="STOPPED"
CONFIG_STATUS="VALID"
PORT_STATUS="FREE"
DISK_STATUS=""
MEMORY_STATUS=""
CPU_STATUS=""
OOM_STATUS="None"
LAST_EVENT="Unknown"
ROOT_CAUSE="Unknown"

####################################################
# Service State
####################################################

if systemctl is-active --quiet "$SERVICE_NAME"; then
    SERVICE_STATE="RUNNING"
fi

####################################################
# Configuration Check
####################################################

if sudo nginx -t >/tmp/nginx_test.log 2>&1; then
    CONFIG_STATUS="VALID"
else
    CONFIG_STATUS="INVALID"
fi

####################################################
# Port Check
####################################################

PORT_OUTPUT=$(sudo ss -tulpn | grep ":80")

if [ -n "$PORT_OUTPUT" ]; then
    if echo "$PORT_OUTPUT" | grep -q "$SERVICE_NAME"; then
        PORT_STATUS="IN USE BY NGINX"
    else
        PORT_STATUS="IN USE BY ANOTHER PROCESS"
    fi
fi

####################################################
# Disk Usage
####################################################

DISK_USED=$(df / | awk 'NR==2 {gsub("%","");print $5}')

if [ "$DISK_USED" -ge 90 ]; then
    DISK_STATUS="${DISK_USED}% (Critical)"
else
    DISK_STATUS="${DISK_USED}% (Healthy)"
fi

####################################################
# Memory Usage
####################################################

MEM_USED=$(free | awk '/Mem:/ {print int($3/$2*100)}')

if [ "$MEM_USED" -ge 90 ]; then
    MEMORY_STATUS="${MEM_USED}% (Critical)"
else
    MEMORY_STATUS="${MEM_USED}% (Healthy)"
fi

####################################################
# CPU Usage
####################################################

CPU_USED=$(top -bn1 | awk '/Cpu/ {print int($2+$4)}')

if [ "$CPU_USED" -ge 90 ]; then
    CPU_STATUS="${CPU_USED}% (High)"
else
    CPU_STATUS="${CPU_USED}% (Normal)"
fi

####################################################
# OOM Detection
####################################################

if sudo journalctl -k | grep -qi "Out of memory"; then
    OOM_STATUS="Detected"
fi

####################################################
# Last Service Event
####################################################

LAST_EVENT=$(sudo journalctl -u "$SERVICE_NAME" -n 5 --no-pager | tail -1)

####################################################
# Root Cause Analysis
####################################################

if [ "$CONFIG_STATUS" = "INVALID" ]; then

    ROOT_CAUSE="Invalid nginx configuration."

elif [ "$PORT_STATUS" = "IN USE BY ANOTHER PROCESS" ]; then

    ROOT_CAUSE="Port 80 is already occupied."

elif [ "$OOM_STATUS" = "Detected" ]; then

    ROOT_CAUSE="nginx terminated by OOM Killer."

elif [ "$DISK_USED" -ge 95 ]; then

    ROOT_CAUSE="Disk space critically low."

elif echo "$LAST_EVENT" | grep -qi "Stopped"; then

    ROOT_CAUSE="Service was stopped gracefully."

elif echo "$LAST_EVENT" | grep -qi "Failed"; then

    ROOT_CAUSE="Service failed unexpectedly."

else

    ROOT_CAUSE="Unable to determine exact root cause."

fi

####################################################
# Print Summary
####################################################

echo
echo "======================================================"
echo "              ROOT CAUSE ANALYSIS"
echo "======================================================"

printf "%-22s : %s\n" "Service State" "$SERVICE_STATE"
printf "%-22s : %s\n" "Configuration" "$CONFIG_STATUS"
printf "%-22s : %s\n" "Port 80" "$PORT_STATUS"
printf "%-22s : %s\n" "Disk Usage" "$DISK_STATUS"
printf "%-22s : %s\n" "Memory Usage" "$MEMORY_STATUS"
printf "%-22s : %s\n" "CPU Usage" "$CPU_STATUS"
printf "%-22s : %s\n" "OOM Events" "$OOM_STATUS"
printf "%-22s : %s\n" "Last Service Event" "$LAST_EVENT"

echo
echo "------------------------------------------------------"
echo "PROBABLE ROOT CAUSE"
echo "------------------------------------------------------"

echo "$ROOT_CAUSE"

echo
echo "------------------------------------------------------"
echo "RECOVERY ACTION"
echo "------------------------------------------------------"

echo "Recovery will be attempted by process_check.sh"

echo
echo "======================================================"

####################################################
# Detailed Logs (Optional)
####################################################

log_info ""
log_info "===== systemctl status ====="
sudo systemctl status "$SERVICE_NAME" --no-pager

log_info ""
log_info "===== nginx configuration test ====="
cat /tmp/nginx_test.log

log_info ""
log_info "===== Recent journal ====="
sudo journalctl -u "$SERVICE_NAME" -n 20 --no-pager
