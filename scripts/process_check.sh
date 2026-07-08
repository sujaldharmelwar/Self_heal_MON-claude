#!/bin/bash

####################################################
# Self-Healing Monitoring - Main Script
####################################################

#---------------------------------------------------
# Load configuration files
#---------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/../config/monitor.conf"
source "$SCRIPT_DIR/logger.sh"

#---------------------------------------------------
# Create report file
#---------------------------------------------------
REPORT_FILE="$REPORT_DIR/report_$(date +%F_%H-%M-%S).log"

mkdir -p "$REPORT_DIR"
touch "$REPORT_FILE"

#---------------------------------------------------
# NEW: Export REPORT_FILE so child scripts
# (diagnostics.sh, logger.sh) can use it
#---------------------------------------------------
export REPORT_FILE

#---------------------------------------------------
# Banner
#---------------------------------------------------
log_info "=================================================="
log_info "      SELF-HEALING MONITORING STARTED"
log_info "=================================================="
log_info "Hostname : $(hostname)"
log_info "Service  : $SERVICE_NAME"
log_info "Time     : $(date)"
log_info "Report   : $REPORT_FILE"
log_info "=================================================="

####################################################
# Helper Function
####################################################

check_status() {
    pgrep -x "$SERVICE_NAME" > /dev/null 2>&1
}

####################################################
# STEP 1 - Check Current Service Status
####################################################

log_step "STEP 1/4 - Checking current status of $SERVICE_NAME"

if check_status; then
    PID=$(pgrep -x "$SERVICE_NAME")

    log_info "Current Status : RUNNING"
    log_info "PID            : $PID"

else
    log_warn "Current Status : NOT RUNNING"
fi

####################################################
# STEP 2 - Service Recovery (Only if Stopped)
####################################################

if ! check_status; then

    log_step "STEP 2/4 - Service Recovery"

    log_warn "$SERVICE_NAME is DOWN."

    log_info "Collecting root cause BEFORE attempting recovery..."

    "$SCRIPT_DIR/diagnostics.sh"

    log_info "Attempting to START $SERVICE_NAME..."

    sudo systemctl start "$SERVICE_NAME"

    log_info "Waiting ${WAIT_TIME} seconds..."
    sleep "$WAIT_TIME"

    if check_status; then

        PID=$(pgrep -x "$SERVICE_NAME")

        log_info "Recovery Result : SUCCESS"
        log_info "$SERVICE_NAME started successfully."
        log_info "PID : $PID"

    else

        log_error "Recovery Result : FAILED"
        log_error "$SERVICE_NAME could not be started."

        log_info "Collecting diagnostics AFTER failed start..."

        "$SCRIPT_DIR/diagnostics.sh"

        log_error "SCRIPT TERMINATED"

        exit 1

    fi

else

    log_step "STEP 2/4 - Service Recovery"

    log_info "Recovery skipped because service is already running."

fi

####################################################
# STEP 3 - HTTP Health Check
####################################################

log_step "STEP 3/4 - HTTP Health Check"

log_info "Checking URL : $HEALTH_URL"

HTTP_CODE=$(curl -o /dev/null -s -w "%{http_code}" "$HEALTH_URL")

log_info "HTTP Response Code : $HTTP_CODE"

if [ "$HTTP_CODE" = "200" ]; then

    log_info "Health Check : PASSED"

    log_info "=================================================="
    log_info "FINAL RESULT : SUCCESS"
    log_info "$SERVICE_NAME is running and healthy."
    log_info "=================================================="

    exit 0

fi

log_warn "Health Check : FAILED"

####################################################
# STEP 4 - Restart Service
####################################################

log_step "STEP 4/4 - Restart Service"

log_warn "Service is running but application is unhealthy."

log_info "Collecting diagnostics BEFORE restart..."

"$SCRIPT_DIR/diagnostics.sh"

log_info "Restarting $SERVICE_NAME..."

sudo systemctl restart "$SERVICE_NAME"

log_info "Waiting ${WAIT_TIME} seconds..."

sleep "$WAIT_TIME"

if check_status; then

    PID=$(pgrep -x "$SERVICE_NAME")

    log_info "$SERVICE_NAME restarted successfully."
    log_info "PID : $PID"

else

    log_error "$SERVICE_NAME is NOT running after restart."

fi

####################################################
# Final Health Check
####################################################

log_info "Running final HTTP Health Check..."

HTTP_CODE=$(curl -o /dev/null -s -w "%{http_code}" "$HEALTH_URL")

log_info "HTTP Response Code : $HTTP_CODE"

if [ "$HTTP_CODE" = "200" ]; then

    log_info "=================================================="
    log_info "FINAL RESULT : SUCCESS"
    log_info "Service recovered after restart."
    log_info "=================================================="

    exit 0

fi

####################################################
# Critical Failure
####################################################

log_error "Health Check FAILED after restart."

log_info "Collecting FINAL diagnostics..."

"$SCRIPT_DIR/diagnostics.sh"

log_error "=================================================="
log_error "FINAL RESULT : CRITICAL FAILURE"
log_error "$SERVICE_NAME could not be recovered."
log_error "Manual intervention required."
log_error "=================================================="

exit 1
