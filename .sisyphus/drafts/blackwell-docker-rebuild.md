# Draft: RTX 5090 (Blackwell) Docker Rebuild for ComfyUI Serverless

## Requirements (confirmed from user context)

### Hardware Target
- RTX 5090 (Blackwell architecture, sm_120)
- CUDA 12.8 required

### Base Image Decision
- ABANDON: `runpod/worker-comfyui:5.6.0-base-cuda12.8.1` (too many issues)
- USE: `nvidia/cuda:12.8.0-cudnn-devel-ubuntu24.04` (devel for SageAttention compilation)

### PyTorch Requirements
- PyTorch 2.10.0 stable with cu128 (or nightly if not available)
- Command: `pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu128`
- MUST set `TORCH_CUDA_ARCH_LIST="12.0"` for compilation

### SageAttention Requirements
- Version 2.4.0+ for Blackwell compatibility
- Install with `--no-build-isolation`
- KNOWN ISSUE: SageAttention + Wan2.2 FP8 can produce black frames (Issue #221)

### ComfyUI Setup
- Source: `https://github.com/comfyanonymous/ComfyUI.git` (latest master)
- Launch flags: `--listen 0.0.0.0 --port 8188 --fast fp16_accumulation --preview-method none --use-sage-attention`

### Custom Nodes (10 total) - FROM WORKING 4090 SETUP
1. rgthree-comfy (rgthree)
2. ComfyUI_essentials (cubiq)
3. ComfyUI-Easy-Use (yolain)
4. ComfyUI-KJNodes (kijai)
5. ComfyUI-VideoHelperSuite (Kosinkadink)
6. ComfyUI-Crystools (crystian)
7. RES4LYF (ClownsharkBatwing)
8. ComfyUI-Custom-Scripts (pythongosssss)
9. ComfyUI-Frame-Interpolation (Fannovel16) - for RIFE
10. ComfyUI-Manager - EXCLUDE for serverless (security)

### Python Packages
- sageattention (--no-build-isolation)
- deepdiff
- jsondiff
- PyWavelets
- ffmpeg-python
- runpod (for serverless handler)

### RunPod Serverless Requirements
- Handler script (`rp_handler.py`) with `runpod.serverless.start({"handler": handler})`
- ComfyUI runs internally on 127.0.0.1:8188
- No public ports needed for serverless
- start.sh starts ComfyUI in background, then runs handler

## Existing Files Analysis

### Current Dockerfile (WILL BE REPLACED)
- Uses `runpod/worker-comfyui:5.6.0-base-cuda12.8.1` - PROBLEMATIC
- ComfyUI path: `/comfyui/`
- Custom nodes at `/comfyui/custom_nodes/`
- Already removes ComfyUI-Manager for serverless

### Current start.sh (NEEDS MODIFICATION)
- Model download logic: R2 for DaSiWa, HuggingFace for others
- Creates `/workspace/models/` directories
- Starts ComfyUI with `--listen 0.0.0.0 --port 8188 --use-sage-attention --fast fp16_accumulation`
- Checks `RUNPOD_SERVERLESS` env var for mode switching
- ISSUE: ComfyUI path is `/comfyui/main.py` - needs to match new Dockerfile

### Current rp_handler.py (LIKELY KEEP AS-IS)
- Well-structured handler
- Paths: `/comfyui/workflows/`, `/comfyui/input/`, `/comfyui/output/`
- Workflow: `wan_flf_i2v_api.json`
- ISSUE: Paths must match new Dockerfile structure

### Current extra_model_paths.yaml (LIKELY KEEP AS-IS)
- Supports both `/workspace/models` and `/runpod-volume/models`

### GitHub Workflow (KEEP AS-IS)
- Docker build push to GHCR
- Uses disk space cleanup step (important for large images)

## Open Questions

1. **Python Version**: What Python version to install? 3.10? 3.11? 3.12?
2. **ComfyUI Install Path**: Keep `/comfyui/` or change to something like `/app/ComfyUI/`?
3. **Test Strategy**: How to test locally before deploying to RunPod?
4. **Fallback**: If SageAttention causes black frames, should we have a fallback mode?
5. **Image Size**: Any concerns about final image size with NVIDIA devel image?

## Scope Boundaries

### INCLUDE
- New Dockerfile from scratch with NVIDIA base image
- Modified start.sh with correct paths
- Any necessary path updates in rp_handler.py and extra_model_paths.yaml
- Testing strategy

### EXCLUDE (Guardrails)
- Workflow file changes (wan_flf_i2v_api.json is working)
- GitHub Actions workflow changes (working fine)
- Model changes or new model additions
- New custom nodes beyond the 10 specified
