# RTX 5090 (Blackwell) 호환 베이스 이미지 - CUDA 12.8.1
FROM runpod/worker-comfyui:5.6.0-base-cuda12.8.1

# 시스템 패키지 설치
RUN apt-get update && apt-get install -y \
    gcc g++ python3-dev curl aria2 \
    && curl -O https://downloads.rclone.org/rclone-current-linux-amd64.deb \
    && dpkg -i rclone-current-linux-amd64.deb \
    && rm rclone-current-linux-amd64.deb \
    && rm -rf /var/lib/apt/lists/*

# ComfyUI 최신 버전으로 업데이트 (comfy_quant 지원 필수)
RUN cd /comfyui && git pull origin master

# PyTorch 2.9.x + CUDA 13.0 (Blackwell 최적화)
RUN pip install --pre torch torchvision torchaudio --index-url https://download.pytorch.org/whl/nightly/cu130 --force-reinstall

# 커스텀 노드 설치 (git clone 방식 - 안정적)
RUN cd /comfyui/custom_nodes && \
    git clone https://github.com/kijai/ComfyUI-KJNodes.git && \
    git clone https://github.com/rgthree/rgthree-comfy.git && \
    git clone https://github.com/cubiq/ComfyUI_essentials.git && \
    git clone https://github.com/yolain/ComfyUI-Easy-Use.git && \
    git clone https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git && \
    git clone https://github.com/crystian/ComfyUI-Crystools.git && \
    git clone https://github.com/ClownsharkBatwing/RES4LYF.git && \
    git clone https://github.com/pythongosssss/ComfyUI-Custom-Scripts.git && \
    git clone https://github.com/Fannovel16/ComfyUI-Frame-Interpolation.git

# 각 노드의 requirements 설치
RUN cd /comfyui/custom_nodes && \
    for dir in */; do \
        if [ -f "$dir/requirements.txt" ]; then \
            pip install -r "$dir/requirements.txt" --no-cache-dir || true; \
        fi \
    done

# Python 패키지 설치 (SageAttention Blackwell 호환)
RUN pip install sageattention --no-build-isolation --force-reinstall
RUN pip install deepdiff jsondiff PyWavelets ffmpeg-python

# 설정 파일 및 핸들러 복사
COPY extra_model_paths.yaml /comfyui/
COPY start.sh /start.sh
COPY rp_handler.py /rp_handler.py
COPY workflows/ /comfyui/workflows/

# 실행 권한 부여
RUN chmod +x /start.sh

# 보안 및 서버리스 최적화를 위해 ComfyUI-Manager 삭제
RUN rm -rf /comfyui/custom_nodes/ComfyUI-Manager

# 핸들러 타임아웃 설정 증가
RUN sed -i 's/COMFY_API_AVAILABLE_MAX_RETRIES = 500/COMFY_API_AVAILABLE_MAX_RETRIES = 2400/' /handler.py || true

ENTRYPOINT ["/start.sh"]
