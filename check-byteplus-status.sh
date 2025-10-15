#!/bin/bash

# BytePlus VMP Datasource 狀態檢查腳本

echo "🔍 檢查 BytePlus VMP Datasource 狀態..."
echo

# 檢查 Grafana 服務狀態
echo "1. Grafana 服務狀態："
if curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/api/health | grep -q "200"; then
    echo "   ✅ Grafana 服務正常運行"
else
    echo "   ❌ Grafana 服務異常"
    exit 1
fi

# 檢查環境變數
echo
echo "2. 環境變數載入狀態："
if docker exec kevin-telemetry-grafana env | grep -q "BYTEPLUS_ACCESS_KEY="; then
    echo "   ✅ BYTEPLUS_ACCESS_KEY 已載入"
else
    echo "   ❌ BYTEPLUS_ACCESS_KEY 未載入"
fi

if docker exec kevin-telemetry-grafana env | grep -q "BYTEPLUS_SECRET_KEY="; then
    echo "   ✅ BYTEPLUS_SECRET_KEY 已載入"
else
    echo "   ❌ BYTEPLUS_SECRET_KEY 未載入"
fi

# 檢查 datasource 配置檔案
echo
echo "3. Datasource 配置檔案狀態："
if docker exec kevin-telemetry-grafana test -f /etc/grafana/provisioning/datasources/byteplus-vmp.yml; then
    echo "   ✅ byteplus-vmp.yml 配置檔案存在"
else
    echo "   ❌ byteplus-vmp.yml 配置檔案不存在"
fi

# 檢查 Docker Volume
echo
echo "4. Docker Volume 狀態："
if docker volume ls | grep -q "telemetry_grafana_data"; then
    echo "   ✅ Grafana 資料 volume 存在"
else
    echo "   ❌ Grafana 資料 volume 不存在"
fi

echo
echo "🌐 請前往 Grafana 進行最終驗證："
echo "   1. 開啟瀏覽器：http://localhost:3000"
echo "   2. 登入：admin/admin"
echo "   3. 導航至：Administration > Data sources"
echo "   4. 檢查 BP-VMP 資料來源"
echo "   5. 確認密碼欄位顯示 'configured'"
echo "   6. 點擊 'Save & Test' 測試連線"
echo
echo "✅ 如果所有檢查都通過，您的 Secret Key 現在已經持久化儲存！"
