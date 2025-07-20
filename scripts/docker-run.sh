#!/bin/bash
# Convenient script to run OGemini in Docker

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default values
WORKSPACE_DIR="./workspace"
MODE="agent"  # agent or dev

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dev)
            MODE="dev"
            shift
            ;;
        --workspace)
            WORKSPACE_DIR="$2"
            shift 2
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  --dev          Start in development mode (bash shell)"
            echo "  --workspace    Set workspace directory (default: ./workspace)"
            echo "  --help         Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Create workspace directory if it doesn't exist
if [ ! -d "$WORKSPACE_DIR" ]; then
    echo -e "${BLUE}Creating workspace directory: $WORKSPACE_DIR${NC}"
    mkdir -p "$WORKSPACE_DIR"
fi

# Check if .env file exists
if [ ! -f ".env" ]; then
    echo -e "${YELLOW}Warning: .env file not found. API key may not be available.${NC}"
fi

# Build the Docker image if needed
echo -e "${BLUE}Building Docker image...${NC}"
docker-compose build ogemini

# Run the appropriate container
if [ "$MODE" = "dev" ]; then
    echo -e "${GREEN}Starting OGemini in development mode...${NC}"
    docker-compose run --rm ogemini-dev
else
    echo -e "${GREEN}Starting OGemini agent...${NC}"
    echo -e "${BLUE}Workspace mounted at: $WORKSPACE_DIR${NC}"
    docker-compose run --rm -v "$(pwd)/$WORKSPACE_DIR:/workspace" ogemini
fi