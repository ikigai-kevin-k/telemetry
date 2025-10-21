#!/bin/bash

# ZCAM Comprehensive Monitoring Script
# This script monitors all available ZCAM API endpoints and provides detailed status information

ZCAM_IP="192.168.88.175"
BASE_URL="http://${ZCAM_IP}"
TIMEOUT=5
LOGFILE="/tmp/zcam_monitor.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to log with timestamp
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOGFILE"
}

# Function to make API call with error handling
api_call() {
    local endpoint="$1"
    local description="$2"
    
    response=$(curl -s --max-time $TIMEOUT "${BASE_URL}${endpoint}" 2>/dev/null)
    if [ $? -eq 0 ] && [ -n "$response" ]; then
        echo "$response"
        log_message "SUCCESS: $description - $response"
        return 0
    else
        log_message "ERROR: $description - Failed to get response"
        return 1
    fi
}

# Function to extract JSON value
get_json_value() {
    local json="$1"
    local key="$2"
    echo "$json" | grep -o "\"$key\":[^,}]*" | sed "s/\"$key\"://; s/\"//g"
}

echo -e "${BLUE}=== ZCAM Comprehensive Monitor ===${NC}"
echo "Target: $ZCAM_IP"
echo "Time: $(date)"
echo ""

# Test basic connectivity first
echo -e "${BLUE}1. Connectivity Test${NC}"
if ping -c 1 -W 2 $ZCAM_IP &> /dev/null; then
    echo -e "   ${GREEN}✓${NC} Host $ZCAM_IP is reachable"
else
    echo -e "   ${RED}✗${NC} Host $ZCAM_IP is not reachable"
    exit 1
fi
echo ""

# Monitor RTMP Status
echo -e "${BLUE}2. RTMP Streaming Status${NC}"
rtmp_response=$(api_call "/ctrl/rtmp?action=query&index=0" "RTMP Status")
if [ $? -eq 0 ]; then
    rtmp_status=$(get_json_value "$rtmp_response" "status")
    rtmp_url=$(get_json_value "$rtmp_response" "url")
    rtmp_bw=$(get_json_value "$rtmp_response" "bw")
    rtmp_restart=$(get_json_value "$rtmp_response" "autoRestart")
    
    echo "   Stream URL: $rtmp_url"
    
    if [ "$rtmp_status" = "busy" ]; then
        echo -e "   Status: ${GREEN}$rtmp_status${NC} (Streaming active)"
    else
        echo -e "   Status: ${RED}$rtmp_status${NC} (Not streaming)"
    fi
    
    echo "   Bandwidth: ${rtmp_bw} Mbps"
    echo "   Auto Restart: $([ "$rtmp_restart" = "1" ] && echo "Enabled" || echo "Disabled")"
else
    echo -e "   ${RED}✗${NC} Failed to get RTMP status"
fi
echo ""

# Monitor Battery Level
echo -e "${BLUE}3. Battery Status${NC}"
battery_response=$(api_call "/ctrl/get?k=battery" "Battery Level")
if [ $? -eq 0 ]; then
    battery_level=$(get_json_value "$battery_response" "value")
    
    if [ "$battery_level" -ge 80 ]; then
        echo -e "   Battery: ${GREEN}${battery_level}%${NC} (Good)"
    elif [ "$battery_level" -ge 30 ]; then
        echo -e "   Battery: ${YELLOW}${battery_level}%${NC} (Medium)"
    else
        echo -e "   Battery: ${RED}${battery_level}%${NC} (Low - Needs charging)"
    fi
else
    echo -e "   ${RED}✗${NC} Failed to get battery status"
fi
echo ""

# Monitor Camera Mode
echo -e "${BLUE}4. Camera Mode${NC}"
mode_response=$(api_call "/ctrl/mode" "Camera Mode")
if [ $? -eq 0 ]; then
    camera_mode=$(get_json_value "$mode_response" "msg")
    echo "   Current Mode: $camera_mode"
    
    case "$camera_mode" in
        "rec")
            echo -e "   Status: ${GREEN}Recording Mode${NC}"
            ;;
        "photo")
            echo -e "   Status: ${BLUE}Photo Mode${NC}"
            ;;
        *)
            echo -e "   Status: ${YELLOW}Unknown Mode${NC}"
            ;;
    esac
