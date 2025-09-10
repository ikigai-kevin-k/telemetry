#!/bin/bash

# System Health Check Script for Zabbix
# This script performs comprehensive system health checks
# Usage: ./health_check.sh [check_type]

# Function to log messages
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >&2
}

# Function to check system critical services
check_critical_services() {
    local failed_services=0
    local critical_services=("ssh" "systemd-resolved" "systemd-networkd")
    
    for service in "${critical_services[@]}"; do
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            log_message "Service $service is running"
        else
            log_message "WARNING: Service $service is not running"
            failed_services=$((failed_services + 1))
        fi
    done
    
    echo "$failed_services"
}

# Function to check disk space for critical directories
check_critical_disk_space() {
    local critical_dirs=("/" "/var" "/tmp" "/home")
    local failed_dirs=0
    
    for dir in "${critical_dirs[@]}"; do
        if [ -d "$dir" ]; then
            local usage=$(df "$dir" | tail -1 | awk '{print $5}' | sed 's/%//')
            if [ "$usage" -gt 90 ]; then
                log_message "CRITICAL: $dir is ${usage}% full"
                failed_dirs=$((failed_dirs + 1))
            elif [ "$usage" -gt 80 ]; then
                log_message "WARNING: $dir is ${usage}% full"
            fi
        fi
    done
    
    echo "$failed_dirs"
}

# Function to check memory usage
check_memory_usage() {
    local mem_total=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    local mem_available=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
    
    if [ -z "$mem_available" ]; then
        local mem_free=$(grep MemFree /proc/meminfo | awk '{print $2}')
        local buffers=$(grep Buffers /proc/meminfo | awk '{print $2}')
        local cached=$(grep -E '^Cached:' /proc/meminfo | awk '{print $2}')
        mem_available=$((mem_free + buffers + cached))
    fi
    
    local mem_used=$((mem_total - mem_available))
    local usage_percent=$((mem_used * 100 / mem_total))
    
    if [ "$usage_percent" -gt 95 ]; then
        echo "2"  # Critical
    elif [ "$usage_percent" -gt 85 ]; then
        echo "1"  # Warning
    else
        echo "0"  # OK
    fi
}

# Function to check CPU load
check_cpu_load() {
    local load_avg=$(uptime | awk -F'load average:' '{print $2}' | awk -F',' '{print $1}' | sed 's/^ *//')
    local cpu_cores=$(nproc)
    local load_ratio=$(echo "scale=2; $load_avg / $cpu_cores" | bc -l)
    
    if (( $(echo "$load_ratio > 3" | bc -l) )); then
        echo "2"  # Critical
    elif (( $(echo "$load_ratio > 2" | bc -l) )); then
        echo "1"  # Warning
    else
        echo "0"  # OK
    fi
}

# Function to check network connectivity
check_network_connectivity() {
    local failed_checks=0
    
    # Check if primary network interface is up
    local primary_interface=$(ip route | grep default | awk '{print $5}' | head -1)
    if [ -n "$primary_interface" ]; then
        local operstate=$(cat "/sys/class/net/$primary_interface/operstate" 2>/dev/null)
        if [ "$operstate" != "up" ]; then
            log_message "WARNING: Primary network interface $primary_interface is not up"
            failed_checks=$((failed_checks + 1))
        fi
    fi
    
    # Check DNS resolution
    if ! nslookup google.com &>/dev/null; then
        log_message "WARNING: DNS resolution failed"
        failed_checks=$((failed_checks + 1))
    fi
    
    # Check internet connectivity
    if ! ping -c 1 -W 5 8.8.8.8 &>/dev/null; then
        log_message "WARNING: Internet connectivity failed"
        failed_checks=$((failed_checks + 1))
    fi
    
    echo "$failed_checks"
}

