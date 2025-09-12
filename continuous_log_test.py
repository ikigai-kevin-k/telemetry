#!/usr/bin/env python3
import requests
import time
import json
from datetime import datetime
import random

def push_continuous_logs():
    """Continuously push test logs to remote Loki server"""
    loki_url = "http://100.64.0.160:3100/loki/api/v1/push"
    
    log_types = [
        ("mock_sicbo", "INFO", "Mock Sicbo game log"),
        ("server", "INFO", "Server application log"),
        ("tmux_client", "DEBUG", "TMUX client debug log"),
        ("system", "WARN", "System warning log"),
        ("database", "ERROR", "Database error log")
    ]
    
    print("🚀 Starting continuous log push to Loki...")
    print(f"📡 Target: {loki_url}")
    print("📝 Log types: mock_sicbo, server, tmux_client, system, database")
    print("⏰ Pushing logs every 5 seconds...")
    print("🛑 Press Ctrl+C to stop")
    print("-" * 50)
    
    try:
        counter = 1
        while True:
            current_time = int(time.time() * 1000000000)  # nanoseconds
            
            # Generate random log entry
            log_type, level, description = random.choice(log_types)
            log_message = f"{description} #{counter} - {datetime.now().strftime('%Y-%m-%d %H:%M:%S')} - Random data: {random.randint(1000, 9999)}"
            
            # Prepare the payload
            stream = {
                "stream": {
                    "job": log_type,
                    "instance": "GC-ARO-001-2-agent",
                    "level": level,
                    "logger": f"{log_type}_logger",
                    "service_name": "telemetry_agent"
                },
                "values": [
                    [str(current_time), log_message]
                ]
            }
            
            payload = {"streams": [stream]}
            
            try:
                response = requests.post(
                    loki_url,
                    headers={"Content-Type": "application/json"},
                    json=payload,
                    timeout=5
                )
                
                if response.status_code == 204:
                    print(f"✅ [{counter:03d}] {log_type.upper()}/{level} - {log_message[:50]}...")
                else:
                    print(f"❌ [{counter:03d}] Failed to push log: {response.status_code}")
                    
            except Exception as e:
                print(f"❌ [{counter:03d}] Error pushing log: {e}")
            
            counter += 1
            time.sleep(5)  # Wait 5 seconds between pushes
            
    except KeyboardInterrupt:
        print("\n🛑 Stopped by user")
        print(f"📊 Total logs pushed: {counter - 1}")

if __name__ == "__main__":
    push_continuous_logs()
