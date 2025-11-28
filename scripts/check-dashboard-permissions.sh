#!/bin/bash

# Grafana Dashboard Permissions Check Script
# 用途: 檢查所有 dashboard 的權限設定，確認 viewer role 是否已移除

set -e

# Grafana API 設定
GRAFANA_URL="${GRAFANA_URL:-http://localhost:3000}"
GRAFANA_API_KEY="${GRAFANA_API_KEY}"

# 顏色輸出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 檢查必要參數
if [ -z "$GRAFANA_API_KEY" ]; then
    echo -e "${RED}錯誤: 請設定 GRAFANA_API_KEY 環境變數${NC}"
    echo "例如: export GRAFANA_API_KEY=\"your-api-key-here\""
    echo ""
    echo "取得 API Key 的方法:"
    echo "1. 登入 Grafana (http://localhost:3000)"
    echo "2. 前往 Administration → Users and access → API keys"
    echo "3. 建立新的 API Key (Role: Admin)"
    exit 1
fi

# 檢查 jq 是否安裝
if ! command -v jq &> /dev/null; then
    echo -e "${RED}錯誤: 需要安裝 jq 工具${NC}"
    echo "Ubuntu/Debian: sudo apt-get install jq"
    echo "macOS: brew install jq"
    exit 1
fi

# 檢查 curl 是否安裝
if ! command -v curl &> /dev/null; then
    echo -e "${RED}錯誤: 需要安裝 curl 工具${NC}"
    exit 1
fi

# 測試 Grafana 連線
echo -e "${BLUE}=== Grafana Dashboard 權限檢查工具 ===${NC}"
echo "Grafana URL: $GRAFANA_URL"
echo ""

if ! curl -s -f -H "Authorization: Bearer $GRAFANA_API_KEY" "$GRAFANA_URL/api/org" > /dev/null; then
    echo -e "${RED}錯誤: 無法連接到 Grafana，請檢查 URL 和 API Key${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Grafana 連線成功${NC}"
echo ""

# 取得所有 dashboards
echo -e "${YELLOW}取得所有 dashboards...${NC}"
DASHBOARDS=$(curl -s -H "Authorization: Bearer $GRAFANA_API_KEY" \
    "$GRAFANA_URL/api/search?type=dash-db&limit=1000")

DASHBOARD_COUNT=$(echo "$DASHBOARDS" | jq 'length')
echo -e "${GREEN}✓ 找到 $DASHBOARD_COUNT 個 dashboards${NC}"
echo ""

# 統計變數
TOTAL_DASHBOARDS=0
DASHBOARDS_WITH_VIEWER=0
DASHBOARDS_WITHOUT_VIEWER=0
DASHBOARDS_WITH_VIEWER_LIST=()

# 檢查每個 dashboard 的權限
echo -e "${BLUE}檢查 Dashboard 權限...${NC}"
echo ""

for ((i=0; i<$DASHBOARD_COUNT; i++)); do
    DASHBOARD_UID=$(echo "$DASHBOARDS" | jq -r ".[$i].uid")
    DASHBOARD_TITLE=$(echo "$DASHBOARDS" | jq -r ".[$i].title")
    FOLDER_TITLE=$(echo "$DASHBOARDS" | jq -r ".[$i].folderTitle // \"General\"")
    
    # 取得 dashboard 權限
    PERMISSIONS=$(curl -s -H "Authorization: Bearer $GRAFANA_API_KEY" \
        "$GRAFANA_URL/api/dashboards/uid/$DASHBOARD_UID/permissions" 2>/dev/null || echo "{}")
    
    # 檢查是否有 viewer role 權限
    HAS_VIEWER=$(echo "$PERMISSIONS" | jq -r '.permissions[]? | select(.role == "Viewer" or .role == "viewer") | .role' | head -1)
    
    TOTAL_DASHBOARDS=$((TOTAL_DASHBOARDS + 1))
    
    if [ -n "$HAS_VIEWER" ] && [ "$HAS_VIEWER" != "null" ]; then
        DASHBOARDS_WITH_VIEWER=$((DASHBOARDS_WITH_VIEWER + 1))
        DASHBOARDS_WITH_VIEWER_LIST+=("$DASHBOARD_TITLE (UID: $DASHBOARD_UID, Folder: $FOLDER_TITLE)")
        echo -e "${RED}✗ $DASHBOARD_TITLE${NC} (Folder: $FOLDER_TITLE)"
        echo -e "  ${RED}  → 仍有 Viewer Role 權限${NC}"
        
        # 顯示詳細權限資訊
        VIEWER_PERMS=$(echo "$PERMISSIONS" | jq -r '.permissions[]? | select(.role == "Viewer" or .role == "viewer") | "    Role: \(.role), Permission: \(.permission), PermissionName: \(.permissionName)"')
        if [ -n "$VIEWER_PERMS" ]; then
            echo "$VIEWER_PERMS"
        fi
    else
        DASHBOARDS_WITHOUT_VIEWER=$((DASHBOARDS_WITHOUT_VIEWER + 1))
        echo -e "${GREEN}✓ $DASHBOARD_TITLE${NC} (Folder: $FOLDER_TITLE)"
        echo -e "  ${GREEN}  → 無 Viewer Role 權限${NC}"
    fi
    echo ""
