# NVIDIA Base Image Rebuild for RTX 5090 Wan2.2 Serverless

## TL;DR

> **Quick Summary**: Rebuild Docker image from scratch using NVIDIA CUDA 12.8 base instead of RunPod worker image. Target RTX 5090 (Blackwell) in eu-is-2/eu-no-1 regions.
> 
> **Deliverables**:
> - New Dockerfile with `nvidia/cuda:12.8.0-cudnn-devel-ubuntu24.04` base
> - Updated start.sh with ComfyUI path changes
> - Updated rp_handler.py with path updates
> - Working serverless endpoint for Wan2.2 I2V
> 
> **Estimated Effort**: Medium (4-6 hours)
> **Parallel Execution**: YES - 2 waves
> **Critical Path**: Task 1 → Task 2 → Task 4 → Task 5

---

## Context

### Original Request
Rebuild RunPod serverless endpoint for Wan2.2 I2V without using `runpod/worker-comfyui` base image due to repeated issues (comfy_aimdo errors, PyTorch conflicts, rclone "Text file busy" errors).

### Interview Summary
**Key Discussions**:
- Target GPU: RTX 5090 (Blackwell, SM_120) in eu-is-2/eu-no-1
- Base image: `nvidia/cuda:12.8.0-cudnn-devel-ubuntu24.04`
- Models: DaSiWa from R2, others from HuggingFace
- Verification: Manual testing on RunPod after deployment

