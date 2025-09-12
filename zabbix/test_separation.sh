#!/bin/bash

# Zabbix Separation Test Script
# This script tests the separated Zabbix server and agent configuration

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

# Function to test server configuration
test_server_config() {
    print_status "Testing Zabbix server configuration..."
    
    cd "$(dirname "$0")"
    
    # Check if server compose file exists
    if [ ! -f "zabbix-server-compose.yml" ]; then
        print_error "zabbix-server-compose.yml not found"
        return 1
    fi
    
    # Validate compose file
    if docker compose -f zabbix-server-compose.yml config > /dev/null 2>&1; then
        print_success "Server compose file is valid"
    else
        print_error "Server compose file has errors"
        return 1
    fi
    
    # Check if server script exists and is executable
    if [ -x "start_zabbix_server.sh" ]; then
        print_success "Server script is executable"
    else
        print_error "Server script is not executable"
        return 1
    fi
}

# Function to test agent configuration
test_agent_config() {
    print_status "Testing Zabbix agent configuration..."
    
    cd "$(dirname "$0")"
    
    # Check if agent compose file exists
    if [ ! -f "zabbix-agent-compose.yml" ]; then
        print_error "zabbix-agent-compose.yml not found"
        return 1
    fi
    
    # Validate compose file
    if docker compose -f zabbix-agent-compose.yml config > /dev/null 2>&1; then
        print_success "Agent compose file is valid"
    else
        print_error "Agent compose file has errors"
        return 1
    fi
    
    # Check if agent script exists and is executable
    if [ -x "start_zabbix_agent.sh" ]; then
        print_success "Agent script is executable"
    else
        print_error "Agent script is not executable"
        return 1
    fi
    
    # Check agent configuration file
    if [ -f "agent2.conf" ]; then
        print_success "Agent configuration file exists"
    else
        print_error "Agent configuration file not found"
        return 1
    fi
}

# Function to test network connectivity
test_network() {
    local server_host="${1:-zabbix-server}"
    local server_port="${2:-10051}"
    
    print_status "Testing network connectivity to $server_host:$server_port..."
    
    if command -v nc >/dev/null 2>&1; then
        if nc -z "$server_host" "$server_port" 2>/dev/null; then
            print_success "Network connectivity test passed"
        else
            print_warning "Cannot reach $server_host:$server_port"
            print_warning "This is normal if the server is not running"
        fi
    else
        print_warning "netcat not available, skipping network test"
    fi
}

# Function to test Docker environment
test_docker() {
    print_status "Testing Docker environment..."
    
    # Check if Docker is running
    if ! docker info > /dev/null 2>&1; then
        print_error "Docker is not running"
        return 1
    fi
    print_success "Docker is running"
    
    # Check if docker compose is available
    if ! docker compose version &> /dev/null; then
        print_error "docker compose is not available"
        return 1
    fi
    print_success "docker compose is available"
}

# Function to show configuration summary
show_config_summary() {
    print_status "Configuration Summary:"
    echo ""
    echo "Server Configuration:"
    echo "  - Compose file: zabbix-server-compose.yml"
    echo "  - Start script: start_zabbix_server.sh"
    echo "  - Web interface: http://localhost:8080"
    echo "  - Server port: 10051"
    echo "  - Database port: 3306"
    echo ""
    echo "Agent Configuration:"
    echo "  - Compose file: zabbix-agent-compose.yml"
    echo "  - Start script: start_zabbix_agent.sh"
    echo "  - Agent port: 10050"
    echo "  - Server host: ${ZBX_SERVER_HOST:-zabbix-server}"
    echo "  - Server port: ${ZBX_SERVER_PORT:-10051}"
    echo ""
    echo "Environment Variables:"
    echo "  - ZBX_SERVER_HOST: ${ZBX_SERVER_HOST:-zabbix-server (default)}"
    echo "  - ZBX_SERVER_PORT: ${ZBX_SERVER_PORT:-10051 (default)}"
    echo "  - ZBX_HOSTNAME: ${ZBX_HOSTNAME:-kevin-telemetry-zabbix-agent (default)}"
}

# Function to show help
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --server-only    Test only server configuration"
    echo "  --agent-only     Test only agent configuration"
    echo "  --network HOST   Test network connectivity to HOST"
    echo "  --summary        Show configuration summary"
    echo "  --help           Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                           # Test all configurations"
    echo "  $0 --server-only            # Test only server"
    echo "  $0 --network 192.168.1.100  # Test network to specific host"
    echo "  $0 --summary                # Show configuration summary"
}

# Main script logic
main() {
    local test_server=true
    local test_agent=true
    local network_host=""
    local show_summary=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --server-only)
                test_agent=false
                shift
                ;;
            --agent-only)
                test_server=false
                shift
                ;;
            --network)
                network_host="$2"
                shift 2
                ;;
            --summary)
                show_summary=true
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Test Docker environment
    if ! test_docker; then
        exit 1
    fi
    
    # Test configurations
    local failed=false
    
    if [ "$test_server" = true ]; then
        if ! test_server_config; then
            failed=true
        fi
    fi
    
    if [ "$test_agent" = true ]; then
        if ! test_agent_config; then
            failed=true
        fi
    fi
    
    # Test network if specified
    if [ -n "$network_host" ]; then
        test_network "$network_host"
    fi
    
    # Show summary if requested
    if [ "$show_summary" = true ]; then
        show_config_summary
    fi
    
    # Final result
    if [ "$failed" = true ]; then
        print_error "Some tests failed"
        exit 1
    else
        print_success "All tests passed"
    fi
}

# Run main function with all arguments
main "$@"
