#!/bin/bash
set -e

echo "--- Checking and downloading models ---"

mkdir -p /workspace/models/diffusion_models
mkdir -p /workspace/models/text_encoders
mkdir -p /workspace/models/vae
mkdir -p /workspace/models/loras
mkdir -p /workspace/models/clip_vision

download_model() {
    local url=$1
    local dest=$2
    local name=$3
    if [ ! -f "$dest" ]; then
        echo "Downloading $name..."
        aria2c -x 16 -s 16 -k 1M -o "$(basename "$dest")" -d "$(dirname "$dest")" "$url"
        echo "Finished downloading $name."
    else
        echo "$name already exists, skipping."
    fi
}

download_model "https://huggingface.co/landon2022/smooth_mix_v2/resolve/main/smoothMixWan2214BI2V_i2vV20High.safetensors" "/workspace/models/diffusion_models/smoothMix_v2_WAN2.2_I2V_14B_High_fp8.safetensors" "smoothMix_v2" &
download_model "https://huggingface.co/NSFW-API/NSFW-Wan-UMT5-XXL/resolve/main/nsfw_wan_umt5-xxl_fp8_scaled.safetensors" "/workspace/models/text_encoders/NSFW-Wan-UMT5-XXL_fp8_scaled.safetensors" "NSFW-Wan-UMT5-XXL" &
download_model "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/vae/wan_2.1_vae.safetensors" "/workspace/models/vae/wan2.1_vae.safetensors" "wan2.1_vae" &
download_model "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Lightx2v/lightx2v_I2V_14B_480p_cfg_step_distill_rank128_bf16.safetensors" "/workspace/models/loras/WAN2.2_lightx2v_I2V_14B_480p_rank128_bf16.safetensors" "lightx2v LoRA" &
download_model "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/clip_vision/clip_vision_h.safetensors" "/workspace/models/clip_vision/clip_vision_h.safetensors" "clip_vision_h" &
download_model "https://civitai.com/api/download/models/2555652?type=Model&format=SafeTensor&size=full&fp=fp8&token=fcdbdc3523412beb1d5d3ec3d80c617d" "/workspace/models/diffusion_models/DaSiWa_v9_WAN2.2_I2V_14B_Low_fp8.safetensors" "DaSiWa" &

wait

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
