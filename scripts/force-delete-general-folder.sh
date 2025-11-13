#!/bin/bash

# Script to force delete General folder by trying different methods

set -e

GRAFANA_URL="${GRAFANA_URL:-http://localhost:3000}"
GRAFANA_USER="${GRAFANA_USER:-admin}"
GRAFANA_PASSWORD="${GRAFANA_PASSWORD:-admin}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== 強制刪除 General Folder ===${NC}"
echo ""

# Method 1: Try to find General folder in all folders
echo -e "${YELLOW}方法 1: 搜尋所有 folders...${NC}"
ALL_FOLDERS=$(curl -s -u "$GRAFANA_USER:$GRAFANA_PASSWORD" \
    "$GRAFANA_URL/api/folders")

# Try common UIDs for General folder
POSSIBLE_UIDS=("general" "General" "GENERAL" "0")

for FOLDER_UID_TRY in "${POSSIBLE_UIDS[@]}"; do
    echo -e "${YELLOW}嘗試 UID: $FOLDER_UID_TRY${NC}"
    FOLDER_INFO=$(curl -s -u "$GRAFANA_USER:$GRAFANA_PASSWORD" \
        "$GRAFANA_URL/api/folders/$FOLDER_UID_TRY" 2>/dev/null)
    
    if ! echo "$FOLDER_INFO" | jq -e '.message' > /dev/null 2>&1; then
        FOLDER_TITLE=$(echo "$FOLDER_INFO" | jq -r '.title // empty')
        if [ "$FOLDER_TITLE" = "General" ]; then
            echo -e "${GREEN}✓ 找到 General folder: UID=$FOLDER_UID_TRY${NC}"
            
            # Check if empty
            FOLDER_ID=$(echo "$FOLDER_INFO" | jq -r '.id')
            DASHBOARDS=$(curl -s -u "$GRAFANA_USER:$GRAFANA_PASSWORD" \
                "$GRAFANA_URL/api/search?folderIds=$FOLDER_ID&type=dash-db" | jq 'length')
            
            if [ "$DASHBOARDS" -eq 0 ]; then
                echo -e "${YELLOW}刪除 General folder (UID: $FOLDER_UID_TRY)...${NC}"
                DELETE_RESPONSE=$(curl -s -X DELETE \
                    -u "$GRAFANA_USER:$GRAFANA_PASSWORD" \
                    "$GRAFANA_URL/api/folders/$FOLDER_UID_TRY")
                
                if echo "$DELETE_RESPONSE" | jq -e '.message' > /dev/null 2>&1; then
                    ERROR_MSG=$(echo "$DELETE_RESPONSE" | jq -r '.message')
                    echo -e "${YELLOW}警告: $ERROR_MSG${NC}"
                else
                    echo -e "${GREEN}✓ General folder 已刪除${NC}"
                    exit 0
                fi
            else
                echo -e "${RED}General folder 包含 $DASHBOARDS 個 dashboard${NC}"
            fi
        fi
    fi
done

# Method 2: Try to find via search API with different queries
echo ""
echo -e "${YELLOW}方法 2: 使用 search API...${NC}"
SEARCH_RESULTS=$(curl -s -u "$GRAFANA_USER:$GRAFANA_PASSWORD" \
    "$GRAFANA_URL/api/search?type=dash-folder&query=General")

GENERAL_FOLDERS=$(echo "$SEARCH_RESULTS" | jq -r '.[] | select(.title == "General")')

if [ -n "$GENERAL_FOLDERS" ] && [ "$GENERAL_FOLDERS" != "null" ]; then
    GENERAL_UID=$(echo "$GENERAL_FOLDERS" | jq -r '.uid')
    echo -e "${GREEN}✓ 透過 search API 找到 General folder: UID=$GENERAL_UID${NC}"
    
    # Try to delete
    DELETE_RESPONSE=$(curl -s -X DELETE \
        -u "$GRAFANA_USER:$GRAFANA_PASSWORD" \
        "$GRAFANA_URL/api/folders/$GENERAL_UID")
    
    if echo "$DELETE_RESPONSE" | jq -e '.message' > /dev/null 2>&1; then
        ERROR_MSG=$(echo "$DELETE_RESPONSE" | jq -r '.message')
        echo -e "${YELLOW}警告: $ERROR_MSG${NC}"
    else
        echo -e "${GREEN}✓ General folder 已刪除${NC}"
        exit 0
    fi
fi

echo ""
echo -e "${YELLOW}無法透過 API 刪除 General folder${NC}"
echo -e "${YELLOW}可能原因:${NC}"
echo "  1. General 是 Grafana 的系統預設 folder，無法刪除"
echo "  2. Folder 有特殊權限限制"
echo ""
echo -e "${YELLOW}建議:${NC}"
echo "  請在 Grafana UI 中手動刪除 General folder："
echo "  1. 前往 Dashboards → Browse"
echo "  2. 找到 General folder"
echo "  3. 點擊 folder 右側的選單（三個點）"
echo "  4. 選擇 Delete"
echo "  5. 確認刪除"

