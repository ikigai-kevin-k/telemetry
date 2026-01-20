#!/bin/bash

# Query Loki hourly log growth and estimate weekly storage
# This script calculates the storage growth in the last hour and estimates weekly usage

LOKI_CONTAINER="kevin-telemetry-loki-server"
LOKI_VOLUME_PATH="/var/lib/docker/volumes/telemetry_loki_data/_data"
CURRENT_TIME=$(date +%s)
ONE_HOUR_AGO=$((CURRENT_TIME - 3600))

echo "==============================================="
echo "Loki Storage Growth Analysis"
echo "==============================================="
echo "Timestamp: $(date)"
echo ""

# Check if Loki container is running
if ! docker ps | grep -q "$LOKI_CONTAINER"; then
    echo "❌ ERROR: Loki container '$LOKI_CONTAINER' is not running!"
    exit 1
fi

# Method 1: Check container's chunks directory for files modified in the last hour
echo "📊 Method 1: Container Chunks Analysis (Last Hour)"
echo "---------------------------------------------------"
# Find files in chunks directory modified in the last hour
HOURLY_GROWTH_BYTES=$(docker exec $LOKI_CONTAINER find /tmp/loki/chunks -type f -newermt "@$ONE_HOUR_AGO" -exec du -cb {} + 2>/dev/null | tail -1 | awk '{print $1}')

if [ -z "$HOURLY_GROWTH_BYTES" ] || [ "$HOURLY_GROWTH_BYTES" -eq 0 ]; then
    echo "⚠️  No chunks modified in the last hour"
    echo "   Trying alternative method: checking file modification times..."
    
    # Alternative: Get all chunk files and their modification times, filter by last hour
    HOURLY_GROWTH_BYTES=$(docker exec $LOKI_CONTAINER sh -c "find /tmp/loki/chunks -type f -exec stat -c '%Y %s' {} \; 2>/dev/null | awk -v cutoff=$ONE_HOUR_AGO '\$1 > cutoff {sum+=\$2} END {print sum}'")
    
    if [ -z "$HOURLY_GROWTH_BYTES" ] || [ "$HOURLY_GROWTH_BYTES" -eq 0 ]; then
        echo "⚠️  Still no files found modified in the last hour"
        echo "   This might indicate low log activity or files are written in batches"
    else
        HOURLY_GROWTH_MB=$(echo "scale=2; $HOURLY_GROWTH_BYTES / 1024 / 1024" | bc)
        HOURLY_GROWTH_GB=$(echo "scale=4; $HOURLY_GROWTH_BYTES / 1024 / 1024 / 1024" | bc)
        echo "✅ Last hour growth: ${HOURLY_GROWTH_MB} MB (${HOURLY_GROWTH_GB} GB)"
    fi
else
    HOURLY_GROWTH_MB=$(echo "scale=2; $HOURLY_GROWTH_BYTES / 1024 / 1024" | bc)
    HOURLY_GROWTH_GB=$(echo "scale=4; $HOURLY_GROWTH_BYTES / 1024 / 1024 / 1024" | bc)
    echo "✅ Last hour growth: ${HOURLY_GROWTH_MB} MB (${HOURLY_GROWTH_GB} GB)"
fi

echo ""

# Method 2: Check container's internal storage
echo "📊 Method 2: Container Internal Storage Analysis"
echo "------------------------------------------------"
# Get current total size
CURRENT_TOTAL_BYTES=$(docker exec $LOKI_CONTAINER du -sb /tmp/loki/ 2>/dev/null | awk '{print $1}')
CURRENT_TOTAL_MB=$(echo "scale=2; $CURRENT_TOTAL_BYTES / 1024 / 1024" | bc)
CURRENT_TOTAL_GB=$(echo "scale=4; $CURRENT_TOTAL_BYTES / 1024 / 1024 / 1024" | bc)

echo "Current total storage: ${CURRENT_TOTAL_MB} MB (${CURRENT_TOTAL_GB} GB)"

# Get chunks size (main log data)
CHUNKS_BYTES=$(docker exec $LOKI_CONTAINER du -sb /tmp/loki/chunks 2>/dev/null | awk '{print $1}')
if [ -n "$CHUNKS_BYTES" ] && [ "$CHUNKS_BYTES" -gt 0 ]; then
    CHUNKS_MB=$(echo "scale=2; $CHUNKS_BYTES / 1024 / 1024" | bc)
    CHUNKS_GB=$(echo "scale=4; $CHUNKS_BYTES / 1024 / 1024 / 1024" | bc)
    echo "Chunks storage: ${CHUNKS_MB} MB (${CHUNKS_GB} GB)"
fi

