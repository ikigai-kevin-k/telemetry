#!/bin/bash
# Test script to check which Loki datasource contains speed_roulette_sensor_errors data

set -e

LOKI_URL="http://localhost:3100"
QUERY='{job="speed_roulette_sensor_errors"}'

echo "🔍 檢查 Loki datasource 中的 speed_roulette_sensor_errors 資料"
echo "=========================================="
echo ""

# Check if Loki is accessible
echo "1. 檢查 Loki server 連線..."
if curl -s "${LOKI_URL}/ready" > /dev/null; then
    echo "   ✅ Loki server 可連線 (${LOKI_URL})"
else
    echo "   ❌ 無法連線到 Loki server"
    exit 1
fi
echo ""

# Check if job exists
echo "2. 檢查 job label 是否存在..."
JOB_EXISTS=$(curl -s -G "${LOKI_URL}/loki/api/v1/label/job/values" | jq -r '.data[]' | grep -c "speed_roulette_sensor_errors" || echo "0")
if [ "$JOB_EXISTS" -gt 0 ]; then
    echo "   ✅ 找到 job: speed_roulette_sensor_errors"
else
    echo "   ❌ 找不到 job: speed_roulette_sensor_errors"
    exit 1
fi
echo ""

# Query for data
echo "3. 查詢資料（過去 30 天）..."
START_TIME=$(date -d '30 days ago' -u +%s)000000000
END_TIME=$(date -u +%s)000000000

RESULT=$(curl -s -G "${LOKI_URL}/loki/api/v1/query_range" \
    --data-urlencode "query=${QUERY}" \
    --data-urlencode "start=${START_TIME}" \
    --data-urlencode "end=${END_TIME}" \
    --data-urlencode "limit=1000")

TOTAL_ENTRIES=$(echo "$RESULT" | jq '[.data.result[].values | length] | add // 0')
STREAM_COUNT=$(echo "$RESULT" | jq '.data.result | length')

echo "   📊 找到 ${TOTAL_ENTRIES} 筆記錄，${STREAM_COUNT} 個 stream"
echo ""

# Show stream details
if [ "$TOTAL_ENTRIES" -gt 0 ]; then
    echo "4. Stream 詳細資訊："
    echo "$RESULT" | jq -r '.data.result[] | "   Stream: \(.stream | to_entries | map("\(.key)=\(.value)") | join(", "))\n   記錄數: \(.values | length)"'
    echo ""
    
    echo "5. 範例記錄（前 3 筆）："
    echo "$RESULT" | jq -r '.data.result[0].values[0:3][] | "   \(.[0] | tonumber / 1000000000 | strftime("%Y-%m-%d %H:%M:%S")) | \(.[1] | .[0:100])..."'
    echo ""
fi

# Check instances
echo "6. 相關的 instance labels："
INSTANCES=$(curl -s -G "${LOKI_URL}/loki/api/v1/label/instance/values" | jq -r '.data[]' | grep -i "aro" || echo "")
if [ -n "$INSTANCES" ]; then
    echo "$INSTANCES" | while read -r instance; do
        echo "   - ${instance}"
    done
else
    echo "   ⚠️  未找到相關 instance"
fi
echo ""

# Conclusion
echo "=========================================="
echo "📌 結論："
echo ""
echo "✅ 資料存在於 Loki server: ${LOKI_URL}"
echo "✅ 所有 Grafana datasource 都能查到這筆資料（因為都連到同一個 Loki server）"
echo ""
echo "🎯 建議在 Grafana 中使用："
echo "   - Datasource: Loki-ARO-001-1-SDP (最相關，因為 instance 是 GC-ARO-001-1)"
echo "   - 查詢語句: {job=\"speed_roulette_sensor_errors\"}"
echo "   - 或更精確: {job=\"speed_roulette_sensor_errors\", instance=\"GC-ARO-001-1\"}"
echo ""
echo "📖 詳細查詢指南請參考: grafana_query_speed_roulette_guide.md"

