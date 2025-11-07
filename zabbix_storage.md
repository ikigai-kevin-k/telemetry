# Zabbix 資料庫儲存資訊統整報告

## 一、資料庫儲存資訊

### 總儲存大小
- **總大小**: 2.54 GB (2,730,576,294 bytes)
- **位置**: Docker volume `telemetry_zabbix_db_data`
- **容器內路徑**: `/var/lib/mysql`
- **主機掛載點**: `/var/lib/docker/volumes/telemetry_zabbix_db_data/_data`
- **資料庫類型**: MySQL 8.0
- **資料庫名稱**: `zabbix`

### 資料統計
- **歷史記錄數**: 1,508,025 筆（過去約 7 天）
- **平均每小時記錄數**: 約 8,925 筆
- **資料時間跨度**: 約 7.04 天（168.96 小時）
- **最早資料**: 2025-10-31 06:46:24
- **最新資料**: 2025-11-07 07:43:53

### 主要資料表大小

| 表名 | 大小 (MB) | 說明 |
|------|-----------|------|
| `history` | 99.23 | 歷史資料（浮點數） |
| `history_uint` | 67.16 | 歷史資料（無符號整數） |
| `trends` | 18.55 | 趨勢資料（浮點數） |
| `trends_uint` | 13.47 | 趨勢資料（無符號整數） |
| `items` | 24.88 | 監控項目配置 |
| `triggers` | 4.56 | 觸發器配置 |
| `functions` | 3.39 | 函數配置 |
| `item_tag` | 3.03 | 項目標籤 |
| `item_preproc` | 3.03 | 項目預處理配置 |
| `valuemap_mapping` | 5.03 | 值映射 |

### 容器狀態
- **容器名稱**: `kevin-telemetry-zabbix-db`
- **資料庫版本**: MySQL 8.0
- **Volume 創建時間**: 2025-09-18T14:07:05+04:00
- **運行狀態**: ✅ 正常運行中

---

## 二、資料增長統計

### 2.1 過去 1 天資料增長分析

**分析時間範圍**: 2025-10-31 06:46:24 至 2025-11-07 07:43:53（約 7.04 天）

**統計結果**:
- **歷史記錄數**: 1,508,025 筆
- **時間跨度**: 168.96 小時（約 7.04 天）
- **平均每小時記錄數**: 8,925 筆
- **當前資料庫大小**: 2.54 GB

### 2.2 資料增長估算

基於過去約 7 天的資料增長率進行估算：

| 時間範圍 | 估算增長量 | 備註 |
|---------|-----------|------|
| **每小時** | 約 **15.41 MB** | 基於當前資料大小和時間跨度 |
| **每天（24小時）** | 約 **0.36 GB** | 約 369.84 MB |
| **每週（7天）** | 約 **2.52 GB** | 約 2,588.88 MB |
| **一個月（30天）** | 約 **10.84 GB** | 約 11,095.2 MB |

### 2.3 記錄數增長估算

| 時間範圍 | 估算記錄數 | 備註 |
|---------|-----------|------|
| **每小時** | 約 **8,925 筆** | 基於歷史資料統計 |
| **每天（24小時）** | 約 **214,200 筆** | 約 21.4 萬筆 |
| **每週（7天）** | 約 **1,499,400 筆** | 約 150 萬筆 |
| **一個月（30天）** | 約 **6,426,000 筆** | 約 642.6 萬筆 |

### 2.4 注意事項

⚠️ **重要提醒**:
- 以上估算基於過去約 7 天的資料增長率
- 實際增長量會受到以下因素影響：
  - 監控項目數量變化
  - 監控間隔設定
  - 資料保留策略
  - 系統負載變化
  - 新增或移除監控主機
- 建議定期監控實際增長量，並根據實際情況調整估算

---

## 三、資料保留設定

### 3.1 保留期限配置

根據 `zabbix/alert_thresholds.conf` 配置：

| 資料類型 | 保留期限 | 配置值 |
|---------|---------|--------|
| **History 資料** | 30 天 | `HISTORY_RETENTION_DAYS=30` |
| **Trends 資料** | 365 天（1年） | `TRENDS_RETENTION_DAYS=365` |
| **Events 資料** | 90 天 | `EVENTS_RETENTION_DAYS=90` |

### 3.2 資料保留說明

