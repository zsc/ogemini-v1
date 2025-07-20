#!/bin/bash
# Quick test to verify agent can create files

set -e
cd /Users/zsc/Downloads/ogemini

echo "🧪 Quick Agent Test: File Creation"
echo "=================================="

# Clean and prepare
rm -rf workspace/test_dir
mkdir -p workspace/test_dir

# Simple task
echo "Create a file called hello.txt with 'Hello World'" | timeout 30 docker run --rm -i \
  -v "$(pwd)/workspace/test_dir:/workspace" \
  -e GEMINI_API_KEY="${GEMINI_API_KEY}" \
  -w /workspace \
  ogemini-secure:latest \
  /ogemini-src/_build/default/bin/main.exe || echo "Agent finished or timed out"

# Check result
echo
echo "Results:"
ls -la workspace/test_dir/
if [ -f workspace/test_dir/hello.txt ]; then
    echo "✅ SUCCESS: File created!"
    echo "Content:"
    cat workspace/test_dir/hello.txt
else
    echo "❌ FAIL: No file created"
fi

# Cleanup
rm -rf workspace/test_dir