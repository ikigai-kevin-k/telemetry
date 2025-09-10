# Zabbix 系統監控設定指南

本指南說明如何為 Zabbix 系統添加全面的系統監控功能，以防止 agent 端電腦出現突然斷電、硬碟/記憶體/CPU 用量超標等問題。

## 📋 功能概述

### 🔧 系統資源監控
- **CPU 使用率監控** - 即時監控 CPU 使用率，設定警告和嚴重閾值
- **記憶體使用率監控** - 監控系統記憶體使用情況
- **硬碟使用率監控** - 監控根目錄和指定掛載點的使用率
- **系統負載監控** - 監控系統負載平均值
- **溫度監控** - 監控系統溫度（如果硬體支援）

### ⚡ 電源狀態監控
- **電池狀態監控** - 檢測系統是否使用電池供電
- **電池電量監控** - 監控電池剩餘電量
- **UPS 監控** - 監控 UPS 狀態和剩餘運行時間
- **電源供應器狀態** - 監控 AC 電源連接狀態
- **電源事件監控** - 監控電源相關事件

### 🏥 系統健康檢查
- **關鍵服務檢查** - 監控關鍵系統服務狀態
- **網路連通性檢查** - 檢查網路連接和 DNS 解析
- **檔案系統完整性** - 檢查檔案系統錯誤
- **系統日誌檢查** - 監控系統錯誤日誌
- **綜合健康評分** - 提供整體系統健康評分

## 📁 檔案結構

```
zabbix/
├── scripts/
│   ├── system_monitor.sh          # 系統資源監控腳本
│   ├── power_monitor.sh           # 電源狀態監控腳本
│   ├── health_check.sh            # 系統健康檢查腳本
│   ├── check_zcam_status.sh       # 現有的 ZCAM 監控腳本
│   └── check_zcam_detailed.sh     # 現有的詳細 ZCAM 監控腳本
├── agent2.conf                    # 更新的 Zabbix Agent 配置
├── zabbix_template_system_monitoring.xml  # Zabbix 模板檔案
├── alert_thresholds.conf          # 告警閾值配置
└── SYSTEM_MONITORING_README.md    # 本說明文件
```

## 🚀 安裝步驟

### 1. 確認腳本權限
所有監控腳本都已設定為可執行：
```bash
chmod +x /home/rnd/telemetry/zabbix/scripts/*.sh
```

### 2. 重啟 Zabbix Agent
更新 agent 配置後需要重啟：
```bash
cd /home/rnd/telemetry
./zabbix/start_zabbix.sh restart
```

### 3. 測試監控腳本
測試各個監控腳本是否正常運作：

```bash
# 測試系統監控
./zabbix/scripts/system_monitor.sh cpu_usage
./zabbix/scripts/system_monitor.sh memory_usage
./zabbix/scripts/system_monitor.sh disk_usage

# 測試電源監控
./zabbix/scripts/power_monitor.sh battery_power
./zabbix/scripts/power_monitor.sh battery_charge

# 測試健康檢查
./zabbix/scripts/health_check.sh comprehensive
./zabbix/scripts/health_check.sh summary
```

