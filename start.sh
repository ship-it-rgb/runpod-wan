#!/bin/bash
set -e

echo "--- Setting up models ---"

mkdir -p /runpod-volume/models/{diffusion_models,text_encoders,vae,loras,clip_vision}

CACHE_DIR="/runpod-volume/huggingface-cache/hub"

find_cached_model() {
    local hf_repo=$1
    local filename=$2
    local cache_name="${hf_repo//\//-}"
    local snapshots_dir="$CACHE_DIR/models--$cache_name/snapshots"
    
    if [ -d "$snapshots_dir" ]; then
        local snapshot=$(ls -1 "$snapshots_dir" 2>/dev/null | head -1)
        if [ -n "$snapshot" ]; then
            local model_path="$snapshots_dir/$snapshot/$filename"
            if [ -f "$model_path" ]; then
                echo "$model_path"
                return 0
            fi
        fi
    fi
    return 1
}

link_or_download() {
    local hf_repo=$1
    local hf_filename=$2
    local dest=$3
    local name=$4
    local url=$5
    
    if [ -f "$dest" ] || [ -L "$dest" ]; then
        echo "✓ $name already exists"
        return 0
    fi
    
    local cached_path=$(find_cached_model "$hf_repo" "$hf_filename")
    if [ -n "$cached_path" ]; then
        echo "✓ $name found in RunPod cache, creating symlink..."
        ln -sf "$cached_path" "$dest"
        return 0
    fi
    
    echo "Downloading $name from HuggingFace..."
    if [ -n "$HF_TOKEN" ]; then
        aria2c -x 16 -s 16 -k 1M -o "$(basename "$dest")" -d "$(dirname "$dest")" --header "Authorization: Bearer $HF_TOKEN" "$url" --quiet
    else
        aria2c -x 16 -s 16 -k 1M -o "$(basename "$dest")" -d "$(dirname "$dest")" "$url" --quiet
    fi
    echo "✓ $name downloaded"
}

download_from_hf() {
    local url=$1
    local dest=$2
    local name=$3
    
    if [ -f "$dest" ]; then
        echo "✓ $name already exists"
        return 0
    fi
    
    echo "Downloading $name from HuggingFace..."
    if [ -n "$HF_TOKEN" ]; then
        aria2c -x 16 -s 16 -k 1M -o "$(basename "$dest")" -d "$(dirname "$dest")" --header "Authorization: Bearer $HF_TOKEN" "$url" --quiet
    else
        aria2c -x 16 -s 16 -k 1M -o "$(basename "$dest")" -d "$(dirname "$dest")" "$url" --quiet
    fi
    echo "✓ $name downloaded"
}

echo "--- Setting up models ---"

link_or_download "landon2022/smooth_mix_v2" \
    "smoothMixWan2214BI2V_i2vV20High.safetensors" \
    "/runpod-volume/models/diffusion_models/smoothMix_v2_WAN2.2_I2V_14B_High_fp8.safetensors" \
    "smoothMix_v2" \
    "https://huggingface.co/landon2022/smooth_mix_v2/resolve/main/smoothMixWan2214BI2V_i2vV20High.safetensors" &

download_from_hf "https://huggingface.co/hyejeonge/dasiwa_wan2.2_v9/resolve/main/DasiwaWAN22I2V14BLightspeed_synthseductionLowV9.safetensors" \
    "/runpod-volume/models/diffusion_models/DaSiWa_v9_WAN2.2_I2V_14B_Low_fp8.safetensors" \
    "DaSiWa_v9" &

download_from_hf "https://huggingface.co/NSFW-API/NSFW-Wan-UMT5-XXL/resolve/main/nsfw_wan_umt5-xxl_fp8_scaled.safetensors" \
    "/runpod-volume/models/text_encoders/NSFW-Wan-UMT5-XXL_fp8_scaled.safetensors" \
    "NSFW-Wan-UMT5-XXL" &

download_from_hf "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/vae/wan_2.1_vae.safetensors" \
    "/runpod-volume/models/vae/wan2.1_vae.safetensors" \
    "wan2.1_vae" &

download_from_hf "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Lightx2v/lightx2v_I2V_14B_480p_cfg_step_distill_rank128_bf16.safetensors" \
    "/runpod-volume/models/loras/WAN2.2_lightx2v_I2V_14B_480p_rank128_bf16.safetensors" \
    "lightx2v_LoRA" &

RIFE_VOLUME="/runpod-volume/models/rife/rife47.pth"
RIFE_DEST="/ComfyUI/custom_nodes/ComfyUI-Frame-Interpolation/ckpts/rife/rife47.pth"
mkdir -p "$(dirname "$RIFE_VOLUME")"
mkdir -p "$(dirname "$RIFE_DEST")"

if [ -f "$RIFE_VOLUME" ]; then
    echo "✓ RIFE 4.7 found in network volume, linking..."
    ln -sf "$RIFE_VOLUME" "$RIFE_DEST"
else
    echo "Downloading RIFE 4.7 model..."
    wget -q -O "$RIFE_VOLUME" "https://github.com/styler00dollar/VSGAN-tensorrt-docker/releases/download/models/rife47.pth"
    ln -sf "$RIFE_VOLUME" "$RIFE_DEST"
    echo "✓ RIFE 4.7 downloaded to volume and linked"
fi &

wait
echo "--- All models ready ---"

echo "--- Starting ComfyUI server ---"
python3 -u /ComfyUI/main.py --listen 0.0.0.0 --port 8188 --fast fp16_accumulation &

echo "--- Waiting for ComfyUI to be ready ---"
COMFY_URL="http://127.0.0.1:8188/system_stats"
MAX_WAIT=300
WAITED=0
while [ $WAITED -lt $MAX_WAIT ]; do
    if curl -s --max-time 5 "$COMFY_URL" > /dev/null 2>&1; then
        echo "✓ ComfyUI is ready (waited ${WAITED}s)"
        break
    fi
    sleep 2
    WAITED=$((WAITED + 2))
    if [ $((WAITED % 10)) -eq 0 ]; then
        echo "Still waiting for ComfyUI... (${WAITED}s)"
    fi
done

if [ $WAITED -ge $MAX_WAIT ]; then
    echo "ERROR: ComfyUI failed to start within ${MAX_WAIT}s"
    exit 1
fi

echo "--- Starting RunPod handler ---"
python -u /rp_handler.py
