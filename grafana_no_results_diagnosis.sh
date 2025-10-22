#!/bin/bash

# Grafana Explore 無結果問題診斷和解決方案
# 針對 "No logs found" 問題的完整診斷

echo "🔍 Grafana Explore 無結果問題診斷"
echo "================================="
echo "診斷時間: $(date)"
echo ""

# 配置資訊
GRAFANA_URL="http://100.64.0.113:3000"
LOKI_URL="http://100.64.0.113:3100"
AGENT_IP="100.64.0.167"

echo "📋 配置資訊:"
echo "   Grafana URL: $GRAFANA_URL"
echo "   Loki URL: $LOKI_URL"
echo "   Agent IP: $AGENT_IP"
echo ""

echo "🔍 問題診斷步驟"
echo "=============="
echo ""

# 1. 檢查 Loki 服務狀態
echo "1. 檢查 Loki 服務狀態"
echo "==================="
if curl -s "$LOKI_URL/ready" > /dev/null 2>&1; then
    echo "   ✅ Loki 服務運行正常"
else
    echo "   ❌ Loki 服務無法訪問"
    echo "   💡 解決方案: 檢查 Loki 容器是否運行"
    exit 1
fi

# 2. 檢查可用的標籤
echo ""
echo "2. 檢查可用的標籤"
echo "==============="
echo "   📊 檢查 job 標籤..."
JOBS=$(curl -s "$LOKI_URL/loki/api/v1/label/job/values" | jq -r '.data[]' 2>/dev/null)
if [ -n "$JOBS" ]; then
    echo "   ✅ 可用的 job 標籤:"
    echo "$JOBS" | while read job; do
        echo "     - $job"
    done
else
    echo "   ❌ 沒有找到任何 job 標籤"
fi

echo ""
echo "   📊 檢查 instance 標籤..."
INSTANCES=$(curl -s "$LOKI_URL/loki/api/v1/label/instance/values" | jq -r '.data[]' 2>/dev/null)
if [ -n "$INSTANCES" ]; then
    echo "   ✅ 可用的 instance 標籤:"
    echo "$INSTANCES" | while read instance; do
        echo "     - $instance"
    done
else
    echo "   ❌ 沒有找到任何 instance 標籤"
fi

# 3. 檢查是否有任何資料
echo ""
echo "3. 檢查是否有任何資料"
echo "==================="
echo "   🔍 查詢所有資料 (過去 24 小時)..."
ALL_DATA=$(curl -s -G "$LOKI_URL/loki/api/v1/query_range" \
    --data-urlencode 'query={}' \
    --data-urlencode 'start='$(date -d '24 hours ago' -u +%Y-%m-%dT%H:%M:%SZ) \
    --data-urlencode 'end='$(date -u +%Y-%m-%dT%H:%M:%SZ) \
    --data-urlencode 'limit=1' 2>/dev/null)

if echo "$ALL_DATA" | jq -e '.data.result | length > 0' > /dev/null 2>&1; then
    echo "   ✅ Loki 中有資料"
    echo "   📊 資料樣本:"
    echo "$ALL_DATA" | jq -r '.data.result[0].stream | keys[]' | head -5
else
    echo "   ❌ Loki 中沒有任何資料"
    echo "   💡 這表示 agent-side 可能沒有傳送任何資料"
fi

# 4. 檢查 network_monitor 相關資料
echo ""
echo "4. 檢查 network_monitor 相關資料"
echo "=============================="
echo "   🔍 查詢 network_monitor job..."
NETWORK_DATA=$(curl -s -G "$LOKI_URL/loki/api/v1/query_range" \
    --data-urlencode 'query={job="network_monitor"}' \
    --data-urlencode 'start='$(date -d '24 hours ago' -u +%Y-%m-%dT%H:%M:%SZ) \
    --data-urlencode 'end='$(date -u +%Y-%m-%dT%H:%M:%SZ) \
    --data-urlencode 'limit=1' 2>/dev/null)

if echo "$NETWORK_DATA" | jq -e '.data.result | length > 0' > /dev/null 2>&1; then
    echo "   ✅ 找到 network_monitor 資料"
else
    echo "   ❌ 沒有找到 network_monitor 資料"
fi

# 5. 檢查 GC-aro12-agent 資料
echo ""
echo "5. 檢查 GC-aro12-agent 資料"
echo "========================="
echo "   🔍 查詢 GC-aro12-agent instance..."
ARO12_DATA=$(curl -s -G "$LOKI_URL/loki/api/v1/query_range" \
    --data-urlencode 'query={instance="GC-aro12-agent"}' \
    --data-urlencode 'start='$(date -d '24 hours ago' -u +%Y-%m-%dT%H:%M:%SZ) \
    --data-urlencode 'end='$(date -u +%Y-%m-%dT%H:%M:%SZ) \
    --data-urlencode 'limit=1' 2>/dev/null)

if echo "$ARO12_DATA" | jq -e '.data.result | length > 0' > /dev/null 2>&1; then
    echo "   ✅ 找到 GC-aro12-agent 資料"
    echo "   📊 Job 類型:"
    echo "$ARO12_DATA" | jq -r '.data.result[] | .stream.job' | sort -u
