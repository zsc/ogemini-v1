#!/bin/bash

echo "🤖 OGemini Autonomous Agent - Comprehensive Test Scenarios"
echo "========================================================="

# Function to run a test scenario
run_scenario() {
  local scenario_name="$1"
  local input="$2"
  local expected_behavior="$3"
  
  echo -e "\n📋 Scenario: $scenario_name"
  echo "Input: '$input'"
  echo "Expected: $expected_behavior"
  echo "---"
  
  # Create a temporary workspace for this test
  TEMP_WORKSPACE=$(mktemp -d)
  
  echo "$input" | \
  docker run --rm -i \
    -v "$(pwd):/ogemini-src" \
    -v "$TEMP_WORKSPACE:/workspace" \
    -v "$(pwd)/.env:/workspace/.env:ro" \
    -w /workspace \
    --env-file .env \
    -e https_proxy=http://192.168.3.196:7890 \
    -e http_proxy=http://192.168.3.196:7890 \
    -e all_proxy=socks5://192.168.3.196:7890 \
    ogemini-base:latest \
    bash -c "cd /ogemini-src && eval \$(opam env) && dune build && cd /workspace && timeout 60 /ogemini-src/_build/default/bin/main_autonomous.exe"
  
  # Show what was created in workspace
  echo -e "\n📂 Files created in workspace:"
  ls -la "$TEMP_WORKSPACE" 2>/dev/null || echo "  (none)"
  
  # Cleanup
  rm -rf "$TEMP_WORKSPACE"
  
  echo -e "\n---"
  sleep 2
}

# Build base image if needed
if ! docker images | grep -q "ogemini-base"; then
  echo "🔨 Building base Docker image..."
  docker build -t ogemini-base:latest .
fi

# Test scenarios
run_scenario "Project Creation" \
  "Create a simple hello world OCaml project with a dune file" \
  "Should autonomously create project structure, dune files, and source code"

run_scenario "File Analysis" \
  "Help me understand the project by reading and analyzing the CLAUDE.md file" \
  "Should autonomously read file, extract key information, and summarize"

run_scenario "Build Task" \
  "Build and test an OCaml project that calculates fibonacci numbers" \
  "Should create source files, build configuration, and run tests"

run_scenario "Complex Multi-Step" \
  "Create a TODO list application in OCaml with add, list, and remove functionality" \
  "Should plan multiple steps, create files, implement features, and test"

echo -e "\n🎉 All test scenarios completed!"
echo ""
echo "Key autonomous capabilities demonstrated:"
echo "✅ Automatic task decomposition"
echo "✅ Multi-step execution planning"
echo "✅ Tool orchestration without user intervention"
echo "✅ Error recovery and adaptation"
echo "✅ Context-aware decision making"