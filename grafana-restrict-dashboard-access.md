# Grafana Dashboard 存取限制設定指南

## 目標：設定特定 Dashboard 供 Viewer 存取，其他僅供 Admin 存取

本指南說明如何設定 "Round Stat" dashboard 供 Viewer 角色存取，而其他所有 dashboard 僅供 Admin 存取。

## 方法一：使用 Dashboard 權限設定（推薦）

### 步驟 1: 為 "Round Stat" Dashboard 設定 Viewer 權限

1. **進入 "Round Stat" Dashboard**：
   - 前往 **Dashboards** → **Browse**
   - 展開 **Overview** folder
   - 點擊 **Round Stat** dashboard

2. **開啟 Dashboard 設定**：
   - 點擊右上角的 **Settings**（齒輪圖示）

3. **設定權限**：
   - 點擊 **Permissions** 標籤
   - 點擊 **Add permission** 按鈕
   - 在彈出視窗中選擇：
     - **Type**: 選擇 **Role**
     - **Role**: 選擇 **Viewer**
     - **Permission**: 選擇 **View**
   - 點擊 **Save**

4. **確認權限設定**：
   - 您應該會看到權限列表中顯示：
     - **Viewer Role** - View 權限
     - **Admin Role** - Admin 權限（預設）

### 步驟 2: 限制其他 Dashboard 僅供 Admin 存取

有兩種方式可以限制其他 dashboard：

#### 方式 A: 為每個 Dashboard 設定權限（精確控制）

對於每個需要限制的 dashboard：

1. **進入 Dashboard**：
   - 前往 **Dashboards** → **Browse**
   - 進入目標 dashboard（例如：System Overview）

2. **開啟 Dashboard 設定**：
   - 點擊右上角 **Settings**（齒輪圖示）

3. **設定權限**：
   - 點擊 **Permissions** 標籤
   - 檢查現有權限：
     - 如果有 **Viewer Role** 或 **Editor Role** 的權限，點擊右側的 **X** 移除
     - 確保只保留 **Admin Role** 的權限
   - 如果沒有明確的權限設定，點擊 **Add permission**：
     - **Type**: 選擇 **Role**
     - **Role**: 選擇 **Admin**
     - **Permission**: 選擇 **Admin**
     - 點擊 **Save**

#### 方式 B: 使用 Folder 權限（批量控制，推薦）

如果 dashboard 都放在特定的 folder 中，可以設定 folder 權限：

1. **設定 "Overview" Folder 權限**：
   - 前往 **Dashboards** → **Browse**
   - 找到 **Overview** folder
   - 點擊 folder 右側的 **...** 選單（三個點）
   - 選擇 **Manage permissions**

2. **移除預設權限並設定限制**：
   - 檢查現有權限列表
   - 如果有 **Viewer Role** 或 **Editor Role** 的權限，點擊 **X** 移除
   - 點擊 **Add permission**：
     - **Type**: 選擇 **Role**
     - **Role**: 選擇 **Admin**
     - **Permission**: 選擇 **Admin**
     - 點擊 **Save**

3. **為 "Round Stat" 設定個別權限**（覆蓋 folder 權限）：
   - 進入 **Round Stat** dashboard
   - 點擊 **Settings** → **Permissions**
   - 點擊 **Add permission**：
     - **Type**: 選擇 **Role**
     - **Role**: 選擇 **Viewer**
     - **Permission**: 選擇 **View**
     - 點擊 **Save**
   - 這樣 "Round Stat" 就會有 Viewer 權限，即使 folder 限制為 Admin

4. **設定其他 Folder 權限**：
   - 重複上述步驟，為其他 folder 設定 Admin-only 權限：
     - General
     - BytePlus
     - disk-monitoring
     - loki
     - Prometheus
     - prometheus
     - SDP Monitoring
     - Zabbix

## 方法二：使用組織層級的預設權限（進階）

### 步驟 1: 修改 Grafana 配置

編輯 `grafana/grafana.ini` 檔案：

```ini
[users]
# 禁止使用者自動成為 Editor
viewers_can_edit = false

# 禁止使用者自動成為 Admin
viewers_can_admin = false
```

### 步驟 2: 重啟 Grafana

