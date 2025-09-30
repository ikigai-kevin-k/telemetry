# ZCAM 多設備監控設定指南

## 📋 概述
本指南說明如何設定和使用 6 台 ZCAM 設備的監控系統，對應到不同的 Zabbix agents。

## 🎯 設備對應關係

| ZCAM 設備名稱 | IP 位址 | 對應 Agent | RTMP 伺服器 | 串流金鑰 |
|---------------|---------|------------|-------------|----------|
| zcam-aro-001-1 | 192.168.88.184 | aro-001-1 | 192.168.88.26 | r184_sr |
| zcam-aro-001-2 | 192.168.88.186 | aro-001-2 | 192.168.88.27 | r186_sr |
| zcam-aro-002-1 | 192.168.88.183 | aro-002-1 | 192.168.88.84 | r183_vr |
| zcam-aro-002-2 | 192.168.88.34 | aro-002-2 | 192.168.88.50 | r034_vr |
| zcam-asb-001-1 | 192.168.88.212 | asb-001-1 | 192.168.88.10 | r212_sb |
| zcam-tpe-001-1 | 192.168.20.8 | tpe-001-1 | 192.168.20.10 | r008_tpe |

## 📁 建立的檔案

### 1. **配置檔案**
- **`zabbix/zcam_devices.conf`** - 設備配置檔案
- **`zabbix/zabbix_zcam_items.conf`** - Zabbix 監控項目配置

### 2. **監控腳本**
- **`zabbix/zcam_multi_monitor.sh`** - 多設備綜合監控
- **`zabbix/zcam_single_check.sh`** - 單一設備查詢
- **`zabbix/discover_zcam_api.sh`** - API 探索腳本

### 3. **文件**
- **`ZCAM_API_Reference.md`** - API 參考指南
- **`ZCAM_Multi_Device_Setup.md`** - 本設定指南

## 🔧 使用方式

### **多設備監控**
```bash
# 監控所有 6 台 ZCAM 設備
./zabbix/zcam_multi_monitor.sh

# 輸出範例：
# === ZCAM Multi-Device Monitor ===
# === GLOBAL SUMMARY ===
# Total Devices: 6
# Healthy: 6
# Warning: 0  
# Critical: 0
# Overall Status: SYSTEM HEALTHY (100%)
```

### **單一設備查詢**
```bash
# 查詢特定設備的 RTMP 狀態
./zabbix/zcam_single_check.sh zcam-aro-001-1 rtmp_status
# 輸出: busy

# 查詢電池電量
./zabbix/zcam_single_check.sh zcam-aro-001-1 battery_level  
# 輸出: 100

# 查詢頻寬使用
./zabbix/zcam_single_check.sh zcam-aro-001-1 bandwidth
# 輸出: 5.82678
```

### **可用監控指標**
- `rtmp_status` - RTMP 串流狀態 (busy/idle)
- `battery_level` - 電池電量 (0-100)
- `camera_mode` - 攝影機模式 (rec/photo)
- `bandwidth` - 頻寬使用 (Mbps)
- `health_score` - 健康評分 (0-100%)
- `resolution` - 影像解析度
- `iso` - ISO 感光度

## 📊 當前設備狀態

根據最新測試結果：

### **ZCAM ARO-001-1 (192.168.88.184)**
- ✅ RTMP 狀態: busy (正在串流)
- ✅ 電池電量: 100%
- ✅ 攝影機模式: rec (錄影)
- 📊 頻寬: 5.83 Mbps
- 🎥 解析度: 1920x1080
- 📷 ISO: 500

### **ZCAM ARO-001-2 (192.168.88.186)**
- ✅ RTMP 狀態: busy (正在串流)
- ✅ 電池電量: 100%
- ✅ 攝影機模式: rec (錄影)
- 📊 頻寬: 5.96 Mbps
- 🎥 解析度: 1920x1080
- 📷 ISO: 500

### **ZCAM ARO-002-1 (192.168.88.183)**
- ✅ RTMP 狀態: busy (正在串流)
- ✅ 電池電量: 100%
- ✅ 攝影機模式: rec (錄影)
- 📊 頻寬: 5.85 Mbps
- 🎥 解析度: 1920x1080
- 📷 ISO: 500

### **ZCAM ARO-002-2 (192.168.88.34)**
- ✅ RTMP 狀態: busy (正在串流)
- ✅ 電池電量: 100%
- ✅ 攝影機模式: rec (錄影)
- 📊 頻寬: 0.0 Mbps (注意：可能是待機狀態)
- 🎥 解析度: 1920x1080
- 📷 ISO: 500
- ⚠️ 自動重啟: 停用

### **ZCAM ASB-001-1 (192.168.88.212)**
- ✅ RTMP 狀態: busy (正在串流)
- ✅ 電池電量: 100%
- ✅ 攝影機模式: rec (錄影)
- 📊 頻寬: 5.81 Mbps
- 🎥 解析度: 1920x1080
- 📷 ISO: Auto

### **ZCAM TPE-001-1 (192.168.20.8) - New TPE Server**
- ✅ RTMP 狀態: busy (正在串流)
- ✅ 電池電量: 100%
- ✅ 攝影機模式: rec (錄影)
- 📊 頻寬: 5.81 Mbps
- 🌡️ 溫度: 46°C
- 🎥 解析度: 1920x1080
- 📷 ISO: Auto
- 🔄 自動重啟: 啟用

## 🚨 告警建議

### **監控閾值設定**
- **電池電量**: < 30% 警告，< 15% 嚴重
- **RTMP 狀態**: != "busy" 警告
- **頻寬使用**: = 0 且狀態為 busy 時警告
- **健康評分**: < 80% 警告，< 60% 嚴重

### **特別注意**
1. **ARO-002-2**: 頻寬為 0 但狀態為 busy，需要檢查
2. **ARO-002-2**: 自動重啟功能停用，建議啟用

## 🔗 Zabbix 整合

### **新增監控項目**
將 `zabbix/zabbix_zcam_items.conf` 的內容加入到對應的 Zabbix Agent 配置中：

```bash
# 在各個 agent 主機上執行
sudo cat /path/to/zabbix_zcam_items.conf >> /etc/zabbix/zabbix_agentd.conf
sudo systemctl restart zabbix-agent
```

### **Grafana Dashboard 整合**
可以在現有的 Zabbix dashboard 中新增 ZCAM 監控面板：

1. **RTMP 串流狀態面板**
2. **電池電量趨勢面板**
3. **頻寬使用面板**
4. **設備健康評分面板**

## 📝 維護建議

### **定期檢查**
- 每日執行多設備監控腳本
- 每週檢查設備配置是否有變更
- 每月檢查 API 端點可用性

### **日誌管理**
- 監控日誌位置: `/tmp/zcam_multi_monitor.log`
- 建議設定日誌輪轉避免磁碟空間不足

### **故障排除**
1. **設備無回應**: 檢查網路連通性
2. **API 錯誤**: 檢查設備是否重啟或設定變更
3. **串流異常**: 檢查 RTMP 伺服器狀態

## 🎯 後續擴展

### **可能的改進**
1. **自動設備發現**: 自動掃描網段發現新 ZCAM 設備
2. **設定同步**: 批次設定多台設備的參數
3. **效能監控**: 增加 CPU、記憶體使用率監控
4. **告警整合**: 與 Slack/Email 告警系統整合

---

**建立日期**: 2025-09-19  
**最後更新**: 2025-09-19  
**狀態**: ✅ 所有 5 台設備正常運作
