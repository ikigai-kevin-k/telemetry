#!/bin/bash

# Query Prometheus 24-hour storage growth
# This script calculates the storage growth in the last 24 hours

PROM_CONTAINER="kevin-telemetry-prometheus"
PROM_DATA_PATH="/prometheus"
CURRENT_TIME=$(date +%s)
TWENTY_FOUR_HOURS_AGO=$((CURRENT_TIME - 86400))  # 24 hours = 86400 seconds

echo "==============================================="
echo "Prometheus 24-Hour Storage Growth Analysis"
echo "==============================================="
echo "Timestamp: $(date)"
echo "Analysis Period: Last 24 hours"
echo ""

# Check if Prometheus container is running
if ! docker ps | grep -q "$PROM_CONTAINER"; then
    echo "❌ ERROR: Prometheus container '$PROM_CONTAINER' is not running!"
    exit 1
fi

# Method 1: Check container's TSDB directory for files modified in the last 24 hours
echo "📊 Method 1: Container TSDB Analysis (Last 24 Hours)"
echo "---------------------------------------------------"
# Find files in prometheus directory modified in the last 24 hours
DAILY_GROWTH_BYTES=$(docker exec $PROM_CONTAINER find $PROM_DATA_PATH -type f -newermt "@$TWENTY_FOUR_HOURS_AGO" -exec du -cb {} + 2>/dev/null | tail -1 | awk '{print $1}')

if [ -z "$DAILY_GROWTH_BYTES" ] || [ "$DAILY_GROWTH_BYTES" -eq 0 ]; then
    echo "⚠️  No files modified in the last 24 hours using find -newermt"
    echo "   Trying alternative method: checking file modification times..."
    
    # Alternative: Get all files and their modification times, filter by last 24 hours
    DAILY_GROWTH_BYTES=$(docker exec $PROM_CONTAINER sh -c "find $PROM_DATA_PATH -type f -exec stat -c '%Y %s' {} \; 2>/dev/null | awk -v cutoff=$TWENTY_FOUR_HOURS_AGO '\$1 > cutoff {sum+=\$2} END {print sum+0}'")
    
    if [ -z "$DAILY_GROWTH_BYTES" ] || [ "$DAILY_GROWTH_BYTES" -eq 0 ]; then
        echo "⚠️  Still no files found modified in the last 24 hours"
        echo "   This might indicate low metric activity or files are written in batches"
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
CURRENT_TOTAL_BYTES=$(docker exec $PROM_CONTAINER du -sb $PROM_DATA_PATH 2>/dev/null | awk '{print $1}')
CURRENT_TOTAL_MB=$(echo "scale=2; $CURRENT_TOTAL_BYTES / 1024 / 1024" | bc)
CURRENT_TOTAL_GB=$(echo "scale=4; $CURRENT_TOTAL_BYTES / 1024 / 1024 / 1024" | bc)

echo "Current total storage: ${CURRENT_TOTAL_MB} MB (${CURRENT_TOTAL_GB} GB)"

# Get chunks_head size (in-memory data)
CHUNKS_HEAD_BYTES=$(docker exec $PROM_CONTAINER du -sb $PROM_DATA_PATH/chunks_head 2>/dev/null | awk '{print $1}')
if [ -n "$CHUNKS_HEAD_BYTES" ] && [ "$CHUNKS_HEAD_BYTES" -gt 0 ]; then
    CHUNKS_HEAD_MB=$(echo "scale=2; $CHUNKS_HEAD_BYTES / 1024 / 1024" | bc)
    CHUNKS_HEAD_GB=$(echo "scale=4; $CHUNKS_HEAD_BYTES / 1024 / 1024 / 1024" | bc)
    echo "Chunks head (in-memory): ${CHUNKS_HEAD_MB} MB (${CHUNKS_HEAD_GB} GB)"
fi

# Get wal size (Write-Ahead Log)
WAL_BYTES=$(docker exec $PROM_CONTAINER du -sb $PROM_DATA_PATH/wal 2>/dev/null | awk '{print $1}')
if [ -n "$WAL_BYTES" ] && [ "$WAL_BYTES" -gt 0 ]; then
    WAL_MB=$(echo "scale=2; $WAL_BYTES / 1024 / 1024" | bc)
    WAL_GB=$(echo "scale=4; $WAL_BYTES / 1024 / 1024 / 1024" | bc)
    echo "WAL (Write-Ahead Log): ${WAL_MB} MB (${WAL_GB} GB)"
fi

echo ""

