#!/bin/bash

# Grafana Explore 查詢指南：Loki aro-001-1 enp86s0 log data
# 說明如何在 Grafana Explore 中查詢 network monitoring 資料

echo "📊 Grafana Explore 查詢指南：Loki aro-001-1 enp86s0 log data"
echo "=========================================================="
echo ""

# 配置資訊
GRAFANA_URL="http://100.64.0.113:3000"
LOKI_URL="http://100.64.0.113:3100"

echo "📋 配置資訊:"
echo "   Grafana URL: $GRAFANA_URL"
echo "   Loki URL: $LOKI_URL"
echo ""

echo "🔍 步驟 1: 開啟 Grafana Explore"
echo "============================="
echo "1. 開啟瀏覽器，訪問: $GRAFANA_URL"
echo "2. 登入 Grafana (如果需要的話)"
echo "3. 點擊左側選單的 'Explore' 圖示 (放大鏡圖示)"
echo "4. 在右上角選擇資料來源為 'Loki'"
echo ""

echo "🔍 步驟 2: 基本查詢語法"
echo "====================="
echo "在 Explore 的查詢框中輸入以下 LogQL 查詢語法："
echo ""

echo "📊 查詢 1: 所有 network monitoring 資料"
echo "------------------------------------"
echo "查詢語法: {job=\"network_monitor\"}"
echo "說明: 查詢所有 network monitoring 相關的 log"
echo ""

echo "📊 查詢 2: GC-aro12-agent 的所有資料"
echo "----------------------------------"
echo "查詢語法: {instance=\"GC-aro12-agent\"}"
echo "說明: 查詢來自 GC-aro12-agent 的所有 log"
echo ""

echo "📊 查詢 3: enp86s0 介面資料"
echo "-------------------------"
echo "查詢語法: {job=\"network_monitor\", interface=\"enp86s0\"}"
echo "說明: 查詢 enp86s0 介面的 network monitoring 資料"
echo ""

echo "📊 查詢 4: 完整的 aro-001-1 enp86s0 查詢"
echo "--------------------------------------"
echo "查詢語法: {job=\"network_monitor\", instance=\"GC-aro12-agent\", interface=\"enp86s0\"}"
echo "說明: 查詢來自 GC-aro12-agent 的 enp86s0 介面資料"
echo ""

echo "🔍 步驟 3: 進階查詢語法"
echo "====================="
echo ""

echo "📊 查詢 5: 包含特定欄位的查詢"
echo "--------------------------"
echo "查詢語法: {job=\"network_monitor\", instance=\"GC-aro12-agent\"} | json | rx_bits > 0"
echo "說明: 查詢有 rx_bits 資料的 log"
echo ""

echo "📊 查詢 6: 時間範圍查詢"
echo "--------------------"
echo "查詢語法: {job=\"network_monitor\", instance=\"GC-aro12-agent\"} | json | __error__=\"\""
echo "說明: 查詢沒有解析錯誤的 log"
echo ""

echo "📊 查詢 7: 統計查詢"
echo "-----------------"
echo "查詢語法: sum by (interface) (count_over_time({job=\"network_monitor\", instance=\"GC-aro12-agent\"}[5m]))"
echo "說明: 統計過去 5 分鐘內每個介面的 log 數量"
echo ""

echo "🔍 步驟 4: 查詢參數設定"
echo "====================="
echo ""

echo "⏰ 時間範圍設定:"
echo "   - 在右上角選擇時間範圍 (例如: Last 1 hour, Last 6 hours)"
echo "   - 或使用自定義時間範圍"
echo ""

echo "📊 查詢限制:"
echo "   - 在查詢框下方可以設定 'Limit' (例如: 1000)"
echo "   - 建議設定合理的限制以避免過多資料"
echo ""

echo "🔍 步驟 5: 實際測試查詢"
echo "====================="
echo ""

echo "讓我們測試一些實際的查詢..."
echo ""

# 測試查詢 1: 檢查是否有 network_monitor 資料
echo "🔍 測試查詢 1: {job=\"network_monitor\"}"
NETWORK_DATA=$(curl -s -G "$LOKI_URL/loki/api/v1/query_range" \
    --data-urlencode 'query={job="network_monitor"}' \
    --data-urlencode 'start='$(date -d '1 hour ago' -u +%Y-%m-%dT%H:%M:%SZ) \
    --data-urlencode 'end='$(date -u +%Y-%m-%dT%H:%M:%SZ) \
    --data-urlencode 'limit=3' 2>/dev/null)

if echo "$NETWORK_DATA" | jq -e '.data.result | length > 0' > /dev/null 2>&1; then
    echo "   ✅ 找到 network_monitor 資料"
    echo "   📊 資料樣本:"
    echo "$NETWORK_DATA" | jq -r '.data.result[0].values[-1][1]' | jq '.' 2>/dev/null
else
    echo "   ❌ 沒有找到 network_monitor 資料"
fi
echo ""

