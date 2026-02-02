#!/bin/bash
set -e

echo "--- Configuring rclone for R2 ---"

# Check required environment variables
if [ -z "$R2_ACCESS_KEY" ] || [ -z "$R2_SECRET_KEY" ] || [ -z "$R2_ENDPOINT" ]; then
    echo "ERROR: R2_ACCESS_KEY, R2_SECRET_KEY, and R2_ENDPOINT must be set"
    exit 1
fi

R2_BUCKET="${R2_BUCKET:-wan-models}"

# Configure rclone
mkdir -p ~/.config/rclone
cat > ~/.config/rclone/rclone.conf << EOF
[r2]
type = s3
provider = Cloudflare
access_key_id = ${R2_ACCESS_KEY}
secret_access_key = ${R2_SECRET_KEY}
endpoint = ${R2_ENDPOINT}
acl = private
EOF

echo "--- Downloading models from R2 ---"

# Create model directories
mkdir -p /workspace/models/{diffusion_models,text_encoders,vae,loras,clip_vision}

# Function to download if not exists
download_if_missing() {
    local r2_path=$1
    local local_path=$2
    local name=$3
    
    if [ ! -f "$local_path" ]; then
        echo "Downloading $name..."
        rclone copy "r2:${R2_BUCKET}/${r2_path}" "$(dirname "$local_path")" \
            --transfers 16 \
            --s3-chunk-size 64M \
            --buffer-size 128M \
            --progress
        echo "✓ $name downloaded"
    else
        echo "✓ $name already exists"
    fi
}

# Download all models in parallel
download_if_missing "diffusion_models/smoothMix_v2_WAN2.2_I2V_14B_High_fp8.safetensors" "/workspace/models/diffusion_models/smoothMix_v2_WAN2.2_I2V_14B_High_fp8.safetensors" "smoothMix_v2" &
download_if_missing "diffusion_models/DaSiWa_v9_WAN2.2_I2V_14B_Low_fp8.safetensors" "/workspace/models/diffusion_models/DaSiWa_v9_WAN2.2_I2V_14B_Low_fp8.safetensors" "DaSiWa_v9" &
download_if_missing "text_encoders/NSFW-Wan-UMT5-XXL_fp8_scaled.safetensors" "/workspace/models/text_encoders/NSFW-Wan-UMT5-XXL_fp8_scaled.safetensors" "NSFW-Wan-UMT5-XXL" &
download_if_missing "vae/wan2.1_vae.safetensors" "/workspace/models/vae/wan2.1_vae.safetensors" "wan2.1_vae" &
download_if_missing "loras/WAN2.2_lightx2v_I2V_14B_480p_rank128_bf16.safetensors" "/workspace/models/loras/WAN2.2_lightx2v_I2V_14B_480p_rank128_bf16.safetensors" "lightx2v_LoRA" &
download_if_missing "clip_vision/clip_vision_h.safetensors" "/workspace/models/clip_vision/clip_vision_h.safetensors" "clip_vision_h" &

wait
echo "--- All models ready ---"

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
