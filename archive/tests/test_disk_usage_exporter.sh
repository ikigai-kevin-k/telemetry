#!/bin/bash
# Test script for Disk Usage Exporter
# This script tests if the disk-usage-exporter is working correctly

set -e

echo "=== Testing Disk Usage Exporter ==="
echo ""

# Check if container is running
echo "1. Checking if container is running..."
if docker ps | grep -q kevin-telemetry-disk-usage-exporter; then
    echo "   ✓ Container is running"
else
    echo "   ✗ Container is not running"
    echo "   Please start it with: docker-compose up -d disk-usage-exporter"
    exit 1
fi

# Check if metrics endpoint is accessible
echo ""
echo "2. Checking metrics endpoint..."
if curl -s http://localhost:9275/metrics > /dev/null 2>&1; then
    echo "   ✓ Metrics endpoint is accessible"
else
    echo "   ✗ Metrics endpoint is not accessible"
    echo "   Please check container logs: docker logs kevin-telemetry-disk-usage-exporter"
    exit 1
fi

# Check if disk usage metrics are present
echo ""
echo "3. Checking for disk usage metrics..."
METRICS=$(curl -s http://localhost:9275/metrics)

if echo "$METRICS" | grep -q "disk_usage_percent"; then
    echo "   ✓ disk_usage_percent metric found"
else
    echo "   ✗ disk_usage_percent metric not found"
    exit 1
fi

if echo "$METRICS" | grep -q "disk_total_bytes"; then
    echo "   ✓ disk_total_bytes metric found"
else
    echo "   ✗ disk_total_bytes metric not found"
    exit 1
fi

if echo "$METRICS" | grep -q "disk_used_bytes"; then
    echo "   ✓ disk_used_bytes metric found"
else
    echo "   ✗ disk_used_bytes metric not found"
    exit 1
fi

if echo "$METRICS" | grep -q "disk_available_bytes"; then
    echo "   ✓ disk_available_bytes metric found"
else
    echo "   ✗ disk_available_bytes metric not found"
    exit 1
fi

# Display current metrics
echo ""
echo "4. Current disk usage metrics:"
echo "$METRICS" | grep -E "disk_(usage_percent|total_bytes|used_bytes|available_bytes)" | head -10

# Check if Prometheus can scrape the metrics
echo ""
echo "5. Checking Prometheus target..."
if docker ps | grep -q kevin-telemetry-prometheus; then
    echo "   Prometheus container is running"
    echo "   You can check targets at: http://localhost:9090/targets"
    echo "   Look for 'disk-usage' job"
else
    echo "   Prometheus container is not running"
fi

echo ""
echo "=== Test completed successfully ==="
echo ""
echo "Next steps:"
echo "1. Verify metrics in Prometheus: http://localhost:9090"
echo "2. Query disk usage: disk_usage_percent{filesystem=\"/dev/mapper/ubuntu--vg-ubuntu--lv\"}"
echo "3. Create Grafana dashboard to visualize disk usage"

