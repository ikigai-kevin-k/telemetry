#!/bin/bash

# Grafana User Creation Script
# 用途: 建立 Grafana 唯讀使用者並設定特定 dashboard/folder 權限
#
# 用法:
#   export GRAFANA_API_KEY="your-api-key"
#   export GRAFANA_URL="http://localhost:3000"
#   ./scripts/create-grafana-user.sh <username> <email> <password> [display_name] [dashboard_uid] [folder_uid]

set -e

# Grafana API 設定
GRAFANA_URL="${GRAFANA_URL:-http://localhost:3000}"
GRAFANA_API_KEY="${GRAFANA_API_KEY}"

# 使用者資訊
USERNAME="${1}"
EMAIL="${2}"
PASSWORD="${3}"
USER_NAME="${4:-${USERNAME}}"

# Dashboard UID 或 Folder UID（可選）
DASHBOARD_UID="${5}"
FOLDER_UID="${6}"

# 顏色輸出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 檢查必要參數
if [ -z "$GRAFANA_API_KEY" ]; then
    echo -e "${RED}錯誤: 請設定 GRAFANA_API_KEY 環境變數${NC}"
    echo "例如: export GRAFANA_API_KEY=\"your-api-key-here\""
    exit 1
fi

if [ -z "$USERNAME" ] || [ -z "$EMAIL" ] || [ -z "$PASSWORD" ]; then
    echo -e "${YELLOW}用法:${NC}"
    echo "  $0 <username> <email> <password> [display_name] [dashboard_uid] [folder_uid]"
    echo ""
    echo -e "${YELLOW}範例:${NC}"
    echo "  # 建立一般唯讀使用者"
    echo "  $0 viewer1 viewer1@example.com 'secure-pass' 'Viewer One'"
    echo ""
    echo "  # 建立只能存取特定 Dashboard 的使用者"
    echo "  $0 dashboard-viewer viewer@example.com 'secure-pass' 'Dashboard Viewer' 'abc123'"
    echo ""
    echo "  # 建立只能存取特定 Folder 的使用者"
    echo "  $0 folder-viewer viewer@example.com 'secure-pass' 'Folder Viewer' '' 'sdp-monitoring'"
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

echo -e "${GREEN}=== Grafana 使用者建立工具 ===${NC}"
echo "Grafana URL: $GRAFANA_URL"
echo "使用者名稱: $USERNAME"
echo "電子郵件: $EMAIL"
echo "顯示名稱: $USER_NAME"
echo ""

# 測試 Grafana 連線
echo -e "${YELLOW}測試 Grafana 連線...${NC}"
if ! curl -s -f -H "Authorization: Bearer $GRAFANA_API_KEY" "$GRAFANA_URL/api/org" > /dev/null; then
    echo -e "${RED}錯誤: 無法連接到 Grafana，請檢查 URL 和 API Key${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Grafana 連線成功${NC}"
echo ""

# 建立使用者
echo -e "${YELLOW}建立使用者: $USERNAME...${NC}"
USER_RESPONSE=$(curl -s -X POST \
    -H "Authorization: Bearer $GRAFANA_API_KEY" \
    -H "Content-Type: application/json" \
    "$GRAFANA_URL/api/admin/users" \
    -d "{
        \"name\": \"$USER_NAME\",
        \"email\": \"$EMAIL\",
        \"login\": \"$USERNAME\",
        \"password\": \"$PASSWORD\"
    }")

# 檢查回應
if echo "$USER_RESPONSE" | jq -e '.message' > /dev/null 2>&1; then
    ERROR_MSG=$(echo "$USER_RESPONSE" | jq -r '.message')
    if [[ "$ERROR_MSG" == *"already exists"* ]] || [[ "$ERROR_MSG" == *"已存在"* ]]; then
        echo -e "${YELLOW}警告: 使用者已存在，嘗試取得使用者 ID...${NC}"
        # 查詢現有使用者
        USER_RESPONSE=$(curl -s -H "Authorization: Bearer $GRAFANA_API_KEY" \
            "$GRAFANA_URL/api/users/lookup?loginOrEmail=$USERNAME")
    else
        echo -e "${RED}錯誤: $ERROR_MSG${NC}"
        echo "$USER_RESPONSE" | jq '.'
        exit 1
    fi
fi

USER_ID=$(echo "$USER_RESPONSE" | jq -r '.id // empty')

if [ -z "$USER_ID" ] || [ "$USER_ID" = "null" ]; then
    echo -e "${RED}錯誤: 無法取得使用者 ID${NC}"
    echo "$USER_RESPONSE" | jq '.'
    exit 1
fi

echo -e "${GREEN}✓ 使用者已建立/找到，ID: $USER_ID${NC}"
echo ""

