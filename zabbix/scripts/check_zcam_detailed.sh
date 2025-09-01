#!/bin/bash

# ZCAM Detailed Status Check Script for Zabbix
# This script provides detailed information about ZCAM status

# Set the ZCAM API endpoint
ZCAM_API_URL="http://192.168.88.175/ctrl/rtmp?action=query&index=0"

# Set timeout for curl request (in seconds)
TIMEOUT=10

# Function to log messages
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >&2
}

# Check if curl is available
if ! command -v curl &> /dev/null; then
    log_message "ERROR: curl command not found"
    exit 1
fi

# Check if jq is available for JSON parsing
if ! command -v jq &> /dev/null; then
    log_message "WARNING: jq command not found, will use basic parsing"
    USE_JQ=false
else
    USE_JQ=true
fi

# Function to get specific field value
get_field_value() {
    local response="$1"
    local field="$2"
    
    if [ "$USE_JQ" = true ]; then
        echo "$response" | jq -r ".$field // \"unknown\"" 2>/dev/null || echo "unknown"
    else
        case "$field" in
            "status")
                echo "$response" | grep -o '"status":"[^"]*"' | sed 's/.*"status":"\([^"]*\)".*/\1/' 2>/dev/null || echo "unknown"
                ;;
            "bw")
                echo "$response" | grep -o '"bw":[0-9.]*' | sed 's/.*"bw":\([0-9.]*\)/\1/' 2>/dev/null || echo "unknown"
                ;;
            "url")
                echo "$response" | grep -o '"url":"[^"]*"' | sed 's/.*"url":"\([^"]*\)".*/\1/' 2>/dev/null || echo "unknown"
                ;;
            "code")
                echo "$response" | grep -o '"code":[0-9]*' | sed 's/.*"code":\([0-9]*\)/\1/' 2>/dev/null || echo "unknown"
                ;;
            "autoRestart")
                echo "$response" | grep -o '"autoRestart":[0-9]*' | sed 's/.*"autoRestart":\([0-9]*\)/\1/' 2>/dev/null || echo "unknown"
                ;;
            *)
                echo "unknown"
                ;;
        esac
    fi
}

# Function to get status code description
get_status_description() {
    local code="$1"
    case "$code" in
        "0") echo "success" ;;
        "1") echo "error" ;;
        "2") echo "timeout" ;;
        "3") echo "connection_failed" ;;
        *) echo "unknown_code_$code" ;;
    esac
}

# Function to get status description
get_status_text() {
    local status="$1"
    case "$status" in
        "busy") echo "streaming" ;;
        "idle") echo "not_streaming" ;;
        "error") echo "error_state" ;;
        "offline") echo "offline" ;;
        *) echo "$status" ;;
    esac
}

# Main execution
log_message "Starting detailed ZCAM status check"

# Make the API call
response=$(curl -s --max-time "$TIMEOUT" --connect-timeout "$TIMEOUT" "$ZCAM_API_URL" 2>/dev/null)

# Check if curl was successful
if [ $? -ne 0 ]; then
    log_message "ERROR: Failed to connect to ZCAM API"
    echo "connection_error"
    exit 1
fi

# Check if response is empty
if [ -z "$response" ]; then
    log_message "ERROR: Empty response from ZCAM API"
    echo "empty_response"
    exit 1
fi

# Check if response contains valid JSON structure
if ! echo "$response" | grep -q '{.*}'; then
    log_message "ERROR: Invalid JSON response from ZCAM API"
    echo "invalid_json"
    exit 1
fi

# Extract all fields
status=$(get_field_value "$response" "status")
bandwidth=$(get_field_value "$response" "bw")
url=$(get_field_value "$response" "url")
code=$(get_field_value "$response" "code")
autoRestart=$(get_field_value "$response" "autoRestart")

# Get descriptions
status_desc=$(get_status_text "$status")
code_desc=$(get_status_description "$code")

# Log the parsed values
log_message "Parsed values - Status: $status ($status_desc), Bandwidth: $bandwidth, URL: $url, Code: $code ($code_desc), AutoRestart: $autoRestart"

# Return the main status for Zabbix (this is what Zabbix will use as the item value)
echo "$status"
