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

# Run the container with OCaml interpreter
echo -e "${GREEN}Starting OGemini in Docker (interpreter mode)...${NC}"
docker run -it --rm \
  -v "$(pwd):/ogemini" \
  -v "$(pwd)/workspace:/workspace" \
  -v "$(pwd)/.env:/workspace/.env:ro" \
  -w /workspace \
  ogemini:latest \
  bash -c "cd /ogemini && eval \$(opam env) && dune exec ./bin/main.exe"