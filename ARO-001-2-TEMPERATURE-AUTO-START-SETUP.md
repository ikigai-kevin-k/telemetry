# ARO-001-2 溫度監控自動啟動設定

## 概述

本文件說明如何確保 GC-ARO-001-2 agent 的溫度監控服務在每次重開機後都會自動啟動並推送溫度資料。

## 已完成的配置

### 1. Systemd Service 配置

**檔案：** `temperature-exporter-aro001-2.service`

Service 配置特點：
- ✅ 已配置為開機自動啟動 (`WantedBy=multi-user.target`)
- ✅ 等待網路就緒 (`After=network-online.target`)
- ✅ 使用 `Restart=always` 確保服務自動重啟
- ✅ 直接執行溫度推送腳本，由 systemd 管理進程生命週期
- ✅ 日誌輸出到 systemd journal

### 2. 安裝腳本

**檔案：** `setup-temperature-exporter-auto-start-aro001-2.sh`

自動化安裝腳本，執行以下操作：
- 複製 service 檔案到 `/etc/systemd/system/`
- 重新載入 systemd daemon
- 啟用開機自動啟動
- 停止手動啟動的進程（如果存在）
- 啟動 systemd service

## 安裝步驟

### 方法 1：使用自動安裝腳本（推薦）

```bash
cd /home/rnd/telemetry
bash setup-temperature-exporter-auto-start-aro001-2.sh
```

### 方法 2：手動安裝

```bash
cd /home/rnd/telemetry

# 1. 確保腳本有執行權限
chmod +x start-temperature-exporter-aro001-2.sh
chmod +x push_temperature_to_pushgateway_aro001_2.sh

# 2. 複製 service 檔案到 systemd 目錄
sudo cp temperature-exporter-aro001-2.service /etc/systemd/system/

# 3. 重新載入 systemd daemon
sudo systemctl daemon-reload

# 4. 啟用 service 開機自動啟動
sudo systemctl enable temperature-exporter-aro001-2.service

# 5. 停止手動啟動的進程（如果存在）
if [ -f /tmp/temperature-exporter-aro001-2.pid ]; then
    OLD_PID=$(cat /tmp/temperature-exporter-aro001-2.pid)
    if ps -p "$OLD_PID" > /dev/null 2>&1; then
        kill "$OLD_PID"
    fi
fi

# 6. 立即啟動 service（可選）
sudo systemctl start temperature-exporter-aro001-2.service
```

## 驗證步驟

### 步驟 1：確認 Systemd Service 已啟用

```bash
sudo systemctl is-enabled temperature-exporter-aro001-2.service
```

預期輸出：`enabled`

### 步驟 2：檢查 Service 狀態

```bash
sudo systemctl status temperature-exporter-aro001-2.service
```

預期狀態：
- `Loaded: loaded` (已載入)
- `Active: active (running)` (正在運行)
- `enabled` (開機自動啟動已啟用)

### 步驟 3：確認進程運行

```bash
ps aux | grep push_temperature_to_pushgateway_aro001_2 | grep -v grep
```

應該看到溫度監控腳本正在運行。

### 步驟 4：檢查 Pushgateway 資料

```bash
curl -s "http://100.64.0.113:9091/metrics" | grep "system_temperature_celsius.*GC-ARO-001-2-agent"
```

應該看到溫度資料：
```
system_temperature_celsius{instance="GC-ARO-001-2-agent",job="agent_temperature"} <temperature_value>
```

### 步驟 5：查看 Service 日誌

```bash
sudo journalctl -u temperature-exporter-aro001-2.service -f
```

應該看到類似以下的輸出：
```
Starting temperature exporter -> http://100.64.0.113:9091 as job=agent_temperature, instance=GC-ARO-001-2-agent
```

## 測試自動啟動

### 測試重啟後自動啟動

```bash
# 重啟系統測試（請在安全時間進行）
sudo reboot

# 重啟後檢查服務狀態
sudo systemctl status temperature-exporter-aro001-2.service

# 檢查進程是否運行
ps aux | grep push_temperature_to_pushgateway_aro001_2 | grep -v grep

# 檢查 Pushgateway 是否有資料
curl -s "http://100.64.0.113:9091/metrics" | grep "system_temperature_celsius.*GC-ARO-001-2-agent"
```

## 常用操作指令

### 查看服務狀態

```bash
sudo systemctl status temperature-exporter-aro001-2.service
```

### 查看服務日誌

```bash
# 查看所有日誌
sudo journalctl -u temperature-exporter-aro001-2.service

# 查看最新日誌（即時）
sudo journalctl -u temperature-exporter-aro001-2.service -f

# 查看最近 50 行日誌
sudo journalctl -u temperature-exporter-aro001-2.service -n 50
```

### 手動操作服務

```bash
# 啟動服務
sudo systemctl start temperature-exporter-aro001-2.service

# 停止服務
sudo systemctl stop temperature-exporter-aro001-2.service

# 重啟服務
sudo systemctl restart temperature-exporter-aro001-2.service

# 禁用開機自動啟動
sudo systemctl disable temperature-exporter-aro001-2.service

# 重新啟用開機自動啟動
sudo systemctl enable temperature-exporter-aro001-2.service
```

## 故障排除

### 問題 1：服務無法啟動

**檢查步驟：**
1. 查看服務狀態：`sudo systemctl status temperature-exporter-aro001-2.service`
2. 查看詳細日誌：`sudo journalctl -u temperature-exporter-aro001-2.service -n 50`
3. 檢查腳本權限：`ls -l /home/rnd/telemetry/push_temperature_to_pushgateway_aro001_2.sh`
4. 檢查 sensors 命令是否可用：`which sensors`

### 問題 2：服務啟動但沒有推送資料

**檢查步驟：**
1. 檢查網路連線：`curl -s http://100.64.0.113:9091/metrics | head -5`
2. 檢查溫度讀取：`sensors -j | jq -r '..|.temp1_input? // empty' | head -n1`
3. 查看服務日誌：`sudo journalctl -u temperature-exporter-aro001-2.service -f`

### 問題 3：重啟後服務沒有自動啟動

**檢查步驟：**
1. 確認服務已啟用：`sudo systemctl is-enabled temperature-exporter-aro001-2.service`
2. 檢查服務狀態：`sudo systemctl status temperature-exporter-aro001-2.service`
3. 查看系統啟動日誌：`sudo journalctl -b | grep temperature-exporter`

## 技術細節

### Service 配置說明

- **Type=simple**: systemd 會等待 ExecStart 命令啟動的進程成為主進程
- **Restart=always**: 無論如何退出都會自動重啟
- **RestartSec=10**: 重啟前等待 10 秒
- **After=network-online.target**: 確保網路就緒後才啟動
- **User=rnd / Group=rnd**: 以 rnd 使用者身份運行

### 與手動啟動的差異

- **手動啟動**：使用 `start-temperature-exporter-aro001-2.sh`，進程在背景運行，PID 保存在 `/tmp/temperature-exporter-aro001-2.pid`
- **Systemd 管理**：systemd 直接管理進程，不需要 PID 文件，自動處理重啟和日誌

## 完成時間

2025-11-29