# Get index size
INDEX_BYTES=$(docker exec $LOKI_CONTAINER du -sb /tmp/loki/index 2>/dev/null | awk '{print $1}')
if [ -n "$INDEX_BYTES" ] && [ "$INDEX_BYTES" -gt 0 ]; then
    INDEX_MB=$(echo "scale=2; $INDEX_BYTES / 1024 / 1024" | bc)
    INDEX_GB=$(echo "scale=4; $INDEX_BYTES / 1024 / 1024 / 1024" | bc)
    echo "Index storage: ${INDEX_MB} MB (${INDEX_GB} GB)"
fi

echo ""

# Method 3: Use Loki metrics API to get ingestion stats
echo "📊 Method 3: Loki Metrics API Analysis"
echo "--------------------------------------"
LOKI_METRICS=$(curl -s http://localhost:3100/metrics 2>/dev/null)

if [ -n "$LOKI_METRICS" ]; then
    # Extract ingestion rate metrics
    INGESTED_BYTES_TOTAL=$(echo "$LOKI_METRICS" | grep '^loki_ingester_chunk_stored_bytes_total' | awk '{sum+=$2} END {print sum+0}')
    INGESTED_SAMPLES_TOTAL=$(echo "$LOKI_METRICS" | grep '^loki_ingester_chunk_samples_total' | awk '{sum+=$2} END {print sum+0}')
    
    if [ -n "$INGESTED_BYTES_TOTAL" ] && [ "$INGESTED_BYTES_TOTAL" != "0" ]; then
        INGESTED_GB=$(echo "scale=4; $INGESTED_BYTES_TOTAL / 1024 / 1024 / 1024" | bc)
        echo "Total ingested bytes (since start): ${INGESTED_GB} GB"
        if [ -n "$INGESTED_SAMPLES_TOTAL" ] && [ "$INGESTED_SAMPLES_TOTAL" != "0" ]; then
            echo "Total ingested samples: ${INGESTED_SAMPLES_TOTAL}"
        fi
    else
        echo "⚠️  Could not extract ingestion metrics from Loki API"
    fi
    
    # Get current ingestion rate (bytes per second)
    INGESTION_RATE=$(echo "$LOKI_METRICS" | grep '^loki_ingester_ingestion_rate_bytes' | awk '{sum+=$2} END {print sum+0}')
    if [ -n "$INGESTION_RATE" ] && [ "$INGESTION_RATE" != "0" ]; then
        INGESTION_RATE_MB=$(echo "scale=2; $INGESTION_RATE / 1024 / 1024" | bc)
        echo "Current ingestion rate: ${INGESTION_RATE_MB} MB/s"
        
        # Estimate hourly growth from rate
        ESTIMATED_HOURLY_BYTES=$(echo "scale=0; $INGESTION_RATE * 3600" | bc)
        ESTIMATED_HOURLY_MB=$(echo "scale=2; $ESTIMATED_HOURLY_BYTES / 1024 / 1024" | bc)
        ESTIMATED_HOURLY_GB=$(echo "scale=4; $ESTIMATED_HOURLY_BYTES / 1024 / 1024 / 1024" | bc)
        echo "Estimated hourly growth (from rate): ${ESTIMATED_HOURLY_MB} MB (${ESTIMATED_HOURLY_GB} GB)"
    else
        echo "⚠️  No active ingestion rate detected (might be idle or metrics not available)"
    fi
else
    echo "⚠️  Could not connect to Loki metrics endpoint"
fi

echo ""

# Calculate weekly estimate
echo "📈 Weekly Storage Estimate"
echo "--------------------------"

# Priority order for estimation methods:
# 1. Container uptime-based average (most reliable for long-running containers)
# 2. Loki ingestion rate (if available)
# 3. Recent file modifications (least reliable, may miss batch writes)

HOURLY_GROWTH=""
METHOD=""
UPTIME_HOURS=""

# Method 1: Estimate from container uptime and total storage (most reliable)
CONTAINER_START=$(docker inspect --format='{{.State.StartedAt}}' $LOKI_CONTAINER 2>/dev/null)
if [ -n "$CONTAINER_START" ]; then
    CONTAINER_START_EPOCH=$(date -d "$CONTAINER_START" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%S" "${CONTAINER_START%.*}" +%s 2>/dev/null)
    if [ -n "$CONTAINER_START_EPOCH" ]; then
        UPTIME_SECONDS=$((CURRENT_TIME - CONTAINER_START_EPOCH))
        if [ "$UPTIME_SECONDS" -gt 3600 ]; then
            UPTIME_HOURS=$(echo "scale=1; $UPTIME_SECONDS / 3600" | bc)
            # Estimate based on total storage / uptime (average hourly growth)
            HOURLY_GROWTH=$(echo "scale=0; $CURRENT_TOTAL_BYTES * 3600 / $UPTIME_SECONDS" | bc)
            METHOD="Average hourly growth (based on container uptime: ${UPTIME_HOURS} hours)"
        fi
    fi
fi

# Method 2: Use Loki ingestion rate if available and uptime method not suitable
if [ -z "$HOURLY_GROWTH" ] || [ "$HOURLY_GROWTH" = "0" ]; then
    if [ -n "$ESTIMATED_HOURLY_BYTES" ] && [ "$ESTIMATED_HOURLY_BYTES" != "0" ]; then
        HOURLY_GROWTH=$ESTIMATED_HOURLY_BYTES
        METHOD="Loki ingestion rate (current rate)"
    fi
fi

# Method 3: Use recent file modifications as last resort
if [ -z "$HOURLY_GROWTH" ] || [ "$HOURLY_GROWTH" = "0" ]; then
    if [ -n "$HOURLY_GROWTH_BYTES" ] && [ "$HOURLY_GROWTH_BYTES" -gt 0 ]; then
        HOURLY_GROWTH=$HOURLY_GROWTH_BYTES
        METHOD="Container chunks file modification time (last hour)"
    fi
fi

if [ -z "$HOURLY_GROWTH" ] || [ "$HOURLY_GROWTH" = "0" ]; then
    echo "❌ Cannot calculate hourly growth - insufficient data"
    echo "   Please wait for more log activity or check Loki configuration"
    echo ""
    echo "💡 Suggestions:"
    echo "   1. Wait for at least 1 hour of log activity"
    echo "   2. Check if logs are being ingested: curl http://localhost:3100/metrics | grep ingestion"
    echo "   3. Verify Loki is receiving logs from agents"
    exit 1
fi

# Calculate weekly (168 hours)
WEEKLY_GROWTH_BYTES=$(echo "scale=0; $HOURLY_GROWTH * 168" | bc)
WEEKLY_GROWTH_MB=$(echo "scale=2; $WEEKLY_GROWTH_BYTES / 1024 / 1024" | bc)
WEEKLY_GROWTH_GB=$(echo "scale=4; $WEEKLY_GROWTH_BYTES / 1024 / 1024 / 1024" | bc)

echo "📊 Calculation Method:"
echo "  $METHOD"
echo ""
if [ -n "$UPTIME_HOURS" ]; then
    UPTIME_DAYS=$(echo "scale=1; $UPTIME_HOURS / 24" | bc)
    echo "📅 Container Information:"
    echo "  Uptime: ${UPTIME_HOURS} hours (${UPTIME_DAYS} days)"
    echo ""
fi
echo "📊 Results:"
HOURLY_GROWTH_MB_DISPLAY=$(echo "scale=2; $HOURLY_GROWTH / 1024 / 1024" | bc)
HOURLY_GROWTH_GB_DISPLAY=$(echo "scale=4; $HOURLY_GROWTH / 1024 / 1024 / 1024" | bc)
echo "  Average hourly growth: ${HOURLY_GROWTH_MB_DISPLAY} MB (${HOURLY_GROWTH_GB_DISPLAY} GB)"
echo "  Estimated weekly growth: ${WEEKLY_GROWTH_MB} MB (${WEEKLY_GROWTH_GB} GB)"
echo ""

# Show current retention and storage info
echo "🔧 Current Configuration:"
echo "------------------------"
echo "Retention Period: 7 days (168h)"
echo "Current Total Storage: ${CURRENT_TOTAL_MB} MB (${CURRENT_TOTAL_GB} GB)"
echo ""

# Storage projection
PROJECTED_TOTAL_BYTES=$(echo "scale=0; $CURRENT_TOTAL_BYTES + $WEEKLY_GROWTH_BYTES" | bc)
PROJECTED_TOTAL_GB=$(echo "scale=4; $PROJECTED_TOTAL_BYTES / 1024 / 1024 / 1024" | bc)

echo "💡 Storage Projection (after 1 week):"
echo "  Current: ${CURRENT_TOTAL_GB} GB"
echo "  + Weekly growth: ${WEEKLY_GROWTH_GB} GB"
echo "  = Projected total: ${PROJECTED_TOTAL_GB} GB"
echo ""

# Warning if projected size is high
PROJECTED_TOTAL_GB_INT=$(echo "scale=0; $PROJECTED_TOTAL_GB / 1" | bc)
if [ "$PROJECTED_TOTAL_GB_INT" -gt 10 ]; then
    echo "⚠️  WARNING: Projected storage exceeds 10GB"
    echo "   Consider reviewing log retention policies or log filtering"
elif [ "$PROJECTED_TOTAL_GB_INT" -gt 5 ]; then
    echo "⚠️  WARNING: Projected storage exceeds 5GB"
    echo "   Monitor storage usage closely"
else
    echo "✅ Projected storage is within acceptable limits"
fi

echo ""
echo "==============================================="

