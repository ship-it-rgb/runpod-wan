# NVIDIA CUDA 12.8.0 Base Image (devel for compilation support)
FROM nvidia/cuda:12.8.0-cudnn-devel-ubuntu22.04

# Environment Variables - RTX 5090 is sm_120 (Blackwell architecture)
ENV TORCH_CUDA_ARCH_LIST="8.0;8.6;8.9;9.0;12.0"
ENV CUDA_HOME=/usr/local/cuda
ENV PIP_BREAK_SYSTEM_PACKAGES=1
ENV DEBIAN_FRONTEND=noninteractive
ENV FORCE_CUDA=1

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git python3-pip python3-dev ffmpeg ninja-build aria2 \
    libgl1 libglib2.0-0 libsm6 libxrender1 libxext6 curl \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Install rclone
RUN curl -O https://downloads.rclone.org/rclone-current-linux-amd64.deb \
    && dpkg -i rclone-current-linux-amd64.deb \
    && rm rclone-current-linux-amd64.deb

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

# Install SageAttention (no-build-isolation) and other packages
RUN pip install sageattention --no-build-isolation
RUN pip install runpod websocket-client deepdiff jsondiff PyWavelets ffmpeg-python

# Copy files
COPY extra_model_paths.yaml /ComfyUI/
COPY start.sh /start.sh
COPY rp_handler.py /rp_handler.py
COPY workflows/ /ComfyUI/workflows/

# Set permissions
RUN chmod +x /start.sh

# Entrypoint
ENTRYPOINT ["/start.sh"]
