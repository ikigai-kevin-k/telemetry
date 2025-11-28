#!/bin/bash

# Script to move existing dashboards to a target folder using Grafana API

set -e

GRAFANA_URL="${GRAFANA_URL:-http://localhost:3000}"
GRAFANA_USER="${GRAFANA_USER:-admin}"
GRAFANA_PASSWORD="${GRAFANA_PASSWORD:-admin}"

TARGET_FOLDER="${1:-General}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== 移動 Dashboards 到 $TARGET_FOLDER Folder ===${NC}"
echo ""

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo -e "${RED}錯誤: 需要安裝 jq 工具${NC}"
    exit 1
fi

# Get target folder ID
echo -e "${YELLOW}取得 $TARGET_FOLDER folder 資訊...${NC}"
TARGET_FOLDER_INFO=$(curl -s -u "$GRAFANA_USER:$GRAFANA_PASSWORD" \
    "$GRAFANA_URL/api/folders" | jq -r ".[] | select(.title == \"$TARGET_FOLDER\")")

if [ -z "$TARGET_FOLDER_INFO" ] || [ "$TARGET_FOLDER_INFO" = "null" ]; then
    echo -e "${RED}錯誤: $TARGET_FOLDER folder 不存在${NC}"
    echo -e "${YELLOW}請先確認 folder 名稱正確，或等待 provisioning 建立 folder${NC}"
    exit 1
fi

TARGET_FOLDER_UID=$(echo "$TARGET_FOLDER_INFO" | jq -r '.uid')
TARGET_FOLDER_ID=$(echo "$TARGET_FOLDER_INFO" | jq -r '.id')

echo -e "${GREEN}✓ 找到 $TARGET_FOLDER folder: UID=$TARGET_FOLDER_UID, ID=$TARGET_FOLDER_ID${NC}"
echo ""

# Dashboards to move
DASHBOARDS=(
    "development-dashboard:Development"
    "b9c076a5-be27-4ee0-a9ff-501f42efe3f3:SDP Log"
    "overview-dashboard:System Overview"
)

for DASHBOARD_INFO in "${DASHBOARDS[@]}"; do
    DASHBOARD_UID="${DASHBOARD_INFO%%:*}"
    DASHBOARD_TITLE="${DASHBOARD_INFO##*:}"
    
    echo -e "${YELLOW}移動 $DASHBOARD_TITLE (UID: $DASHBOARD_UID)...${NC}"
    
    # Get current dashboard
    DASHBOARD_JSON=$(curl -s -u "$GRAFANA_USER:$GRAFANA_PASSWORD" \
        "$GRAFANA_URL/api/dashboards/uid/$DASHBOARD_UID")
    
    if echo "$DASHBOARD_JSON" | jq -e '.message' > /dev/null 2>&1; then
        ERROR_MSG=$(echo "$DASHBOARD_JSON" | jq -r '.message')
        echo -e "${RED}錯誤: $ERROR_MSG${NC}"
        continue
    fi
    
    # Extract dashboard data
    DASHBOARD_DATA=$(echo "$DASHBOARD_JSON" | jq '.dashboard')
    
    # Update folderId
    UPDATED_DASHBOARD=$(echo "$DASHBOARD_DATA" | jq --arg folderId "$TARGET_FOLDER_ID" \
        '. + {folderId: ($folderId | tonumber)}')
    
    # Update dashboard via API
    UPDATE_RESPONSE=$(curl -s -X POST \
        -u "$GRAFANA_USER:$GRAFANA_PASSWORD" \
        -H "Content-Type: application/json" \
        "$GRAFANA_URL/api/dashboards/db" \
        -d "{
            \"dashboard\": $UPDATED_DASHBOARD,
            \"folderId\": $TARGET_FOLDER_ID,
            \"overwrite\": true
        }")
    
    if echo "$UPDATE_RESPONSE" | jq -e '.message' > /dev/null 2>&1; then
        ERROR_MSG=$(echo "$UPDATE_RESPONSE" | jq -r '.message')
        echo -e "${RED}錯誤: $ERROR_MSG${NC}"
    else
        echo -e "${GREEN}✓ $DASHBOARD_TITLE 已移動到 $TARGET_FOLDER folder${NC}"
    fi
    echo ""
done

echo -e "${GREEN}=== 完成 ===${NC}"








