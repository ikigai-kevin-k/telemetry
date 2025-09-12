#!/usr/bin/env python3
import requests
import json
from datetime import datetime, timedelta

def check_grafana_loki_connection():
    """Check if Grafana can connect to Loki"""
    
    # Test different Grafana URLs
    grafana_urls = [
        "http://100.64.0.160:3000",  # Server IP
        "http://100.64.0.113:3000",  # From your browser URL
        "http://localhost:3000"
    ]
    
    loki_url = "http://100.64.0.160:3100"
    
    print("🔍 Checking Grafana to Loki connection...")
    print(f"📡 Loki URL: {loki_url}")
    print("-" * 50)
    
    # First, verify Loki is accessible
    try:
        loki_response = requests.get(f"{loki_url}/ready", timeout=5)
        print(f"✅ Loki server is accessible: {loki_response.status_code}")
    except Exception as e:
        print(f"❌ Loki server not accessible: {e}")
        return
    
    # Check if we can query Loki directly
    try:
        query_url = f"{loki_url}/loki/api/v1/query_range"
        params = {
            "query": "{job=\"test_agent\"}",
            "start": str(int((datetime.now() - timedelta(hours=1)).timestamp() * 1000000000)),
            "end": str(int(datetime.now().timestamp() * 1000000000)),
            "limit": 5
        }
        
        response = requests.get(query_url, params=params, timeout=10)
        if response.status_code == 200:
            data = response.json()
            if data.get("status") == "success":
                streams = data.get("data", {}).get("result", [])
                print(f"✅ Loki query successful: Found {len(streams)} streams")
                for stream in streams:
                    labels = stream.get("stream", {})
                    values = stream.get("values", [])
                    print(f"   📊 Stream: {labels} - {len(values)} entries")
            else:
                print(f"❌ Loki query failed: {data}")
        else:
            print(f"❌ Loki query HTTP error: {response.status_code}")
    except Exception as e:
        print(f"❌ Loki query error: {e}")
    
    print("\n" + "=" * 50)
    print("🔧 Grafana 設定建議:")
    print("1. 檢查 Grafana 的時間範圍設定")
    print("   - 設定為 'Last 1 hour' 或 'Last 6 hours'")
    print("   - 確保時區設定正確")
    print()
    print("2. 檢查 Loki 資料來源配置")
    print("   - URL: http://100.64.0.160:3100")
    print("   - 確保 Grafana 可以訪問這個 URL")
    print()
    print("3. 嘗試的查詢語法:")
    print("   - {job=\"test_agent\"}")
    print("   - {instance=\"GC-ARO-001-2-agent\"}")
    print("   - {job=~\"test_agent|server|tmux_client\"}")
    print()
    print("4. 如果還是沒有資料，嘗試:")
    print("   - 重新整理 Grafana 頁面")
    print("   - 檢查瀏覽器開發者工具的 Network 標籤")
    print("   - 查看是否有 CORS 或其他網路錯誤")

if __name__ == "__main__":
    check_grafana_loki_connection()
