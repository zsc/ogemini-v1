#!/bin/bash

# Create a clean workspace
rm -rf workspace-phase84-test
mkdir -p workspace-phase84-test

# Create a Python file that will generate OCaml code needing 'rec'
cat > workspace-phase84-test/fibonacci.py << 'EOF'
def fibonacci(n):
    """Calculate fibonacci number recursively"""
    if n <= 0:
        return 0
    elif n == 1:
        return 1
    else:
        return fibonacci(n - 1) + fibonacci(n - 2)

def main():
    for i in range(10):
        print(f"fib({i}) = {fibonacci(i)}")

if __name__ == "__main__":
    main()
EOF

# Run the translation
echo "=== Running Phase 8.4 Test - Improved Context Passing ==="
(
    echo "Translate /workspace/fibonacci.py to OCaml"
    sleep 2
    echo "exit"
) | docker run --rm -i \
  -v "$(pwd):/ogemini-src" \
  -v "$(pwd)/workspace-phase84-test:/workspace" \
  --env-file .env \
  -e https_proxy=http://192.168.3.196:7890 \
  -e http_proxy=http://192.168.3.196:7890 \
  -e all_proxy=socks5://192.168.3.196:7890 \
  ogemini-base:latest \
  bash -c "cd /ogemini-src && dune exec bin/main_autonomous.exe 2>&1" | tee traces/phase84_test_$(date +%Y%m%d_%H%M%S).log

# Check results
echo ""
echo "=== Files created ==="
ls -la workspace-phase84-test/

echo ""
echo "=== Check for fix files ==="
find workspace-phase84-test -name "fixed_*.ml" -exec echo "File: {}" \; -exec head -20 {} \; -exec echo "" \;

echo ""
echo "=== Check if build succeeded ==="
if [ -d "workspace-phase84-test/_build" ]; then
    echo "Build directory exists - checking for executable"
    find workspace-phase84-test/_build -name "*.exe" -o -name "*.bc"
else
    echo "No build directory found"
fi