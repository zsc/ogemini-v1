#!/bin/bash

# Run autonomous agent with comprehensive trace logging
# Usage: ./scripts/run-autonomous-with-trace.sh "task description"

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
WORKSPACE_DIR="$PROJECT_ROOT/workspace"
TRACE_DIR="$PROJECT_ROOT/traces"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
TRACE_FILE="$TRACE_DIR/autonomous_trace_$TIMESTAMP.log"

# Create necessary directories
mkdir -p "$WORKSPACE_DIR"
mkdir -p "$TRACE_DIR"

# Get task from command line or use default
TASK="${1:-Create a simple hello world OCaml program}"

echo "🤖 Running Autonomous Agent with Trace Logging"
echo "=============================================="
echo "📅 Timestamp: $(date)"
echo "🎯 Task: $TASK"
echo "📁 Workspace: $WORKSPACE_DIR"
echo "📋 Trace file: $TRACE_FILE"
echo "=============================================="

# Initialize trace file
cat > "$TRACE_FILE" << EOF
OGemini Autonomous Agent Execution Trace
========================================
Start Time: $(date)
Task: $TASK
Workspace: $WORKSPACE_DIR
Agent Version: Phase 5.1.1
========================================

EOF

# Function to log and display
log_and_show() {
    echo "$1" | tee -a "$TRACE_FILE"
}

log_and_show "🐳 Building Docker image..."
cd "$PROJECT_ROOT"
docker build -t ogemini-base:latest . 2>&1 | tee -a "$TRACE_FILE"

log_and_show ""
log_and_show "🚀 Starting autonomous agent execution..."
log_and_show "Command: echo '$TASK' | docker run --rm -i ..."

# Run the autonomous agent with full trace
echo "$TASK" | docker run --rm -i \
  -v "$PROJECT_ROOT:/ogemini-src" \
  -v "$WORKSPACE_DIR:/workspace" \
  -v "$PROJECT_ROOT/.env:/workspace/.env:ro" \
  -w /workspace \
  --env-file "$PROJECT_ROOT/.env" \
  -e https_proxy=http://192.168.3.196:7890 \
  -e http_proxy=http://192.168.3.196:7890 \
  -e all_proxy=socks5://192.168.3.196:7890 \
  ogemini-base:latest \
  bash -c "cd /ogemini-src && eval \$(opam env) && dune build && timeout 120 dune exec ogemini-autonomous" \
  2>&1 | tee -a "$TRACE_FILE"

AGENT_EXIT_CODE=${PIPESTATUS[0]}

log_and_show ""
log_and_show "=========================================="
log_and_show "🏁 Execution completed"
log_and_show "Exit code: $AGENT_EXIT_CODE"
log_and_show "End time: $(date)"

# Check workspace results
log_and_show ""
log_and_show "📁 Workspace contents after execution:"
if [ -d "$WORKSPACE_DIR" ]; then
    find "$WORKSPACE_DIR" -type f -exec ls -la {} \; 2>/dev/null | tee -a "$TRACE_FILE" || log_and_show "No files found in workspace"
    
    log_and_show ""
    log_and_show "📄 Generated file contents:"
    find "$WORKSPACE_DIR" -name "*.ml" -o -name "*.mli" -o -name "dune*" | while read file; do
        if [ -f "$file" ]; then
            log_and_show "--- File: $file ---"
            cat "$file" 2>/dev/null | tee -a "$TRACE_FILE" || log_and_show "Could not read file"
            log_and_show "--- End of $file ---"
            log_and_show ""
        fi
    done
else
    log_and_show "Workspace directory not found"
fi

log_and_show "=========================================="
log_and_show "✅ Trace saved to: $TRACE_FILE"
log_and_show "📖 You can review the complete execution with:"
log_and_show "   cat $TRACE_FILE"
log_and_show "   less $TRACE_FILE"
log_and_show "   tail -f $TRACE_FILE"

# Copy trace to a standard location for easy access
cp "$TRACE_FILE" "$PROJECT_ROOT/latest_autonomous_trace.log"
log_and_show "📋 Latest trace also available at: $PROJECT_ROOT/latest_autonomous_trace.log"

exit $AGENT_EXIT_CODE