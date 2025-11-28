# ZCAM Values Exporter 開機自動啟動設定

## 概述

本文件說明如何確保 GC-ARO-001-2 agent 的 ZCAM Values Exporter 在每次重開機後都會自動啟動並傳送資料。

## 已完成的修改

### 1. 將 ZCAM Exporter 加入到 Agent Docker Compose

已將 `zcam-values-exporter` 服務加入到 `docker-compose-GC-ARO-001-2-agent.yml` 中，確保它與其他 agent 服務（Promtail、Zabbix Agent）一起啟動。

**修改的檔案：**
- `docker-compose-GC-ARO-001-2-agent.yml`

**新增的服務配置：**
```yaml
  # ZCAM Values Exporter - Exports ZCAM device metrics to Prometheus
  zcam-values-exporter:
    image: python:3.11-alpine
    container_name: kevin-telemetry-zcam-values-exporter
    restart: unless-stopped
    working_dir: /app
    command: sh -c "pip install prometheus-client requests && python zcam-values-exporter.py"
    volumes:
      - ./scripts/zcam-values-exporter.py:/app/zcam-values-exporter.py:ro
    ports:
      - "9274:9274"  # Prometheus metrics endpoint
    networks:
      - monitoring
```

### 2. 創建 Systemd Service

已創建 systemd service 檔案 `telemetry-agent-GC-ARO-001-2.service`，確保 agent 服務在開機時自動啟動。

**Service 檔案位置：**
- `telemetry-agent-GC-ARO-001-2.service` (在專案根目錄)

**Service 配置：**
- 在 Docker 服務啟動後自動執行
- 使用 `docker compose up -d` 啟動所有 agent 服務
- 配置為開機自動啟動

## 安裝步驟

### 方法 1：使用自動安裝腳本（推薦）

```bash
cd /home/rnd/telemetry
./setup-zcam-exporter-auto-start.sh
```

### 方法 2：手動安裝

```bash
cd /home/rnd/telemetry

# 1. 複製 service 檔案到 systemd 目錄
sudo cp telemetry-agent-GC-ARO-001-2.service /etc/systemd/system/

# 2. 重新載入 systemd daemon
sudo systemctl daemon-reload

# 3. 啟用 service 開機自動啟動
sudo systemctl enable telemetry-agent-GC-ARO-001-2.service

# 4. 立即啟動 service（可選）
sudo systemctl start telemetry-agent-GC-ARO-001-2.service

# 5. 檢查 service 狀態
sudo systemctl status telemetry-agent-GC-ARO-001-2.service
```

## 驗證步驟

### 1. 檢查 Service 狀態

```bash
sudo systemctl status telemetry-agent-GC-ARO-001-2.service
```

預期輸出應顯示：
- `Loaded: loaded` (已載入)
- `Active: active (exited)` (已啟用)
- `enabled` (開機自動啟動已啟用)

### 2. 檢查容器是否運行

```bash
docker ps | grep -E "zcam-values-exporter|promtail|zabbix-agent"
```

應該看到三個容器：
- `kevin-telemetry-zcam-values-exporter`
- `telemetry-promtail-GC-aro12-agent`
- `telemetry-zabbix-agent-GC-aro12-agent`

### 3. 檢查 ZCAM Exporter Metrics

```bash
curl http://localhost:9274/metrics | grep "zcam_bitrate.*aro12"
```

應該看到類似以下的輸出：
```
zcam_bitrate{device_ip="192.168.88.11",device_name="zcam-aro12"} 5.8819
```

### 4. 測試開機自動啟動

```bash
# 重啟系統（請在適當的時間執行）
sudo reboot

# 重啟後檢查服務狀態
sudo systemctl status telemetry-agent-GC-ARO-001-2.service
docker ps | grep zcam-values-exporter
```

## 服務管理命令

### 啟動服務

```bash
sudo systemctl start telemetry-agent-GC-ARO-001-2.service
```

### 停止服務

```bash
sudo systemctl stop telemetry-agent-GC-ARO-001-2.service
```

### 重新啟動服務

```bash
sudo systemctl restart telemetry-agent-GC-ARO-001-2.service
```

### 查看服務日誌

```bash
sudo journalctl -u telemetry-agent-GC-ARO-001-2.service -f
```

### 查看容器日誌

```bash
docker logs kevin-telemetry-zcam-values-exporter -f
```

## 故障排除

### 問題 1：Service 無法啟動

**檢查：**
```bash
sudo systemctl status telemetry-agent-GC-ARO-001-2.service
sudo journalctl -u telemetry-agent-GC-ARO-001-2.service -n 50
```

**可能原因：**
- Docker 服務未啟動
- docker-compose 檔案路徑錯誤
- 權限問題

### 問題 2：容器無法啟動

**檢查：**
```bash
docker ps -a | grep zcam-values-exporter
docker logs kevin-telemetry-zcam-values-exporter
```

**可能原因：**
- 網路配置問題（monitoring network 不存在）
- 腳本檔案路徑錯誤
- 端口衝突

### 問題 3：Metrics 無法訪問

**檢查：**
```bash
# 檢查容器是否運行
docker ps | grep zcam-values-exporter

# 檢查端口是否監聽
netstat -tlnp | grep 9274

# 檢查容器日誌
docker logs kevin-telemetry-zcam-values-exporter --tail 50
```

## 架構說明

```
開機流程：
1. 系統啟動
2. Docker 服務啟動 (systemd)
3. telemetry-agent-GC-ARO-001-2.service 啟動
4. 執行 docker compose up -d
5. 啟動三個容器：
   - Promtail (日誌收集)
   - Zabbix Agent (系統監控)
   - ZCAM Values Exporter (ZCAM 指標)
```

## 相關檔案

- `docker-compose-GC-ARO-001-2-agent.yml` - Agent Docker Compose 配置
- `telemetry-agent-GC-ARO-001-2.service` - Systemd Service 配置
- `setup-zcam-exporter-auto-start.sh` - 自動安裝腳本
- `scripts/zcam-values-exporter.py` - ZCAM Exporter 腳本

## 更新日期

2025-11-28

