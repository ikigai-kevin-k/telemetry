#!/usr/bin/env python3
"""
Disk Usage Exporter for Prometheus
Monitors disk usage for specified filesystem and exposes Prometheus metrics
"""

import os
import time
import subprocess
from prometheus_client import start_http_server, Gauge
from typing import Dict, Optional

# Target filesystem to monitor
TARGET_FILESYSTEM = "/dev/mapper/ubuntu--vg-ubuntu--lv"

# Prometheus metrics
disk_usage_percent = Gauge(
    'disk_usage_percent',
    'Disk usage percentage',
    ['filesystem', 'mountpoint']
)

disk_total_bytes = Gauge(
    'disk_total_bytes',
    'Total disk capacity in bytes',
    ['filesystem', 'mountpoint']
)

disk_used_bytes = Gauge(
    'disk_used_bytes',
    'Used disk capacity in bytes',
    ['filesystem', 'mountpoint']
)

disk_available_bytes = Gauge(
    'disk_available_bytes',
    'Available disk capacity in bytes',
    ['filesystem', 'mountpoint']
)


def get_disk_stats(filesystem: str) -> Optional[Dict[str, str]]:
    """
    Get disk statistics for specified filesystem using df command
    
    Args:
        filesystem: Filesystem path (e.g., /dev/mapper/ubuntu--vg-ubuntu--lv)
        
    Returns:
        Dictionary with filesystem, mountpoint, total, used, available, and usage_percent
        Returns None if filesystem not found or error occurs
    """
    try:
        # Use df command on root mountpoint to get disk usage
        # This ensures we get the correct mountpoint even in containers
        result = subprocess.run(
            ['df', '-k', '-P', '/'],
            capture_output=True,
            text=True,
            timeout=5,
            check=True
        )
        
        # Parse output
        # Format: Filesystem     1024-blocks  Used Available Capacity Mounted on
        lines = result.stdout.strip().split('\n')
        if len(lines) < 2:
            return None
        
        # Skip header line, get data line
        data_line = lines[1].split()
        if len(data_line) < 6:
            return None
        
        filesystem_name = data_line[0]
        
        # Verify this is our target filesystem
        if filesystem_name != filesystem:
            # If not exact match, try to find it in all filesystems
            all_result = subprocess.run(
                ['df', '-k', '-P'],
                capture_output=True,
                text=True,
                timeout=5,
                check=True
            )
            all_lines = all_result.stdout.strip().split('\n')
            for line in all_lines[1:]:
                if line.startswith(filesystem):
                    data_line = line.split()
                    if len(data_line) >= 6:
                        filesystem_name = data_line[0]
                        break
        
        total_kb = int(data_line[1])
        used_kb = int(data_line[2])
        available_kb = int(data_line[3])
        usage_percent_str = data_line[4].rstrip('%')
        # Mountpoint is the last field (may contain spaces, so join from index 5 onwards)
        mountpoint = ' '.join(data_line[5:])
        
        # Convert kilobytes to bytes
        total_bytes = total_kb * 1024
        used_bytes = used_kb * 1024
        available_bytes = available_kb * 1024
        
        # Parse usage percentage
        try:
            usage_percent = float(usage_percent_str)
        except ValueError:
            usage_percent = 0.0
        
        return {
            'filesystem': filesystem_name,
            'mountpoint': mountpoint,
            'total_bytes': total_bytes,
            'used_bytes': used_bytes,
            'available_bytes': available_bytes,
            'usage_percent': usage_percent
        }
        
    except subprocess.TimeoutExpired:
        print(f"Error: df command timed out for {filesystem}")
        return None
    except subprocess.CalledProcessError as e:
        print(f"Error: df command failed for {filesystem}: {e}")
        return None
    except Exception as e:
        print(f"Error getting disk stats for {filesystem}: {e}")
        return None


def update_metrics():
    """Update all Prometheus metrics with current disk usage information"""
    stats = get_disk_stats(TARGET_FILESYSTEM)
    
    if stats:
        # Update metrics with labels
        disk_usage_percent.labels(
            filesystem=stats['filesystem'],
            mountpoint=stats['mountpoint']
        ).set(stats['usage_percent'])
        
        disk_total_bytes.labels(
            filesystem=stats['filesystem'],
            mountpoint=stats['mountpoint']
        ).set(stats['total_bytes'])
        
        disk_used_bytes.labels(
            filesystem=stats['filesystem'],
            mountpoint=stats['mountpoint']
        ).set(stats['used_bytes'])
        
        disk_available_bytes.labels(
            filesystem=stats['filesystem'],
            mountpoint=stats['mountpoint']
        ).set(stats['available_bytes'])
        
        print(f"Updated metrics: {stats['filesystem']} @ {stats['mountpoint']} - "
              f"{stats['usage_percent']:.1f}% used")
    else:
        print(f"Warning: Could not get disk stats for {TARGET_FILESYSTEM}")


def main():
    """Main function"""
    print("Starting Disk Usage Exporter...")
    print(f"Monitoring filesystem: {TARGET_FILESYSTEM}")
    
    # Start Prometheus metrics server
    start_http_server(9275)
    print("Metrics server started on port 9275")
    
    # Update metrics every 30 seconds
    while True:
        try:
            update_metrics()
            time.sleep(30)
        except KeyboardInterrupt:
            print("\nShutting down...")
            break
        except Exception as e:
            print(f"Error in main loop: {e}")
            time.sleep(30)


if __name__ == "__main__":
    main()
