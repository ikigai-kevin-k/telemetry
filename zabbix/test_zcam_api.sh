#!/bin/bash

# Test script for ZCAM API connection
# This script tests the connection to the ZCAM RTMP API endpoint

echo "=== ZCAM API Connection Test ==="
echo "Testing connection to: http://192.168.88.175/ctrl/rtmp?action=query&index=0"
echo ""

# Test basic connectivity
echo "1. Testing basic connectivity..."
if ping -c 1 192.168.88.175 &> /dev/null; then
    echo "   ✓ Host 192.168.88.175 is reachable"
else
    echo "   ✗ Host 192.168.88.175 is not reachable"
    exit 1
fi

# Test HTTP connection
echo ""
echo "2. Testing HTTP connection..."
response=$(curl -s --max-time 10 --connect-timeout 10 "http://192.168.88.175/ctrl/rtmp?action=query&index=0" 2>/dev/null)

if [ $? -eq 0 ]; then
    echo "   ✓ HTTP connection successful"
    echo "   Response length: ${#response} characters"
else
    echo "   ✗ HTTP connection failed"
    exit 1
fi

# Check if response is empty
if [ -z "$response" ]; then
    echo "   ✗ Empty response received"
    exit 1
else
    echo "   ✓ Response received"
fi

# Check if response contains JSON structure
echo ""
echo "3. Validating JSON response..."
if echo "$response" | grep -q '{.*}'; then
    echo "   ✓ Response appears to be valid JSON"
else
    echo "   ✗ Response does not appear to be valid JSON"
    echo "   Raw response: $response"
    exit 1
fi

# Parse and display the response
echo ""
echo "4. Parsing response..."
echo "   Raw response: $response"

# Try to extract individual fields
echo ""
echo "5. Extracting fields..."

# Status
status=$(echo "$response" | grep -o '"status":"[^"]*"' | sed 's/.*"status":"\([^"]*\)".*/\1/' 2>/dev/null)
if [ -n "$status" ]; then
    echo "   Status: $status"
else
    echo "   Status: Not found"
fi

# Bandwidth
bw=$(echo "$response" | grep -o '"bw":[0-9.]*' | sed 's/.*"bw":\([0-9.]*\)/\1/' 2>/dev/null)
if [ -n "$bw" ]; then
    echo "   Bandwidth: $bw Mbps"
else
    echo "   Bandwidth: Not found"
fi

# URL
url=$(echo "$response" | grep -o '"url":"[^"]*"' | sed 's/.*"url":"\([^"]*\)".*/\1/' 2>/dev/null)
if [ -n "$url" ]; then
    echo "   URL: $url"
else
    echo "   URL: Not found"
fi

# Code
code=$(echo "$response" | grep -o '"code":[0-9]*' | sed 's/.*"code":\([0-9]*\)/\1/' 2>/dev/null)
if [ -n "$code" ]; then
    echo "   Code: $code"
else
    echo "   Code: Not found"
fi

# AutoRestart
autoRestart=$(echo "$response" | grep -o '"autoRestart":[0-9]*' | sed 's/.*"autoRestart":\([0-9]*\)/\1/' 2>/dev/null)
if [ -n "$autoRestart" ]; then
    echo "   AutoRestart: $autoRestart"
else
    echo "   AutoRestart: Not found"
fi

echo ""
echo "=== Test completed ==="

# Test the monitoring script
echo ""
echo "6. Testing monitoring script..."
if [ -f "./scripts/check_zcam_status.sh" ]; then
    echo "   Running check_zcam_status.sh..."
    script_output=$(./scripts/check_zcam_status.sh 2>&1)
    echo "   Script output: $script_output"
else
    echo "   ✗ Script check_zcam_status.sh not found"
fi

echo ""
echo "=== All tests completed ==="