# 測試查詢 2: 檢查 GC-aro12-agent 資料
echo "🔍 測試查詢 2: {instance=\"GC-aro12-agent\"}"
ARO12_DATA=$(curl -s -G "$LOKI_URL/loki/api/v1/query_range" \
    --data-urlencode 'query={instance="GC-aro12-agent"}' \
    --data-urlencode 'start='$(date -d '1 hour ago' -u +%Y-%m-%dT%H:%M:%SZ) \
    --data-urlencode 'end='$(date -u +%Y-%m-%dT%H:%M:%SZ) \
    --data-urlencode 'limit=3' 2>/dev/null)

if echo "$ARO12_DATA" | jq -e '.data.result | length > 0' > /dev/null 2>&1; then
    echo "   ✅ 找到 GC-aro12-agent 資料"
    echo "   📊 Job 類型:"
    echo "$ARO12_DATA" | jq -r '.data.result[] | .stream.job' | sort -u
else
    echo "   ❌ 沒有找到 GC-aro12-agent 資料"
fi
echo ""

# 測試查詢 3: 檢查 enp86s0 介面資料
echo "🔍 測試查詢 3: {job=\"network_monitor\", interface=\"enp86s0\"}"
ENP86S0_DATA=$(curl -s -G "$LOKI_URL/loki/api/v1/query_range" \
    --data-urlencode 'query={job="network_monitor",interface="enp86s0"}' \
    --data-urlencode 'start='$(date -d '1 hour ago' -u +%Y-%m-%dT%H:%M:%SZ) \
    --data-urlencode 'end='$(date -u +%Y-%m-%dT%H:%M:%SZ) \
    --data-urlencode 'limit=2' 2>/dev/null)

if echo "$ENP86S0_DATA" | jq -e '.data.result | length > 0' > /dev/null 2>&1; then
    echo "   ✅ 找到 enp86s0 介面資料"
    echo "   📊 資料樣本:"
    echo "$ENP86S0_DATA" | jq -r '.data.result[0].values[-1][1]' | jq '.' 2>/dev/null
else
    echo "   ❌ 沒有找到 enp86s0 介面資料"
fi
echo ""

echo "🔍 步驟 6: Grafana Explore 使用技巧"
echo "=================================="
echo ""

echo "💡 查詢技巧:"
echo "   1. 使用標籤過濾器: {job=\"network_monitor\"}"
echo "   2. 組合多個標籤: {job=\"network_monitor\", instance=\"GC-aro12-agent\"}"
echo "   3. 使用管道操作符: | json | rx_bits > 0"
echo "   4. 使用正則表達式: {job=~\".*network.*\"}"
echo ""

echo "💡 除錯技巧:"
echo "   1. 先查詢基本標籤: {job=\"network_monitor\"}"
echo "   2. 逐步縮小範圍: 加上 instance, interface 標籤"
echo "   3. 檢查 JSON 解析: | json | __error__=\"\""
echo "   4. 查看原始資料: 不使用管道操作符"
echo ""

echo "💡 視覺化技巧:"
echo "   1. 使用 'Logs' 視圖查看原始 log"
echo "   2. 使用 'Table' 視圖查看結構化資料"
echo "   3. 使用 'Graph' 視圖查看時間序列資料"
echo ""

echo "🔍 步驟 7: 常見問題排除"
echo "======================"
echo ""

echo "❓ 問題 1: 查詢沒有結果"
echo "   解決方案:"
echo "   - 檢查時間範圍是否正確"
echo "   - 確認標籤名稱是否正確"
echo "   - 嘗試更寬鬆的查詢條件"
echo ""

echo "❓ 問題 2: JSON 解析錯誤"
echo "   解決方案:"
echo "   - 先查看原始 log 格式"
echo "   - 檢查 JSON 語法是否正確"
echo "   - 使用 | json | __error__=\"\" 過濾錯誤"
echo ""

echo "❓ 問題 3: 查詢太慢"
echo "   解決方案:"
echo "   - 縮短時間範圍"
echo "   - 增加標籤過濾器"
echo "   - 減少查詢限制"
echo ""

echo "📋 快速參考"
echo "==========="
echo ""
echo "🔗 Grafana Explore URL: $GRAFANA_URL/explore"
echo "🔗 Loki API URL: $LOKI_URL"
echo ""
echo "📊 推薦查詢順序:"
echo "   1. {job=\"network_monitor\"}"
echo "   2. {job=\"network_monitor\", instance=\"GC-aro12-agent\"}"
echo "   3. {job=\"network_monitor\", instance=\"GC-aro12-agent\", interface=\"enp86s0\"}"
echo "   4. {job=\"network_monitor\", instance=\"GC-aro12-agent\"} | json"
echo ""

echo "🎯 成功指標:"
echo "   - 查詢返回 log 資料"
echo "   - JSON 解析成功"
echo "   - 可以看到 rx_bits, tx_bits 等欄位"
echo "   - 時間戳記正確"
echo ""

echo "指南完成時間: $(date)"
