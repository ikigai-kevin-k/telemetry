#!/usr/bin/env python3
import requests
import json
from datetime import datetime, timedelta

def query_loki_logs():
    """Query logs from remote Loki server"""
    loki_url = "http://100.64.0.113:3100/loki/api/v1/query_range"
    
    # Query parameters
    end_time = int(time.time() * 1000000000)  # nanoseconds
    start_time = end_time - (3600 * 1000000000)  # 1 hour ago
    
    queries = [
        "{job=\"test_agent\"}",  # Our test logs
        "{instance=\"GC-ARO-001-2-agent\"}",  # All logs from our agent
        "{job=~\"mock_sicbo|server|tmux_client\"}",  # Specific jobs
        "{level=\"INFO\"}",  # INFO level logs
        "{level=\"ERROR\"}"  # ERROR level logs
    ]
    
    print("🔍 Querying logs from Loki server...")
    print(f"📡 Target: {loki_url}")
    print(f"⏰ Time range: Last 1 hour")
    print("-" * 50)
    
    for i, query in enumerate(queries, 1):
        print(f"\n📋 Query {i}: {query}")
        
        try:
            params = {
                "query": query,
                "start": str(start_time),
                "end": str(end_time),
                "limit": 10
            }
            
            response = requests.get(loki_url, params=params, timeout=10)
            
            if response.status_code == 200:
                data = response.json()
                
                if data.get("status") == "success":
                    streams = data.get("data", {}).get("result", [])
                    
                    if streams:
                        print(f"✅ Found {len(streams)} stream(s)")
                        total_entries = sum(len(stream.get("values", [])) for stream in streams)
                        print(f"📊 Total log entries: {total_entries}")
                        
                        # Show first few entries
                        for stream in streams[:2]:  # Show first 2 streams
                            labels = stream.get("stream", {})
                            values = stream.get("values", [])
                            
                            print(f"   🏷️  Labels: {labels}")
                            print(f"   📝 Entries: {len(values)}")
                            
                            # Show first entry
                            if values:
                                timestamp, message = values[0]
                                readable_time = datetime.fromtimestamp(int(timestamp) / 1000000000)
                                print(f"   ⏰ Latest: {readable_time} - {message[:80]}...")
                    else:
                        print("❌ No logs found")
                else:
                    print(f"❌ Query failed: {data}")
            else:
                print(f"❌ HTTP Error: {response.status_code}")
                
        except Exception as e:
            print(f"❌ Error querying: {e}")

if __name__ == "__main__":
    import time
    query_loki_logs()
