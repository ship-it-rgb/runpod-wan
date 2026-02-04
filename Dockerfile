# ⚠️ WARNING: DO NOT CHANGE BASE IMAGE - RTX 5090 REQUIRES CUDA 12.8+
# See .sisyphus/notepads/runpod-wan-serverless/CRITICAL_REQUIREMENTS.md
# NVIDIA CUDA 12.8.0 Base Image (devel for compilation support)
FROM nvidia/cuda:12.8.0-cudnn-devel-ubuntu22.04

# Environment Variables - RTX 5090 is sm_120 (Blackwell architecture)
# SageAttention checks for 12.0/12.1 in TORCH_CUDA_ARCH_LIST to enable sm120a build
ENV TORCH_CUDA_ARCH_LIST="8.0;8.6;8.9;9.0;12.0"
ENV CUDA_HOME=/usr/local/cuda
ENV PIP_BREAK_SYSTEM_PACKAGES=1
ENV DEBIAN_FRONTEND=noninteractive
ENV FORCE_CUDA=1

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git python3-pip python3-dev ffmpeg ninja-build aria2 \
    libgl1 libglib2.0-0 libsm6 libxrender1 libxext6 curl \
    build-essential wget \
    && rm -rf /var/lib/apt/lists/*

# Upgrade pip first
RUN pip install --upgrade pip setuptools wheel

# Install PyTorch 2.7.0 stable with CUDA 12.8 (official RTX 5090/Blackwell sm_120 support)
RUN pip install torch==2.7.0 torchvision torchaudio --index-url https://download.pytorch.org/whl/cu128 \
    && pip cache purge

# Verify PyTorch CUDA version
RUN python3 -c "import torch; print(f'PyTorch: {torch.__version__}'); print(f'CUDA version: {torch.version.cuda}')"

# Clone ComfyUI
RUN git clone https://github.com/comfyanonymous/ComfyUI.git /ComfyUI
WORKDIR /ComfyUI
RUN pip install -r requirements.txt

# Install Custom Nodes
WORKDIR /ComfyUI/custom_nodes
RUN git clone https://github.com/kijai/ComfyUI-KJNodes.git \
    && git clone https://github.com/rgthree/rgthree-comfy.git \
    && git clone https://github.com/cubiq/ComfyUI_essentials.git \
    && git clone https://github.com/yolain/ComfyUI-Easy-Use.git \
    && git clone https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git \
    && git clone https://github.com/crystian/ComfyUI-Crystools.git \
    && git clone https://github.com/ClownsharkBatwing/RES4LYF.git \
    && git clone https://github.com/pythongosssss/ComfyUI-Custom-Scripts.git \
    && git clone https://github.com/Fannovel16/ComfyUI-Frame-Interpolation.git

# Install Custom Node Requirements
RUN for dir in */; do \
        if [ -f "$dir/requirements.txt" ]; then \
            pip install -r "$dir/requirements.txt" || true; \
        fi \
    done

# Install SageAttention 2.2.0 with Blackwell (RTX 5090) support
RUN pip install "git+https://github.com/thu-ml/SageAttention.git@main" --no-build-isolation
RUN pip install runpod websocket-client deepdiff jsondiff PyWavelets ffmpeg-python

# Copy files
COPY extra_model_paths.yaml /ComfyUI/
COPY start.sh /start.sh
COPY rp_handler.py /rp_handler.py
COPY workflows/ /ComfyUI/workflows/

# 1. 모델을 저장할 디렉토리 생성
RUN mkdir -p /ComfyUI/custom_nodes/ComfyUI-Frame-Interpolation/models/vfi/rife

# 2. RIFE 4.7 모델 다운로드 (가장 안정적인 허깅페이스 미러 사용)
RUN wget -O /ComfyUI/custom_nodes/ComfyUI-Frame-Interpolation/models/vfi/rife/rife47.pth \
    https://huggingface.co/jasonot/mycomfyui/resolve/main/rife47.pth

# Set permissions
RUN chmod +x /start.sh

# Entrypoint
ENTRYPOINT ["/start.sh"]
