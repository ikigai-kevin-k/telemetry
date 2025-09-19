#!/bin/bash

# ZCAM Single Device Check Script
# Usage: ./zcam_single_check.sh <device_name> <metric>
# Metrics: rtmp_status, battery_level, camera_mode, bandwidth, health_score

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/zcam_devices.conf"
TIMEOUT=5

# Function to get device IP from config
get_device_ip() {
    local device_name="$1"
    grep "^${device_name}|" "$CONFIG_FILE" | cut -d'|' -f2
}

# Function to make API call
api_call() {
    local ip="$1"
    local endpoint="$2"
    curl -s --max-time $TIMEOUT "http://${ip}${endpoint}" 2>/dev/null
}

# Function to extract JSON value
get_json_value() {
    local json="$1"
    local key="$2"
    echo "$json" | grep -o "\"$key\":[^,}]*" | sed "s/\"$key\"://; s/\"//g"
}

# Check arguments
if [ $# -lt 2 ]; then
    echo "Usage: $0 <device_name> <metric>"
    echo "Available devices: $(grep -v '^#' $CONFIG_FILE | grep -v '^$' | cut -d'|' -f1 | tr '\n' ' ')"
    echo "Available metrics: rtmp_status, battery_level, camera_mode, bandwidth, health_score, resolution, iso"
    exit 1
fi

DEVICE_NAME="$1"
METRIC="$2"

# Get device IP
DEVICE_IP=$(get_device_ip "$DEVICE_NAME")

if [ -z "$DEVICE_IP" ]; then
    echo "ERROR: Device $DEVICE_NAME not found in configuration"
    exit 1
fi

# Check connectivity first
if ! ping -c 1 -W 2 "$DEVICE_IP" &> /dev/null; then
    echo "ERROR: Device $DEVICE_IP is not reachable"
    exit 1
fi

# Handle different metrics
case "$METRIC" in
    "rtmp_status")
        response=$(api_call "$DEVICE_IP" "/ctrl/rtmp?action=query&index=0")
        if [ -n "$response" ]; then
            status=$(get_json_value "$response" "status")
            echo "$status"
        else
            echo "ERROR"
        fi
        ;;
    
    "battery_level")
        response=$(api_call "$DEVICE_IP" "/ctrl/get?k=battery")
        if [ -n "$response" ]; then
            battery=$(get_json_value "$response" "value")
            echo "$battery"
        else
            echo "ERROR"
        fi
        ;;
    
    "camera_mode")
        response=$(api_call "$DEVICE_IP" "/ctrl/mode")
        if [ -n "$response" ]; then
            mode=$(get_json_value "$response" "msg")
            echo "$mode"
        else
            echo "ERROR"
        fi
        ;;
    
    "bandwidth")
        response=$(api_call "$DEVICE_IP" "/ctrl/rtmp?action=query&index=0")
        if [ -n "$response" ]; then
            bw=$(get_json_value "$response" "bw")
            echo "$bw"
        else
            echo "ERROR"
        fi
        ;;
    
    "resolution")
        response=$(api_call "$DEVICE_IP" "/ctrl/get?k=resolution")
        if [ -n "$response" ]; then
            resolution=$(get_json_value "$response" "value")
            echo "$resolution"
        else
            echo "ERROR"
        fi
        ;;
    
    "iso")
        response=$(api_call "$DEVICE_IP" "/ctrl/get?k=iso")
        if [ -n "$response" ]; then
            iso=$(get_json_value "$response" "value")
            echo "$iso"
        else
            echo "ERROR"
        fi
        ;;
    
    "health_score")
        # Calculate simple health score based on key metrics
        health_score=0
        total_checks=0
        
        # Check RTMP
        rtmp_response=$(api_call "$DEVICE_IP" "/ctrl/rtmp?action=query&index=0")
        if [ -n "$rtmp_response" ]; then
            rtmp_status=$(get_json_value "$rtmp_response" "status")
            if [ "$rtmp_status" = "busy" ]; then
                health_score=$((health_score + 1))
            fi
        fi
        total_checks=$((total_checks + 1))
        
        # Check Battery
        battery_response=$(api_call "$DEVICE_IP" "/ctrl/get?k=battery")
        if [ -n "$battery_response" ]; then
            battery_level=$(get_json_value "$battery_response" "value")
            if [ "$battery_level" -ge 30 ]; then
                health_score=$((health_score + 1))
            fi
        fi
        total_checks=$((total_checks + 1))
        
        # Check Mode
        mode_response=$(api_call "$DEVICE_IP" "/ctrl/mode")
        if [ -n "$mode_response" ]; then
            camera_mode=$(get_json_value "$mode_response" "msg")
            if [ "$camera_mode" = "rec" ]; then
                health_score=$((health_score + 1))
            fi
        fi
        total_checks=$((total_checks + 1))
        
        # Return percentage
        health_percentage=$((health_score * 100 / total_checks))
        echo "$health_percentage"
        ;;
    
    *)
        echo "ERROR: Unknown metric $METRIC"
        echo "Available metrics: rtmp_status, battery_level, camera_mode, bandwidth, health_score, resolution, iso"
        exit 1
        ;;
esac
