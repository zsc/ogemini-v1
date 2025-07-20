#!/bin/bash

echo "🤖 Starting OGemini Autonomous Agent in Docker"
echo "=============================================="
echo ""
echo "This runs the autonomous agent with full file permissions in a Docker container."
echo "The agent can autonomously plan and execute complex multi-step tasks."
echo ""
echo "Try commands like:"
echo "  - 'Create a simple calculator in OCaml'"
echo "  - 'Help me build a command-line todo app'"
echo "  - 'Analyze and improve the project structure'"
echo ""
echo "Type 'exit' or 'quit' to stop."
echo ""

# Build base image if needed
if ! docker images | grep -q "ogemini-base"; then
  echo "🔨 Building base Docker image..."
  docker build -t ogemini-base:latest .
fi

# Create a persistent workspace directory
WORKSPACE_DIR="$(pwd)/workspace-autonomous"
mkdir -p "$WORKSPACE_DIR"

echo "📁 Using workspace: $WORKSPACE_DIR"
echo ""

# Run the autonomous agent
docker run --rm -it \
  -v "$(pwd):/ogemini-src" \
  -v "$WORKSPACE_DIR:/workspace" \
  -v "$(pwd)/.env:/workspace/.env:ro" \
  -w /workspace \
  --env-file .env \
  -e https_proxy=http://192.168.3.196:7890 \
  -e http_proxy=http://192.168.3.196:7890 \
  -e all_proxy=socks5://192.168.3.196:7890 \
  ogemini-base:latest \
  bash -c "cd /ogemini-src && eval \$(opam env) && dune build && cd /workspace && /ogemini-src/_build/default/bin/main_autonomous.exe"

echo ""
echo "👋 Autonomous agent session ended."
echo "📁 Check $WORKSPACE_DIR for any files created during the session."