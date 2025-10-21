# Zabbix Email 警告設定完整指南

## 📋 概述

本文檔詳細說明如何在 Zabbix Web GUI 中設定圖表數據門檻值的 Email 警告功能。透過觸發器 (Triggers) 和動作 (Actions) 的配置，當監控數值超過或低於設定門檻值時，系統會自動發送 Email 警告通知。

## 🎯 功能特色

- ✅ 監控任何數據項目的門檻值
- ✅ 支援多種嚴重程度等級
- ✅ 自動發送 Email 警告通知
- ✅ 可設定恢復通知
- ✅ 支援多種觸發條件

## 📋 前置需求

- Zabbix Server 已正常運作
- SMTP 郵件伺服器可用
- 管理員權限帳號
- 已配置要監控的主機和項目

## 🚀 設定步驟

### 第一步：登入 Zabbix Web 介面

1. 開啟瀏覽器，前往您的 Zabbix Web 介面
   - 預設網址：`http://YOUR_ZABBIX_SERVER:8080`
2. 使用管理員帳號登入
   - 預設帳號：`Admin`
   - 預設密碼：`zabbix`

### 第二步：配置媒體類型 (Media Types)

#### 2.1 設定 Email 媒體類型

1. 在主選單中，點擊 **"Administration"** (管理) → **"Media types"** (媒體類型)
2. 點擊現有的 **"Email"** 項目進行編輯，或點擊 **"Create media type"** 建立新的
3. 配置 Email 設定：

**基本設定：**
- **Name**: `Zabbix Alarm Email` (或您偏好的名稱)
- **Type**: `Email`

**SMTP 伺服器設定：**
```
SMTP server: your-smtp-server.com
SMTP server port: 587 (或 25, 465)
SMTP helo: your-domain.com
SMTP email: zabbix-alarm@your-domain.com
Connection security: STARTTLS (建議)
Authentication: Normal password
Username: your-smtp-username
Password: your-smtp-password
```

**訊息格式設定：**
- **Subject**: `{ALERT.SUBJECT}`
- **Message**: 
```
Alert: {ALERT.SUBJECT}

Host: {HOST.NAME}
Trigger: {TRIGGER.NAME}
Status: {TRIGGER.STATUS}
Severity: {TRIGGER.SEVERITY}
Time: {EVENT.DATE} {EVENT.TIME}
Item: {ITEM.NAME}
Value: {ITEM.LASTVALUE}

Details: {TRIGGER.URL}
```

4. 點擊 **"Test"** 測試連線
5. 點擊 **"Add"** 或 **"Update"** 儲存設定

### 第三步：為使用者添加媒體

#### 3.1 配置管理員使用者

1. 前往 **"Administration"** → **"Users"** (使用者)
2. 點擊 **"Admin"** 使用者 (或您要接收警告的使用者)
3. 切換到 **"Media"** (媒體) 標籤
4. 點擊 **"Add"** 新增媒體

**媒體設定：**
- **Type**: 選擇剛才設定的 `Zabbix Alarm Email`
- **Send to**: 輸入接收警告的 Email 地址
- **When active**: `1-7,00:00-24:00` (全週 24 小時)
- **Use if severity**: 選擇要接收的嚴重程度等級
  - ✅ Information
  - ✅ Warning  
  - ✅ Average
  - ✅ High
  - ✅ Disaster

5. 點擊 **"Add"** 儲存媒體設定
6. 點擊 **"Update"** 儲存使用者設定

### 第四步：建立觸發器 (Triggers)

#### 4.1 進入觸發器設定

1. 在主選單中，點擊 **"Configuration"** (配置) → **"Hosts"** (主機)
2. 找到您要設定警告的主機
3. 點擊該主機右側的 **"Triggers"** (觸發器) 連結
4. 點擊 **"Create trigger"** (建立觸發器)

#### 4.2 設定觸發器 - CPU 使用率警告

**基本設定：**
- **Name**: `High CPU Usage - {HOST.NAME}`
- **Severity**: `Warning` (警告)
- **Expression**: 點擊 **"Add"** 按鈕設定

**表達式設定：**
- **Item**: 選擇 `CPU utilization` 或 `system.cpu.util`
- **Function**: `last`
- **Last of (T)**: `#1` (最新值)
- **Result**: `> 80` (超過 80%)

**完整表達式範例：**
```
last(/HOST_NAME/system.cpu.util)>80
```

