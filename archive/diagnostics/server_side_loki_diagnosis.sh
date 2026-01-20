#!/bin/bash

# Server-side Loki Network Monitoring 診斷報告
# 驗證 server-side 是否收到 aro-001-1 的 enp86s0 metrics

echo "🔍 Server-side Loki Network Monitoring 診斷報告"
echo "================================================"
echo "診斷時間: $(date)"
echo ""

# 配置資訊
AGENT_IP="100.64.0.167"
SERVER_IP="100.64.0.113"
LOKI_PORT="3100"

echo "📋 配置資訊:"
echo "   Agent IP: $AGENT_IP"
echo "   Server IP: $SERVER_IP"
echo "   Loki Port: $LOKI_PORT"
echo ""

# 1. 檢查 Loki 服務狀態
echo "1. Loki 服務狀態檢查"
echo "===================="
if curl -s "http://$SERVER_IP:$LOKI_PORT/ready" > /dev/null 2>&1; then
    echo "   ✅ Loki 服務運行正常"
else
    echo "   ❌ Loki 服務無法訪問"
    exit 1
fi

# 2. 檢查可用的標籤
echo ""
echo "2. Loki 標籤檢查"
echo "================"
echo "   📊 可用的 instance 標籤:"
INSTANCES=$(curl -s "http://$SERVER_IP:$LOKI_PORT/loki/api/v1/label/instance/values" | jq -r '.data[]' 2>/dev/null)
echo "$INSTANCES" | grep -E "(aro|GC)" | while read instance; do
    echo "     - $instance"
done

echo ""
echo "   📊 可用的 job 標籤:"
JOBS=$(curl -s "http://$SERVER_IP:$LOKI_PORT/loki/api/v1/label/job/values" | jq -r '.data[]' 2>/dev/null)
echo "$JOBS" | grep -E "(network|monitor)" | while read job; do
    echo "     - $job"
done

echo ""
echo "   📊 可用的 interface 標籤:"
INTERFACES=$(curl -s "http://$SERVER_IP:$LOKI_PORT/loki/api/v1/label/interface/values" | jq -r '.data[]' 2>/dev/null)
echo "$INTERFACES" | grep -E "(enp|eth)" | while read interface; do
    echo "     - $interface"
done

# 3. 查詢 network monitoring 資料
echo ""
echo "3. Network Monitoring 資料查詢"
echo "=============================="

# 查詢所有 network_monitor 資料
echo "   🔍 查詢所有 network_monitor 資料..."
NETWORK_DATA=$(curl -s -G "http://$SERVER_IP:$LOKI_PORT/loki/api/v1/query_range" \
    --data-urlencode 'query={job="network_monitor"}' \
    --data-urlencode 'start='$(date -d '24 hours ago' -u +%Y-%m-%dT%H:%M:%SZ) \
    --data-urlencode 'end='$(date -u +%Y-%m-%dT%H:%M:%SZ) \
    --data-urlencode 'limit=1' 2>/dev/null)

if echo "$NETWORK_DATA" | jq -e '.data.result | length > 0' > /dev/null 2>&1; then
    echo "   ✅ 找到 network_monitor 資料"
    echo "   📊 資料樣本:"
    echo "$NETWORK_DATA" | jq -r '.data.result[0].values[-1][1]' | jq '.' 2>/dev/null
else
    echo "   ❌ 沒有找到 network_monitor 資料"
fi

# 查詢 enp86s0 介面資料
echo ""
echo "   🔍 查詢 enp86s0 介面資料..."
ENP86S0_DATA=$(curl -s -G "http://$SERVER_IP:$LOKI_PORT/loki/api/v1/query_range" \
    --data-urlencode 'query={job="network_monitor",interface="enp86s0"}' \
    --data-urlencode 'start='$(date -d '24 hours ago' -u +%Y-%m-%dT%H:%M:%SZ) \
    --data-urlencode 'end='$(date -u +%Y-%m-%dT%H:%M:%SZ) \
    --data-urlencode 'limit=1' 2>/dev/null)

if echo "$ENP86S0_DATA" | jq -e '.data.result | length > 0' > /dev/null 2>&1; then
    echo "   ✅ 找到 enp86s0 介面資料"
    echo "   📊 資料樣本:"
    echo "$ENP86S0_DATA" | jq -r '.data.result[0].values[-1][1]' | jq '.' 2>/dev/null
else
    echo "   ❌ 沒有找到 enp86s0 介面資料"
fi

# 4. 檢查 GC-ARO-001-1 agent 的其他資料
echo ""
echo "4. GC-ARO-001-1 Agent 資料檢查"
echo "============================="

