# Docker Volume 資訊統整文件

## 概述

本文檔記錄 Telemetry 系統中所有 Docker volumes 的詳細資訊，包括 Prometheus、Zabbix 資料庫以及其他服務的 volume 配置。

---

## 一、Prometheus 資料庫 Volume

### Volume 基本資訊

- **Volume 名稱**: `telemetry_prometheus_data`
- **主機掛載點（實際位置）**: `/var/lib/docker/volumes/telemetry_prometheus_data/_data`
- **容器內路徑**: `/prometheus`
- **容器名稱**: `kevin-telemetry-prometheus`
- **驅動程式**: `local`
- **創建時間**: 2025-09-19T08:00:29+04:00
- **唯讀**: `false`（可讀寫）

### 掛載配置

**Docker Compose 配置** (`docker-compose.yml`):
```yaml
services:
  prometheus:
    container_name: kevin-telemetry-prometheus
    volumes:
      - prometheus_data:/prometheus
    command:
      - '--storage.tsdb.path=/prometheus'

volumes:
  prometheus_data:  # 實際名稱會加上專案前綴: telemetry_prometheus_data
```

**實際掛載資訊**:
- **來源 (Source)**: `/var/lib/docker/volumes/telemetry_prometheus_data/_data`
- **目標 (Destination)**: `/prometheus`
- **類型 (Type)**: `volume`
- **唯讀 (RW)**: `true`（可讀寫）

### 儲存資訊

- **當前資料大小**: 約 74.5 MB
- **檔案系統**: `/dev/mapper/ubuntu--vg-ubuntu--lv`
- **總容量**: 97.9 GB
- **已使用**: 71.1 GB
- **可用空間**: 21.7 GB
- **使用率**: 77%

### 用途

- 儲存 Prometheus TSDB 資料
- 包含所有時間序列資料
- 保留時間：200 小時（約 8.3 天）

---

## 二、Zabbix 資料庫 Volume

### Volume 基本資訊

- **Volume 名稱**: `telemetry_zabbix_db_data`
- **主機掛載點（實際位置）**: `/var/lib/docker/volumes/telemetry_zabbix_db_data/_data`
- **容器內路徑**: `/var/lib/mysql`
- **容器名稱**: `kevin-telemetry-zabbix-db`
- **驅動程式**: `local`
- **創建時間**: 2025-09-18T14:07:05+04:00
- **唯讀**: `false`（可讀寫）

### 掛載配置

**Docker Compose 配置** (`docker-compose.yml`):
```yaml
services:
  zabbix-db:
    image: mysql:8.0
    container_name: kevin-telemetry-zabbix-db
    volumes:
      - zabbix_db_data:/var/lib/mysql
      - ./zabbix/mysql-init:/docker-entrypoint-initdb.d
    environment:
      - MYSQL_DATABASE=zabbix
      - MYSQL_USER=zabbix
      - MYSQL_PASSWORD=zabbix_pwd

volumes:
  zabbix_db_data:  # 實際名稱會加上專案前綴: telemetry_zabbix_db_data
```

**實際掛載資訊**:
- **來源 (Source)**: `/var/lib/docker/volumes/telemetry_zabbix_db_data/_data`
- **目標 (Destination)**: `/var/lib/mysql`
- **類型 (Type)**: `volume`
- **唯讀 (RW)**: `true`（可讀寫）

### 儲存資訊

- **當前資料大小**: 約 2.54 GB
- **檔案系統**: `/dev/mapper/ubuntu--vg-ubuntu--lv`
- **總容量**: 98 GB
- **已使用**: 72 GB
- **可用空間**: 22 GB
- **使用率**: 77%

### 用途

- 儲存 Zabbix MySQL 資料庫
- 包含所有監控資料、配置、歷史記錄
- History 保留：30 天
- Trends 保留：365 天

---

## 三、其他相關 Volumes

### 3.1 Grafana Volume

- **Volume 名稱**: `telemetry_grafana_data`
- **主機掛載點**: `/var/lib/docker/volumes/telemetry_grafana_data/_data`
- **容器內路徑**: `/var/lib/grafana`
- **容器名稱**: `kevin-telemetry-grafana`
- **用途**: 儲存 Grafana 儀表板、配置、使用者資料

### 3.2 Loki Volume

