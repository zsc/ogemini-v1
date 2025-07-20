#!/bin/bash
# Debug script to see where OGemini agent gets stuck

set -e
cd /Users/zsc/Downloads/ogemini

echo "🔍 Debug Agent Test"
echo "=================="

# Clean and prepare
rm -rf workspace/debug_test
mkdir -p workspace/debug_test

echo "Step 1: Testing container startup..."
docker run --rm \
  -v "$(pwd)/workspace/debug_test:/workspace" \
  -e GEMINI_API_KEY="${GEMINI_API_KEY}" \
  -w /workspace \
  ogemini-secure:latest \
  echo "Container works!"

echo "Step 2: Testing OGemini binary..."
docker run --rm \
  -v "$(pwd)/workspace/debug_test:/workspace" \
  -e GEMINI_API_KEY="${GEMINI_API_KEY}" \
  -w /workspace \
  ogemini-secure:latest \
  /ogemini-src/_build/default/bin/main.exe --help 2>&1 || echo "No help flag, trying version check..."

echo "Step 3: Testing OGemini startup (no input)..."
timeout 10 docker run --rm \
  -v "$(pwd)/workspace/debug_test:/workspace" \
  -e GEMINI_API_KEY="${GEMINI_API_KEY}" \
  -w /workspace \
  ogemini-secure:latest \
  /ogemini-src/_build/default/bin/main.exe < /dev/null || echo "Startup test completed"

echo "Step 4: Testing with simple input..."
echo "exit" | timeout 15 docker run --rm -i \
  -v "$(pwd)/workspace/debug_test:/workspace" \
  -e GEMINI_API_KEY="${GEMINI_API_KEY}" \
  -w /workspace \
  ogemini-secure:latest \
  /ogemini-src/_build/default/bin/main.exe || echo "Simple input test completed"

echo "Step 5: Testing API connectivity..."
echo "hello" | timeout 20 docker run --rm -i \
  -v "$(pwd)/workspace/debug_test:/workspace" \
  -e GEMINI_API_KEY="${GEMINI_API_KEY}" \
  -w /workspace \
  ogemini-secure:latest \
  /ogemini-src/_build/default/bin/main.exe 2>&1 | head -20 || echo "API test completed"

echo "Step 6: Check environment variables..."
docker run --rm \
  -v "$(pwd)/workspace/debug_test:/workspace" \
  -e GEMINI_API_KEY="${GEMINI_API_KEY}" \
  -w /workspace \
  ogemini-secure:latest \
  bash -c "echo API_KEY length: \${#GEMINI_API_KEY}; env | grep GEMINI || echo 'No GEMINI env vars'"

echo "Step 7: Test with .env file copy..."
cp .env workspace/debug_test/.env
echo "test file creation" | timeout 30 docker run --rm -i \
  -v "$(pwd)/workspace/debug_test:/workspace" \
  -w /workspace \
  ogemini-secure:latest \
  /ogemini-src/_build/default/bin/main.exe 2>&1 | head -30 || echo "Test with .env file completed"

# Cleanup
rm -rf workspace/debug_test