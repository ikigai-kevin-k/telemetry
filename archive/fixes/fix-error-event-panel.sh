#!/bin/bash

# Fix duplicate sr-test legend in error event panel
# This script helps identify and fix duplicate legendFormat values

set -e

DASHBOARD_FILE="grafana/provisioning/dashboards/general/development.json"
BACKUP_FILE="${DASHBOARD_FILE}.backup.$(date +%Y%m%d_%H%M%S)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Fix Error Event Panel Duplicate Legend ===${NC}"
echo ""

if [ ! -f "$DASHBOARD_FILE" ]; then
    echo -e "${RED}Error: Dashboard file not found: $DASHBOARD_FILE${NC}"
    echo ""
    echo "Please export the dashboard from Grafana UI first:"
    echo "1. Go to Development dashboard in Grafana"
    echo "2. Click Settings (gear icon)"
    echo "3. Select JSON Model tab"
    echo "4. Copy the entire JSON content"
    echo "5. Replace the content in $DASHBOARD_FILE"
    exit 1
fi

# Backup original file
echo -e "${YELLOW}Creating backup: $BACKUP_FILE${NC}"
cp "$DASHBOARD_FILE" "$BACKUP_FILE"
echo -e "${GREEN}✓ Backup created${NC}"
echo ""

# Find error event panel
ERROR_PANEL=$(jq '.panels[] | select(.title | contains("Error Event") or contains("error") or contains("Error") or test("(?i)error.*event"))' "$DASHBOARD_FILE" 2>/dev/null)

if [ -z "$ERROR_PANEL" ] || [ "$ERROR_PANEL" == "null" ]; then
    echo -e "${YELLOW}Warning: No error event panel found in current JSON${NC}"
    echo ""
    echo "The error event panel might have been added in Grafana UI but not exported yet."
    echo "Please export the dashboard from Grafana UI first."
    exit 0
fi

echo -e "${BLUE}Found error event panel. Checking for duplicate legends...${NC}"
echo ""

# Check for duplicate legendFormat
LEGENDS=$(echo "$ERROR_PANEL" | jq -r '.targets[]? | select(.legendFormat != null) | .legendFormat' | sort)
DUPLICATES=$(echo "$LEGENDS" | uniq -d)

if [ -z "$DUPLICATES" ]; then
    echo -e "${GREEN}✓ No duplicate legendFormat found${NC}"
    echo ""
    echo "Current legend formats:"
    echo "$LEGENDS" | uniq
    echo ""
    echo "If you still see duplicate labels in Grafana, the issue might be:"
    echo "1. Multiple queries returning the same label combination"
    echo "2. Queries need different legendFormat to distinguish them"
    exit 0
fi

echo -e "${RED}Found duplicate legendFormat:${NC}"
echo "$DUPLICATES"
echo ""

# Show current targets
echo -e "${BLUE}Current targets:${NC}"
echo "$ERROR_PANEL" | jq '.targets[]? | {refId, legendFormat, expr: (.expr | tostring | .[0:80])}'
echo ""

# Fix duplicate legends
echo -e "${YELLOW}Fixing duplicate legends...${NC}"

# Create a temporary file with fixed configuration
TEMP_FILE=$(mktemp)
jq --argjson panel "$ERROR_PANEL" '
    .panels |= map(
        if (.title | contains("Error Event") or contains("error") or contains("Error") or test("(?i)error.*event")) then
            .targets |= map(
                if .legendFormat == "sr-test" then
                    # Check if there are multiple queries with same legendFormat
                    if (.refId == "A") then
                        .legendFormat = "sr-test-main"
                    elif (.refId == "B") then
                        .legendFormat = "sr-test-alt"
                    elif (.refId == "C") then
                        .legendFormat = "sr-test-3"
                    elif (.refId == "D") then
                        .legendFormat = "sr-test-4"
                    else
                        .legendFormat = "sr-test-\(.refId)"
                    end
                else
                    .
                end
            )
        else
            .
        end
    )
' "$DASHBOARD_FILE" > "$TEMP_FILE"

# Validate JSON
if jq '.' "$TEMP_FILE" > /dev/null 2>&1; then
    mv "$TEMP_FILE" "$DASHBOARD_FILE"
    echo -e "${GREEN}✓ Fixed duplicate legends${NC}"
    echo ""
    echo "Updated legend formats:"
    jq '.panels[] | select(.title | contains("Error Event") or contains("error") or contains("Error") or test("(?i)error.*event")) | .targets[]? | {refId, legendFormat}' "$DASHBOARD_FILE"
    echo ""
    echo -e "${YELLOW}Next steps:${NC}"
    echo "1. Wait 10-30 seconds for Grafana to reload provisioning"
    echo "2. Refresh the Development dashboard in Grafana UI"
    echo "3. Check if duplicate sr-test labels are resolved"
    echo ""
    echo -e "${BLUE}If you need to restore the original:${NC}"
    echo "cp $BACKUP_FILE $DASHBOARD_FILE"
else
    echo -e "${RED}Error: Invalid JSON generated. Restoring backup...${NC}"
    mv "$BACKUP_FILE" "$DASHBOARD_FILE"
    rm -f "$TEMP_FILE"
    exit 1
fi

