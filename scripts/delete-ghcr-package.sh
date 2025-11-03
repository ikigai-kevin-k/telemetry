#!/bin/bash
# 刪除 GitHub Container Registry 中的舊包
# 使用 GitHub API 刪除指定版本或整個包

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration
OWNER="ikigai-kevin-k"
REPO="telemetry"
PACKAGE_NAME="telemetry-webhook"

# GitHub API endpoint
API_BASE="https://api.github.com"

# Function to check if required tools exist
check_prerequisites() {
    if ! command -v curl >/dev/null 2>&1 && ! command -v jq >/dev/null 2>&1; then
        echo -e "${RED}錯誤: 需要 curl 和 jq${NC}"
        exit 1
    fi
}

# Function to get authentication
get_auth() {
    if [ -z "$GITHUB_TOKEN" ]; then
        echo -e "${YELLOW}請輸入 GitHub Personal Access Token:${NC}"
        echo "  (需要 'delete:packages' 權限)"
        read -sp "Token: " GITHUB_TOKEN
        echo
    fi
    
    if [ -z "$GITHUB_TOKEN" ]; then
        echo -e "${RED}錯誤: 未提供 GitHub Token${NC}"
        exit 1
    fi
}

# Function to list package versions
list_package_versions() {
    echo -e "${YELLOW}獲取包版本列表...${NC}"
    
    response=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
        -H "Accept: application/vnd.github.v3+json" \
        "$API_BASE/user/packages/container/$PACKAGE_NAME/versions")
    
    if echo "$response" | jq -e '.message' >/dev/null 2>&1; then
        error_msg=$(echo "$response" | jq -r '.message')
        echo -e "${RED}錯誤: $error_msg${NC}"
        exit 1
    fi
    
    echo "$response" | jq -r '.[] | "\(.id) - \(.name) (Created: \(.created_at))"'
}

# Function to delete specific package version
delete_version() {
    local version_id=$1
    
    echo -e "${YELLOW}刪除版本 ID: $version_id${NC}"
    
    response=$(curl -s -w "\n%{http_code}" -X DELETE \
        -H "Authorization: token $GITHUB_TOKEN" \
        -H "Accept: application/vnd.github.v3+json" \
        "$API_BASE/user/packages/container/$PACKAGE_NAME/versions/$version_id")
    
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | head -n-1)
    
    if [ "$http_code" -eq 204 ]; then
        echo -e "${GREEN}✓ 成功刪除版本${NC}"
    else
        echo -e "${RED}✗ 刪除失敗 (HTTP $http_code)${NC}"
        echo "$body" | jq '.' 2>/dev/null || echo "$body"
        exit 1
    fi
}

# Function to delete all versions
delete_all_versions() {
    echo -e "${RED}警告: 這將刪除所有版本！${NC}"
    read -p "確認刪除所有版本？(yes/no): " confirm
    
    if [ "$confirm" != "yes" ]; then
        echo "取消操作"
        exit 0
    fi
    
    echo -e "${YELLOW}獲取所有版本...${NC}"
    versions=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
        -H "Accept: application/vnd.github.v3+json" \
        "$API_BASE/user/packages/container/$PACKAGE_NAME/versions" | \
        jq -r '.[].id')
    
    if [ -z "$versions" ]; then
        echo -e "${YELLOW}沒有找到任何版本${NC}"
        exit 0
    fi
    
    count=0
    for version_id in $versions; do
        delete_version "$version_id"
        count=$((count + 1))
    done
    
    echo -e "${GREEN}✓ 已刪除 $count 個版本${NC}"
}

# Function to delete package by tag
delete_by_tag() {
    local tag=$1
    
    echo -e "${YELLOW}查找標籤 '$tag' 的版本...${NC}"
    
    version_id=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
        -H "Accept: application/vnd.github.v3+json" \
        "$API_BASE/user/packages/container/$PACKAGE_NAME/versions" | \
        jq -r ".[] | select(.metadata.container.tags[]? == \"$tag\") | .id" | head -n1)
    
    if [ -z "$version_id" ] || [ "$version_id" = "null" ]; then
        echo -e "${YELLOW}未找到標籤 '$tag' 的版本${NC}"
        exit 0
    fi
    
    delete_version "$version_id"
}

# Main menu
main() {
    echo -e "${GREEN}=== 刪除 GHCR 包工具 ===${NC}\n"
    
    check_prerequisites
    get_auth
    
    echo -e "\n${GREEN}請選擇操作:${NC}"
    echo "1) 列出所有版本"
    echo "2) 刪除指定標籤的版本"
    echo "3) 刪除所有版本"
    echo "4) 退出"
    echo
    read -p "請選擇 (1-4): " choice
    
    case $choice in
        1)
            list_package_versions
            ;;
        2)
            read -p "請輸入要刪除的標籤 (例如: latest, server, agent): " tag
            delete_by_tag "$tag"
            ;;
        3)
            delete_all_versions
            ;;
        4)
            echo "退出"
            exit 0
            ;;
        *)
            echo -e "${RED}無效選擇${NC}"
            exit 1
            ;;
    esac
}

main "$@"

