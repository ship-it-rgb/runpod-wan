#!/bin/bash
set -e

echo "--- Setting up models ---"

# Create model directories
mkdir -p /workspace/models/{diffusion_models,text_encoders,vae,loras,clip_vision}

# === R2 CONFIGURATION (for CivitAI models only) ===
if [ -n "$R2_ACCESS_KEY" ] && [ -n "$R2_SECRET_KEY" ] && [ -n "$R2_ENDPOINT" ]; then
    echo "Configuring rclone for R2..."
    mkdir -p ~/.config/rclone
    cat > ~/.config/rclone/rclone.conf << EOF
[r2]
type = s3
provider = Other
access_key_id = ${R2_ACCESS_KEY}
secret_access_key = ${R2_SECRET_KEY}
endpoint = ${R2_ENDPOINT}
acl = private
no_check_bucket = true
EOF
    R2_CONFIGURED=true
else
    echo "WARNING: R2 credentials not set. DaSiWa model will not be available."
    R2_CONFIGURED=false
fi

R2_BUCKET="${R2_BUCKET:-wan-models}"

# === WORKAROUND: Copy rclone to avoid "Text file busy" error ===
# Docker overlay filesystem on RunPod can lock binaries - copy to /tmp first
if [ -f /usr/bin/rclone ]; then
    cp /usr/bin/rclone /tmp/rclone
    chmod +x /tmp/rclone
    RCLONE_BIN="/tmp/rclone"
else
    RCLONE_BIN="rclone"
fi

# === DOWNLOAD FUNCTIONS ===
download_from_r2() {
    local r2_path=$1
    local local_path=$2
    local name=$3
    
    if [ "$R2_CONFIGURED" = "true" ] && [ ! -f "$local_path" ]; then
        echo "Downloading $name from R2..."
        $RCLONE_BIN copy "r2:${R2_BUCKET}/${r2_path}" "$(dirname "$local_path")" \
            --transfers 4 --s3-chunk-size 16M --buffer-size 16M
        echo "✓ $name downloaded from R2"
    elif [ -f "$local_path" ]; then
        echo "✓ $name already exists"
    fi
}

download_from_hf() {
    local url=$1
    local dest=$2
    local name=$3
    
    if [ ! -f "$dest" ]; then
        echo "Downloading $name from HuggingFace..."
        aria2c -x 16 -s 16 -k 1M -o "$(basename "$dest")" -d "$(dirname "$dest")" "$url" --quiet
        echo "✓ $name downloaded"
    else
        echo "✓ $name already exists"
    fi
}

# === DOWNLOAD MODELS ===
echo "--- Downloading models in parallel ---"

# R2: DaSiWa (CivitAI model - not on HuggingFace)
download_from_r2 "diffusion_models/DaSiWa_v9_WAN2.2_I2V_14B_Low_fp8.safetensors" \
    "/workspace/models/diffusion_models/DaSiWa_v9_WAN2.2_I2V_14B_Low_fp8.safetensors" \
    "DaSiWa_v9" &

# HuggingFace: All other models
download_from_hf "https://huggingface.co/landon2022/smooth_mix_v2/resolve/main/smoothMixWan2214BI2V_i2vV20High.safetensors" \
    "/workspace/models/diffusion_models/smoothMix_v2_WAN2.2_I2V_14B_High_fp8.safetensors" \
    "smoothMix_v2" &

download_from_hf "https://huggingface.co/NSFW-API/NSFW-Wan-UMT5-XXL/resolve/main/nsfw_wan_umt5-xxl_fp8_scaled.safetensors" \
    "/workspace/models/text_encoders/NSFW-Wan-UMT5-XXL_fp8_scaled.safetensors" \
    "NSFW-Wan-UMT5-XXL" &

download_from_hf "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/vae/wan_2.1_vae.safetensors" \
    "/workspace/models/vae/wan2.1_vae.safetensors" \
    "wan2.1_vae" &

download_from_hf "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Lightx2v/lightx2v_I2V_14B_480p_cfg_step_distill_rank128_bf16.safetensors" \
    "/workspace/models/loras/WAN2.2_lightx2v_I2V_14B_480p_rank128_bf16.safetensors" \
    "lightx2v_LoRA" &

download_from_hf "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/clip_vision/clip_vision_h.safetensors" \
    "/workspace/models/clip_vision/clip_vision_h.safetensors" \
    "clip_vision_h" &

wait
echo "--- All models ready ---"

echo "--- Starting ComfyUI server ---"
python3 -u /ComfyUI/main.py --listen 0.0.0.0 --port 8188 --use-sage-attention --fast fp16_accumulation &

# Wait for server to be ready
sleep 10

if [ "$RUNPOD_SERVERLESS" = "true" ]; then
    echo "--- Serverless mode: Starting handler ---"
    python -u /rp_handler.py
else
    echo "--- Pod mode: Keeping container alive ---"
    wait
fi
