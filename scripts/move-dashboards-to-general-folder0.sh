#!/bin/bash

# Script to move dashboards to General folder (folderId=0)
# Since General is a system default folder, we can move dashboards to it

set -e

GRAFANA_URL="${GRAFANA_URL:-http://localhost:3000}"
GRAFANA_USER="${GRAFANA_USER:-admin}"
GRAFANA_PASSWORD="${GRAFANA_PASSWORD:-admin}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== 移動 Dashboards 到 General Folder (folderId=0) ===${NC}"
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
    
    # Update folderId to 0 (General folder)
    UPDATED_DASHBOARD=$(echo "$DASHBOARD_DATA" | jq '. + {folderId: 0}')
    
    # Update dashboard via API
    UPDATE_RESPONSE=$(curl -s -X POST \
        -u "$GRAFANA_USER:$GRAFANA_PASSWORD" \
        -H "Content-Type: application/json" \
        "$GRAFANA_URL/api/dashboards/db" \
        -d "{
            \"dashboard\": $UPDATED_DASHBOARD,
            \"folderId\": 0,
            \"overwrite\": true
        }")
    
    if echo "$UPDATE_RESPONSE" | jq -e '.message' > /dev/null 2>&1; then
        ERROR_MSG=$(echo "$UPDATE_RESPONSE" | jq -r '.message')
        echo -e "${RED}錯誤: $ERROR_MSG${NC}"
    else
        echo -e "${GREEN}✓ $DASHBOARD_TITLE 已移動到 General folder${NC}"
    fi
    echo ""
done

echo -e "${GREEN}=== 完成 ===${NC}"

# Verify
echo ""
echo -e "${YELLOW}驗證結果:${NC}"
DASHBOARDS=$(curl -s -u "$GRAFANA_USER:$GRAFANA_PASSWORD" \
    "$GRAFANA_URL/api/search?type=dash-db" | \
    jq -r '.[] | select(.folderId == 0 or .folderTitle == "General") | "  ✓ \(.title) - Folder: \(.folderTitle)"')

if [ -n "$DASHBOARDS" ]; then
    echo -e "${GREEN}General folder 中的 dashboards:${NC}"
    echo "$DASHBOARDS"
else
    echo -e "${YELLOW}未找到 General folder 中的 dashboards${NC}"
fi

