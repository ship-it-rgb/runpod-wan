import runpod
import json
import time
import base64
import requests
import websocket
import os
import urllib.request
import random
from uuid import uuid4

COMFY_HOST = "127.0.0.1:8188"
COMFY_API_URL = f"http://{COMFY_HOST}"

# Workflow file path (inside the container)
WORKFLOW_PATH = "/ComfyUI/workflows/wan_flf_i2v_api.json"


def wait_for_comfyui():
    """Wait for ComfyUI to be ready"""
    print("Waiting for ComfyUI...")
    for _ in range(120):
        try:
            r = requests.get(f"{COMFY_API_URL}/system_stats", timeout=5)
            if r.status_code == 200:
                print("ComfyUI is ready.")
                return True
        except requests.exceptions.RequestException:
            pass
        time.sleep(1)
    print("ComfyUI timed out.")
    return False


def save_input_image(image_data, filename):
    """Save base64 image or download URL to ComfyUI input folder"""
    # Assuming standard ComfyUI container layout
    input_path = f"/ComfyUI/input/{filename}"

    print(f"Saving input image to {input_path}...")
    try:
        if image_data.startswith("http"):
            urllib.request.urlretrieve(image_data, input_path)
        else:
            # Handle base64
            if "," in image_data:
                image_data = image_data.split(",")[1]
            with open(input_path, "wb") as f:
                f.write(base64.b64decode(image_data))
        return filename
    except Exception as e:
        print(f"Error saving input image: {e}")
        raise


def queue_workflow(workflow, client_id):
    """Queue workflow and return prompt_id"""
    payload = {"prompt": workflow, "client_id": client_id}
    print(f"Queuing workflow with client_id={client_id}...")
    try:
        r = requests.post(f"{COMFY_API_URL}/prompt", json=payload)
        r.raise_for_status()
        response = r.json()
        prompt_id = response.get("prompt_id")
        print(f"Workflow queued. prompt_id={prompt_id}")
        return prompt_id
    except Exception as e:
        print(f"Error queuing workflow: {e}")
        return None


def wait_for_completion(prompt_id, client_id, timeout=3600):
    """Wait for workflow completion via WebSocket"""
    ws_url = f"ws://{COMFY_HOST}/ws?clientId={client_id}"
    print(f"Connecting to WebSocket: {ws_url}")

    try:
        ws = websocket.create_connection(ws_url)
    except Exception as e:
        print(f"WebSocket connection failed: {e}")
        return False

    start_time = time.time()
    print(f"Monitoring execution for prompt_id={prompt_id}...")

    try:
        while time.time() - start_time < timeout:
            try:
                msg = ws.recv()
                if isinstance(msg, str):
                    data = json.loads(msg)

                    if data.get("type") == "executing":
                        data_content = data.get("data", {})
                        if (
                            data_content.get("node") is None
                            and data_content.get("prompt_id") == prompt_id
                        ):
                            print("Workflow execution complete.")
                            return True
                    elif data.get("type") == "execution_error":
                        data_content = data.get("data", {})
                        if data_content.get("prompt_id") == prompt_id:
                            print(f"Workflow execution error: {data_content}")
                            return False
            except websocket.WebSocketTimeoutException:
                continue
            except Exception as e:
                print(f"WebSocket error: {e}")
                break
    finally:
        ws.close()

    print("Workflow execution timed out.")
    return False


def get_output_video(prompt_id):
    """Get output video path from history"""
    print(f"Fetching history for prompt_id={prompt_id}...")
    try:
        r = requests.get(f"{COMFY_API_URL}/history/{prompt_id}")
        r.raise_for_status()
        history = r.json()

        outputs = history.get(prompt_id, {}).get("outputs", {})

        # Look for video output
        for node_id, node_output in outputs.items():
            if "gifs" in node_output:
                for video_info in node_output["gifs"]:
                    subfolder = video_info.get("subfolder", "")
                    filename = video_info.get("filename", "")
                    # Construct path - handling empty subfolder
                    if subfolder:
                        video_path = f"/ComfyUI/output/{subfolder}/{filename}"
                    else:
                        video_path = f"/ComfyUI/output/{filename}"
                    print(f"Found output video: {video_path}")
                    return video_path

            # Fallback for some VHS versions or other video nodes that might use 'videos' key
            if "videos" in node_output:
                for video_info in node_output["videos"]:
                    subfolder = video_info.get("subfolder", "")
                    filename = video_info.get("filename", "")
                    if subfolder:
                        video_path = f"/ComfyUI/output/{subfolder}/{filename}"
                    else:
                        video_path = f"/ComfyUI/output/{filename}"
                    print(f"Found output video (videos key): {video_path}")
                    return video_path

    except Exception as e:
        print(f"Error getting output video: {e}")

    print("No output video found in history.")
    return None


