#!/bin/bash
set -e

echo "--- Setting up models ---"

# Create model directories
mkdir -p /workspace/models/{diffusion_models,text_encoders,vae,loras}

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

# HuggingFace: All other models
download_from_hf "https://huggingface.co/hyejeonge/dasiwa_wan2.2_v9/resolve/main/DasiwaWAN22I2V14BLightspeed_synthseductionLowV9.safetensors" \
    "/runpod_volume/models/diffusion_models/DasiwaWAN22I2V14BLightspeed_synthseductionLowV9.safetensors" \
    "Dasiwa_v9" &

download_from_hf "https://huggingface.co/landon2022/smooth_mix_v2/resolve/main/smoothMixWan2214BI2V_i2vV20High.safetensors" \
    "/runpod_volume/models/diffusion_models/smoothMix_v2_WAN2.2_I2V_14B_High_fp8.safetensors" \
    "smoothMix_v2" &

download_from_hf "https://huggingface.co/NSFW-API/NSFW-Wan-UMT5-XXL/resolve/main/nsfw_wan_umt5-xxl_fp8_scaled.safetensors" \
    "/runpod_volume/models/text_encoders/NSFW-Wan-UMT5-XXL_fp8_scaled.safetensors" \
    "NSFW-Wan-UMT5-XXL" &

download_from_hf "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/vae/wan_2.1_vae.safetensors" \
    "/runpod_volume/models/vae/wan2.1_vae.safetensors" \
    "wan2.1_vae" &

download_from_hf "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Lightx2v/lightx2v_I2V_14B_480p_cfg_step_distill_rank128_bf16.safetensors" \
    "/runpod_volume/models/loras/WAN2.2_lightx2v_I2V_14B_480p_rank128_bf16.safetensors" \
    "lightx2v_LoRA" &

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
