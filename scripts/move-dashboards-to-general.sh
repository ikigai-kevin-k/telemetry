#!/bin/bash

# Script to move dashboards to General folder
# This script deletes the existing empty General folder and updates provisioning

set -e

GRAFANA_URL="${GRAFANA_URL:-http://localhost:3000}"
GRAFANA_USER="${GRAFANA_USER:-admin}"
GRAFANA_PASSWORD="${GRAFANA_PASSWORD:-admin}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== 移動 Dashboards 到 General Folder ===${NC}"
echo ""

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo -e "${RED}錯誤: 需要安裝 jq 工具${NC}"
    exit 1
fi

# Get General folder info
echo -e "${YELLOW}檢查 General folder...${NC}"
GENERAL_FOLDER=$(curl -s -u "$GRAFANA_USER:$GRAFANA_PASSWORD" \
    "$GRAFANA_URL/api/folders" | jq -r '.[] | select(.title == "General")')

if [ -z "$GENERAL_FOLDER" ] || [ "$GENERAL_FOLDER" = "null" ]; then
    echo -e "${GREEN}✓ General folder 不存在，provisioning 會自動建立${NC}"
else
    GENERAL_UID=$(echo "$GENERAL_FOLDER" | jq -r '.uid')
    GENERAL_ID=$(echo "$GENERAL_FOLDER" | jq -r '.id')
    
    echo "找到 General folder: UID=$GENERAL_UID, ID=$GENERAL_ID"
    
    # Check if folder is empty
    DASHBOARDS_IN_GENERAL=$(curl -s -u "$GRAFANA_USER:$GRAFANA_PASSWORD" \
        "http://localhost:3000/api/search?folderIds=$GENERAL_ID&type=dash-db" | jq 'length')
    
    if [ "$DASHBOARDS_IN_GENERAL" -eq 0 ]; then
        echo -e "${YELLOW}General folder 是空的，準備刪除...${NC}"
        
        # Delete the folder
        DELETE_RESPONSE=$(curl -s -X DELETE \
            -u "$GRAFANA_USER:$GRAFANA_PASSWORD" \
            "$GRAFANA_URL/api/folders/$GENERAL_UID")
        
        if echo "$DELETE_RESPONSE" | jq -e '.message' > /dev/null 2>&1; then
            ERROR_MSG=$(echo "$DELETE_RESPONSE" | jq -r '.message')
            echo -e "${RED}錯誤: 無法刪除 General folder: $ERROR_MSG${NC}"
            exit 1
        else
            echo -e "${GREEN}✓ General folder 已刪除${NC}"
        fi
    else
        echo -e "${YELLOW}General folder 包含 $DASHBOARDS_IN_GENERAL 個 dashboard，無法自動刪除${NC}"
        echo -e "${YELLOW}請手動在 Grafana UI 中移動或刪除這些 dashboard 後再執行此腳本${NC}"
        exit 1
    fi
fi

echo ""
echo -e "${GREEN}✓ 準備完成，現在可以更新 dashboard.yml 將 folder 改為 'General'${NC}"
echo -e "${YELLOW}下一步:${NC}"
echo "1. 更新 dashboard.yml 將 folder 從 'GeneralDashboards' 改為 'General'"
echo "2. 重啟 Grafana 或等待自動重新載入"









