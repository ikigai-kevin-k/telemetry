#!/bin/bash

# Complete script to delete General folder and rename GeneralDashboards
# Note: General folder must be deleted manually in UI first

set -e

GRAFANA_URL="${GRAFANA_URL:-http://localhost:3000}"
GRAFANA_USER="${GRAFANA_USER:-admin}"
GRAFANA_PASSWORD="${GRAFANA_PASSWORD:-admin}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== 刪除 General Folder 並重新命名 GeneralDashboards ===${NC}"
echo ""

echo -e "${YELLOW}⚠️  重要：General folder 無法透過 API 刪除${NC}"
echo -e "${YELLOW}請先按照以下步驟在 Grafana UI 中手動刪除：${NC}"
echo ""
echo -e "${GREEN}📋 手動操作步驟：${NC}"
echo ""
echo -e "${BLUE}步驟 1: 刪除 General folder${NC}"
echo "  1. 開啟瀏覽器，前往: ${GRAFANA_URL}"
echo "  2. 登入 Grafana（如果需要）"
echo "  3. 點擊左側選單的 'Dashboards' → 'Browse'"
echo "  4. 在 folder 列表中找到空的 'General' folder"
echo "  5. 點擊 'General' folder 右側的選單圖示（三個點 ⋮）"
echo "  6. 選擇 'Delete'"
echo "  7. 在確認對話框中點擊 'Delete' 確認"
echo ""
echo -e "${BLUE}步驟 2: 完成後回到此腳本${NC}"
echo "  完成步驟 1 後，腳本會自動重新命名 GeneralDashboards 為 General"
echo ""
read -p "完成步驟 1（刪除 General folder）後，按 Enter 繼續..." -r
echo ""

# Verify General folder is deleted
echo -e "${YELLOW}檢查 General folder 是否已刪除...${NC}"
GENERAL_EXISTS=$(curl -s -u "$GRAFANA_USER:$GRAFANA_PASSWORD" \
    "$GRAFANA_URL/api/search?type=dash-folder&query=General" | \
    jq -r '.[] | select(.title == "General") | .uid')

if [ -n "$GENERAL_EXISTS" ] && [ "$GENERAL_EXISTS" != "null" ]; then
    echo -e "${RED}❌ General folder 仍然存在（UID: $GENERAL_EXISTS）${NC}"
    echo -e "${YELLOW}請確認已刪除 General folder，然後再次執行此腳本${NC}"
    exit 1
fi

echo -e "${GREEN}✓ General folder 已刪除${NC}"
echo ""

# Rename GeneralDashboards to General
echo -e "${YELLOW}重新命名 GeneralDashboards 為 General...${NC}"
GENERALDASHBOARDS_UID="f8f00ed1-a0d4-40e9-89dd-c33816343572"

RENAME_RESPONSE=$(curl -s -X PUT \
    -u "$GRAFANA_USER:$GRAFANA_PASSWORD" \
    -H "Content-Type: application/json" \
    "$GRAFANA_URL/api/folders/$GENERALDASHBOARDS_UID" \
    -d "{
        \"title\": \"General\",
        \"uid\": \"$GENERALDASHBOARDS_UID\"
    }")

if echo "$RENAME_RESPONSE" | jq -e '.message' > /dev/null 2>&1; then
    ERROR_MSG=$(echo "$RENAME_RESPONSE" | jq -r '.message')
    echo -e "${RED}❌ 錯誤: $ERROR_MSG${NC}"
    echo ""
    echo -e "${YELLOW}可能原因:${NC}"
    echo "  - General folder 尚未完全刪除"
    echo "  - 請重新整理 Grafana 頁面並確認 General folder 已消失"
    echo "  - 然後再次執行此腳本"
    exit 1
else
    NEW_TITLE=$(echo "$RENAME_RESPONSE" | jq -r '.title')
    echo -e "${GREEN}✓ Folder 已成功重新命名為: $NEW_TITLE${NC}"
fi

echo ""
echo -e "${GREEN}=== 完成 ===${NC}"
echo ""

# Verify final state
echo -e "${YELLOW}驗證結果:${NC}"
DASHBOARDS=$(curl -s -u "$GRAFANA_USER:$GRAFANA_PASSWORD" \
    "$GRAFANA_URL/api/search?type=dash-db" | \
    jq -r '.[] | select(.folderTitle == "General") | "  ✓ \(.title)"')

if [ -n "$DASHBOARDS" ]; then
    echo -e "${GREEN}General folder 中的 dashboards:${NC}"
    echo "$DASHBOARDS"
else
    echo -e "${YELLOW}未找到 General folder 中的 dashboards${NC}"
fi







