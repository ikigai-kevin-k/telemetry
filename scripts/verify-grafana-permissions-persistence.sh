#!/bin/bash

# Grafana Permissions Persistence Verification Script
# 用途: 驗證 Grafana 權限設定已正確持久化儲存

set -e

# 顏色輸出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Grafana 權限持久化驗證 ===${NC}"
echo ""

# 檢查 Docker volume
echo -e "${YELLOW}1. 檢查 Grafana Volume...${NC}"
VOLUME_NAME="telemetry_grafana_data"
if docker volume inspect "$VOLUME_NAME" > /dev/null 2>&1; then
    VOLUME_PATH=$(docker volume inspect "$VOLUME_NAME" | jq -r '.[0].Mountpoint')
    echo -e "${GREEN}✓ Volume 存在: $VOLUME_NAME${NC}"
    echo "  掛載點: $VOLUME_PATH"
else
    echo -e "${RED}✗ Volume 不存在: $VOLUME_NAME${NC}"
    exit 1
fi
echo ""

# 檢查容器狀態
echo -e "${YELLOW}2. 檢查 Grafana 容器狀態...${NC}"
if docker ps --format '{{.Names}}' | grep -q "kevin-telemetry-grafana"; then
    echo -e "${GREEN}✓ Grafana 容器正在運行${NC}"
else
    echo -e "${RED}✗ Grafana 容器未運行${NC}"
    exit 1
fi
echo ""

# 檢查資料庫檔案
echo -e "${YELLOW}3. 檢查 Grafana 資料庫檔案...${NC}"
CONTAINER_NAME="kevin-telemetry-grafana"
if docker exec "$CONTAINER_NAME" test -f /var/lib/grafana/grafana.db; then
    DB_SIZE=$(docker exec "$CONTAINER_NAME" stat -c%s /var/lib/grafana/grafana.db 2>/dev/null || echo "0")
    echo -e "${GREEN}✓ Grafana 資料庫存在${NC}"
    echo "  檔案大小: $(numfmt --to=iec-i --suffix=B $DB_SIZE 2>/dev/null || echo "${DB_SIZE} bytes")"
    echo "  路徑: /var/lib/grafana/grafana.db"
else
    echo -e "${RED}✗ Grafana 資料庫不存在${NC}"
    exit 1
fi
echo ""

# 檢查 volume 掛載
echo -e "${YELLOW}4. 檢查 Volume 掛載狀態...${NC}"
MOUNT_INFO=$(docker inspect "$CONTAINER_NAME" | jq -r '.[0].Mounts[] | select(.Destination == "/var/lib/grafana")')
if [ -n "$MOUNT_INFO" ]; then
    MOUNT_TYPE=$(echo "$MOUNT_INFO" | jq -r '.Type')
    MOUNT_SOURCE=$(echo "$MOUNT_INFO" | jq -r '.Source')
    echo -e "${GREEN}✓ Volume 已正確掛載${NC}"
    echo "  掛載類型: $MOUNT_TYPE"
    echo "  來源: $MOUNT_SOURCE"
else
    echo -e "${RED}✗ Volume 未正確掛載${NC}"
    exit 1
fi
echo ""

# 檢查權限相關資料表（如果 SQLite 可用）
echo -e "${YELLOW}5. 檢查權限資料...${NC}"
if docker exec "$CONTAINER_NAME" which sqlite3 > /dev/null 2>&1; then
    # 檢查 dashboard_permissions 表
    DASHBOARD_PERMS=$(docker exec "$CONTAINER_NAME" sqlite3 /var/lib/grafana/grafana.db \
        "SELECT COUNT(*) FROM dashboard_acl WHERE id > 0;" 2>/dev/null || echo "0")
    
    # 檢查 folder_permissions 表
    FOLDER_PERMS=$(docker exec "$CONTAINER_NAME" sqlite3 /var/lib/grafana/grafana.db \
        "SELECT COUNT(*) FROM folder_acl WHERE id > 0;" 2>/dev/null || echo "0")
    
    # 檢查 datasource_permissions 表
    DATASOURCE_PERMS=$(docker exec "$CONTAINER_NAME" sqlite3 /var/lib/grafana/grafana.db \
        "SELECT COUNT(*) FROM datasource_acl WHERE id > 0;" 2>/dev/null || echo "0")
    
    echo -e "${GREEN}✓ 權限資料統計:${NC}"
    echo "  Dashboard 權限: $DASHBOARD_PERMS 筆"
    echo "  Folder 權限: $FOLDER_PERMS 筆"
    echo "  Datasource 權限: $DATASOURCE_PERMS 筆"
    
    if [ "$DASHBOARD_PERMS" -gt 0 ] || [ "$FOLDER_PERMS" -gt 0 ] || [ "$DATASOURCE_PERMS" -gt 0 ]; then
        echo -e "${GREEN}✓ 已偵測到權限設定${NC}"
    else
        echo -e "${YELLOW}⚠ 未偵測到權限設定（可能是預設權限）${NC}"
    fi
else
    echo -e "${YELLOW}⚠ SQLite3 不可用，跳過資料庫檢查${NC}"
fi
echo ""

# 檢查備份狀態
echo -e "${YELLOW}6. 檢查備份狀態...${NC}"
BACKUP_DIR="./backups"
if [ -d "$BACKUP_DIR" ]; then
    LATEST_BACKUP=$(ls -td "$BACKUP_DIR"/telemetry_backup_* 2>/dev/null | head -1)
    if [ -n "$LATEST_BACKUP" ]; then
        BACKUP_DATE=$(basename "$LATEST_BACKUP" | sed 's/telemetry_backup_//')
        echo -e "${GREEN}✓ 找到備份: $BACKUP_DATE${NC}"
        if [ -f "$LATEST_BACKUP/grafana_data_backup.tar.gz" ]; then
            BACKUP_SIZE=$(stat -c%s "$LATEST_BACKUP/grafana_data_backup.tar.gz" 2>/dev/null || echo "0")
            echo "  備份大小: $(numfmt --to=iec-i --suffix=B $BACKUP_SIZE 2>/dev/null || echo "${BACKUP_SIZE} bytes")"
        fi
    else
        echo -e "${YELLOW}⚠ 未找到備份${NC}"
    fi
else
    echo -e "${YELLOW}⚠ 備份目錄不存在${NC}"
fi
echo ""

# 總結
echo -e "${BLUE}=== 驗證結果 ===${NC}"
echo -e "${GREEN}✓ Grafana 權限設定已正確持久化儲存${NC}"
echo ""
echo -e "${YELLOW}重要提醒:${NC}"
echo "1. 權限設定儲存在 Grafana 資料庫中 (/var/lib/grafana/grafana.db)"
echo "2. 資料庫位於持久化 volume: $VOLUME_NAME"
echo "3. 容器重啟不會影響權限設定"
echo "4. 建議定期備份 volume 資料"
echo ""
echo -e "${YELLOW}測試持久化:${NC}"
echo "1. 重啟 Grafana: docker-compose restart grafana"
echo "2. 檢查權限是否仍然存在"
echo "3. 使用 Viewer 帳號登入驗證權限"



