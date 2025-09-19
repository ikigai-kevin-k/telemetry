#!/bin/bash

# ZCAM Multi-Device Monitoring Script
# This script monitors multiple ZCAM devices based on configuration file

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/zcam_devices.conf"
LOGFILE="/tmp/zcam_multi_monitor.log"
TIMEOUT=5

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Function to log with timestamp
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOGFILE"
}

# Function to make API call with error handling
api_call() {
    local ip="$1"
    local endpoint="$2"
    local description="$3"
    
    response=$(curl -s --max-time $TIMEOUT "http://${ip}${endpoint}" 2>/dev/null)
    if [ $? -eq 0 ] && [ -n "$response" ]; then
        echo "$response"
        log_message "SUCCESS: $ip - $description - $response"
        return 0
    else
        log_message "ERROR: $ip - $description - Failed to get response"
        return 1
    fi
}

# Function to extract JSON value
get_json_value() {
    local json="$1"
    local key="$2"
    echo "$json" | grep -o "\"$key\":[^,}]*" | sed "s/\"$key\"://; s/\"//g"
}

# Function to monitor single ZCAM device
monitor_zcam() {
    local device_name="$1"
    local ip="$2"
    local agent_name="$3"
    local rtmp_server="$4"
    local stream_key="$5"
    
    echo -e "${PURPLE}=== $device_name ($agent_name) ===${NC}"
    echo "IP: $ip | RTMP Server: $rtmp_server | Stream: $stream_key"
    echo ""
    
    local health_score=0
    local total_checks=0
    local issues=()
    
    # Test connectivity
    echo -e "${CYAN}1. Connectivity Test${NC}"
    if ping -c 1 -W 2 $ip &> /dev/null; then
        echo -e "   ${GREEN}✓${NC} Host $ip is reachable"
        health_score=$((health_score + 1))
    else
        echo -e "   ${RED}✗${NC} Host $ip is not reachable"
        issues+=("$device_name: Host unreachable")
        echo ""
        return 1
    fi
    total_checks=$((total_checks + 1))
    
    # RTMP Status
    echo -e "${CYAN}2. RTMP Status${NC}"
    rtmp_response=$(api_call "$ip" "/ctrl/rtmp?action=query&index=0" "RTMP Status")
    if [ $? -eq 0 ]; then
        rtmp_status=$(get_json_value "$rtmp_response" "status")
        rtmp_url=$(get_json_value "$rtmp_response" "url")
        rtmp_bw=$(get_json_value "$rtmp_response" "bw")
        rtmp_restart=$(get_json_value "$rtmp_response" "autoRestart")
        
        echo "   Stream URL: $rtmp_url"
        
        if [ "$rtmp_status" = "busy" ]; then
            echo -e "   Status: ${GREEN}$rtmp_status${NC} (Streaming active)"
            health_score=$((health_score + 1))
        else
            echo -e "   Status: ${RED}$rtmp_status${NC} (Not streaming)"
            issues+=("$device_name: Not streaming")
        fi
        
        echo "   Bandwidth: ${rtmp_bw} Mbps"
        echo "   Auto Restart: $([ "$rtmp_restart" = "1" ] && echo "Enabled" || echo "Disabled")"
        
        # Validate expected stream URL
        expected_stream="rtmp://${rtmp_server}:1935/live/${stream_key}"
        if [ "$rtmp_url" = "$expected_stream" ]; then
            echo -e "   Stream Config: ${GREEN}✓ Correct${NC}"
        else
            echo -e "   Stream Config: ${YELLOW}⚠ Unexpected${NC}"
            echo "   Expected: $expected_stream"
            issues+=("$device_name: Unexpected stream URL")
        fi
    else
        echo -e "   ${RED}✗${NC} Failed to get RTMP status"
        issues+=("$device_name: RTMP API failed")
    fi
    total_checks=$((total_checks + 1))
    
    # Battery Status
    echo -e "${CYAN}3. Battery${NC}"
    battery_response=$(api_call "$ip" "/ctrl/get?k=battery" "Battery Level")
    if [ $? -eq 0 ]; then
        battery_level=$(get_json_value "$battery_response" "value")
        
        if [ "$battery_level" -ge 80 ]; then
            echo -e "   Battery: ${GREEN}${battery_level}%${NC} (Good)"
            health_score=$((health_score + 1))
        elif [ "$battery_level" -ge 30 ]; then
            echo -e "   Battery: ${YELLOW}${battery_level}%${NC} (Medium)"
            health_score=$((health_score + 1))
            issues+=("$device_name: Battery medium ($battery_level%)")
        else
            echo -e "   Battery: ${RED}${battery_level}%${NC} (Low)"
            issues+=("$device_name: Battery low ($battery_level%)")
        fi
    else
        echo -e "   ${RED}✗${NC} Failed to get battery status"
        issues+=("$device_name: Battery API failed")
    fi
    total_checks=$((total_checks + 1))
    
    # Camera Mode
    echo -e "${CYAN}4. Camera Mode${NC}"
    mode_response=$(api_call "$ip" "/ctrl/mode" "Camera Mode")
    if [ $? -eq 0 ]; then
        camera_mode=$(get_json_value "$mode_response" "msg")
        echo "   Mode: $camera_mode"
        
        if [ "$camera_mode" = "rec" ]; then
            echo -e "   Status: ${GREEN}Recording Mode${NC}"
            health_score=$((health_score + 1))
        else
            echo -e "   Status: ${YELLOW}$camera_mode Mode${NC}"
            issues+=("$device_name: Not in recording mode")
        fi
    else
        echo -e "   ${RED}✗${NC} Failed to get camera mode"
        issues+=("$device_name: Mode API failed")
    fi
    total_checks=$((total_checks + 1))
    
    # Quick Settings Check
    echo -e "${CYAN}5. Settings${NC}"
    
    # Resolution
    resolution_response=$(api_call "$ip" "/ctrl/get?k=resolution" "Resolution")
    if [ $? -eq 0 ]; then
        resolution=$(get_json_value "$resolution_response" "value")
        echo "   Resolution: $resolution"
    else
        echo -e "   Resolution: ${RED}Failed${NC}"
    fi
    
    # ISO
    iso_response=$(api_call "$ip" "/ctrl/get?k=iso" "ISO")
    if [ $? -eq 0 ]; then
        iso=$(get_json_value "$iso_response" "value")
        echo "   ISO: $iso"
    else
        echo -e "   ISO: ${RED}Failed${NC}"
    fi
    
    # Calculate health percentage
    health_percentage=$((health_score * 100 / total_checks))
    
    echo ""
    echo -e "${CYAN}6. Summary${NC}"
    echo "   Health Score: $health_score/$total_checks ($health_percentage%)"
    
    if [ "$health_percentage" -ge 80 ]; then
        echo -e "   Status: ${GREEN}HEALTHY${NC}"
        device_status="HEALTHY"
    elif [ "$health_percentage" -ge 60 ]; then
        echo -e "   Status: ${YELLOW}WARNING${NC}"
        device_status="WARNING"
    else
        echo -e "   Status: ${RED}CRITICAL${NC}"
        device_status="CRITICAL"
    fi
    
    echo ""
    echo "----------------------------------------"
    echo ""
    
    # Return values for global summary
    echo "$device_name|$health_percentage|$device_status|$(IFS=';'; echo "${issues[*]}")"
}

