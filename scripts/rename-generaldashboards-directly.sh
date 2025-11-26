#!/bin/bash

# Script to directly rename GeneralDashboards to General
# This will work if General folder is truly empty and can be replaced

set -e

GRAFANA_URL="${GRAFANA_URL:-http://localhost:3000}"
GRAFANA_USER="${GRAFANA_USER:-admin}"
GRAFANA_PASSWORD="${GRAFANA_PASSWORD:-admin}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== 直接重新命名 GeneralDashboards 為 General ===${NC}"
echo ""

GENERALDASHBOARDS_UID="f8f00ed1-a0d4-40e9-89dd-c33816343572"

# Get current folder info
echo -e "${YELLOW}取得 GeneralDashboards folder 資訊...${NC}"
FOLDER_INFO=$(curl -s -u "$GRAFANA_USER:$GRAFANA_PASSWORD" \
    "$GRAFANA_URL/api/folders/$GENERALDASHBOARDS_UID")

if echo "$FOLDER_INFO" | jq -e '.message' > /dev/null 2>&1; then
    ERROR_MSG=$(echo "$FOLDER_INFO" | jq -r '.message')
    echo -e "${RED}錯誤: $ERROR_MSG${NC}"
    exit 1
fi

CURRENT_TITLE=$(echo "$FOLDER_INFO" | jq -r '.title')
echo -e "${GREEN}✓ 找到 folder: $CURRENT_TITLE${NC}"
echo ""

# Try to rename directly
echo -e "${YELLOW}嘗試重新命名為 General...${NC}"
RENAME_RESPONSE=$(curl -s -X PUT \
    -u "$GRAFANA_USER:$GRAFANA_PASSWORD" \
    -H "Content-Type: application/json" \
    "$GRAFANA_URL/api/folders/$GENERALDASHBOARDS_UID" \
    -d '{
        "title": "General",
        "uid": "f8f00ed1-a0d4-40e9-89dd-c33816343572"
    }')

if echo "$RENAME_RESPONSE" | jq -e '.message' > /dev/null 2>&1; then
    ERROR_MSG=$(echo "$RENAME_RESPONSE" | jq -r '.message')
    echo -e "${RED}❌ 錯誤: $ERROR_MSG${NC}"
    echo ""
    echo -e "${YELLOW}解決方案：${NC}"
    echo "由於 General folder 是 Grafana 的系統預設 folder，無法刪除或取代。"
    echo ""
    echo -e "${GREEN}選項 1: 保持使用 GeneralDashboards 名稱${NC}"
    echo "  - 所有 dashboard 已經在 GeneralDashboards folder 中"
    echo "  - 功能上沒有差異，只是名稱不同"
    echo ""
    echo -e "${GREEN}選項 2: 使用 Grafana UI 手動移動 dashboard${NC}"
    echo "  1. 在 Grafana UI 中，進入每個 dashboard（Development, SDP Log, System Overview）"
    echo "  2. 點擊 Settings → General"
    echo "  3. 在 'Folder' 下拉選單中，選擇 'General'（如果可選）"
    echo "  4. 儲存變更"
    echo ""
    echo -e "${GREEN}選項 3: 修改 provisioning 配置使用不同的 folder 名稱${NC}"
    echo "  將 dashboard.yml 中的 folder 改為 'GeneralDashboards' 以匹配現有 folder"
    exit 1
else
    NEW_TITLE=$(echo "$RENAME_RESPONSE" | jq -r '.title')
    echo -e "${GREEN}✓ Folder 已成功重新命名為: $NEW_TITLE${NC}"
    echo ""
    echo -e "${GREEN}=== 完成 ===${NC}"
    
    # Verify
    echo ""
    echo -e "${YELLOW}驗證結果:${NC}"
    DASHBOARDS=$(curl -s -u "$GRAFANA_USER:$GRAFANA_PASSWORD" \
        "$GRAFANA_URL/api/search?type=dash-db" | \
        jq -r '.[] | select(.folderTitle == "General") | "  ✓ \(.title)"')
    
    if [ -n "$DASHBOARDS" ]; then
        echo -e "${GREEN}General folder 中的 dashboards:${NC}"
        echo "$DASHBOARDS"
    fi
fi