### 4. 導入 Zabbix 模板
1. 登入 Zabbix Web 介面 (http://localhost:8080)
2. 前往 **Configuration** → **Templates**
3. 點擊 **Import**
4. 選擇 `zabbix_template_system_monitoring.xml` 檔案
5. 點擊 **Import** 完成導入

### 5. 將模板套用到主機
1. 前往 **Configuration** → **Hosts**
2. 選擇要監控的主機
3. 在 **Templates** 標籤中添加 **System Monitoring Template**
4. 點擊 **Update** 儲存設定

## 📊 監控項目說明

### 系統資源監控項目
| 項目名稱 | 鍵值 | 說明 | 單位 |
|---------|------|------|------|
| CPU Usage | system.cpu.usage | CPU 使用率 | % |
| Memory Usage | system.memory.usage | 記憶體使用率 | % |
| Disk Usage | system.disk.usage | 根目錄使用率 | % |
| Load Average | system.load.average | 系統負載平均值 | - |
| Temperature | system.temperature | 系統溫度 | °C |

### 電源監控項目
| 項目名稱 | 鍵值 | 說明 | 單位 |
|---------|------|------|------|
| Battery Status | power.battery.status | 電池狀態 (1=電池, 0=AC) | - |
| Battery Charge | power.battery.charge | 電池電量 | % |
| UPS Runtime | power.ups.runtime | UPS 剩餘時間 | 分鐘 |
| Power Supply Status | power.supply.status | AC 電源狀態 | - |

### 健康檢查項目
| 項目名稱 | 鍵值 | 說明 | 單位 |
|---------|------|------|------|
| System Health Score | health.comprehensive | 系統健康評分 | 分數 |
| Critical Services | health.critical.services | 失敗的關鍵服務數量 | 個 |
| Network Issues | health.network | 網路問題數量 | 個 |

## ⚠️ 告警設定

### 預設閾值
- **CPU 使用率**: 警告 80%, 嚴重 90%
- **記憶體使用率**: 警告 80%, 嚴重 90%
- **硬碟使用率**: 警告 80%, 嚴重 90%
- **系統溫度**: 警告 70°C, 嚴重 80°C
- **電池電量**: 警告 20%, 嚴重 10%
- **系統健康評分**: 警告 <70, 嚴重 <50

### 告警觸發器
模板包含以下主要觸發器：
- High CPU Usage (CPU > 80%)
- Critical CPU Usage (CPU > 90%)
- High Memory Usage (Memory > 80%)
- High Disk Usage (Disk > 80%)
- High System Temperature (Temp > 70°C)
- Low Battery Charge (Battery < 20%)
- System Running on Battery
- Low System Health (Score < 70)
- Critical Services Down

## 🔧 自訂設定

### 修改閾值
編輯 `alert_thresholds.conf` 檔案來調整告警閾值：

```bash
# CPU 監控閾值
CPU_WARNING_THRESHOLD=80
CPU_CRITICAL_THRESHOLD=90

# 記憶體監控閾值
MEMORY_WARNING_THRESHOLD=80
MEMORY_CRITICAL_THRESHOLD=90
```

### 添加自訂監控項目
在 `agent2.conf` 中添加新的 UserParameter：

```bash
UserParameter=custom.metric,/path/to/script.sh parameter
```

### 監控特定掛載點
使用參數化監控項目：

```bash
# 監控 /var 目錄
system.disk.usage.mount[/var]

# 監控特定網路介面
system.network.status[eth0]
```

## 📈 圖表設定

模板包含兩個預設圖表：
1. **System Resources** - 顯示 CPU、記憶體、硬碟使用率
2. **Power Status** - 顯示電池電量和 UPS 運行時間

## 🛠️ 故障排除

### 常見問題

1. **腳本無法執行**
   ```bash
   # 檢查腳本權限
   ls -la /home/rnd/telemetry/zabbix/scripts/
   
   # 重新設定權限
   chmod +x /home/rnd/telemetry/zabbix/scripts/*.sh
   ```

2. **監控項目無資料**
   ```bash
   # 檢查 Zabbix Agent 狀態
   ./zabbix/start_zabbix.sh status
   
   # 查看 Agent 日誌
   ./zabbix/start_zabbix.sh logs zabbix-agent
   ```

3. **溫度監控無資料**
   - 確認系統支援溫度感測器
   - 檢查 `/sys/class/thermal/` 目錄是否存在
   - 安裝 `lm-sensors` 套件

4. **UPS 監控無資料**
   - 確認已安裝 Network UPS Tools (nut)
   - 檢查 UPS 驅動程式是否正確安裝
   - 確認 UPS 連接狀態

### 日誌檢查
```bash
# 查看 Zabbix Agent 日誌
docker compose logs zabbix-agent

# 查看系統日誌
journalctl -f

# 查看特定服務日誌
systemctl status ssh
```

## 📞 支援

如果遇到問題，請檢查：
1. 腳本執行權限
2. Zabbix Agent 配置
3. 系統日誌
4. 網路連通性

## 🔄 更新說明

當需要更新監控腳本時：
1. 修改對應的腳本檔案
2. 重啟 Zabbix Agent
3. 測試新的監控項目
4. 更新告警設定（如需要）

---

**注意**: 本監控系統設計為防止系統突然斷電、資源使用超標等問題，請根據實際環境調整閾值設定。
