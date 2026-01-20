#!/usr/bin/env python3
import requests
import time
import json
from datetime import datetime

def push_sdp_log_to_loki():
    """Push SDP error log directly to Loki server"""
    loki_url = "http://100.64.0.113:3100/loki/api/v1/push"
    
    # Generate SDP error log
    current_time = int(time.time() * 1000000000)  # nanoseconds
    log_message = "SDP Error in SPEED_ROULETTE - Table: Speed Roulette - Error Code: SENSOR_STUCK - Error: SENSOR ERROR - Detected warning_flag=4 in *X;6 message"
    
    # Prepare the payload
    stream = {
        "stream": {
            "job": "sdp",
            "instance": "GC-aro12-agent",
            "service": "sdp_service",
            "level": "ERROR",
            "logger": "SDP",
            "game_type": "SPEED_ROULETTE",
            "table_name": "Speed Roulette",
            "error_code": "SENSOR_STUCK"
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
            timeout=10
        )
        
        print(f"Response status: {response.status_code}")
        print(f"Response text: {response.text}")
        
        if response.status_code == 204:
            print("✅ Successfully pushed SDP log to Loki!")
        else:
            print("❌ Failed to push SDP log to Loki")
            
    except Exception as e:
        print(f"❌ Error pushing SDP log: {e}")

if __name__ == "__main__":
    push_sdp_log_to_loki()
