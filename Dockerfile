# NVIDIA CUDA 12.8 Devel Base (Downgraded from 12.9 to fix Error 804 on RunPod)
FROM nvidia/cuda:12.8.0-devel-ubuntu22.04

# Environment Variables
ENV CUDA_HOME=/usr/local/cuda
ENV DEBIAN_FRONTEND=noninteractive
# Force Blackwell architecture build
ENV TORCH_CUDA_ARCH_LIST="12.0"
# Limit parallel build jobs to prevent OOM on GitHub Actions runners
ENV MAX_JOBS=2

# Install system dependencies & Python 3.13 via PPA
RUN apt-get update && apt-get install -y software-properties-common && \
    add-apt-repository ppa:deadsnakes/ppa && \
    apt-get update && apt-get install -y \
    git python3.13 python3.13-dev python3.13-venv \
    ffmpeg ninja-build aria2 \
    libgl1 libglib2.0-0 libsm6 libxrender1 libxext6 curl \
    build-essential wget \
    && rm -rf /var/lib/apt/lists/*

# Install pip for Python 3.13
RUN curl -sS https://bootstrap.pypa.io/get-pip.py | python3.13

# Link python3/python to python3.13
RUN ln -sf /usr/bin/python3.13 /usr/bin/python3 && \
    ln -sf /usr/bin/python3.13 /usr/bin/python

# Upgrade pip
RUN python3.13 -m pip install --upgrade pip

# Install PyTorch 2.8.0 with CUDA 12.8 support (cu128)
# Downgraded from cu129 to match RunPod host drivers and fix Error 804
# Verified torch-2.8.0+cu128 exists
RUN python3.13 -m pip install torch==2.8.0 torchvision torchaudio --index-url https://download.pytorch.org/whl/cu128

# Verify PyTorch CUDA version
RUN python3.13 -c "import torch; print(f'PyTorch: {torch.__version__}'); print(f'CUDA version: {torch.version.cuda}')"

# Clone ComfyUI
RUN git clone https://github.com/comfyanonymous/ComfyUI.git /ComfyUI
WORKDIR /ComfyUI
RUN python3.13 -m pip install --no-cache-dir -r requirements.txt

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
            python3.13 -m pip install --no-cache-dir -r "$dir/requirements.txt" || true; \
        fi \
    done

# Install additional Python packages
RUN python3.13 -m pip install --no-cache-dir runpod websocket-client deepdiff jsondiff PyWavelets ffmpeg-python triton comfy-kitchen

# Install SageAttention from source (Main branch)
# This includes Blackwell (sm_120) support
RUN python3.13 -m pip install -v "git+https://github.com/thu-ml/SageAttention.git@main" --no-build-isolation

# Copy files
COPY extra_model_paths.yaml /ComfyUI/
COPY start.sh /start.sh
COPY rp_handler.py /rp_handler.py
COPY workflows/ /ComfyUI/workflows/

RUN mkdir -p /ComfyUI/custom_nodes/ComfyUI-Frame-Interpolation/ckpts/rife

# Set permissions
RUN chmod +x /start.sh

# Entrypoint
ENTRYPOINT ["/start.sh"]
