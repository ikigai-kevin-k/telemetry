#!/bin/bash

# ARO-001-1 Agent Volume Management Script
# This script manages Docker volumes for ARO-001-1 agent data persistence

set -e

AGENT_NAME="GC-ARO-001-1-agent"
COMPOSE_FILE="docker-compose-${AGENT_NAME}.yml"
BACKUP_DIR="./backups/aro-001-1-volumes"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Volume names
PROMTAIL_POSITIONS_VOLUME="telemetry_promtail_aro_001_1_positions"
PROMTAIL_DATA_VOLUME="telemetry_promtail_aro_001_1_data"
ZABBIX_AGENT_DATA_VOLUME="telemetry_zabbix_agent_aro_001_1_data"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if volume exists
volume_exists() {
    local volume_name=$1
    docker volume ls --format "{{.Name}}" | grep -q "^${volume_name}$"
}

# Function to get volume size
get_volume_size() {
    local volume_name=$1
    if volume_exists "$volume_name"; then
        docker system df -v | grep "$volume_name" | awk '{print $3}' || echo "Unknown"
    else
        echo "N/A"
    fi
}

# Function to show volume status
show_volume_status() {
    print_status "ARO-001-1 Agent Volume Status:"
    echo "================================================="
    
    printf "%-40s %-10s %-10s\n" "Volume Name" "Status" "Size"
    printf "%-40s %-10s %-10s\n" "----------------------------------------" "----------" "----------"
    
    for volume in "$PROMTAIL_POSITIONS_VOLUME" "$PROMTAIL_DATA_VOLUME" "$ZABBIX_AGENT_DATA_VOLUME"; do
        if volume_exists "$volume"; then
            status="${GREEN}✅ Exists${NC}"
            size=$(get_volume_size "$volume")
        else
            status="${RED}❌ Missing${NC}"
            size="N/A"
        fi
        printf "%-40s %-20s %-10s\n" "$volume" "$status" "$size"
    done
    echo ""
}

# Function to create volumes
create_volumes() {
    print_status "Creating Docker volumes for ARO-001-1 agent..."
    
    for volume in "$PROMTAIL_POSITIONS_VOLUME" "$PROMTAIL_DATA_VOLUME" "$ZABBIX_AGENT_DATA_VOLUME"; do
        if ! volume_exists "$volume"; then
            print_status "Creating volume: $volume"
            docker volume create "$volume"
            print_success "Volume created: $volume"
        else
            print_warning "Volume already exists: $volume"
        fi
    done
}

# Function to backup volumes
backup_volumes() {
    print_status "Backing up ARO-001-1 agent volumes..."
    
    # Create backup directory
    mkdir -p "$BACKUP_DIR/$TIMESTAMP"
    
    # Backup each volume
    for volume in "$PROMTAIL_POSITIONS_VOLUME" "$PROMTAIL_DATA_VOLUME" "$ZABBIX_AGENT_DATA_VOLUME"; do
        if volume_exists "$volume"; then
            print_status "Backing up volume: $volume"
            backup_file="$BACKUP_DIR/$TIMESTAMP/${volume}.tar.gz"
            
            # Create backup using temporary container
            docker run --rm \
                -v "$volume":/volume \
                -v "$(pwd)/$BACKUP_DIR/$TIMESTAMP":/backup \
                alpine:latest \
                tar czf "/backup/${volume}.tar.gz" -C /volume .
            
            print_success "Volume backed up: $backup_file"
        else
            print_warning "Volume not found, skipping: $volume"
        fi
    done
    
    # Create backup metadata
    cat > "$BACKUP_DIR/$TIMESTAMP/backup_info.txt" << EOF
ARO-001-1 Agent Volume Backup
=============================
Backup Date: $(date)
Agent: $AGENT_NAME
Volumes Backed Up:
- $PROMTAIL_POSITIONS_VOLUME
- $PROMTAIL_DATA_VOLUME
- $ZABBIX_AGENT_DATA_VOLUME

Restore Command:
./manage_aro_001_1_volumes.sh --restore $TIMESTAMP
EOF
    
    print_success "Backup completed: $BACKUP_DIR/$TIMESTAMP"
}

