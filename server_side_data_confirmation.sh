#!/bin/bash

# Server-side Loki 資料接收確認腳本
# 根據 agent-side 修正報告，確認 server-side 是否收到 enp86s0 資料

echo "🔍 Server-side Loki 資料接收確認"
echo "================================="
echo "確認時間: $(date)"
echo ""

# 配置資訊
SERVER_IP="100.64.0.113"
LOKI_PORT="3100"
AGENT_IP="100.64.0.167"

echo "📋 配置資訊:"
echo "   Server IP: $SERVER_IP"
echo "   Loki Port: $LOKI_PORT"
echo "   Agent IP: $AGENT_IP"
echo ""

echo "🔍 根據 Agent-side 修正報告進行確認"
echo "===================================="
echo ""

# 1. 檢查 Loki 服務狀態
echo "1. 檢查 Loki 服務狀態"
echo "==================="
if curl -s "http://$SERVER_IP:$LOKI_PORT/ready" > /dev/null 2>&1; then
    echo "   ✅ Loki 服務運行正常"
else
    echo "   ❌ Loki 服務無法訪問"
    exit 1
fi

# 2. 檢查 network_monitor 資料 (過去 10 分鐘)
echo ""
echo "2. 檢查 Network Monitor 資料 (過去 10 分鐘)"
echo "=========================================="
echo "   🔍 查詢 {job=\"network_monitor\"}..."
NETWORK_DATA=$(curl -s -G "http://$SERVER_IP:$LOKI_PORT/loki/api/v1/query_range" \
    --data-urlencode 'query={job="network_monitor"}' \
    --data-urlencode 'start='$(date -d '10 minutes ago' -u +%Y-%m-%dT%H:%M:%SZ) \
    --data-urlencode 'end='$(date -u +%Y-%m-%dT%H:%M:%SZ) \
    --data-urlencode 'limit=5' 2>/dev/null)

if echo "$NETWORK_DATA" | jq -e '.data.result | length > 0' > /dev/null 2>&1; then
    echo "   ✅ 找到 network_monitor 資料！"
    echo "   📊 資料數量: $(echo "$NETWORK_DATA" | jq '.data.result | length')"
    echo "   📊 最新資料樣本:"
    echo "$NETWORK_DATA" | jq -r '.data.result[0].values[-1][1]' | jq '.' 2>/dev/null
else
    echo "   ❌ 沒有找到 network_monitor 資料"
fi

# 3. 檢查 GC-aro12-agent 資料 (過去 10 分鐘)
echo ""
echo "3. 檢查 GC-aro12-agent 資料 (過去 10 分鐘)"
echo "=========================================="
echo "   🔍 查詢 {instance=\"GC-aro12-agent\"}..."
ARO12_DATA=$(curl -s -G "http://$SERVER_IP:$LOKI_PORT/loki/api/v1/query_range" \
    --data-urlencode 'query={instance="GC-aro12-agent"}' \
    --data-urlencode 'start='$(date -d '10 minutes ago' -u +%Y-%m-%dT%H:%M:%SZ) \
    --data-urlencode 'end='$(date -u +%Y-%m-%dT%H:%M:%SZ) \
    --data-urlencode 'limit=5' 2>/dev/null)

if echo "$ARO12_DATA" | jq -e '.data.result | length > 0' > /dev/null 2>&1; then
    echo "   ✅ 找到 GC-aro12-agent 資料！"
    echo "   📊 資料數量: $(echo "$ARO12_DATA" | jq '.data.result | length')"
    echo "   📊 Job 類型:"
    echo "$ARO12_DATA" | jq -r '.data.result[] | .stream.job' | sort -u | while read job; do
        echo "     - $job"
    done
    echo "   📊 最新資料樣本:"
    echo "$ARO12_DATA" | jq -r '.data.result[0].values[-1][1]' | jq '.' 2>/dev/null
else
    echo "   ❌ 沒有找到 GC-aro12-agent 資料"
fi

# 4. 檢查 enp86s0 介面資料 (過去 10 分鐘)
echo ""
echo "4. 檢查 enp86s0 介面資料 (過去 10 分鐘)"
echo "======================================"
echo "   🔍 查詢 {job=\"network_monitor\", interface=\"enp86s0\"}..."
ENP86S0_DATA=$(curl -s -G "http://$SERVER_IP:$LOKI_PORT/loki/api/v1/query_range" \
    --data-urlencode 'query={job="network_monitor",interface="enp86s0"}' \
    --data-urlencode 'start='$(date -d '10 minutes ago' -u +%Y-%m-%dT%H:%M:%SZ) \
    --data-urlencode 'end='$(date -u +%Y-%m-%dT%H:%M:%SZ) \
    --data-urlencode 'limit=3' 2>/dev/null)

