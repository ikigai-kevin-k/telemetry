# Prometheus 資料庫儲存資訊統整報告

## 一、資料庫儲存資訊

### 總儲存大小
- **總大小**: 74.5 MB (78,519,513 bytes)
- **位置**: Docker volume `telemetry_prometheus_data`
- **容器內路徑**: `/prometheus`
- **主機掛載點**: `/var/lib/docker/volumes/telemetry_prometheus_data/_data`

### 資料統計
- **時間序列數**: 1,389 個
- **標籤對數**: 663 個
- **Chunks 數**: 3,911 個
- **時間序列 Block 數**: 16 個
- **總檔案數**: 72 個

### 時間範圍
- **最早資料**: 2025-10-30 05:00
- **最新資料**: 2025-11-07 03:00
- **資料跨度**: 約 8 天

### 保留設定
- **保留時間**: 200 小時（約 8.3 天）
- **配置來源**: `docker-compose.yml` 中的 `--storage.tsdb.retention.time=200h`
- **持久化期限**: **永久**（只要 Docker volume 存在，資料會一直保留）
- **自動清理**: Prometheus 會自動刪除超過 200 小時的資料
- **注意**: 資料保留時間與持久化期限不同：
  - **保留時間 (Retention Time)**: 200 小時 - Prometheus 會自動清理超過此時間的資料
  - **持久化期限 (Persistence)**: 永久 - 只要 volume 存在，資料會持續儲存在磁碟上，直到超過保留時間被自動清理

### 儲存結構
- **chunks_head**: 884 KB（記憶體中的最新資料）
- **時間序列 blocks**: 每個約 5-6 MB（歷史資料）
- **最新 blocks**: 約 800 KB - 2.1 MB

### 容器狀態
- **容器名稱**: `kevin-telemetry-prometheus`
- **運行狀態**: 已運行 2 週
- **API 端點**: `http://localhost:9090`
- **Volume 創建時間**: 2025-09-19T08:00:29+04:00

### 主要指標來源
根據統計，主要資料來源包括：
- **Prometheus 自身指標**: 1,044 個時間序列
- **Telegraf ZCAM 指標**: 105 個時間序列（配置存在，但目前無活躍資料）
- **ZCAM Values Exporter**: 95 個時間序列
- **Pushgateway 指標**: 75 個時間序列

---

## 二、指標列表

### 2.1 ZCAM Values Exporter 指標

**Job 名稱**: `zcam-values`  
**目標**: `kevin-telemetry-zcam-values-exporter:9274`  
**抓取間隔**: 30 秒

**指標列表**（共 6 個唯一指標名稱）:
1. `zcam_api_requests_created` - ZCAM API 請求創建時間戳
2. `zcam_api_requests_total` - ZCAM API 請求總數
3. `zcam_battery_level` - ZCAM 電池電量
4. `zcam_bitrate` - ZCAM 位元率
5. `zcam_camera_mode` - ZCAM 相機模式
6. `zcam_temperature` - ZCAM 溫度

### 2.2 Pushgateway 指標

**Job 名稱**: `pushgateway`  
**目標**: `pushgateway:9091`  
**抓取間隔**: 15 秒

**Pushgateway 自身指標**（共 8 個唯一指標名稱）:
1. `pushgateway_build_info` - Pushgateway 建置資訊
2. `pushgateway_http_push_duration_seconds` - HTTP Push 請求持續時間（直方圖）
3. `pushgateway_http_push_duration_seconds_count` - HTTP Push 請求持續時間計數
4. `pushgateway_http_push_duration_seconds_sum` - HTTP Push 請求持續時間總和
5. `pushgateway_http_push_size_bytes` - HTTP Push 請求大小（直方圖）
6. `pushgateway_http_push_size_bytes_count` - HTTP Push 請求大小計數
7. `pushgateway_http_push_size_bytes_sum` - HTTP Push 請求大小總和
8. `pushgateway_http_requests_total` - HTTP 請求總數

**透過 Pushgateway 傳送的業務指標**:

#### AIPC Temperature Metrics (job: agent_temperature)