def handler(job):
    """Main handler for RunPod serverless"""
    print(f"Received job: {job.get('id')}")
    job_input = job.get("input", {})

    # Validate input
    if "start_image" not in job_input:
        return {"error": "start_image is required"}
    if "prompt" not in job_input:
        return {"error": "prompt is required"}

    # Wait for ComfyUI
    if not wait_for_comfyui():
        return {"error": "ComfyUI not ready"}

    try:
        # Process input image
        image_filename = f"{uuid4()}.png"
        save_input_image(job_input["start_image"], image_filename)

        # Load and modify workflow
        if not os.path.exists(WORKFLOW_PATH):
            return {"error": f"Workflow file not found: {WORKFLOW_PATH}"}

        with open(WORKFLOW_PATH, "r") as f:
            workflow = json.load(f)

        # Inject inputs based on wanworkflow0202.json node IDs
        # Node 260: LoadImage
        if "260" in workflow:
            workflow["260"]["inputs"]["image"] = image_filename
        else:
            return {"error": "Node 260 (LoadImage) not found in workflow"}

        # Node 246: PrimitiveStringMultiline (Positive Prompt)
        if "246" in workflow:
            workflow["246"]["inputs"]["value"] = job_input["prompt"]
        else:
            return {"error": "Node 246 (Positive Prompt) not found in workflow"}

        # Node 247: PrimitiveStringMultiline (Negative Prompt)
        if "247" in workflow:
            workflow["247"]["inputs"]["value"] = job_input.get(
                "negative_prompt", "低质量, 模糊, 变形, 扭曲, 水印"
            )  # Default negative prompt
        else:
            return {"error": "Node 247 (Negative Prompt) not found in workflow"}

        # Node 500:1: EmptyImage (Resolution)
        width = job_input.get("width", 720)
        height = job_input.get("height", 1280)
        if "500:1" in workflow:
            workflow["500:1"]["inputs"]["width"] = width
            workflow["500:1"]["inputs"]["height"] = height
            print(f"Resolution set to {width}x{height}")

        # Node 834: PrimitiveInt (Seed for RandomNoise)
        seed = job_input.get("seed")
        if seed is None:
            seed = random.randint(0, 2**53 - 1)  # Generate random seed if not provided
        if "834" in workflow:
            workflow["834"]["inputs"]["value"] = int(seed)
            print(f"Seed set to {seed}")
        else:
            print("Warning: Node 834 (Seed) not found in workflow")

        # Queue workflow
        client_id = str(uuid4())
        prompt_id = queue_workflow(workflow, client_id)

        if not prompt_id:
            return {"error": "Failed to queue workflow"}

        # Wait for completion
        if not wait_for_completion(prompt_id, client_id):
            return {"error": "Workflow execution failed or timed out"}

        # Get output
        video_path = get_output_video(prompt_id)
        if not video_path or not os.path.exists(video_path):
            return {"error": "Output video not found on disk"}

        # Return base64 video
        print(f"Reading output video from {video_path}...")
        with open(video_path, "rb") as f:
            video_base64 = base64.b64encode(f.read()).decode("utf-8")

        # Cleanup input image (optional, but good practice)
        try:
            os.remove(f"/comfyui/input/{image_filename}")
        except:
            pass

        return {"video": video_base64, "format": "mp4"}

    except Exception as e:
        print(f"Handler error: {e}")
        return {"error": str(e)}


if __name__ == "__main__":
    runpod.serverless.start({"handler": handler})
