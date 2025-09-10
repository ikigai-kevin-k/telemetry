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

# Function to detect available docker compose command
detect_docker_compose() {
    # Try docker compose (newer format) first
    if docker compose version &> /dev/null; then
        echo "docker compose"
        return 0
    fi
    
    # Try docker-compose (legacy format)
    if docker-compose version &> /dev/null; then
        echo "docker-compose"
        return 0
    fi
    
    return 1
}

# Function to check if docker compose is available
check_docker_compose() {
    if ! detect_docker_compose &> /dev/null; then
        print_error "Neither 'docker compose' nor 'docker-compose' is available. Please install Docker Compose first."
        exit 1
    fi
    
    local compose_cmd=$(detect_docker_compose)
    print_success "Docker Compose is available: $compose_cmd"
}

# Function to start Zabbix containers
start_zabbix() {
    print_status "Starting Zabbix containers..."
    
    # Change to the parent directory where docker compose .yml is located
    cd "$(dirname "$0")/.."
    
    # Get the detected docker compose command
    local compose_cmd=$(detect_docker_compose)
    
    # Start only Zabbix-related services
    $compose_cmd up -d zabbix-db zabbix-server zabbix-web zabbix-agent
    
    print_success "Zabbix containers started successfully"
}

# Function to start only Zabbix server components (DB, Server, Web)
start_zabbix_server() {
    print_status "Starting Zabbix server components (DB, Server, Web)..."
    
    # Change to the parent directory where docker compose .yml is located
    cd "$(dirname "$0")/.."
    
    # Get the detected docker compose command
    local compose_cmd=$(detect_docker_compose)
    
    # Start only Zabbix server-related services
    $compose_cmd up -d zabbix-db zabbix-server zabbix-web
    
    print_success "Zabbix server components started successfully"
}

# Function to start only Zabbix agent
start_zabbix_agent() {
    print_status "Starting Zabbix agent..."
    
    # Change to the parent directory where docker compose .yml is located
    cd "$(dirname "$0")/.."
    
    # Get the detected docker compose command
    local compose_cmd=$(detect_docker_compose)
    
    # Start only Zabbix agent
    $compose_cmd up -d zabbix-agent
    
    print_success "Zabbix agent started successfully"
}

# Function to stop Zabbix containers
stop_zabbix() {
    print_status "Stopping Zabbix containers..."
    
    cd "$(dirname "$0")/.."
    
    # Get the detected docker compose command
    local compose_cmd=$(detect_docker_compose)
    
    $compose_cmd stop zabbix-agent zabbix-web zabbix-server zabbix-db
    
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
    
    # Get the detected docker compose command
    local compose_cmd=$(detect_docker_compose)
    
    $compose_cmd ps zabbix-db zabbix-server zabbix-web zabbix-agent
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
    
    # Get the detected docker compose command
    local compose_cmd=$(detect_docker_compose)
    
    $compose_cmd logs -f "$service"
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
    echo "  start         Start all Zabbix containers (DB, Server, Web, Agent)"
    echo "  start-server  Start only Zabbix server components (DB, Server, Web)"
    echo "  start-agent   Start only Zabbix agent"
    echo "  stop          Stop Zabbix containers"
    echo "  restart       Restart Zabbix containers"
    echo "  status        Show Zabbix containers status"
    echo "  logs          Show logs for a specific service"
    echo "  test          Test ZCAM API connection"
    echo "  help          Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 start                    # Start all Zabbix containers"
    echo "  $0 start-server             # Start only server components"
    echo "  $0 start-agent              # Start only agent"
    echo "  $0 logs zabbix-agent        # Show agent logs"
    echo "  $0 test                     # Test ZCAM API"
}

# Main script logic
main() {
    case "${1:-help}" in
        help|--help|-h)
            show_help
            exit 0
            ;;
        *)
            # Check prerequisites for non-help commands
            check_docker
            check_docker_compose
            ;;
    esac
    
    case "${1:-help}" in
        start)
            start_zabbix
            ;;
        start-server)
            start_zabbix_server
            ;;
        start-agent)
            start_zabbix_agent
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
        *)
            print_error "Unknown command: $1"
            show_help
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"
