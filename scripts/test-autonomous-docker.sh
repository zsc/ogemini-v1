#!/bin/bash

echo "🤖 Testing OGemini Autonomous Agent in Docker"
echo "============================================="

# Build the base image if needed
if ! docker images | grep -q "ogemini-base"; then
  echo "🔨 Building base Docker image..."
  docker build -t ogemini-base:latest .
fi

# Test 1: Simple autonomous task
echo -e "\n📋 Test 1: Simple file exploration task"
echo "Input: 'Help me explore the project structure and understand what files are here'"
echo ""

echo 'Help me explore the project structure and understand what files are here' | \
docker run --rm -i \
  -v "$(pwd):/ogemini-src" \
  -v "$(pwd)/workspace:/workspace" \
  -v "$(pwd)/.env:/workspace/.env:ro" \
  -w /workspace \
  --env-file .env \
  -e https_proxy=http://192.168.3.196:7890 \
  -e http_proxy=http://192.168.3.196:7890 \
  -e all_proxy=socks5://192.168.3.196:7890 \
  ogemini-base:latest \
  bash -c "cd /ogemini-src && eval \$(opam env) && dune build && cd /workspace && /ogemini-src/_build/default/bin/main_autonomous.exe"

echo -e "\n================================================"
echo "🎉 Autonomous test completed!"
echo ""
echo "The autonomous agent should have:"
echo "✅ Detected the complex task request"
echo "✅ Entered autonomous planning mode"
echo "✅ Generated an execution plan"
echo "✅ Executed multiple tool calls independently"
echo "✅ Provided comprehensive results"