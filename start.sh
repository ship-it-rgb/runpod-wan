#!/bin/bash
set -e

echo "--- Starting ComfyUI server ---"
python -u /comfyui/main.py --listen 0.0.0.0 --port 8188 --use-sage-attention --fast &

# Wait for server to be ready
sleep 10

if [ "$RUNPOD_SERVERLESS" = "true" ]; then
    echo "--- Serverless mode: Starting handler ---"
    python -u /rp_handler.py
else
    echo "--- Pod mode: Keeping container alive ---"
    wait
fi
