#!/bin/bash

# Zabbix Container Management Script
# This script helps manage the Zabbix containers

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

# Function to check if docker-compose is available
check_docker_compose() {
    if ! command -v docker-compose &> /dev/null; then
        print_error "docker-compose is not installed. Please install it first."
        exit 1
    fi
    print_success "docker-compose is available"
}

# Function to start Zabbix containers
start_zabbix() {
    print_status "Starting Zabbix containers..."
    
    # Change to the parent directory where docker compose .yml is located
    cd "$(dirname "$0")/.."
    
    # Start only Zabbix-related services
    docker-compose up -d zabbix-db zabbix-server zabbix-web zabbix-agent
    
    print_success "Zabbix containers started successfully"
}

# Function to stop Zabbix containers
stop_zabbix() {
    print_status "Stopping Zabbix containers..."
    
    cd "$(dirname "$0")/.."
    
    docker-compose stop zabbix-agent zabbix-web zabbix-server zabbix-db
    
    print_success "Zabbix containers stopped successfully"
}

# Function to restart Zabbix containers
restart_zabbix() {
    print_status "Restarting Zabbix containers..."
    
    stop_zabbix
    sleep 5
    start_zabbix
    
    print_success "Zabbix containers restarted successfully"
}

# Function to show Zabbix status
show_status() {
    print_status "Zabbix containers status:"
    
    cd "$(dirname "$0")/.."
    
    docker-compose ps zabbix-db zabbix-server zabbix-web zabbix-agent
}

# Function to show Zabbix logs
show_logs() {
    local service="$1"
    
    if [ -z "$service" ]; then
        print_error "Please specify a service (zabbix-db, zabbix-server, zabbix-web, zabbix-agent)"
        exit 1
    fi
    
    print_status "Showing logs for $service..."
    
    cd "$(dirname "$0")/.."
    
    docker-compose logs -f "$service"
}

# Function to test ZCAM API connection
test_zcam() {
    print_status "Testing ZCAM API connection..."
    
    if [ -f "./zabbix/test_zcam_api.sh" ]; then
        cd "$(dirname "$0")"
        ./test_zcam_api.sh
    else
        print_error "Test script not found"
        exit 1
    fi
}

# Function to show help
show_help() {
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  start     Start Zabbix containers"
    echo "  stop      Stop Zabbix containers"
    echo "  restart   Restart Zabbix containers"
    echo "  status    Show Zabbix containers status"
    echo "  logs      Show logs for a specific service"
    echo "  test      Test ZCAM API connection"
    echo "  help      Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 start                    # Start Zabbix containers"
    echo "  $0 logs zabbix-agent       # Show agent logs"
    echo "  $0 test                    # Test ZCAM API"
}

# Main script logic
main() {
    # Check prerequisites
    check_docker
    check_docker_compose
    
    case "${1:-help}" in
        start)
            start_zabbix
            ;;
        stop)
            stop_zabbix
            ;;
        restart)
            restart_zabbix
            ;;
        status)
            show_status
            ;;
        logs)
            show_logs "$2"
            ;;
        test)
            test_zcam
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
