#!/bin/bash
# ─────────────────────────────────────────────
# This script starts the API and file server in
# the Docker container (castilsec-app)
# ─────────────────────────────────────────────

set -e

# Start the API in the background
deno run --allow-net --allow-read apps/api/index.ts &

# Start the file server in the foreground
exec deno run --allow-net --allow-read file-server.ts
