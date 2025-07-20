#!/bin/bash
# Docker Basic Q&A Regression Test: Verify simple questions work without tools
# Tests the actual Docker environment with proxy setup

set -e  # Exit on any error

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}🧪 Docker Basic Q&A Regression Test${NC}"
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

echo -e "${YELLOW}Step 3: Running Docker container with basic Q&A...${NC}"

# Run the test in Docker with direct OCaml compilation
OUTPUT=$(echo "2+2=?" | timeout 30 docker run --rm -i \
  -v "$(pwd):/ogemini-src" \
  -v "$(pwd)/.env:/workspace/.env:ro" \
  -w /ogemini-src \
  -e https_proxy=http://127.0.0.1:7890 \
  -e http_proxy=http://127.0.0.1:7890 \
  -e all_proxy=socks5://127.0.0.1:7890 \
  -e GEMINI_API_KEY="${GEMINI_API_KEY}" \
  ogemini-secure:latest \
  bash -c "eval \$(opam env) && ocamlfind ocamlc -package lwt,lwt.unix,yojson,re,unix,str -linkpkg -I lib lib/types.ml lib/config.ml lib/ui.ml lib/api_client.ml lib/event_parser.ml lib/tools/file_tools.ml lib/tools/shell_tools.ml lib/tools/build_tools.ml bin/main.ml -o main_temp && ./main_temp" 2>&1)

echo -e "${YELLOW}Step 4: Verifying response format...${NC}"

# Check for successful completion
if echo "$OUTPUT" | grep -q "🤖 Assistant:"; then
    echo -e "${GREEN}✅ Got assistant response${NC}"
else
    echo -e "${RED}❌ FAIL: No assistant response found${NC}"
    echo "Output: $OUTPUT"
    exit 1
fi

# Check that no tools were used (should be clean request)
if echo "$OUTPUT" | grep -q "🔧 Tool call:"; then
    echo -e "${RED}❌ FAIL: Tools were called for simple math question${NC}"
    exit 1
fi
echo -e "${GREEN}✅ No tools called (correct for simple Q&A)${NC}"

# Check API request format (should not include tools)
if echo "$OUTPUT" | grep -q '"contents":\[{"parts":\[{"text":"2+2=?"}]}]}'; then
    echo -e "${GREEN}✅ Clean API request without tools${NC}"
else
    echo -e "${RED}❌ FAIL: API request format incorrect${NC}"
    exit 1
fi

# Check for correct answer
if echo "$OUTPUT" | grep -i -q "4"; then
    echo -e "${GREEN}✅ Correct mathematical answer${NC}"
else
    echo -e "${RED}❌ FAIL: Incorrect or missing answer${NC}"
    exit 1
fi

echo -e "${YELLOW}Step 5: Verifying Docker environment...${NC}"

# Check that Docker environment is working properly
if echo "$OUTPUT" | grep -q "✅ Using model: gemini-2.0-flash"; then
    echo -e "${GREEN}✅ Gemini API integration working${NC}"
else
    echo -e "${RED}❌ FAIL: API integration issue${NC}"
    exit 1
fi

if echo "$OUTPUT" | grep -q "✅ API key loaded:"; then
    echo -e "${GREEN}✅ API key properly loaded in Docker${NC}"
else
    echo -e "${RED}❌ FAIL: API key not loaded${NC}"
    exit 1
fi

echo
echo "================================================"
echo -e "${GREEN}🎉 DOCKER BASIC Q&A TEST PASSED${NC}"
echo -e "${GREEN}✅ Docker environment: Working${NC}"
echo -e "${GREEN}✅ Proxy setup: Working${NC}"
echo -e "${GREEN}✅ API integration: Working${NC}"
echo -e "${GREEN}✅ Tool detection: Working (no tools for simple Q&A)${NC}"
echo -e "${GREEN}✅ Response parsing: Working${NC}"
echo
echo -e "${BLUE}This test verifies:${NC}"
echo "- Docker containerized environment works"
echo "- Proxy settings are properly configured"
echo "- Simple questions don't trigger tool calls"
echo "- API requests are clean without tool declarations"
echo "- Mathematical reasoning works correctly"