# PyTorch 2.7.0 + CUDA 12.8 + cuDNN9 (devel for CUDA compilation)
# RTX 5090 (Blackwell sm_120) officially supported
FROM pytorch/pytorch:2.7.0-cuda12.8-cudnn9-devel

# Environment Variables
ENV CUDA_HOME=/usr/local/cuda
ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git ffmpeg ninja-build aria2 \
    libgl1 libglib2.0-0 libsm6 libxrender1 libxext6 curl \
    build-essential wget \
    && rm -rf /var/lib/apt/lists/*

# Verify PyTorch CUDA version (pre-installed in base image)
RUN python -c "import torch; print(f'PyTorch: {torch.__version__}'); print(f'CUDA version: {torch.version.cuda}')"

# Clone ComfyUI
RUN git clone https://github.com/comfyanonymous/ComfyUI.git /ComfyUI
WORKDIR /ComfyUI
RUN pip install --no-cache-dir -r requirements.txt

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
            pip install --no-cache-dir -r "$dir/requirements.txt" || true; \
        fi \
    done

# Install additional Python packages
RUN pip install --no-cache-dir runpod websocket-client deepdiff jsondiff PyWavelets ffmpeg-python triton

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
