#!/bin/bash

####################################################
# Logger Functions
####################################################

log_info() {
    local MESSAGE="$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO]  $MESSAGE"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO]  $MESSAGE" >> "$REPORT_FILE"
}

log_warn() {
    local MESSAGE="$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [WARN]  $MESSAGE"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [WARN]  $MESSAGE" >> "$REPORT_FILE"
}

log_error() {
    local MESSAGE="$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR] $MESSAGE"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR] $MESSAGE" >> "$REPORT_FILE"
}

# Prints a clear section divider so each stage is easy to spot in the
# Jenkins console output.
log_step() {
    local MESSAGE="$1"
    echo ""
    echo "-------------------------------------------------"
    echo "STEP: $MESSAGE"
    echo "-------------------------------------------------"
    {
        echo ""
        echo "-------------------------------------------------"
        echo "STEP: $MESSAGE"
        echo "-------------------------------------------------"
    } >> "$REPORT_FILE"
}