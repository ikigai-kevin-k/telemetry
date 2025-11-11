# Grafana 使用者權限管理指南

## 概述

本指南說明如何在 Grafana 中為特定使用者建立唯讀帳號，並限制其只能存取特定的 dashboard。

## 方法一：使用 Grafana UI（推薦用於快速設定）

### 步驟 1: 建立新使用者

1. 以管理員身份登入 Grafana (http://localhost:3000)
2. 前往 **Administration** → **Users and access** → **Users**
3. 點擊 **New user**
4. 填寫使用者資訊：
   - **Name**: 使用者名稱
   - **Email**: 使用者電子郵件
   - **Username**: 登入帳號
   - **Password**: 密碼
5. 點擊 **Create user**

### 步驟 2: 設定使用者角色為 Viewer（唯讀）

1. 在使用者列表中，找到剛建立的使用者
2. 點擊使用者名稱進入詳細頁面
3. 在 **Permissions** 區塊中，確認角色為 **Viewer**
   - **Viewer**: 只能查看 dashboard 和資料源，無法編輯
   - **Editor**: 可以編輯 dashboard，但無法修改資料源
   - **Admin**: 完整管理權限

### 步驟 3: 限制 Dashboard 存取權限

有兩種方式可以限制使用者只能存取特定 dashboard：

#### 方式 A: 使用 Folder 權限（推薦）

1. **建立專用 Folder**：
   - 前往 **Dashboards** → **Browse**
   - 點擊 **New** → **New folder**
   - 建立一個專用資料夾（例如：`Restricted-Dashboards`）

2. **將 Dashboard 移動到 Folder**：
   - 進入要限制的 dashboard
   - 點擊右上角 **Settings** (齒輪圖示)
   - 在 **General** 標籤中，選擇 **Folder** → 選擇剛建立的 folder
   - 儲存變更

3. **設定 Folder 權限**：
   - 前往 **Dashboards** → **Browse**
   - 找到目標 folder，點擊右側的 **...** 選單
   - 選擇 **Manage permissions**
   - 點擊 **Add permission**
   - 選擇 **User**，選擇目標使用者
   - 設定權限為 **View**（唯讀）
   - 點擊 **Save**

4. **移除其他 Folder 的存取權限**（可選）：
   - 對於其他 folder，可以設定為 **No access** 或直接不授予權限

#### 方式 B: 直接設定 Dashboard 權限

1. 進入目標 dashboard
2. 點擊右上角 **Settings** (齒輪圖示)
3. 前往 **Permissions** 標籤
4. 點擊 **Add permission**
5. 選擇 **User**，選擇目標使用者
6. 設定權限為 **View**（唯讀）
7. 點擊 **Save**

### 步驟 4: 限制資料源存取（可選）

如果需要限制使用者只能使用特定資料源：

1. 前往 **Administration** → **Data sources**
2. 選擇目標資料源（例如：Loki、Prometheus）
3. 點擊 **Permissions** 標籤
4. 點擊 **Add permission**
5. 選擇 **User**，選擇目標使用者
6. 設定權限為 **Query**（只能查詢，不能編輯設定）
7. 點擊 **Save**

## 方法二：使用 Grafana API（推薦用於自動化）

### 前置準備

建立一個腳本來自動化建立使用者和設定權限。

### 步驟 1: 建立 API Token

1. 以管理員身份登入 Grafana
2. 前往 **Administration** → **Users and access** → **API keys**
3. 點擊 **New API key**
4. 填寫資訊：
   - **Key name**: 例如 `user-management-token`
   - **Role**: **Admin**
   - **Time to live**: 設定過期時間（或留空為永不過期）
5. 點擊 **Add**，**複製 token**（只會顯示一次）

### 步驟 2: 建立使用者管理腳本

建立 `scripts/create-grafana-user.sh`：

```bash
#!/bin/bash

# Grafana API 設定
GRAFANA_URL="${GRAFANA_URL:-http://localhost:3000}"
GRAFANA_API_KEY="${GRAFANA_API_KEY}"

# 使用者資訊
USERNAME="${1}"
EMAIL="${2}"
PASSWORD="${3}"
USER_NAME="${4:-${USERNAME}}"

# Dashboard UID 或 Folder UID（可選）
DASHBOARD_UID="${5}"
FOLDER_UID="${6}"

if [ -z "$GRAFANA_API_KEY" ]; then
    echo "錯誤: 請設定 GRAFANA_API_KEY 環境變數"
    exit 1
fi

if [ -z "$USERNAME" ] || [ -z "$EMAIL" ] || [ -z "$PASSWORD" ]; then
    echo "用法: $0 <username> <email> <password> [display_name] [dashboard_uid] [folder_uid]"
    exit 1
fi

# 建立使用者
echo "建立使用者: $USERNAME"
USER_RESPONSE=$(curl -s -X POST \
    -H "Authorization: Bearer $GRAFANA_API_KEY" \
    -H "Content-Type: application/json" \
    "$GRAFANA_URL/api/admin/users" \
    -d "{
        \"name\": \"$USER_NAME\",
        \"email\": \"$EMAIL\",
        \"login\": \"$USERNAME\",
        \"password\": \"$PASSWORD\"
    }")

USER_ID=$(echo "$USER_RESPONSE" | jq -r '.id // empty')

if [ -z "$USER_ID" ] || [ "$USER_ID" = "null" ]; then
    echo "錯誤: 無法建立使用者"
    echo "$USER_RESPONSE" | jq '.'
    exit 1
fi

echo "使用者已建立，ID: $USER_ID"

# 設定使用者角色為 Viewer（唯讀）
echo "設定使用者角色為 Viewer..."
curl -s -X PATCH \
    -H "Authorization: Bearer $GRAFANA_API_KEY" \
    -H "Content-Type: application/json" \
    "$GRAFANA_URL/api/org/users/$USER_ID" \
    -d '{
        "role": "Viewer"
    }' > /dev/null

# 如果提供了 Folder UID，設定 Folder 權限
if [ -n "$FOLDER_UID" ]; then
    echo "設定 Folder 權限: $FOLDER_UID"
    curl -s -X POST \
        -H "Authorization: Bearer $GRAFANA_API_KEY" \
        -H "Content-Type: application/json" \
        "$GRAFANA_URL/api/folders/$FOLDER_UID/permissions" \
        -d "{
            \"items\": [
                {
                    \"userId\": $USER_ID,
                    \"permission\": 1
                }
            ]
        }" > /dev/null
    echo "Folder 權限已設定"
fi

# 如果提供了 Dashboard UID，設定 Dashboard 權限
if [ -n "$DASHBOARD_UID" ]; then
    echo "設定 Dashboard 權限: $DASHBOARD_UID"
    curl -s -X POST \
        -H "Authorization: Bearer $GRAFANA_API_KEY" \
        -H "Content-Type: application/json" \
        "$GRAFANA_URL/api/dashboards/uid/$DASHBOARD_UID/permissions" \
        -d "{
            \"items\": [
                {
                    \"userId\": $USER_ID,
                    \"permission\": 1
                }
            ]
        }" > /dev/null
    echo "Dashboard 權限已設定"
fi

echo "完成！使用者 $USERNAME 已建立並設定為唯讀權限"
```

### 步驟 3: 使用腳本建立使用者

```bash
# 設定 API Key
export GRAFANA_API_KEY="your-api-key-here"
export GRAFANA_URL="http://localhost:3000"

# 建立使用者（僅唯讀，無特定 dashboard 限制）
./scripts/create-grafana-user.sh \
    "viewer1" \
    "viewer1@example.com" \
    "secure-password-123" \
    "Viewer One"

# 建立使用者並限制只能存取特定 Folder
# 首先需要取得 Folder UID（可在 Grafana UI 中查看，或使用 API）
FOLDER_UID="abc123"  # 替換為實際的 Folder UID
./scripts/create-grafana-user.sh \
    "restricted-user" \
    "restricted@example.com" \
    "secure-password-456" \
    "Restricted User" \
    "" \
    "$FOLDER_UID"

# 建立使用者並限制只能存取特定 Dashboard
DASHBOARD_UID="xyz789"  # 替換為實際的 Dashboard UID
./scripts/create-grafana-user.sh \
    "dashboard-viewer" \
    "dashboard@example.com" \
    "secure-password-789" \
    "Dashboard Viewer" \
    "$DASHBOARD_UID"
```

## 方法三：使用 Provisioning 配置（進階）

### 建立使用者 Provisioning 配置

建立 `grafana/provisioning/users/users.yml`：

```yaml
apiVersion: 1

users:
  - name: viewer1
    email: viewer1@example.com
    login: viewer1
    password: secure-password-123
    is_admin: false
    org_role: Viewer
```

> **注意**: Grafana 不支援透過 provisioning 自動建立使用者。此方法僅供參考，實際仍需使用 API 或 UI。

## 權限等級說明

### Grafana 角色權限

| 角色 | 權限說明 |
|------|---------|
| **Viewer** | 只能查看 dashboard 和資料源，無法編輯任何內容 |
| **Editor** | 可以建立和編輯 dashboard，但無法修改資料源或系統設定 |
| **Admin** | 完整管理權限，可以修改所有設定 |

### Dashboard/Folder 權限等級

| 權限等級 | 數值 | 說明 |
|---------|------|------|
| **No Access** | 0 | 無法存取 |
| **View** | 1 | 只能查看（唯讀） |
| **Edit** | 2 | 可以查看和編輯 |
| **Admin** | 4 | 完整管理權限 |

## 實作範例：建立受限使用者

### 範例 1: 只能查看 SDP Log Dashboard

```bash
# 1. 取得 SDP Dashboard 的 UID
# 在 Grafana UI 中，進入 dashboard，URL 會顯示 UID
# 例如: http://localhost:3000/d/abc123/sdp-logs
# UID 就是 abc123

# 2. 建立使用者並設定權限
export GRAFANA_API_KEY="your-api-key"
export GRAFANA_URL="http://localhost:3000"

DASHBOARD_UID="abc123"  # SDP Dashboard UID

./scripts/create-grafana-user.sh \
    "sdp-viewer" \
    "sdp-viewer@example.com" \
    "secure-password" \
    "SDP Log Viewer" \
    "$DASHBOARD_UID"
```

### 範例 2: 只能查看特定 Folder 的所有 Dashboard

```bash
# 1. 取得 Folder UID
# 在 Grafana UI 中，進入 folder，URL 會顯示 UID
# 或使用 API 查詢:
curl -H "Authorization: Bearer $GRAFANA_API_KEY" \
    "$GRAFANA_URL/api/folders" | jq '.[] | {uid: .uid, title: .title}'

# 2. 建立使用者並設定 Folder 權限
FOLDER_UID="sdp-monitoring"  # Folder UID

./scripts/create-grafana-user.sh \
    "sdp-folder-viewer" \
    "sdp-folder@example.com" \
    "secure-password" \
    "SDP Folder Viewer" \
    "" \
    "$FOLDER_UID"
```

## 驗證設定

### 檢查使用者權限

```bash
# 使用 API 查詢使用者資訊
curl -H "Authorization: Bearer $GRAFANA_API_KEY" \
    "$GRAFANA_URL/api/users" | jq '.[] | {id: .id, login: .login, email: .email}'

# 查詢特定使用者的組織角色
USER_ID=2
curl -H "Authorization: Bearer $GRAFANA_API_KEY" \
    "$GRAFANA_URL/api/org/users/$USER_ID" | jq '.role'
```

### 檢查 Dashboard 權限

```bash
# 查詢 Dashboard 權限
DASHBOARD_UID="abc123"
curl -H "Authorization: Bearer $GRAFANA_API_KEY" \
    "$GRAFANA_URL/api/dashboards/uid/$DASHBOARD_UID/permissions" | jq '.'
```

### 檢查 Folder 權限

```bash
# 查詢 Folder 權限
FOLDER_UID="sdp-monitoring"
curl -H "Authorization: Bearer $GRAFANA_API_KEY" \
    "$GRAFANA_URL/api/folders/$FOLDER_UID/permissions" | jq '.'
```

## 進階設定：隱藏其他 Dashboard

如果希望使用者完全看不到其他 dashboard，可以：

1. **建立新的組織（Organization）**：
   - 為受限使用者建立專屬組織
   - 只將特定 dashboard 匯入該組織
   - 使用者登入時只能看到該組織的內容

2. **使用 Dashboard 權限**：
   - 為所有不想讓使用者看到的 dashboard 設定權限
   - 確保該使用者沒有這些 dashboard 的存取權限

## 注意事項

1. **API Token 安全**：
   - 妥善保管 API Token，不要提交到版本控制系統
   - 定期輪換 API Token
   - 使用環境變數或密碼管理工具儲存

2. **密碼政策**：
   - 確保使用者密碼符合安全要求
   - 考慮啟用 Grafana 的密碼複雜度要求

3. **權限繼承**：
   - Folder 權限會繼承給其中的 dashboard
   - 如果 dashboard 有明確權限設定，會覆蓋 folder 權限

4. **資料源權限**：
   - 即使限制了 dashboard 存取，使用者仍可能透過 Explore 功能查詢資料源
   - 如需完全限制，請同時設定資料源權限

## 相關檔案

- `docker-compose.yml` - Grafana 服務配置
- `grafana/grafana.ini` - Grafana 主配置檔案
- `grafana/provisioning/` - Provisioning 配置目錄

## 參考資料

- [Grafana 使用者管理文件](https://grafana.com/docs/grafana/latest/administration/user-management/)
- [Grafana API 文件](https://grafana.com/docs/grafana/latest/developers/http_api/)
- [Grafana 權限管理](https://grafana.com/docs/grafana/latest/administration/roles-and-permissions/)