else
    echo "   ❌ 沒有找到 GC-aro12-agent 資料"
fi

# 6. 檢查其他 agent 資料作為對比
echo ""
echo "6. 檢查其他 agent 資料作為對比"
echo "============================="
echo "   🔍 查詢 GC-aro11-agent instance..."
ARO11_DATA=$(curl -s -G "$LOKI_URL/loki/api/v1/query_range" \
    --data-urlencode 'query={instance="GC-aro11-agent"}' \
    --data-urlencode 'start='$(date -d '1 hour ago' -u +%Y-%m-%dT%H:%M:%SZ) \
    --data-urlencode 'end='$(date -u +%Y-%m-%dT%H:%M:%SZ) \
    --data-urlencode 'limit=1' 2>/dev/null)

if echo "$ARO11_DATA" | jq -e '.data.result | length > 0' > /dev/null 2>&1; then
    echo "   ✅ 找到 GC-aro11-agent 資料"
    echo "   📊 Job 類型:"
    echo "$ARO11_DATA" | jq -r '.data.result[] | .stream.job' | sort -u
else
    echo "   ❌ 沒有找到 GC-aro11-agent 資料"
fi

# 7. 檢查 Loki 容器狀態
echo ""
echo "7. 檢查 Loki 容器狀態"
echo "====================="
LOKI_CONTAINER=$(docker ps --format '{{.Names}}' | grep -i loki)
if [ -n "$LOKI_CONTAINER" ]; then
    echo "   ✅ Loki 容器運行中: $LOKI_CONTAINER"
    echo "   📊 容器狀態:"
    docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' | grep -i loki
else
    echo "   ❌ 沒有找到 Loki 容器"
fi

# 8. 檢查 Loki 日誌
echo ""
echo "8. 檢查 Loki 日誌"
echo "==============="
if [ -n "$LOKI_CONTAINER" ]; then
    echo "   📊 最近的 Loki 日誌 (最後 10 行):"
    docker logs "$LOKI_CONTAINER" --tail 10 2>&1 | grep -E "(error|warn|info)" | tail -5
else
    echo "   ❌ 無法檢查 Loki 日誌 (容器未運行)"
fi

echo ""
echo "🔍 問題分析和解決方案"
echo "==================="
echo ""

# 分析問題
if echo "$ALL_DATA" | jq -e '.data.result | length > 0' > /dev/null 2>&1; then
    echo "✅ Loki 服務正常，有資料進來"
    if echo "$NETWORK_DATA" | jq -e '.data.result | length > 0' > /dev/null 2>&1; then
        echo "✅ Network monitoring 資料存在"
        echo "💡 問題可能是 Grafana Explore 的時間範圍設定"
    else
        echo "❌ Network monitoring 資料不存在"
        echo "💡 問題可能是 agent-side 沒有啟動 network monitoring"
    fi
else
    echo "❌ Loki 中沒有任何資料"
    echo "💡 問題可能是 agent-side 沒有傳送任何資料"
fi

echo ""
echo "🛠️ 解決方案建議"
echo "=============="
echo ""

echo "1. 檢查 Grafana Explore 設定:"
echo "   - 確認時間範圍設定 (建議設為 'Last 6 hours' 或 'Last 24 hours')"
echo "   - 確認資料來源選擇為 'Loki'"
echo "   - 嘗試更寬鬆的查詢條件"
echo ""

echo "2. 檢查 agent-side 狀態:"
echo "   - 確認 agent-side promtail 容器是否運行"
echo "   - 確認 network_monitor.py 腳本是否運行"
echo "   - 確認 /var/log/network_stats.log 檔案是否存在"
echo ""

echo "3. 嘗試不同的查詢語法:"
echo "   - {job=\"network_monitor\"}"
echo "   - {instance=\"GC-aro12-agent\"}"
echo "   - {job=\"network_monitor\", instance=\"GC-aro12-agent\"}"
echo "   - {job=\"network_monitor\", interface=\"enp86s0\"}"
echo ""

echo "4. 檢查時間範圍:"
echo "   - 嘗試 'Last 6 hours'"
echo "   - 嘗試 'Last 24 hours'"
echo "   - 嘗試自定義時間範圍"
echo ""

echo "📋 快速測試查詢"
echo "=============="
echo ""
echo "在 Grafana Explore 中依序嘗試以下查詢:"
echo ""
echo "1. {job=\"network_monitor\"}"
echo "2. {instance=\"GC-aro12-agent\"}"
echo "3. {job=\"network_monitor\", instance=\"GC-aro12-agent\"}"
echo "4. {job=\"network_monitor\", interface=\"enp86s0\"}"
echo "5. {job=\"network_monitor\", instance=\"GC-aro12-agent\", interface=\"enp86s0\"}"
echo ""

echo "💡 如果所有查詢都沒有結果，問題可能在於:"
echo "   - Agent-side 沒有啟動 network monitoring"
echo "   - Agent-side promtail 容器沒有運行"
echo "   - Network monitoring log 檔案沒有產生"
echo "   - Agent-side 和 server-side 的配置不匹配"
echo ""

echo "診斷完成時間: $(date)"
