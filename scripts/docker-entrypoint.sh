#!/bin/bash
# Docker entrypoint script for OGemini

# Ensure opam environment is set up
eval $(opam env)

# Source .env file if it exists
if [ -f /workspace/.env ]; then
    source /workspace/.env
fi

# Execute the command passed to docker run
exec "$@"