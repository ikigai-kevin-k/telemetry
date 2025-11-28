#!/bin/bash

# Script to delete an empty Grafana folder by UID

set -e

GRAFANA_URL="${GRAFANA_URL:-http://localhost:3000}"
GRAFANA_USER="${GRAFANA_USER:-admin}"
GRAFANA_PASSWORD="${GRAFANA_PASSWORD:-admin}"

FOLDER_UID="${1}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

if [ -z "$FOLDER_UID" ]; then
    echo -e "${RED}用法: $0 <folder-uid>${NC}"
    exit 1
fi

echo -e "${BLUE}=== 刪除 Folder (UID: $FOLDER_UID) ===${NC}"
echo ""

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo -e "${RED}錯誤: 需要安裝 jq 工具${NC}"
    exit 1
fi

# Get folder info
FOLDER_INFO=$(curl -s -u "$GRAFANA_USER:$GRAFANA_PASSWORD" \
    "$GRAFANA_URL/api/folders/$FOLDER_UID")

if echo "$FOLDER_INFO" | jq -e '.message' > /dev/null 2>&1; then
    ERROR_MSG=$(echo "$FOLDER_INFO" | jq -r '.message')
    echo -e "${RED}錯誤: $ERROR_MSG${NC}"
    exit 1
fi

FOLDER_TITLE=$(echo "$FOLDER_INFO" | jq -r '.title')
FOLDER_ID=$(echo "$FOLDER_INFO" | jq -r '.id')

echo -e "${YELLOW}Folder: $FOLDER_TITLE (ID: $FOLDER_ID)${NC}"

# Check if folder is empty
DASHBOARDS=$(curl -s -u "$GRAFANA_USER:$GRAFANA_PASSWORD" \
    "http://localhost:3000/api/search?folderIds=$FOLDER_ID&type=dash-db" | jq 'length')

if [ "$DASHBOARDS" -gt 0 ]; then
    echo -e "${RED}錯誤: Folder 包含 $DASHBOARDS 個 dashboard，無法刪除${NC}"
    exit 1
fi

# Delete folder
echo -e "${YELLOW}刪除 folder...${NC}"
DELETE_RESPONSE=$(curl -s -X DELETE \
    -u "$GRAFANA_USER:$GRAFANA_PASSWORD" \
    "$GRAFANA_URL/api/folders/$FOLDER_UID")

if echo "$DELETE_RESPONSE" | jq -e '.message' > /dev/null 2>&1; then
    ERROR_MSG=$(echo "$DELETE_RESPONSE" | jq -r '.message')
    echo -e "${RED}錯誤: $ERROR_MSG${NC}"
    exit 1
else
    echo -e "${GREEN}✓ Folder 已刪除${NC}"
fi








