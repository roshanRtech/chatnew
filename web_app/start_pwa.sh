#!/usr/bin/env bash
PORT=${1:-8080}
echo "🚀 Starting Mighty Chat PWA on http://localhost:$PORT ..."
python3 -m http.server "$PORT" -d "$(dirname "$0")"
