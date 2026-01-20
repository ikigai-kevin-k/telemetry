#!/bin/bash

# Loki Storage Monitor Script
# This script monitors Loki storage usage and alerts if it exceeds limits

LOKI_CONTAINER="kevin-telemetry-loki-server"
WARNING_THRESHOLD_GB=2  # Warning at 2GB
CRITICAL_THRESHOLD_GB=5  # Critical at 5GB

echo "==============================================="
echo "Loki Storage Usage Monitor"
echo "==============================================="
echo "Timestamp: $(date)"
echo ""

# Check if Loki container is running
if ! docker ps | grep -q "$LOKI_CONTAINER"; then
    echo "❌ ERROR: Loki container '$LOKI_CONTAINER' is not running!"
    exit 1
fi

# Get storage usage
echo "📊 Current Storage Usage:"
echo "------------------------"

# Total storage
TOTAL_SIZE=$(docker exec $LOKI_CONTAINER du -sh /tmp/loki/ 2>/dev/null | awk '{print $1}')
echo "Total Loki Storage: $TOTAL_SIZE"

# Chunks storage (main data)
CHUNKS_SIZE=$(docker exec $LOKI_CONTAINER du -sh /tmp/loki/chunks 2>/dev/null | awk '{print $1}')
echo "Chunks Storage: $CHUNKS_SIZE"

# Index storage
INDEX_SIZE=$(docker exec $LOKI_CONTAINER du -sh /tmp/loki/index 2>/dev/null | awk '{print $1}')
echo "Index Storage: $INDEX_SIZE"

# Convert to GB for comparison
TOTAL_SIZE_GB=$(docker exec $LOKI_CONTAINER du -s /tmp/loki/ 2>/dev/null | awk '{print int($1/1024/1024)}')

echo ""
echo "📈 Storage Analysis:"
echo "-------------------"

if [ "$TOTAL_SIZE_GB" -gt "$CRITICAL_THRESHOLD_GB" ]; then
    echo "🚨 CRITICAL: Storage usage is ${TOTAL_SIZE_GB}GB (exceeds ${CRITICAL_THRESHOLD_GB}GB limit)"
    echo "   Action: Consider cleaning old logs or increasing retention cleanup frequency"
elif [ "$TOTAL_SIZE_GB" -gt "$WARNING_THRESHOLD_GB" ]; then
    echo "⚠️  WARNING: Storage usage is ${TOTAL_SIZE_GB}GB (exceeds ${WARNING_THRESHOLD_GB}GB warning threshold)"
    echo "   Action: Monitor closely, consider log filtering optimization"
else
    echo "✅ OK: Storage usage is ${TOTAL_SIZE_GB}GB (within acceptable limits)"
fi

echo ""
echo "🔧 Current Configuration:"
echo "-------------------------"
echo "Retention Period: 7 days (168h)"
echo "SRS Logs Retention: 72h (3 days)"
echo "FFmpeg Logs Retention: 48h (2 days)"
echo "Ingestion Rate Limit: 32MB/s"
echo "Burst Limit: 64MB"

echo ""
echo "💡 Storage Optimization Tips:"
echo "-----------------------------"
echo "1. SRS logs are filtered to exclude debug/trace messages"
echo "2. FFmpeg logs are filtered to exclude verbose messages"
echo "3. Shorter retention periods for high-volume logs"
echo "4. Automatic cleanup enabled for old data"

echo ""
echo "==============================================="
