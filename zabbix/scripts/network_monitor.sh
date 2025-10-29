#!/bin/bash

# Network Interface Monitoring Script for Zabbix
# This script monitors network interface traffic for enp86s0
# Usage: ./network_monitor.sh [metric_name] [interface_name]

# Function to log messages
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >&2
}

# Function to get network interface statistics
get_network_stats() {
    local interface="$1"
    if [ -z "$interface" ]; then
        interface="enp86s0"  # Default to enp86s0 as per your requirement
    fi
    
    # Read from /proc/net/dev (works with host networking)
    if [ -f "/proc/net/dev" ]; then
        local line=$(grep "^[[:space:]]*$interface:" /proc/net/dev)
        if [ -n "$line" ]; then
            # Parse /proc/net/dev format: interface: rx_bytes rx_packets rx_errs rx_drop ... tx_bytes tx_packets tx_errs tx_drop
            local rx_bytes=$(echo "$line" | awk '{print $2}')
            local rx_packets=$(echo "$line" | awk '{print $3}')
            local rx_errors=$(echo "$line" | awk '{print $4}')
            local rx_dropped=$(echo "$line" | awk '{print $5}')
            local tx_bytes=$(echo "$line" | awk '{print $10}')
            local tx_packets=$(echo "$line" | awk '{print $11}')
            local tx_errors=$(echo "$line" | awk '{print $12}')
            local tx_dropped=$(echo "$line" | awk '{print $13}')
            
            echo "rx_bytes:$rx_bytes tx_bytes:$tx_bytes rx_packets:$rx_packets tx_packets:$tx_packets rx_errors:$rx_errors tx_errors:$tx_errors rx_dropped:$rx_dropped tx_dropped:$tx_dropped"
            return 0
        fi
    fi
    
    # Fallback to /sys/class/net (if available)
    local stats_file="/sys/class/net/$interface/statistics"
    if [ -d "$stats_file" ]; then
        local rx_bytes=$(cat "$stats_file/rx_bytes" 2>/dev/null || echo "0")
        local tx_bytes=$(cat "$stats_file/tx_bytes" 2>/dev/null || echo "0")
        local rx_packets=$(cat "$stats_file/rx_packets" 2>/dev/null || echo "0")
        local tx_packets=$(cat "$stats_file/tx_packets" 2>/dev/null || echo "0")
        local rx_errors=$(cat "$stats_file/rx_errors" 2>/dev/null || echo "0")
        local tx_errors=$(cat "$stats_file/tx_errors" 2>/dev/null || echo "0")
        local rx_dropped=$(cat "$stats_file/rx_dropped" 2>/dev/null || echo "0")
        local tx_dropped=$(cat "$stats_file/tx_dropped" 2>/dev/null || echo "0")
        
        echo "rx_bytes:$rx_bytes tx_bytes:$tx_bytes rx_packets:$rx_packets tx_packets:$tx_packets rx_errors:$rx_errors tx_errors:$tx_errors rx_dropped:$rx_dropped tx_dropped:$tx_dropped"
        return 0
    fi
    
    log_message "ERROR: Interface $interface not found"
    echo "0"
    return 1
}

# Function to get network interface bytes received
get_network_rx_bytes() {
    local interface="$1"
    if [ -z "$interface" ]; then
        interface="enp86s0"
    fi
    
    # Read from /proc/net/dev (works with host networking)
    if [ -f "/proc/net/dev" ]; then
        local line=$(grep "^[[:space:]]*$interface:" /proc/net/dev)
        if [ -n "$line" ]; then
            echo "$line" | awk '{print $2}'
            return 0
        fi
    fi
    
    # Fallback to /sys/class/net (if available)
    local stats_file="/sys/class/net/$interface/statistics"
    if [ -d "$stats_file" ]; then
        cat "$stats_file/rx_bytes" 2>/dev/null || echo "0"
        return 0
    fi
    
    log_message "ERROR: Interface $interface not found"
    echo "0"
    return 1
}

# Function to get network interface bytes sent
get_network_tx_bytes() {
    local interface="$1"
    if [ -z "$interface" ]; then
        interface="enp86s0"
    fi
    
    # Read from /proc/net/dev (works with host networking)
    if [ -f "/proc/net/dev" ]; then
        local line=$(grep "^[[:space:]]*$interface:" /proc/net/dev)
        if [ -n "$line" ]; then
            echo "$line" | awk '{print $10}'
            return 0
        fi
    fi
    
    # Fallback to /sys/class/net (if available)
    local stats_file="/sys/class/net/$interface/statistics"
    if [ -d "$stats_file" ]; then
        cat "$stats_file/tx_bytes" 2>/dev/null || echo "0"
        return 0
    fi
    
    log_message "ERROR: Interface $interface not found"
    echo "0"
    return 1
}

