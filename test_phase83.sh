#!/bin/bash

# Create a clean workspace
rm -rf workspace-phase83-test
mkdir -p workspace-phase83-test

# Create factorial.py
cat > workspace-phase83-test/factorial.py << 'EOF'
def factorial(n):
    if n < 0:
        return None
    elif n == 0:
        return 1
    else:
        return n * factorial(n - 1)

if __name__ == "__main__":
    for i in range(10):
        print(f"factorial({i}) = {factorial(i)}")
EOF

# Run the translation
(
    echo "Translate /workspace/factorial.py to OCaml"
    sleep 2
    echo "exit"
) | docker run --rm -i \
  -v "$(pwd):/ogemini-src" \
  -v "$(pwd)/workspace-phase83-test:/workspace" \
  --env-file .env \
  -e https_proxy=http://192.168.3.196:7890 \
  -e http_proxy=http://192.168.3.196:7890 \
  -e all_proxy=socks5://192.168.3.196:7890 \
  ogemini-base:latest \
  bash -c "cd /ogemini-src && dune exec bin/main_autonomous.exe 2>&1" | tee traces/phase83_test_$(date +%Y%m%d_%H%M%S).log

# Check results
echo ""
echo "=== Files created ==="
ls -la workspace-phase83-test/

echo ""
echo "=== OCaml files content ==="
find workspace-phase83-test -name "*.ml" -exec echo "File: {}" \; -exec cat {} \; -exec echo "" \;