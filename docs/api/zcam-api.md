# ZCAM API Reference Guide

## 📋 概述
本文件記錄了 ZCAM 攝影機 (IP: 192.168.88.175) 的可用 HTTP API 端點和參數。

## 🌐 基本資訊
- **設備 IP**: 192.168.88.175
- **基本 URL**: http://192.168.88.175
- **API 協議**: HTTP GET/POST
- **回應格式**: JSON

## ✅ 已發現的工作 API 端點

### 1. 基本端點

#### `/ctrl/session` - 會話資訊
```bash
curl "http://192.168.88.175/ctrl/session"
```
**回應**:
```json
{"code":0,"desc":"","msg":""}
```

#### `/ctrl/mode` - 攝影機模式
```bash
curl "http://192.168.88.175/ctrl/mode"
```
**回應**:
```json
{"code":0,"desc":"","msg":"rec"}
```

### 2. RTMP 串流相關

#### `/ctrl/rtmp?action=query&index=0` - RTMP 狀態查詢
```bash
curl "http://192.168.88.175/ctrl/rtmp?action=query&index=0"
```
**回應**:
```json
{
  "url": "rtmp://192.168.88.180:1935/live/r175_bj",
  "key": "",
  "bw": 0.0,
  "status": "busy",
  "autoRestart": 1,
  "code": 0
}
```

**欄位說明**:
- `url`: RTMP 串流 URL
- `key`: 串流金鑰 (空值)
- `bw`: 頻寬使用 (Mbps)
- `status`: 串流狀態 ("busy" = 正在串流)
- `autoRestart`: 自動重啟設定 (1=啟用)
- `code`: 回應代碼 (0=成功)

#### `/ctrl/rtmp?action=query` - RTMP 查詢 (不指定索引)
與上述相同，但不需要指定 index 參數。

### 3. 攝影機設定參數 (GET)

#### `/ctrl/get?k=battery` - 電池狀態
```bash
curl "http://192.168.88.175/ctrl/get?k=battery"
```
**回應**:
```json
{
  "code": 0,
  "desc": "string",
  "key": "battery",
  "type": 2,
  "ro": 1,
  "value": 100,
  "min": 0,
  "max": 100,
  "step": 1
}
```

**欄位說明**:
- `value`: 電池電量百分比 (100 = 滿電)
- `ro`: 唯讀屬性 (1=唯讀)
- `min/max`: 數值範圍
- `step`: 數值步進

#### `/ctrl/get?k=resolution` - 影像解析度
```bash
curl "http://192.168.88.175/ctrl/get?k=resolution"
```
**回應**:
```json
{
  "code": 0,
  "desc": "string",
  "key": "resolution",
  "type": 1,
  "ro": 0,
  "value": "3696x2772 (Low Noise)",
  "opts": [
    "C4K 2.4:1",
    "4K (Low Noise)",
    "4K",
    "4K 2.4:1",
    "3696x2772 (Low Noise)",
    "3696x2772",
    "3312x2760",
    "S16 16:9",
    "S16",
    "1920x1080"
  ],
  "all": []
}
```

**可用解析度選項**:
- C4K 2.4:1
- 4K (Low Noise)
- 4K
- 4K 2.4:1
- 3696x2772 (Low Noise) ← 目前設定
- 3696x2772
- 3312x2760
- S16 16:9
- S16
- 1920x1080

#### `/ctrl/get?k=iso` - ISO 感光度
```bash
curl "http://192.168.88.175/ctrl/get?k=iso"
```
**回應**:
```json
{
  "code": 0,
  "desc": "string",
  "key": "iso",
  "type": 1,
  "ro": 0,
  "value": "2500",
  "opts": [
    "Auto", "500", "640", "800", "1000", "1250", "1600", 
    "2000", "2500", "3200", "4000", "5000", "6400", "8000", 
    "10000", "12800", "16000", "20000", "25600", "32000", 
    "40000", "51200", "64000", "80000", "102400"
  ]
}
```

