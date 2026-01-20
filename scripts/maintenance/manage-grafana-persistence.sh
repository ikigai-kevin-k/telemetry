#!/bin/bash

# Grafana Loki aro11 SDP Log Persistence Management Script
# This script helps manage Docker persistent storage for Grafana datasource configuration

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
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
    echo -e "${BLUE}=== $1 ===${NC}"
}

# Check if running on server (100.64.0.113)
check_server() {
    current_ip=$(hostname -I | awk '{print $1}')
    if [[ "$current_ip" != "100.64.0.113" ]]; then
        print_warning "This script should be run on the main server (100.64.0.113)"
        print_warning "Current IP: $current_ip"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

# Function to backup current Grafana data
backup_grafana_data() {
    print_header "Backing up Grafana Data"
    
    if docker volume ls | grep -q "telemetry_grafana_data"; then
        backup_dir="./backup/grafana_$(date +%Y%m%d_%H%M%S)"
        mkdir -p "$backup_dir"
        
        print_status "Creating backup in $backup_dir"
        docker run --rm -v telemetry_grafana_data:/data -v "$(pwd)/$backup_dir:/backup" alpine:latest \
            sh -c "cd /data && tar czf /backup/grafana_data.tar.gz ."
        
        print_status "Backup completed: $backup_dir/grafana_data.tar.gz"
    else
        print_status "No existing Grafana data volume found"
    fi
}

# Function to verify aro11 agent volumes
verify_agent_volumes() {
    print_header "Verifying aro11 Agent Volumes"
    
    volumes=(
        "telemetry_promtail_aro_001_1_positions"
        "telemetry_promtail_aro_001_1_data"
        "telemetry_zabbix_agent_aro_001_1_data"
    )
    
    for volume in "${volumes[@]}"; do
        if docker volume ls | grep -q "$volume"; then
            print_status "✓ Volume exists: $volume"
        else
            print_warning "✗ Volume missing: $volume"
            print_status "Creating volume: $volume"
            docker volume create "$volume"
        fi
    done
}

# Function to restart Grafana service
restart_grafana() {
    print_header "Restarting Grafana Service"
    
    if docker ps | grep -q "kevin-telemetry-grafana"; then
        print_status "Stopping Grafana container..."
        docker stop kevin-telemetry-grafana
    fi
    
    print_status "Starting Grafana with new configuration..."
    docker-compose up -d grafana
    
    print_status "Waiting for Grafana to be ready..."
    sleep 10
    
    # Check if Grafana is responding
    if curl -s http://localhost:3000/api/health > /dev/null 2>&1; then
        print_status "✓ Grafana is running and responding"
    else
        print_warning "Grafana may still be starting up. Check logs with: docker logs kevin-telemetry-grafana"
    fi
}

# Function to verify datasource configuration
verify_datasource() {
    print_header "Verifying Loki Datasource Configuration"
    
    # Wait a bit more for Grafana to fully initialize
    sleep 5
    
    # Check if Loki datasource is configured
    response=$(curl -s -u admin:admin http://localhost:3000/api/datasources/name/Loki-aro11-SDP 2>/dev/null || echo "error")
    
    if [[ "$response" == "error" ]] || [[ "$response" == *"Not found"* ]]; then
        print_warning "aro11 SDP Loki datasource not found. It may take a few moments to provision."
        print_status "You can check the provisioning status in Grafana UI at http://localhost:3000"
    else
        print_status "✓ aro11 SDP Loki datasource is configured"
    fi
}

# Function to show status
show_status() {
    print_header "Current Status"
    
    echo "Docker Containers:"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "(grafana|loki|promtail)"
    
    echo -e "\nDocker Volumes:"
    docker volume ls | grep -E "(grafana|loki|promtail|telemetry)" | sort
    
    echo -e "\nGrafana Configuration Files:"
    ls -la grafana/provisioning/datasources/
    ls -la grafana/provisioning/dashboards/
    
    echo -e "\naro11 Agent Status:"
    if ping -c 1 100.64.0.167 > /dev/null 2>&1; then
        print_status "✓ aro11 agent (100.64.0.167) is reachable"
    else
        print_warning "✗ aro11 agent (100.64.0.167) is not reachable"
    fi
}

# Function to display help
show_help() {
    echo "Grafana Loki aro11 SDP Log Persistence Management"
    echo ""
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  backup          Backup current Grafana data"
    echo "  verify-volumes  Verify and create required Docker volumes"
    echo "  restart         Restart Grafana service with new configuration"
    echo "  verify-ds       Verify Loki datasource configuration"
    echo "  status          Show current status of all services"
    echo "  setup           Run complete setup (backup + verify + restart + verify-ds)"
    echo "  help            Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 setup        # Complete setup process"
    echo "  $0 status       # Check current status"
    echo "  $0 restart      # Restart Grafana only"
}

# Main execution
main() {
    case "$1" in
        "backup")
            check_server
            backup_grafana_data
            ;;
        "verify-volumes")
            verify_agent_volumes
            ;;
        "restart")
            check_server
            restart_grafana
            ;;
        "verify-ds")
            check_server
            verify_datasource
            ;;
        "status")
            show_status
            ;;
        "setup")
            print_header "Complete Grafana aro11 SDP Log Setup"
            check_server
            backup_grafana_data
            verify_agent_volumes
            restart_grafana
            verify_datasource
            show_status
            print_status "Setup completed! Access Grafana at http://localhost:3000"
            print_status "Look for 'aro11 SDP Log Dashboard' in the SDP Monitoring folder"
            ;;
        "help"|"--help"|"-h"|"")
            show_help
            ;;
        *)
            print_error "Unknown command: $1"
            show_help
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"