# Function to get network interface packets received
get_network_rx_packets() {
    local interface="$1"
    if [ -z "$interface" ]; then
        interface="enp86s0"
    fi
    
    # Try to read from /proc/net/dev first (works in containers)
    if [ -f "/proc/net/dev" ]; then
        local line=$(grep "^[[:space:]]*$interface:" /proc/net/dev)
        if [ -n "$line" ]; then
            echo "$line" | awk '{print $3}'
            return 0
        fi
    fi
    
    # Fallback to /sys/class/net (if available)
    local stats_file="/sys/class/net/$interface/statistics"
    if [ -d "$stats_file" ]; then
        cat "$stats_file/rx_packets" 2>/dev/null || echo "0"
        return 0
    fi
    
    log_message "ERROR: Interface $interface not found"
    echo "0"
    return 1
}

# Function to get network interface packets sent
get_network_tx_packets() {
    local interface="$1"
    if [ -z "$interface" ]; then
        interface="enp86s0"
    fi
    
    # Try to read from /proc/net/dev first (works in containers)
    if [ -f "/proc/net/dev" ]; then
        local line=$(grep "^[[:space:]]*$interface:" /proc/net/dev)
        if [ -n "$line" ]; then
            echo "$line" | awk '{print $11}'
            return 0
        fi
    fi
    
    # Fallback to /sys/class/net (if available)
    local stats_file="/sys/class/net/$interface/statistics"
    if [ -d "$stats_file" ]; then
        cat "$stats_file/tx_packets" 2>/dev/null || echo "0"
        return 0
    fi
    
    log_message "ERROR: Interface $interface not found"
    echo "0"
    return 1
}

# Function to get network interface errors received
get_network_rx_errors() {
    local interface="$1"
    if [ -z "$interface" ]; then
        interface="enp86s0"
    fi
    
    local stats_file="/sys/class/net/$interface/statistics"
    
    if [ ! -d "$stats_file" ]; then
        log_message "ERROR: Interface $interface not found"
        echo "0"
        return 1
    fi
    
    cat "$stats_file/rx_errors" 2>/dev/null || echo "0"
}

# Function to get network interface errors sent
get_network_tx_errors() {
    local interface="$1"
    if [ -z "$interface" ]; then
        interface="enp86s0"
    fi
    
    local stats_file="/sys/class/net/$interface/statistics"
    
    if [ ! -d "$stats_file" ]; then
        log_message "ERROR: Interface $interface not found"
        echo "0"
        return 1
    fi
    
    cat "$stats_file/tx_errors" 2>/dev/null || echo "0"
}

# Function to get network interface dropped packets received
get_network_rx_dropped() {
    local interface="$1"
    if [ -z "$interface" ]; then
        interface="enp86s0"
    fi
    
    local stats_file="/sys/class/net/$interface/statistics"
    
    if [ ! -d "$stats_file" ]; then
        log_message "ERROR: Interface $interface not found"
        echo "0"
        return 1
    fi
    
    cat "$stats_file/rx_dropped" 2>/dev/null || echo "0"
}

# Function to get network interface dropped packets sent
get_network_tx_dropped() {
    local interface="$1"
    if [ -z "$interface" ]; then
        interface="enp86s0"
    fi
    
    local stats_file="/sys/class/net/$interface/statistics"
    
    if [ ! -d "$stats_file" ]; then
        log_message "ERROR: Interface $interface not found"
        echo "0"
        return 1
    fi
    
    cat "$stats_file/tx_dropped" 2>/dev/null || echo "0"
}

# Function to get network interface speed
get_network_speed() {
    local interface="$1"
    if [ -z "$interface" ]; then
        interface="enp86s0"
    fi
    
    local speed_file="/sys/class/net/$interface/speed"
    
    if [ ! -f "$speed_file" ]; then
        log_message "ERROR: Speed file for interface $interface not found"
        echo "0"
        return 1
    fi
    
    cat "$speed_file" 2>/dev/null || echo "0"
}

# Function to get network interface status
get_network_status() {
    local interface="$1"
    if [ -z "$interface" ]; then
        interface="enp86s0"
    fi
    
    local operstate_file="/sys/class/net/$interface/operstate"
    
    if [ ! -f "$operstate_file" ]; then
        log_message "ERROR: Operstate file for interface $interface not found"
        echo "0"
        return 1
    fi
    
    local operstate=$(cat "$operstate_file" 2>/dev/null)
    if [ "$operstate" = "up" ]; then
        echo "1"
    else
        echo "0"
    fi
}

