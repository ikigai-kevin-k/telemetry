#!/bin/bash

# ZCAM Status Check Script for Zabbix
# This script checks the status of ZCAM by calling the RTMP API endpoint

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

# Function to parse JSON response
parse_json_response() {
    local response="$1"
    
    if [ "$USE_JQ" = true ]; then
        # Use jq for proper JSON parsing
        echo "$response" | jq -r '.status' 2>/dev/null || echo "parse_error"
    else
        # Basic parsing using grep and sed (fallback)
        echo "$response" | grep -o '"status":"[^"]*"' | sed 's/.*"status":"\([^"]*\)".*/\1/' 2>/dev/null || echo "parse_error"
    fi
}

# Function to extract bandwidth value
parse_bandwidth() {
    local response="$1"
    
    if [ "$USE_JQ" = true ]; then
        echo "$response" | jq -r '.bw // "unknown"' 2>/dev/null || echo "unknown"
    else
        echo "$response" | grep -o '"bw":[0-9.]*' | sed 's/.*"bw":\([0-9.]*\)/\1/' 2>/dev/null || echo "unknown"
    fi
}

# Function to extract URL
parse_url() {
    local response="$1"
    
    if [ "$USE_JQ" = true ]; then
        echo "$response" | jq -r '.url // "unknown"' 2>/dev/null || echo "unknown"
    else
        echo "$response" | grep -o '"url":"[^"]*"' | sed 's/.*"url":"\([^"]*\)".*/\1/' 2>/dev/null || echo "unknown"
    fi
}

# Function to extract code
parse_code() {
    local response="$1"
    
    if [ "$USE_JQ" = true ]; then
        echo "$response" | jq -r '.code // "unknown"' 2>/dev/null || echo "unknown"
    else
        echo "$response" | grep -o '"code":[0-9]*' | sed 's/.*"code":\([0-9]*\)/\1/' 2>/dev/null || echo "unknown"
    fi
}

# Main execution
log_message "Starting ZCAM status check"

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

# Parse the response
status=$(parse_json_response "$response")
bandwidth=$(parse_bandwidth "$response")
url=$(parse_url "$response")
code=$(parse_code "$response")

# Log the parsed values
log_message "Parsed values - Status: $status, Bandwidth: $bandwidth, URL: $url, Code: $code"

# Return the status for Zabbix
echo "$status"
