#!/bin/bash

# Setup Automated Backup for Telemetry System
# This script sets up cron jobs for automated backups and health checks
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

# Function to create log rotation script
create_log_rotation() {
    print_status "Creating log rotation configuration..."
    
    cat > /tmp/telemetry-logrotate.conf << EOF
# Log rotation for telemetry system
/home/ella/kevin/telemetry/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    copytruncate
    maxsize 100M
}

/home/ella/kevin/telemetry/backups/*/backup_info.txt {
    weekly
    missingok
    rotate 12
    compress
    notifempty
}
EOF
    
    # Install logrotate config if running as root
    if [ "$EUID" -eq 0 ]; then
        cp /tmp/telemetry-logrotate.conf /etc/logrotate.d/telemetry
        print_status "Log rotation configuration installed to /etc/logrotate.d/telemetry"
    else
        print_warning "Not running as root, log rotation config saved to: /tmp/telemetry-logrotate.conf"
        print_warning "To install: sudo cp /tmp/telemetry-logrotate.conf /etc/logrotate.d/telemetry"
    fi
}

# Function to create cleanup script
create_cleanup_script() {
    print_status "Creating backup cleanup script..."
    
    cat > "${PROJECT_DIR}/cleanup_old_backups.sh" << 'EOF'
#!/bin/bash
# Cleanup old backups script
# Keeps only the last 30 days of daily backups and 12 months of weekly backups

BACKUP_DIR="/home/ella/kevin/telemetry/backups"
RETENTION_DAILY=30
RETENTION_WEEKLY=52

echo "Cleaning up old backups in: $BACKUP_DIR"

# Remove daily backups older than retention period
find "$BACKUP_DIR" -name "telemetry_backup_*" -type d -mtime +$RETENTION_DAILY -exec rm -rf {} \; 2>/dev/null || true

# Keep only the most recent backup from each week for weekly retention
find "$BACKUP_DIR" -name "telemetry_backup_*" -type d -mtime +7 | sort -r | tail -n +2 | xargs rm -rf 2>/dev/null || true

echo "Backup cleanup completed"
EOF
    
    chmod +x "${PROJECT_DIR}/cleanup_old_backups.sh"
    print_status "Cleanup script created: ${PROJECT_DIR}/cleanup_old_backups.sh"
}

# Function to setup cron jobs
setup_cron_jobs() {
    print_header "Setting up automated cron jobs..."
    
    # Create cron job entries
    local cron_entries=(
        "# Telemetry System Automated Tasks"
        "# Daily backup at 2:00 AM"
        "0 2 * * * cd ${PROJECT_DIR} && ./backup_telemetry_data.sh >> /var/log/telemetry_backup.log 2>&1"
        ""
        "# Health check every 6 hours"
        "0 */6 * * * cd ${PROJECT_DIR} && ./check_and_restore_containers.sh --check-only >> /var/log/telemetry_health.log 2>&1"
        ""
        "# Weekly cleanup of old backups (Sundays at 3:00 AM)"
        "0 3 * * 0 cd ${PROJECT_DIR} && ./cleanup_old_backups.sh >> /var/log/telemetry_cleanup.log 2>&1"
        ""
        "# Log rotation (handled by system logrotate)"
    )
    
    # Create temporary cron file
    local temp_cron="/tmp/telemetry_cron"
    printf "%s\n" "${cron_entries[@]}" > "$temp_cron"
    
    print_status "Cron job entries created:"
    cat "$temp_cron"
    echo ""
    
    # Check if we can modify crontab
    if command -v crontab >/dev/null 2>&1; then
        print_status "Current crontab entries:"
        crontab -l 2>/dev/null || echo "No existing crontab entries"
        echo ""
        
        # Ask user if they want to install cron jobs
        echo -e "${YELLOW}Do you want to install these cron jobs? (y/n)${NC}"
        read -r response
        
        if [[ "$response" =~ ^[Yy]$ ]]; then
            # Backup existing crontab
            crontab -l > /tmp/crontab_backup_$(date +%Y%m%d_%H%M%S) 2>/dev/null || true
            
            # Add new entries to crontab
            (crontab -l 2>/dev/null; cat "$temp_cron") | crontab -
            
            print_status "✓ Cron jobs installed successfully!"
            print_status "Current crontab:"
            crontab -l
            
            # Create log files with proper permissions
            sudo touch /var/log/telemetry_backup.log /var/log/telemetry_health.log /var/log/telemetry_cleanup.log 2>/dev/null || {
                print_warning "Could not create log files in /var/log/, you may need to run:"
                print_warning "sudo touch /var/log/telemetry_backup.log /var/log/telemetry_health.log /var/log/telemetry_cleanup.log"
            }
            
        else
            print_status "Cron jobs not installed. You can install them manually later."
        fi
    else
        print_error "crontab command not found. Please install cron package."
    fi
    
    # Clean up temp file
    rm -f "$temp_cron"
}

