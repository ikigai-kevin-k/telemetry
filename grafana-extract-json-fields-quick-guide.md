# Grafana 提取 JSON 欄位快速指南

## 目標

從 Line 欄位的 JSON 中只顯示 `datetime` 和 `message` 兩個欄位。

## 快速設定步驟

### 步驟 1: 修改 Loki 查詢

在每個 panel 的查詢中，加入 `| json`：

**ARO21 panel**：
```
{job="vip_roulette_sensor_errors"} | json
```

**ARO11 panel**：
```
{job="speed_roulette_error_logs"} | json
```

**SBO11 panel**：
```
{job="sicbo_error_logs"} | json
```

### 步驟 2: 在 UI 中添加 Transform

1. **進入 Edit Panel 模式**
   - 點擊 panel 標題旁的 **...** → **Edit**

2. **添加 Extract fields Transform**
   - 點擊 **Transform** 標籤
   - 點擊 **+ Transform**
   - 選擇 **Extract fields**
   - 設定：
     - **Source**: `A Line`
     - **Format**: `JSON` 或 `Auto`
   - 點擊 **Apply**

3. **修改 Organize fields Transform**
   - 找到現有的 **Organize fields** transform
   - 在 **Exclude by name** 中，新增勾選：
     - `log_file`
     - `date`
     - `time`
     - `Line`（如果還存在）
   - 在 **Rename by name** 中（可選）：
     - `datetime` → `DateTime`
     - `message` → `Message`
   - 點擊 **Apply**

4. **儲存**
   - 點擊右上角 **Apply** 或 **Save**

### 步驟 3: 套用到所有 Panel

對 ARO21、ARO11、SBO11 三個 panel 重複步驟 2。

## Transform 設定順序

確保 Transform 的順序是：
1. **Extract fields** (JSON) - 提取 JSON 欄位
2. **Organize fields** - 隱藏不需要的欄位

## 預期結果

設定完成後，每個 panel 應該只顯示：
- **DateTime**: 2025-11-10 14:34:38.793
- **Message**: *X;6;178;13;0;001;0

## 如果 Extract fields 沒有 JSON 選項

使用 **Auto** 格式，Grafana 會自動偵測 JSON 格式。

## 驗證

1. 檢查表格是否出現 `datetime` 和 `message` 欄位
2. 確認其他欄位（log_file, date, time 等）已隱藏
3. 確認資料正確顯示