# Main execution
echo -e "${BLUE}=== ZCAM Multi-Device Monitor ===${NC}"
echo "Time: $(date)"
echo "Config: $CONFIG_FILE"
echo ""

# Check if config file exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${RED}ERROR: Configuration file not found: $CONFIG_FILE${NC}"
    exit 1
fi

# Initialize global counters
total_devices=0
healthy_devices=0
warning_devices=0
critical_devices=0
all_issues=()
device_results=()

# Read configuration and monitor each device
while IFS='|' read -r device_name ip agent_name rtmp_server stream_key; do
    # Skip comments and empty lines
    [[ $device_name =~ ^#.*$ ]] && continue
    [[ -z "$device_name" ]] && continue
    
    total_devices=$((total_devices + 1))
    
    # Monitor device and capture result
    result=$(monitor_zcam "$device_name" "$ip" "$agent_name" "$rtmp_server" "$stream_key")
    device_results+=("$result")
    
    # Parse result for global summary
    if echo "$result" | tail -1 | grep -q "HEALTHY"; then
        healthy_devices=$((healthy_devices + 1))
    elif echo "$result" | tail -1 | grep -q "WARNING"; then
        warning_devices=$((warning_devices + 1))
    else
        critical_devices=$((critical_devices + 1))
    fi
    
    # Collect issues
    issues_line=$(echo "$result" | tail -1 | cut -d'|' -f4)
    if [ -n "$issues_line" ]; then
        IFS=';' read -ra ISSUES <<< "$issues_line"
        for issue in "${ISSUES[@]}"; do
            [ -n "$issue" ] && all_issues+=("$issue")
        done
    fi
    
done < "$CONFIG_FILE"

# Global Summary
echo -e "${BLUE}=== GLOBAL SUMMARY ===${NC}"
echo "Total Devices: $total_devices"
echo -e "Healthy: ${GREEN}$healthy_devices${NC}"
echo -e "Warning: ${YELLOW}$warning_devices${NC}"
echo -e "Critical: ${RED}$critical_devices${NC}"
echo ""

# Overall system health
overall_health=$((healthy_devices * 100 / total_devices))

if [ "$overall_health" -ge 80 ]; then
    echo -e "Overall Status: ${GREEN}SYSTEM HEALTHY${NC} ($overall_health%)"
    exit_code=0
elif [ "$overall_health" -ge 60 ]; then
    echo -e "Overall Status: ${YELLOW}SYSTEM WARNING${NC} ($overall_health%)"
    exit_code=1
else
    echo -e "Overall Status: ${RED}SYSTEM CRITICAL${NC} ($overall_health%)"
    exit_code=2
fi

# Show issues if any
if [ ${#all_issues[@]} -gt 0 ]; then
    echo ""
    echo -e "${YELLOW}Issues Found:${NC}"
    for issue in "${all_issues[@]}"; do
        echo -e "   ${YELLOW}⚠${NC} $issue"
    done
fi

echo ""
echo "Log file: $LOGFILE"
echo -e "${BLUE}=== Monitor Complete ===${NC}"

exit $exit_code