# Method 3: Use Prometheus TSDB API to get storage stats
echo "📊 Method 3: Prometheus TSDB API Analysis"
echo "-----------------------------------------"
TSDB_STATUS=$(curl -s http://localhost:9090/api/v1/status/tsdb 2>/dev/null)

if [ -n "$TSDB_STATUS" ]; then
    # Extract TSDB statistics
    TOTAL_SERIES=$(echo "$TSDB_STATUS" | grep -o '"totalSeries":[0-9]*' | cut -d':' -f2)
    TOTAL_CHUNKS=$(echo "$TSDB_STATUS" | grep -o '"totalChunks":[0-9]*' | cut -d':' -f2)
    HEAD_SERIES=$(echo "$TSDB_STATUS" | grep -o '"headSeries":[0-9]*' | cut -d':' -f2)
    
    if [ -n "$TOTAL_SERIES" ]; then
        echo "Total time series: ${TOTAL_SERIES}"
    fi
    if [ -n "$TOTAL_CHUNKS" ]; then
        echo "Total chunks: ${TOTAL_CHUNKS}"
    fi
    if [ -n "$HEAD_SERIES" ]; then
        echo "Head series (in-memory): ${HEAD_SERIES}"
    fi
    
    # Try to extract storage size from TSDB status if available
    STORAGE_SIZE=$(echo "$TSDB_STATUS" | grep -o '"storageSize":[0-9.]*' | cut -d':' -f2)
    if [ -n "$STORAGE_SIZE" ]; then
        STORAGE_SIZE_GB=$(echo "scale=4; $STORAGE_SIZE / 1024 / 1024 / 1024" | bc)
        echo "Storage size (from API): ${STORAGE_SIZE_GB} GB"
    fi
else
    echo "⚠️  Could not connect to Prometheus TSDB API endpoint"
fi

echo ""

# Method 4: Use Prometheus metrics API to get ingestion stats
echo "📊 Method 4: Prometheus Metrics API Analysis"
echo "-------------------------------------------"
PROM_METRICS=$(curl -s http://localhost:9090/metrics 2>/dev/null)

if [ -n "$PROM_METRICS" ]; then
    # Extract ingestion rate metrics
    INGESTED_SAMPLES_TOTAL=$(echo "$PROM_METRICS" | grep '^prometheus_tsdb_head_samples_appended_total' | awk '{sum+=$2} END {print sum+0}')
    
    if [ -n "$INGESTED_SAMPLES_TOTAL" ] && [ "$INGESTED_SAMPLES_TOTAL" != "0" ]; then
        echo "Total ingested samples (since start): ${INGESTED_SAMPLES_TOTAL}"
    else
        echo "⚠️  Could not extract ingestion metrics from Prometheus API"
    fi
    
    # Get current ingestion rate (samples per second)
    INGESTION_RATE=$(echo "$PROM_METRICS" | grep '^prometheus_tsdb_head_samples_appended_total' | awk '{sum+=$2} END {print sum+0}')
    if [ -n "$INGESTION_RATE" ] && [ "$INGESTION_RATE" != "0" ]; then
        # Note: This is total samples, not rate. We need to calculate rate differently
        echo "Total samples appended: ${INGESTION_RATE}"
    fi
    
    # Get TSDB head series count
    HEAD_SERIES_COUNT=$(echo "$PROM_METRICS" | grep '^prometheus_tsdb_head_series' | awk '{sum+=$2} END {print sum+0}')
    if [ -n "$HEAD_SERIES_COUNT" ] && [ "$HEAD_SERIES_COUNT" != "0" ]; then
        echo "Head series count: ${HEAD_SERIES_COUNT}"
    fi
else
    echo "⚠️  Could not connect to Prometheus metrics endpoint"
fi

echo ""

# Method 5: Estimate from container uptime (if container has been running for at least 24 hours)
echo "📊 Method 5: Container Uptime-Based Analysis"
echo "---------------------------------------------"
CONTAINER_START=$(docker inspect --format='{{.State.StartedAt}}' $PROM_CONTAINER 2>/dev/null)
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
# 3. Extrapolation from shorter uptime

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

# Method 3: Extrapolation from shorter uptime
if [ -z "$BEST_24H_GROWTH" ] || [ "$BEST_24H_GROWTH" = "0" ]; then
    if [ -n "$AVG_24H_GROWTH" ] && [ "$AVG_24H_GROWTH" -gt 0 ]; then
        BEST_24H_GROWTH=$AVG_24H_GROWTH
        BEST_METHOD="Extrapolated from container uptime (${UPTIME_HOURS} hours)"
    fi
fi

if [ -z "$BEST_24H_GROWTH" ] || [ "$BEST_24H_GROWTH" = "0" ]; then
    echo "❌ Cannot calculate 24-hour growth - insufficient data"
    echo "   Please wait for more metric activity or check Prometheus configuration"
    echo ""
    echo "💡 Suggestions:"
    echo "   1. Wait for at least 24 hours of metric activity"
    echo "   2. Check if metrics are being ingested: curl http://localhost:9090/metrics | grep tsdb"
    echo "   3. Verify Prometheus is scraping targets correctly"
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
echo "Retention Period: 200 hours (8.3 days)"
echo "Current Total Storage: ${CURRENT_TOTAL_MB} MB (${CURRENT_TOTAL_GB} GB)"
echo ""

# Storage projection for retention period (200 hours = 8.3 days)
RETENTION_DAYS=8.3
RETENTION_HOURS=200
PROJECTED_GROWTH_BYTES=$(echo "scale=0; $BEST_24H_GROWTH * $RETENTION_DAYS" | bc)
PROJECTED_GROWTH_GB=$(echo "scale=4; $PROJECTED_GROWTH_BYTES / 1024 / 1024 / 1024" | bc)

echo "💡 Storage Projection:"
echo "  Current: ${CURRENT_TOTAL_GB} GB"
echo "  + 24-hour growth: ${BEST_24H_GROWTH_GB} GB"
echo "  + Projected at retention limit (${RETENTION_DAYS} days): ${PROJECTED_GROWTH_GB} GB"
echo ""

# Warning if growth is high
BEST_24H_GROWTH_GB_INT=$(echo "scale=0; $BEST_24H_GROWTH_GB / 1" | bc)
if [ "$BEST_24H_GROWTH_GB_INT" -gt 5 ]; then
    echo "🚨 WARNING: 24-hour growth exceeds 5GB"
    echo "   Consider reviewing retention policies or metric filtering"
elif [ "$BEST_24H_GROWTH_GB_INT" -gt 1 ]; then
    echo "⚠️  WARNING: 24-hour growth exceeds 1GB"
    echo "   Monitor storage usage closely"
else
    echo "✅ 24-hour growth is within acceptable limits"
fi

echo ""
echo "==============================================="

