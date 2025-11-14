#!/bin/bash

# Query Loki 24-hour storage growth
# This script calculates the storage growth in the last 24 hours

LOKI_CONTAINER="kevin-telemetry-loki-server"
CURRENT_TIME=$(date +%s)
TWENTY_FOUR_HOURS_AGO=$((CURRENT_TIME - 86400))  # 24 hours = 86400 seconds

echo "==============================================="
echo "Loki 24-Hour Storage Growth Analysis"
echo "==============================================="
echo "Timestamp: $(date)"
echo "Analysis Period: Last 24 hours"
echo ""

# Check if Loki container is running
if ! docker ps | grep -q "$LOKI_CONTAINER"; then
    echo "❌ ERROR: Loki container '$LOKI_CONTAINER' is not running!"
    exit 1
fi

# Method 1: Check container's chunks directory for files modified in the last 24 hours
echo "📊 Method 1: Container Chunks Analysis (Last 24 Hours)"
echo "------------------------------------------------------"
# Find files in chunks directory modified in the last 24 hours
DAILY_GROWTH_BYTES=$(docker exec $LOKI_CONTAINER find /tmp/loki/chunks -type f -newermt "@$TWENTY_FOUR_HOURS_AGO" -exec du -cb {} + 2>/dev/null | tail -1 | awk '{print $1}')

if [ -z "$DAILY_GROWTH_BYTES" ] || [ "$DAILY_GROWTH_BYTES" -eq 0 ]; then
    echo "⚠️  No chunks modified in the last 24 hours using find -newermt"
    echo "   Trying alternative method: checking file modification times..."
    
    # Alternative: Get all chunk files and their modification times, filter by last 24 hours
    DAILY_GROWTH_BYTES=$(docker exec $LOKI_CONTAINER sh -c "find /tmp/loki/chunks -type f -exec stat -c '%Y %s' {} \; 2>/dev/null | awk -v cutoff=$TWENTY_FOUR_HOURS_AGO '\$1 > cutoff {sum+=\$2} END {print sum+0}'")
    
    if [ -z "$DAILY_GROWTH_BYTES" ] || [ "$DAILY_GROWTH_BYTES" -eq 0 ]; then
        echo "⚠️  Still no files found modified in the last 24 hours"
        echo "   This might indicate low log activity or files are written in batches"
    else
        DAILY_GROWTH_MB=$(echo "scale=2; $DAILY_GROWTH_BYTES / 1024 / 1024" | bc)
        DAILY_GROWTH_GB=$(echo "scale=4; $DAILY_GROWTH_BYTES / 1024 / 1024 / 1024" | bc)
        echo "✅ Last 24 hours growth: ${DAILY_GROWTH_MB} MB (${DAILY_GROWTH_GB} GB)"
    fi
else
    DAILY_GROWTH_MB=$(echo "scale=2; $DAILY_GROWTH_BYTES / 1024 / 1024" | bc)
    DAILY_GROWTH_GB=$(echo "scale=4; $DAILY_GROWTH_BYTES / 1024 / 1024 / 1024" | bc)
    echo "✅ Last 24 hours growth: ${DAILY_GROWTH_MB} MB (${DAILY_GROWTH_GB} GB)"
fi

echo ""

# Method 2: Check container's internal storage (current state)
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
        
        # Estimate 24-hour growth from rate
        ESTIMATED_24H_BYTES=$(echo "scale=0; $INGESTION_RATE * 86400" | bc)
        ESTIMATED_24H_MB=$(echo "scale=2; $ESTIMATED_24H_BYTES / 1024 / 1024" | bc)
        ESTIMATED_24H_GB=$(echo "scale=4; $ESTIMATED_24H_BYTES / 1024 / 1024 / 1024" | bc)
        echo "Estimated 24-hour growth (from current rate): ${ESTIMATED_24H_MB} MB (${ESTIMATED_24H_GB} GB)"
    else
        echo "⚠️  No active ingestion rate detected (might be idle or metrics not available)"
    fi
else
    echo "⚠️  Could not connect to Loki metrics endpoint"
fi

echo ""

