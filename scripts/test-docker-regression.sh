#!/bin/bash
# Docker Container Build Regression Test: Tests that container-internal build works correctly
# This replaces host-based builds with Docker-internal builds to avoid macOS/Linux binary incompatibility

set -e  # Exit on any error

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}🐳 Docker Container Build Regression Test${NC}"
echo "================================================"

echo -e "${YELLOW}Step 1: Building base Docker image...${NC}"
if ! docker build -t ogemini-base:latest . >/dev/null 2>&1; then
    echo -e "${RED}❌ FAIL: Base Docker image build failed${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Base Docker image built successfully${NC}"

echo -e "${YELLOW}Step 2: Building OGemini with container-internal dune build...${NC}"
docker build -t ogemini-built:latest -f- . <<'EOF'
FROM ogemini-base:latest
COPY --chown=opam:opam . /ogemini-src
WORKDIR /ogemini-src
RUN eval $(opam env) && dune build
WORKDIR /workspace
EOF

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ FAIL: Container-internal dune build failed${NC}"
    exit 1
fi

# Clean up old ogemini-secure image if it exists
echo -e "${YELLOW}Cleaning up old images...${NC}"
docker image rm ogemini-secure:latest 2>/dev/null || true

echo -e "${GREEN}✅ Container-internal dune build succeeded${NC}"

echo -e "${YELLOW}Step 3: Verifying binary exists and is Linux-compatible...${NC}"
BINARY_CHECK=$(docker run --rm ogemini-built:latest file /ogemini-src/_build/default/bin/main.exe)
if echo "$BINARY_CHECK" | grep -q "ELF.*Linux"; then
    echo -e "${GREEN}✅ Binary is Linux ELF format (correct for container)${NC}"
else
    echo -e "${RED}❌ FAIL: Binary format unexpected: $BINARY_CHECK${NC}"
    exit 1
fi

echo -e "${YELLOW}Step 4: Testing basic Q&A functionality in container...${NC}"
# Create workspace if it doesn't exist
mkdir -p workspace

# Check if .env exists
if [ ! -f .env ]; then
    echo -e "${RED}❌ FAIL: .env file not found${NC}"
    exit 1
fi

# Test basic math Q&A (no tools)
OUTPUT=$(echo "2+2=?" | timeout 30 docker run --rm -i \
  -v "$(pwd)/workspace:/workspace" \
  -v "$(pwd)/.env:/workspace/.env:ro" \
  -w /workspace \
  -e https_proxy=http://192.168.3.196:7890 \
  -e http_proxy=http://192.168.3.196:7890 \
  -e all_proxy=socks5://192.168.3.196:7890 \
  ogemini-built:latest \
  /ogemini-src/_build/default/bin/main.exe 2>&1)

if echo "$OUTPUT" | grep -q "2 + 2 = 4"; then
    echo -e "${GREEN}✅ Basic Q&A working in container${NC}"
else
    echo -e "${RED}❌ FAIL: Basic Q&A not working${NC}"
    echo "Output: $OUTPUT"
    exit 1
fi

echo -e "${YELLOW}Step 5: Testing tool functionality in container...${NC}"
# Test file listing (requires tools)
TOOL_OUTPUT=$(echo "List the files in the current directory" | timeout 45 docker run --rm -i \
  -v "$(pwd)/workspace:/workspace" \
  -v "$(pwd)/.env:/workspace/.env:ro" \
  -w /workspace \
  -e https_proxy=http://192.168.3.196:7890 \
  -e http_proxy=http://192.168.3.196:7890 \
  -e all_proxy=socks5://192.168.3.196:7890 \
  ogemini-built:latest \
  /ogemini-src/_build/default/bin/main.exe 2>&1)

# Check if tools were detected and used
if echo "$TOOL_OUTPUT" | grep -q "🔧 Tool call: list_files"; then
    echo -e "${GREEN}✅ Tool detection working in container${NC}"
else
    echo -e "${RED}❌ FAIL: Tool was not detected/called in container${NC}"
    echo "Tool Output: $TOOL_OUTPUT"
    exit 1
fi

# Check if tool execution succeeded
if echo "$TOOL_OUTPUT" | grep -q "✅ Tool result:"; then
    echo -e "${GREEN}✅ Tool execution working in container${NC}"
else
    echo -e "${RED}❌ FAIL: Tool execution failed in container${NC}"
    exit 1
fi

echo -e "${YELLOW}Step 6: Verifying API integration in container...${NC}"
# Check that API key was loaded
if echo "$TOOL_OUTPUT" | grep -q "✅ API key loaded:"; then
    echo -e "${GREEN}✅ API key properly loaded in container${NC}"
else
    echo -e "${RED}❌ FAIL: API key not loaded in container${NC}"
    exit 1
fi

# Check that API call succeeded  
if echo "$TOOL_OUTPUT" | grep -q "📥 Full Response:"; then
    echo -e "${GREEN}✅ API integration working in container${NC}"
else
    echo -e "${RED}❌ FAIL: API integration issue in container${NC}"
    exit 1
fi

echo
echo "================================================"
echo -e "${GREEN}🎉 DOCKER CONTAINER BUILD REGRESSION TEST PASSED${NC}"
echo -e "${GREEN}✅ Container build: Working${NC}"
echo -e "${GREEN}✅ Binary compatibility: Working${NC}"
echo -e "${GREEN}✅ Basic Q&A: Working${NC}"
echo -e "${GREEN}✅ Tool system: Working${NC}"
echo -e "${GREEN}✅ API integration: Working${NC}"
echo -e "${GREEN}✅ Complete Docker workflow: Working${NC}"
echo
echo -e "${BLUE}This test verifies:${NC}"
echo "- Docker base image builds successfully"
echo "- Container-internal dune build works (avoids macOS/Linux binary issues)"
echo "- Generated binary is Linux ELF format"
echo "- Basic Q&A functionality works in container"
echo "- Tool detection and execution works in container"
echo "- API integration works in containerized environment"
echo "- Complete end-to-end Docker workflow is functional"