#!/bin/bash
# Simple Docker run script for OGemini

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Build the base image
echo -e "${BLUE}Building Docker base image...${NC}"
docker build -t ogemini-base:latest .

# Create workspace if it doesn't exist
mkdir -p workspace

# Create a built container with copied source and internal build
echo -e "${YELLOW}Building OGemini container with internal build...${NC}"
docker build -t ogemini-built:latest -f- . <<'EOF'
FROM ogemini-base:latest
# Copy source code into container (not mounted)
COPY --chown=opam:opam . /ogemini-src
WORKDIR /ogemini-src
# Build OGemini inside container
RUN eval $(opam env) && dune build
# Set working directory to workspace
WORKDIR /workspace
EOF

# Clean up old ogemini-secure image if it exists
echo -e "${YELLOW}Cleaning up old images...${NC}"
docker image rm ogemini-secure:latest 2>/dev/null || true

# Load environment variables
echo -e "${YELLOW}Loading environment variables...${NC}"
if [ ! -f .env ]; then
    echo -e "${RED}❌ FAIL: .env file not found${NC}"
    exit 1
fi
source .env
if [ -z "$GEMINI_API_KEY" ]; then
    echo -e "${RED}❌ FAIL: GEMINI_API_KEY not set in .env${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Environment loaded${NC}"

# Run the built container with only workspace access
echo -e "${GREEN}Starting OGemini in Docker...${NC}"
docker run -it --rm \
  -v "$(pwd)/workspace:/workspace" \
  -v "$(pwd)/.env:/workspace/.env:ro" \
  -w /workspace \
  -e https_proxy=http://127.0.0.1:7890 \
  -e http_proxy=http://127.0.0.1:7890 \
  -e all_proxy=socks5://127.0.0.1:7890 \
  -e GEMINI_API_KEY="${GEMINI_API_KEY}" \
  ogemini-built:latest \
  /ogemini-src/_build/default/bin/main.exe