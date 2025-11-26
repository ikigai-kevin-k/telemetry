#!/bin/bash
# 切換到指定分支並觸發 GHCR 構建
# 用於 server 和 agent 分支的自動構建

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
REPO="ikigai-kevin-k/telemetry"
GITHUB_API="https://api.github.com"

# Function to check prerequisites
check_prerequisites() {
    if ! command -v git >/dev/null 2>&1; then
        echo -e "${RED}錯誤: 需要 Git${NC}"
        exit 1
    fi
    
    if ! command -v gh >/dev/null 2>&1; then
        echo -e "${YELLOW}警告: 未安裝 GitHub CLI，將使用 Git 方式觸發${NC}"
    fi
}

# Function to checkout and verify branch
checkout_branch() {
    local branch=$1
    
    echo -e "${BLUE}切換到分支: $branch${NC}"
    
    # Fetch latest
    git fetch origin "$branch" 2>/dev/null || {
        echo -e "${RED}錯誤: 無法獲取分支 $branch${NC}"
        return 1
    }
    
    # Checkout branch
    git checkout "origin/$branch" -B "$branch" 2>/dev/null || {
        echo -e "${RED}錯誤: 無法切換到分支 $branch${NC}"
        return 1
    }
    
    echo -e "${GREEN}✓ 已切換到分支 $branch${NC}"
    
    # Verify Dockerfile exists
    if [ ! -f "Dockerfile.webhook" ]; then
        echo -e "${RED}錯誤: 找不到 Dockerfile.webhook${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✓ Dockerfile.webhook 存在${NC}"
    return 0
}

# Function to trigger workflow via GitHub CLI
trigger_workflow_gh_cli() {
    local branch=$1
    
    echo -e "${BLUE}使用 GitHub CLI 觸發 workflow...${NC}"
    
    if gh workflow run "build-and-push.yml" \
        --ref "$branch" \
        --field branch="$branch" 2>/dev/null; then
        echo -e "${GREEN}✓ 已觸發 workflow${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠ GitHub CLI 觸發失敗，嘗試其他方法${NC}"
        return 1
    fi
}

# Function to trigger workflow via API
trigger_workflow_api() {
    local branch=$1
    local token=${GITHUB_TOKEN:-}
    
    if [ -z "$token" ]; then
        echo -e "${YELLOW}請輸入 GitHub Personal Access Token (需要 workflow 寫入權限):${NC}"
        read -sp "Token: " token
        echo
    fi
    
    if [ -z "$token" ]; then
        echo -e "${RED}錯誤: 未提供 GitHub Token${NC}"
        return 1
    fi
    
    echo -e "${BLUE}使用 GitHub API 觸發 workflow...${NC}"
    
    # Get workflow ID
    workflow_id=$(curl -s -H "Authorization: token $token" \
        -H "Accept: application/vnd.github.v3+json" \
        "$GITHUB_API/repos/$REPO/actions/workflows/build-and-push.yml" | \
        jq -r '.id')
    
    if [ -z "$workflow_id" ] || [ "$workflow_id" = "null" ]; then
        echo -e "${RED}錯誤: 無法獲取 workflow ID${NC}"
        return 1
    fi
    
    # Trigger workflow
    response=$(curl -s -w "\n%{http_code}" -X POST \
        -H "Authorization: token $token" \
        -H "Accept: application/vnd.github.v3+json" \
        -d "{\"ref\":\"$branch\",\"inputs\":{\"branch\":\"$branch\"}}" \
        "$GITHUB_API/repos/$REPO/actions/workflows/$workflow_id/dispatches")
    
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | head -n-1)
    
    if [ "$http_code" -eq 204 ]; then
        echo -e "${GREEN}✓ 已觸發 workflow${NC}"
        return 0
    else
        echo -e "${RED}✗ 觸發失敗 (HTTP $http_code)${NC}"
        echo "$body" | jq '.' 2>/dev/null || echo "$body"
        return 1
    fi
}

# Function to trigger workflow via push
trigger_workflow_push() {
    local branch=$1
    
    echo -e "${BLUE}通過推送觸發 workflow...${NC}"
    echo -e "${YELLOW}這會在當前分支創建一個空提交來觸發 workflow${NC}"
    read -p "確認繼續？(yes/no): " confirm
    
    if [ "$confirm" != "yes" ]; then
        echo "取消操作"
        return 1
    fi
    
    # Create empty commit to trigger workflow
    git commit --allow-empty -m "Trigger GHCR build for $branch" 2>/dev/null || true
    
    # Push to trigger workflow
    if git push origin "$branch" 2>/dev/null; then
        echo -e "${GREEN}✓ 已推送並觸發 workflow${NC}"
        return 0
    else
        echo -e "${RED}✗ 推送失敗${NC}"
        return 1
    fi
}

# Function to rebuild branch
rebuild_branch() {
    local branch=$1
    local current_branch=$(git branch --show-current 2>/dev/null || echo "unknown")
    
    echo -e "\n${GREEN}=== 重建分支: $branch ===${NC}\n"
    
    # Checkout branch
    if ! checkout_branch "$branch"; then
        return 1
    fi
    
    # Try to trigger workflow
    echo -e "\n${YELLOW}觸發 GitHub Actions workflow...${NC}"
    
    # Try GitHub CLI first
    if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
        if trigger_workflow_gh_cli "$branch"; then
            echo -e "${GREEN}✓ Workflow 已觸發${NC}"
        else
            # Fallback to API
            trigger_workflow_api "$branch" || trigger_workflow_push "$branch"
        fi
    else
        # Try API, then push
        if ! trigger_workflow_api "$branch"; then
            trigger_workflow_push "$branch"
        fi
    fi
    
    echo -e "\n${GREEN}✓ 重建流程完成${NC}"
    echo -e "${BLUE}查看構建狀態: https://github.com/$REPO/actions${NC}"
    echo -e "${BLUE}查看包: https://github.com/$REPO/pkgs/container/telemetry-${branch}${NC}\n"
    
    # Restore original branch
    if [ "$current_branch" != "unknown" ] && [ "$current_branch" != "$branch" ]; then
        echo -e "${YELLOW}恢復到原始分支: $current_branch${NC}"
        git checkout "$current_branch" 2>/dev/null || true
    fi
}

# Main function
main() {
    echo -e "${GREEN}=== GHCR 分支重建工具 ===${NC}\n"
    
    check_prerequisites
    
    # Check if we're in a git repository
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        echo -e "${RED}錯誤: 不在 Git 倉庫中${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}請選擇操作:${NC}"
    echo "1) 重建 server 分支"
    echo "2) 重建 agent 分支"
    echo "3) 重建 server 和 agent 分支"
    echo "4) 退出"
    echo
    read -p "請選擇 (1-4): " choice
    
    case $choice in
        1)
            rebuild_branch "server"
            ;;
        2)
            rebuild_branch "agent"
            ;;
        3)
            rebuild_branch "server"
            rebuild_branch "agent"
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

