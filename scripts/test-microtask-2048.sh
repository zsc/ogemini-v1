#!/bin/bash

# Test micro-task decomposition with OCaml 2048 translation
# This script tests the Phase 7.2 micro-task system

echo "🔬 Testing Phase 7.2 Micro-Task Decomposition System"
echo "===================================================="
echo ""

# Ensure we're in the correct directory
cd /Users/zsc/Downloads/ogemini

# Create clean workspace
WORKSPACE_DIR="/Users/zsc/d/ogemini/workspace-microtask-test"
mkdir -p "$WORKSPACE_DIR"
rm -rf "$WORKSPACE_DIR"/*

# Copy the Python 2048 source for translation
mkdir -p "$WORKSPACE_DIR"
cp toy_projects/ocaml_2048/game.py "$WORKSPACE_DIR/"

echo "📋 Test Task: Translate Python 2048 to OCaml with micro-task decomposition"
echo "📁 Workspace: $WORKSPACE_DIR"
echo "🎯 Expected: System should use micro-task decomposition for this complex task"
echo ""

# Create input file for automated test
cat > /tmp/microtask_input.txt << 'EOF'
Translate the Python 2048 game in game.py to OCaml with bit-level precision. Create a complete OCaml project with proper dune configuration, maintain all game logic, and ensure it compiles and runs correctly.
exit
EOF

echo "🚀 Starting micro-task test..."

# Run the autonomous agent with the complex task
docker run --rm -i \
  -e https_proxy=http://192.168.3.196:7890 \
  -e http_proxy=http://192.168.3.196:7890 \
  -e all_proxy=socks5://192.168.3.196:7890 \
  --env-file .env \
  -v "$(pwd):/ogemini-src" \
  -v "$WORKSPACE_DIR:/workspace" \
  ogemini-base:latest \
  /bin/bash -c "cd /ogemini-src && timeout 300 dune exec bin/main_autonomous.exe" \
  < /tmp/microtask_input.txt > "traces/microtask_2048_test_$(date +%Y%m%d_%H%M%S).log" 2>&1

# Get the latest trace file
TRACE_FILE=$(ls -t traces/microtask_2048_test_*.log | head -1)

echo ""
echo "📊 Test Results Analysis"
echo "======================="

if [ -f "$TRACE_FILE" ]; then
    echo "✅ Trace file created: $TRACE_FILE"
    
    # Check for micro-task indicators
    if grep -q "🔍 Micro-task decomposition" "$TRACE_FILE"; then
        echo "✅ Micro-task decomposition activated"
    else
        echo "❌ Micro-task decomposition not activated"
    fi
    
    # Check for complex task classification
    if grep -q "Complex.*task" "$TRACE_FILE"; then
        echo "✅ Complex task correctly classified"
    else
        echo "❌ Task classification issue"
    fi
    
    # Check for template usage
    if grep -q "template.*2048" "$TRACE_FILE"; then
        echo "✅ OCaml 2048 template used"
    else
        echo "❌ Template not used"
    fi
    
    # Check error patterns
    ERROR_COUNT=$(grep -c "❌" "$TRACE_FILE" || echo "0")
    SUCCESS_COUNT=$(grep -c "✅" "$TRACE_FILE" || echo "0")
    
    echo "📈 Execution Stats:"
    echo "   Successes: $SUCCESS_COUNT"
    echo "   Errors: $ERROR_COUNT"
    
    # Show final result
    echo ""
    echo "📄 Final 20 lines of execution:"
    tail -20 "$TRACE_FILE"
    
else
    echo "❌ No trace file generated"
fi

# Check workspace for created files
echo ""
echo "📁 Workspace Contents:"
echo "====================="
ls -la "$WORKSPACE_DIR" || echo "Workspace not accessible"

echo ""
echo "🔍 Check trace file for detailed analysis: $TRACE_FILE"

# Cleanup
rm -f /tmp/microtask_input.txt