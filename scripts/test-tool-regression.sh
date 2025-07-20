#!/bin/bash
# Tool Regression Test: Verify tool detection and execution works correctly
# Tests that the agent properly uses tools for file operations

set -e  # Exit on any error

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}🧪 Tool Regression Test: list_files functionality${NC}"
echo "================================================"

# Expected files that should exist in the project root
EXPECTED_FILES=(
    "CLAUDE.md"
    "dune-project"
    "bin"
    "lib"
    ".env"
)

echo -e "${YELLOW}Step 1: Running OGemini with file listing request...${NC}"

# Run the agent and capture output
OUTPUT=$(source .env && echo "List the files in the current directory" | timeout 30 dune exec ./bin/main.exe 2>&1)

echo -e "${YELLOW}Step 2: Verifying tool detection...${NC}"

# Check if tools were detected and used
if echo "$OUTPUT" | grep -q "🔧 Tool call: list_files"; then
    echo -e "${GREEN}✅ Tool detection working: list_files was called${NC}"
else
    echo -e "${RED}❌ FAIL: Tool was not detected/called${NC}"
    exit 1
fi

# Check if tool execution succeeded
if echo "$OUTPUT" | grep -q "✅ Tool result:"; then
    echo -e "${GREEN}✅ Tool execution working: Got successful result${NC}"
else
    echo -e "${RED}❌ FAIL: Tool execution failed${NC}"
    exit 1
fi

echo -e "${YELLOW}Step 3: Verifying expected files are listed...${NC}"

# Check if expected files appear in the output
MISSING_FILES=()
for file in "${EXPECTED_FILES[@]}"; do
    if ! echo "$OUTPUT" | grep -q "$file"; then
        MISSING_FILES+=("$file")
    fi
done

if [ ${#MISSING_FILES[@]} -eq 0 ]; then
    echo -e "${GREEN}✅ All expected files found in listing${NC}"
else
    echo -e "${RED}❌ FAIL: Missing expected files:${NC}"
    for file in "${MISSING_FILES[@]}"; do
        echo "  - $file"
    done
    exit 1
fi

echo -e "${YELLOW}Step 4: Verifying API request format...${NC}"

# Check that tools were included in the API request (not like the 2+2 case)
if echo "$OUTPUT" | grep -q '"tools":\[{"function_dec'; then
    echo -e "${GREEN}✅ Tool declarations included in API request${NC}"
else
    echo -e "${RED}❌ FAIL: Tools not included in API request${NC}"
    exit 1
fi

echo
echo "================================================"
echo -e "${GREEN}🎉 TOOL REGRESSION TEST PASSED${NC}"
echo -e "${GREEN}✅ Tool detection: Working${NC}"
echo -e "${GREEN}✅ Tool execution: Working${NC}"  
echo -e "${GREEN}✅ File listing: Working${NC}"
echo -e "${GREEN}✅ API integration: Working${NC}"
echo
echo -e "${BLUE}This test verifies:${NC}"
echo "- Smart tool detection for file operations"
echo "- Proper API request with tool declarations"
echo "- Successful tool execution and result parsing"
echo "- Expected project files are accessible"