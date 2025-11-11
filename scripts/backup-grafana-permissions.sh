#!/bin/bash

# Grafana Permissions Backup Script
# 用途: 備份 Grafana 權限設定和資料庫

set -e

# 顏色輸出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 設定
BACKUP_DIR="./backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="grafana_permissions_${TIMESTAMP}"
CONTAINER_NAME="kevin-telemetry-grafana"
VOLUME_NAME="telemetry_grafana_data"

echo -e "${BLUE}=== Grafana 權限備份工具 ===${NC}"
echo ""

# 建立備份目錄
mkdir -p "$BACKUP_DIR/$BACKUP_NAME"
echo -e "${YELLOW}建立備份目錄: $BACKUP_DIR/$BACKUP_NAME${NC}"
echo ""

# 檢查容器狀態
if ! docker ps --format '{{.Names}}' | grep -q "$CONTAINER_NAME"; then
    echo -e "${RED}錯誤: Grafana 容器未運行${NC}"
    exit 1
fi

# 備份 Grafana 資料庫
echo -e "${YELLOW}1. 備份 Grafana 資料庫...${NC}"
if docker exec "$CONTAINER_NAME" test -f /var/lib/grafana/grafana.db; then
    docker cp "$CONTAINER_NAME:/var/lib/grafana/grafana.db" "$BACKUP_DIR/$BACKUP_NAME/grafana.db"
    echo -e "${GREEN}✓ 資料庫已備份${NC}"
else
    echo -e "${RED}✗ 找不到 Grafana 資料庫${NC}"
    exit 1
fi
echo ""

# 備份權限相關資料（使用 SQLite 匯出）
echo -e "${YELLOW}2. 匯出權限資料...${NC}"
if docker exec "$CONTAINER_NAME" which sqlite3 > /dev/null 2>&1; then
    # 匯出 dashboard 權限
    docker exec "$CONTAINER_NAME" sqlite3 /var/lib/grafana/grafana.db \
        ".mode csv" \
        ".headers on" \
        ".output /tmp/dashboard_acl.csv" \
        "SELECT * FROM dashboard_acl;" 2>/dev/null || true
    
    docker cp "$CONTAINER_NAME:/tmp/dashboard_acl.csv" "$BACKUP_DIR/$BACKUP_NAME/dashboard_acl.csv" 2>/dev/null || true
    
    # 匯出 folder 權限
    docker exec "$CONTAINER_NAME" sqlite3 /var/lib/grafana/grafana.db \
        ".mode csv" \
        ".headers on" \
        ".output /tmp/folder_acl.csv" \
        "SELECT * FROM folder_acl;" 2>/dev/null || true
    
    docker cp "$CONTAINER_NAME:/tmp/folder_acl.csv" "$BACKUP_DIR/$BACKUP_NAME/folder_acl.csv" 2>/dev/null || true
    
    # 匯出 datasource 權限
    docker exec "$CONTAINER_NAME" sqlite3 /var/lib/grafana/grafana.db \
        ".mode csv" \
        ".headers on" \
        ".output /tmp/datasource_acl.csv" \
        "SELECT * FROM datasource_acl;" 2>/dev/null || true
    
    docker cp "$CONTAINER_NAME:/tmp/datasource_acl.csv" "$BACKUP_DIR/$BACKUP_NAME/datasource_acl.csv" 2>/dev/null || true
    
    echo -e "${GREEN}✓ 權限資料已匯出${NC}"
else
    echo -e "${YELLOW}⚠ SQLite3 不可用，跳過權限資料匯出${NC}"
fi
echo ""

# 備份完整 volume（可選，較大）
echo -e "${YELLOW}3. 備份完整 Grafana Volume...${NC}"
read -p "是否備份完整 volume？（會產生較大的備份檔案）[y/N]: " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    docker run --rm \
        -v "$VOLUME_NAME:/data:ro" \
        -v "$(pwd)/$BACKUP_DIR/$BACKUP_NAME:/backup" \
        alpine tar czf /backup/grafana_volume_backup.tar.gz -C /data . 2>/dev/null || {
        echo -e "${YELLOW}⚠ 完整 volume 備份失敗，但資料庫備份已成功${NC}"
    }
    echo -e "${GREEN}✓ 完整 volume 已備份${NC}"
else
    echo -e "${YELLOW}跳過完整 volume 備份${NC}"
fi
echo ""

# 建立備份資訊檔案
echo -e "${YELLOW}4. 建立備份資訊...${NC}"
cat > "$BACKUP_DIR/$BACKUP_NAME/backup_info.txt" << EOF
Grafana 權限備份資訊
====================
備份時間: $(date)
備份名稱: $BACKUP_NAME
容器名稱: $CONTAINER_NAME
Volume 名稱: $VOLUME_NAME

備份內容:
- grafana.db: Grafana 完整資料庫（包含所有權限設定）
- dashboard_acl.csv: Dashboard 權限資料
- folder_acl.csv: Folder 權限資料
- datasource_acl.csv: Datasource 權限資料

恢復方法:
1. 停止 Grafana: docker-compose stop grafana
2. 恢復資料庫: docker cp grafana.db kevin-telemetry-grafana:/var/lib/grafana/grafana.db
3. 設定正確權限: docker exec kevin-telemetry-grafana chown grafana:grafana /var/lib/grafana/grafana.db
4. 啟動 Grafana: docker-compose start grafana
EOF

echo -e "${GREEN}✓ 備份資訊已建立${NC}"
echo ""

# 計算備份大小
BACKUP_SIZE=$(du -sh "$BACKUP_DIR/$BACKUP_NAME" 2>/dev/null | cut -f1 || echo "未知")
echo -e "${BLUE}=== 備份完成 ===${NC}"
echo -e "${GREEN}備份位置: $BACKUP_DIR/$BACKUP_NAME${NC}"
echo -e "${GREEN}備份大小: $BACKUP_SIZE${NC}"
echo ""
echo -e "${YELLOW}備份內容:${NC}"
ls -lh "$BACKUP_DIR/$BACKUP_NAME" | tail -n +2
echo ""
echo -e "${YELLOW}重要提醒:${NC}"
echo "1. 備份檔案包含所有權限設定"
echo "2. 建議定期備份（建議在設定權限後立即備份）"
echo "3. 備份檔案應妥善保管，避免遺失"