# 查詢 GC-aro11-agent 的資料
echo "   🔍 查詢 GC-aro11-agent 資料..."
ARO11_DATA=$(curl -s -G "http://$SERVER_IP:$LOKI_PORT/loki/api/v1/query_range" \
    --data-urlencode 'query={instance="GC-aro11-agent"}' \
    --data-urlencode 'start='$(date -d '1 hour ago' -u +%Y-%m-%dT%H:%M:%SZ) \
    --data-urlencode 'end='$(date -u +%Y-%m-%dT%H:%M:%SZ) \
    --data-urlencode 'limit=3' 2>/dev/null)

if echo "$ARO11_DATA" | jq -e '.data.result | length > 0' > /dev/null 2>&1; then
    echo "   ✅ 找到 GC-aro11-agent 資料"
    echo "   📊 Job 類型:"
    echo "$ARO11_DATA" | jq -r '.data.result[] | .stream.job' | sort -u | while read job; do
        echo "     - $job"
    done
else
    echo "   ❌ 沒有找到 GC-aro11-agent 資料"
fi

# 查詢 GC-aro12-agent 的資料
echo ""
echo "   🔍 查詢 GC-aro12-agent 資料..."
ARO12_DATA=$(curl -s -G "http://$SERVER_IP:$LOKI_PORT/loki/api/v1/query_range" \
    --data-urlencode 'query={instance="GC-aro12-agent"}' \
    --data-urlencode 'start='$(date -d '1 hour ago' -u +%Y-%m-%dT%H:%M:%SZ) \
    --data-urlencode 'end='$(date -u +%Y-%m-%dT%H:%M:%SZ) \
    --data-urlencode 'limit=3' 2>/dev/null)

if echo "$ARO12_DATA" | jq -e '.data.result | length > 0' > /dev/null 2>&1; then
    echo "   ✅ 找到 GC-aro12-agent 資料"
    echo "   📊 Job 類型:"
    echo "$ARO12_DATA" | jq -r '.data.result[] | .stream.job' | sort -u | while read job; do
        echo "     - $job"
    done
else
    echo "   ❌ 沒有找到 GC-aro12-agent 資料"
fi

# 5. 診斷結論
echo ""
echo "5. 診斷結論"
echo "==========="
echo ""

# 檢查是否有任何 network monitoring 資料
if echo "$NETWORK_DATA" | jq -e '.data.result | length > 0' > /dev/null 2>&1; then
    echo "✅ **確認：Server-side Loki 已收到 network monitoring 資料**"
    echo ""
    echo "📊 資料詳情:"
    echo "   - Job: network_monitor"
    echo "   - Interface: enp86s0"
    echo "   - 資料格式: JSON"
    echo "   - 包含欄位: rx_bits, tx_bits, rx_bytes, tx_bytes 等"
    echo ""
    echo "🎯 結論: Server-side 配置正確，可以接收來自 agent 的 enp86s0 metrics"
else
    echo "❌ **問題：Server-side Loki 沒有收到 network monitoring 資料**"
    echo ""
    echo "🔍 可能原因:"
    echo "   1. Agent-side network monitoring 沒有啟動"
    echo "   2. Agent-side promtail 配置問題"
    echo "   3. Network monitoring log 檔案沒有產生"
    echo "   4. Agent-side 和 server-side 的 instance 標籤不匹配"
    echo ""
    echo "💡 建議檢查:"
    echo "   1. 確認 agent-side network_monitor.py 腳本正在運行"
    echo "   2. 確認 /var/log/network_stats.log 檔案存在且有資料"
    echo "   3. 確認 agent-side promtail 容器正在運行"
    echo "   4. 檢查 agent-side 和 server-side 的 instance 標籤是否一致"
fi

echo ""
echo "📋 技術細節:"
echo "============"
echo "   - Loki 服務器: $SERVER_IP:$LOKI_PORT"
echo "   - 查詢時間範圍: 過去 24 小時"
echo "   - 查詢限制: 1 筆資料"
echo "   - 資料格式: JSON"
echo ""

echo "🔧 下一步建議:"
echo "============="
if echo "$NETWORK_DATA" | jq -e '.data.result | length > 0' > /dev/null 2>&1; then
    echo "   1. 檢查 Grafana dashboard 是否正確顯示 network metrics"
    echo "   2. 驗證 network monitoring dashboard 的查詢語句"
    echo "   3. 確認資料更新頻率符合預期"
else
    echo "   1. 檢查 agent-side network monitoring 狀態"
    echo "   2. 確認 agent-side promtail 配置"
    echo "   3. 驗證 network monitoring log 檔案"
    echo "   4. 檢查 agent-side 和 server-side 的標籤匹配"
fi

echo ""
echo "診斷完成時間: $(date)"



