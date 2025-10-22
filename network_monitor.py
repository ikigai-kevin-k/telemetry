#!/usr/bin/env python3
"""
Network Interface Monitor
Collects network interface statistics and writes to log file for Promtail collection
"""

import time
import json
import subprocess
from datetime import datetime
import os

def get_network_stats(interface="enp86s0"):
    """
    Get network interface statistics from /proc/net/dev
    Returns: dict with rx_bytes, tx_bytes, rx_packets, tx_packets
    """
    try:
        with open('/proc/net/dev', 'r') as f:
            lines = f.readlines()
        
        for line in lines:
            if interface in line:
                # Parse the line: interface: rx_bytes rx_packets ... tx_bytes tx_packets ...
                parts = line.split(':')
                if len(parts) >= 2:
                    stats = parts[1].split()
                    if len(stats) >= 8:
                        return {
                            'rx_bytes': int(stats[0]),
                            'rx_packets': int(stats[1]),
                            'tx_bytes': int(stats[8]),
                            'tx_packets': int(stats[9]),
                            'rx_bits': int(stats[0]) * 8,  # Convert bytes to bits
                            'tx_bits': int(stats[8]) * 8   # Convert bytes to bits
                        }
    except Exception as e:
        print(f"Error reading network stats: {e}")
    
    return None

def write_network_log(stats, log_file="/home/rnd/telemetry/logs/network_stats.log"):
    """
    Write network statistics to log file in JSON format
    """
    if not stats:
        return
    
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S.%f")[:-3]
    
    log_entry = {
        "timestamp": timestamp,
        "interface": "enp86s0",
        "rx_bytes": stats['rx_bytes'],
        "rx_packets": stats['rx_packets'],
        "tx_bytes": stats['tx_bytes'],
        "tx_packets": stats['tx_packets'],
        "rx_bits": stats['rx_bits'],
        "tx_bits": stats['tx_bits']
    }
    
    # Create log file if it doesn't exist
    os.makedirs(os.path.dirname(log_file), exist_ok=True)
    
    try:
        with open(log_file, 'a') as f:
            f.write(json.dumps(log_entry) + '\n')
    except Exception as e:
        print(f"Error writing to log file: {e}")

def main():
    """
    Main monitoring loop
    """
    print("Starting network interface monitoring...")
    print("Interface: enp86s0")
    print("Log file: /home/rnd/telemetry/logs/network_stats.log")
    print("Press Ctrl+C to stop")
    
    try:
        while True:
            stats = get_network_stats()
            if stats:
                write_network_log(stats)
                print(f"[{datetime.now().strftime('%H:%M:%S')}] RX: {stats['rx_bits']:,} bits, TX: {stats['tx_bits']:,} bits")
            
            time.sleep(10)  # Collect every 10 seconds
            
    except KeyboardInterrupt:
        print("\nMonitoring stopped.")

if __name__ == "__main__":
    main()