**History 資料**:
- 儲存所有監控項目的原始資料點
- 保留期限：**30 天**
- 超過 30 天的資料會被自動清理
- 主要儲存在 `history`, `history_uint`, `history_text`, `history_str`, `history_log` 等表

**Trends 資料**:
- 儲存監控項目的聚合資料（小時平均值、最小值、最大值）
- 保留期限：**365 天（1年）**
- 超過 1 年的資料會被自動清理
- 主要儲存在 `trends`, `trends_uint` 等表

**Events 資料**:
- 儲存觸發器事件、告警事件等
- 保留期限：**90 天**
- 超過 90 天的資料會被自動清理

### 3.3 自動清理機制

Zabbix 會自動執行資料清理任務：
- **清理頻率**: 根據 Zabbix Server 配置的清理間隔
- **清理方式**: 刪除超過保留期限的資料
- **清理範圍**: 僅清理歷史資料，不影響配置資料（hosts, items, triggers 等）

---

## 四、資料持久化配置

### 4.1 Docker Volume 配置

**Volume 資訊**:
- **Volume 名稱**: `telemetry_zabbix_db_data`
- **實際名稱**: `telemetry_zabbix_db_data`（Docker Compose 自動前綴）
- **驅動程式**: `local`
- **掛載點**: `/var/lib/docker/volumes/telemetry_zabbix_db_data/_data`
- **創建時間**: 2025-09-18T14:07:05+04:00

### 4.2 容器掛載配置

**掛載資訊**:
- **來源**: `/var/lib/docker/volumes/telemetry_zabbix_db_data/_data`
- **目標**: `/var/lib/mysql`
- **類型**: `volume`
- **唯讀**: `false`（可讀寫）

### 4.3 Docker Compose 配置

```yaml
services:
  zabbix-db:
    image: mysql:8.0
    container_name: kevin-telemetry-zabbix-db
    volumes:
      - zabbix_db_data:/var/lib/mysql
    environment:
      - MYSQL_DATABASE=zabbix
      - MYSQL_USER=zabbix
      - MYSQL_PASSWORD=zabbix_pwd
      - MYSQL_ROOT_PASSWORD=root_pwd

volumes:
  zabbix_db_data:
```

### 4.4 持久化驗證

✅ **持久化狀態**: **已正確配置**

**驗證項目**:
- ✅ Docker volume 已創建並掛載
- ✅ 容器重啟後資料會保留（volume 獨立於容器生命週期）
- ✅ 資料儲存在主機檔案系統中（`/var/lib/docker/volumes/`）
- ✅ MySQL 資料庫檔案完整儲存

### 4.5 持久化期限

- **持久化期限**: **永久**（只要 Docker volume 存在，資料會一直保留）
- **自動清理**: Zabbix 會根據保留設定自動清理超過期限的資料
- **注意**: 資料持久化期限與資料保留期限不同：
  - **持久化期限 (Persistence)**: 永久 - 只要 volume 存在，資料會持續儲存在磁碟上
  - **資料保留期限 (Retention)**: 
    - History: 30 天
    - Trends: 365 天
    - Events: 90 天
  - 超過保留期限的資料會被 Zabbix 自動清理，但配置資料（hosts, items, triggers 等）會永久保留

### 4.6 備份建議

**備份策略**:
1. **定期備份**: 使用 `backup_telemetry_data.sh` 腳本定期備份
2. **備份位置**: `/home/ella/kevin/telemetry/backups/`
3. **備份頻率**: 建議每日備份一次
4. **備份內容**: 
   - Docker volume 資料（完整 MySQL 資料庫）
   - Zabbix 配置檔案
   - 監控項目配置

**恢復程序**:
```bash
# 檢查容器狀態
./check_and_restore_containers.sh --check-only

# 從備份恢復
./check_and_restore_containers.sh --restore
```

### 4.7 持久化風險評估

**低風險項目** ✅:
- Volume 配置正確
- 資料儲存在持久化 volume 中
- 容器重啟不會影響資料
- 配置資料永久保留

**需要注意** ⚠️:
- Volume 刪除會導致資料遺失（需透過備份恢復）
- 主機磁碟空間不足可能影響寫入
- 建議定期監控磁碟使用率
- 歷史資料會根據保留期限自動清理

---