**Research Findings**:
- CUDA 12.8 required for Blackwell SM_120 compute capability
- PyTorch 2.7+ with cu128 wheels
- SageAttention 3 has Blackwell-specific fixes (Issue #291)
- `TORCH_CUDA_ARCH_LIST="12.0"` required for building custom kernels

### Metis Review
**Identified Gaps** (addressed):
- RIFE model download: ComfyUI-Frame-Interpolation auto-downloads, no action needed
- Python version: Ubuntu 24.04 ships Python 3.12, compatible with all deps
- Path updates: `/comfyui` → `/ComfyUI` throughout all files
- Missing system deps: Added libgl1, libglib2.0, ffmpeg, ninja-build

---

## Work Objectives

### Core Objective
Replace RunPod worker-comfyui base image with pure NVIDIA CUDA base, installing ComfyUI and dependencies from scratch for better control and Blackwell compatibility.

### Concrete Deliverables
- `/Users/ahnjinkyu/Desktop/wan/runpod-wan/Dockerfile` - Rewritten with NVIDIA base
- `/Users/ahnjinkyu/Desktop/wan/runpod-wan/start.sh` - Updated paths
- `/Users/ahnjinkyu/Desktop/wan/runpod-wan/rp_handler.py` - Updated paths

### Definition of Done
- [ ] Docker image builds successfully
- [ ] SageAttention imports without error
- [ ] ComfyUI starts in CPU mode (local test)
- [ ] Serverless endpoint responds on RunPod
- [ ] Video generation produces valid MP4

### Must Have
- NVIDIA CUDA 12.8 base image
- PyTorch with cu128 wheels
- SageAttention 3 compiled for SM_120
- All 9 custom nodes from wansetup0202.sh (minus Manager, QwenVL)
- R2 download for DaSiWa model
- HuggingFace download for other models

### Must NOT Have (Guardrails)
- `runpod/worker-comfyui` as base image
- ComfyUI-Manager (security risk in serverless)
- QwenVL node (not needed for I2V)
- Additional API parameters beyond `start_image`, `prompt`, `negative_prompt`
- Multi-model or multi-workflow support
- BF16 model variants (FP8 only)

---

## Verification Strategy (MANDATORY)

### Test Decision
- **Infrastructure exists**: NO (manual verification)
- **User wants tests**: NO
- **QA approach**: Manual verification on RunPod

### Automated Verification

**For Docker Build** (using Bash):
```bash
cd /Users/ahnjinkyu/Desktop/wan/runpod-wan
docker build -t wan-blackwell:test . 2>&1 | tail -10
# Assert: Contains "Successfully built" or "Successfully tagged"
```

**For SageAttention Import** (using Bash):
```bash
docker run --rm wan-blackwell:test python3 -c "import sageattention; print('OK')"
# Assert: Output is "OK"
```

**For ComfyUI Startup** (using Bash):
```bash
docker run --rm wan-blackwell:test timeout 30 python3 /ComfyUI/main.py --cpu --port 8188 2>&1 | grep -c "To see the GUI"
# Assert: Output is "1" (found the ready message)
```

**For RunPod Handler** (using Bash):
```bash
docker run --rm wan-blackwell:test python3 -c "import runpod; print('OK')"
# Assert: Output is "OK"
```

**For Deployed Endpoint** (using curl):
```bash
curl -s -X POST "https://api.runpod.ai/v2/${ENDPOINT_ID}/runsync" \
  -H "Authorization: Bearer ${RUNPOD_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"input":{"start_image":"https://example.com/test.jpg","prompt":"woman walking"}}' \
  | jq -r '.status'
# Assert: Output is "COMPLETED"
```

---

## Execution Strategy

### Parallel Execution Waves

```
Wave 1 (Start Immediately):
├── Task 1: Rewrite Dockerfile with NVIDIA base
└── Task 3: Update rp_handler.py paths

Wave 2 (After Wave 1):
├── Task 2: Update start.sh paths and structure
└── (Task 3 if not done)

Wave 3 (After Wave 2):
├── Task 4: Local Docker build and test
└── Task 5: Deploy to RunPod and verify
```

### Dependency Matrix

| Task | Depends On | Blocks | Can Parallelize With |
|------|------------|--------|---------------------|
| 1 | None | 2, 4 | 3 |
| 2 | 1 | 4 | 3 |
| 3 | None | 4 | 1, 2 |
| 4 | 1, 2, 3 | 5 | None |
| 5 | 4 | None | None (final) |

---

## TODOs

- [ ] 1. Rewrite Dockerfile with NVIDIA CUDA 12.8 Base

  **What to do**:
  - Replace base image: `nvidia/cuda:12.8.0-cudnn-devel-ubuntu24.04`
  - Set environment variables: `TORCH_CUDA_ARCH_LIST="12.0"`, `CUDA_HOME`, `PIP_BREAK_SYSTEM_PACKAGES=1`
  - Install system dependencies: git, python3-pip, ffmpeg, ninja-build, aria2, rclone, libgl1-mesa-glx, libglib2.0-0
  - Install PyTorch: `pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu128`
  - Clone ComfyUI to `/ComfyUI`
  - Install ComfyUI requirements
  - Clone 9 custom nodes (KJNodes, rgthree, essentials, Easy-Use, VHS, Crystools, RES4LYF, Custom-Scripts, Frame-Interpolation)
  - Install each node's requirements
  - Install SageAttention: `pip install sageattention --no-build-isolation`
  - Install runpod, websocket-client, deepdiff, jsondiff, PyWavelets, ffmpeg-python
  - Copy start.sh, rp_handler.py, extra_model_paths.yaml, workflows/
  - Set ENTRYPOINT to /start.sh

  **Must NOT do**:
  - Use any runpod base image
  - Install ComfyUI-Manager
  - Install QwenVL or related LLM nodes
  - Add model downloads in Dockerfile (done at runtime)

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: Infrastructure/DevOps work requiring careful dependency management
  - **Skills**: []
    - No special skills needed - straightforward Dockerfile editing

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Task 3)
  - **Blocks**: Tasks 2, 4
  - **Blocked By**: None

  **References**:

  **Pattern References**:
  - `/Users/ahnjinkyu/Desktop/wan/wansetup0202.sh:1-68` - Custom node list and installation pattern
  - `/Users/ahnjinkyu/Desktop/wan/runpod-wan/Dockerfile:1-50` - Current Dockerfile structure to replace

  **External References**:
  - PyTorch wheels: `https://download.pytorch.org/whl/cu128/`
  - SageAttention: `https://github.com/thu-ml/SageAttention`

  **Acceptance Criteria**:

  ```bash
  # Docker build completes
  cd /Users/ahnjinkyu/Desktop/wan/runpod-wan && docker build -t wan-blackwell:test . 2>&1 | grep -E "(Successfully|FINISHED)"
  # Assert: Match found
  
  # Base image is NVIDIA
  grep -c "nvidia/cuda:12.8" /Users/ahnjinkyu/Desktop/wan/runpod-wan/Dockerfile
  # Assert: Output is "1"
  
  # No runpod base image
  grep -c "runpod/worker" /Users/ahnjinkyu/Desktop/wan/runpod-wan/Dockerfile
  # Assert: Output is "0"
  ```

  **Commit**: YES
  - Message: `feat: rewrite Dockerfile with NVIDIA CUDA 12.8 base for RTX 5090`
  - Files: `Dockerfile`