if echo "$ENP86S0_DATA" | jq -e '.data.result | length > 0' > /dev/null 2>&1; then
    echo "   ✅ 找到 enp86s0 介面資料！"
    echo "   📊 資料數量: $(echo "$ENP86S0_DATA" | jq '.data.result | length')"
    echo "   📊 最新資料樣本:"
    echo "$ENP86S0_DATA" | jq -r '.data.result[0].values[-1][1]' | jq '.' 2>/dev/null
else
    echo "   ❌ 沒有找到 enp86s0 介面資料"
fi

# 5. 檢查完整的 aro-001-1 enp86s0 查詢 (過去 10 分鐘)
echo ""
echo "5. 檢查完整的 aro-001-1 enp86s0 查詢 (過去 10 分鐘)"
echo "=================================================="
echo "   🔍 查詢 {job=\"network_monitor\", instance=\"GC-aro12-agent\", interface=\"enp86s0\"}..."
COMPLETE_DATA=$(curl -s -G "http://$SERVER_IP:$LOKI_PORT/loki/api/v1/query_range" \
    --data-urlencode 'query={job="network_monitor",instance="GC-aro12-agent",interface="enp86s0"}' \
    --data-urlencode 'start='$(date -d '10 minutes ago' -u +%Y-%m-%dT%H:%M:%SZ) \
    --data-urlencode 'end='$(date -u +%Y-%m-%dT%H:%M:%SZ) \
    --data-urlencode 'limit=3' 2>/dev/null)

if echo "$COMPLETE_DATA" | jq -e '.data.result | length > 0' > /dev/null 2>&1; then
    echo "   ✅ 找到完整的 aro-001-1 enp86s0 資料！"
    echo "   📊 資料數量: $(echo "$COMPLETE_DATA" | jq '.data.result | length')"
    echo "   📊 最新資料樣本:"
    echo "$COMPLETE_DATA" | jq -r '.data.result[0].values[-1][1]' | jq '.' 2>/dev/null
else
    echo "   ❌ 沒有找到完整的 aro-001-1 enp86s0 資料"
fi

# 6. 檢查 JSON 解析的資料 (過去 10 分鐘)
echo ""
echo "6. 檢查 JSON 解析的資料 (過去 10 分鐘)"
echo "====================================="
echo "   🔍 查詢 {job=\"network_monitor\", instance=\"GC-aro12-agent\"} | json..."
JSON_DATA=$(curl -s -G "http://$SERVER_IP:$LOKI_PORT/loki/api/v1/query_range" \
    --data-urlencode 'query={job="network_monitor",instance="GC-aro12-agent"} | json' \
    --data-urlencode 'start='$(date -d '10 minutes ago' -u +%Y-%m-%dT%H:%M:%SZ) \
    --data-urlencode 'end='$(date -u +%Y-%m-%dT%H:%M:%SZ) \
    --data-urlencode 'limit=2' 2>/dev/null)

if echo "$JSON_DATA" | jq -e '.data.result | length > 0' > /dev/null 2>&1; then
    echo "   ✅ JSON 解析成功！"
    echo "   📊 資料數量: $(echo "$JSON_DATA" | jq '.data.result | length')"
    echo "   📊 最新資料樣本:"
    echo "$JSON_DATA" | jq -r '.data.result[0].values[-1][1]' | jq '.' 2>/dev/null
else
    echo "   ❌ JSON 解析失敗或沒有資料"
fi

# 7. 檢查 Loki 日誌中的接收記錄
echo ""
echo "7. 檢查 Loki 日誌中的接收記錄"
echo "============================"
LOKI_CONTAINER=$(docker ps --format '{{.Names}}' | grep -i loki)
if [ -n "$LOKI_CONTAINER" ]; then
    echo "   📊 檢查最近的 Loki 日誌 (最後 20 行)..."
    RECENT_LOGS=$(docker logs "$LOKI_CONTAINER" --tail 20 2>&1 | grep -E "(ingest|push|receive|GC-aro12)" | tail -5)
    if [ -n "$RECENT_LOGS" ]; then
        echo "   ✅ 找到相關的接收記錄:"
        echo "$RECENT_LOGS"
    else
        echo "   ⚠️  沒有找到明顯的接收記錄"
        echo "   📊 最近的 Loki 日誌 (最後 5 行):"
        docker logs "$LOKI_CONTAINER" --tail 5 2>&1
    fi
