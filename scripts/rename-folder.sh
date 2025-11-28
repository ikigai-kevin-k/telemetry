#!/bin/bash

# Script to rename a Grafana folder

set -e

GRAFANA_URL="${GRAFANA_URL:-http://localhost:3000}"
GRAFANA_USER="${GRAFANA_USER:-admin}"
GRAFANA_PASSWORD="${GRAFANA_PASSWORD:-admin}"

OLD_FOLDER_NAME="${1:-GeneralDashboards}"
NEW_FOLDER_NAME="${2:-General}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== 重新命名 Folder: $OLD_FOLDER_NAME → $NEW_FOLDER_NAME ===${NC}"
echo ""

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo -e "${RED}錯誤: 需要安裝 jq 工具${NC}"
    exit 1
fi

# Get old folder info
OLD_FOLDER_INFO=$(curl -s -u "$GRAFANA_USER:$GRAFANA_PASSWORD" \
    "$GRAFANA_URL/api/folders" | jq -r ".[] | select(.title == \"$OLD_FOLDER_NAME\")")

if [ -z "$OLD_FOLDER_INFO" ] || [ "$OLD_FOLDER_INFO" = "null" ]; then
    echo -e "${RED}錯誤: $OLD_FOLDER_NAME folder 不存在${NC}"
    exit 1
fi

OLD_FOLDER_UID=$(echo "$OLD_FOLDER_INFO" | jq -r '.uid')
OLD_FOLDER_ID=$(echo "$OLD_FOLDER_INFO" | jq -r '.id')

echo -e "${GREEN}✓ 找到 $OLD_FOLDER_NAME folder: UID=$OLD_FOLDER_UID, ID=$OLD_FOLDER_ID${NC}"

# Update folder name
echo -e "${YELLOW}重新命名為 $NEW_FOLDER_NAME...${NC}"
UPDATE_RESPONSE=$(curl -s -X PUT \
    -u "$GRAFANA_USER:$GRAFANA_PASSWORD" \
    -H "Content-Type: application/json" \
    "$GRAFANA_URL/api/folders/$OLD_FOLDER_UID" \
    -d "{
        \"title\": \"$NEW_FOLDER_NAME\",
        \"uid\": \"$OLD_FOLDER_UID\"
    }")

if echo "$UPDATE_RESPONSE" | jq -e '.message' > /dev/null 2>&1; then
    ERROR_MSG=$(echo "$UPDATE_RESPONSE" | jq -r '.message')
    echo -e "${RED}錯誤: $ERROR_MSG${NC}"
    exit 1
else
    echo -e "${GREEN}✓ Folder 已重新命名為 $NEW_FOLDER_NAME${NC}"
fi