**目前 ISO**: 2500
**可用範圍**: Auto, 500-102400

#### `/ctrl/get?k=wb` - 白平衡設定
```bash
curl "http://192.168.88.175/ctrl/get?k=wb"
```
**回應**:
```json
{
  "code": 0,
  "desc": "string",
  "key": "wb",
  "type": 1,
  "ro": 0,
  "value": "Manual",
  "opts": [
    "Auto", "Manual", "Incandescent", "Cloudy", "D10000",
    "Fluorescent", "Indoor", "Daylight", "Shade", "Expert"
  ]
}
```

**目前設定**: Manual
**可用選項**: Auto, Manual, Incandescent, Cloudy, D10000, Fluorescent, Indoor, Daylight, Shade, Expert

#### `/ctrl/get?k=focus` - 對焦模式
```bash
curl "http://192.168.88.175/ctrl/get?k=focus"
```
**回應**:
```json
{
  "code": 0,
  "desc": "string",
  "key": "focus",
  "type": 1,
  "ro": 1,
  "value": "MF",
  "opts": ["MF", "AF"]
}
```

**目前模式**: MF (手動對焦)
**可用選項**: MF (手動), AF (自動)

## 🔍 監控建議

### 重要監控指標

1. **RTMP 串流狀態**
   - 端點: `/ctrl/rtmp?action=query&index=0`
   - 監控欄位: `status`, `bw`, `autoRestart`
   - 告警條件: status != "busy" 表示串流異常

2. **電池電量**
   - 端點: `/ctrl/get?k=battery`
   - 監控欄位: `value`
   - 告警條件: value < 20 (低電量警告)

3. **攝影機模式**
   - 端點: `/ctrl/mode`
   - 監控欄位: `msg`
   - 預期值: "rec" (錄影模式)

4. **會話狀態**
   - 端點: `/ctrl/session`
   - 監控欄位: `code`
   - 預期值: 0 (正常)

### Zabbix 監控項目建議

```bash
# RTMP 串流狀態
zabbix_get -s 192.168.88.175 -k zcam.rtmp.status

# 電池電量
zabbix_get -s 192.168.88.175 -k zcam.battery.level

# 串流頻寬
zabbix_get -s 192.168.88.175 -k zcam.rtmp.bandwidth
```

## ❌ 不支援的參數

以下參數經測試後不被此 ZCAM 設備支援:
- `model` - 攝影機型號
- `fw_version` - 韌體版本
- `temperature` - 溫度
- `storage` - 儲存空間
- `rec_state` - 錄影狀態
- `fps` - 幀率
- `bitrate` - 位元率

## 🛠️ 使用範例

### 監控腳本範例
```bash
#!/bin/bash
ZCAM_IP="192.168.88.175"

# 檢查 RTMP 狀態
rtmp_status=$(curl -s "http://${ZCAM_IP}/ctrl/rtmp?action=query&index=0" | jq -r '.status')
echo "RTMP Status: $rtmp_status"

# 檢查電池電量
battery_level=$(curl -s "http://${ZCAM_IP}/ctrl/get?k=battery" | jq -r '.value')
echo "Battery Level: ${battery_level}%"

# 檢查攝影機模式
camera_mode=$(curl -s "http://${ZCAM_IP}/ctrl/mode" | jq -r '.msg')
echo "Camera Mode: $camera_mode"
```

## 📊 API 回應代碼

- `code: 0` - 成功
- `code: -1` - 參數不支援或錯誤
- 空回應 - 端點不存在或網路問題

## 🔧 故障排除

1. **連線超時**: 檢查網路連通性和設備狀態
2. **code: -1**: 參數不被此設備型號支援
3. **空回應**: API 端點不存在或設備離線

---

**建立日期**: 2025-09-19  
**最後更新**: 2025-09-19  
**測試設備**: ZCAM (192.168.88.175)