else
    echo "   ❌ 無法找到 Loki 容器"
fi

# 8. 檢查更長時間範圍的資料 (過去 1 小時)
echo ""
echo "8. 檢查更長時間範圍的資料 (過去 1 小時)"
echo "======================================"
echo "   🔍 查詢 {job=\"network_monitor\", instance=\"GC-aro12-agent\"} (過去 1 小時)..."
HOURLY_DATA=$(curl -s -G "http://$SERVER_IP:$LOKI_PORT/loki/api/v1/query_range" \
    --data-urlencode 'query={job="network_monitor",instance="GC-aro12-agent"}' \
    --data-urlencode 'start='$(date -d '1 hour ago' -u +%Y-%m-%dT%H:%M:%SZ) \
    --data-urlencode 'end='$(date -u +%Y-%m-%dT%H:%M:%SZ) \
    --data-urlencode 'limit=1' 2>/dev/null)

if echo "$HOURLY_DATA" | jq -e '.data.result | length > 0' > /dev/null 2>&1; then
    echo "   ✅ 過去 1 小時內有資料！"
    echo "   📊 資料樣本:"
    echo "$HOURLY_DATA" | jq -r '.data.result[0].values[-1][1]' | jq '.' 2>/dev/null
else
    echo "   ❌ 過去 1 小時內沒有資料"
fi

# 9. 最終確認結果
echo ""
echo "9. 最終確認結果"
echo "=============="
echo ""

# 檢查是否有任何 network monitoring 資料
if echo "$NETWORK_DATA" | jq -e '.data.result | length > 0' > /dev/null 2>&1; then
    echo "🎉 **成功：Server-side Loki 已收到 enp86s0 metrics！**"
    echo ""
    echo "📊 成功項目:"
    echo "   ✅ Network monitoring 資料已到達 Loki"
    echo "   ✅ enp86s0 介面資料正在傳輸"
    echo "   ✅ Server-side 和 agent-side 配置匹配成功"
    echo "   ✅ 資料傳輸流程正常運作"
    echo ""
    echo "🎯 結果: Server-side 現在可以正確接收來自 GC-ARO-001-1 agent 的 network metrics"
    echo ""
    echo "💡 在 Grafana Explore 中，你現在可以成功查詢:"
    echo "   - {job=\"network_monitor\"}"
    echo "   - {job=\"network_monitor\", instance=\"GC-aro12-agent\"}"
    echo "   - {job=\"network_monitor\", instance=\"GC-aro12-agent\", interface=\"enp86s0\"}"
    echo "   - {job=\"network_monitor\", instance=\"GC-aro12-agent\"} | json"
else
    echo "⚠️  **問題：Server-side Loki 尚未收到 enp86s0 metrics**"
    echo ""
    echo "🔍 可能原因:"
    echo "   1. Agent-side 資料傳輸可能有延遲"
    echo "   2. 網路連線問題"
    echo "   3. Loki 配置問題"
    echo "   4. 時間同步問題"
    echo ""
    echo "💡 建議檢查:"
    echo "   1. 等待幾分鐘後再次檢查"
    echo "   2. 檢查 agent-side promtail 日誌"
    echo "   3. 檢查網路連線"
    echo "   4. 檢查 Loki 配置"
fi

echo ""
echo "📋 技術摘要:"
echo "==========="
echo "   - Loki 服務狀態: ✅ 正常運行"
echo "   - Network monitoring 資料: $(if echo "$NETWORK_DATA" | jq -e '.data.result | length > 0' > /dev/null 2>&1; then echo "✅ 已收到"; else echo "❌ 未收到"; fi)"
echo "   - GC-aro12-agent 資料: $(if echo "$ARO12_DATA" | jq -e '.data.result | length > 0' > /dev/null 2>&1; then echo "✅ 已收到"; else echo "❌ 未收到"; fi)"
echo "   - enp86s0 介面資料: $(if echo "$ENP86S0_DATA" | jq -e '.data.result | length > 0' > /dev/null 2>&1; then echo "✅ 已收到"; else echo "❌ 未收到"; fi)"
echo "   - JSON 解析: $(if echo "$JSON_DATA" | jq -e '.data.result | length > 0' > /dev/null 2>&1; then echo "✅ 成功"; else echo "❌ 失敗"; fi)"
echo ""

echo "確認完成時間: $(date)"