---

- [ ] 2. Update start.sh with New Paths

  **What to do**:
  - Change all `/comfyui` paths to `/ComfyUI`
  - Update model paths: `/workspace/models` remains same (symlinked)
  - Keep R2 download logic with rclone copy workaround
  - Keep HuggingFace aria2c download logic
  - Update ComfyUI startup command: `python3 /ComfyUI/main.py`
  - Keep serverless mode detection (`RUNPOD_SERVERLESS`)
  - Keep handler startup: `python3 /rp_handler.py`

  **Must NOT do**:
  - Change download URLs or model names
  - Add new environment variables
  - Change the parallel download pattern

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Simple path string replacements
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: NO (depends on Task 1 for context)
  - **Parallel Group**: Wave 2
  - **Blocks**: Task 4
  - **Blocked By**: Task 1

  **References**:

  **Pattern References**:
  - `/Users/ahnjinkyu/Desktop/wan/runpod-wan/start.sh:1-116` - Current start.sh to update

  **Acceptance Criteria**:

  ```bash
  # No old /comfyui paths remain (except comments)
  grep -c "/comfyui/" /Users/ahnjinkyu/Desktop/wan/runpod-wan/start.sh
  # Assert: Output is "0"
  
  # New /ComfyUI paths present
  grep -c "/ComfyUI/" /Users/ahnjinkyu/Desktop/wan/runpod-wan/start.sh
  # Assert: Output >= 1
  ```

  **Commit**: YES (groups with Task 3)
  - Message: `refactor: update paths from /comfyui to /ComfyUI`
  - Files: `start.sh`, `rp_handler.py`

---

- [ ] 3. Update rp_handler.py with New Paths

  **What to do**:
  - Change `WORKFLOW_PATH` from `/comfyui/workflows/` to `/ComfyUI/workflows/`
  - Change input path from `/comfyui/input/` to `/ComfyUI/input/`
  - Change output path from `/comfyui/output/` to `/ComfyUI/output/`
  - Keep all handler logic unchanged

  **Must NOT do**:
  - Change node IDs (260, 246, 247)
  - Change API parameters
  - Change timeout values
  - Add new functionality

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Simple path string replacements
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Task 1)
  - **Blocks**: Task 4
  - **Blocked By**: None

  **References**:

  **Pattern References**:
  - `/Users/ahnjinkyu/Desktop/wan/runpod-wan/rp_handler.py:15,37,135-151,231` - Paths to update

  **Acceptance Criteria**:

  ```bash
  # No old /comfyui paths remain
  grep -c "/comfyui/" /Users/ahnjinkyu/Desktop/wan/runpod-wan/rp_handler.py
  # Assert: Output is "0"
  
  # New /ComfyUI paths present
  grep -c "/ComfyUI/" /Users/ahnjinkyu/Desktop/wan/runpod-wan/rp_handler.py
  # Assert: Output >= 3
  ```

  **Commit**: YES (groups with Task 2)
  - Message: `refactor: update paths from /comfyui to /ComfyUI`
  - Files: `start.sh`, `rp_handler.py`

---

