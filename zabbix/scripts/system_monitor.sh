#!/bin/bash

# System Resource Monitoring Script for Zabbix
# This script monitors CPU, Memory, Disk usage and system health
# Usage: ./system_monitor.sh [metric_name]

# Function to log messages
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >&2
}

# Function to get CPU usage percentage
get_cpu_usage() {
    # Get CPU usage from /proc/stat
    local cpu_info=$(grep '^cpu ' /proc/stat)
    local idle=$(echo $cpu_info | awk '{print $5}')
    local total=0
    
    for val in $cpu_info; do
        total=$((total + val))
    done
    
    # Calculate usage percentage
    local usage=$((100 - (idle * 100) / total))
    echo $usage
}

# Function to get memory usage percentage
get_memory_usage() {
    # Get memory info from /proc/meminfo
    local mem_total=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    local mem_available=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
    
    if [ -z "$mem_available" ]; then
        # Fallback for older kernels without MemAvailable
        local mem_free=$(grep MemFree /proc/meminfo | awk '{print $2}')
        local buffers=$(grep Buffers /proc/meminfo | awk '{print $2}')
        local cached=$(grep -E '^Cached:' /proc/meminfo | awk '{print $2}')
        mem_available=$((mem_free + buffers + cached))
    fi
    
    local mem_used=$((mem_total - mem_available))
    local usage=$((mem_used * 100 / mem_total))
    echo $usage
}

# Function to get disk usage percentage for root filesystem
get_disk_usage() {
    # Get disk usage for root filesystem
    df / | tail -1 | awk '{print $5}' | sed 's/%//'
}

# Function to get disk usage for specific mount point
get_disk_usage_mount() {
    local mount_point="$1"
    if [ -z "$mount_point" ]; then
        mount_point="/"
    fi
    
    if mountpoint -q "$mount_point" 2>/dev/null; then
        df "$mount_point" | tail -1 | awk '{print $5}' | sed 's/%//'
    else
        echo "0"
    fi
}

# Function to get system load average (1 minute)
get_load_average() {
    uptime | awk -F'load average:' '{print $2}' | awk -F',' '{print $1}' | sed 's/^ *//'
}

# Function to get system uptime in seconds
get_uptime() {
    cat /proc/uptime | awk '{print int($1)}'
}

# Function to check if system is under high load
check_high_load() {
    local load_avg=$(get_load_average)
    local cpu_cores=$(nproc)
    local threshold=$((cpu_cores * 2))  # 2x CPU cores as threshold
    
    # Compare load average with threshold (multiply by 100 to avoid floating point)
    local load_int=$(echo "$load_avg * 100" | bc -l | cut -d. -f1)
    local threshold_int=$((threshold * 100))
    
    if [ "$load_int" -gt "$threshold_int" ]; then
        echo "1"  # High load detected
    else
        echo "0"  # Normal load
    fi
}

# Function to check disk space warning
check_disk_warning() {
    local usage=$(get_disk_usage)
    local warning_threshold=80
    local critical_threshold=90
    
    if [ "$usage" -ge "$critical_threshold" ]; then
        echo "2"  # Critical
    elif [ "$usage" -ge "$warning_threshold" ]; then
        echo "1"  # Warning
    else
        echo "0"  # OK
    fi
}

# Function to check memory warning
check_memory_warning() {
    local usage=$(get_memory_usage)
    local warning_threshold=80
    local critical_threshold=90
    
    if [ "$usage" -ge "$critical_threshold" ]; then
        echo "2"  # Critical
    elif [ "$usage" -ge "$warning_threshold" ]; then
        echo "1"  # Warning
    else
        echo "0"  # OK
    fi
}

# Function to check CPU warning
check_cpu_warning() {
    local usage=$(get_cpu_usage)
    local warning_threshold=80
    local critical_threshold=90
    
    if [ "$usage" -ge "$critical_threshold" ]; then
        echo "2"  # Critical
    elif [ "$usage" -ge "$warning_threshold" ]; then
        echo "1"  # Warning
    else
        echo "0"  # OK
    fi
}

# Function to get system temperature (if available)
get_temperature() {
    # Try to get temperature from thermal zones
    local temp_file=""
    
    # Check for thermal zones
    if [ -d "/sys/class/thermal" ]; then
        for zone in /sys/class/thermal/thermal_zone*/temp; do
            if [ -r "$zone" ]; then
                local temp=$(cat "$zone" 2>/dev/null)
                if [ -n "$temp" ] && [ "$temp" -gt 0 ]; then
                    # Convert from millidegrees to degrees
                    echo $((temp / 1000))
                    return
                fi
            fi
        done
    fi
    
    # Fallback: try sensors command if available
    if command -v sensors &> /dev/null; then
        sensors 2>/dev/null | grep -E 'Core 0|Package id 0' | head -1 | grep -o '[0-9.]*°C' | grep -o '[0-9.]*' | head -1
    else
        echo "0"
    fi
}

# Function to check if system is overheating
check_temperature_warning() {
    local temp=$(get_temperature)
    local warning_threshold=70
    local critical_threshold=80
    
    if [ "$temp" -ge "$critical_threshold" ]; then
        echo "2"  # Critical
    elif [ "$temp" -ge "$warning_threshold" ]; then
        echo "1"  # Warning
    else
        echo "0"  # OK
    fi
}