- **Volume 名稱**: `telemetry_loki_data`
- **主機掛載點**: `/var/lib/docker/volumes/telemetry_loki_data/_data`
- **容器內路徑**: `/loki`
- **容器名稱**: `kevin-telemetry-loki-server`
- **用途**: 儲存 Loki 日誌資料

### 3.3 Zabbix Server Volume

- **Volume 名稱**: `telemetry_zabbix_server_data`
- **主機掛載點**: `/var/lib/docker/volumes/telemetry_zabbix_server_data/_data`
- **容器內路徑**: `/var/lib/zabbix`
- **容器名稱**: `kevin-telemetry-zabbix-server`
- **用途**: 儲存 Zabbix Server 配置和緩存

### 3.4 Alertmanager Volume

- **Volume 名稱**: `telemetry_alertmanager_data`
- **主機掛載點**: `/var/lib/docker/volumes/telemetry_alertmanager_data/_data`
- **容器內路徑**: `/alertmanager`
- **容器名稱**: `kevin-telemetry-alertmanager`
- **用途**: 儲存 Alertmanager 配置和狀態

---

## 四、Volume 命名規則

### Docker Compose 命名規則

Docker Compose 會自動為 volume 名稱加上專案前綴。專案名稱通常是：
- 目錄名稱（如 `telemetry`）
- 或透過 `COMPOSE_PROJECT_NAME` 環境變數設定

**命名格式**:
```
<專案名稱>_<volume名稱>
```

**範例**:
- `prometheus_data` → `telemetry_prometheus_data`
- `zabbix_db_data` → `telemetry_zabbix_db_data`
- `grafana_data` → `telemetry_grafana_data`

---

## 五、查詢指令參考

### 列出所有相關 Volumes

```bash
docker volume ls | grep -E "prometheus|zabbix|grafana|loki|alertmanager"
```

### 查看 Volume 詳細資訊

```bash
# Prometheus
docker volume inspect telemetry_prometheus_data

# Zabbix DB
docker volume inspect telemetry_zabbix_db_data

# Grafana
docker volume inspect telemetry_grafana_data

# Loki
docker volume inspect telemetry_loki_data

# Zabbix Server
docker volume inspect telemetry_zabbix_server_data
```

### 查看容器掛載資訊

```bash
# Prometheus
docker inspect kevin-telemetry-prometheus --format '{{range .Mounts}}{{if eq .Destination "/prometheus"}}Volume 名稱: {{.Name}}
來源: {{.Source}}
目標: {{.Destination}}
類型: {{.Type}}
唯讀: {{.RW}}
{{end}}{{end}}'

# Zabbix DB
docker inspect kevin-telemetry-zabbix-db --format '{{range .Mounts}}{{if eq .Destination "/var/lib/mysql"}}Volume 名稱: {{.Name}}
來源: {{.Source}}
目標: {{.Destination}}
類型: {{.Type}}
唯讀: {{.RW}}
{{end}}{{end}}'
```

### 查看 Volume 掛載點

```bash
docker volume inspect telemetry_prometheus_data telemetry_zabbix_db_data --format '{{.Name}}: {{.Mountpoint}}'
```

### 查看容器內資料大小

```bash
# Prometheus
docker exec kevin-telemetry-prometheus du -sh /prometheus

# Zabbix DB
docker exec kevin-telemetry-zabbix-db du -sh /var/lib/mysql
```

### 查看檔案系統使用情況

```bash
# Prometheus
docker exec kevin-telemetry-prometheus df -h /prometheus

# Zabbix DB
docker exec kevin-telemetry-zabbix-db df -h /var/lib/mysql
```

---

## 六、Volume 管理

### 6.1 備份 Volume

**備份 Prometheus Volume**:
```bash
docker run --rm \
  -v telemetry_prometheus_data:/data \
  -v $(pwd)/backups:/backup \
  alpine tar czf /backup/prometheus_backup_$(date +%Y%m%d_%H%M%S).tar.gz -C /data .
```

**備份 Zabbix DB Volume**:
```bash
docker run --rm \
  -v telemetry_zabbix_db_data:/data \
  -v $(pwd)/backups:/backup \
  alpine tar czf /backup/zabbix_db_backup_$(date +%Y%m%d_%H%M%S).tar.gz -C /data .
```

**使用專用備份腳本**:
```bash
./backup_telemetry_data.sh
```

### 6.2 恢復 Volume