# Function to restore volumes
restore_volumes() {
    local backup_timestamp=$1
    
    if [ -z "$backup_timestamp" ]; then
        print_error "Please specify backup timestamp"
        echo "Available backups:"
        ls -la "$BACKUP_DIR/" 2>/dev/null || echo "No backups found"
        exit 1
    fi
    
    local restore_dir="$BACKUP_DIR/$backup_timestamp"
    
    if [ ! -d "$restore_dir" ]; then
        print_error "Backup directory not found: $restore_dir"
        exit 1
    fi
    
    print_status "Restoring ARO-001-1 agent volumes from backup: $backup_timestamp"
    
    # Stop containers first
    print_status "Stopping ARO-001-1 agent containers..."
    docker compose -f "$COMPOSE_FILE" down
    
    # Restore each volume
    for volume in "$PROMTAIL_POSITIONS_VOLUME" "$PROMTAIL_DATA_VOLUME" "$ZABBIX_AGENT_DATA_VOLUME"; do
        backup_file="$restore_dir/${volume}.tar.gz"
        
        if [ -f "$backup_file" ]; then
            print_status "Restoring volume: $volume"
            
            # Remove existing volume if it exists
            if volume_exists "$volume"; then
                docker volume rm "$volume"
            fi
            
            # Create new volume
            docker volume create "$volume"
            
            # Restore data
            docker run --rm \
                -v "$volume":/volume \
                -v "$(pwd)/$restore_dir":/backup \
                alpine:latest \
                tar xzf "/backup/${volume}.tar.gz" -C /volume
            
            print_success "Volume restored: $volume"
        else
            print_warning "Backup file not found: $backup_file"
        fi
    done
    
    # Restart containers
    print_status "Starting ARO-001-1 agent containers..."
    docker compose -f "$COMPOSE_FILE" up -d
    
    print_success "Restore completed from backup: $backup_timestamp"
}

# Function to clean old backups
clean_old_backups() {
    local keep_days=${1:-7}  # Default keep 7 days
    
    print_status "Cleaning backups older than $keep_days days..."
    
    if [ -d "$BACKUP_DIR" ]; then
        find "$BACKUP_DIR" -type d -name "*_*" -mtime +$keep_days -exec rm -rf {} \; 2>/dev/null || true
        print_success "Old backups cleaned"
    else
        print_warning "Backup directory not found: $BACKUP_DIR"
    fi
}

# Function to restart agent with volumes
restart_agent() {
    print_status "Restarting ARO-001-1 agent with persistent volumes..."
    
    # Stop current containers
    docker compose -f "$COMPOSE_FILE" down
    
    # Create volumes if they don't exist
    create_volumes
    
    # Start containers
    docker compose -f "$COMPOSE_FILE" up -d
    
    # Wait for services to start
    sleep 5
    
    # Show status
    docker compose -f "$COMPOSE_FILE" ps
    
    print_success "ARO-001-1 agent restarted with persistent volumes"
}

# Function to show help
show_help() {
    echo "ARO-001-1 Agent Volume Management Script"
    echo "========================================"
    echo ""
    echo "Usage: $0 [OPTION]"
    echo ""
    echo "Options:"
    echo "  --status                Show volume status"
    echo "  --create                Create volumes"
    echo "  --backup                Backup volumes"
    echo "  --restore TIMESTAMP     Restore volumes from backup"
    echo "  --clean [DAYS]          Clean old backups (default: 7 days)"
    echo "  --restart               Restart agent with volumes"
    echo "  --help                  Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --status"
    echo "  $0 --backup"
    echo "  $0 --restore 20250919_140000"
    echo "  $0 --clean 14"
    echo ""
}

# Main script logic
case "$1" in
    --status)
        show_volume_status
        ;;
    --create)
        create_volumes
        ;;
    --backup)
        backup_volumes
        ;;
    --restore)
        restore_volumes "$2"
        ;;
    --clean)
        clean_old_backups "$2"
        ;;
    --restart)
        restart_agent
        ;;
    --help|"")
        show_help
        ;;
    *)
        print_error "Unknown option: $1"
        show_help
        exit 1
        ;;
esac