# Function to get network interface status
get_network_status() {
    local interface="$1"
    if [ -z "$interface" ]; then
        # Get the primary network interface
        interface=$(ip route | grep default | awk '{print $5}' | head -1)
    fi
    
    # Try to read from host-mounted path first, then container path
    local operstate_file="/host/sys/class/net/$interface/operstate"
    if [ ! -f "$operstate_file" ]; then
        operstate_file="/sys/class/net/$interface/operstate"
    fi
    
    if [ -n "$interface" ] && [ -f "$operstate_file" ]; then
        local operstate=$(cat "$operstate_file" 2>/dev/null)
        if [ "$operstate" = "up" ]; then
            echo "1"
        else
            echo "0"
        fi
    else
        echo "0"
    fi
}

# Function to get network interface incoming traffic (bytes)
get_network_in() {
    local interface="$1"
    if [ -z "$interface" ]; then
        interface="enp86s0"  # Default to enp86s0 for GC-ARO-002-2
    fi
    
    # Try to read from host-mounted path first, then container path
    local rx_file="/host/sys/class/net/$interface/statistics/rx_bytes"
    if [ ! -f "$rx_file" ]; then
        rx_file="/sys/class/net/$interface/statistics/rx_bytes"
    fi
    
    if [ -n "$interface" ] && [ -f "$rx_file" ]; then
        cat "$rx_file" 2>/dev/null
    else
        echo "0"
    fi
}

# Function to get network interface outgoing traffic (bytes)
get_network_out() {
    local interface="$1"
    if [ -z "$interface" ]; then
        interface="enp86s0"  # Default to enp86s0 for GC-ARO-002-2
    fi
    
    # Try to read from host-mounted path first, then container path
    local tx_file="/host/sys/class/net/$interface/statistics/tx_bytes"
    if [ ! -f "$tx_file" ]; then
        tx_file="/sys/class/net/$interface/statistics/tx_bytes"
    fi
    
    if [ -n "$interface" ] && [ -f "$tx_file" ]; then
        cat "$tx_file" 2>/dev/null
    else
        echo "0"
    fi
}

# Main execution
case "${1:-help}" in
    "cpu_usage")
        get_cpu_usage
        ;;
    "memory_usage")
        get_memory_usage
        ;;
    "disk_usage")
        get_disk_usage
        ;;
    "disk_usage_mount")
        get_disk_usage_mount "$2"
        ;;
    "load_average")
        get_load_average
        ;;
    "uptime")
        get_uptime
        ;;
    "temperature")
        get_temperature
        ;;
    "network_status")
        get_network_status "$2"
        ;;
    "network_in")
        get_network_in "$2"
        ;;
    "network_out")
        get_network_out "$2"
        ;;
    "cpu_warning")
        check_cpu_warning
        ;;
    "memory_warning")
        check_memory_warning
        ;;
    "disk_warning")
        check_disk_warning
        ;;
    "temperature_warning")
        check_temperature_warning
        ;;
    "high_load")
        check_high_load
        ;;
    "system_health")
        # Overall system health score (0-100)
        cpu_usage=$(get_cpu_usage)
        memory_usage=$(get_memory_usage)
        disk_usage=$(get_disk_usage)
        load_avg=$(get_load_average)
        cpu_cores=$(nproc)
        
        # Calculate health score (lower is better)
        health_score=100
        
        # Deduct points for high usage
        health_score=$((health_score - (cpu_usage / 2)))
        health_score=$((health_score - (memory_usage / 2)))
        health_score=$((health_score - (disk_usage / 2)))
        
        # Deduct points for high load
        load_ratio=$(echo "scale=2; $load_avg / $cpu_cores" | awk '{print $1}')
        if (( $(echo "$load_ratio > 2" | awk '{print ($1 > 2)}') )); then
            health_score=$((health_score - 20))
        elif (( $(echo "$load_ratio > 1" | awk '{print ($1 > 1)}') )); then
            health_score=$((health_score - 10))
        fi
        
        # Ensure score is not negative
        if [ "$health_score" -lt 0 ]; then
            health_score=0
        fi
        
        echo $health_score
        ;;
    "help"|*)
        echo "Usage: $0 [metric_name] [optional_parameter]"
        echo ""
        echo "Available metrics:"
        echo "  cpu_usage          - CPU usage percentage"
        echo "  memory_usage       - Memory usage percentage"
        echo "  disk_usage         - Root filesystem usage percentage"
        echo "  disk_usage_mount   - Usage for specific mount point"
        echo "  load_average       - System load average (1 minute)"
        echo "  uptime             - System uptime in seconds"
        echo "  temperature        - System temperature in Celsius"
        echo "  network_status     - Network interface status (1=up, 0=down)"
        echo "  network_in         - Network interface incoming traffic (bytes)"
        echo "  network_out        - Network interface outgoing traffic (bytes)"
        echo "  cpu_warning        - CPU warning level (0=OK, 1=Warning, 2=Critical)"
        echo "  memory_warning     - Memory warning level"
        echo "  disk_warning       - Disk warning level"
        echo "  temperature_warning - Temperature warning level"
        echo "  high_load          - High load detection (1=high, 0=normal)"
        echo "  system_health      - Overall system health score (0-100)"
        echo ""
        echo "Examples:"
        echo "  $0 cpu_usage"
        echo "  $0 disk_usage_mount /var"
        echo "  $0 network_status eth0"
        echo "  $0 network_in enp86s0"
        echo "  $0 network_out enp86s0"
        ;;
esac
