#!/bin/bash

# Power Status Monitoring Script for Zabbix
# This script monitors UPS, battery status, and power-related events
# Usage: ./power_monitor.sh [metric_name]

# Function to log messages
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >&2
}

# Function to check if system is on battery power
check_battery_power() {
    # Check if running on battery (for laptops)
    if [ -d "/sys/class/power_supply" ]; then
        # Look for battery power supplies
        for supply in /sys/class/power_supply/*; do
            if [ -d "$supply" ]; then
                local type=$(cat "$supply/type" 2>/dev/null)
                local status=$(cat "$supply/status" 2>/dev/null)
                
                if [ "$type" = "Battery" ] && [ "$status" = "Discharging" ]; then
                    echo "1"  # On battery
                    return
                fi
            fi
        done
    fi
    
    # Check for UPS status using upower (if available)
    if command -v upower &> /dev/null; then
        local ups_status=$(upower -d | grep -i "ups\|battery" | grep -i "discharging" | wc -l)
        if [ "$ups_status" -gt 0 ]; then
            echo "1"  # On battery/UPS
            return
        fi
    fi
    
    # Check for UPS using nut (Network UPS Tools)
    if command -v upsc &> /dev/null; then
        local ups_list=$(upsc -l 2>/dev/null)
        if [ -n "$ups_list" ]; then
            for ups in $ups_list; do
                local ups_status=$(upsc "$ups" ups.status 2>/dev/null)
                if echo "$ups_status" | grep -qi "OB\|OLB\|LB"; then
                    echo "1"  # On battery
                    return
                fi
            done
        fi
    fi
    
    echo "0"  # On AC power
}

# Function to get battery charge percentage
get_battery_charge() {
    # Check laptop battery
    if [ -d "/sys/class/power_supply" ]; then
        for supply in /sys/class/power_supply/*; do
            if [ -d "$supply" ]; then
                local type=$(cat "$supply/type" 2>/dev/null)
                if [ "$type" = "Battery" ]; then
                    local capacity=$(cat "$supply/capacity" 2>/dev/null)
                    if [ -n "$capacity" ]; then
                        echo "$capacity"
                        return
                    fi
                fi
            fi
        done
    fi
    
    # Check UPS battery using upower
    if command -v upower &> /dev/null; then
        local battery_info=$(upower -d | grep -A 5 -i "battery\|ups" | grep -i "percentage" | head -1)
        if [ -n "$battery_info" ]; then
            echo "$battery_info" | grep -o '[0-9]*%' | sed 's/%//'
            return
        fi
    fi
    
    # Check UPS battery using nut
    if command -v upsc &> /dev/null; then
        local ups_list=$(upsc -l 2>/dev/null)
        if [ -n "$ups_list" ]; then
            for ups in $ups_list; do
                local battery_charge=$(upsc "$ups" battery.charge 2>/dev/null)
                if [ -n "$battery_charge" ]; then
                    echo "$battery_charge"
                    return
                fi
            done
        fi
    fi
    
    echo "0"
}

# Function to get UPS runtime remaining (in minutes)
get_ups_runtime() {
    # Check UPS runtime using nut
    if command -v upsc &> /dev/null; then
        local ups_list=$(upsc -l 2>/dev/null)
        if [ -n "$ups_list" ]; then
            for ups in $ups_list; do
                local runtime=$(upsc "$ups" battery.runtime 2>/dev/null)
                if [ -n "$runtime" ]; then
                    # Convert seconds to minutes
                    echo $((runtime / 60))
                    return
                fi
            done
        fi
    fi
    
    # Check laptop battery time remaining
    if [ -d "/sys/class/power_supply" ]; then
        for supply in /sys/class/power_supply/*; do
            if [ -d "$supply" ]; then
                local type=$(cat "$supply/type" 2>/dev/null)
                if [ "$type" = "Battery" ]; then
                    local time_to_empty=$(cat "$supply/time_to_empty_now" 2>/dev/null)
                    if [ -n "$time_to_empty" ] && [ "$time_to_empty" -gt 0 ]; then
                        # Convert seconds to minutes
                        echo $((time_to_empty / 60))
                        return
                    fi
                fi
            fi
        done
    fi
    
    echo "0"
}

# Function to check power supply status
get_power_supply_status() {
    # Check AC adapter status
    if [ -d "/sys/class/power_supply" ]; then
        for supply in /sys/class/power_supply/*; do
            if [ -d "$supply" ]; then
                local type=$(cat "$supply/type" 2>/dev/null)
                if [ "$type" = "Mains" ] || [ "$type" = "USB" ]; then
                    local online=$(cat "$supply/online" 2>/dev/null)
                    if [ "$online" = "1" ]; then
                        echo "1"  # AC power connected
                        return
                    fi
                fi
            fi
        done
    fi
    
    # Check UPS status
    if command -v upsc &> /dev/null; then
        local ups_list=$(upsc -l 2>/dev/null)
        if [ -n "$ups_list" ]; then
            for ups in $ups_list; do
                local ups_status=$(upsc "$ups" ups.status 2>/dev/null)
                if echo "$ups_status" | grep -qi "OL"; then
                    echo "1"  # UPS online (AC power)
                    return
                fi
            done
        fi
    fi
    
    echo "0"  # No AC power detected
}

# Function to get power consumption (if available)
get_power_consumption() {
    # Try to get power consumption from power supply
    if [ -d "/sys/class/power_supply" ]; then
        for supply in /sys/class/power_supply/*; do
            if [ -d "$supply" ]; then
                local power_now=$(cat "$supply/power_now" 2>/dev/null)
                if [ -n "$power_now" ] && [ "$power_now" -gt 0 ]; then
                    # Convert from microwatts to watts
                    echo $((power_now / 1000000))
                    return
                fi
            fi
        done
    fi
    
    echo "0"
}

# Function to check for power events in system logs
check_power_events() {
    local events=0
    
    # Check for power-related events in the last hour
    local one_hour_ago=$(date -d '1 hour ago' '+%b %d %H:%M')
    
    # Check systemd journal for power events
    if command -v journalctl &> /dev/null; then
        local power_events_count=$(journalctl --since "1 hour ago" | grep -i "power\|battery\|ups\|acpi" | wc -l)
        events=$((events + power_events_count))
    fi
    
    # Check kernel messages for power events
    if [ -f "/var/log/kern.log" ]; then
        local kernel_events=$(grep -i "power\|battery\|ups\|acpi" /var/log/kern.log | grep "$one_hour_ago" | wc -l)
        events=$((events + kernel_events))
    fi
    
    echo "$events"
}

# Function to check battery health
get_battery_health() {
    # Check battery health for laptops
    if [ -d "/sys/class/power_supply" ]; then
        for supply in /sys/class/power_supply/*; do
            if [ -d "$supply" ]; then
                local type=$(cat "$supply/type" 2>/dev/null)
                if [ "$type" = "Battery" ]; then
                    local health=$(cat "$supply/health" 2>/dev/null)
                    case "$health" in
                        "Good")
                            echo "100"
                            ;;
                        "Fair")
                            echo "75"
                            ;;
                        "Poor")
                            echo "50"
                            ;;
                        "Unknown")
                            echo "0"
                            ;;
                        *)
                            echo "0"
                            ;;
                    esac
                    return
                fi
            fi
        done
    fi
    
    echo "0"
}

# Function to check power warning levels
check_power_warning() {
    local battery_charge=$(get_battery_charge)
    local on_battery=$(check_battery_power)
    
    # Only check warnings if on battery
    if [ "$on_battery" = "1" ]; then
        if [ "$battery_charge" -le 10 ]; then
            echo "2"  # Critical
        elif [ "$battery_charge" -le 20 ]; then
            echo "1"  # Warning
        else
            echo "0"  # OK
        fi
    else
        echo "0"  # On AC power, no warning
    fi
}

# Function to get UPS status details
get_ups_status() {
    if command -v upsc &> /dev/null; then
        local ups_list=$(upsc -l 2>/dev/null)
        if [ -n "$ups_list" ]; then
            for ups in $ups_list; do
                local ups_status=$(upsc "$ups" ups.status 2>/dev/null)
                if [ -n "$ups_status" ]; then
                    echo "$ups_status"
                    return
                fi
            done
        fi
    fi
    
    echo "unknown"
}

# Main execution
case "${1:-help}" in
    "battery_power")
        check_battery_power
        ;;
    "battery_charge")
        get_battery_charge
        ;;
    "ups_runtime")
        get_ups_runtime
        ;;
    "power_supply_status")
        get_power_supply_status
        ;;
    "power_consumption")
        get_power_consumption
        ;;
    "power_events")
        check_power_events
        ;;
    "battery_health")
        get_battery_health
        ;;
    "power_warning")
        check_power_warning
        ;;
    "ups_status")
        get_ups_status
        ;;
    "power_summary")
        # Return a summary of power status
        local on_battery=$(check_battery_power)
        local battery_charge=$(get_battery_charge)
        local power_supply=$(get_power_supply_status)
        local runtime=$(get_ups_runtime)
        
        echo "battery:$on_battery,charge:$battery_charge,ac:$power_supply,runtime:$runtime"
        ;;
    "help"|*)
        echo "Usage: $0 [metric_name]"
        echo ""
        echo "Available metrics:"
        echo "  battery_power       - Is system on battery power (1=yes, 0=no)"
        echo "  battery_charge      - Battery charge percentage"
        echo "  ups_runtime         - UPS runtime remaining in minutes"
        echo "  power_supply_status - AC power supply status (1=connected, 0=disconnected)"
        echo "  power_consumption   - Current power consumption in watts"
        echo "  power_events        - Number of power-related events in last hour"
        echo "  battery_health      - Battery health percentage"
        echo "  power_warning       - Power warning level (0=OK, 1=Warning, 2=Critical)"
        echo "  ups_status          - UPS status string"
        echo "  power_summary       - Complete power status summary"
        echo ""
        echo "Examples:"
        echo "  $0 battery_power"
        echo "  $0 battery_charge"
        echo "  $0 ups_runtime"
        ;;
esac
