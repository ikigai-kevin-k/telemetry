#!/bin/bash

# ZCAM API Discovery Script
# This script explores and tests various ZCAM API endpoints to discover available information

ZCAM_IP="192.168.88.175"
BASE_URL="http://${ZCAM_IP}"
TIMEOUT=5

echo "=== ZCAM API Discovery ==="
echo "Target device: ${ZCAM_IP}"
echo "Base URL: ${BASE_URL}"
echo ""

# Function to test API endpoint
test_endpoint() {
    local endpoint="$1"
    local description="$2"
    
    echo -n "Testing ${description}: "
    response=$(curl -s --max-time $TIMEOUT "${BASE_URL}${endpoint}" 2>/dev/null)
    
    if [ $? -eq 0 ] && [ -n "$response" ]; then
        # Check if response contains error
        if echo "$response" | grep -q '"code":-1'; then
            echo "❌ Not supported"
        else
            echo "✅ Success"
            echo "   Response: $response"
        fi
    else
        echo "❌ Failed/Empty"
    fi
    echo ""
}

# Function to test GET parameter
test_get_param() {
    local param="$1"
    local description="$2"
    
    echo -n "Testing GET parameter '${param}' (${description}): "
    response=$(curl -s --max-time $TIMEOUT "${BASE_URL}/ctrl/get?k=${param}" 2>/dev/null)
    
    if [ $? -eq 0 ] && [ -n "$response" ]; then
        if echo "$response" | grep -q '"code":-1'; then
            echo "❌ Not supported"
        else
            echo "✅ Success"
            echo "   Response: $response"
            # Extract value if present
            value=$(echo "$response" | grep -o '"value":[^,}]*' | sed 's/"value"://')
            if [ -n "$value" ]; then
                echo "   Value: $value"
            fi
        fi
    else
        echo "❌ Failed/Empty"
    fi
    echo ""
}

echo "1. Testing Base API Endpoints"
echo "================================"

# Test basic endpoints
test_endpoint "/ctrl/session" "Session info"
test_endpoint "/ctrl/info" "Device info"
test_endpoint "/ctrl/status" "Device status"
test_endpoint "/api" "API root"
test_endpoint "/ctrl/rtmp?action=query&index=0" "RTMP status (known working)"

echo "2. Testing GET Parameters"
echo "========================="

# Known working parameters
test_get_param "battery" "Battery level"

# Common camera parameters to test
echo "Testing common camera parameters..."
test_get_param "model" "Camera model"
test_get_param "fw_version" "Firmware version"
test_get_param "device_name" "Device name"
test_get_param "serial_number" "Serial number"
test_get_param "temperature" "Temperature"
test_get_param "card_status" "SD card status"
test_get_param "storage" "Storage info"
test_get_param "rec_state" "Recording state"
test_get_param "rec_time" "Recording time"
test_get_param "rec_remain_time" "Remaining recording time"
test_get_param "resolution" "Video resolution"
test_get_param "fps" "Frame rate"
test_get_param "bitrate" "Bitrate"
test_get_param "iso" "ISO setting"
test_get_param "wb" "White balance"
test_get_param "exposure" "Exposure"
test_get_param "focus" "Focus mode"
test_get_param "zoom" "Zoom level"
test_get_param "wifi_status" "WiFi status"
test_get_param "network" "Network info"
test_get_param "rtmp_status" "RTMP status"
test_get_param "streaming" "Streaming status"

echo "3. Testing Alternative Endpoints"
echo "================================"

# Test alternative API paths
test_endpoint "/ctrl/get" "GET without parameters"
test_endpoint "/ctrl/set" "SET endpoint"
test_endpoint "/ctrl/mode" "Mode endpoint"
test_endpoint "/ctrl/media" "Media endpoint"
test_endpoint "/ctrl/system" "System endpoint"
test_endpoint "/ctrl/network" "Network endpoint"
test_endpoint "/ctrl/wifi" "WiFi endpoint"

echo "4. Testing RTMP Variants"
echo "========================"

# Test different RTMP queries
test_endpoint "/ctrl/rtmp?action=query" "RTMP query (no index)"
test_endpoint "/ctrl/rtmp?action=query&index=1" "RTMP query index 1"
test_endpoint "/ctrl/rtmp?action=status" "RTMP status"
test_endpoint "/ctrl/rtmp?action=info" "RTMP info"

echo "5. Summary of Working APIs"
echo "=========================="

echo "Creating summary of discovered working APIs..."

# Re-test known working endpoints for summary
echo ""
echo "✅ Working RTMP API:"
curl -s --max-time $TIMEOUT "${BASE_URL}/ctrl/rtmp?action=query&index=0" 2>/dev/null | \
    jq . 2>/dev/null || curl -s --max-time $TIMEOUT "${BASE_URL}/ctrl/rtmp?action=query&index=0" 2>/dev/null

echo ""
echo "✅ Working Battery API:"
curl -s --max-time $TIMEOUT "${BASE_URL}/ctrl/get?k=battery" 2>/dev/null | \
    jq . 2>/dev/null || curl -s --max-time $TIMEOUT "${BASE_URL}/ctrl/get?k=battery" 2>/dev/null

echo ""
echo "=== Discovery Complete ==="
echo "Check the output above for all working API endpoints."
echo "Use these endpoints for monitoring integration."
