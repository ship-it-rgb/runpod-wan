#!/bin/bash
set -e

# Handle both /workspace and /runpod-volume for model paths
if [ -d "/runpod-volume" ]; then
    echo "Configuring for Serverless mode with /runpod-volume"
    mkdir -p /runpod-volume/models/{diffusion_models,text_encoders,vae,loras,clip_vision}
fi

if [ -d "/workspace" ]; then
    echo "Configuring for Pod mode with /workspace"
    mkdir -p /workspace/models/{diffusion_models,text_encoders,vae,loras,clip_vision}
fi

# Start ComfyUI in background (port 8188)
# Flags: --use-sage-attention --fast
echo "Starting ComfyUI server..."
python3 /comfyui/main.py --listen 0.0.0.0 --port 8188 --use-sage-attention --fast &

# Wait for ComfyUI to be ready
echo "Waiting for ComfyUI to be ready..."
sleep 10

# Check RUNPOD_SERVERLESS mode
if [ "$RUNPOD_SERVERLESS" = "true" ]; then
    echo "RUNPOD_SERVERLESS is true, starting rp_handler.py"
    python3 /rp_handler.py
else
    # Pod mode - keep running (keep web UI alive)
    echo "Pod mode detected, waiting indefinitely..."
    wait
fi
