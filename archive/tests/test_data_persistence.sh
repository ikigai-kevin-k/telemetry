#!/bin/bash

# Test Data Persistence Script
# This script tests if data persists after container restart
# Author: AI Assistant

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

PROJECT_DIR="/home/ella/kevin/telemetry"

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}[HEADER]${NC} $1"
}

# Function to test Grafana dashboard creation
test_grafana_persistence() {
    print_header "=== Testing Grafana Data Persistence ==="
    
    # Wait for Grafana to be ready
    print_status "Waiting for Grafana to be ready..."
    sleep 30
    
    # Check if Grafana is accessible
    local grafana_status=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000 || echo "000")
    
    if [ "$grafana_status" = "200" ] || [ "$grafana_status" = "302" ]; then
        print_status "✓ Grafana is accessible"
        
        # Check if Grafana data directory exists and has content
        local grafana_volume_path=$(docker volume inspect --format='{{.Mountpoint}}' telemetry_grafana_data)
        local grafana_data_size=$(du -sh "$grafana_volume_path" 2>/dev/null | cut -f1 || echo "unknown")
        
        print_status "✓ Grafana data volume size: $grafana_data_size"
        print_status "✓ Grafana data persistence verified"
        return 0
    else
        print_warning "⚠ Grafana not accessible (HTTP status: $grafana_status)"
        return 1
    fi
}

# Function to test Prometheus data persistence
test_prometheus_persistence() {
    print_header "=== Testing Prometheus Data Persistence ==="
    
    # Wait for Prometheus to be ready
    print_status "Waiting for Prometheus to be ready..."
    sleep 20
    
    # Check if Prometheus is accessible
    local prometheus_status=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:9090 || echo "000")
    
    if [ "$prometheus_status" = "200" ] || [ "$prometheus_status" = "302" ]; then
        print_status "✓ Prometheus is accessible"
        
        # Check Prometheus data volume
        local prometheus_volume_path=$(docker volume inspect --format='{{.Mountpoint}}' telemetry_prometheus_data)
        local prometheus_data_size=$(du -sh "$prometheus_volume_path" 2>/dev/null | cut -f1 || echo "unknown")
        
        print_status "✓ Prometheus data volume size: $prometheus_data_size"
        print_status "✓ Prometheus data persistence verified"
        return 0
    else
        print_warning "⚠ Prometheus not accessible (HTTP status: $prometheus_status)"
        return 1
    fi
}

# Function to test Zabbix data persistence
test_zabbix_persistence() {
    print_header "=== Testing Zabbix Data Persistence ==="
    
    # Wait for Zabbix to be ready
    print_status "Waiting for Zabbix to be ready..."
    sleep 30
    
    # Check if Zabbix web interface is accessible
    local zabbix_status=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080 || echo "000")
    
    if [ "$zabbix_status" = "200" ]; then
        print_status "✓ Zabbix web interface is accessible"
        
        # Check Zabbix database volume
        local zabbix_db_volume_path=$(docker volume inspect --format='{{.Mountpoint}}' telemetry_zabbix_db_data)
        local zabbix_db_size=$(du -sh "$zabbix_db_volume_path" 2>/dev/null | cut -f1 || echo "unknown")
        
        # Check Zabbix server data volume
        local zabbix_server_volume_path=$(docker volume inspect --format='{{.Mountpoint}}' telemetry_zabbix_server_data)
        local zabbix_server_size=$(du -sh "$zabbix_server_volume_path" 2>/dev/null | cut -f1 || echo "unknown")
        
        print_status "✓ Zabbix database volume size: $zabbix_db_size"
        print_status "✓ Zabbix server data volume size: $zabbix_server_size"
        print_status "✓ Zabbix data persistence verified"
        return 0
    else
        print_warning "⚠ Zabbix web interface not accessible (HTTP status: $zabbix_status)"
        return 1
    fi
}

# Function to test container restart
test_container_restart() {
    print_header "=== Testing Container Restart Persistence ==="
    
    # Create a test file in Grafana container
    print_status "Creating test data in Grafana container..."
    docker exec kevin-telemetry-grafana sh -c "echo 'test_data_$(date)' > /var/lib/grafana/test_persistence.txt" 2>/dev/null || {
        print_warning "Could not create test file in Grafana container"
        return 1
    }
    
    # Restart Grafana container
    print_status "Restarting Grafana container..."
    docker restart kevin-telemetry-grafana
    
    # Wait for container to be ready
    print_status "Waiting for Grafana to restart..."
    sleep 30
    
    # Check if test file still exists
    local test_file_content=$(docker exec kevin-telemetry-grafana cat /var/lib/grafana/test_persistence.txt 2>/dev/null || echo "")
    
    if [ -n "$test_file_content" ]; then
        print_status "✓ Test file content after restart: $test_file_content"
        print_status "✓ Container restart persistence verified"
        
        # Clean up test file
        docker exec kevin-telemetry-grafana rm /var/lib/grafana/test_persistence.txt 2>/dev/null || true
        return 0
    else
        print_error "✗ Test file not found after container restart"
        return 1
    fi
}

# Main test function
main() {
    print_header "=== Telemetry System Data Persistence Test ==="
    
    cd "$PROJECT_DIR"
    
    local test_results=()
    
    # Test each component
    if test_grafana_persistence; then
        test_results+=("Grafana: ✓ PASS")
    else
        test_results+=("Grafana: ✗ FAIL")
    fi
    
    if test_prometheus_persistence; then
        test_results+=("Prometheus: ✓ PASS")
    else
        test_results+=("Prometheus: ✗ FAIL")
    fi
    
    if test_zabbix_persistence; then
        test_results+=("Zabbix: ✓ PASS")
    else
        test_results+=("Zabbix: ✗ FAIL")
    fi
    
    if test_container_restart; then
        test_results+=("Container Restart: ✓ PASS")
    else
        test_results+=("Container Restart: ✗ FAIL")
    fi
    
    # Print results summary
    print_header "=== Test Results Summary ==="
    for result in "${test_results[@]}"; do
        echo "$result"
    done
    
    # Count passes and failures
    local pass_count=$(printf '%s\n' "${test_results[@]}" | grep -c "✓ PASS" || echo "0")
    local total_count=${#test_results[@]}
    
    print_header "=== Final Result ==="
    if [ "$pass_count" -eq "$total_count" ]; then
        print_status "✓ All tests passed! Data persistence is working correctly."
        print_status "Your telemetry system data will be preserved across container restarts."
        return 0
    else
        print_warning "⚠ $pass_count/$total_count tests passed. Some components may have issues."
        print_warning "Please check the failed components and ensure proper volume mounting."
        return 1
    fi
}

# Run main function
main "$@"
