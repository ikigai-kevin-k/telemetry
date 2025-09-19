#!/usr/bin/env python3
"""
Test script to verify Studio SDP Roulette log collection
Tests the new Promtail configuration for ARO-001-1 agent
"""

import requests
import json
import time
import subprocess
from datetime import datetime, timedelta

def check_promtail_status():
    """Check if Promtail container is running and healthy"""
    try:
        result = subprocess.run([
            'docker', 'ps', '--filter', 'name=telemetry-promtail-GC-ARO-001-1-agent',
            '--format', 'table {{.Names}}\t{{.Status}}'
        ], capture_output=True, text=True, check=True)
        
        print("📊 Promtail Container Status:")
        print(result.stdout)
        return "Up" in result.stdout
    except subprocess.CalledProcessError as e:
        print(f"❌ Error checking Promtail status: {e}")
        return False

def check_loki_connection():
    """Check if Loki server is accessible"""
    try:
        response = requests.get('http://100.64.0.113:3100/ready', timeout=5)
        if response.status_code == 200:
            print("✅ Loki server is ready")
            return True
        else:
            print(f"⚠️  Loki server returned status: {response.status_code}")
            return False
    except requests.RequestException as e:
        print(f"❌ Cannot connect to Loki server: {e}")
        return False

def query_studio_sdp_logs():
    """Query Loki for Studio SDP Roulette logs"""
    try:
        # Query for logs from the last hour
        end_time = datetime.now()
        start_time = end_time - timedelta(hours=1)
        
        query_params = {
            'query': '{job="studio_sdp_roulette", instance="GC-ARO-001-1-agent"}',
            'start': int(start_time.timestamp() * 1000000000),  # nanoseconds
            'end': int(end_time.timestamp() * 1000000000),
            'limit': 100
        }
        
        response = requests.get(
            'http://100.64.0.113:3100/loki/api/v1/query_range',
            params=query_params,
            timeout=10
        )
        
        if response.status_code == 200:
            data = response.json()
            if data.get('data', {}).get('result'):
                log_count = sum(len(stream.get('values', [])) for stream in data['data']['result'])
                print(f"✅ Found {log_count} Studio SDP Roulette log entries in the last hour")
                
                # Show sample logs
                if log_count > 0:
                    print("\n📋 Sample log entries:")
                    for stream in data['data']['result'][:2]:  # Show first 2 streams
                        labels = stream.get('stream', {})
                        print(f"   Labels: {labels}")
                        for value in stream.get('values', [])[:3]:  # Show first 3 entries
                            timestamp, log_line = value
                            # Convert nanosecond timestamp to readable format
                            dt = datetime.fromtimestamp(int(timestamp) / 1000000000)
                            print(f"   {dt.strftime('%Y-%m-%d %H:%M:%S')}: {log_line[:100]}...")
                        print()
                return True
            else:
                print("⚠️  No Studio SDP Roulette logs found in the last hour")
                return False
        else:
            print(f"❌ Loki query failed with status: {response.status_code}")
            print(f"Response: {response.text}")
            return False
            
    except requests.RequestException as e:
        print(f"❌ Error querying Loki: {e}")
        return False

def check_log_file_exists():
    """Check if the Studio SDP log file exists and is readable"""
    import os
    log_path = "/home/rnd/studio-sdp-roulette/self-test-2api.log"
    
    if os.path.exists(log_path):
        try:
            size = os.path.getsize(log_path)
            print(f"✅ Studio SDP log file exists: {log_path}")
            print(f"   File size: {size / (1024*1024):.2f} MB")
            
            # Check if file is readable
            with open(log_path, 'r') as f:
                f.readline()
            print("✅ Log file is readable")
            return True
        except Exception as e:
            print(f"❌ Error reading log file: {e}")
            return False
    else:
        print(f"❌ Studio SDP log file not found: {log_path}")
        return False

def main():
    """Main test function"""
    print("🔍 Testing Studio SDP Roulette Log Collection Configuration")
    print("=" * 60)
    
    tests_passed = 0
    total_tests = 4
    
    # Test 1: Check log file exists
    print("\n1️⃣  Checking log file availability...")
    if check_log_file_exists():
        tests_passed += 1
    
    # Test 2: Check Promtail status
    print("\n2️⃣  Checking Promtail container status...")
    if check_promtail_status():
        tests_passed += 1
    
    # Test 3: Check Loki connection
    print("\n3️⃣  Checking Loki server connection...")
    if check_loki_connection():
        tests_passed += 1
    
    # Test 4: Query logs from Loki
    print("\n4️⃣  Querying Studio SDP logs from Loki...")
    if query_studio_sdp_logs():
        tests_passed += 1
    
    # Summary
    print("\n" + "=" * 60)
    print(f"📊 Test Results: {tests_passed}/{total_tests} tests passed")
    
    if tests_passed == total_tests:
        print("🎉 All tests passed! Studio SDP log collection is working correctly.")
    elif tests_passed >= total_tests - 1:
        print("⚠️  Most tests passed. Check the failed test above.")
    else:
        print("❌ Multiple tests failed. Please check the configuration.")
    
    return tests_passed == total_tests

if __name__ == "__main__":
    main()