# Method 4: Estimate from container uptime (if container has been running for at least 24 hours)
echo "📊 Method 4: Container Uptime-Based Analysis"
echo "--------------------------------------------"
CONTAINER_START=$(docker inspect --format='{{.State.StartedAt}}' $LOKI_CONTAINER 2>/dev/null)
if [ -n "$CONTAINER_START" ]; then
    # Try different date parsing methods for compatibility
    CONTAINER_START_EPOCH=$(date -d "$CONTAINER_START" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%S" "${CONTAINER_START%.*}" +%s 2>/dev/null)
    if [ -n "$CONTAINER_START_EPOCH" ]; then
        UPTIME_SECONDS=$((CURRENT_TIME - CONTAINER_START_EPOCH))
        UPTIME_HOURS=$(echo "scale=1; $UPTIME_SECONDS / 3600" | bc)
        UPTIME_DAYS=$(echo "scale=2; $UPTIME_SECONDS / 86400" | bc)
        
        echo "Container uptime: ${UPTIME_HOURS} hours (${UPTIME_DAYS} days)"
        
        if [ "$UPTIME_SECONDS" -gt 86400 ]; then
            # Container has been running for more than 24 hours
            # Calculate average hourly growth
            AVG_HOURLY_GROWTH=$(echo "scale=0; $CURRENT_TOTAL_BYTES * 3600 / $UPTIME_SECONDS" | bc)
            AVG_24H_GROWTH=$(echo "scale=0; $AVG_HOURLY_GROWTH * 24" | bc)
            AVG_24H_GROWTH_MB=$(echo "scale=2; $AVG_24H_GROWTH / 1024 / 1024" | bc)
            AVG_24H_GROWTH_GB=$(echo "scale=4; $AVG_24H_GROWTH / 1024 / 1024 / 1024" | bc)
            echo "Average 24-hour growth (based on uptime): ${AVG_24H_GROWTH_MB} MB (${AVG_24H_GROWTH_GB} GB)"
        elif [ "$UPTIME_SECONDS" -gt 3600 ]; then
            # Container has been running for more than 1 hour but less than 24 hours
            AVG_HOURLY_GROWTH=$(echo "scale=0; $CURRENT_TOTAL_BYTES * 3600 / $UPTIME_SECONDS" | bc)
            AVG_24H_GROWTH=$(echo "scale=0; $AVG_HOURLY_GROWTH * 24" | bc)
            AVG_24H_GROWTH_MB=$(echo "scale=2; $AVG_24H_GROWTH / 1024 / 1024" | bc)
            AVG_24H_GROWTH_GB=$(echo "scale=4; $AVG_24H_GROWTH / 1024 / 1024 / 1024" | bc)
            echo "⚠️  Container uptime is less than 24 hours (${UPTIME_HOURS} hours)"
            echo "   Projected 24-hour growth (extrapolated): ${AVG_24H_GROWTH_MB} MB (${AVG_24H_GROWTH_GB} GB)"
        else
            echo "⚠️  Container uptime is less than 1 hour (${UPTIME_HOURS} hours)"
            echo "   Cannot reliably estimate 24-hour growth"
        fi
    else
        echo "⚠️  Could not parse container start time"
    fi
else
    echo "⚠️  Could not get container start time"
fi

echo ""

# Summary: Determine the best estimate for 24-hour growth
echo "📈 Summary: 24-Hour Storage Growth"
echo "-----------------------------------"

# Priority order for estimation methods:
# 1. Direct file modification check (most accurate if available)
# 2. Container uptime-based average (reliable for long-running containers)
# 3. Loki ingestion rate (if available)
# 4. Extrapolation from shorter uptime

BEST_24H_GROWTH=""
BEST_METHOD=""

# Method 1: Direct file modification check (most accurate)
if [ -n "$DAILY_GROWTH_BYTES" ] && [ "$DAILY_GROWTH_BYTES" -gt 0 ]; then
    BEST_24H_GROWTH=$DAILY_GROWTH_BYTES
    BEST_METHOD="Direct file modification check (last 24 hours)"
fi

# Method 2: Container uptime-based (if container running > 24 hours)
if [ -z "$BEST_24H_GROWTH" ] || [ "$BEST_24H_GROWTH" = "0" ]; then
    if [ -n "$UPTIME_SECONDS" ] && [ "$UPTIME_SECONDS" -gt 86400 ]; then
        if [ -n "$AVG_24H_GROWTH" ] && [ "$AVG_24H_GROWTH" -gt 0 ]; then
            BEST_24H_GROWTH=$AVG_24H_GROWTH
            BEST_METHOD="Container uptime-based average (${UPTIME_DAYS} days uptime)"
        fi
    fi
fi

# Method 3: Loki ingestion rate
if [ -z "$BEST_24H_GROWTH" ] || [ "$BEST_24H_GROWTH" = "0" ]; then
    if [ -n "$ESTIMATED_24H_BYTES" ] && [ "$ESTIMATED_24H_BYTES" != "0" ]; then
        BEST_24H_GROWTH=$ESTIMATED_24H_BYTES
        BEST_METHOD="Loki ingestion rate (current rate)"
    fi
fi

# Method 4: Extrapolation from shorter uptime
if [ -z "$BEST_24H_GROWTH" ] || [ "$BEST_24H_GROWTH" = "0" ]; then
    if [ -n "$AVG_24H_GROWTH" ] && [ "$AVG_24H_GROWTH" -gt 0 ]; then
        BEST_24H_GROWTH=$AVG_24H_GROWTH
        BEST_METHOD="Extrapolated from container uptime (${UPTIME_HOURS} hours)"
    fi
fi

if [ -z "$BEST_24H_GROWTH" ] || [ "$BEST_24H_GROWTH" = "0" ]; then
    echo "❌ Cannot calculate 24-hour growth - insufficient data"
    echo "   Please wait for more log activity or check Loki configuration"
    echo ""
    echo "💡 Suggestions:"
    echo "   1. Wait for at least 24 hours of log activity"
    echo "   2. Check if logs are being ingested: curl http://localhost:3100/metrics | grep ingestion"
    echo "   3. Verify Loki is receiving logs from agents"
    exit 1
fi

# Display results
BEST_24H_GROWTH_MB=$(echo "scale=2; $BEST_24H_GROWTH / 1024 / 1024" | bc)
BEST_24H_GROWTH_GB=$(echo "scale=4; $BEST_24H_GROWTH / 1024 / 1024 / 1024" | bc)
BEST_24H_GROWTH_KB=$(echo "scale=0; $BEST_24H_GROWTH / 1024" | bc)

echo "📊 Calculation Method:"
echo "  $BEST_METHOD"
echo ""
echo "📊 Results:"
echo "  Last 24 hours growth: ${BEST_24H_GROWTH_KB} KB"
echo "  Last 24 hours growth: ${BEST_24H_GROWTH_MB} MB"
echo "  Last 24 hours growth: ${BEST_24H_GROWTH_GB} GB"
echo ""

# Calculate hourly average
HOURLY_AVG_BYTES=$(echo "scale=0; $BEST_24H_GROWTH / 24" | bc)
HOURLY_AVG_MB=$(echo "scale=2; $HOURLY_AVG_BYTES / 1024 / 1024" | bc)
echo "  Average hourly growth: ${HOURLY_AVG_MB} MB"
echo ""

# Show current retention and storage info
echo "🔧 Current Configuration:"
echo "------------------------"
echo "Retention Period: 7 days (168h)"
echo "Current Total Storage: ${CURRENT_TOTAL_MB} MB (${CURRENT_TOTAL_GB} GB)"
echo ""

# Storage projection for 7 days
WEEKLY_GROWTH_BYTES=$(echo "scale=0; $BEST_24H_GROWTH * 7" | bc)
WEEKLY_GROWTH_GB=$(echo "scale=4; $WEEKLY_GROWTH_BYTES / 1024 / 1024 / 1024" | bc)

echo "💡 Storage Projection:"
echo "  Current: ${CURRENT_TOTAL_GB} GB"
echo "  + 24-hour growth: ${BEST_24H_GROWTH_GB} GB"
echo "  + 7-day projection: ${WEEKLY_GROWTH_GB} GB"
echo ""

# Warning if growth is high
BEST_24H_GROWTH_GB_INT=$(echo "scale=0; $BEST_24H_GROWTH_GB / 1" | bc)
if [ "$BEST_24H_GROWTH_GB_INT" -gt 5 ]; then
    echo "🚨 WARNING: 24-hour growth exceeds 5GB"
    echo "   Consider reviewing log retention policies or log filtering"
elif [ "$BEST_24H_GROWTH_GB_INT" -gt 1 ]; then
    echo "⚠️  WARNING: 24-hour growth exceeds 1GB"
    echo "   Monitor storage usage closely"
else
    echo "✅ 24-hour growth is within acceptable limits"
fi

echo ""
echo "==============================================="