# Function to calculate network interface rate (bits per second)
# This function maintains state in a temporary file to calculate rate
get_network_rx_rate() {
    local interface="$1"
    if [ -z "$interface" ]; then
        interface="enp86s0"
    fi
    
    # State file path (in persistent directory for Zabbix agent)
    local state_dir="/var/lib/zabbix/network_monitor_state"
    mkdir -p "$state_dir"
    local state_file="${state_dir}/${interface}_rx.state"
    local current_time=$(date +%s)
    local current_bytes
    
    # Get current bytes value
    current_bytes=$(get_network_rx_bytes "$interface")
    if [ "$current_bytes" = "0" ] || [ -z "$current_bytes" ]; then
        echo "0"
        return 1
    fi
    
    # Convert bytes to bits
    local current_bits=$((current_bytes * 8))
    
    # Read previous state if exists
    if [ -f "$state_file" ]; then
        local prev_bits prev_time
        read prev_bits prev_time < "$state_file"
        
        if [ -n "$prev_bits" ] && [ -n "$prev_time" ] && [ "$prev_time" -lt "$current_time" ]; then
            local time_diff=$((current_time - prev_time))
            if [ "$time_diff" -gt 0 ]; then
                local bit_diff=$((current_bits - prev_bits))
                # Handle counter wrap-around (64-bit counter, but use large threshold)
                # If negative difference is too large, assume wrap-around
                if [ "$bit_diff" -lt -1000000000 ]; then
                    # Assume 64-bit counter wrap-around, calculate properly
                    bit_diff=$((current_bits - prev_bits + 18446744073709551615))
                elif [ "$bit_diff" -lt 0 ]; then
                    # Small negative might be legitimate (counter reset), set to 0
                    bit_diff=0
                fi
                local rate=$((bit_diff / time_diff))
                # Save current state
                echo "$current_bits $current_time" > "$state_file"
                echo "$rate"
                return 0
            fi
        fi
    fi
    
    # First run or invalid state - save current state and return 0
    echo "$current_bits $current_time" > "$state_file"
    echo "0"
    return 0
}

# Function to calculate network interface TX rate (bits per second)
get_network_tx_rate() {
    local interface="$1"
    if [ -z "$interface" ]; then
        interface="enp86s0"
    fi
    
    # State file path (in persistent directory for Zabbix agent)
    local state_dir="/var/lib/zabbix/network_monitor_state"
    mkdir -p "$state_dir"
    local state_file="${state_dir}/${interface}_tx.state"
    local current_time=$(date +%s)
    local current_bytes
    
    # Get current bytes value
    current_bytes=$(get_network_tx_bytes "$interface")
    if [ "$current_bytes" = "0" ] || [ -z "$current_bytes" ]; then
        echo "0"
        return 1
    fi
    
    # Convert bytes to bits
    local current_bits=$((current_bytes * 8))
    
    # Read previous state if exists
    if [ -f "$state_file" ]; then
        local prev_bits prev_time
        read prev_bits prev_time < "$state_file"
        
        if [ -n "$prev_bits" ] && [ -n "$prev_time" ] && [ "$prev_time" -lt "$current_time" ]; then
            local time_diff=$((current_time - prev_time))
            if [ "$time_diff" -gt 0 ]; then
                local bit_diff=$((current_bits - prev_bits))
                # Handle counter wrap-around (64-bit counter, but use large threshold)
                if [ "$bit_diff" -lt -1000000000 ]; then
                    # Assume 64-bit counter wrap-around
                    bit_diff=$((current_bits - prev_bits + 18446744073709551615))
                elif [ "$bit_diff" -lt 0 ]; then
                    # Small negative might be legitimate (counter reset), set to 0
                    bit_diff=0
                fi
                local rate=$((bit_diff / time_diff))
                # Save current state
                echo "$current_bits $current_time" > "$state_file"
                echo "$rate"
                return 0
            fi
        fi
    fi
    
    # First run or invalid state - save current state and return 0
    echo "$current_bits $current_time" > "$state_file"
    echo "0"
    return 0
}

# Main execution
case "${1:-help}" in
    "rx_bytes")
        get_network_rx_bytes "$2"
        ;;
    "tx_bytes")
        get_network_tx_bytes "$2"
        ;;
    "rx_packets")
        get_network_rx_packets "$2"
        ;;
    "tx_packets")
        get_network_tx_packets "$2"
        ;;
    "rx_errors")
        get_network_rx_errors "$2"
        ;;
    "tx_errors")
        get_network_tx_errors "$2"
        ;;
    "rx_dropped")
        get_network_rx_dropped "$2"
        ;;
    "tx_dropped")
        get_network_tx_dropped "$2"
        ;;
    "speed")
        get_network_speed "$2"
        ;;
    "status")
        get_network_status "$2"
        ;;
    "rx_rate")
        get_network_rx_rate "$2"
        ;;
    "tx_rate")
        get_network_tx_rate "$2"
        ;;
    "stats")
        get_network_stats "$2"
        ;;
    "help"|*)
        echo "Usage: $0 [metric_name] [interface_name]"
        echo ""
        echo "Available metrics:"
        echo "  rx_bytes      - Bytes received"
        echo "  tx_bytes      - Bytes sent"
        echo "  rx_packets    - Packets received"
        echo "  tx_packets    - Packets sent"
        echo "  rx_errors     - Receive errors"
        echo "  tx_errors     - Transmit errors"
        echo "  rx_dropped    - Receive dropped packets"
        echo "  tx_dropped    - Transmit dropped packets"
        echo "  speed         - Interface speed (Mbps)"
        echo "  status        - Interface status (1=up, 0=down)"
        echo "  rx_rate       - Receive rate (bits per second)"
        echo "  tx_rate       - Transmit rate (bits per second)"
        echo "  stats         - All statistics"
        echo ""
        echo "Examples:"
        echo "  $0 rx_bytes enp86s0"
        echo "  $0 tx_bytes enp86s0"
        echo "  $0 status enp86s0"
        echo ""
        echo "Default interface: enp86s0"
        ;;
esac
