#!/bin/bash

# MPZSQL FlightSQL Client Runner
# This script runs the MPZSQL demo client using UV with predefined connection parameters

set -e  # Exit on any error

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MPZSQL_DIR="$PROJECT_ROOT/mpzsql"
CLIENT_SCRIPT="$MPZSQL_DIR/src/demo_client/client.py"
CERTIFICATE_PATH="$PROJECT_ROOT/secrets/certs/letsencrypt-server.crt"

# Connection parameters
HOST="mpzsql-dev-app.gentlesky-02d35219.swedencentral.azurecontainerapps.io"
PORT="8080"
USERNAME="user"
PASSWORD="iamsecret"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 MPZSQL FlightSQL Client Runner${NC}"
echo "============================================"

# Check if UV is installed
if ! command -v uv &> /dev/null; then
    echo -e "${RED}❌ UV is not installed. Please install UV first:${NC}"
    echo "curl -LsSf https://astral.sh/uv/install.sh | sh"
    exit 1
fi

# Check if client script exists
if [ ! -f "$CLIENT_SCRIPT" ]; then
    echo -e "${RED}❌ Client script not found: $CLIENT_SCRIPT${NC}"
    exit 1
fi

# Check if certificate exists
if [ ! -f "$CERTIFICATE_PATH" ]; then
    echo -e "${RED}❌ Certificate file not found: $CERTIFICATE_PATH${NC}"
    exit 1
fi

# Change to the mpzsql directory
cd "$MPZSQL_DIR"

echo -e "${BLUE}📁 Working directory: $(pwd)${NC}"
echo -e "${BLUE}🔐 Host: $HOST${NC}"
echo -e "${BLUE}🚪 Port: $PORT${NC}"
echo -e "${BLUE}👤 Username: $USERNAME${NC}"
echo -e "${BLUE}🗝️  Password: [HIDDEN]${NC}"
echo -e "${BLUE}📜 Certificate: $CERTIFICATE_PATH${NC}"
echo ""

# Function to run client command
run_client() {
    local command="$1"
    shift
    local args=("$@")
    
    echo -e "${YELLOW}🔄 Running: uv run python $CLIENT_SCRIPT $command ${args[*]}${NC}"
    echo "----------------------------------------"
    
    uv run python "$CLIENT_SCRIPT" "$command" \
        "${args[@]}" \
        --host "$HOST" \
        --port "$PORT" \
        --user "$USERNAME" \
        --password "$PASSWORD" \
        --cert "$CERTIFICATE_PATH"
}

# Parse command line arguments
case "${1:-connect}" in
    "test")
        echo -e "${BLUE}🧪 Testing connection...${NC}"
        run_client "test-connection"
        ;;
    "query")
        if [ -z "$2" ]; then
            echo -e "${RED}❌ Query command requires a SQL query argument${NC}"
            echo "Usage: $0 query \"SELECT 1\""
            exit 1
        fi
        echo -e "${BLUE}🔍 Executing query: $2${NC}"
        run_client "query" "$2"
        ;;
    "execute")
        if [ -z "$2" ]; then
            echo -e "${RED}❌ Execute command requires a SQL statement argument${NC}"
            echo "Usage: $0 execute \"CREATE TABLE test (id INT)\""
            exit 1
        fi
        echo -e "${BLUE}⚡ Executing statement: $2${NC}"
        run_client "execute" "$2"
        ;;
    "connect"|"interactive")
        echo -e "${BLUE}🎯 Starting interactive mode...${NC}"
        run_client "connect" "--interactive"
        ;;
    "help"|"-h"|"--help")
        echo -e "${GREEN}MPZSQL FlightSQL Client Runner${NC}"
        echo ""
        echo -e "${YELLOW}Usage:${NC}"
        echo "  $0 [command] [args...]"
        echo ""
        echo -e "${YELLOW}Commands:${NC}"
        echo "  connect, interactive    Start interactive mode (default)"
        echo "  test                    Test connection without interactive mode"
        echo "  query \"SQL\"             Execute a single SQL query"
        echo "  execute \"SQL\"           Execute a DDL/DML statement"
        echo "  help                    Show this help message"
        echo ""
        echo -e "${YELLOW}Examples:${NC}"
        echo "  $0                                    # Interactive mode"
        echo "  $0 test                               # Test connection"
        echo "  $0 query \"SELECT 1\"                  # Execute query"
        echo "  $0 execute \"CREATE TABLE test (id INT)\" # Execute statement"
        ;;
    *)
        echo -e "${RED}❌ Unknown command: $1${NC}"
        echo "Use '$0 help' for usage information"
        exit 1
        ;;
esac

echo ""
echo -e "${GREEN}✅ Client execution completed${NC}"
