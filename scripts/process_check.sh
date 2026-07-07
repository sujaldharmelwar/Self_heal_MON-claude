#!/bin/bash

####################################################
# Self-Healing Monitoring - Main Script
####################################################

# Load configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config/monitor.conf"
source "$SCRIPT_DIR/logger.sh"

REPORT_FILE="$REPORT_DIR/report_$(date +%F_%H-%M-%S).log"

mkdir -p "$REPORT_DIR"
touch "$REPORT_FILE"

log_info "========================================"
log_info "Self-Healing Monitoring Started"
log_info "Hostname : $(hostname)"
log_info "Time     : $(date)"
log_info "========================================"

# Small helper so we always print a plain-English RUNNING / NOT RUNNING
# status, instead of only logging when something is wrong.
check_status() {
    pgrep -x "$SERVICE_NAME" > /dev/null 2>&1
}

####################################################
# Step 1: Initial Status Check
####################################################

log_step "1/4 - Checking current status of $SERVICE_NAME"

if check_status; then
    PID=$(pgrep -x "$SERVICE_NAME")
    log_info "Status: $SERVICE_NAME IS RUNNING (PID: $PID)"
else
    log_warn "Status: $SERVICE_NAME IS NOT RUNNING"
fi

####################################################
# Step 2: Start Service If Needed
####################################################

if ! check_status; then
    log_step "2/4 - Starting $SERVICE_NAME"

    log_info "Running: sudo systemctl start $SERVICE_NAME"
    sudo systemctl start "$SERVICE_NAME"

    log_info "Waiting ${WAIT_TIME}s for service to come up..."
    sleep "$WAIT_TIME"

    if check_status; then
        PID=$(pgrep -x "$SERVICE_NAME")
        log_info "Status after start attempt: $SERVICE_NAME IS RUNNING (PID: $PID)"
    else
        log_error "Status after start attempt: $SERVICE_NAME IS STILL NOT RUNNING"
        log_error "Could not start $SERVICE_NAME. Collecting diagnostics..."

        "$SCRIPT_DIR/diagnostics.sh"

        log_error "RESULT: FAILED - service would not start. See diagnostics above."
        exit 1
    fi
else
    log_step "2/4 - Starting $SERVICE_NAME"
    log_info "Skipped - service was already running."
fi

####################################################
# Step 3: HTTP Health Check
####################################################

log_step "3/4 - Running HTTP health check ($HEALTH_URL)"

HTTP_CODE=$(curl -o /dev/null -s -w "%{http_code}" "$HEALTH_URL")

log_info "HTTP response code: $HTTP_CODE"

if [ "$HTTP_CODE" = "200" ]; then
    log_info "Status: HEALTH CHECK PASSED"
    log_info "RESULT: SUCCESS - $SERVICE_NAME is running and healthy."
    exit 0
fi

log_warn "Status: HEALTH CHECK FAILED (got HTTP $HTTP_CODE, expected 200)"

####################################################
# Step 4: Recovery - Restart and Recheck
####################################################

log_step "4/4 - Health check failed - attempting recovery"

log_info "Collecting diagnostics before restart..."
"$SCRIPT_DIR/diagnostics.sh"

log_info "Running: sudo systemctl restart $SERVICE_NAME"
sudo systemctl restart "$SERVICE_NAME"

log_info "Waiting ${WAIT_TIME}s before re-checking..."
sleep "$WAIT_TIME"

if check_status; then
    PID=$(pgrep -x "$SERVICE_NAME")
    log_info "Status after restart: $SERVICE_NAME IS RUNNING (PID: $PID)"
else
    log_error "Status after restart: $SERVICE_NAME IS NOT RUNNING"
fi

log_info "Re-running HTTP health check..."
HTTP_CODE=$(curl -o /dev/null -s -w "%{http_code}" "$HEALTH_URL")
log_info "HTTP response code: $HTTP_CODE"

if [ "$HTTP_CODE" = "200" ]; then
    log_info "Status: HEALTH CHECK PASSED"
    log_info "RESULT: SUCCESS - recovered after restart."
    exit 0
fi

####################################################
# Critical Failure
####################################################

log_error "Status: HEALTH CHECK FAILED AGAIN (got HTTP $HTTP_CODE, expected 200)"
log_error "Collecting final diagnostics..."

"$SCRIPT_DIR/diagnostics.sh"

log_error "RESULT: CRITICAL FAILURE - $SERVICE_NAME did not recover. See diagnostics above and report at $REPORT_FILE"

exit 1