- [ ] 4. Local Docker Build and Test

  **What to do**:
  - Build Docker image locally: `docker build -t wan-blackwell:test .`
  - Test SageAttention import: `docker run --rm wan-blackwell:test python3 -c "import sageattention"`
  - Test runpod import: `docker run --rm wan-blackwell:test python3 -c "import runpod"`
  - Test ComfyUI startup (CPU mode): `docker run --rm wan-blackwell:test timeout 30 python3 /ComfyUI/main.py --cpu`
  - Fix any build or import errors

  **Must NOT do**:
  - Push to registry until tests pass
  - Skip any verification step
  - Ignore build warnings related to CUDA

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: Build debugging may require iterative fixes
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: NO (integration test)
  - **Parallel Group**: Wave 3 (sequential)
  - **Blocks**: Task 5
  - **Blocked By**: Tasks 1, 2, 3

  **References**:

  **Pattern References**:
  - All files modified in Tasks 1-3

  **Acceptance Criteria**:

  ```bash
  # Build succeeds
  cd /Users/ahnjinkyu/Desktop/wan/runpod-wan && docker build -t wan-blackwell:test . 2>&1 | tail -3 | grep -E "(Successfully|FINISHED)"
  # Assert: Match found
  
  # SageAttention imports
  docker run --rm wan-blackwell:test python3 -c "import sageattention; print('OK')" 2>&1
  # Assert: Contains "OK"
  
  # runpod imports
  docker run --rm wan-blackwell:test python3 -c "import runpod; print('OK')" 2>&1
  # Assert: Contains "OK"
  ```

  **Commit**: YES (if fixes needed)
  - Message: `fix: resolve build issues for NVIDIA base image`
  - Files: `Dockerfile` (if changed)

---

- [ ] 5. Deploy to RunPod and Verify

  **What to do**:
  - Push image to GHCR: `docker push ghcr.io/ship-it-rgb/runpod-wan:blackwell`
  - Create or update RunPod serverless endpoint with new image
  - Set environment variables: R2_ACCESS_KEY, R2_SECRET_KEY, R2_ENDPOINT, R2_BUCKET, RUNPOD_SERVERLESS=true
  - Select RTX 5090 GPU in eu-is-2 or eu-no-1
  - Send test request with sample image and prompt
  - Verify video output is valid MP4

  **Must NOT do**:
  - Delete existing endpoint before new one is verified
  - Skip environment variable configuration
  - Use non-Blackwell GPU for initial test

  **Recommended Agent Profile**:
  - **Category**: `unspecified-low`
    - Reason: Manual deployment steps, agent provides guidance
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: NO (final step)
  - **Parallel Group**: Wave 3 (after Task 4)
  - **Blocks**: None
  - **Blocked By**: Task 4

  **References**:

  **External References**:
  - RunPod Console: `https://www.runpod.io/console/serverless`
  - GHCR: `https://ghcr.io/ship-it-rgb/runpod-wan`

  **Acceptance Criteria**:

  ```bash
  # Test request returns COMPLETED
  curl -s -X POST "https://api.runpod.ai/v2/${ENDPOINT_ID}/runsync" \
    -H "Authorization: Bearer ${RUNPOD_API_KEY}" \
    -H "Content-Type: application/json" \
    -d '{"input":{"start_image":"https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=720","prompt":"woman smiling and walking"}}' \
    | jq -r '.status'
  # Assert: Output is "COMPLETED"
  
  # Output contains video
  # (Same curl) | jq -r '.output.video' | head -c 100
  # Assert: Starts with base64 characters (not null/error)
  ```

  **Commit**: YES
  - Message: `chore: tag and push blackwell image`
  - Files: None (git tag only)

---

## Commit Strategy

| After Task | Message | Files | Verification |
|------------|---------|-------|--------------|
| 1 | `feat: rewrite Dockerfile with NVIDIA CUDA 12.8 base` | Dockerfile | grep base image |
| 2, 3 | `refactor: update paths from /comfyui to /ComfyUI` | start.sh, rp_handler.py | grep paths |
| 4 | `fix: resolve build issues` (if needed) | Dockerfile | docker build |
| 5 | `chore: tag blackwell image` | (tag) | docker push |

---

## Success Criteria

### Verification Commands
```bash
# 1. Image builds
docker build -t wan-blackwell:test .  # Expected: success

# 2. Imports work
docker run --rm wan-blackwell:test python3 -c "import sageattention, runpod; print('OK')"  # Expected: OK

# 3. Endpoint responds
curl -s https://api.runpod.ai/v2/${ENDPOINT_ID}/health | jq .  # Expected: {"status": "READY"}

# 4. Video generated
# Test request returns base64 video data
```

### Final Checklist
- [ ] All "Must Have" present
- [ ] All "Must NOT Have" absent
- [ ] Docker image uses NVIDIA base (not RunPod)
- [ ] SageAttention compiles for Blackwell
- [ ] Serverless endpoint generates videos