# 設定使用者角色為 Viewer（唯讀）
echo -e "${YELLOW}設定使用者角色為 Viewer（唯讀）...${NC}"
ORG_RESPONSE=$(curl -s -X PATCH \
    -H "Authorization: Bearer $GRAFANA_API_KEY" \
    -H "Content-Type: application/json" \
    "$GRAFANA_URL/api/org/users/$USER_ID" \
    -d '{
        "role": "Viewer"
    }')

if echo "$ORG_RESPONSE" | jq -e '.message' > /dev/null 2>&1; then
    echo -e "${YELLOW}警告: $(echo "$ORG_RESPONSE" | jq -r '.message')${NC}"
else
    echo -e "${GREEN}✓ 使用者角色已設定為 Viewer${NC}"
fi
echo ""

# 如果提供了 Folder UID，設定 Folder 權限
if [ -n "$FOLDER_UID" ]; then
    echo -e "${YELLOW}設定 Folder 權限: $FOLDER_UID...${NC}"
    
    # 先檢查 folder 是否存在
    FOLDER_CHECK=$(curl -s -H "Authorization: Bearer $GRAFANA_API_KEY" \
        "$GRAFANA_URL/api/folders/$FOLDER_UID")
    
    if echo "$FOLDER_CHECK" | jq -e '.message' > /dev/null 2>&1; then
        echo -e "${RED}錯誤: Folder '$FOLDER_UID' 不存在${NC}"
        exit 1
    fi
    
    # 設定權限
    PERM_RESPONSE=$(curl -s -X POST \
        -H "Authorization: Bearer $GRAFANA_API_KEY" \
        -H "Content-Type: application/json" \
        "$GRAFANA_URL/api/folders/$FOLDER_UID/permissions" \
        -d "{
            \"items\": [
                {
                    \"userId\": $USER_ID,
                    \"permission\": 1
                }
            ]
        }")
    
    if echo "$PERM_RESPONSE" | jq -e '.message' > /dev/null 2>&1; then
        echo -e "${YELLOW}警告: $(echo "$PERM_RESPONSE" | jq -r '.message')${NC}"
    else
        echo -e "${GREEN}✓ Folder 權限已設定（View 權限）${NC}"
    fi
    echo ""
fi

# 如果提供了 Dashboard UID，設定 Dashboard 權限
if [ -n "$DASHBOARD_UID" ]; then
    echo -e "${YELLOW}設定 Dashboard 權限: $DASHBOARD_UID...${NC}"
    
    # 先檢查 dashboard 是否存在
    DASHBOARD_CHECK=$(curl -s -H "Authorization: Bearer $GRAFANA_API_KEY" \
        "$GRAFANA_URL/api/dashboards/uid/$DASHBOARD_UID")
    
    if echo "$DASHBOARD_CHECK" | jq -e '.message' > /dev/null 2>&1; then
        echo -e "${RED}錯誤: Dashboard '$DASHBOARD_UID' 不存在${NC}"
        exit 1
    fi
    
    # 設定權限
    PERM_RESPONSE=$(curl -s -X POST \
        -H "Authorization: Bearer $GRAFANA_API_KEY" \
        -H "Content-Type: application/json" \
        "$GRAFANA_URL/api/dashboards/uid/$DASHBOARD_UID/permissions" \
        -d "{
            \"items\": [
                {
                    \"userId\": $USER_ID,
                    \"permission\": 1
                }
            ]
        }")
    
    if echo "$PERM_RESPONSE" | jq -e '.message' > /dev/null 2>&1; then
        echo -e "${YELLOW}警告: $(echo "$PERM_RESPONSE" | jq -r '.message')${NC}"
    else
        echo -e "${GREEN}✓ Dashboard 權限已設定（View 權限）${NC}"
    fi
    echo ""
fi

# 完成
echo -e "${GREEN}=== 完成 ===${NC}"
echo "使用者資訊:"
echo "  - 使用者名稱: $USERNAME"
echo "  - 電子郵件: $EMAIL"
echo "  - 顯示名稱: $USER_NAME"
echo "  - 使用者 ID: $USER_ID"
echo "  - 角色: Viewer (唯讀)"
if [ -n "$FOLDER_UID" ]; then
    echo "  - Folder 權限: $FOLDER_UID (View)"
fi
if [ -n "$DASHBOARD_UID" ]; then
    echo "  - Dashboard 權限: $DASHBOARD_UID (View)"
fi
echo ""
echo -e "${YELLOW}使用者現在可以使用以下資訊登入 Grafana:${NC}"
echo "  URL: $GRAFANA_URL"
echo "  帳號: $USERNAME"
echo "  密碼: $PASSWORD"



