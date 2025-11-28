# 檢查 Viewer Role 權限指南

## 方法一：使用檢查腳本（推薦）

### 步驟 1: 取得 Grafana API Key

1. 登入 Grafana (http://localhost:3000)
2. 前往 **Administration** → **Users and access** → **API keys**
3. 點擊 **New API key**
4. 填寫資訊：
   - **Key name**: `permission-check-token`
   - **Role**: **Admin**
   - **Time to live**: 設定過期時間（或留空為永不過期）
5. 點擊 **Add**，**複製 token**（只會顯示一次）

### 步驟 2: 執行檢查腳本

```bash
# 設定 API Key
export GRAFANA_API_KEY="your-api-key-here"

# 執行檢查腳本
./scripts/check-dashboard-permissions.sh
```

### 腳本輸出說明

腳本會顯示：
- ✅ **綠色標記**: 無 Viewer 權限的 dashboard/folder
- ❌ **紅色標記**: 仍有 Viewer 權限的 dashboard/folder
- 📊 **統計資訊**: 總數、有/無 Viewer 權限的數量
- 📋 **詳細列表**: 列出所有仍有 Viewer 權限的項目

## 方法二：使用 Grafana UI 手動檢查

### 檢查 Dashboard 權限

1. 前往 **Dashboards** → **Browse**
2. 對每個 dashboard：
   - 點擊 dashboard 名稱進入
   - 點擊右上角 **Settings**（齒輪圖示）
   - 點擊 **Permissions** 標籤
   - 檢查是否有 **Viewer Role** 權限
   - 如果有，點擊右側的 **X** 移除

### 檢查 Folder 權限

1. 前往 **Dashboards** → **Browse**
2. 對每個 folder：
   - 點擊 folder 右側的 **...** 選單
   - 選擇 **Manage permissions**
   - 檢查是否有 **Viewer Role** 權限
   - 如果有，點擊右側的 **X** 移除

## 方法三：使用 Grafana API 直接查詢

### 查詢所有 Dashboard 權限

```bash
# 設定 API Key
export GRAFANA_API_KEY="your-api-key-here"
export GRAFANA_URL="http://localhost:3000"

# 取得所有 dashboards
curl -s -H "Authorization: Bearer $GRAFANA_API_KEY" \
  "$GRAFANA_URL/api/search?type=dash-db" | jq '.[] | {title: .title, uid: .uid, folder: .folderTitle}'

# 檢查特定 dashboard 的權限（替換 DASHBOARD_UID）
DASHBOARD_UID="your-dashboard-uid"
curl -s -H "Authorization: Bearer $GRAFANA_API_KEY" \
  "$GRAFANA_URL/api/dashboards/uid/$DASHBOARD_UID/permissions" | jq '.permissions[] | select(.role == "Viewer")'
```

### 查詢所有 Folder 權限

```bash
# 取得所有 folders
curl -s -H "Authorization: Bearer $GRAFANA_API_KEY" \
  "$GRAFANA_URL/api/folders" | jq '.[] | {title: .title, uid: .uid}'

# 檢查特定 folder 的權限（替換 FOLDER_UID）
FOLDER_UID="your-folder-uid"
curl -s -H "Authorization: Bearer $GRAFANA_API_KEY" \
  "$GRAFANA_URL/api/folders/$FOLDER_UID/permissions" | jq '.permissions[] | select(.role == "Viewer")'
```

## 預期結果

### ✅ 正確的權限設定

- **Round Stat** dashboard: 應該有 **Viewer Role** 權限（View）
- **其他所有 dashboard**: 應該**沒有** Viewer Role 權限
- **所有 folder**（除了可能需要的）: 應該**沒有** Viewer Role 權限

### ❌ 需要修正的情況

如果發現其他 dashboard 仍有 Viewer 權限：
1. 前往該 dashboard 的 **Settings** → **Permissions**
2. 移除 **Viewer Role** 權限
3. 確保只保留 **Admin Role** 權限

## 快速檢查清單

- [ ] 已取得 Grafana API Key
- [ ] 已執行檢查腳本
- [ ] 已確認 "Round Stat" 有 Viewer 權限
- [ ] 已確認其他 dashboard 沒有 Viewer 權限
- [ ] 已確認 folder 權限設定正確
- [ ] 已測試 Viewer 帳號登入驗證

## 相關檔案

- `scripts/check-dashboard-permissions.sh` - 自動檢查腳本
- `grafana-restrict-dashboard-access.md` - 權限設定指南










