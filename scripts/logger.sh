#!/bin/bash

####################################################
# Logger Functions
####################################################

write_report() {
    # Write to report only if REPORT_FILE is set
    if [ -n "$REPORT_FILE" ]; then
        echo "$1" >> "$REPORT_FILE"
    fi
}

log_info() {
    local MESSAGE="$1"
    local LOG_MSG="$(date '+%Y-%m-%d %H:%M:%S') [INFO]  $MESSAGE"

    echo "$LOG_MSG"
    write_report "$LOG_MSG"
}

log_warn() {
    local MESSAGE="$1"
    local LOG_MSG="$(date '+%Y-%m-%d %H:%M:%S') [WARN]  $MESSAGE"

    echo "$LOG_MSG"
    write_report "$LOG_MSG"
}

log_error() {
    local MESSAGE="$1"
    local LOG_MSG="$(date '+%Y-%m-%d %H:%M:%S') [ERROR] $MESSAGE"

    echo "$LOG_MSG"
    write_report "$LOG_MSG"
}

log_step() {
    local MESSAGE="$1"

    echo ""
    echo "-------------------------------------------------"
    echo "STEP: $MESSAGE"
    echo "-------------------------------------------------"

    if [ -n "$REPORT_FILE" ]; then
        {
            echo ""
            echo "-------------------------------------------------"
            echo "STEP: $MESSAGE"
            echo "-------------------------------------------------"
        } >> "$REPORT_FILE"
    fi
}
