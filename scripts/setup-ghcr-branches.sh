#!/bin/bash
# GHCR 分支設置和重建腳本
# 用於刪除舊包、重建 server 和 agent 分支

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_ROOT"

echo -e "${GREEN}=== GHCR 分支設置和重建 ===${NC}\n"

# Function to delete old packages
delete_old_packages() {
    echo -e "${BLUE}步驟 1: 刪除舊版本包...${NC}\n"
    
    if [ -f "$SCRIPT_DIR/delete-ghcr-package.sh" ]; then
        echo -e "${YELLOW}運行刪除腳本...${NC}"
        "$SCRIPT_DIR/delete-ghcr-package.sh" || {
            echo -e "${YELLOW}⚠ 刪除腳本失敗或已取消${NC}"
        }
    else
        echo -e "${YELLOW}⚠ 找不到刪除腳本，跳過${NC}"
    fi
    
    echo ""
}

# Function to rebuild server branch
rebuild_server() {
    echo -e "${BLUE}步驟 2: 重建 server 分支...${NC}\n"
    
    if [ -f "$SCRIPT_DIR/rebuild-branches-ghcr.sh" ]; then
        echo -e "${YELLOW}觸發 server 分支構建...${NC}"
        echo "server" | "$SCRIPT_DIR/rebuild-branches-ghcr.sh" || {
            echo -e "${RED}✗ Server 分支重建失敗${NC}"
            return 1
        }
    else
        echo -e "${YELLOW}⚠ 找不到重建腳本，使用手動方式${NC}"
        git fetch origin server
        git checkout origin/server -B server
        echo -e "${GREEN}✓ 已切換到 server 分支${NC}"
        echo -e "${YELLOW}請手動觸發 GitHub Actions 或推送更改${NC}"
    fi
    
    echo ""
}

# Function to rebuild agent branch
rebuild_agent() {
    echo -e "${BLUE}步驟 3: 重建 agent 分支...${NC}\n"
    
    if [ -f "$SCRIPT_DIR/rebuild-branches-ghcr.sh" ]; then
        echo -e "${YELLOW}觸發 agent 分支構建...${NC}"
        echo "agent" | "$SCRIPT_DIR/rebuild-branches-ghcr.sh" || {
            echo -e "${RED}✗ Agent 分支重建失敗${NC}"
            return 1
        }
    else
        echo -e "${YELLOW}⚠ 找不到重建腳本，使用手動方式${NC}"
        git fetch origin agent
        git checkout origin/agent -B agent
        echo -e "${GREEN}✓ 已切換到 agent 分支${NC}"
        echo -e "${YELLOW}請手動觸發 GitHub Actions 或推送更改${NC}"
    fi
    
    echo ""
}

# Main menu
main() {
    echo -e "${GREEN}請選擇操作:${NC}"
    echo "1) 僅刪除舊包"
    echo "2) 僅重建 server 分支"
    echo "3) 僅重建 agent 分支"
    echo "4) 刪除舊包 + 重建 server 分支"
    echo "5) 刪除舊包 + 重建 agent 分支"
    echo "6) 完整流程：刪除舊包 + 重建 server + 重建 agent"
    echo "7) 退出"
    echo
    read -p "請選擇 (1-7): " choice
    
    case $choice in
        1)
            delete_old_packages
            ;;
        2)
            rebuild_server
            ;;
        3)
            rebuild_agent
            ;;
        4)
            delete_old_packages
            rebuild_server
            ;;
        5)
            delete_old_packages
            rebuild_agent
            ;;
        6)
            delete_old_packages
            rebuild_server
            rebuild_agent
            echo -e "${GREEN}✓ 完整流程完成！${NC}\n"
            echo -e "${BLUE}查看構建狀態: https://github.com/ikigai-kevin-k/telemetry/actions${NC}"
            echo -e "${BLUE}查看包:${NC}"
            echo -e "  - Server: https://github.com/ikigai-kevin-k/telemetry/pkgs/container/telemetry-server"
            echo -e "  - Agent: https://github.com/ikigai-kevin-k/telemetry/pkgs/container/telemetry-agent"
            ;;
        7)
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

