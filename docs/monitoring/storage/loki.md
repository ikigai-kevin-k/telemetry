# Loki Server Docker Service 設定文件

## 概述

Loki Server 是集中式日誌聚合服務，接收來自遠端 Promtail Agent 的日誌資料。本文件說明 Loki Server 的 Docker Service 設定與配置。

## Docker Compose 設定

### Service 定義

```yaml
# Loki Server - Accepts logs from remote Promtail agents
loki:
  image: grafana/loki:latest
  container_name: kevin-telemetry-loki-server
  ports:
    - "3100:3100"
  volumes:
    - loki_data:/loki
    - ./loki-config.yml:/etc/loki/local-config.yaml
  command: -config.file=/etc/loki/local-config.yaml
  restart: unless-stopped
  networks:
    - monitoring
```

### 設定說明

- **Image**: `grafana/loki:latest` - 使用官方最新版 Loki 映像檔
- **Container Name**: `kevin-telemetry-loki-server` - 容器名稱
- **Ports**: `3100:3100` - 對外暴露 HTTP API 端口 3100
- **Volumes**:
  - `loki_data:/loki` - 持久化儲存卷，存放 Loki 資料
  - `./loki-config.yml:/etc/loki/local-config.yaml` - 掛載配置檔案
- **Command**: `-config.file=/etc/loki/local-config.yaml` - 指定配置檔案路徑
- **Restart Policy**: `unless-stopped` - 除非手動停止，否則自動重啟
- **Network**: `monitoring` - 加入監控網路，與其他服務（Prometheus、Grafana）通訊

### Volume 定義

```yaml
volumes:
  loki_data:
```

持久化儲存卷 `loki_data` 用於保存 Loki 的索引和日誌塊資料。

## Loki 配置檔案 (loki-config.yml)

### 完整配置

```yaml
auth_enabled: false

server:
  http_listen_port: 3100
  http_listen_address: 0.0.0.0  # Allow connections from remote agents

ingester:
  lifecycler:
    address: 0.0.0.0  # Allow connections from remote agents
    ring:
      kvstore:
        store: inmemory
      replication_factor: 1
    final_sleep: 0s
  chunk_idle_period: 5m
  chunk_retain_period: 30s
  wal:
    dir: /tmp/loki/wal
    enabled: false

schema_config:
  configs:
    - from: 2020-05-15
      store: boltdb
      object_store: filesystem
      schema: v11
      index:
        prefix: index_
        period: 24h

storage_config:
  boltdb:
    directory: /tmp/loki/index

  filesystem:
    directory: /tmp/loki/chunks

limits_config:
  reject_old_samples: true
  reject_old_samples_max_age: 168h  # 7 days
  allow_structured_metadata: false
  creation_grace_period: 10m
  # Limit ingestion rate to handle large log files efficiently
  ingestion_rate_mb: 32  # Reduced from 64MB to 32MB per second
  ingestion_burst_size_mb: 64  # Reduced from 128MB to 64MB burst
  max_streams_per_user: 10000
  max_line_size: 256000
  # Additional storage limits for SRS/FFmpeg logs
  max_chunks_per_query: 2000000
  max_query_series: 5000
  max_query_parallelism: 32
  max_entries_limit_per_query: 10000

table_manager:
  retention_deletes_enabled: true
  retention_period: 168h  # 7 days retention
```

### 配置項目說明

#### 1. Server 設定

- **auth_enabled**: `false` - 禁用認證（開發/內部環境）
- **http_listen_port**: `3100` - HTTP API 監聽端口
- **http_listen_address**: `0.0.0.0` - 監聽所有網路介面，允許遠端 Agent 連接

#### 2. Ingester 設定

- **address**: `0.0.0.0` - 允許遠端 Agent 連接
- **ring.kvstore.store**: `inmemory` - 使用記憶體儲存 ring 資訊
- **replication_factor**: `1` - 單節點部署，複製因子為 1
- **chunk_idle_period**: `5m` - Chunk 閒置 5 分鐘後寫入儲存
- **chunk_retain_period**: `30s` - Chunk 保留 30 秒後可被清理
- **wal.enabled**: `false` - 禁用 Write-Ahead Log（單節點模式）

#### 3. Schema 設定

- **from**: `2020-05-15` - Schema 生效起始日期
- **store**: `boltdb` - 索引儲存使用 BoltDB
- **object_store**: `filesystem` - 日誌塊儲存使用檔案系統
- **schema**: `v11` - 使用 v11 Schema
- **index.period**: `24h` - 索引表每 24 小時建立一個

#### 4. Storage 設定

- **boltdb.directory**: `/tmp/loki/index` - BoltDB 索引目錄
- **filesystem.directory**: `/tmp/loki/chunks` - 檔案系統日誌塊目錄

> **注意**: 實際資料會儲存在 Docker volume `loki_data` 中，而非 `/tmp/loki`。

#### 5. Limits 設定

**資料保留與拒絕**:
- **reject_old_samples**: `true` - 拒絕過舊的樣本
- **reject_old_samples_max_age**: `168h` (7 天) - 超過 7 天的樣本會被拒絕
- **creation_grace_period**: `10m` - 允許 10 分鐘的時鐘偏差

**攝取速率限制**:
- **ingestion_rate_mb**: `32` - 每秒最大攝取 32MB
- **ingestion_burst_size_mb**: `64` - 突發攝取最大 64MB