**從備份恢復**:
```bash
# 停止相關容器
docker stop kevin-telemetry-prometheus

# 恢復資料
docker run --rm \
  -v telemetry_prometheus_data:/data \
  -v $(pwd)/backups:/backup \
  alpine tar xzf /backup/prometheus_backup_YYYYMMDD_HHMMSS.tar.gz -C /data

# 啟動容器
docker start kevin-telemetry-prometheus
```

**使用專用恢復腳本**:
```bash
./check_and_restore_containers.sh --restore
```

### 6.3 刪除 Volume

⚠️ **警告**: 刪除 volume 會永久刪除所有資料！

```bash
# 停止並刪除容器
docker stop kevin-telemetry-prometheus
docker rm kevin-telemetry-prometheus

# 刪除 volume
docker volume rm telemetry_prometheus_data
```

### 6.4 清理未使用的 Volumes

```bash
# 查看未使用的 volumes
docker volume ls -f dangling=true

# 清理未使用的 volumes
docker volume prune
```

---

## 七、重要提醒

### 7.1 資料持久化

✅ **資料持久化狀態**: **已正確配置**

- 所有重要資料都儲存在 Docker volumes 中
- Volume 獨立於容器生命週期
- 容器刪除不會影響 volume 資料
- 容器重啟後資料會保留

### 7.2 存取權限

⚠️ **重要提醒**:
- 主機掛載點位於 `/var/lib/docker/volumes/` 目錄
- 直接存取需要 **root 權限**
- 建議透過 Docker 命令或容器內存取資料

### 7.3 備份建議

1. **定期備份**: 建議每日或每週備份一次
2. **備份位置**: `/home/ella/kevin/telemetry/backups/`
3. **備份內容**: 所有 Docker volumes
4. **保留期限**: 建議保留至少 2-4 週的備份

### 7.4 磁碟空間監控

- 當前檔案系統使用率：**77%**
- 可用空間：約 **21-22 GB**
- 建議定期監控磁碟使用率
- 當使用率超過 80% 時應考慮清理或擴充

### 7.5 資料保留期限

**Prometheus**:
- 保留時間：200 小時（約 8.3 天）
- 超過保留時間的資料會被自動清理

**Zabbix**:
- History 資料：30 天
- Trends 資料：365 天
- Events 資料：90 天
- 超過保留期限的資料會被自動清理

---

## 八、Volume 位置總結

| 服務 | Volume 名稱 | 主機掛載點 | 容器內路徑 | 資料大小 |
|------|-----------|-----------|-----------|---------|
| **Prometheus** | `telemetry_prometheus_data` | `/var/lib/docker/volumes/telemetry_prometheus_data/_data` | `/prometheus` | ~74.5 MB |
| **Zabbix DB** | `telemetry_zabbix_db_data` | `/var/lib/docker/volumes/telemetry_zabbix_db_data/_data` | `/var/lib/mysql` | ~2.54 GB |
| **Grafana** | `telemetry_grafana_data` | `/var/lib/docker/volumes/telemetry_grafana_data/_data` | `/var/lib/grafana` | - |
| **Loki** | `telemetry_loki_data` | `/var/lib/docker/volumes/telemetry_loki_data/_data` | `/loki` | - |
| **Zabbix Server** | `telemetry_zabbix_server_data` | `/var/lib/docker/volumes/telemetry_zabbix_server_data/_data` | `/var/lib/zabbix` | - |
| **Alertmanager** | `telemetry_alertmanager_data` | `/var/lib/docker/volumes/telemetry_alertmanager_data/_data` | `/alertmanager` | - |

---

## 九、故障排查

### 9.1 Volume 不存在

**問題**: 容器啟動時找不到 volume

**解決方案**:
```bash
# 檢查 volume 是否存在
docker volume ls | grep telemetry_prometheus_data

# 如果不存在，重新創建（會自動創建）
docker-compose up -d prometheus
```

### 9.2 資料遺失

**問題**: 容器重啟後資料消失

**可能原因**:
- Volume 未正確掛載
- Volume 被刪除
- 資料被清理（超過保留期限）

**解決方案**:
1. 檢查 volume 掛載狀態
2. 確認 volume 是否存在
3. 從備份恢復資料

### 9.3 磁碟空間不足

**問題**: 無法寫入資料

**解決方案**:
1. 清理舊資料
2. 擴充磁碟空間
3. 調整資料保留期限
4. 刪除不需要的 volumes

---

**文件生成時間**: 2025-11-07  
**最後更新**: 2025-11-07












