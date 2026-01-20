#!/bin/bash

# Container Health Check and Auto-Restore Script
# This script checks container status and ensures data persistence
# Author: AI Assistant

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_DIR="/home/ella/kevin/telemetry"
BACKUP_DIR="${PROJECT_DIR}/backups"
LOG_FILE="${PROJECT_DIR}/container_health.log"

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

print_header() {
    echo -e "${BLUE}[HEADER]${NC} $1" | tee -a "$LOG_FILE"
}

# Function to check container health
check_container_health() {
    local container_name=$1
    local expected_status=$2
    
    print_status "Checking health of container: $container_name"
    
    # Check if container exists
    if ! docker ps -a --format "{{.Names}}" | grep -q "^${container_name}$"; then
        print_error "Container $container_name does not exist!"
        return 1
    fi
    
    # Get container status
    local status=$(docker inspect --format='{{.State.Status}}' "$container_name" 2>/dev/null)
    local health=$(docker inspect --format='{{.State.Health.Status}}' "$container_name" 2>/dev/null || echo "no-health-check")
    
    print_status "Container $container_name status: $status, health: $health"
    
    if [ "$status" = "running" ]; then
        if [ "$health" = "healthy" ] || [ "$health" = "no-health-check" ]; then
            print_status "✓ Container $container_name is healthy"
            return 0
        else
            print_warning "⚠ Container $container_name is running but unhealthy (health: $health)"
            return 1
        fi
    else
        print_warning "⚠ Container $container_name is not running (status: $status)"
        return 1
    fi
}

# Function to restart container
restart_container() {
    local container_name=$1
    
    print_status "Restarting container: $container_name"
    
    # Stop container if running
    docker stop "$container_name" 2>/dev/null || true
    
    # Remove container
    docker rm "$container_name" 2>/dev/null || true
    
    # Start using docker-compose
    cd "$PROJECT_DIR"
    docker-compose up -d "$container_name" 2>/dev/null || {
        print_error "Failed to restart container $container_name with docker-compose"
        return 1
    }
    
    # Wait for container to be ready
    print_status "Waiting for container $container_name to be ready..."
    sleep 10
    
    # Check health again
    if check_container_health "$container_name"; then
        print_status "✓ Successfully restarted container $container_name"
        return 0
    else
        print_error "✗ Failed to restore container $container_name to healthy state"
        return 1
    fi
}

# Function to verify data persistence
verify_data_persistence() {
    print_header "=== Verifying Data Persistence ==="
    
    local volumes=(
        "telemetry_prometheus_data"
        "telemetry_grafana_data"
        "telemetry_loki_data"
        "telemetry_zabbix_server_data"
        "telemetry_zabbix_db_data"
    )
    
    for volume in "${volumes[@]}"; do
        print_status "Checking volume: $volume"
        
        if docker volume inspect "$volume" >/dev/null 2>&1; then
            local volume_path=$(docker volume inspect --format='{{.Mountpoint}}' "$volume")
            local volume_size=$(du -sh "$volume_path" 2>/dev/null | cut -f1 || echo "unknown")
            print_status "✓ Volume $volume exists (size: $volume_size)"
        else
            print_error "✗ Volume $volume does not exist!"
            return 1
        fi
    done
    
    print_status "✓ All volumes are properly configured"
    return 0
}

# Function to create emergency backup
create_emergency_backup() {
    print_header "=== Creating Emergency Backup ==="
    
    if [ -f "${PROJECT_DIR}/backup_telemetry_data.sh" ]; then
        print_status "Running emergency backup..."
        "${PROJECT_DIR}/backup_telemetry_data.sh"
        if [ $? -eq 0 ]; then
            print_status "✓ Emergency backup completed successfully"
            return 0
        else
            print_error "✗ Emergency backup failed"
            return 1
        fi
    else
        print_warning "Backup script not found, skipping emergency backup"
        return 1
    fi
}

