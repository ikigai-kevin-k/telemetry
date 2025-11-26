# Grafana 從 Line 欄位提取 JSON 欄位指南

## 目標

從 Line 欄位中的 JSON 字串提取 `datetime` 和 `message` 欄位，並只顯示這兩個欄位。

**原始資料**：
```json
{"log_file": "self-test-2api.log", "date": "2025-11-10", "time": "14:34:38.793", "datetime": "2025-11-10 14:34:38.793", "message": "*X;6;178;13;0;001;0"}
```

**目標顯示**：
- `datetime`: 2025-11-10 14:34:38.793
- `message`: *X;6;178;13;0;001;0

## 方法一：使用 JSON Extract Transform（推薦）

### 步驟 1: 修改 Loki 查詢

在查詢中加入 `| json` 來解析 JSON：

**原始查詢**：
```
{job="vip_roulette_sensor_errors"} |= ``
```

**修改後的查詢**：
```
{job="vip_roulette_sensor_errors"} | json
```

### 步驟 2: 添加 JSON Extract Transform

1. **進入 Edit Panel 模式**
   - 點擊 panel 標題旁的 **...** 選單
   - 選擇 **Edit**

2. **添加 Transform**
   - 點擊 **Transform** 標籤
   - 點擊 **+ Transform**
   - 選擇 **Extract fields**

3. **配置 Extract fields**
   - **Source**: 選擇 `A Line`（或 `Line`）
   - **Format**: 選擇 `JSON`
   - **JSON Path**: 留空（會自動解析所有 JSON 欄位）

4. **確認欄位提取**
   - 點擊 **Apply**
   - 檢查表格是否出現 `datetime` 和 `message` 欄位

### 步驟 3: 使用 Organize fields 只顯示需要的欄位

1. **添加 Organize fields Transform**
   - 點擊 **+ Transform**
   - 選擇 **Organize fields**

2. **配置欄位顯示**
   - 在 **Exclude by name** 中，勾選所有不需要的欄位：
     - `log_file`
     - `date`
     - `time`
     - `labels`
     - `Time`
     - `tsNs`
     - `id`
     - `Line`（如果還存在）
   
   - 確保 `datetime` 和 `message` **沒有**被勾選

3. **重新命名欄位（可選）**
   - 在 **Rename by name** 中：
     - `datetime` → `DateTime`
     - `message` → `Message`

### 步驟 4: 儲存設定

點擊右上角的 **Apply** 或 **Save**

## 方法二：使用 LogQL 查詢層面解析（進階）

### 修改查詢語法

在 Loki 查詢中使用 `| json` 和 `| line_format`：

```
{job="vip_roulette_sensor_errors"} | json | line_format "datetime: {{.datetime}}, message: {{.message}}"
```

然後使用 **Extract fields** transform 來提取這些欄位。

## 方法三：使用 Regex Extract（如果 JSON Extract 不可用）

### 步驟 1: 添加 Extract fields Transform

1. **點擊 + Transform**
2. **選擇 Extract fields**
3. **配置**：
   - **Source**: `A Line`
   - **Format**: `Regex`
   - **Regex**: 
     ```
     "datetime":\s*"(?P<datetime>[^"]+)"[^}]*"message":\s*"(?P<message>[^"]+)"
     ```

### 步驟 2: 使用 Organize fields

按照方法一的步驟 3 來只顯示 `datetime` 和 `message` 欄位。

## 完整 Transform 設定順序

建議的 Transform 順序：

1. **Extract fields** (JSON) - 從 Line 欄位提取 JSON 欄位
2. **Organize fields** - 隱藏不需要的欄位，只保留 datetime 和 message

## JSON 格式的 Transform 設定

如果使用 JSON Extract，Transform 設定應該類似：

```json
{
  "transformations": [
    {
      "id": "extractFields",
      "options": {
        "source": "A Line",
        "format": "json"
      }
    },
    {
      "id": "organize",
      "options": {
        "excludeByName": {
          "log_file": true,
          "date": true,
          "time": true,
          "labels": true,
          "Time": true,
          "tsNs": true,
          "id": true,
          "Line": true
        },
        "renameByName": {
          "datetime": "DateTime",
          "message": "Message"
        }
      }
    }
  ]
}
```

## 在 UI 中設定的詳細步驟

### 1. 修改查詢

在 **Query** 標籤中：
- 找到查詢編輯器
- 將查詢改為：`{job="vip_roulette_sensor_errors"} | json`
- 點擊 **Run queries**

### 2. 添加 Extract fields Transform

在 **Transform** 標籤中：
1. 點擊 **+ Transform**
2. 選擇 **Extract fields**
3. 設定：
   - **Source**: `A Line`
   - **Format**: `JSON`（如果可用）或 `Auto`
4. 點擊 **Apply**

### 3. 檢查欄位

確認表格中出現：
- `datetime` 欄位
- `message` 欄位
- 以及其他 JSON 欄位（log_file, date, time 等）

### 4. 添加 Organize fields Transform

1. 點擊 **+ Transform**
2. 選擇 **Organize fields**
3. 在 **Exclude by name** 中勾選：
   - `log_file`
   - `date`
   - `time`
   - `labels`
   - `Time`
   - `tsNs`
   - `id`
   - `Line`
4. 確認 `datetime` 和 `message` 沒有被勾選
5. 點擊 **Apply**

### 5. 驗證結果

表格應該只顯示：
- `datetime` 欄位
- `message` 欄位

## 疑難排解

### 問題 1: Extract fields 沒有 JSON 選項

**解決方案**：
- 使用 **Auto** 格式
- 或使用 **Regex** 格式配合正則表達式

### 問題 2: 欄位沒有被提取

**解決方案**：
1. 確認查詢中有 `| json`
2. 確認 Line 欄位包含有效的 JSON
3. 檢查 Transform 的 Source 是否選擇正確

### 問題 3: 仍然顯示其他欄位

**解決方案**：
1. 檢查 Organize fields transform 的 Exclude 設定
2. 確認所有不需要的欄位都已勾選
3. 檢查 Transform 的執行順序

## 預期結果

設定完成後，Table panel 應該：
- ✅ 只顯示 `datetime` 和 `message` 兩個欄位
- ✅ `datetime` 顯示：2025-11-10 14:34:38.793
- ✅ `message` 顯示：*X;6;178;13;0;001;0
- ❌ 不顯示其他欄位（log_file, date, time, labels, Time, tsNs, id, Line）

## 相關檔案

- `grafana/provisioning/dashboards/general/error_event.json` - Dashboard JSON
- `grafana-hide-table-columns-guide.md` - 隱藏欄位指南









