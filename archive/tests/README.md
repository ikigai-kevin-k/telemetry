
## Node.js 測試工具

以下 Node.js 相關檔案用於測試和演示 Prometheus metrics 功能：

### 檔案說明

1. **test-client.html** - Prometheus Pushgateway 測試客戶端
   - 用途：從瀏覽器發送 videostutter metrics 到 Pushgateway
   - 使用方式：在瀏覽器中開啟此 HTML 檔案
   - 功能：提供圖形化介面測試 Pushgateway 連接和發送 metrics

2. **example-metrics-server.js** - 範例 Prometheus metrics 伺服器
   - 用途：提供 Prometheus metrics 端點的範例伺服器
   - 使用方式：`npm start` 或 `node example-metrics-server.js`
   - 功能：模擬 video stutter metrics，提供 `/metrics` 端點

3. **test-pushgateway.js** - Pushgateway 測試腳本
   - 用途：測試 Pushgateway 連接和發送 metrics
   - 使用方式：`node test-pushgateway.js`
   - 功能：自動發送多個測試 metrics 到 Pushgateway

### 使用前準備

1. 安裝 Node.js 依賴：
   ```bash
   cd archive/tests/
   npm install
   ```

2. 確保 Pushgateway 服務正在運行（預設端口 9091）

### 注意事項

- 這些工具僅用於測試和演示，不屬於核心功能
- 專案核心技術棧為 Python/Shell，Node.js 工具為額外測試工具
- 如需使用這些工具，請先安裝 Node.js 和 npm
