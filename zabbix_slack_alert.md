# Zabbix Slack 警告設定完整指南

## 📋 概述

本文檔詳細說明如何在 Zabbix Web GUI 中設定 Slack 警告通知功能。透過 Webhook 整合，當監控數值超過門檻值時，系統會自動發送格式化的警告訊息到指定的 Slack 頻道。

## 🎯 功能特色

- ✅ 即時 Slack 通知
- ✅ 豐富的訊息格式
- ✅ 支援多個頻道
- ✅ 自動恢復通知
- ✅ 可自訂訊息模板
- ✅ 支援不同嚴重程度分級

## 📋 前置需求

- Zabbix Server 6.0+ 已正常運作
- Slack 工作區管理員權限
- 網路連線可訪問 Slack API
- 已配置要監控的主機和觸發器

## 🚀 設定步驟

### 第一步：建立 Slack Webhook URL

#### 1.1 在 Slack 中建立 Incoming Webhook

1. **登入 Slack 工作區**
   - 前往您的 Slack 工作區
   - 確保您有管理員權限

2. **建立 Slack App**
   - 前往 https://api.slack.com/apps
   - 點擊 **"Create New App"**
   - 選擇 **"From scratch"**
   - 輸入 App 名稱：`Zabbix Alerts`
   - 選擇您的工作區

