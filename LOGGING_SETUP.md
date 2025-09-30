# 日誌收集設置說明

這個設置在現有的 Grafana + Prometheus + Pushgateway 架構中添加了 Loki 來收集 `mock_main_sicbo.py` 的日誌。

## 架構概覽

```
mock_main_sicbo.py → mock_sicbo.log → Promtail → Loki → Grafana
```

## 組件說明

### 1. mock_main_sicbo.py
- 替代 `main_sicbo.py` 的臨時應用程式
- 只包含日誌功能，不包含實際業務邏輯
- 將日誌輸出到控制台和 `mock_sicbo.log` 文件

### 2. Loki (kevin-telemetry-loki)
- 日誌聚合系統
- 端口：3100
- 收集並存儲日誌數據

### 3. Promtail (kevin-telemetry-promtail)
- 日誌收集代理
- 監控 `mock_sicbo.log` 文件
- 將日誌發送到 Loki

### 4. Grafana
- 已配置 Loki 數據源
- 可以查詢和可視化日誌數據

## 使用方法

### 1. 啟動服務
```bash
docker-compose up -d
```

### 2. 運行模擬應用程式
```bash
python3 mock_main_sicbo.py
```

或者使用測試腳本：
```bash
python3 test_logging.py
```

### 3. 查看日誌
- **Grafana**: http://localhost:3000 (admin/admin)
  - 進入 Explore 頁面
  - 選擇 Loki 數據源
  - 查詢：`{job="mock_sicbo"}`

- **Loki API**: http://localhost:3100

### 4. 日誌查詢範例
在 Grafana Explore 中可以使用以下查詢：

```
# 查看所有日誌
{job="mock_sicbo"}

# 查看特定級別的日誌
{job="mock_sicbo", level="INFO"}

# 查看包含特定關鍵字的日誌
{job="mock_sicbo"} |= "game round"

# 查看錯誤日誌
{job="mock_sicbo", level="ERROR"}
```

## 配置文件

### loki-config.yml
Loki 的配置文件，定義了存儲和索引設置。

### promtail-config.yml
Promtail 的配置文件，定義了：
- 監控的日誌文件路徑
- 日誌解析規則
- 標籤提取

### grafana/provisioning/datasources/loki.yml
Grafana 的 Loki 數據源配置。

## 故障排除

### 1. 檢查容器狀態
```bash
docker-compose ps
```

### 2. 查看容器日誌
```bash
docker-compose logs loki
docker-compose logs promtail
```

### 3. 檢查日誌文件
```bash
tail -f mock_sicbo.log
```

### 4. 測試 Loki API
```bash
curl http://localhost:3100/ready
```

## 注意事項

1. 確保 `mock_sicbo.log` 文件存在且有適當的權限
2. 日誌格式必須符合 Promtail 配置中的正則表達式
3. 首次啟動可能需要一些時間來初始化 Loki
4. Grafana 中需要手動添加 Loki 數據源（如果自動配置失敗）
