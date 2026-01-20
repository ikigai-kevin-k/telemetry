#!/usr/bin/env python3
import requests
import time
import json
from datetime import datetime

def push_log_to_loki():
    """Push test logs to remote Loki server"""
    loki_url = "http://100.64.0.113:3100/loki/api/v1/push"
    
    # Generate test log entries
    current_time = int(time.time() * 1000000000)  # nanoseconds
    
    log_entries = [
        f"Test log entry 1 from agent side - {datetime.now()}",
        f"Test log entry 2 from agent side - {datetime.now()}",
        f"Test log entry 3 from agent side - {datetime.now()}",
    ]
    
    # Prepare the payload
    streams = []
    for i, log_entry in enumerate(log_entries):
        stream = {
            "stream": {
                "job": "test_agent",
                "instance": "GC-aro12-agent",
                "level": "INFO",
                "logger": "test_logger"
            },
            "values": [
                [str(current_time + i * 1000000000), log_entry]
            ]
        }
        streams.append(stream)
    
    payload = {"streams": streams}
    
    try:
        response = requests.post(
            loki_url,
            headers={"Content-Type": "application/json"},
            json=payload,
            timeout=10
        )
        
        print(f"Response status: {response.status_code}")
        print(f"Response text: {response.text}")
        
        if response.status_code == 204:
            print("✅ Successfully pushed logs to Loki!")
        else:
            print("❌ Failed to push logs to Loki")
            
    except Exception as e:
        print(f"❌ Error pushing logs: {e}")

if __name__ == "__main__":
    push_log_to_loki()
