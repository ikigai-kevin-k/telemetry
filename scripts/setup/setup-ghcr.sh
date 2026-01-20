#!/bin/bash
# GHCR 快速設置腳本
# 用於幫助用戶快速設置和使用 GitHub Container Registry

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
GHCR_REGISTRY="ghcr.io"
IMAGE_NAME="ikigai-kevin-k/telemetry-webhook"
FULL_IMAGE_NAME="${GHCR_REGISTRY}/${IMAGE_NAME}"

echo -e "${GREEN}=== GHCR 快速設置腳本 ===${NC}\n"

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
echo -e "${YELLOW}檢查必要工具...${NC}"
if ! command_exists docker; then
    echo -e "${RED}錯誤: 未安裝 Docker${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Docker 已安裝${NC}"

if ! command_exists git; then
    echo -e "${RED}錯誤: 未安裝 Git${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Git 已安裝${NC}\n"

# Check if logged in to GHCR
echo -e "${YELLOW}檢查 GHCR 登入狀態...${NC}"
if docker info | grep -q "Username.*ikigai-kevin-k" || \
   docker info | grep -q "ghcr.io"; then
    echo -e "${GREEN}✓ 已登入 GHCR${NC}\n"
    LOGGED_IN=true
else
    echo -e "${YELLOW}未登入 GHCR${NC}\n"
    LOGGED_IN=false
fi

# Login function
login_ghcr() {
    echo -e "${YELLOW}請選擇登入方式:${NC}"
    echo "1) 使用 GitHub Personal Access Token (PAT)"
    echo "2) 使用 GitHub CLI (gh)"
    echo "3) 跳過（稍後手動登入）"
    read -p "請選擇 (1-3): " choice
    
    case $choice in
        1)
            read -sp "請輸入 GitHub Personal Access Token: " token
            echo
            echo "$token" | docker login ghcr.io -u ikigai-kevin-k --password-stdin
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}✓ 登入成功${NC}\n"
                LOGGED_IN=true
            else
                echo -e "${RED}✗ 登入失敗${NC}\n"
                LOGGED_IN=false
            fi
            ;;
        2)
            if command_exists gh; then
                gh auth token | docker login ghcr.io -u ikigai-kevin-k --password-stdin
                if [ $? -eq 0 ]; then
                    echo -e "${GREEN}✓ 登入成功${NC}\n"
                    LOGGED_IN=true
                else
                    echo -e "${RED}✗ 登入失敗，請先運行 'gh auth login'${NC}\n"
                    LOGGED_IN=false
                fi
            else
                echo -e "${RED}錯誤: 未安裝 GitHub CLI${NC}\n"
                LOGGED_IN=false
            fi
            ;;
        3)
            echo -e "${YELLOW}跳過登入，請稍後手動執行:${NC}"
            echo "  docker login ghcr.io -u ikigai-kevin-k\n"
            ;;
        *)
            echo -e "${RED}無效選擇${NC}\n"
            ;;
    esac
}

# Main menu
show_menu() {
    echo -e "${GREEN}請選擇操作:${NC}"
    echo "1) 登入 GHCR"
    echo "2) 構建鏡像"
    echo "3) 推送鏡像到 GHCR"
    echo "4) 拉取鏡像"
    echo "5) 測試鏡像"
    echo "6) 查看本地鏡像"
    echo "7) 顯示完整使用說明"
    echo "8) 退出"
    echo
    read -p "請選擇 (1-8): " choice
    
    case $choice in
        1)
            login_ghcr
            ;;
        2)
            echo -e "\n${YELLOW}構建鏡像...${NC}"
            read -p "使用標籤 (預設: latest): " tag
            tag=${tag:-latest}
            docker build -f Dockerfile.webhook -t "${FULL_IMAGE_NAME}:${tag}" .
            echo -e "${GREEN}✓ 構建完成: ${FULL_IMAGE_NAME}:${tag}${NC}\n"
            ;;
        3)
            if [ "$LOGGED_IN" = false ]; then
                echo -e "${RED}請先登入 GHCR${NC}\n"
                login_ghcr
            fi
            echo -e "\n${YELLOW}推送鏡像...${NC}"
            read -p "推送標籤 (預設: latest): " tag
            tag=${tag:-latest}
            docker push "${FULL_IMAGE_NAME}:${tag}"
            echo -e "${GREEN}✓ 推送完成: ${FULL_IMAGE_NAME}:${tag}${NC}\n"
            echo -e "鏡像位置: https://github.com/${IMAGE_NAME}/pkgs/container/telemetry-webhook\n"
            ;;
        4)
            if [ "$LOGGED_IN" = false ]; then
                echo -e "${RED}請先登入 GHCR${NC}\n"
                login_ghcr
            fi
            echo -e "\n${YELLOW}拉取鏡像...${NC}"
            read -p "拉取標籤 (預設: latest): " tag
            tag=${tag:-latest}
            docker pull "${FULL_IMAGE_NAME}:${tag}"
            echo -e "${GREEN}✓ 拉取完成: ${FULL_IMAGE_NAME}:${tag}${NC}\n"
            ;;
        5)
            echo -e "\n${YELLOW}測試鏡像...${NC}"
            read -p "測試標籤 (預設: latest): " tag
            tag=${tag:-latest}
            
            # Stop and remove existing test container
            docker stop test-webhook 2>/dev/null || true
            docker rm test-webhook 2>/dev/null || true
            
            # Run test container
            docker run -d -p 5000:5000 --name test-webhook "${FULL_IMAGE_NAME}:${tag}"
            echo -e "${GREEN}✓ 容器已啟動${NC}"
            
            # Wait a bit for service to start
            sleep 2
            
            # Test health endpoint
            echo -e "\n${YELLOW}測試健康檢查端點...${NC}"
            if curl -s http://localhost:5000/health > /dev/null; then
                echo -e "${GREEN}✓ 健康檢查通過${NC}"
                curl -s http://localhost:5000/health | python3 -m json.tool || echo
            else
                echo -e "${RED}✗ 健康檢查失敗${NC}"
            fi
            
            echo -e "\n${YELLOW}容器日誌:${NC}"
            docker logs test-webhook
            
            echo -e "\n${YELLOW}停止測試容器:${NC}"
            echo "  docker stop test-webhook"
            echo "  docker rm test-webhook\n"
            ;;
        6)
            echo -e "\n${YELLOW}本地鏡像列表:${NC}\n"
            docker images | grep telemetry-webhook || echo "未找到相關鏡像"
            echo
            ;;
        7)
            echo -e "\n${YELLOW}完整使用說明:${NC}\n"
            cat << EOF
1. 登入 GHCR:
   docker login ghcr.io -u ikigai-kevin-k

2. 構建鏡像:
   docker build -f Dockerfile.webhook -t ${FULL_IMAGE_NAME}:latest .

3. 推送鏡像:
   docker push ${FULL_IMAGE_NAME}:latest

4. 拉取鏡像:
   docker pull ${FULL_IMAGE_NAME}:latest

5. 使用鏡像:
   docker run -d -p 5000:5000 ${FULL_IMAGE_NAME}:latest

6. 在 docker-compose.yml 中使用:
   image: ${FULL_IMAGE_NAME}:latest

詳細說明請參考: GHCR_SETUP.md
EOF
            echo
            ;;
        8)
            echo -e "${GREEN}再見！${NC}\n"
            exit 0
            ;;
        *)
            echo -e "${RED}無效選擇${NC}\n"
            ;;
    esac
}

# Interactive loop
while true; do
    show_menu
done

