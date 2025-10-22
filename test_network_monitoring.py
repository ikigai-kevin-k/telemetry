#!/usr/bin/env python3
"""
Test script to verify network monitoring data flow
"""

import requests
import time
import json
from datetime import datetime

def test_loki_connection():
    """Test if we can query Loki for network monitoring data"""
    loki_url = "http://100.64.0.113:3100/loki/api/v1/query_range"
    
    # Query for network monitoring data (range query)
    params = {
        'query': '{job="network_monitor", instance="GC-aro12-agent"}',
        'start': str(int(time.time() - 300) * 1000000000),  # 5 minutes ago
        'end': str(int(time.time()) * 1000000000),  # now
        'limit': 10
    }
    
    try:
        response = requests.get(loki_url, params=params, timeout=10)
        print(f"Loki query status: {response.status_code}")
        
        if response.status_code == 200:
            data = response.json()
            if 'data' in data and 'result' in data['data']:
                results = data['data']['result']
                print(f"Found {len(results)} streams")
                
                for stream in results[:3]:  # Show first 3 streams
                    print(f"Stream labels: {stream['stream']}")
                    if 'values' in stream and stream['values']:
                        latest_entry = stream['values'][-1]
                        print(f"Latest entry: {latest_entry[1]}")
            else:
                print("No data found in response")
        else:
            print(f"Error response: {response.text}")
            
    except Exception as e:
        print(f"Error querying Loki: {e}")

def test_grafana_dashboard():
    """Test if Grafana dashboard is accessible"""
    grafana_url = "http://100.64.0.113:3000"
    
    try:
        response = requests.get(grafana_url, timeout=10)
        print(f"Grafana status: {response.status_code}")
        
        if response.status_code == 200:
            print("✅ Grafana is accessible")
        else:
            print("❌ Grafana is not accessible")
            
    except Exception as e:
        print(f"Error accessing Grafana: {e}")

def main():
    print("=== Network Monitoring Data Flow Test ===")
    print(f"Test time: {datetime.now()}")
    print()
    
    print("1. Testing Loki connection...")
    test_loki_connection()
    print()
    
    print("2. Testing Grafana accessibility...")
    test_grafana_dashboard()
    print()
    
    print("=== Test completed ===")

if __name__ == "__main__":
    main()
