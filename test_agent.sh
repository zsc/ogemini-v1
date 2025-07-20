#\!/bin/bash

# Script to test OGemini agent with automatic confirmations
cd /Users/zsc/Downloads/ogemini
source .env

# Create input that includes the task and confirmations
{
    echo "set up a toy ml and dune related files and see if ocaml toolchain works"
    sleep 2
    echo "y"  # Confirm first tool call
    sleep 1
    echo "y"  # Confirm second tool call
    sleep 1
    echo "y"  # Confirm third tool call
    sleep 1
    echo "y"  # Confirm fourth tool call
    sleep 1
    echo "y"  # Confirm fifth tool call
    sleep 1
    echo "exit"
} | dune exec ./bin/main.exe
EOF < /dev/null