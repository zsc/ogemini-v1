#!/bin/bash

# Test Phase 8.1: Template-free autonomous system
# This script verifies that the Agent can work without pre-programmed templates

echo "🔬 Testing Phase 8.1: Template-Free Autonomous System"
echo "===================================================="
echo ""

# Ensure we're in the correct directory
cd /Users/zsc/Downloads/ogemini

# Create clean workspace for template-free test
WORKSPACE_DIR="/Users/zsc/d/ogemini/workspace-templatefree-test"
mkdir -p "$WORKSPACE_DIR"
rm -rf "$WORKSPACE_DIR"/*

# Copy the Python 2048 source for translation (same as before)
cp toy_projects/ocaml_2048/game.py "$WORKSPACE_DIR/"

echo "📋 Test Task: Template-free OCaml 2048 translation"
echo "📁 Workspace: $WORKSPACE_DIR"
echo "🎯 Expected: System should work WITHOUT any pre-programmed templates"
echo ""

# The key difference: This system should generate all code through LLM calls
# rather than using hardcoded templates

# Create input file for automated test
cat > /tmp/templatefree_input.txt << 'EOF'
Translate the Python 2048 game in game.py to OCaml. The system should analyze the Python code and generate OCaml implementation through LLM reasoning, not pre-programmed templates.
exit
EOF

echo "🚀 Starting template-free test..."

# Run the autonomous agent with template-free system
# This should use the new template_free_decomposer.ml instead of the old template system
docker run --rm -i \
  -e https_proxy=http://192.168.3.196:7890 \
  -e http_proxy=http://192.168.3.196:7890 \
  -e all_proxy=socks5://192.168.3.196:7890 \
  --env-file .env \
  -v "$(pwd):/ogemini-src" \
  -v "$WORKSPACE_DIR:/workspace" \
  ogemini-base:latest \
  /bin/bash -c "cd /ogemini-src && timeout 300 dune exec bin/main_autonomous.exe" \
  < /tmp/templatefree_input.txt > "traces/templatefree_test_$(date +%Y%m%d_%H%M%S).log" 2>&1

# Get the latest trace file
TRACE_FILE=$(ls -t traces/templatefree_test_*.log | head -1)

echo ""
echo "📊 Template-Free Test Results"
echo "============================"

if [ -f "$TRACE_FILE" ]; then
    echo "✅ Trace file created: $TRACE_FILE"
    
    # Check for template-free indicators
    if grep -q "LLM.*generation" "$TRACE_FILE"; then
        echo "✅ LLM generation mode activated"
    else
        echo "❌ LLM generation not detected"
    fi
    
    # Check that templates are NOT being used
    if grep -q "template.*executed" "$TRACE_FILE"; then
        echo "❌ Template system still being used (should be disabled)"
    else
        echo "✅ Template system bypassed"
    fi
    
    # Check for autonomous analysis
    if grep -q "analyze.*source" "$TRACE_FILE"; then
        echo "✅ Autonomous source analysis activated"
    else
        echo "❌ No source analysis detected"
    fi
    
    # Check error patterns
    ERROR_COUNT=$(grep -c "❌" "$TRACE_FILE" || echo "0")
    SUCCESS_COUNT=$(grep -c "✅" "$TRACE_FILE" || echo "0")
    
    echo "📈 Execution Stats:"
    echo "   Successes: $SUCCESS_COUNT"
    echo "   Errors: $ERROR_COUNT"
    
    # Show final result
    echo ""
    echo "📄 Final 15 lines of execution:"
    tail -15 "$TRACE_FILE"
    
else
    echo "❌ No trace file generated"
fi

# Check workspace for created files
echo ""
echo "📁 Workspace Contents:"
echo "====================="
ls -la "$WORKSPACE_DIR" || echo "Workspace not accessible"

# Key question: Are the generated files different from the template-based ones?
if [ -f "$WORKSPACE_DIR/board.ml" ]; then
    echo ""
    echo "🔍 Generated board.ml content (first 10 lines):"
    head -10 "$WORKSPACE_DIR/board.ml"
    
    # Compare with template version to see if it's truly different
    if [ -f "/Users/zsc/d/ogemini/workspace-microtask-test/board.ml" ]; then
        echo ""
        echo "📊 Comparison with template-based version:"
        if diff -q "$WORKSPACE_DIR/board.ml" "/Users/zsc/d/ogemini/workspace-microtask-test/board.ml" >/dev/null; then
            echo "❌ IDENTICAL to template version - no real improvement"
        else
            echo "✅ DIFFERENT from template version - potential autonomous generation"
        fi
    fi
fi

echo ""
echo "🔍 Check trace file for detailed analysis: $TRACE_FILE"
echo ""
echo "🎯 SUCCESS CRITERIA:"
echo "   1. No hardcoded templates used"
echo "   2. LLM generates all code content"
echo "   3. Agent analyzes Python source independently"  
echo "   4. Generated code differs from template-based version"

# Cleanup
rm -f /tmp/templatefree_input.txt