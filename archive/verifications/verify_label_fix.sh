#!/bin/bash

# Server-side Network Monitoring 標籤修正驗證腳本
# 驗證修正後的配置是否能正確接收 GC-ARO-001-1 agent 的 enp86s0 metrics

echo "🔧 Server-side Network Monitoring 標籤修正驗證"
echo "=============================================="
echo "驗證時間: $(date)"
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

# 1. 檢查修正後的配置
echo "1. 檢查修正後的 Promtail 配置"
echo "============================="
if grep -q "instance: GC-aro12-agent" /home/ella/kevin/telemetry/promtail-GC-ARO-001-1-agent.yml; then
    echo "   ✅ Network monitoring 配置使用正確的 instance 標籤: GC-aro12-agent"
else
    echo "   ❌ Network monitoring 配置仍使用錯誤的 instance 標籤"
    exit 1
fi

if grep -q "job: network_monitor" /home/ella/kevin/telemetry/promtail-GC-ARO-001-1-agent.yml; then
    echo "   ✅ Network monitoring job 配置存在"
else
    echo "   ❌ Network monitoring job 配置不存在"
    exit 1
fi

if grep -q "interface: enp86s0" /home/ella/kevin/telemetry/promtail-GC-ARO-001-1-agent.yml; then
    echo "   ✅ enp86s0 interface 配置存在"
else
    echo "   ❌ enp86s0 interface 配置不存在"
    exit 1
fi

# 2. 檢查 Docker Compose 配置
echo ""
echo "2. 檢查 Docker Compose 配置"
echo "==========================="
if grep -q "network_stats.log" /home/ella/kevin/telemetry/docker-compose-GC-ARO-001-1-agent.yml; then
    echo "   ✅ Network stats log 檔案掛載配置存在"
else
    echo "   ❌ Network stats log 檔案掛載配置不存在"
    exit 1
fi

# 3. 檢查 Loki 服務狀態
echo ""
echo "3. 檢查 Loki 服務狀態"
echo "===================="
if curl -s "http://$SERVER_IP:$LOKI_PORT/ready" > /dev/null 2>&1; then
    echo "   ✅ Loki 服務運行正常"
else
    echo "   ❌ Loki 服務無法訪問"
    exit 1
fi

# 4. 查詢修正後的 network monitoring 資料
echo ""
echo "4. 查詢修正後的 Network Monitoring 資料"
echo "====================================="

# 查詢 GC-aro12-agent 的 network monitoring 資料
echo "   🔍 查詢 GC-aro12-agent 的 network monitoring 資料..."
NETWORK_DATA=$(curl -s -G "http://$SERVER_IP:$LOKI_PORT/loki/api/v1/query_range" \
    --data-urlencode 'query={job="network_monitor",instance="GC-aro12-agent"}' \
    --data-urlencode 'start='$(date -d '1 hour ago' -u +%Y-%m-%dT%H:%M:%SZ) \
    --data-urlencode 'end='$(date -u +%Y-%m-%dT%H:%M:%SZ) \
    --data-urlencode 'limit=3' 2>/dev/null)

if echo "$NETWORK_DATA" | jq -e '.data.result | length > 0' > /dev/null 2>&1; then
    echo "   ✅ 找到 GC-aro12-agent 的 network monitoring 資料"
    echo "   📊 資料樣本:"
    echo "$NETWORK_DATA" | jq -r '.data.result[0].values[-1][1]' | jq '.' 2>/dev/null
else
    echo "   ⚠️  還沒有找到 GC-aro12-agent 的 network monitoring 資料"
    echo "   💡 這可能是因為 agent-side 還沒有重新啟動 promtail 容器"
fi

# 查詢 enp86s0 介面資料
echo ""
echo "   🔍 查詢 enp86s0 介面資料..."
ENP86S0_DATA=$(curl -s -G "http://$SERVER_IP:$LOKI_PORT/loki/api/v1/query_range" \
    --data-urlencode 'query={job="network_monitor",instance="GC-aro12-agent",interface="enp86s0"}' \
    --data-urlencode 'start='$(date -d '1 hour ago' -u +%Y-%m-%dT%H:%M:%SZ) \
    --data-urlencode 'end='$(date -u +%Y-%m-%dT%H:%M:%SZ) \
    --data-urlencode 'limit=1' 2>/dev/null)

if echo "$ENP86S0_DATA" | jq -e '.data.result | length > 0' > /dev/null 2>&1; then
    echo "   ✅ 找到 enp86s0 介面資料"
    echo "   📊 資料樣本:"
    echo "$ENP86S0_DATA" | jq -r '.data.result[0].values[-1][1]' | jq '.' 2>/dev/null
else
    echo "   ⚠️  還沒有找到 enp86s0 介面資料"
fi

# 5. 檢查現有的 SDP log 配置是否仍然正常
echo ""
echo "5. 檢查現有的 SDP Log 配置"
echo "=========================="
SDP_DATA=$(curl -s -G "http://$SERVER_IP:$LOKI_PORT/loki/api/v1/query_range" \
    --data-urlencode 'query={job="studio_sdp_roulette",instance="GC-aro11-agent"}' \
    --data-urlencode 'start='$(date -d '1 hour ago' -u +%Y-%m-%dT%H:%M:%SZ) \
    --data-urlencode 'end='$(date -u +%Y-%m-%dT%H:%M:%SZ) \
    --data-urlencode 'limit=1' 2>/dev/null)

if echo "$SDP_DATA" | jq -e '.data.result | length > 0' > /dev/null 2>&1; then
    echo "   ✅ SDP log 配置仍然正常運作"
    echo "   📊 SDP log 資料持續接收中"
else
    echo "   ⚠️  SDP log 配置可能有問題"
fi

# 6. 總結
echo ""
echo "6. 修正結果總結"
echo "=============="
echo ""

if echo "$NETWORK_DATA" | jq -e '.data.result | length > 0' > /dev/null 2>&1; then
    echo "✅ **修正成功：Server-side 已能接收 GC-ARO-001-1 agent 的 enp86s0 metrics**"
    echo ""
    echo "📊 修正內容:"
    echo "   - 將 network monitoring 的 instance 標籤從 GC-aro11-agent 改為 GC-aro12-agent"
    echo "   - 保持現有的 SDP log 配置不變"
    echo "   - 新增專門的 network monitoring job 配置"
    echo ""
    echo "🎯 結果: Server-side 現在可以正確接收來自 aro-001-1 agent 的 network metrics"
else
    echo "⚠️  **配置已修正，但資料尚未到達**"
    echo ""
    echo "📊 修正內容:"
    echo "   - ✅ 將 network monitoring 的 instance 標籤從 GC-aro11-agent 改為 GC-aro12-agent"
    echo "   - ✅ 保持現有的 SDP log 配置不變"
    echo "   - ✅ 新增專門的 network monitoring job 配置"
    echo ""
    echo "💡 下一步:"
    echo "   1. 重新啟動 agent-side 的 promtail 容器"
    echo "   2. 確認 agent-side network monitoring 正在運行"
    echo "   3. 等待資料傳輸到 server-side"
fi

echo ""
echo "🔧 技術細節:"
echo "============"
echo "   - 修正的檔案: promtail-GC-ARO-001-1-agent.yml"
echo "   - 修正的標籤: instance: GC-aro12-agent"
echo "   - 保持的配置: 所有現有的 SDP log 配置"
echo "   - 新增的配置: network monitoring job"
echo ""

echo "驗證完成時間: $(date)"



