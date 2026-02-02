# RunPod Wan2.2 Serverless Endpoint

This project provides a RunPod serverless endpoint for the Wan2.2 Image-to-Video (I2V) model, optimized for high-performance video generation using SageAttention and network volume support.

## Features

- **Pod Mode**: Access the ComfyUI web interface directly for manual workflows.
- **Serverless Mode**: API-driven video generation for automated pipelines.
- **SageAttention Optimization**: Improved performance and reduced VRAM usage.
- **Network Volume Support**: Efficient model management using RunPod network volumes.
- **Wan2.2 I2V Support**: High-quality video generation from images.
- **RTX 5090 Support**: Recommended for full resolution generation (32GB VRAM).

## GPU Requirements

| GPU | Resolution Support | Notes |
|-----|-------------------|-------|
| RTX 4090 (24GB) | Limited | May OOM on high-resolution workflows. |
| RTX 5090 (32GB) | Full | Recommended for the best experience and highest resolution. |

## Automatic Model Download

If the required models are not found in the volume (or if no volume is used), they will be automatically downloaded on the first boot.
- **First Boot**: Takes ~3-5 minutes depending on network speed.
- **Subsequent Boots**: Instant, as models are cached in the Container/Volume Disk.

## Usage

### Quick Start (RTX 5090 Regions)

For regions like **eu-is-2** or **eu-no-1** where network volumes might not be available, you can run with just a Container Disk:

- **Container Image**: `ghcr.io/ship-it-rgb/runpod-wan:main`
- **GPU**: RTX 5090
- **Region**: `eu-is-2` or `eu-no-1`
- **Container Disk**: 50GB (required for model cache)
- **Volume**: None required
- **Port**: 8188 (HTTP)

### Building Locally

To build the Docker image locally:

```bash
docker build -t runpod-wan .
```

### Running in Pod Mode

By default, the container starts in Pod mode, providing access to the ComfyUI web UI on port 8188.

### Running in Serverless Mode

Set the environment variable `RUNPOD_SERVERLESS` to `true` to enable the serverless handler.

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `RUNPOD_SERVERLESS` | Set to `true` to enable serverless mode. | `false` |
| `COMFY_PORT` | The port ComfyUI will run on. | `8188` |

## API Input/Output

### Input Schema

```json
{
  "input": {
    "start_image": "https://example.com/image.jpg", // or base64 encoded string
    "prompt": "a beautiful cinematic video of a sunset",
    "negative_prompt": "low quality, blurry",
    "steps": 30,
    "cfg": 6.0,
    "seed": 42
  }
}
```

### Output Schema

```json
{
  "video": "base64_encoded_mp4_data",
  "format": "mp4"
}
```

## Network Volume Setup

This endpoint is designed to work with a RunPod network volume mounted at `/workspace/ComfyUI`. The following model paths are expected:

- `models/diffusion_models/`:
  - `smoothMix_v2_WAN2.2_I2V_14B_High_fp8.safetensors`
  - `DaSiWa_v9_WAN2.2_I2V_14B_Low_fp8.safetensors`
- `models/text_encoders/`:
  - `NSFW-Wan-UMT5-XXL_fp8_scaled.safetensors`
- `models/vae/`:
  - `wan2.1_vae.safetensors`
- `models/loras/`:
  - `WAN2.2_lightx2v_I2V_14B_480p_rank128_bf16.safetensors`
- `models/clip_vision/`:
  - `clip_vision_h.safetensors`

## License

MIT License
