#!/bin/bash

# Test script for ZCAM Temperature API exploration
ZCAM_IP="192.168.88.184"
BASE_URL="http://${ZCAM_IP}"
TIMEOUT=5

echo "=== ZCAM Temperature API Test ==="
echo "Testing device: $ZCAM_IP"
echo ""

# Temperature related parameters to test
temp_params=(
    "temperature"
    "temp"
    "thermal" 
    "cpu_temp"
    "sensor_temp"
    "system_temp"
    "device_temp"
    "core_temp"
    "chip_temp"
    "soc_temp"
    "internal_temp"
    "ambient_temp"
    "board_temp"
    "cam_temp"
    "camera_temp"
    "hw_temp"
    "hardware_temp"
    "therm"
    "overheat"
    "temp_status"
    "thermal_status"
)

echo "Testing GET parameters for temperature..."
for param in "${temp_params[@]}"; do
    echo -n "Testing parameter '$param': "
    response=$(curl -s --max-time $TIMEOUT "${BASE_URL}/ctrl/get?k=${param}" 2>/dev/null)
    
    if [ -n "$response" ]; then
        if echo "$response" | grep -q '"code":-1'; then
            echo "❌ Not supported"
        else
            echo "✅ Success!"
            echo "   Response: $response"
        fi
    else
        echo "❌ No response"
    fi
done

echo ""
echo "Testing alternative endpoints..."

# Test other possible endpoints
endpoints=(
    "/ctrl/temperature"
    "/ctrl/thermal"
    "/ctrl/system/temperature"
    "/ctrl/device/temp"
    "/ctrl/status/temp"
    "/api/temperature"
    "/api/thermal"
    "/status/temperature"
)

for endpoint in "${endpoints[@]}"; do
    echo -n "Testing endpoint '$endpoint': "
    response=$(curl -s --max-time $TIMEOUT "${BASE_URL}${endpoint}" 2>/dev/null)
    
    if [ -n "$response" ] && [ "$response" != "404" ]; then
        echo "✅ Response received"
        echo "   Response: $response" | head -c 200
        echo ""
    else
        echo "❌ No response/404"
    fi
done

echo ""
echo "=== Temperature API Test Complete ==="
