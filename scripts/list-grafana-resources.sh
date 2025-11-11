#!/bin/bash

# Grafana Resources Listing Script
# 用途: 列出 Grafana 中的 Folders 和 Dashboards，方便取得 UID 用於權限設定

set -e

# Grafana API 設定
GRAFANA_URL="${GRAFANA_URL:-http://localhost:3000}"
GRAFANA_API_KEY="${GRAFANA_API_KEY}"

# 顏色輸出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 檢查必要參數
if [ -z "$GRAFANA_API_KEY" ]; then
    echo -e "${RED}錯誤: 請設定 GRAFANA_API_KEY 環境變數${NC}"
    echo "例如: export GRAFANA_API_KEY=\"your-api-key-here\""
    exit 1
fi

# 檢查 jq 是否安裝
if ! command -v jq &> /dev/null; then
    echo -e "${RED}錯誤: 需要安裝 jq 工具${NC}"
    exit 1
fi

# 檢查 curl 是否安裝
if ! command -v curl &> /dev/null; then
    echo -e "${RED}錯誤: 需要安裝 curl 工具${NC}"
    exit 1
fi

# 測試 Grafana 連線
if ! curl -s -f -H "Authorization: Bearer $GRAFANA_API_KEY" "$GRAFANA_URL/api/org" > /dev/null; then
    echo -e "${RED}錯誤: 無法連接到 Grafana，請檢查 URL 和 API Key${NC}"
    exit 1
fi

echo -e "${GREEN}=== Grafana 資源列表 ===${NC}"
echo "Grafana URL: $GRAFANA_URL"
echo ""

# 列出 Folders
echo -e "${BLUE}📁 Folders:${NC}"
FOLDERS=$(curl -s -H "Authorization: Bearer $GRAFANA_API_KEY" \
    "$GRAFANA_URL/api/folders")

if [ "$(echo "$FOLDERS" | jq 'length')" -eq 0 ]; then
    echo "  (無)"
else
    echo "$FOLDERS" | jq -r '.[] | "  UID: \(.uid) | 名稱: \(.title) | ID: \(.id)"'
fi
echo ""

# 列出 Dashboards
echo -e "${BLUE}📊 Dashboards:${NC}"
DASHBOARDS=$(curl -s -H "Authorization: Bearer $GRAFANA_API_KEY" \
    "$GRAFANA_URL/api/search?type=dash-db")

if [ "$(echo "$DASHBOARDS" | jq 'length')" -eq 0 ]; then
    echo "  (無)"
else
    echo "$DASHBOARDS" | jq -r '.[] | "  UID: \(.uid) | 名稱: \(.title) | Folder: \(.folderTitle // "General") | URL: \(.url)"'
fi
echo ""

# 使用說明
echo -e "${YELLOW}使用說明:${NC}"
echo "1. 複製上述的 UID 用於設定使用者權限"
echo "2. 使用 create-grafana-user.sh 建立使用者並設定權限"
echo ""
echo "範例:"
echo "  # 建立只能存取特定 Folder 的使用者"
echo "  ./scripts/create-grafana-user.sh viewer viewer@example.com 'pass' 'Viewer' '' 'folder-uid-here'"
echo ""
echo "  # 建立只能存取特定 Dashboard 的使用者"
echo "  ./scripts/create-grafana-user.sh viewer viewer@example.com 'pass' 'Viewer' 'dashboard-uid-here'"