**進階設定：**
- **OK event generation**: `Recovery expression`
- **Recovery expression**: `last(/HOST_NAME/system.cpu.util)<=75`
- **Problem event generation mode**: `Single`
- **OK event closes**: `All problems`

**描述：**
```
CPU usage is above 80% on {HOST.NAME}
Current value: {ITEM.LASTVALUE}%
```

#### 4.3 建立其他觸發器

**記憶體使用率警告：**
- **Name**: `High Memory Usage - {HOST.NAME}`
- **Severity**: `Warning`
- **Expression**: `last(/HOST_NAME/vm.memory.utilization)>80`
- **Recovery expression**: `last(/HOST_NAME/vm.memory.utilization)<=75`

**硬碟使用率警告：**
- **Name**: `High Disk Usage - {HOST.NAME}`
- **Severity**: `Average`
- **Expression**: `last(/HOST_NAME/vfs.fs.size[/,pused])>85`
- **Recovery expression**: `last(/HOST_NAME/vfs.fs.size[/,pused])<=80`

**嚴重 CPU 使用率警告：**
- **Name**: `Critical CPU Usage - {HOST.NAME}`
- **Severity**: `High`
- **Expression**: `last(/HOST_NAME/system.cpu.util)>90`
- **Recovery expression**: `last(/HOST_NAME/system.cpu.util)<=85`

### 第五步：建立動作 (Actions)

#### 5.1 建立警告動作

1. 前往 **"Configuration"** → **"Actions"**
2. 確認 **"Event source"** 設為 **"Triggers"**
3. 點擊 **"Create action"** (建立動作)

**動作設定：**
- **Name**: `Email Alert for High Resource Usage`
- **Event source**: `Triggers`

#### 5.2 設定動作條件 (Conditions)

點擊 **"Conditions"** 標籤，新增以下條件：

**條件 1 - 觸發器嚴重程度：**
- **Type**: `Trigger severity`
- **Operator**: `>=`
- **Value**: `Warning`

**條件 2 - 主機群組 (可選)：**
- **Type**: `Host group`
- **Operator**: `equals`
- **Value**: 選擇相關主機群組

#### 5.3 設定動作操作 (Operations)

點擊 **"Operations"** 標籤，新增操作：

**發送警告操作：**
- **Operation type**: `Send message`
- **Send to users**: 選擇 `Admin` (或其他使用者)
- **Send only to**: `Zabbix Alarm Email`
- **Default subject**: `Problem: {EVENT.NAME}`
- **Default message**:
```
🚨 ZABBIX ALERT 🚨

Problem started at {EVENT.TIME} on {EVENT.DATE}
Problem name: {EVENT.NAME}
Host: {HOST.NAME}
Severity: {EVENT.SEVERITY}
Operational data: {EVENT.OPDATA}
Original problem ID: {EVENT.ID}

Trigger: {TRIGGER.NAME}
Trigger status: {TRIGGER.STATUS}
Trigger severity: {TRIGGER.SEVERITY}
Trigger URL: {TRIGGER.URL}

Item values:
{ITEM.NAME1} ({HOST.NAME1}:{ITEM.KEY1}): {ITEM.VALUE1}

Event acknowledgement history:
{EVENT.ACK.HISTORY}
```

**操作步驟設定：**
- **Step duration**: `0` (立即執行)
- **Step start from**: `1`
- **Step end at**: `1`

#### 5.4 設定恢復操作 (Recovery operations)

點擊 **"Recovery operations"** 標籤：

**恢復通知操作：**
- **Operation type**: `Send message`
- **Send to users**: 選擇 `Admin`
- **Send only to**: `Zabbix Alarm Email`
- **Subject**: `Resolved: {EVENT.NAME}`
- **Message**:
```
✅ ZABBIX RECOVERY ✅

Problem resolved at {EVENT.RECOVERY.TIME} on {EVENT.RECOVERY.DATE}
Problem name: {EVENT.NAME}
Host: {HOST.NAME}
Severity: {EVENT.SEVERITY}
Duration: {EVENT.DURATION}

Trigger: {TRIGGER.NAME}
Trigger status: {TRIGGER.STATUS}

Item values:
{ITEM.NAME1} ({HOST.NAME1}:{ITEM.KEY1}): {ITEM.VALUE1}
```

### 第六步：測試和驗證

#### 6.1 測試觸發器

1. 前往 **"Monitoring"** → **"Problems"** (問題)
2. 觀察是否有觸發器被啟動
3. 檢查 Email 是否正確發送

