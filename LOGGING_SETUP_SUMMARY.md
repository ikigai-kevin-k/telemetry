# 日誌收集設置完成總結

## 已完成的工作

### 1. 創建了 mock_main_sicbo.py
- 替代 `main_sicbo.py` 的臨時應用程式
- 包含完整的日誌功能
- 將日誌輸出到控制台和 `mock_sicbo.log` 文件
- 格式：`YYYY-MM-DD HH:MM:SS - logger_name - LEVEL - message`

### 2. 更新了 Docker Compose 配置
在現有的 Grafana + Prometheus + Pushgateway 架構中添加了：

#### Loki 容器 (kevin-telemetry-loki)
- 端口：3100
- 日誌聚合和存儲系統
- 配置文件：`loki-config.yml`

#### Promtail 容器 (kevin-telemetry-promtail)
- 日誌收集代理
- 監控 `mock_sicbo.log` 文件
- 將日誌發送到 Loki
- 配置文件：`promtail-config.yml`

### 3. 配置文件
- `loki-config.yml` - Loki 服務器配置
- `promtail-config.yml` - Promtail 日誌收集配置
- `grafana/provisioning/datasources/loki.yml` - Grafana Loki 數據源配置

### 4. 測試腳本
- `test_logging.py` - 用於測試 mock 應用程式的腳本

## 架構流程

```
mock_main_sicbo.py → mock_sicbo.log → Promtail → Loki → Grafana
```

## 服務狀態

所有服務都已成功啟動：
- ✅ Grafana (端口 3000)
- ✅ Prometheus (端口 9090)
- ✅ Pushgateway (端口 9091)
- ✅ Loki (端口 3100)
- ✅ Promtail (日誌收集代理)

## 使用方法

### 1. 啟動所有服務
```bash
docker compose up -d
```

### 2. 運行模擬應用程式
```bash
python3 mock_main_sicbo.py
```

### 3. 在 Grafana 中查看日誌
1. 訪問 http://localhost:3000 (admin/admin)
2. 進入 Explore 頁面
3. 選擇 Loki 數據源
4. 查詢：`{job="mock_sicbo"}`

### 4. 日誌查詢範例
```
# 查看所有日誌
{job="mock_sicbo"}

# 查看特定級別的日誌
{job="mock_sicbo", level="INFO"}

# 查看包含特定關鍵字的日誌
{job="mock_sicbo"} |= "game round"
```

## 注意事項

1. **時間戳問題**：目前存在時間戳驗證問題，Loki 拒絕未來的時間戳
2. **配置優化**：可能需要進一步調整 Loki 配置以解決時間戳問題
3. **日誌格式**：確保日誌格式符合 Promtail 配置中的正則表達式

## 下一步

1. 解決時間戳驗證問題
2. 測試日誌收集功能
3. 在 Grafana 中創建日誌儀表板
4. 配置日誌警報

## 故障排除

### 檢查服務狀態
```bash
docker ps | grep kevin-telemetry
```

### 查看容器日誌
```bash
docker logs kevin-telemetry-loki
docker logs kevin-telemetry-promtail
```

### 測試 API
```bash
curl http://localhost:3100/ready  # Loki
curl http://localhost:3000/api/health  # Grafana
```