3. **啟用 Incoming Webhooks**
   - 在 App 設定頁面，點擊左側選單的 **"Incoming Webhooks"**
   - 將 **"Activate Incoming Webhooks"** 切換為 **On**
   - 點擊 **"Add New Webhook to Workspace"**
   - 選擇要接收警告的頻道 (例如：#alerts 或 #monitoring)
   - 點擊 **"Allow"**

4. **複製 Webhook URL**
   - 複製生成的 Webhook URL，格式如下：
   ```
   https://hooks.slack.com/services/T00000000/B00000000/XXXXXXXXXXXXXXXXXXXXXXXX
   ```
   - **重要**: 請妥善保管此 URL，不要公開分享

#### 1.2 測試 Webhook (可選)

使用 curl 測試 Webhook 是否正常：
```bash
curl -X POST -H 'Content-type: application/json' \
--data '{"text":"Hello from Zabbix! Webhook test successful."}' \
YOUR_WEBHOOK_URL
```

### 第二步：在 Zabbix 中建立 Slack Media Type

#### 2.1 進入媒體類型設定

1. **登入 Zabbix Web 介面**
   - 開啟瀏覽器前往您的 Zabbix Web 介面
   - 使用管理員帳號登入

2. **進入媒體類型設定**
   - 點擊主選單 **"Administration"** (管理)
   - 選擇 **"Media types"** (媒體類型)
   - 點擊右上角 **"Create media type"** (建立媒體類型)

#### 2.2 設定 Slack Media Type

**基本設定：**
- **Name**: `Slack`
- **Type**: `Webhook`
- **Webhook URL**: 留空 (將在參數中設定)

**參數設定：**
點擊 **"Parameters"** 標籤，新增以下參數：

| Name | Value |
|------|-------|
| `HTTPProxy` | `{ALERT.SENDTO}` |
| `Message` | `{ALERT.MESSAGE}` |
| `Subject` | `{ALERT.SUBJECT}` |
| `To` | `{ALERT.SENDTO}` |

**腳本設定：**
在 **"Script"** 欄位中，輸入以下 JavaScript 代碼：

```javascript
var Slack = {
    to: null,
    message: null,
    proxy: null,

    sendMessage: function () {
        var params = {
            channel: Slack.to,
            text: Slack.message
        },
        data,
        response,
        request = new CurlHttpRequest(),
        url = params.HTTPProxy;

        if (typeof params.HTTPProxy === 'string' && params.HTTPProxy.trim() !== '') {
            request.setProxy(params.HTTPProxy);
        }

        if (typeof params.To === 'undefined') {
            throw 'Incorrect webhook URL given: ' + params.HTTPProxy;
        }

        data = JSON.stringify({
            channel: params.channel,
            text: params.text,
            parse: 'full',
            link_names: true,
            unfurl_links: true,
            unfurl_media: true
        });

        Zabbix.Log(4, '[Slack Webhook] URL: ' + url);
        Zabbix.Log(4, '[Slack Webhook] data: ' + data);

        request.AddHeader('Content-Type: application/json');
        response = request.Post(url, data);

        Zabbix.Log(4, '[Slack Webhook] HTTP code: ' + request.Status());

        try {
            response = JSON.parse(response);
        }
        catch (error) {
            response = null;
        }

        if (request.Status() !== 200 || !response || response.ok !== true) {
            if (typeof response.error === 'string') {
                throw response.error;
            }
            else {
                throw 'Unknown error. Check debug log for more information.';
            }
        }
    }
};

try {
    var params = JSON.parse(value);

    if (typeof params.Subject === 'string') {
        Slack.message = params.Subject;
    }

    if (typeof params.Message === 'string') {
        Slack.message += (Slack.message.trim() !== '') ? '\n' + params.Message : params.Message;
    }

    if (typeof params.To === 'string') {
        Slack.to = params.To;
    }

    if (typeof params.HTTPProxy === 'string') {
        Slack.proxy = params.HTTPProxy;
    }

    Slack.sendMessage();

    return 'OK';
}
catch (error) {
    Zabbix.Log(4, '[Slack Webhook] notification failed: ' + error);
    throw 'Sending failed: ' + error + '.';
}
```

**簡化版腳本 (建議新手使用)：**
如果上述腳本太複雜，可以使用這個簡化版本：

```javascript
var req = new CurlHttpRequest();
var params = JSON.parse(value);

var payload = JSON.stringify({
    text: params.Subject + '\n' + params.Message
});

req.AddHeader('Content-Type: application/json');
var resp = req.Post(params.To, payload);

if (req.Status() != 200) {
    throw 'Response code: ' + req.Status() + '\nResponse: ' + resp;
}

return 'OK';
```

#### 2.3 設定訊息模板

點擊 **"Message templates"** 標籤，設定不同事件類型的模板：

**Problem (問題) 模板：**
- **Message type**: `Problem`
- **Subject**: `🚨 Zabbix Alert: {EVENT.NAME}`
- **Message**:
```
🚨 **ZABBIX ALERT** 🚨

**Problem**: {EVENT.NAME}
**Host**: {HOST.NAME} ({HOST.IP})
**Severity**: {EVENT.SEVERITY}
**Time**: {EVENT.DATE} {EVENT.TIME}

**Details**:
• **Trigger**: {TRIGGER.NAME}
• **Item**: {ITEM.NAME}
• **Current Value**: {ITEM.LASTVALUE}
• **Trigger Status**: {TRIGGER.STATUS}

**Operational Data**: {EVENT.OPDATA}
**Event ID**: {EVENT.ID}

🔗 **Dashboard**: {TRIGGER.URL}
📊 **View Details**: http://your-zabbix-server:8080/tr_events.php?triggerid={TRIGGER.ID}
```

**Problem recovery (問題恢復) 模板：**
- **Message type**: `Problem recovery`
- **Subject**: `✅ Resolved: {EVENT.NAME}`
- **Message**:
```
✅ **PROBLEM RESOLVED** ✅

**Problem**: {EVENT.NAME}
**Host**: {HOST.NAME} ({HOST.IP})
**Severity**: {EVENT.SEVERITY}
**Duration**: {EVENT.DURATION}
**Resolved**: {EVENT.RECOVERY.DATE} {EVENT.RECOVERY.TIME}

**Details**:
• **Trigger**: {TRIGGER.NAME}
• **Current Value**: {ITEM.LASTVALUE}
• **Status**: {TRIGGER.STATUS}

**Event ID**: {EVENT.ID}
```

**Problem update (問題更新) 模板：**
- **Message type**: `Problem update`
- **Subject**: `ℹ️ Updated: {EVENT.NAME}`
- **Message**:
```
ℹ️ **PROBLEM UPDATED** ℹ️

**Problem**: {EVENT.NAME}
**Host**: {HOST.NAME}
**Update**: {EVENT.UPDATE.MESSAGE}
**Updated by**: {USER.FULLNAME}
**Time**: {EVENT.UPDATE.DATE} {EVENT.UPDATE.TIME}
```

3. **儲存設定**
   - 點擊 **"Add"** 儲存媒體類型

### 第三步：為使用者添加 Slack 媒體設定

#### 3.1 配置使用者媒體

1. **進入使用者管理**
   - 點擊 **"Administration"** → **"Users"** (使用者)
   - 點擊要設定的使用者 (例如：**"Admin"**)

2. **添加 Slack 媒體**
   - 切換到 **"Media"** (媒體) 標籤
   - 點擊 **"Add"** 新增媒體

**媒體設定：**
- **Type**: 選擇剛才建立的 `Slack`
- **Send to**: 輸入您的 Slack Webhook URL
  ```
  https://hooks.slack.com/services/T00000000/B00000000/XXXXXXXXXXXXXXXXXXXXXXXX
  ```
- **When active**: `1-7,00:00-24:00` (全週 24 小時)
- **Use if severity**: 選擇要接收的嚴重程度
  - ✅ Not classified
  - ✅ Information
  - ✅ Warning  
  - ✅ Average
  - ✅ High
  - ✅ Disaster

3. **儲存設定**
   - 點擊 **"Add"** 新增媒體
   - 點擊 **"Update"** 儲存使用者設定

#### 3.2 為多個使用者設定 (可選)

重複上述步驟為其他需要接收通知的使用者添加 Slack 媒體設定。

### 第四步：建立或修改 Actions 使用 Slack

#### 4.1 建立新的 Slack Action

1. **進入動作設定**
   - 點擊 **"Configuration"** → **"Actions"**
   - 確認 **"Event source"** 設為 **"Triggers"**
   - 點擊 **"Create action"** (建立動作)

#### 4.2 設定動作基本資訊

**動作設定：**
- **Name**: `Slack Alert for Resource Issues`
- **Event source**: `Triggers`

#### 4.3 設定動作條件

點擊 **"Conditions"** 標籤，新增條件：

**基本條件：**
- **Type**: `Trigger severity`
- **Operator**: `>=`
- **Value**: `Warning`

**進階條件 (可選)：**
可以添加更多條件來精確控制何時發送通知：

| Type | Operator | Value | 說明 |
|------|----------|-------|------|
| Host group | equals | Linux servers | 只針對特定主機群組 |
| Trigger name | like | CPU\|Memory\|Disk | 只針對特定觸發器 |
| Time period | in | 1-5,09:00-18:00 | 只在工作時間發送 |

#### 4.4 設定動作操作

點擊 **"Operations"** 標籤，新增操作：

**Slack 通知操作：**
- **Operation type**: `Send message`
- **Send to users**: 選擇設定了 Slack 媒體的使用者
- **Send only to**: `Slack`
- **Custom message**: 啟用 (如果要自訂訊息)

**操作步驟設定：**
- **Step duration**: `0` (立即執行)
- **Step start from**: `1`
- **Step end at**: `1`

**自訂訊息 (可選)：**
如果啟用自訂訊息，可以設定：
- **Subject**: `🚨 {HOST.NAME}: {EVENT.NAME}`
- **Message**: 使用前面設定的模板內容

#### 4.5 設定恢復操作

點擊 **"Recovery operations"** 標籤，新增恢復操作：

**恢復通知：**
- **Operation type**: `Send message`
- **Send to users**: 選擇相同使用者
- **Send only to**: `Slack`

#### 4.6 設定更新操作 (可選)

點擊 **"Update operations"** 標籤，設定問題更新通知：

**更新通知：**
- **Operation type**: `Send message`
- **Send to users**: 選擇相同使用者
- **Send only to**: `Slack`

4. **儲存動作**
   - 點擊 **"Add"** 儲存動作

### 第五步：測試和驗證

#### 5.1 測試媒體類型

1. **直接測試 Slack 媒體類型**
   - 前往 **"Administration"** → **"Media types"**
   - 點擊您建立的 **"Slack"** 媒體類型
   - 點擊 **"Test"** 按鈕

2. **填入測試參數**
   - **To**: 輸入您的 Slack Webhook URL
   - **Subject**: `Zabbix Test Alert`
   - **Message**: `This is a test message from Zabbix to verify Slack integration is working correctly.`
   - 點擊 **"Test"** 發送測試訊息

3. **檢查測試結果**
   - 如果成功，會顯示 "Media type test successful"
   - 如果失敗，會顯示錯誤訊息

#### 5.2 檢查 Slack 頻道

1. **前往 Slack 頻道**
   - 打開您設定接收通知的 Slack 頻道
   - 確認是否收到測試訊息

2. **驗證訊息格式**
   - 檢查訊息是否正確顯示
   - 確認格式是否符合預期

#### 5.3 觸發實際警告測試

**方法 1: 調整觸發器門檻值**
1. 前往 **"Configuration"** → **"Hosts"** → **"Triggers"**
2. 選擇一個現有觸發器 (如 CPU 使用率)
3. 暫時降低門檻值 (例如從 80% 改為 10%)
4. 等待觸發器啟動
5. 檢查 Slack 是否收到警告
6. 將門檻值改回正常值

**方法 2: 製造高負載**
1. 在被監控的主機上執行：
   ```bash
   # 製造 CPU 負載
   stress --cpu 4 --timeout 300s
   
   # 或使用 dd 製造 I/O 負載
   dd if=/dev/zero of=/tmp/testfile bs=1M count=1000
   ```
2. 觀察觸發器是否被啟動
3. 檢查 Slack 通知

**方法 3: 手動觸發問題**
1. 前往 **"Monitoring"** → **"Problems"**
2. 找到現有問題或等待新問題出現
3. 檢查是否收到 Slack 通知

#### 5.4 驗證恢復通知

1. **等待問題自然恢復**
   - 停止負載測試
   - 等待系統恢復正常

2. **檢查恢復通知**
   - 確認 Slack 收到恢復通知
   - 驗證恢復訊息格式正確

#### 5.5 檢查日誌

如果遇到問題，檢查以下日誌：

```bash
# Zabbix Server 日誌
tail -f /var/log/zabbix/zabbix_server.log | grep -i slack

# 檢查 Webhook 相關錯誤
grep -i "webhook\|slack" /var/log/zabbix/zabbix_server.log

# 檢查系統日誌
journalctl -u zabbix-server -f
```

## 🔧 進階設定和自訂

### 自訂 Slack 訊息格式

#### 使用 Slack Block Kit

建立更豐富的視覺化訊息格式：

```javascript
// 在 Media Type 腳本中使用
var payload = JSON.stringify({
    "blocks": [
        {
            "type": "header",
            "text": {
                "type": "plain_text",
                "text": "🚨 Zabbix Alert"
            }
        },
        {
            "type": "section",
            "fields": [
                {
                    "type": "mrkdwn",
                    "text": "*Problem:*\n" + params.Subject
                },
                {
                    "type": "mrkdwn",
                    "text": "*Host:*\n{HOST.NAME}"
                },
                {
                    "type": "mrkdwn",
                    "text": "*Severity:*\n{EVENT.SEVERITY}"
                },
                {
                    "type": "mrkdwn",
                    "text": "*Time:*\n{EVENT.DATE} {EVENT.TIME}"
                }
            ]
        },
        {
            "type": "section",
            "text": {
                "type": "mrkdwn",
                "text": params.Message
            }
        },
        {
            "type": "actions",
            "elements": [
                {
                    "type": "button",
                    "text": {
                        "type": "plain_text",
                        "text": "View Dashboard"
                    },
                    "url": "{TRIGGER.URL}",
                    "style": "danger"
                }
            ]
        }
    ]
});
```

#### 添加顏色和圖示

根據嚴重程度使用不同顏色：

```javascript
var severityColors = {
    'Not classified': '#97AAB3',
    'Information': '#7499FF',
    'Warning': '#FFC859',
    'Average': '#FFA059',
    'High': '#E97659',
    'Disaster': '#E45959'
};

var severityIcons = {
    'Not classified': '⚪',
    'Information': '🔵',
    'Warning': '🟡',
    'Average': '🟠',
    'High': '🔴',
    'Disaster': '💥'
};
```

### 設定多個 Slack 頻道

#### 建立不同嚴重程度的頻道

1. **建立多個 Media Types**
   - `Slack-Critical`: 用於 High 和 Disaster 級別
   - `Slack-Warning`: 用於 Warning 和 Average 級別
   - `Slack-Info`: 用於 Information 級別

2. **設定不同的 Webhook URLs**
   - 每個 Media Type 使用不同頻道的 Webhook URL

3. **在 Actions 中設定條件**
   - 根據 `Trigger severity` 發送到對應的媒體類型

#### 範例：多頻道設定

```bash
# Critical 頻道 (#alerts-critical)
Webhook URL: https://hooks.slack.com/services/T00000000/B00000001/XXXXXXXXXXXXXXXXXXXXXXXX

# Warning 頻道 (#alerts-warning)  
Webhook URL: https://hooks.slack.com/services/T00000000/B00000002/YYYYYYYYYYYYYYYYYYYYYYYY

# Info 頻道 (#alerts-info)
Webhook URL: https://hooks.slack.com/services/T00000000/B00000003/ZZZZZZZZZZZZZZZZZZZZZZZZ
```

### 整合使用者提及

在訊息中提及特定使用者：

```
<@U1234567890> 請注意此嚴重警告！
<@channel> 系統出現問題，需要立即處理。
```

### 設定工作時間通知

在 Actions 條件中添加時間限制：

```
Type: Time period
Operator: in
Value: 1-5,09:00-18:00  # 週一到週五，上午9點到下午6點
```

### 整合其他 Slack 功能

#### 使用 Slack Workflow

1. 建立 Slack Workflow 處理 Zabbix 通知
2. 自動建立事件追蹤
3. 分配責任人員

#### 整合 Slack Bot

1. 建立互動式 Slack Bot
2. 提供問題確認和處理功能
3. 查詢系統狀態

## 🛠️ 故障排除

### 常見問題和解決方案

#### 1. Slack 沒有收到訊息

**可能原因和解決方案：**

**檢查 Webhook URL**
```bash
# 測試 Webhook URL 是否有效
curl -X POST -H 'Content-type: application/json' \
--data '{"text":"Test from command line"}' \
YOUR_WEBHOOK_URL
```

**檢查 Zabbix 日誌**
```bash
# 查看詳細錯誤訊息
tail -f /var/log/zabbix/zabbix_server.log | grep -i "slack\|webhook\|media"

# 增加日誌詳細程度
# 在 zabbix_server.conf 中設定：
# DebugLevel=4
```

**檢查網路連線**
```bash
# 測試 Zabbix Server 到 Slack API 的連線
telnet hooks.slack.com 443

# 檢查 DNS 解析
nslookup hooks.slack.com

# 檢查防火牆
iptables -L | grep -i drop
```

**檢查 Slack App 權限**
- 確認 App 有 `incoming-webhook` 權限
- 檢查 App 是否已安裝到工作區
- 確認頻道允許機器人發送訊息

#### 2. 訊息格式錯誤

**JSON 格式錯誤**
```javascript
// 使用 JSON.stringify() 確保格式正確
var payload = JSON.stringify({
    text: message,
    channel: channel
});

// 檢查特殊字元轉義
message = message.replace(/"/g, '\\"');
```

**字元編碼問題**
```bash
# 確保 Zabbix 使用 UTF-8 編碼
# 在 zabbix_server.conf 中：
# DBCharacterSet=utf8
```

**Slack 格式限制**
- 訊息長度不能超過 4000 字元
- Block Kit 元素數量有限制
- 某些 HTML 標籤不支援

#### 3. 權限和認證問題

**Slack App 權限不足**
1. 前往 Slack App 設定頁面
2. 檢查 **OAuth & Permissions** 設定
3. 確認有以下權限：
   - `incoming-webhook`
   - `chat:write`

**工作區權限設定**
1. 檢查工作區的 App 安裝政策
2. 確認頻道設定允許機器人
3. 檢查使用者權限

#### 4. 效能和頻率問題

**訊息發送頻率限制**
```bash
# Slack API 有頻率限制 (1 message per second per channel)
# 在 Actions 中設定適當的延遲
```

**大量警告處理**
1. 使用 Action 條件過濾不必要的通知
2. 設定適當的觸發器恢復條件
3. 使用維護模式避免維護期間的通知

#### 5. 測試和調試技巧

**段階式測試**
1. 先測試 Webhook URL (使用 curl)
2. 再測試 Media Type (使用 Test 功能)
3. 然後測試完整的 Action 流程
4. 最後測試實際觸發器

**日誌分析**
```bash
# 啟用詳細日誌
echo "DebugLevel=4" >> /etc/zabbix/zabbix_server.conf
systemctl restart zabbix-server

# 監控即時日誌
tail -f /var/log/zabbix/zabbix_server.log | grep -E "(slack|webhook|media|alert)"

# 分析錯誤模式
grep -i error /var/log/zabbix/zabbix_server.log | grep -i slack
```

**網路診斷**
```bash
# 檢查 HTTPS 連線
openssl s_client -connect hooks.slack.com:443

# 檢查代理設定
echo $https_proxy
echo $http_proxy

# 測試 DNS 解析
dig hooks.slack.com
```

### 效能優化建議

#### 1. 減少不必要的通知

**設定智慧過濾條件**
```sql
-- 只在工作時間發送非緊急通知
Time period: 1-5,09:00-18:00 AND Trigger severity < High

-- 避免重複通知相同問題
Problem event generation mode: Single
```

**使用維護模式**
1. 設定定期維護視窗
2. 在維護期間暫停通知
3. 使用標籤過濾維護中的主機

#### 2. 優化訊息內容

**精簡訊息格式**
- 只包含必要資訊
- 使用縮寫和符號
- 限制訊息長度

**批次處理**
- 將多個相關警告合併
- 使用摘要格式
- 定期發送狀態報告

## 📊 監控和報告

### 通知統計

定期檢查通知效果：

```sql
-- 檢查最近 24 小時的通知統計
SELECT 
    mt.name as media_type,
    COUNT(*) as notification_count,
    AVG(a.esc_step) as avg_escalation_step
FROM alerts a
JOIN media_type mt ON a.mediatypeid = mt.mediatypeid
WHERE a.clock > UNIX_TIMESTAMP(DATE_SUB(NOW(), INTERVAL 24 HOUR))
GROUP BY mt.name;
```

### 建立通知儀表板

在 Zabbix 中建立專門的通知監控：

1. **通知成功率圖表**
2. **通知延遲統計**
3. **最常觸發的警告**
4. **使用者回應時間**

## 📚 相關資源

### 官方文檔
- [Zabbix Media Types](https://www.zabbix.com/documentation/current/manual/config/notifications/media)
- [Slack Incoming Webhooks](https://api.slack.com/messaging/webhooks)
- [Slack Block Kit](https://api.slack.com/block-kit)

### 實用工具
- [Slack Block Kit Builder](https://app.slack.com/block-kit-builder)
- [JSON Formatter](https://jsonformatter.org/)
- [Webhook Testing Tools](https://webhook.site/)

### 社群資源
- [Zabbix Community Templates](https://git.zabbix.com/projects/ZT)
- [Slack App Directory](https://slack.com/apps)

## 📝 版本資訊和更新日誌

- **建立日期**: 2025-09-17
- **適用版本**: Zabbix 6.0+, Slack API v1
- **最後更新**: 2025-09-17
- **作者**: System Administrator

### 更新日誌
- **v1.0** (2025-09-17): 初始版本，包含完整設定指南
- 未來更新將包含更多進階功能和最佳實務

---

**重要提醒**: 
1. 請妥善保管 Slack Webhook URL，不要將其公開或提交到版本控制系統
2. 定期檢查和更新 Slack App 權限
3. 建議在測試環境中完整驗證所有設定後再部署到正式環境
4. 考慮設定備用通知方式 (如 Email) 以防 Slack 服務中斷

## 🔐 安全性考量

### Webhook URL 保護
- 使用環境變數儲存敏感資訊
- 定期輪換 Webhook URL
- 限制網路訪問權限
- 監控異常使用情況

### 資料隱私
- 避免在通知中包含敏感資料
- 使用適當的頻道權限設定
- 考慮資料保留政策
- 遵守相關法規要求

這份完整指南涵蓋了 Zabbix Slack 整合的所有面向，從基本設定到進階功能，以及故障排除和最佳實務。請根據您的實際需求調整相關設定。