**查詢限制**:
- **max_streams_per_user**: `10000` - 每個使用者最大 10000 個 stream
- **max_line_size**: `256000` - 單行日誌最大 256KB
- **max_chunks_per_query**: `2000000` - 每次查詢最大 200 萬個 chunks
- **max_query_series**: `5000` - 每次查詢最大 5000 個 series
- **max_query_parallelism**: `32` - 最大並行查詢數 32
- **max_entries_limit_per_query**: `10000` - 每次查詢最大 10000 筆記錄

#### 6. Table Manager 設定

- **retention_deletes_enabled**: `true` - 啟用自動刪除過期資料
- **retention_period**: `168h` (7 天) - 資料保留 7 天後自動刪除

## 網路架構

Loki Server 運行在 `monitoring` 橋接網路中，與以下服務通訊：

- **Prometheus**: 監控 Loki 指標
- **Grafana**: 查詢和視覺化日誌
- **Promtail Agents**: 接收來自遠端 Agent 的日誌推送

## 啟動與管理

### 啟動服務

```bash
# 啟動所有服務（包含 Loki）
docker-compose up -d

# 僅啟動 Loki 服務
docker-compose up -d loki
```

### 查看服務狀態

```bash
# 查看容器狀態
docker-compose ps loki

# 查看容器詳細資訊
docker inspect kevin-telemetry-loki-server
```

### 查看日誌

```bash
# 查看即時日誌
docker-compose logs -f loki

# 查看最近 100 行日誌
docker-compose logs --tail=100 loki
```

### 重啟服務

```bash
# 重啟 Loki 服務
docker-compose restart loki

# 停止服務
docker-compose stop loki

# 啟動服務
docker-compose start loki
```

### 更新配置

```bash
# 修改 loki-config.yml 後，重啟服務使配置生效
docker-compose restart loki

# 或重新建立容器
docker-compose up -d --force-recreate loki
```

## 健康檢查

### 檢查服務就緒狀態

```bash
# 檢查 Loki 是否就緒
curl http://localhost:3100/ready

# 預期回應: ready
```

### 檢查服務健康狀態

```bash
# 檢查健康狀態
curl http://localhost:3100/ready

# 檢查指標
curl http://localhost:3100/metrics
```

### 測試日誌推送

```bash
# 測試推送日誌到 Loki
curl -X POST http://localhost:3100/loki/api/v1/push \
  -H "Content-Type: application/json" \
  -d '{
    "streams": [{
      "stream": {"job": "test", "level": "info"},
      "values": [["'$(date +%s%N)'", "test log message"]]
    }]
  }'
```

## 資料儲存

### Volume 位置

Loki 資料儲存在 Docker volume `loki_data` 中，預設位置通常在：
- Linux: `/var/lib/docker/volumes/<project>_loki_data/_data`

### 查看儲存使用量

```bash
# 查看 volume 使用量
docker system df -v | grep loki_data

# 查看 volume 詳細資訊
docker volume inspect <project>_loki_data
```

### 備份資料

```bash
# 備份 volume 資料
docker run --rm \
  -v <project>_loki_data:/data \
  -v $(pwd):/backup \
  alpine tar czf /backup/loki_data_backup_$(date +%Y%m%d).tar.gz -C /data .
```

### 清理資料

```bash
# 停止服務
docker-compose stop loki

# 刪除 volume（會清除所有資料）
docker volume rm <project>_loki_data

# 重新啟動服務（會建立新的 volume）
docker-compose up -d loki
```

## 效能調優

### 針對大量日誌的設定

當前配置已針對大量日誌（如 SRS/FFmpeg 日誌）進行優化：

- **ingestion_rate_mb**: 32MB/s - 降低攝取速率避免過載
- **ingestion_burst_size_mb**: 64MB - 降低突發大小
- **max_chunks_per_query**: 2000000 - 提高查詢 chunks 限制
- **max_query_parallelism**: 32 - 提高並行查詢能力

### 調整建議

如需處理更大流量，可考慮：

1. **增加攝取速率**:
   ```yaml
   ingestion_rate_mb: 64
   ingestion_burst_size_mb: 128
   ```

2. **增加查詢限制**:
   ```yaml
   max_chunks_per_query: 5000000
   max_query_series: 10000
   max_query_parallelism: 64
   ```

3. **調整保留期限**:
   ```yaml
   retention_period: 336h  # 14 天
   reject_old_samples_max_age: 336h
   ```

## 故障排除

### 常見問題

#### 1. Loki 無法啟動

```bash
# 檢查配置檔案語法
docker-compose config

# 查看詳細錯誤訊息
docker-compose logs loki
```

#### 2. 無法接收遠端 Agent 日誌

- 確認 `http_listen_address` 設為 `0.0.0.0`
- 檢查防火牆是否開放 3100 端口
- 確認網路連通性

#### 3. 儲存空間不足

```bash
# 檢查磁碟使用量
df -h

# 清理舊資料（調整 retention_period）
# 或擴展儲存空間
```

#### 4. 查詢效能緩慢

- 檢查 `max_chunks_per_query` 和 `max_query_parallelism` 設定
- 考慮增加查詢限制或優化 LogQL 查詢語句

## 相關檔案

- `docker-compose.yml` - Docker Compose 服務定義
- `loki-config.yml` - Loki 配置檔案
- `grafana/provisioning/datasources/loki.yml` - Grafana 資料源配置
- [Loki Architecture](../../setup/LOKI_ARCHITECTURE.md) - 架構說明文件

## 參考資料

- [Loki 官方文件](https://grafana.com/docs/loki/latest/)
- [Loki 配置參考](https://grafana.com/docs/loki/latest/configuration/)
- [Docker Compose 文件](https://docs.docker.com/compose/)