#### 6.2 手動測試 Email

1. 前往 **"Administration"** → **"Media types"**
2. 點擊您設定的 Email 媒體類型
3. 點擊 **"Test"** 按鈕
4. 填入測試 Email 地址
5. 點擊 **"Test"** 發送測試郵件

#### 6.3 檢查日誌

如果遇到問題，可以檢查以下日誌：
```bash
# Zabbix Server 日誌
tail -f /var/log/zabbix/zabbix_server.log

# 系統郵件日誌
tail -f /var/log/mail.log
```

## 📊 建議的門檻值設定

### 系統資源監控

| 監控項目 | 警告門檻 | 嚴重門檻 | 恢復門檻 |
|---------|---------|---------|---------|
| CPU 使用率 | > 80% | > 90% | <= 75% |
| 記憶體使用率 | > 80% | > 90% | <= 75% |
| 硬碟使用率 | > 80% | > 90% | <= 75% |
| 系統負載 | > 2.0 | > 4.0 | <= 1.5 |
| 系統溫度 | > 70°C | > 80°C | <= 65°C |

### 網路監控

| 監控項目 | 警告門檻 | 嚴重門檻 | 恢復門檻 |
|---------|---------|---------|---------|
| 封包遺失率 | > 5% | > 10% | <= 2% |
| 回應時間 | > 100ms | > 500ms | <= 50ms |
| 頻寬使用率 | > 80% | > 95% | <= 70% |

### 服務監控

| 監控項目 | 警告門檻 | 嚴重門檻 | 恢復門檻 |
|---------|---------|---------|---------|
| 服務可用性 | 離線 | 離線 | 上線 |
| 資料庫連線 | > 80% | > 95% | <= 70% |
| 佇列長度 | > 100 | > 500 | <= 50 |

## 🔧 進階設定

### 避免警告風暴

1. **設定適當的恢復表達式**
   - 使用較低的恢復門檻值避免頻繁觸發
   - 例如：觸發 > 80%，恢復 <= 75%

2. **使用時間延遲**
   ```
   # 持續 5 分鐘超過門檻才觸發
   avg(/HOST_NAME/system.cpu.util,5m)>80
   ```

3. **設定維護模式**
   - 在 **"Configuration"** → **"Maintenance"** 中設定維護時間
   - 維護期間不會發送警告

### 自訂 Email 模板

您可以建立自訂的 Email 模板，包含：
- 公司 Logo 和品牌
- 詳細的故障排除連結
- 相關聯絡人資訊
- 圖表和趨勢連結

### 整合其他通知方式

除了 Email，還可以整合：
- SMS 簡訊通知
- Slack 訊息
- Discord Webhook
- Microsoft Teams
- 自訂 Webhook

## 🛠️ 故障排除

### 常見問題

**1. Email 未收到**
- 檢查 SMTP 設定是否正確
- 確認使用者媒體設定已啟用
- 檢查垃圾郵件資料夾
- 查看 Zabbix Server 日誌

**2. 觸發器未啟動**
- 確認監控項目有資料
- 檢查觸發器表達式語法
- 驗證主機狀態是否正常

**3. 收到太多警告**
- 調整門檻值設定
- 使用時間延遲函數
- 設定適當的恢復條件

**4. SMTP 認證失敗**
- 檢查使用者名稱和密碼
- 確認 SMTP 伺服器支援的認證方式
- 檢查防火牆設定

### 測試指令

```bash
# 測試 SMTP 連線
telnet your-smtp-server.com 587

# 檢查 Zabbix Agent 狀態
systemctl status zabbix-agent

# 檢查 Zabbix Server 狀態  
systemctl status zabbix-server

# 測試觸發器表達式
zabbix_server -R config_cache_reload
```

## 📚 相關文檔

- [Zabbix 官方文檔 - Triggers](https://www.zabbix.com/documentation/current/manual/config/triggers)
- [Zabbix 官方文檔 - Actions](https://www.zabbix.com/documentation/current/manual/config/notifications/action)
- [Zabbix 官方文檔 - Media Types](https://www.zabbix.com/documentation/current/manual/config/notifications/media)

## 📝 版本資訊

- **建立日期**: 2025-09-17
- **適用版本**: Zabbix 6.0+
- **最後更新**: 2025-09-17
- **作者**: System Administrator

---

**注意**: 請根據您的實際環境調整 SMTP 設定和門檻值。建議在正式環境部署前先在測試環境中驗證所有設定。
