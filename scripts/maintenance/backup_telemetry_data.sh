#!/bin/bash

# Telemetry System Backup Script
# This script creates backups of all Docker volumes and configuration files
# Author: AI Assistant
# Date: $(date)

set -e  # Exit on any error

# Configuration
BACKUP_DIR="/home/ella/kevin/telemetry/backups"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_NAME="telemetry_backup_${TIMESTAMP}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# Create backup directory
print_status "Creating backup directory: ${BACKUP_DIR}/${BACKUP_NAME}"
mkdir -p "${BACKUP_DIR}/${BACKUP_NAME}"

# Function to backup Docker volume
backup_volume() {
    local volume_name=$1
    local backup_file=$2
    
    print_status "Backing up Docker volume: ${volume_name}"
    
    # Check if volume exists
    if ! docker volume inspect "${volume_name}" >/dev/null 2>&1; then
        print_warning "Volume ${volume_name} does not exist, skipping..."
        return
    fi
    
    # Create a temporary container to backup the volume
    local temp_container="backup_${volume_name}_$(date +%s)"
    
    # Start temporary container with the volume mounted
    docker run --rm -v "${volume_name}:/source" -v "${BACKUP_DIR}/${BACKUP_NAME}:/backup" \
        alpine:latest sh -c "cd /source && tar czf /backup/${backup_file} ."
    
    if [ $? -eq 0 ]; then
        print_status "Successfully backed up volume: ${volume_name}"
    else
        print_error "Failed to backup volume: ${volume_name}"
        return 1
    fi
}

# Function to backup configuration files
backup_config_files() {
    print_status "Backing up configuration files..."
    
    local config_dir="${BACKUP_DIR}/${BACKUP_NAME}/configs"
    mkdir -p "${config_dir}"
    
    # List of important configuration files to backup
    local config_files=(
        "docker-compose.yml"
        "prometheus.yml"
        "loki-config.yml"
        "grafana/provisioning"
        "grafana/grafana.ini"
        "zabbix"
        "promtail-*.yml"
    )
    
    for pattern in "${config_files[@]}"; do
        if ls ${pattern} >/dev/null 2>&1; then
            print_status "Backing up: ${pattern}"
            cp -r ${pattern} "${config_dir}/" 2>/dev/null || true
        else
            print_warning "Configuration pattern not found: ${pattern}"
        fi
    done
    
    # Backup docker-compose files
    print_status "Backing up all docker-compose files..."
    cp docker-compose*.yml "${config_dir}/" 2>/dev/null || true
}

# Main backup process
main() {
    print_status "Starting telemetry system backup..."
    print_status "Backup will be saved to: ${BACKUP_DIR}/${BACKUP_NAME}"
    
    # Create backup directory structure
    mkdir -p "${BACKUP_DIR}/${BACKUP_NAME}/volumes"
    mkdir -p "${BACKUP_DIR}/${BACKUP_NAME}/configs"
    
    # Backup all Docker volumes
    print_status "=== Backing up Docker volumes ==="
    
    local volumes=(
        "telemetry_prometheus_data:prometheus_data.tar.gz"
        "telemetry_grafana_data:grafana_data.tar.gz"
        "telemetry_loki_data:loki_data.tar.gz"
        "telemetry_zabbix_server_data:zabbix_server_data.tar.gz"
        "telemetry_zabbix_db_data:zabbix_db_data.tar.gz"
    )
    
    for volume_info in "${volumes[@]}"; do
        IFS=':' read -r volume_name backup_file <<< "$volume_info"
        backup_volume "${volume_name}" "volumes/${backup_file}"
    done
    
    # Backup configuration files
    print_status "=== Backing up configuration files ==="
    backup_config_files
    
    # Create backup metadata
    print_status "Creating backup metadata..."
    cat > "${BACKUP_DIR}/${BACKUP_NAME}/backup_info.txt" << EOF
Telemetry System Backup
======================
Backup Date: $(date)
Backup Directory: ${BACKUP_DIR}/${BACKUP_NAME}
Hostname: $(hostname)
Docker Version: $(docker --version)
Docker Compose Version: $(docker-compose --version)

Docker Containers Status:
$(docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}")

Docker Volumes:
$(docker volume ls)

Backup Contents:
- Docker volumes: prometheus_data, grafana_data, loki_data, zabbix_server_data, zabbix_db_data
- Configuration files: docker-compose files, prometheus.yml, loki-config.yml, grafana configs, zabbix configs
EOF
    
    # Create restore script
    print_status "Creating restore script..."
    cat > "${BACKUP_DIR}/${BACKUP_NAME}/restore.sh" << 'EOF'
#!/bin/bash
# Restore script for telemetry system backup
# Usage: ./restore.sh [backup_directory]

set -e

BACKUP_DIR=${1:-"$(pwd)"}
BACKUP_NAME=$(basename "$BACKUP_DIR")

echo "Restoring telemetry system from: $BACKUP_DIR"

# Function to restore Docker volume
restore_volume() {
    local volume_name=$1
    local backup_file=$2
    
    echo "Restoring Docker volume: $volume_name"
    
    # Create volume if it doesn't exist
    docker volume create "$volume_name" 2>/dev/null || true
    
    # Restore volume data
    docker run --rm -v "$volume_name:/target" -v "$BACKUP_DIR:/backup" \
        alpine:latest sh -c "cd /target && tar xzf /backup/$backup_file"
    
    echo "Successfully restored volume: $volume_name"
}

# Restore volumes
restore_volume "telemetry_prometheus_data" "volumes/prometheus_data.tar.gz"
restore_volume "telemetry_grafana_data" "volumes/grafana_data.tar.gz"
restore_volume "telemetry_loki_data" "volumes/loki_data.tar.gz"
restore_volume "telemetry_zabbix_server_data" "volumes/zabbix_server_data.tar.gz"
restore_volume "telemetry_zabbix_db_data" "volumes/zabbix_db_data.tar.gz"

echo "Restore completed. You can now start the containers with: docker-compose up -d"
EOF
    
    chmod +x "${BACKUP_DIR}/${BACKUP_NAME}/restore.sh"
    
    # Calculate backup size
    local backup_size=$(du -sh "${BACKUP_DIR}/${BACKUP_NAME}" | cut -f1)
    
    print_status "=== Backup completed successfully ==="
    print_status "Backup location: ${BACKUP_DIR}/${BACKUP_NAME}"
    print_status "Backup size: ${backup_size}"
    print_status "Restore script created: ${BACKUP_DIR}/${BACKUP_NAME}/restore.sh"
    
    # List backup contents
    print_status "Backup contents:"
    ls -la "${BACKUP_DIR}/${BACKUP_NAME}/"
    
    print_status "To restore this backup, run: ${BACKUP_DIR}/${BACKUP_NAME}/restore.sh"
}

# Run main function
main "$@"