# Function to check system temperature
check_system_temperature() {
    local temp=0
    
    # Try to get temperature from thermal zones
    if [ -d "/sys/class/thermal" ]; then
        for zone in /sys/class/thermal/thermal_zone*/temp; do
            if [ -r "$zone" ]; then
                local zone_temp=$(cat "$zone" 2>/dev/null)
                if [ -n "$zone_temp" ] && [ "$zone_temp" -gt 0 ]; then
                    temp=$((zone_temp / 1000))
                    break
                fi
            fi
        done
    fi
    
    if [ "$temp" -gt 80 ]; then
        echo "2"  # Critical
    elif [ "$temp" -gt 70 ]; then
        echo "1"  # Warning
    else
        echo "0"  # OK
    fi
}

# Function to check system logs for errors
check_system_logs() {
    local error_count=0
    
    # Check for critical errors in systemd journal (last hour)
    if command -v journalctl &> /dev/null; then
        local critical_errors=$(journalctl --since "1 hour ago" --priority=err | wc -l)
        error_count=$((error_count + critical_errors))
    fi
    
    # Check for kernel errors
    if [ -f "/var/log/kern.log" ]; then
        local kernel_errors=$(grep -i "error\|fail\|critical" /var/log/kern.log | tail -20 | wc -l)
        error_count=$((error_count + kernel_errors))
    fi
    
    # Check for system errors
    if [ -f "/var/log/syslog" ]; then
        local syslog_errors=$(grep -i "error\|fail\|critical" /var/log/syslog | tail -20 | wc -l)
        error_count=$((error_count + syslog_errors))
    fi
    
    if [ "$error_count" -gt 50 ]; then
        echo "2"  # Critical
    elif [ "$error_count" -gt 20 ]; then
        echo "1"  # Warning
    else
        echo "0"  # OK
    fi
}

# Function to check file system integrity
check_filesystem_integrity() {
    local failed_checks=0
    
    # Check for read-only file systems
    local readonly_fs=$(mount | grep "ro," | wc -l)
    if [ "$readonly_fs" -gt 0 ]; then
        log_message "WARNING: Found $readonly_fs read-only file systems"
        failed_checks=$((failed_checks + 1))
    fi
    
    # Check for file systems with errors
    local fs_errors=$(dmesg | grep -i "filesystem\|ext4\|xfs" | grep -i "error\|corrupt" | tail -5 | wc -l)
    if [ "$fs_errors" -gt 0 ]; then
        log_message "WARNING: Found $fs_errors file system errors"
        failed_checks=$((failed_checks + 1))
    fi
    
    echo "$failed_checks"
}

# Function to check swap usage
check_swap_usage() {
    local swap_total=$(grep SwapTotal /proc/meminfo | awk '{print $2}')
    local swap_free=$(grep SwapFree /proc/meminfo | awk '{print $2}')
    
    if [ "$swap_total" -gt 0 ]; then
        local swap_used=$((swap_total - swap_free))
        local swap_usage_percent=$((swap_used * 100 / swap_total))
        
        if [ "$swap_usage_percent" -gt 80 ]; then
            echo "2"  # Critical
        elif [ "$swap_usage_percent" -gt 60 ]; then
            echo "1"  # Warning
        else
            echo "0"  # OK
        fi
    else
        echo "0"  # No swap configured
    fi
}

# Function to check system uptime
check_system_uptime() {
    local uptime_seconds=$(cat /proc/uptime | awk '{print int($1)}')
    local uptime_days=$((uptime_seconds / 86400))
    
    # Check if system was recently rebooted (less than 1 hour)
    if [ "$uptime_seconds" -lt 3600 ]; then
        echo "1"  # Recently rebooted
    else
        echo "0"  # Normal uptime
    fi
}

