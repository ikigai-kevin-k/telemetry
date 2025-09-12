#!/bin/bash

# Zabbix Server Management Script
# This script helps manage the Zabbix server components (database, server, web)

set -e

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

# Function to check if Docker is running
check_docker() {
    if ! docker info > /dev/null 2>&1; then
        print_error "Docker is not running. Please start Docker first."
        exit 1
    fi
    print_success "Docker is running"
}

# Function to check if docker compose is available
check_docker_compose() {
    if ! docker compose version &> /dev/null; then
        print_error "docker compose is not available. Please install Docker Compose first."
        exit 1
    fi
    print_success "docker compose is available"
}

# Function to start Zabbix server
start_zabbix_server() {
    print_status "Starting Zabbix server components..."
    
    # Change to the zabbix directory
    cd "$(dirname "$0")"
    
    # Start Zabbix server services
    docker compose -f zabbix-server-compose.yml up -d
    
    print_success "Zabbix server components started successfully"
    print_status "Zabbix Web Interface: http://localhost:8080"
    print_status "Zabbix Server Port: 10051"
    print_status "MySQL Database Port: 3306"
}

# Function to stop Zabbix server
stop_zabbix_server() {
    print_status "Stopping Zabbix server components..."
    
    cd "$(dirname "$0")"
    
    docker compose -f zabbix-server-compose.yml down
    
    print_success "Zabbix server components stopped successfully"
}

# Function to restart Zabbix server
restart_zabbix_server() {
    print_status "Restarting Zabbix server components..."
    
    stop_zabbix_server
    sleep 5
    start_zabbix_server
    
    print_success "Zabbix server components restarted successfully"
}

# Function to show Zabbix server status
show_status() {
    print_status "Zabbix server components status:"
    
    cd "$(dirname "$0")"
    
    docker compose -f zabbix-server-compose.yml ps
}

# Function to show Zabbix server logs
show_logs() {
    local service="$1"
    
    if [ -z "$service" ]; then
        print_error "Please specify a service (zabbix-db, zabbix-server, zabbix-web)"
        exit 1
    fi
    
    print_status "Showing logs for $service..."
    
    cd "$(dirname "$0")"
    
    docker compose -f zabbix-server-compose.yml logs -f "$service"
}

# Function to backup Zabbix database
backup_database() {
    print_status "Creating Zabbix database backup..."
    
    cd "$(dirname "$0")"
    
    # Create backup directory if it doesn't exist
    mkdir -p backups
    
    # Create backup with timestamp
    local backup_file="backups/zabbix_backup_$(date +%Y%m%d_%H%M%S).sql"
    
    docker compose -f zabbix-server-compose.yml exec zabbix-db mysqldump -u root -proot_pwd zabbix > "$backup_file"
    
    print_success "Database backup created: $backup_file"
}

# Function to show help
show_help() {
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  start     Start Zabbix server components"
    echo "  stop      Stop Zabbix server components"
    echo "  restart   Restart Zabbix server components"
    echo "  status    Show Zabbix server components status"
    echo "  logs      Show logs for a specific service"
    echo "  backup    Backup Zabbix database"
    echo "  help      Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 start                    # Start Zabbix server"
    echo "  $0 logs zabbix-server      # Show server logs"
    echo "  $0 backup                  # Backup database"
}

# Main script logic
main() {
    # Check prerequisites
    check_docker
    check_docker_compose
    
    case "${1:-help}" in
        start)
            start_zabbix_server
            ;;
        stop)
            stop_zabbix_server
            ;;
        restart)
            restart_zabbix_server
            ;;
        status)
            show_status
            ;;
        logs)
            show_logs "$2"
            ;;
        backup)
            backup_database
            ;;
        help|--help|-h)
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