```bash
docker-compose restart grafana
```

## 驗證設定

### 測試 Viewer 帳號存取

1. **登出 Admin 帳號**

2. **使用 Viewer 帳號登入**

3. **檢查 Dashboard 列表**：
   - 前往 **Dashboards** → **Browse**
   - Viewer 應該只能看到 "Round Stat" dashboard
   - 其他 dashboard 和 folder 應該不會顯示

4. **測試存取權限**：
   - 嘗試點擊 "Round Stat" → 應該可以正常查看
   - 嘗試直接輸入其他 dashboard 的 URL → 應該會顯示「無權限」或「找不到」錯誤

### 測試 Admin 帳號存取

1. **使用 Admin 帳號登入**

2. **檢查 Dashboard 列表**：
   - 應該可以看到所有 dashboard 和 folder

3. **確認所有 dashboard 都可存取**：
   - 所有 dashboard 都應該可以正常開啟和編輯

## 權限繼承規則

Grafana 的權限繼承順序（由高到低）：

1. **Dashboard 權限**（最高優先級）
   - 如果 dashboard 有明確的權限設定，會覆蓋 folder 權限

2. **Folder 權限**
   - 如果 dashboard 沒有明確權限，會繼承 folder 的權限

3. **組織角色權限**（最低優先級）
   - 如果 dashboard 和 folder 都沒有明確權限，使用組織角色權限

## 完整設定範例

### 設定步驟摘要

1. ✅ 為 "Round Stat" dashboard 設定 Viewer 權限
2. ✅ 為 "Overview" folder 設定 Admin-only 權限（但 "Round Stat" 會覆蓋）
3. ✅ 為其他所有 folder 設定 Admin-only 權限：
   - General
   - BytePlus
   - disk-monitoring
   - loki
   - Prometheus
   - prometheus
   - SDP Monitoring
   - Zabbix
4. ✅ 為其他 dashboard（如 "System Overview"）設定 Admin-only 權限（如果需要的話）

### 預期結果

- **Viewer 角色**：
  - ✅ 可以看到並存取 "Round Stat" dashboard
  - ❌ 無法看到其他 dashboard 和 folder
  - ❌ 無法編輯任何內容

- **Admin 角色**：
  - ✅ 可以看到並存取所有 dashboard
  - ✅ 可以編輯所有 dashboard
  - ✅ 可以管理所有設定

## 注意事項

1. **權限設定需要時間生效**：
   - 設定後可能需要重新整理頁面或重新登入

2. **Explore 功能**：
   - Viewer 仍可能透過 **Explore** 功能查詢資料源
   - 如需完全限制，請同時設定資料源權限

3. **API 存取**：
   - 即使限制了 UI 存取，Viewer 仍可能透過 API 存取資料
   - 如需完全限制，請考慮使用 API 權限控制

4. **快取問題**：
   - 如果設定後仍能看到不應該看到的 dashboard，嘗試：
     - 清除瀏覽器快取
     - 使用無痕模式測試
     - 重新登入

## 故障排除

### 問題：Viewer 仍能看到其他 dashboard

**解決方案**：
1. 確認已為其他 folder 設定了 Admin-only 權限
2. 確認已為其他 dashboard 設定了 Admin-only 權限
3. 檢查是否有其他權限設定覆蓋了限制

### 問題：Viewer 無法看到 "Round Stat"

**解決方案**：
1. 確認 "Round Stat" dashboard 有明確的 Viewer 權限
2. 確認 "Overview" folder 沒有完全禁止 Viewer 存取
3. 檢查使用者是否確實是 Viewer 角色

### 問題：Admin 無法存取某些 dashboard

**解決方案**：
1. 確認 Admin 角色的權限設定正確
2. 檢查是否有其他限制覆蓋了 Admin 權限

## 相關檔案

- `grafana/grafana.ini` - Grafana 主配置檔案
- `grafana-user-permissions.md` - 使用者權限管理完整指南

## 參考資料

- [Grafana Dashboard 權限文件](https://grafana.com/docs/grafana/latest/administration/roles-and-permissions/access-control/)
- [Grafana Folder 權限文件](https://grafana.com/docs/grafana/latest/administration/roles-and-permissions/access-control/folder-permissions/)










