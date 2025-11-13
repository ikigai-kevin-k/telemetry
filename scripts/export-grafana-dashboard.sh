#!/bin/bash

# Grafana Dashboard Export Script
# 用途: 從 Grafana 匯出 dashboard JSON 並儲存到 provisioning 目錄

set -e

# Grafana API 設定
GRAFANA_URL="${GRAFANA_URL:-http://localhost:3000}"
GRAFANA_API_KEY="${GRAFANA_API_KEY}"

# 顏色輸出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 檢查必要參數
if [ -z "$GRAFANA_API_KEY" ]; then
    echo -e "${RED}錯誤: 請設定 GRAFANA_API_KEY 環境變數${NC}"
    echo "例如: export GRAFANA_API_KEY=\"your-api-key-here\""
    exit 1
fi

# 檢查參數
if [ -z "$1" ]; then
    echo -e "${YELLOW}用法:${NC}"
    echo "  $0 <dashboard-uid> [output-file]"
    echo ""
    echo -e "${YELLOW}範例:${NC}"
    echo "  # 匯出 Error Event dashboard"
    echo "  $0 error-event-dashboard"
    echo ""
    echo "  # 指定輸出檔案"
    echo "  $0 error-event-dashboard error_event.json"
    echo ""
    echo -e "${YELLOW}取得 Dashboard UID:${NC}"
    echo "1. 在 Grafana UI 中進入 dashboard"
    echo "2. 點擊 Settings (齒輪圖示)"
    echo "3. 在 General 標籤中查看 UID"
    exit 1
fi

DASHBOARD_UID="$1"
OUTPUT_FILE="${2:-${DASHBOARD_UID}.json}"

# 檢查 jq 是否安裝
if ! command -v jq &> /dev/null; then
    echo -e "${RED}錯誤: 需要安裝 jq 工具${NC}"
    exit 1
fi

# 測試 Grafana 連線
echo -e "${BLUE}=== Grafana Dashboard 匯出工具 ===${NC}"
echo "Grafana URL: $GRAFANA_URL"
echo "Dashboard UID: $DASHBOARD_UID"
echo ""

if ! curl -s -f -H "Authorization: Bearer $GRAFANA_API_KEY" "$GRAFANA_URL/api/org" > /dev/null; then
    echo -e "${RED}錯誤: 無法連接到 Grafana，請檢查 URL 和 API Key${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Grafana 連線成功${NC}"
echo ""

# 取得 dashboard JSON
echo -e "${YELLOW}取得 Dashboard JSON...${NC}"
DASHBOARD_JSON=$(curl -s -H "Authorization: Bearer $GRAFANA_API_KEY" \
    "$GRAFANA_URL/api/dashboards/uid/$DASHBOARD_UID")

# 檢查是否成功
if echo "$DASHBOARD_JSON" | jq -e '.message' > /dev/null 2>&1; then
    ERROR_MSG=$(echo "$DASHBOARD_JSON" | jq -r '.message')
    echo -e "${RED}錯誤: $ERROR_MSG${NC}"
    exit 1
fi

# 提取 dashboard 物件（移除 meta 資訊）
DASHBOARD_DATA=$(echo "$DASHBOARD_JSON" | jq '.dashboard')

# 清理不需要的欄位（這些會在 provisioning 時自動設定）
CLEANED_DASHBOARD=$(echo "$DASHBOARD_DATA" | jq '
    del(.id) |
    del(.uid) |
    del(.version) |
    del(.created) |
    del(.createdBy) |
    del(.updated) |
    del(.updatedBy) |
    del(.gnetId) |
    del(.links) |
    . + {
        "id": null,
        "uid": "'"$DASHBOARD_UID"'",
        "version": 1
    }
')

# 確定輸出目錄（根據 dashboard UID 自動判斷）
if [[ "$DASHBOARD_UID" == *"error-event"* ]] || [[ "$DASHBOARD_UID" == *"error"* ]]; then
    OUTPUT_DIR="./grafana/provisioning/dashboards/error-event"
elif [[ "$DASHBOARD_UID" == *"sdp-log"* ]] || [[ "$DASHBOARD_UID" == *"sdp"* ]]; then
    OUTPUT_DIR="./grafana/provisioning/dashboards/sdp-log"
else
    OUTPUT_DIR="./grafana/provisioning/dashboards/general"
fi

if [ ! -d "$OUTPUT_DIR" ]; then
    echo -e "${YELLOW}建立輸出目錄: $OUTPUT_DIR${NC}"
    mkdir -p "$OUTPUT_DIR"
fi

OUTPUT_PATH="$OUTPUT_DIR/$OUTPUT_FILE"

# 儲存檔案
echo "$CLEANED_DASHBOARD" | jq '.' > "$OUTPUT_PATH"

echo -e "${GREEN}✓ Dashboard 已匯出${NC}"
echo "  檔案位置: $OUTPUT_PATH"
echo ""

# 顯示 dashboard 資訊
DASHBOARD_TITLE=$(echo "$CLEANED_DASHBOARD" | jq -r '.title // "Unknown"')
PANEL_COUNT=$(echo "$CLEANED_DASHBOARD" | jq '.panels | length')

echo -e "${BLUE}Dashboard 資訊:${NC}"
echo "  標題: $DASHBOARD_TITLE"
echo "  UID: $DASHBOARD_UID"
echo "  Panel 數量: $PANEL_COUNT"
echo ""

echo -e "${YELLOW}下一步:${NC}"
echo "1. 檢查匯出的 JSON 檔案"
echo "2. 更新 dashboard.yml 加入新的 provider（如果需要的話）"
echo "3. 重啟 Grafana 或等待自動重新載入（約 10 秒）"



