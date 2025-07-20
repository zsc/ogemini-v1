#!/bin/bash
# Test script: OGemini Agent OCaml Project Setup
# Tests if agent can create proper OCaml project structure

set -e  # Exit on any error

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Test configuration
WORKSPACE_DIR="./workspace"
TEST_PROJECT="ocaml_2048"
GOLDEN_COPY="./toy_projects/ocaml_2048"

# Expected files after agent completes task
EXPECTED_FILES=(
    "dune-project"
    "lib/dune"
    "lib/game2048.ml"
    "bin/dune" 
    "bin/main.ml"
)

echo -e "${BLUE}🧪 Testing OGemini Agent: OCaml Project Setup${NC}"
echo "================================================"

# Step 1: Clean workspace
echo -e "${YELLOW}Step 1: Preparing test environment...${NC}"
rm -rf "${WORKSPACE_DIR}/${TEST_PROJECT}"

# Step 2: Copy golden copy to workspace  
echo -e "${YELLOW}Step 2: Copying golden copy to workspace...${NC}"
cp -r "${GOLDEN_COPY}" "${WORKSPACE_DIR}/"
echo "✅ Golden copy ready at ${WORKSPACE_DIR}/${TEST_PROJECT}"

# Step 3: Create agent task input
echo -e "${YELLOW}Step 3: Preparing agent task...${NC}"
AGENT_TASK="Look at the Python game.py file in the current directory (it's a 2048 game implementation). Set up a proper OCaml project structure for translating this to OCaml. Create:

1. A dune-project file with appropriate project metadata
2. A lib/ directory with dune file and game2048.ml stub  
3. A bin/ directory with dune file and main.ml entry point
4. Make sure the OCaml toolchain can build the project (even if just stubs)

Don't translate the full game logic yet, just set up the project structure and make sure 'dune build' works."

# Step 4: Run OGemini agent
echo -e "${YELLOW}Step 4: Running OGemini agent...${NC}"
echo "Agent task: ${AGENT_TASK}"
echo

# Create task file for agent input
TASK_FILE="${WORKSPACE_DIR}/agent_task.txt"
cat > "${TASK_FILE}" <<'TASK_EOF'
Look at the Python game.py file in the current directory (it's a 2048 game implementation). Set up a proper OCaml project structure for translating this to OCaml. Create:

1. A dune-project file with appropriate project metadata
2. A lib/ directory with dune file and game2048.ml stub  
3. A bin/ directory with dune file and main.ml entry point
4. Make sure the OCaml toolchain can build the project (even if just stubs)

Don't translate the full game logic yet, just set up the project structure and make sure 'dune build' works.
TASK_EOF

echo "Starting agent in 3 seconds..."
sleep 3

# Run agent with task file and proxy settings
source .env 2>/dev/null || true
timeout 120 docker run --rm \
  -v "$(pwd)/workspace:/workspace" \
  -w "/workspace/${TEST_PROJECT}" \
  -e https_proxy=http://192.168.3.196:7890 \
  -e http_proxy=http://192.168.3.196:7890 \
  -e all_proxy=socks5://192.168.3.196:7890 \
  -e GEMINI_API_KEY="${GEMINI_API_KEY}" \
  ogemini-secure:latest \
  bash -c "cat /workspace/agent_task.txt | /ogemini-src/_build/default/bin/main.exe" || echo "Agent completed or timed out"

# Clean up task file
rm -f "${TASK_FILE}"

# Step 5: Verify results
echo -e "${YELLOW}Step 5: Verifying agent results...${NC}"

# Check if expected files exist
MISSING_FILES=()
for file in "${EXPECTED_FILES[@]}"; do
    if [ ! -f "${WORKSPACE_DIR}/${TEST_PROJECT}/${file}" ]; then
        MISSING_FILES+=("${file}")
    fi
done

# Report results
if [ ${#MISSING_FILES[@]} -eq 0 ]; then
    echo -e "${GREEN}✅ SUCCESS: All expected files created!${NC}"
    
    # Step 6: Test OCaml toolchain
    echo -e "${YELLOW}Step 6: Testing OCaml build...${NC}"
    cd "${WORKSPACE_DIR}/${TEST_PROJECT}"
    
    if docker run --rm \
        -v "$(pwd):/workspace" \
        -w /workspace \
        ogemini-secure:latest \
        bash -c "eval \$(opam env) && dune build" 2>/dev/null; then
        echo -e "${GREEN}✅ SUCCESS: OCaml project builds successfully!${NC}"
        BUILD_SUCCESS=true
    else
        echo -e "${RED}❌ FAIL: OCaml project build failed${NC}"
        BUILD_SUCCESS=false
    fi
    
    cd - > /dev/null
else
    echo -e "${RED}❌ FAIL: Missing expected files:${NC}"
    for file in "${MISSING_FILES[@]}"; do
        echo "  - ${file}"
    done
    BUILD_SUCCESS=false
fi

# Step 7: Show created structure
echo -e "${YELLOW}Step 7: Generated project structure:${NC}"
if [ -d "${WORKSPACE_DIR}/${TEST_PROJECT}" ]; then
    tree "${WORKSPACE_DIR}/${TEST_PROJECT}" 2>/dev/null || find "${WORKSPACE_DIR}/${TEST_PROJECT}" -type f | head -20
fi

# Step 8: Cleanup
echo -e "${YELLOW}Step 8: Cleaning up...${NC}"
rm -rf "${WORKSPACE_DIR}/${TEST_PROJECT}"
echo "✅ Workspace cleaned"

# Final result
echo
echo "================================================"
if [ ${#MISSING_FILES[@]} -eq 0 ] && [ "$BUILD_SUCCESS" = true ]; then
    echo -e "${GREEN}🎉 TEST PASSED: Agent successfully set up OCaml project!${NC}"
    exit 0
else
    echo -e "${RED}💥 TEST FAILED: Agent did not complete task correctly${NC}"
    exit 1
fi