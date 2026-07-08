#!/bin/bash

####################################################
# diagnostics.sh
# Collect Root Cause Information for nginx
####################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/../config/monitor.conf"
source "$SCRIPT_DIR/logger.sh"

log_info "========== ROOT CAUSE DIAGNOSTICS =========="

log_info "Hostname : $(hostname)"
log_info "Time     : $(date)"

####################################################
# Service Status
####################################################

log_info ""
log_info "===== systemctl status ====="

sudo systemctl status "$SERVICE_NAME" --no-pager

####################################################
# Recent Service Logs
####################################################

log_info ""
log_info "===== journalctl ====="

sudo journalctl -u "$SERVICE_NAME" -n 50 --no-pager

####################################################
# Configuration Validation
####################################################

log_info ""
log_info "===== nginx configuration test ====="

sudo nginx -t

####################################################
# Error Log
####################################################

log_info ""
log_info "===== nginx error.log ====="

sudo tail -50 /var/log/nginx/error.log

####################################################
# Port Usage
####################################################

log_info ""
log_info "===== Port 80 Usage ====="

sudo ss -tulpn | grep :80 || echo "Nothing is using port 80"

####################################################
# Disk Usage
####################################################

log_info ""
log_info "===== Disk Usage ====="

df -h

####################################################
# Memory Usage
####################################################

log_info ""
log_info "===== Memory Usage ====="

free -h

####################################################
# CPU Usage
####################################################

log_info ""
log_info "===== Top CPU Processes ====="

ps -eo pid,ppid,cmd,%mem,%cpu --sort=-%cpu | head

####################################################
# OOM Killer
####################################################

log_info ""
log_info "===== OOM Events ====="

sudo journalctl -k | grep -i oom || true

log_info ""
log_info "========== END OF DIAGNOSTICS =========="
