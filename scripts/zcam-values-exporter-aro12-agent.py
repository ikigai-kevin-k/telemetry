#!/usr/bin/env python3
"""
ZCAM Values Exporter for ARO12 Agent
Exports ARO12 ZCAM device values (battery, camera mode, temperature, bitrate) as Prometheus metrics
Agent-side specific configuration - only monitors ARO12 device
"""

import json
import time
import requests
from prometheus_client import start_http_server, Gauge, Counter
from typing import Dict, Any

# ZCAM device configuration - Agent-side: only ARO12
# According to user requirement, ARO12 should use IP 192.168.88.12
ZCAM_DEVICES = {
    "zcam-aro12": "192.168.88.12",  # ARO12 device IP as per user requirement
}

# Prometheus metrics
battery_level = Gauge('zcam_battery_level', 'ZCAM device battery level percentage', ['device_name', 'device_ip'])
camera_mode = Gauge('zcam_camera_mode', 'ZCAM device camera mode (1=rec, 0=photo)', ['device_name', 'device_ip'])
temperature = Gauge('zcam_temperature', 'ZCAM device temperature in Celsius', ['device_name', 'device_ip'])
bitrate = Gauge('zcam_bitrate', 'ZCAM device RTMP stream bitrate in Mbps', ['device_name', 'device_ip'])
api_requests_total = Counter('zcam_api_requests_total', 'Total API requests made', ['device_name', 'endpoint', 'status'])

def get_zcam_value(device_ip: str, endpoint: str) -> Dict[str, Any]:
    """Get value from ZCAM device API"""
    try:
        if endpoint == "battery":
            url = f"http://{device_ip}/ctrl/get?k=battery"
        elif endpoint == "camera_mode":
            url = f"http://{device_ip}/ctrl/mode"
        elif endpoint == "temperature":
            url = f"http://{device_ip}/ctrl/temperature"
        elif endpoint == "bitrate":
            url = f"http://{device_ip}/ctrl/rtmp?action=query&index=0"
        else:
            raise ValueError(f"Unknown endpoint: {endpoint}")
        
        response = requests.get(url, timeout=5)
        response.raise_for_status()
        
        data = response.json()
        
        # Parse response based on endpoint
        if endpoint == "battery":
            value = data.get("value", 0)
        elif endpoint == "camera_mode":
            mode = data.get("msg", "unknown")
            value = 1 if mode == "rec" else 0
        elif endpoint == "temperature":
            value = float(data.get("msg", "0"))
        elif endpoint == "bitrate":
            value = float(data.get("bw", 0))  # bw is the bitrate field
        
        return {"success": True, "value": value, "raw_data": data}
        
    except Exception as e:
        print(f"Error getting {endpoint} from {device_ip}: {e}")
        return {"success": False, "value": None, "error": str(e)}

def update_metrics():
    """Update all Prometheus metrics with current ZCAM values"""
    for device_name, device_ip in ZCAM_DEVICES.items():
        # Battery level
        result = get_zcam_value(device_ip, "battery")
        if result["success"]:
            battery_level.labels(device_name=device_name, device_ip=device_ip).set(result["value"])
            api_requests_total.labels(device_name=device_name, endpoint="battery", status="success").inc()
        else:
            api_requests_total.labels(device_name=device_name, endpoint="battery", status="error").inc()
        
        # Camera mode
        result = get_zcam_value(device_ip, "camera_mode")
        if result["success"]:
            camera_mode.labels(device_name=device_name, device_ip=device_ip).set(result["value"])
            api_requests_total.labels(device_name=device_name, endpoint="camera_mode", status="success").inc()
        else:
            api_requests_total.labels(device_name=device_name, endpoint="camera_mode", status="error").inc()
        
        # Temperature
        result = get_zcam_value(device_ip, "temperature")
        if result["success"]:
            temperature.labels(device_name=device_name, device_ip=device_ip).set(result["value"])
            api_requests_total.labels(device_name=device_name, endpoint="temperature", status="success").inc()
        else:
            api_requests_total.labels(device_name=device_name, endpoint="temperature", status="error").inc()
        
        # Bitrate
        result = get_zcam_value(device_ip, "bitrate")
        if result["success"]:
            bitrate.labels(device_name=device_name, device_ip=device_ip).set(result["value"])
            api_requests_total.labels(device_name=device_name, endpoint="bitrate", status="success").inc()
        else:
            api_requests_total.labels(device_name=device_name, endpoint="bitrate", status="error").inc()

def main():
    """Main function"""
    print("Starting ZCAM Values Exporter for ARO12 Agent...")
    print(f"Monitoring device: zcam-aro12 at {ZCAM_DEVICES['zcam-aro12']}")
    
    # Start Prometheus metrics server
    start_http_server(9274)
    print("Metrics server started on port 9274")
    
    # Update metrics every 30 seconds
    while True:
        try:
            print(f"Updating metrics at {time.strftime('%Y-%m-%d %H:%M:%S')}")
            update_metrics()
            time.sleep(30)
        except KeyboardInterrupt:
            print("Shutting down...")
            break
        except Exception as e:
            print(f"Error in main loop: {e}")
            time.sleep(30)

if __name__ == "__main__":
    main()
