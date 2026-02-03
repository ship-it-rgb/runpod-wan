#!/bin/bash
set -e

# Handle both /workspace and /runpod-volume for model paths
if [ -d "/runpod-volume" ]; then
    echo "Configuring for Serverless mode with /runpod-volume"
    MODEL_BASE="/runpod-volume/models"
    mkdir -p $MODEL_BASE/{diffusion_models,text_encoders,vae,loras,clip_vision}
elif [ -d "/workspace" ]; then
    echo "Configuring for Pod mode with /workspace"
    MODEL_BASE="/workspace/models"
    mkdir -p $MODEL_BASE/{diffusion_models,text_encoders,vae,loras,clip_vision}
else
    echo "Neither /runpod-volume nor /workspace found. Defaulting to /models"
    MODEL_BASE="/models"
    mkdir -p $MODEL_BASE/{diffusion_models,text_encoders,vae,loras,clip_vision}
fi

# Download models from R2 if environment variables are set
if [ -n "$R2_ACCESS_KEY" ] && [ -n "$R2_SECRET_KEY" ]; then
    echo "Configuring R2 access..."
    mkdir -p ~/.config/rclone
    cat > ~/.config/rclone/rclone.conf << EOF
[wan-models]
type = s3
provider = Cloudflare
access_key_id = $R2_ACCESS_KEY
secret_access_key = $R2_SECRET_KEY
endpoint = $R2_ENDPOINT
EOF
    
    echo "Downloading models from R2 bucket: $R2_BUCKET..."
    # Download models if they don't exist
    rclone copy wan-models:$R2_BUCKET/diffusion_models/ $MODEL_BASE/diffusion_models/ --include "*.safetensors" --ignore-existing
    rclone copy wan-models:$R2_BUCKET/text_encoders/ $MODEL_BASE/text_encoders/ --include "*.safetensors" --ignore-existing
    rclone copy wan-models:$R2_BUCKET/vae/ $MODEL_BASE/vae/ --include "*.safetensors" --ignore-existing
    rclone copy wan-models:$R2_BUCKET/loras/ $MODEL_BASE/loras/ --include "*.safetensors" --ignore-existing
    rclone copy wan-models:$R2_BUCKET/clip_vision/ $MODEL_BASE/clip_vision/ --include "*.safetensors" --ignore-existing
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