# Function to restore from latest backup
restore_from_backup() {
    print_header "=== Restoring from Latest Backup ==="
    
    if [ ! -d "$BACKUP_DIR" ]; then
        print_error "Backup directory does not exist: $BACKUP_DIR"
        return 1
    fi
    
    # Find latest backup
    local latest_backup=$(ls -t "$BACKUP_DIR" | head -n1)
    
    if [ -z "$latest_backup" ]; then
        print_error "No backups found in $BACKUP_DIR"
        return 1
    fi
    
    print_status "Found latest backup: $latest_backup"
    
    # Run restore script
    local restore_script="${BACKUP_DIR}/${latest_backup}/restore.sh"
    
    if [ -f "$restore_script" ]; then
        print_status "Running restore script..."
        "$restore_script"
        if [ $? -eq 0 ]; then
            print_status "✓ Restore completed successfully"
            return 0
        else
            print_error "✗ Restore failed"
            return 1
        fi
    else
        print_error "Restore script not found: $restore_script"
        return 1
    fi
}

# Main health check function
main_health_check() {
    print_header "=== Telemetry System Health Check - $(date) ==="
    
    # Change to project directory
    cd "$PROJECT_DIR"
    
    # Check if docker-compose.yml exists
    if [ ! -f "docker-compose.yml" ]; then
        print_error "docker-compose.yml not found in $PROJECT_DIR"
        exit 1
    fi
    
    # Verify data persistence first
    if ! verify_data_persistence; then
        print_error "Data persistence verification failed!"
        exit 1
    fi
    
    # Define containers to check
    local containers=(
        "kevin-telemetry-prometheus"
        "kevin-telemetry-grafana"
        "kevin-telemetry-loki-server"
        "kevin-telemetry-zabbix-server"
        "kevin-telemetry-zabbix-db"
        "kevin-telemetry-zabbix-web"
        "kevin-telemetry-pushgateway"
    )
    
    local failed_containers=()
    local healthy_containers=()
    
    # Check each container
    print_header "=== Container Health Check ==="
    for container in "${containers[@]}"; do
        if check_container_health "$container"; then
            healthy_containers+=("$container")
        else
            failed_containers+=("$container")
        fi
    done
    
    # Summary
    print_header "=== Health Check Summary ==="
    print_status "Healthy containers: ${#healthy_containers[@]}/${#containers[@]}"
    
    if [ ${#failed_containers[@]} -eq 0 ]; then
        print_status "✓ All containers are healthy!"
        return 0
    else
        print_warning "⚠ ${#failed_containers[@]} container(s) need attention:"
        for container in "${failed_containers[@]}"; do
            print_warning "  - $container"
        done
        
        # Ask user if they want to attempt recovery
        echo -e "${YELLOW}Do you want to attempt automatic recovery? (y/n)${NC}"
        read -r response
        
        if [[ "$response" =~ ^[Yy]$ ]]; then
            print_header "=== Attempting Automatic Recovery ==="
            
            # Create emergency backup first
            create_emergency_backup
            
            # Try to restart failed containers
            for container in "${failed_containers[@]}"; do
                print_status "Attempting to recover: $container"
                restart_container "$container"
            done
            
            # Final health check
            print_header "=== Final Health Check ==="
            local still_failed=0
            for container in "${failed_containers[@]}"; do
                if ! check_container_health "$container"; then
                    still_failed=$((still_failed + 1))
                fi
            done
            
            if [ $still_failed -eq 0 ]; then
                print_status "✓ All containers recovered successfully!"
            else
                print_error "✗ $still_failed container(s) still need manual intervention"
                print_error "Check logs with: docker logs <container_name>"
            fi
        else
            print_status "Manual intervention required for failed containers"
        fi
        
        return 1
    fi
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --check-only     Only check container health, don't attempt recovery"
    echo "  --backup         Create emergency backup only"
    echo "  --restore        Restore from latest backup"
    echo "  --help           Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                    # Full health check with recovery options"
    echo "  $0 --check-only       # Check health without recovery"
    echo "  $0 --backup           # Create emergency backup"
    echo "  $0 --restore          # Restore from latest backup"
}

# Main function
main() {
    case "${1:-}" in
        --check-only)
            print_header "=== Health Check Only Mode ==="
            main_health_check
            ;;
        --backup)
            create_emergency_backup
            ;;
        --restore)
            restore_from_backup
            ;;
        --help)
            show_usage
            ;;
        "")
            main_health_check
            ;;
        *)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"
