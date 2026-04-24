#!/bin/bash

# BytePlus VMP 環境變數載入腳本
# 確保每次重啟時都能正確載入環境變數

# 檢查憑證檔案是否存在
if [ ! -f "byteplus-credentials.env" ]; then
    echo "❌ 錯誤：byteplus-credentials.env 檔案不存在"
    echo "請先執行: cp byteplus-credentials.env.example byteplus-credentials.env && chmod 600 byteplus-credentials.env"
    echo "或執行 ./scripts/setup/setup-byteplus-credentials.sh 互動設定憑證"
    exit 1
fi

# 載入環境變數檔案
source byteplus-credentials.env

# 檢查環境變數是否設定
if [ -z "$BYTEPLUS_ACCESS_KEY" ] || [ -z "$BYTEPLUS_SECRET_KEY" ]; then
    echo "❌ 錯誤：環境變數未正確設定"
    echo "請檢查 byteplus-credentials.env 檔案內容"
    exit 1
fi

# 重啟 Grafana 服務
cd /home/ella/kevin/telemetry
docker compose restart grafana

echo "✅ BytePlus VMP 環境變數已載入，Grafana 服務已重啟"
echo "🔍 請前往 Grafana (http://localhost:3000) 檢查 BP-VMP 資料來源狀態"