else
    echo -e "   ${RED}✗${NC} Failed to get camera mode"
fi
echo ""

# Monitor Camera Settings
echo -e "${BLUE}5. Camera Settings${NC}"

# Resolution
resolution_response=$(api_call "/ctrl/get?k=resolution" "Resolution")
if [ $? -eq 0 ]; then
    resolution=$(get_json_value "$resolution_response" "value")
    echo "   Resolution: $resolution"
else
    echo -e "   Resolution: ${RED}Failed to retrieve${NC}"
fi

# ISO
iso_response=$(api_call "/ctrl/get?k=iso" "ISO")
if [ $? -eq 0 ]; then
    iso=$(get_json_value "$iso_response" "value")
    echo "   ISO: $iso"
else
    echo -e "   ISO: ${RED}Failed to retrieve${NC}"
fi

# White Balance
wb_response=$(api_call "/ctrl/get?k=wb" "White Balance")
if [ $? -eq 0 ]; then
    wb=$(get_json_value "$wb_response" "value")
    echo "   White Balance: $wb"
else
    echo -e "   White Balance: ${RED}Failed to retrieve${NC}"
fi

# Focus
focus_response=$(api_call "/ctrl/get?k=focus" "Focus")
if [ $? -eq 0 ]; then
    focus=$(get_json_value "$focus_response" "value")
    echo "   Focus Mode: $focus"
else
    echo -e "   Focus Mode: ${RED}Failed to retrieve${NC}"
fi
echo ""

# Session Status
echo -e "${BLUE}6. Session Status${NC}"
session_response=$(api_call "/ctrl/session" "Session")
if [ $? -eq 0 ]; then
    session_code=$(get_json_value "$session_response" "code")
    if [ "$session_code" = "0" ]; then
        echo -e "   Session: ${GREEN}Active${NC}"
    else
        echo -e "   Session: ${RED}Error (Code: $session_code)${NC}"
    fi
else
    echo -e "   ${RED}✗${NC} Failed to get session status"
fi
echo ""

# Generate Summary Report
echo -e "${BLUE}7. Summary Report${NC}"
echo "   =================================="

# Overall Health Status
health_score=0
total_checks=0

# Check RTMP
if [ -n "$rtmp_status" ] && [ "$rtmp_status" = "busy" ]; then
    health_score=$((health_score + 1))
fi
total_checks=$((total_checks + 1))

# Check Battery
if [ -n "$battery_level" ] && [ "$battery_level" -ge 30 ]; then
    health_score=$((health_score + 1))
fi
total_checks=$((total_checks + 1))

# Check Session
if [ -n "$session_code" ] && [ "$session_code" = "0" ]; then
    health_score=$((health_score + 1))
fi
total_checks=$((total_checks + 1))

# Calculate health percentage
health_percentage=$((health_score * 100 / total_checks))

echo "   Health Score: $health_score/$total_checks ($health_percentage%)"

if [ "$health_percentage" -ge 80 ]; then
    echo -e "   Overall Status: ${GREEN}HEALTHY${NC}"
elif [ "$health_percentage" -ge 60 ]; then
    echo -e "   Overall Status: ${YELLOW}WARNING${NC}"
else
    echo -e "   Overall Status: ${RED}CRITICAL${NC}"
fi

echo ""
echo "   Recommendations:"

# Provide recommendations
if [ -n "$battery_level" ] && [ "$battery_level" -lt 30 ]; then
    echo -e "   ${YELLOW}⚠${NC} Battery low - consider charging"
fi

if [ -n "$rtmp_status" ] && [ "$rtmp_status" != "busy" ]; then
    echo -e "   ${YELLOW}⚠${NC} RTMP streaming not active"
fi

if [ "$health_percentage" -ge 80 ]; then
    echo -e "   ${GREEN}✓${NC} All systems operating normally"
fi

echo ""
echo -e "${BLUE}=== Monitor Complete ===${NC}"
echo "Log file: $LOGFILE"

# Return appropriate exit code
if [ "$health_percentage" -ge 80 ]; then
    exit 0
elif [ "$health_percentage" -ge 60 ]; then
    exit 1
else
    exit 2
fi