## 五、儲存容量規劃

### 5.1 當前儲存需求

**當前狀態**:
- **資料庫大小**: 2.54 GB
- **資料時間跨度**: 約 7 天
- **預期保留期限**: 
  - History: 30 天
  - Trends: 365 天

### 5.2 儲存容量估算

**基於當前增長率（約 0.36 GB/天）**:

| 保留期限 | 預期儲存需求 | 備註 |
|---------|------------|------|
| **History (30天)** | 約 **10.8 GB** | 30 天 × 0.36 GB/天 |
| **Trends (365天)** | 約 **131.4 GB** | 365 天 × 0.36 GB/天（但 trends 資料較小） |
| **總計（含配置）** | 約 **15-20 GB** | 包含配置資料和緩衝空間 |

**注意**: Trends 資料是聚合資料，實際大小會比 History 資料小很多，因此總儲存需求會低於上述估算。

### 5.3 容量規劃建議

1. **短期規劃（1個月）**:
   - 預留至少 **15-20 GB** 空間
   - 監控實際增長量

2. **中期規劃（3個月）**:
   - 預留至少 **30-40 GB** 空間
   - 考慮調整保留期限或實施資料壓縮

3. **長期規劃（1年）**:
   - 預留至少 **50-100 GB** 空間
   - 考慮實施資料歸檔策略
   - 定期清理舊資料

---

## 六、總結與建議

### 6.1 當前狀態總結

| 項目 | 狀態 | 備註 |
|-----|------|------|
| 資料庫大小 | 2.54 GB | 正常範圍 |
| 歷史記錄數 | 1,508,025 筆 | 約 7 天資料 |
| History 保留期限 | 30 天 | 正常 |
| Trends 保留期限 | 365 天 | 正常 |
| 持久化配置 | ✅ 已配置 | 正常 |
| 容器狀態 | ✅ 運行中 | 正常 |

### 6.2 建議事項

1. **監控磁碟空間**
   - 定期檢查 volume 大小
   - 確保有足夠空間容納 30 天的 History 資料（約 10-15 GB）
   - 監控 Trends 資料增長（365 天保留）

2. **定期備份**
   - 建議每日備份一次
   - 保留至少 2-4 週的備份
   - 驗證備份完整性

3. **資料清理**
   - 確認 Zabbix 自動清理機制正常運作
   - 定期檢查資料庫大小變化
   - 考慮手動清理舊資料（如需要）

4. **效能監控**
   - 監控資料庫查詢效能
   - 注意資料表大小變化
   - 定期檢查資料庫索引

5. **容量規劃**
   - 基於當前增長率（約 10.84 GB/月），規劃長期儲存需求
   - 考慮是否需要調整保留期限
   - 實施資料歸檔策略（如需要）

---

## 附錄：查詢指令參考

### 檢查資料庫大小
```bash
docker exec kevin-telemetry-zabbix-db du -sh /var/lib/mysql
```

### 查詢資料表大小
```bash
docker exec kevin-telemetry-zabbix-db mysql -uzabbix -pzabbix_pwd zabbix -e "SELECT table_name, ROUND(((data_length + index_length) / 1024 / 1024), 2) AS 'Size (MB)' FROM information_schema.TABLES WHERE table_schema = 'zabbix' ORDER BY (data_length + index_length) DESC LIMIT 10;"
```

### 查詢歷史資料統計
```bash
docker exec kevin-telemetry-zabbix-db mysql -uzabbix -pzabbix_pwd zabbix -e "SELECT MIN(clock) as oldest, MAX(clock) as newest, COUNT(*) as count FROM history WHERE itemid IN (SELECT itemid FROM items WHERE hostid IN (SELECT hostid FROM hosts WHERE host LIKE '%agent%'));"
```

### 檢查 Volume 資訊
```bash
docker volume inspect telemetry_zabbix_db_data
```

### 檢查容器掛載
```bash
docker inspect kevin-telemetry-zabbix-db --format '{{range .Mounts}}{{.Source}} -> {{.Destination}} ({{.Type}}){{"\n"}}{{end}}'
```

### 查詢資料保留設定
```bash
grep -E "RETENTION|retention" zabbix/alert_thresholds.conf
```

---

**文件生成時間**: 2025-11-07  
**最後更新**: 2025-11-07