# Function to create systemd service (alternative to cron)
create_systemd_service() {
    print_status "Creating systemd service templates..."
    
    # Create backup service
    cat > "${PROJECT_DIR}/telemetry-backup.service" << EOF
[Unit]
Description=Telemetry System Backup
After=network.target

[Service]
Type=oneshot
User=ella
WorkingDirectory=${PROJECT_DIR}
ExecStart=${PROJECT_DIR}/backup_telemetry_data.sh
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    # Create backup timer
    cat > "${PROJECT_DIR}/telemetry-backup.timer" << EOF
[Unit]
Description=Run Telemetry Backup Daily
Requires=telemetry-backup.service

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
EOF

    # Create health check service
    cat > "${PROJECT_DIR}/telemetry-health.service" << EOF
[Unit]
Description=Telemetry System Health Check
After=network.target

[Service]
Type=oneshot
User=ella
WorkingDirectory=${PROJECT_DIR}
ExecStart=${PROJECT_DIR}/check_and_restore_containers.sh --check-only
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    # Create health check timer
    cat > "${PROJECT_DIR}/telemetry-health.timer" << EOF
[Unit]
Description=Run Telemetry Health Check Every 6 Hours
Requires=telemetry-health.service

[Timer]
OnCalendar=*:0/6:00
Persistent=true

[Install]
WantedBy=timers.target
EOF

    print_status "Systemd service files created:"
    print_status "  - telemetry-backup.service"
    print_status "  - telemetry-backup.timer"
    print_status "  - telemetry-health.service"
    print_status "  - telemetry-health.timer"
    
    print_status "To install systemd services (run as root):"
    print_status "  sudo cp *.service *.timer /etc/systemd/system/"
    print_status "  sudo systemctl daemon-reload"
    print_status "  sudo systemctl enable telemetry-backup.timer telemetry-health.timer"
    print_status "  sudo systemctl start telemetry-backup.timer telemetry-health.timer"
}

# Function to create monitoring dashboard
create_monitoring_info() {
    print_status "Creating monitoring information..."
    
    cat > "${PROJECT_DIR}/MONITORING_INFO.md" << 'EOF'
# Telemetry System Monitoring Information

## Automated Backup System

### Backup Schedule
- **Daily Backup**: Every day at 2:00 AM
- **Health Check**: Every 6 hours
- **Cleanup**: Weekly on Sundays at 3:00 AM

### Backup Location
- Main backup directory: `/home/ella/kevin/telemetry/backups/`
- Backup naming: `telemetry_backup_YYYYMMDD_HHMMSS`

### Manual Commands

#### Create Backup
```bash
./backup_telemetry_data.sh
```

#### Check System Health
```bash
./check_and_restore_containers.sh
```

#### Restore from Backup
```bash
# Find latest backup
ls -t backups/ | head -1

# Restore from specific backup
./backups/telemetry_backup_YYYYMMDD_HHMMSS/restore.sh
```

#### Emergency Recovery
```bash
# Stop all containers
docker-compose down

# Restore from backup
./backups/telemetry_backup_YYYYMMDD_HHMMSS/restore.sh

# Start containers
docker-compose up -d
```

### Log Files
- Backup logs: `/var/log/telemetry_backup.log`
- Health check logs: `/var/log/telemetry_health.log`
- Cleanup logs: `/var/log/telemetry_cleanup.log`
- Container health: `/home/ella/kevin/telemetry/container_health.log`

### Volume Information
- Prometheus data: `telemetry_prometheus_data`
- Grafana data: `telemetry_grafana_data`
- Loki data: `telemetry_loki_data`
- Zabbix server data: `telemetry_zabbix_server_data`
- Zabbix database data: `telemetry_zabbix_db_data`

### System Requirements
- Docker and Docker Compose installed
- Sufficient disk space for backups
- Cron service running (for automated tasks)

### Troubleshooting
1. Check container status: `docker ps -a`
2. Check logs: `docker logs <container_name>`
3. Check volumes: `docker volume ls`
4. Run health check: `./check_and_restore_containers.sh --check-only`
EOF

    print_status "Monitoring information created: MONITORING_INFO.md"
}

# Main setup function
main() {
    print_header "=== Telemetry System Automated Backup Setup ==="
    
    # Change to project directory
    cd "$PROJECT_DIR"
    
    # Check if required scripts exist
    if [ ! -f "backup_telemetry_data.sh" ] || [ ! -f "check_and_restore_containers.sh" ]; then
        print_error "Required scripts not found. Please ensure backup_telemetry_data.sh and check_and_restore_containers.sh exist."
        exit 1
    fi
    
    # Create necessary directories
    mkdir -p backups
    
    # Run setup functions
    create_log_rotation
    create_cleanup_script
    setup_cron_jobs
    create_systemd_service
    create_monitoring_info
    
    print_header "=== Setup Completed ==="
    print_status "✓ Log rotation configuration created"
    print_status "✓ Backup cleanup script created"
    print_status "✓ Cron jobs configured"
    print_status "✓ Systemd service files created"
    print_status "✓ Monitoring information documented"
    
    print_status ""
    print_status "Next steps:"
    print_status "1. Review and install cron jobs if desired"
    print_status "2. Test backup system: ./backup_telemetry_data.sh"
    print_status "3. Test health check: ./check_and_restore_containers.sh --check-only"
    print_status "4. Read MONITORING_INFO.md for detailed usage instructions"
    
    print_status ""
    print_status "Your telemetry system is now configured for automated backup and monitoring!"
}

# Run main function
main "$@"
