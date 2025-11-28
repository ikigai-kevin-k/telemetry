# ARO12 ZCAM Exporter 開機自動啟動驗證指南

## 概述

本文件說明如何確保 GC-ARO-001-2 agent 的 ZCAM Values Exporter 在每次重開機後都會自動啟動並推送 ARO12 的 zcam data。

## 已完成的配置

### 1. Docker Compose 配置

**檔案：** `docker-compose-GC-ARO-001-2-agent.yml`

所有服務都已配置 `restart: unless-stopped`：
- ✅ Promtail: `restart: unless-stopped`
- ✅ Zabbix Agent: `restart: unless-stopped`
- ✅ ZCAM Values Exporter: `restart: unless-stopped`

這確保了即使容器意外停止，Docker 也會自動重啟它們。

### 2. Systemd Service 配置

**檔案：** `telemetry-agent-GC-ARO-001-2.service`

Service 配置特點：
- ✅ 已配置為開機自動啟動 (`WantedBy=multi-user.target`)
- ✅ 在 Docker 服務啟動後執行 (`After=docker.service`)
- ✅ 等待網路就緒 (`Wants=network-online.target`)
- ✅ 使用 `docker compose` 命令啟動所有服務
- ✅ 配置了重啟策略 (`Restart=on-failure`)

### 3. Agent-Side 專用腳本

**檔案：** `scripts/zcam-values-exporter-aro12-agent.py`

- ✅ 只監控 ARO12 設備（`zcam-aro12`）
- ✅ 使用 IP `192.168.88.12`（根據用戶要求）
- ✅ 自動重試機制（30 秒間隔）

## 驗證步驟

### 步驟 1：確認 Systemd Service 已啟用

```bash
sudo systemctl is-enabled telemetry-agent-GC-ARO-001-2.service
```

預期輸出：`enabled`

### 步驟 2：檢查 Service 狀態

```bash
sudo systemctl status telemetry-agent-GC-ARO-001-2.service
```

預期狀態：
- `Loaded: loaded` (已載入)
- `Active: active (exited)` 或 `Active: inactive (dead)` (對於 oneshot service 這是正常的)
- `enabled` (開機自動啟動已啟用)

### 步驟 3：確認容器運行狀態

```bash
docker ps | grep -E "zcam-values-exporter|promtail|zabbix-agent"
```

應該看到三個容器：
- `kevin-telemetry-zcam-values-exporter` (狀態: Up)
- `telemetry-promtail-GC-aro12-agent` (狀態: Up)
- `telemetry-zabbix-agent-GC-aro12-agent` (狀態: Up)

### 步驟 4：驗證 ZCAM Exporter Metrics

```bash
curl http://localhost:9274/metrics | grep "zcam.*aro12"
```

預期輸出應包含：
```
zcam_temperature{device_ip="192.168.88.12",device_name="zcam-aro12"} <value>
zcam_bitrate{device_ip="192.168.88.12",device_name="zcam-aro12"} <value>
zcam_battery_level{device_ip="192.168.88.12",device_name="zcam-aro12"} <value>
```

### 步驟 5：測試開機自動啟動

```bash
# 重啟系統（請在適當的時間執行）
sudo reboot

# 重啟後檢查服務狀態
sudo systemctl status telemetry-agent-GC-ARO-001-2.service
docker ps | grep zcam-values-exporter
curl http://localhost:9274/metrics | grep "zcam.*aro12"
```

## 安裝/更新 Systemd Service

如果 systemd service 尚未安裝或需要更新，執行：

```bash
cd /home/rnd/telemetry

# 方法 1：使用自動安裝腳本（推薦）
./setup-zcam-exporter-auto-start.sh

# 方法 2：手動安裝
sudo cp telemetry-agent-GC-ARO-001-2.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable telemetry-agent-GC-ARO-001-2.service
```

## 開機流程說明

```
1. 系統啟動
   ↓
2. Docker 服務啟動 (systemd)
   ↓
3. 網路服務就緒 (network-online.target)
   ↓
4. telemetry-agent-GC-ARO-001-2.service 啟動
   ↓
5. 執行: docker compose -f docker-compose-GC-ARO-001-2-agent.yml up -d
   ↓
6. 啟動三個容器：
   - Promtail (日誌收集)
   - Zabbix Agent (系統監控)
   - ZCAM Values Exporter (ARO12 ZCAM 指標)
   ↓
7. 所有容器配置了 restart: unless-stopped
   ↓
8. ZCAM Exporter 開始每 30 秒查詢 192.168.88.12 並推送 metrics
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
- docker-compose 命令路徑錯誤
- 工作目錄不存在

**解決方案：**
```bash
# 確認 Docker 服務狀態
sudo systemctl status docker

# 確認 docker compose 命令
docker compose version

# 確認工作目錄
ls -la /home/rnd/telemetry/docker-compose-GC-ARO-001-2-agent.yml
```

### 問題 2：容器無法啟動

**檢查：**
```bash
docker ps -a | grep zcam-values-exporter
docker logs kevin-telemetry-zcam-values-exporter
```

**可能原因：**
- 腳本檔案路徑錯誤
- 網路配置問題
- 端口衝突

**解決方案：**
```bash
# 檢查腳本檔案是否存在
ls -la scripts/zcam-values-exporter-aro12-agent.py

# 檢查端口是否被占用
netstat -tlnp | grep 9274

# 手動啟動測試
docker compose -f docker-compose-GC-ARO-001-2-agent.yml up -d
```

### 問題 3：Metrics 無法訪問

**檢查：**
```bash
# 檢查容器是否運行
docker ps | grep zcam-values-exporter

# 檢查 metrics endpoint
curl http://localhost:9274/metrics

# 檢查容器日誌
docker logs kevin-telemetry-zcam-values-exporter --tail 50
```

**可能原因：**
- 容器未正常啟動
- 腳本執行錯誤
- 設備 IP 無法訪問

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

## 配置檢查清單

- [x] `docker-compose-GC-ARO-001-2-agent.yml` 中所有服務配置了 `restart: unless-stopped`
- [x] `telemetry-agent-GC-ARO-001-2.service` 已創建
- [x] Systemd service 已複製到 `/etc/systemd/system/`
- [x] Systemd service 已啟用開機自動啟動 (`enabled`)
- [x] `scripts/zcam-values-exporter-aro12-agent.py` 已創建並配置正確的 IP
- [x] Docker 服務已啟用開機自動啟動

## 相關檔案

- `docker-compose-GC-ARO-001-2-agent.yml` - Agent Docker Compose 配置
- `telemetry-agent-GC-ARO-001-2.service` - Systemd Service 配置
- `scripts/zcam-values-exporter-aro12-agent.py` - Agent-side 專用腳本
- `setup-zcam-exporter-auto-start.sh` - 自動安裝腳本

## 更新日期

2025-11-28