**指標名稱**: `system_temperature_celsius`  
**資料來源**: Zabbix Agents → Server-side Script → Pushgateway → Prometheus  
**收集腳本**: `scripts/push_agent_temperature_to_pushgateway.sh`  
**執行頻率**: 每分鐘（Cron: `*/1 * * * *`）

**監控的 Agent 實例**:
1. `GC-ARO-001-1-agent` (ARO11)
2. `GC-ARO-001-2-agent` (ARO12)
3. `GC-ARO-002-1-agent` (ARO21)
4. `GC-ARO-002-2-agent` (ARO22)
5. `GC-aro12-agent` (ARO12)

**資料流程**:
```
Zabbix Agent (system.temperature) 
  → Zabbix Server (zabbix_get)
  → Server Script (push_agent_temperature_to_pushgateway.sh)
  → Pushgateway (job=agent_temperature, instance=<hostname>)
  → Prometheus (抓取間隔: 15秒)
  → Grafana Dashboard (AIPC - Temperature panel)
```

**Prometheus 查詢範例**:
```promql
system_temperature_celsius{instance="GC-ARO-001-1-agent"}
system_temperature_celsius{job="agent_temperature"}
```

**狀態**: ✅ **正常運作中**
- 所有 5 個 Agent 的溫度資料都正常推送到 Pushgateway
- Prometheus 成功抓取並儲存到 TSDB
- Grafana Dashboard 可正常顯示溫度趨勢圖

### 2.3 Telegraf ZCAM 指標

**Job 名稱**: `telegraf-zcam`  
**目標**: `kevin-telemetry-telegraf-zcam:9273`  
**抓取間隔**: 30 秒  
**抓取超時**: 10 秒

**狀態**: ⚠️ **目前無活躍資料**

**說明**: 
- 配置已存在於 `prometheus.yml` 中
- 目標端點可能未運行或無法連接
- 建議檢查 `kevin-telemetry-telegraf-zcam` 容器狀態

---

## 三、資料增長統計

### 3.1 當前資料狀態
- **當前資料大小**: 74.88 MB
- **資料時間跨度**: 約 1.46 小時（基於 headStats 的時間範圍）

### 3.2 資料增長估算

基於當前資料大小和時間跨度進行估算：

| 時間範圍 | 估算增長量 |
|---------|-----------|
| **半小時** | 約 **25.71 MB** |
| **每小時** | 約 **51.42 MB** |
| **一天（24小時）** | 約 **1.23 GB** |
| **一個月（30天）** | 約 **36.16 GB** |

### 3.3 注意事項

⚠️ **重要提醒**:
- 以上估算基於當前短時間內的資料增長率
- 實際增長量會受到以下因素影響：
  - 指標數量變化
  - 抓取間隔設定
  - 資料保留策略
  - 系統負載變化
- 建議定期監控實際增長量，並根據實際情況調整估算

### 3.4 儲存容量規劃建議

基於當前配置（200 小時保留時間）：
- **預期儲存需求**: 約 10-12 GB（200 小時 × 51.42 MB/小時）
- **建議預留空間**: 至少 15-20 GB（包含安全邊際）

---

## 四、資料持久化配置

### 4.1 Docker Volume 配置

**Volume 資訊**:
- **Volume 名稱**: `telemetry_prometheus_data`
- **實際名稱**: `telemetry_prometheus_data`（Docker Compose 自動前綴）
- **驅動程式**: `local`
- **掛載點**: `/var/lib/docker/volumes/telemetry_prometheus_data/_data`
- **創建時間**: 2025-09-19T08:00:29+04:00

### 4.2 容器掛載配置

**掛載資訊**:
- **來源**: `/var/lib/docker/volumes/telemetry_prometheus_data/_data`
- **目標**: `/prometheus`
- **類型**: `volume`
- **唯讀**: `false`（可讀寫）

### 4.3 Docker Compose 配置

