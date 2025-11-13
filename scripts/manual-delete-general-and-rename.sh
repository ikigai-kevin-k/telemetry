#!/bin/bash

# Script to provide instructions for manually deleting General folder and renaming GeneralDashboards

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

echo -e "${YELLOW}由於 General folder 無法透過 API 刪除，請按照以下步驟手動操作：${NC}"
echo ""
echo -e "${GREEN}步驟 1: 刪除 General folder${NC}"
echo "  1. 登入 Grafana: http://100.64.0.113:3000"
echo "  2. 前往 Dashboards → Browse"
echo "  3. 找到空的 'General' folder"
echo "  4. 點擊 folder 右側的選單圖示（三個點 ⋮）"
echo "  5. 選擇 'Delete'"
echo "  6. 確認刪除"
echo ""
echo -e "${GREEN}步驟 2: 重新命名 GeneralDashboards 為 General${NC}"
echo "  1. 在 Dashboards 列表中，找到 'GeneralDashboards' folder"
echo "  2. 點擊 folder 名稱進入 folder"
echo "  3. 點擊右上角的 'Settings'（齒輪圖示）"
echo "  4. 在 'General' 標籤中，將 'Name' 從 'GeneralDashboards' 改為 'General'"
echo "  5. 點擊 'Save'"
echo ""
echo -e "${YELLOW}或者，您也可以：${NC}"
echo "  1. 點擊 GeneralDashboards folder 右側的選單（三個點）"
echo "  2. 選擇 'Manage permissions' 或直接點擊進入 folder 設定"
echo "  3. 修改名稱並儲存"
echo ""

# Try to rename after user confirms deletion
read -p "完成步驟 1 後，按 Enter 繼續嘗試重新命名..." -r
echo ""

echo -e "${YELLOW}嘗試重新命名 GeneralDashboards 為 General...${NC}"
RENAME_RESPONSE=$(curl -s -X PUT \
    -u "$GRAFANA_USER:$GRAFANA_PASSWORD" \
    -H "Content-Type: application/json" \
    "$GRAFANA_URL/api/folders/f8f00ed1-a0d4-40e9-89dd-c33816343572" \
    -d '{
        "title": "General",
        "uid": "f8f00ed1-a0d4-40e9-89dd-c33816343572"
    }')

if echo "$RENAME_RESPONSE" | jq -e '.message' > /dev/null 2>&1; then
    ERROR_MSG=$(echo "$RENAME_RESPONSE" | jq -r '.message')
    echo -e "${RED}錯誤: $ERROR_MSG${NC}"
    echo ""
    echo -e "${YELLOW}請確認已刪除 General folder，然後再次執行此腳本${NC}"
else
    NEW_TITLE=$(echo "$RENAME_RESPONSE" | jq -r '.title')
    echo -e "${GREEN}✓ Folder 已成功重新命名為: $NEW_TITLE${NC}"
    echo ""
    echo -e "${GREEN}=== 完成 ===${NC}"
fi

