#!/bin/bash

# Script to create General folder if it doesn't exist

set -e

GRAFANA_URL="${GRAFANA_URL:-http://localhost:3000}"
GRAFANA_USER="${GRAFANA_USER:-admin}"
GRAFANA_PASSWORD="${GRAFANA_PASSWORD:-admin}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== 建立 General Folder ===${NC}"
echo ""

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo -e "${RED}錯誤: 需要安裝 jq 工具${NC}"
    exit 1
fi

# Check if General folder exists
GENERAL_FOLDER=$(curl -s -u "$GRAFANA_USER:$GRAFANA_PASSWORD" \
    "$GRAFANA_URL/api/folders" | jq -r '.[] | select(.title == "General")')

if [ -n "$GENERAL_FOLDER" ] && [ "$GENERAL_FOLDER" != "null" ]; then
    GENERAL_UID=$(echo "$GENERAL_FOLDER" | jq -r '.uid')
    echo -e "${GREEN}✓ General folder 已存在: UID=$GENERAL_UID${NC}"
    exit 0
fi

# Create General folder
echo -e "${YELLOW}建立 General folder...${NC}"
CREATE_RESPONSE=$(curl -s -X POST \
    -u "$GRAFANA_USER:$GRAFANA_PASSWORD" \
    -H "Content-Type: application/json" \
    "$GRAFANA_URL/api/folders" \
    -d '{
        "title": "General",
        "uid": "general-folder"
    }')

if echo "$CREATE_RESPONSE" | jq -e '.message' > /dev/null 2>&1; then
    ERROR_MSG=$(echo "$CREATE_RESPONSE" | jq -r '.message')
    echo -e "${RED}錯誤: $ERROR_MSG${NC}"
    exit 1
else
    GENERAL_UID=$(echo "$CREATE_RESPONSE" | jq -r '.uid')
    echo -e "${GREEN}✓ General folder 已建立: UID=$GENERAL_UID${NC}"
fi