```yaml
services:
  prometheus:
    image: prom/prometheus:latest
    container_name: kevin-telemetry-prometheus
    volumes:
      - prometheus_data:/prometheus
    command:
      - '--storage.tsdb.path=/prometheus'
      - '--storage.tsdb.retention.time=200h'

volumes:
  prometheus_data:
```

### 4.4 持久化驗證

✅ **持久化狀態**: **已正確配置**

**驗證項目**:
- ✅ Docker volume 已創建並掛載
- ✅ 容器重啟後資料會保留（volume 獨立於容器生命週期）
- ✅ 資料儲存在主機檔案系統中（`/var/lib/docker/volumes/`）
- ✅ 配置檔案已持久化掛載（`prometheus.yml`）

### 4.5 備份建議

**備份策略**:
1. **定期備份**: 使用 `backup_telemetry_data.sh` 腳本定期備份
2. **備份位置**: `/home/ella/kevin/telemetry/backups/`
3. **備份頻率**: 建議每日或每週備份一次
4. **備份內容**: 
   - Docker volume 資料
   - Prometheus 配置檔案
   - Alert 規則檔案

**恢復程序**:
```bash
# 檢查容器狀態
./check_and_restore_containers.sh --check-only

# 從備份恢復
./check_and_restore_containers.sh --restore
```

### 4.6 持久化風險評估

**低風險項目** ✅:
- Volume 配置正確
- 資料儲存在持久化 volume 中
- 容器重啟不會影響資料

**需要注意** ⚠️:
- Volume 刪除會導致資料遺失（需透過備份恢復）
- 主機磁碟空間不足可能影響寫入
- 建議定期監控磁碟使用率

---

## 五、總結與建議

### 5.1 當前狀態總結

| 項目 | 狀態 | 備註 |
|-----|------|------|
| 資料庫大小 | 74.5 MB | 正常範圍 |
| 時間序列數 | 1,389 個 | 正常 |
| 資料保留時間 | 200 小時 | 約 8.3 天 |
| 持久化配置 | ✅ 已配置 | 正常 |
| 容器狀態 | ✅ 運行中 | 已運行 2 週 |

### 5.2 建議事項

1. **監控磁碟空間**
   - 定期檢查 volume 大小
   - 確保有足夠空間容納 200 小時的資料（約 10-15 GB）

2. **定期備份**
   - 建議每日或每週備份一次
   - 保留至少 2-4 週的備份

3. **Telegraf ZCAM 狀態**
   - 檢查 `kevin-telemetry-telegraf-zcam` 容器是否正常運行
   - 確認端點 `kevin-telemetry-telegraf-zcam:9273` 可訪問

4. **效能監控**
   - 監控 Prometheus 查詢效能
   - 注意 chunks_head 大小變化
   - 定期檢查 TSDB 統計資訊

5. **容量規劃**
   - 基於當前增長率（約 36 GB/月），規劃長期儲存需求
   - 考慮是否需要調整保留時間或實施資料壓縮策略

---

## 附錄：查詢指令參考

### 檢查資料庫大小
```bash
docker exec kevin-telemetry-prometheus du -sh /prometheus
```

### 查詢 TSDB 統計
```bash
curl -s http://localhost:9090/api/v1/status/tsdb | python3 -m json.tool
```

### 列出所有指標
```bash
curl -s 'http://localhost:9090/api/v1/label/__name__/values' | python3 -m json.tool
```

### 查詢特定 job 的指標
```bash
# ZCAM Values Exporter
curl -s 'http://localhost:9090/api/v1/query?query={job="zcam-values"}'

# Pushgateway
curl -s 'http://localhost:9090/api/v1/query?query={job="pushgateway"}'

# Telegraf ZCAM
curl -s 'http://localhost:9090/api/v1/query?query={job="telegraf-zcam"}'
```

### 檢查 Volume 資訊
```bash
docker volume inspect telemetry_prometheus_data
```

### 檢查容器掛載
```bash
docker inspect kevin-telemetry-prometheus --format '{{range .Mounts}}{{.Source}} -> {{.Destination}} ({{.Type}}){{"\n"}}{{end}}'
```

---

**文件生成時間**: 2025-11-07  
**最後更新**: 2025-11-07

