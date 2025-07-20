#!/bin/bash
# Simple Docker run script for OGemini

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Build the image
echo -e "${BLUE}Building Docker image...${NC}"
docker build -t ogemini:latest .

# Create workspace if it doesn't exist
mkdir -p workspace

# Create a secure container with copied source (not mounted)
echo -e "${YELLOW}Building secure OGemini container...${NC}"
docker build -t ogemini-secure:latest -f- . <<'EOF'
FROM ogemini:latest
# Copy source code into container (not mounted)
COPY --chown=opam:opam . /ogemini-src
WORKDIR /ogemini-src
# Build OGemini inside container
RUN eval $(opam env) && dune build
# Set working directory to workspace
WORKDIR /workspace
EOF

# Run the secure container with only workspace access
echo -e "${GREEN}Starting OGemini in Docker (secure mode)...${NC}"
docker run -it --rm \
  -v "$(pwd)/workspace:/workspace" \
  -v "$(pwd)/.env:/workspace/.env:ro" \
  -w /workspace \
  ogemini-secure:latest \
  /ogemini-src/_build/default/bin/main.exe