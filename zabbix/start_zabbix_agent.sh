#!/bin/bash

# Zabbix Agent Management Script
# This script helps manage the Zabbix agent

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

# Function to check Zabbix server connectivity
check_server_connectivity() {
    local server_host="${ZBX_SERVER_HOST:-zabbix-server}"
    local server_port="${ZBX_SERVER_PORT:-10051}"
    
    print_status "Checking connectivity to Zabbix server at $server_host:$server_port..."
    
    if command -v nc >/dev/null 2>&1; then
        if nc -z "$server_host" "$server_port" 2>/dev/null; then
            print_success "Zabbix server is reachable"
        else
            print_warning "Cannot reach Zabbix server at $server_host:$server_port"
            print_warning "Make sure the Zabbix server is running and accessible"
        fi
    else
        print_warning "netcat not available, skipping connectivity check"
    fi
}

# Function to start Zabbix agent
start_zabbix_agent() {
    print_status "Starting Zabbix agent..."
    
    # Change to the zabbix directory
    cd "$(dirname "$0")"
    
    # Check server connectivity
    check_server_connectivity
    
    # Start Zabbix agent
    docker compose -f zabbix-agent-compose.yml up -d
    
    print_success "Zabbix agent started successfully"
    print_status "Agent Hostname: kevin-telemetry-zabbix-agent"
    print_status "Agent Port: 10050"
    print_status "Server Host: ${ZBX_SERVER_HOST:-zabbix-server}"
    print_status "Server Port: ${ZBX_SERVER_PORT:-10051}"
}

# Function to stop Zabbix agent
stop_zabbix_agent() {
    print_status "Stopping Zabbix agent..."
    
    cd "$(dirname "$0")"
    
    docker compose -f zabbix-agent-compose.yml down
    
    print_success "Zabbix agent stopped successfully"
}

# Function to restart Zabbix agent
restart_zabbix_agent() {
    print_status "Restarting Zabbix agent..."
    
    stop_zabbix_agent
    sleep 3
    start_zabbix_agent
    
    print_success "Zabbix agent restarted successfully"
}

# Function to show Zabbix agent status
show_status() {
    print_status "Zabbix agent status:"
    
    cd "$(dirname "$0")"
    
    docker compose -f zabbix-agent-compose.yml ps
}

# Function to show Zabbix agent logs
show_logs() {
    print_status "Showing Zabbix agent logs..."
    
    cd "$(dirname "$0")"
    
    docker compose -f zabbix-agent-compose.yml logs -f zabbix-agent
}

# Function to test agent configuration
test_config() {
    print_status "Testing Zabbix agent configuration..."
    
    cd "$(dirname "$0")"
    
    # Test agent configuration file
    if docker compose -f zabbix-agent-compose.yml exec zabbix-agent zabbix_agent2 -t; then
        print_success "Agent configuration is valid"
    else
        print_error "Agent configuration has errors"
        exit 1
    fi
}

# Function to show help
show_help() {
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  start     Start Zabbix agent"
    echo "  stop      Stop Zabbix agent"
    echo "  restart   Restart Zabbix agent"
    echo "  status    Show Zabbix agent status"
    echo "  logs      Show Zabbix agent logs"
    echo "  test      Test agent configuration"
    echo "  help      Show this help message"
    echo ""
    echo "Environment Variables:"
    echo "  ZBX_SERVER_HOST  Zabbix server hostname (default: zabbix-server)"
    echo "  ZBX_SERVER_PORT  Zabbix server port (default: 10051)"
    echo ""
    echo "Examples:"
    echo "  $0 start                                    # Start agent with default settings"
    echo "  $0 start ZBX_SERVER_HOST=192.168.1.100     # Start agent with custom server"
    echo "  $0 logs                                     # Show agent logs"
    echo "  $0 test                                     # Test configuration"
}

# Main script logic
main() {
    # Check prerequisites
    check_docker
    check_docker_compose
    
    case "${1:-help}" in
        start)
            start_zabbix_agent
            ;;
        stop)
            stop_zabbix_agent
            ;;
        restart)
            restart_zabbix_agent
            ;;
        status)
            show_status
            ;;
        logs)
            show_logs
            ;;
        test)
            test_config
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
