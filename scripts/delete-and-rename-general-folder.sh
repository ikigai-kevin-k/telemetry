#!/bin/bash

# Script to delete empty General folder and rename GeneralDashboards to General

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

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo -e "${RED}錯誤: 需要安裝 jq 工具${NC}"
    exit 1
fi

# Step 1: Find and delete General folder
echo -e "${YELLOW}步驟 1: 尋找 General folder...${NC}"

# Try to find General folder using search API
GENERAL_FOLDER_SEARCH=$(curl -s -u "$GRAFANA_USER:$GRAFANA_PASSWORD" \
    "$GRAFANA_URL/api/search?type=dash-folder&query=General" | jq -r '.[] | select(.title == "General")')

if [ -n "$GENERAL_FOLDER_SEARCH" ] && [ "$GENERAL_FOLDER_SEARCH" != "null" ]; then
    GENERAL_UID=$(echo "$GENERAL_FOLDER_SEARCH" | jq -r '.uid')
    GENERAL_ID=$(echo "$GENERAL_FOLDER_SEARCH" | jq -r '.id')
    
    echo -e "${GREEN}✓ 找到 General folder: UID=$GENERAL_UID, ID=$GENERAL_ID${NC}"
    
    # Check if folder is empty
    DASHBOARDS=$(curl -s -u "$GRAFANA_USER:$GRAFANA_PASSWORD" \
        "$GRAFANA_URL/api/search?folderIds=$GENERAL_ID&type=dash-db" | jq 'length')
    
    if [ "$DASHBOARDS" -gt 0 ]; then
        echo -e "${RED}錯誤: General folder 包含 $DASHBOARDS 個 dashboard，無法刪除${NC}"
        exit 1
    fi
    
    # Delete General folder
    echo -e "${YELLOW}刪除 General folder...${NC}"
    DELETE_RESPONSE=$(curl -s -X DELETE \
        -u "$GRAFANA_USER:$GRAFANA_PASSWORD" \
        "$GRAFANA_URL/api/folders/$GENERAL_UID")
    
    if echo "$DELETE_RESPONSE" | jq -e '.message' > /dev/null 2>&1; then
        ERROR_MSG=$(echo "$DELETE_RESPONSE" | jq -r '.message')
        echo -e "${YELLOW}警告: 無法刪除 General folder: $ERROR_MSG${NC}"
        echo -e "${YELLOW}繼續嘗試重新命名 GeneralDashboards...${NC}"
    else
        echo -e "${GREEN}✓ General folder 已刪除${NC}"
    fi
else
    echo -e "${YELLOW}未找到 General folder（可能已經不存在）${NC}"
fi

echo ""

# Step 2: Rename GeneralDashboards to General
echo -e "${YELLOW}步驟 2: 重新命名 GeneralDashboards 為 General...${NC}"

GENERALDASHBOARDS_UID="f8f00ed1-a0d4-40e9-89dd-c33816343572"

# Get current folder info
FOLDER_INFO=$(curl -s -u "$GRAFANA_USER:$GRAFANA_PASSWORD" \
    "$GRAFANA_URL/api/folders/$GENERALDASHBOARDS_UID")

if echo "$FOLDER_INFO" | jq -e '.message' > /dev/null 2>&1; then
    ERROR_MSG=$(echo "$FOLDER_INFO" | jq -r '.message')
    echo -e "${RED}錯誤: $ERROR_MSG${NC}"
    exit 1
fi

echo -e "${GREEN}✓ 找到 GeneralDashboards folder${NC}"

# Rename folder
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
    echo -e "${RED}錯誤: $ERROR_MSG${NC}"
    exit 1
else
    NEW_TITLE=$(echo "$RENAME_RESPONSE" | jq -r '.title')
    echo -e "${GREEN}✓ Folder 已重新命名為: $NEW_TITLE${NC}"
fi

echo ""
echo -e "${GREEN}=== 完成 ===${NC}"

# Verify
echo ""
echo -e "${YELLOW}驗證結果:${NC}"
DASHBOARDS=$(curl -s -u "$GRAFANA_USER:$GRAFANA_PASSWORD" \
    "$GRAFANA_URL/api/search?type=dash-db" | jq -r '.[] | select(.folderTitle == "General") | "  - \(.title)"')

if [ -n "$DASHBOARDS" ]; then
    echo -e "${GREEN}General folder 中的 dashboards:${NC}"
    echo "$DASHBOARDS"
else
    echo -e "${YELLOW}未找到 General folder 中的 dashboards${NC}"
fi