done

# 檢查 folders 權限
echo -e "${BLUE}檢查 Folder 權限...${NC}"
echo ""

FOLDERS=$(curl -s -H "Authorization: Bearer $GRAFANA_API_KEY" \
    "$GRAFANA_URL/api/folders")

FOLDER_COUNT=$(echo "$FOLDERS" | jq 'length')
FOLDERS_WITH_VIEWER=0
FOLDERS_WITHOUT_VIEWER=0
FOLDERS_WITH_VIEWER_LIST=()

for ((i=0; i<$FOLDER_COUNT; i++)); do
    FOLDER_UID=$(echo "$FOLDERS" | jq -r ".[$i].uid")
    FOLDER_TITLE=$(echo "$FOLDERS" | jq -r ".[$i].title")
    
    # 取得 folder 權限
    PERMISSIONS=$(curl -s -H "Authorization: Bearer $GRAFANA_API_KEY" \
        "$GRAFANA_URL/api/folders/$FOLDER_UID/permissions" 2>/dev/null || echo "{}")
    
    # 檢查是否有 viewer role 權限
    HAS_VIEWER=$(echo "$PERMISSIONS" | jq -r '.permissions[]? | select(.role == "Viewer" or .role == "viewer") | .role' | head -1)
    
    if [ -n "$HAS_VIEWER" ] && [ "$HAS_VIEWER" != "null" ]; then
        FOLDERS_WITH_VIEWER=$((FOLDERS_WITH_VIEWER + 1))
        FOLDERS_WITH_VIEWER_LIST+=("$FOLDER_TITLE (UID: $FOLDER_UID)")
        echo -e "${RED}✗ Folder: $FOLDER_TITLE${NC}"
        echo -e "  ${RED}  → 仍有 Viewer Role 權限${NC}"
    else
        FOLDERS_WITHOUT_VIEWER=$((FOLDERS_WITHOUT_VIEWER + 1))
        echo -e "${GREEN}✓ Folder: $FOLDER_TITLE${NC}"
        echo -e "  ${GREEN}  → 無 Viewer Role 權限${NC}"
    fi
    echo ""
done

# 總結報告
echo -e "${BLUE}=== 檢查結果總結 ===${NC}"
echo ""

echo -e "${CYAN}Dashboard 權限統計:${NC}"
echo "  總數: $TOTAL_DASHBOARDS"
echo -e "  ${GREEN}無 Viewer 權限: $DASHBOARDS_WITHOUT_VIEWER${NC}"
echo -e "  ${RED}仍有 Viewer 權限: $DASHBOARDS_WITH_VIEWER${NC}"
echo ""

echo -e "${CYAN}Folder 權限統計:${NC}"
echo "  總數: $FOLDER_COUNT"
echo -e "  ${GREEN}無 Viewer 權限: $FOLDERS_WITHOUT_VIEWER${NC}"
echo -e "  ${RED}仍有 Viewer 權限: $FOLDERS_WITH_VIEWER${NC}"
echo ""

# 列出仍有 Viewer 權限的項目
if [ $DASHBOARDS_WITH_VIEWER -gt 0 ] || [ $FOLDERS_WITH_VIEWER -gt 0 ]; then
    echo -e "${RED}⚠ 仍有 Viewer Role 權限的項目:${NC}"
    echo ""
    
    if [ $DASHBOARDS_WITH_VIEWER -gt 0 ]; then
        echo -e "${RED}Dashboards (${DASHBOARDS_WITH_VIEWER} 個):${NC}"
        for item in "${DASHBOARDS_WITH_VIEWER_LIST[@]}"; do
            echo "  - $item"
        done
        echo ""
    fi
    
    if [ $FOLDERS_WITH_VIEWER -gt 0 ]; then
        echo -e "${RED}Folders (${FOLDERS_WITH_VIEWER} 個):${NC}"
        for item in "${FOLDERS_WITH_VIEWER_LIST[@]}"; do
            echo "  - $item"
        done
        echo ""
    fi
    
    echo -e "${YELLOW}建議:${NC}"
    echo "1. 前往 Grafana UI 移除這些項目的 Viewer 權限"
    echo "2. 或使用 API 移除權限"
    echo ""
else
    echo -e "${GREEN}✓ 所有 Dashboard 和 Folder 都已移除 Viewer Role 權限！${NC}"
    echo ""
    echo -e "${YELLOW}注意:${NC}"
    echo "- 如果 'Round Stat' dashboard 需要 Viewer 存取，請確認它有明確的 Viewer 權限設定"
    echo "- 其他 dashboard 應該只能由 Admin 存取"
    echo ""
fi










