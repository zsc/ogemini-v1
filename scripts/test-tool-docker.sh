#!/bin/bash
# Docker Tool Regression Test: Verify tool detection and execution in Docker environment
# Tests the actual containerized environment with proxy setup

set -e  # Exit on any error

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}🧪 Docker Tool Regression Test${NC}"
echo "================================================"

echo -e "${YELLOW}Step 1: Checking Docker image availability...${NC}"
if ! docker images | grep -q "ogemini-secure"; then
    echo -e "${RED}❌ FAIL: ogemini-secure Docker image not found${NC}"
    echo "Please build the Docker image first"
    exit 1
fi
echo -e "${GREEN}✅ Docker image found${NC}"

echo -e "${YELLOW}Step 2: Loading environment variables...${NC}"
if [ ! -f .env ]; then
    echo -e "${RED}❌ FAIL: .env file not found${NC}"
    exit 1
fi
source .env
if [ -z "$GEMINI_API_KEY" ]; then
    echo -e "${RED}❌ FAIL: GEMINI_API_KEY not set${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Environment loaded${NC}"

echo -e "${YELLOW}Step 3: Running Docker container with file listing request...${NC}"

# Run the test in Docker with direct OCaml compilation
OUTPUT=$(echo "List the files in the current directory" | timeout 45 docker run --rm -i \
  -v "$(pwd):/ogemini-src" \
  -v "$(pwd)/.env:/workspace/.env:ro" \
  -w /ogemini-src \
  -e https_proxy=http://127.0.0.1:7890 \
  -e http_proxy=http://127.0.0.1:7890 \
  -e all_proxy=socks5://127.0.0.1:7890 \
  -e GEMINI_API_KEY="${GEMINI_API_KEY}" \
  ogemini-secure:latest \
  bash -c "eval \$(opam env) && ocamlfind ocamlc -package lwt,lwt.unix,yojson,re,unix,str -linkpkg -I lib lib/types.ml lib/config.ml lib/ui.ml lib/api_client.ml lib/event_parser.ml lib/tools/file_tools.ml lib/tools/shell_tools.ml lib/tools/build_tools.ml bin/main.ml -o main_temp && ./main_temp" 2>&1)

echo -e "${YELLOW}Step 4: Verifying tool detection and execution...${NC}"

# Check if tools were detected and used
if echo "$OUTPUT" | grep -q "🔧 Tool call: list_files"; then
    echo -e "${GREEN}✅ Tool detection working: list_files was called${NC}"
else
    echo -e "${RED}❌ FAIL: Tool was not detected/called${NC}"
    echo "Output: $OUTPUT"
    exit 1
fi

# Check if tool execution succeeded
if echo "$OUTPUT" | grep -q "✅ Tool result:"; then
    echo -e "${GREEN}✅ Tool execution working: Got successful result${NC}"
else
    echo -e "${RED}❌ FAIL: Tool execution failed${NC}"
    exit 1
fi

echo -e "${YELLOW}Step 5: Verifying API request format...${NC}"

# Check that tools were included in the API request (unlike the 2+2 case)
if echo "$OUTPUT" | grep -q '"tools":\[{"function_dec'; then
    echo -e "${GREEN}✅ Tool declarations included in API request${NC}"
else
    echo -e "${RED}❌ FAIL: Tools not included in API request${NC}"
    exit 1
fi

echo -e "${YELLOW}Step 6: Verifying Docker workspace files...${NC}"

# Expected files that should exist in the Docker workspace
# Note: In the secure container, we're in /workspace, not the source directory
EXPECTED_DOCKER_FILES=(
    "ogemini-src"  # Source should be copied to container
)

# Check if we can see the expected Docker environment structure
if echo "$OUTPUT" | grep -q "ogemini-src"; then
    echo -e "${GREEN}✅ Docker workspace structure correct${NC}"
else
    echo -e "${YELLOW}⚠️  Note: Running in different workspace context${NC}"
fi

echo -e "${YELLOW}Step 7: Verifying Docker environment integration...${NC}"

# Check that Docker environment is working properly
if echo "$OUTPUT" | grep -q "✅ Using model: gemini-2.0-flash"; then
    echo -e "${GREEN}✅ Gemini API integration working in Docker${NC}"
else
    echo -e "${RED}❌ FAIL: API integration issue in Docker${NC}"
    exit 1
fi

if echo "$OUTPUT" | grep -q "✅ API key loaded:"; then
    echo -e "${GREEN}✅ API key properly loaded in Docker${NC}"
else
    echo -e "${RED}❌ FAIL: API key not loaded in Docker${NC}"
    exit 1
fi

# Check proxy is working (API call succeeded)
if echo "$OUTPUT" | grep -q "📥 Full Response:"; then
    echo -e "${GREEN}✅ Proxy setup working (API call succeeded)${NC}"
else
    echo -e "${RED}❌ FAIL: Proxy setup issue (no API response)${NC}"
    exit 1
fi

echo
echo "================================================"
echo -e "${GREEN}🎉 DOCKER TOOL REGRESSION TEST PASSED${NC}"
echo -e "${GREEN}✅ Docker environment: Working${NC}"
echo -e "${GREEN}✅ Proxy setup: Working${NC}"
echo -e "${GREEN}✅ Tool detection: Working${NC}"
echo -e "${GREEN}✅ Tool execution: Working${NC}"  
echo -e "${GREEN}✅ API integration: Working${NC}"
echo -e "${GREEN}✅ Containerized workflow: Working${NC}"
echo
echo -e "${BLUE}This test verifies:${NC}"
echo "- Docker containerized environment with proxy"
echo "- Smart tool detection for file operations"
echo "- Successful tool execution in isolated container"
echo "- Proper API request format with tool declarations"
echo "- Complete containerized agent workflow"