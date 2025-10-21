#!/bin/bash

# BytePlus VMP 憑證設定腳本
# 用於設定和驗證 BytePlus VMP Prometheus 資料來源的認證憑證

set -e

# 顏色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 函數：顯示標題
show_title() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}  BytePlus VMP 憑證設定工具${NC}"
    echo -e "${BLUE}================================${NC}"
    echo
}

# 函數：檢查檔案是否存在
check_file() {
    if [ -f "$1" ]; then
        echo -e "${GREEN}✓${NC} $1 存在"
        return 0
    else
        echo -e "${RED}✗${NC} $1 不存在"
        return 1
    fi
}

# 函數：設定憑證
setup_credentials() {
    echo -e "${YELLOW}請輸入您的 BytePlus VMP 認證憑證：${NC}"
    echo
    
    # 讀取 Access Key
    read -p "Access Key (AK): " access_key
    if [ -z "$access_key" ]; then
        echo -e "${RED}錯誤：Access Key 不能為空${NC}"
        exit 1
    fi
    
    # 讀取 Secret Key
    read -s -p "Secret Key (SK): " secret_key
    echo
    if [ -z "$secret_key" ]; then
        echo -e "${RED}錯誤：Secret Key 不能為空${NC}"
        exit 1
    fi
    
    # 建立環境變數檔案
    cat > byteplus-credentials.env << EOF
# BytePlus VMP 認證憑證
# 設定時間: $(date)
BYTEPLUS_ACCESS_KEY=${access_key}
BYTEPLUS_SECRET_KEY=${secret_key}

# Slack Webhook URL (可選)
SLACK_WEBHOOK_URL=

# Server IP (可選，預設為 100.64.0.113)
SERVER_IP=100.64.0.113
EOF
    
    # 設定檔案權限
    chmod 600 byteplus-credentials.env
    
    echo -e "${GREEN}✓${NC} 憑證已儲存到 byteplus-credentials.env"
    echo -e "${GREEN}✓${NC} 檔案權限已設定為 600 (僅擁有者可讀寫)"
}

# 函數：驗證設定
verify_setup() {
    echo
    echo -e "${YELLOW}驗證設定...${NC}"
    
    # 檢查必要檔案
    check_file "byteplus-credentials.env" || return 1
    check_file "docker-compose.yml" || return 1
    check_file "grafana/provisioning/datasources/byteplus-vmp.yml" || return 1
    
    # 檢查環境變數檔案內容
    if grep -q "BYTEPLUS_ACCESS_KEY=" byteplus-credentials.env && \
       grep -q "BYTEPLUS_SECRET_KEY=" byteplus-credentials.env; then
        echo -e "${GREEN}✓${NC} 環境變數檔案包含必要的憑證"
    else
        echo -e "${RED}✗${NC} 環境變數檔案缺少必要的憑證"
        return 1
    fi
    
    # 檢查 Docker Compose 配置
    if grep -q "env_file:" docker-compose.yml && \
       grep -q "byteplus-credentials.env" docker-compose.yml; then
        echo -e "${GREEN}✓${NC} Docker Compose 已配置 env_file"
    else
        echo -e "${RED}✗${NC} Docker Compose 未配置 env_file"
        return 1
    fi
    
    return 0
}

# 函數：重啟服務
restart_services() {
    echo
    echo -e "${YELLOW}重啟 Grafana 服務以載入新憑證...${NC}"
    
    # 停止 Grafana 容器
    docker compose stop grafana
    
    # 啟動 Grafana 容器
    docker compose up -d grafana
    
    # 等待服務啟動
    echo "等待 Grafana 服務啟動..."
    sleep 10
    
    # 檢查容器狀態
    if docker ps | grep -q "kevin-telemetry-grafana"; then
        echo -e "${GREEN}✓${NC} Grafana 容器已成功啟動"
    else
        echo -e "${RED}✗${NC} Grafana 容器啟動失敗"
        return 1
    fi
}

# 函數：測試連線
test_connection() {
    echo
    echo -e "${YELLOW}測試 BytePlus VMP 連線...${NC}"
    
    # 檢查環境變數是否正確載入
    if docker exec kevin-telemetry-grafana env | grep -q "BYTEPLUS_ACCESS_KEY="; then
        echo -e "${GREEN}✓${NC} Access Key 環境變數已載入"
    else
        echo -e "${RED}✗${NC} Access Key 環境變數未載入"
        return 1
    fi
    
    if docker exec kevin-telemetry-grafana env | grep -q "BYTEPLUS_SECRET_KEY="; then
        echo -e "${GREEN}✓${NC} Secret Key 環境變數已載入"
    else
        echo -e "${RED}✗${NC} Secret Key 環境變數未載入"
        return 1
    fi
    
    echo
    echo -e "${GREEN}設定完成！${NC}"
    echo -e "${BLUE}請前往 Grafana (http://localhost:3000) 檢查 BP-VMP 資料來源狀態${NC}"
}

# 主程式
main() {
    show_title
    
    # 檢查是否已有憑證檔案
    if [ -f "byteplus-credentials.env" ]; then
        echo -e "${YELLOW}發現現有的憑證檔案，是否要重新設定？ (y/N)${NC}"
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            echo "使用現有憑證檔案..."
        else
            setup_credentials
        fi
    else
        setup_credentials
    fi
    
    # 驗證設定
    if verify_setup; then
        echo -e "${GREEN}✓${NC} 設定驗證通過"
    else
        echo -e "${RED}✗${NC} 設定驗證失敗"
        exit 1
    fi
    
    # 重啟服務
    restart_services
    
    # 測試連線
    test_connection
}

# 執行主程式
main "$@"