# Function to perform comprehensive health check
comprehensive_health_check() {
    local total_score=100
    local issues=0
    
    # Check critical services
    local service_issues=$(check_critical_services)
    if [ "$service_issues" -gt 0 ]; then
        total_score=$((total_score - (service_issues * 10)))
        issues=$((issues + service_issues))
    fi
    
    # Check disk space
    local disk_issues=$(check_critical_disk_space)
    if [ "$disk_issues" -gt 0 ]; then
        total_score=$((total_score - (disk_issues * 15)))
        issues=$((issues + disk_issues))
    fi
    
    # Check memory
    local memory_status=$(check_memory_usage)
    if [ "$memory_status" -gt 0 ]; then
        total_score=$((total_score - (memory_status * 10)))
        issues=$((issues + memory_status))
    fi
    
    # Check CPU load
    local cpu_status=$(check_cpu_load)
    if [ "$cpu_status" -gt 0 ]; then
        total_score=$((total_score - (cpu_status * 10)))
        issues=$((issues + cpu_status))
    fi
    
    # Check network
    local network_issues=$(check_network_connectivity)
    if [ "$network_issues" -gt 0 ]; then
        total_score=$((total_score - (network_issues * 15)))
        issues=$((issues + network_issues))
    fi
    
    # Check temperature
    local temp_status=$(check_system_temperature)
    if [ "$temp_status" -gt 0 ]; then
        total_score=$((total_score - (temp_status * 10)))
        issues=$((issues + temp_status))
    fi
    
    # Check logs
    local log_status=$(check_system_logs)
    if [ "$log_status" -gt 0 ]; then
        total_score=$((total_score - (log_status * 5)))
        issues=$((issues + log_status))
    fi
    
    # Check file system
    local fs_issues=$(check_filesystem_integrity)
    if [ "$fs_issues" -gt 0 ]; then
        total_score=$((total_score - (fs_issues * 10)))
        issues=$((issues + fs_issues))
    fi
    
    # Check swap
    local swap_status=$(check_swap_usage)
    if [ "$swap_status" -gt 0 ]; then
        total_score=$((total_score - (swap_status * 5)))
        issues=$((issues + swap_status))
    fi
    
    # Ensure score is not negative
    if [ "$total_score" -lt 0 ]; then
        total_score=0
    fi
    
    echo "$total_score"
}

# Function to get health status summary
get_health_summary() {
    local service_issues=$(check_critical_services)
    local disk_issues=$(check_critical_disk_space)
    local memory_status=$(check_memory_usage)
    local cpu_status=$(check_cpu_load)
    local network_issues=$(check_network_connectivity)
    local temp_status=$(check_system_temperature)
    local log_status=$(check_system_logs)
    local fs_issues=$(check_filesystem_integrity)
    local swap_status=$(check_swap_usage)
    local uptime_status=$(check_system_uptime)
    
    echo "services:$service_issues,disk:$disk_issues,memory:$memory_status,cpu:$cpu_status,network:$network_issues,temp:$temp_status,logs:$log_status,fs:$fs_issues,swap:$swap_status,uptime:$uptime_status"
}

# Main execution
case "${1:-help}" in
    "critical_services")
        check_critical_services
        ;;
    "disk_space")
        check_critical_disk_space
        ;;
    "memory")
        check_memory_usage
        ;;
    "cpu_load")
        check_cpu_load
        ;;
    "network")
        check_network_connectivity
        ;;
    "temperature")
        check_system_temperature
        ;;
    "logs")
        check_system_logs
        ;;
    "filesystem")
        check_filesystem_integrity
        ;;
    "swap")
        check_swap_usage
        ;;
    "uptime")
        check_system_uptime
        ;;
    "comprehensive")
        comprehensive_health_check
        ;;
    "summary")
        get_health_summary
        ;;
    "help"|*)
        echo "Usage: $0 [check_type]"
        echo ""
        echo "Available checks:"
        echo "  critical_services  - Check critical system services"
        echo "  disk_space        - Check critical directory disk space"
        echo "  memory            - Check memory usage (0=OK, 1=Warning, 2=Critical)"
        echo "  cpu_load          - Check CPU load (0=OK, 1=Warning, 2=Critical)"
        echo "  network           - Check network connectivity"
        echo "  temperature       - Check system temperature"
        echo "  logs              - Check system logs for errors"
        echo "  filesystem        - Check file system integrity"
        echo "  swap              - Check swap usage"
        echo "  uptime            - Check if system was recently rebooted"
        echo "  comprehensive     - Overall health score (0-100)"
        echo "  summary           - Complete health status summary"
        echo ""
        echo "Examples:"
        echo "  $0 critical_services"
        echo "  $0 comprehensive"
        echo "  $0 summary"
        ;;
esac
