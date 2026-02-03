# Use the specified RunPod ComfyUI base image
FROM runpod/worker-comfyui:5.6.0-base

# Environment variables
ENV PIP_BREAK_SYSTEM_PACKAGES=1
ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies for SageAttention and other builds
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    g++ \
    python3-dev \
    git \
    wget \
    aria2 \
    ffmpeg \
    rclone \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Set working directory to ComfyUI (base image uses /comfyui)
WORKDIR /comfyui

# Install SageAttention and other Python dependencies
# sageattention requires --no-build-isolation
RUN pip install --no-cache-dir sageattention --no-build-isolation && \
    pip install --no-cache-dir deepdiff jsondiff PyWavelets ffmpeg websocket-client

# Install custom nodes using comfy-cli
# Requirement: Install 10 custom nodes (including frame interpolation for RIFE VFI)
RUN comfy node install comfyui-kjnodes && \
    comfy node install rgthree-comfy && \
    comfy node install comfyui_essentials && \
    comfy node install comfyui-easy-use && \
    comfy node install comfyui-videohelpersuites && \
    comfy node install comfyui-crystools && \
    comfy node install res4lyf && \
    comfy node install comfyui-custom-scripts && \
    comfy node install comfyui-qwenvl && \
    comfy node install comfyui-frame-interpolation

# Remove ComfyUI-Manager if it exists (as requested)
RUN rm -rf /comfyui/custom_nodes/ComfyUI-Manager

# Copy extra_model_paths.yaml to /comfyui/
COPY extra_model_paths.yaml /comfyui/extra_model_paths.yaml

# Copy start.sh and set executable
COPY start.sh /start.sh
RUN chmod +x /start.sh

# Copy rp_handler.py and workflows
COPY rp_handler.py /rp_handler.py
COPY workflows/ /comfyui/workflows/

# Increase handler.py timeout using sed (Requirement: timeout=600 -> higher)
# Note: rp_handler.py is used as the handler
RUN sed -i 's/timeout=600/timeout=3600/g' /rp_handler.py

# Set the entrypoint
CMD ["/start.sh"]
