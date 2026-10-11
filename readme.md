# ComfyUI MiniMax H3 Full — ROCm Docker Setup

A reproducible Docker setup for running ComfyUI v0.33.0 on AMD ROCm 7.14 (RX 7900 XTX / gfx1100), pre-loaded with all custom nodes needed for the MiniMax H3 workflow: INT8 fast ROCm loader, GGUF support, IPAdapter, VideoHelperSuite, HuggingFace Downloader, and more.

---

## 1. Requirements

- **Host OS:** Linux (validated on Ubuntu)
- **GPU:** AMD Radeon RX 7900 XTX (gfx1100) — other gfx11xx may work but are unvalidated
- **ROCm driver:** 7.14 on the host, matching the base image
- **Docker:** with Compose v2
- **Disk:** ~30 GB for the image + whatever space you need for models
- **RAM:** 32 GB minimum recommended for MiniMax H3 workloads

Verify the host sees the GPU before starting:

```bash
rocminfo | grep gfx
# Should print: gfx1100
```

---

## 2. Directory Layout

Create the workspace and the standard host folders:

```bash
mkdir -p /home/rx7900/appdev/comfy-docker2/{models,output,input}
cd /home/rx7900/appdev/comfy-docker2
```

Place these files in that directory:

```
comfy-docker2/
├── Dockerfile
├── docker-compose.yml
└── .env
```

---

## 3. `.env` File

Create `.env` next to the compose file:

```env
# Where ComfyUI's output/, input/, and other runtime dirs live on the host
COMFY_ROOT=/home/rx7900/appdev/comfy-docker2

# Where the models live. Point this at a large disk if you have one.
COMFY_MODELS=/home/rx7900/appdev/comfy-docker2
```

> Adjust `COMFY_MODELS` if your models live on a separate drive — the compose file mounts `${COMFY_MODELS}/models` onto `/workspace/ComfyUI/models`.

---

## 4. Dockerfile (Final Working Version)

```dockerfile
FROM rocm/pytorch:rocm7.14_ubuntu24.04_py3.12_pytorch_release_2.12.0

ENV DEBIAN_FRONTEND=noninteractive
WORKDIR /workspace

# System dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    ffmpeg \
    libgl1 \
    libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

# Pin ComfyUI version
RUN git clone --branch v0.33.0 --depth 1 https://github.com/comfyanonymous/ComfyUI.git

WORKDIR /workspace/ComfyUI

# Core runtime dependencies
RUN /opt/venv/bin/python -m pip install --no-cache-dir \
    multidict \
    mako \
    aiohttp \
    sqlalchemy \
    alembic \
    torchsde \
    pydantic_core \
    opencv-python-headless \
    comfyui-frontend-package

# Upgrade pip toolchain, install compatible setuptools
RUN /opt/venv/bin/python -m pip install --upgrade pip wheel && \
    /opt/venv/bin/python -m pip install "setuptools<82"

# Install ComfyUI core requirements (exclude torch-related, keep ROCm PyTorch)
RUN grep -v -E '^(torch|torchvision|torchaudio|#)' requirements.txt | \
    grep -v '^#' | \
    grep -v '^\s*$' | \
    xargs -r /opt/venv/bin/python -m pip install

# Upgrade PyAV
RUN /opt/venv/bin/python -m pip install --no-cache-dir --upgrade av

# ============================================================
# ComfyUI-Manager (v4) — CRITICAL
# ============================================================
# These two lines are what make the new Node Manager functional.
RUN /opt/venv/bin/python -m pip install --no-cache-dir --upgrade comfyui-manager
RUN /opt/venv/bin/python -m pip install --no-cache-dir -r manager_requirements.txt

# ============================================================
# Custom nodes for MiniMax H3 and general workflows
# ============================================================

# 1. ComfyUI-GGUF (molbal fork — supports MiniMax H3 GGUF)
RUN git clone https://github.com/molbal/ComfyUI-GGUF custom_nodes/ComfyUI-GGUF && \
    /opt/venv/bin/python -m pip install --no-cache-dir -r custom_nodes/ComfyUI-GGUF/requirements.txt

# 2. ComfyUI IPAdapter plus
RUN git clone https://github.com/cubiq/ComfyUI_IPAdapter_plus custom_nodes/comfyui_ipadapter_plus && \
    if [ -f custom_nodes/comfyui_ipadapter_plus/requirements.txt ]; then \
      /opt/venv/bin/python -m pip install --no-cache-dir -r custom_nodes/comfyui_ipadapter_plus/requirements.txt; \
    fi

# 3. ComfyUI-UtilsCollection
RUN git clone https://github.com/silveroxides/ComfyUI-UtilsCollection custom_nodes/ComfyUI-UtilsCollection && \
    if [ -f custom_nodes/ComfyUI-UtilsCollection/requirements.txt ]; then \
      /opt/venv/bin/python -m pip install --no-cache-dir -r custom_nodes/ComfyUI-UtilsCollection/requirements.txt; \
    fi

# 4. ComfyUI-VideoHelperSuite
RUN git clone https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite custom_nodes/comfyui-videohelpersuite && \
    if [ -f custom_nodes/comfyui-videohelpersuite/requirements.txt ]; then \
      /opt/venv/bin/python -m pip install --no-cache-dir -r custom_nodes/comfyui-videohelpersuite/requirements.txt; \
    fi

# 5. MiniMax H3 INT8 Fast ROCm (DrBearJew)
RUN git clone https://github.com/DrBearJew/ComfyUI-INT8-Fast-ROCM-ConvRot custom_nodes/minimax-h3-int8-fast-rocm && \
    if [ -f custom_nodes/minimax-h3-int8-fast-rocm/requirements.txt ]; then \
      /opt/venv/bin/python -m pip install --no-cache-dir -r custom_nodes/minimax-h3-int8-fast-rocm/requirements.txt; \
    fi

# 6. ComfyUI HuggingFace Downloader
RUN git clone https://github.com/jnxmx/ComfyUI_HuggingFace_Downloader custom_nodes/ComfyUI_HuggingFace_Downloader && \
    if [ -f custom_nodes/ComfyUI_HuggingFace_Downloader/requirements.txt ]; then \
      /opt/venv/bin/python -m pip install --no-cache-dir -r custom_nodes/ComfyUI_HuggingFace_Downloader/requirements.txt; \
    fi

# 7. ComfyUI Model Manager
RUN git clone https://github.com/hayden-cn/ComfyUI-Model-Manager custom_nodes/comfyui-model-manager && \
    if [ -f custom_nodes/comfyui-model-manager/requirements.txt ]; then \
      /opt/venv/bin/python -m pip install --no-cache-dir -r custom_nodes/comfyui-model-manager/requirements.txt; \
    fi

# 8. ComfyUI VideoDirCombiner
RUN git clone https://github.com/DarioFT/ComfyUI-VideoDirCombiner custom_nodes/comfyui-videodircombiner && \
    if [ -f custom_nodes/comfyui-videodircombiner/requirements.txt ]; then \
      /opt/venv/bin/python -m pip install --no-cache-dir -r custom_nodes/comfyui-videodircombiner/requirements.txt; \
    fi

# 9. MiniMax H3 Image Studio
RUN git clone https://github.com/astropuzzo/ComfyUI-MiniMax-H3-Image-Studio.git \
    custom_nodes/minimax-h3-image-studio && \
    if [ -f custom_nodes/minimax-h3-image-studio/requirements.txt ]; then \
      /opt/venv/bin/python -m pip install --no-cache-dir -r custom_nodes/minimax-h3-image-studio/requirements.txt; \
    fi

# 10. Stable Audio 3 Edit
RUN git clone https://github.com/pavel-zinchenko/comfyui-stable-audio-3-edit custom_nodes/stable-audio-3-edit && \
    if [ -f custom_nodes/stable-audio-3-edit/requirements.txt ]; then \
      /opt/venv/bin/python -m pip install --no-cache-dir -r custom_nodes/stable-audio-3-edit/requirements.txt; \
    fi

# ============================================================
# Model directories
# ============================================================
RUN mkdir -p /workspace/ComfyUI/models/diffusion_models \
             /workspace/ComfyUI/models/text_encoders \
             /workspace/ComfyUI/models/vae \
             /workspace/ComfyUI/models/loras \
             /workspace/ComfyUI/models/unet \
             /workspace/ComfyUI/models/clip

EXPOSE 8188
CMD ["python", "main.py", "--listen", "0.0.0.0"]
```

---

## 5. docker-compose.yml (Final Working Version)

```yaml
services:
  comfyui-minimax-full:
    build:
      context: .
      dockerfile: Dockerfile
    image: comfyui-minimax-rocm7.14:latest
    container_name: comfyui-minimax-full
    restart: "no"
    devices:
      - /dev/kfd:/dev/kfd
      - /dev/dri:/dev/dri
    group_add:
      - video
      - "992"          # render group (adjust to host's actual GID)
    ipc: host
    security_opt:
      - seccomp=unconfined
    shm_size: "16gb"
    ports:
      - "8189:8188"
    volumes:
      - ${COMFY_MODELS}/models:/workspace/ComfyUI/models
      - ${COMFY_ROOT}/output:/workspace/ComfyUI/output
      - ${COMFY_ROOT}/input:/workspace/ComfyUI/input
    environment:
      - HIP_VISIBLE_DEVICES=0
      - HSA_OVERRIDE_GFX_VERSION=11.0.0
      - PYTORCH_HIP_ALLOC_CONF=expandable_segments:True,garbage_collection_threshold:0.75,max_split_size_mb:512
      - HSA_DISABLE_FRAGMENT_ALLOCATOR=1
      - MIOPEN_FIND_MODE=FAST
    working_dir: /workspace/ComfyUI
    command: >
      python main.py --listen 0.0.0.0 --enable-manager
      --enable-dynamic-vram --reserve-vram 0.5 --vram-headroom 2 --cache-none --use-pytorch-cross-attention
```

> **Note on the render group GID (`992`):** check your host's GID with `getent group render` and update the value if it differs.

> **Note on the port:** the UI is exposed on **8189** on the host (`8189:8188`). Open `http://localhost:8189`.

---

## 6. Build

From the directory containing `Dockerfile`, `docker-compose.yml`, and `.env`:

```bash
docker compose build --no-cache --progress=plain 2>&1 | tee build.log
```

Watch `build.log` for any pip errors during custom node installs. The build will take a while — the ROCm base image is large.

---

## 7. Run

```bash
docker compose up -d
docker compose logs -f comfyui-minimax-full
```

Wait for:

```
ComfyUI version: 0.33.0
Device: cuda:0 AMD Radeon RX 7900 XTX
Starting server
```

Then open:

```
http://localhost:8189
```

Stop with:

```bash
docker compose down
```

---

## 8. Critical Notes

### Why `--enable-manager` is required

The new ComfyUI-Manager (v4) is a **pip package**, not a `custom_nodes/` git clone. Even though you install it via pip in the Dockerfile, it will **not activate** unless ComfyUI is launched with `--enable-manager`. Without this flag, the "Manage Extensions" button opens the Settings dialog instead of the Node Manager.

### Why the two Manager lines in the Dockerfile matter

```dockerfile
RUN /opt/venv/bin/python -m pip install --no-cache-dir --upgrade comfyui-manager
RUN /opt/venv/bin/python -m pip install --no-cache-dir -r manager_requirements.txt
```

- The first line installs the Manager package itself.
- The second line installs its runtime dependencies from ComfyUI's own `manager_requirements.txt`. Skipping it causes silent crashes or a non-functional Manager UI on startup.

Both lines must remain in the Dockerfile. They are what make the Manager stable.

### Why the Manager shows no installed custom nodes

After the first boot, the Node Manager may show **none** of your pre-installed custom nodes as "Installed", even though they are physically present under `custom_nodes/` and fully functional. This is a known quirk of the new Manager — it does not automatically register nodes that were baked into the image rather than installed through its own UI.

**The fix:**

1. Open the Node Manager in the UI.
2. Pick **any one** of your custom nodes and click **Install** (reinstall it — it will overwrite the existing folder with the same content).
3. **Restart the container** (`docker compose restart`).
4. On the next boot, **all** of the pre-installed custom nodes will appear correctly as "Installed".

You only need to do this once per fresh image. After step 3, the Manager's internal database is populated, and the state persists in the image.

---

## 9. Common Operations

**Rebuild from zero:**

```bash
docker compose down -v
docker rmi comfyui-minimax-rocm7.14:latest 2>/dev/null || true
docker builder prune -a -f
docker compose build --no-cache --progress=plain
docker compose up -d
```

**Restart without rebuilding:**

```bash
docker compose restart
```

**Open a shell inside the running container:**

```bash
docker compose exec comfyui-minimax-full bash
```

**List custom nodes installed:**

```bash
docker compose exec comfyui-minimax-full ls /workspace/ComfyUI/custom_nodes/
```

**Check GPU visibility from inside the container:**

```bash
docker compose exec comfyui-minimax-full rocminfo | grep gfx
```

---

## 10. Model Locations

Place models on the host under `${COMFY_MODELS}/models/` in the standard ComfyUI subfolders:

```
models/
├── diffusion_models/
├── text_encoders/
├── vae/
├── loras/
├── unet/
└── clip/
```

For MiniMax H3 INT8 ConvRot, the validated models are:

- `MiniMax H3 FL2VA INT8 ConvRot`
- `MiniMax H3 Ref2VA INT8 ConvRot`

Upstream Turbo LoRAs are available at `lightx2v/Minimax-h3-Turbo`. Match FL2V LoRAs with FL2VA and Ref2V LoRAs with Ref2VA.

### Model file reference (from ComfyUI's official MiniMax H3 tutorial)

**Text-to-Video (T2V) and Image-to-Video (I2V):**

```
models/
├── diffusion_models/
│   └── minimax_h3_fl2va_pruned_int8_convrot.safetensors
├── text_encoders/
│   └── qwen3vl_32b_minimax_h3_nvfp4_awq.safetensors
├── vae/
│   ├── minimax_h3_video_vae_int8_convrot.safetensors
│   └── minimax_h3_audio_vae_fp32.safetensors
├── loras/
│   └── minimax_h3_fl2v_turbo_8step_v1.0_comfyui_bf16.safetensors
└── embeddings/
    └── minimaxh3_art_is_explosion.safetensors
```

**Reference-to-Video (R2V):**

```
models/
├── diffusion_models/
│   └── minimax_h3_ref2va_pruned_int8_convrot.safetensors
├── text_encoders/
│   └── qwen3vl_32b_minimax_h3_nvfp4_awq.safetensors
├── vae/
│   ├── minimax_h3_video_vae_int8_convrot.safetensors
│   └── minimax_h3_audio_vae_fp32.safetensors
├── loras/
│   └── minimax_h3_ref2v_turbo_4step_v0.1_comfyui_bf16.safetensors
└── embeddings/
    └── minimaxh3_art_is_explosion.safetensors
```

Key workflow tips from the official docs:
- H3's native canvas is a 768px short edge (1344x768 at 16:9), rounded to multiples of 32
- Duration snaps to a 17-frame-per-block grid (17k+5) at 24fps
- Turbo mode uses the included Lightning LoRA at 8 steps (T2V/I2V) or 4 steps (R2V) for much faster generation
- R2V supports up to 9 reference images, 3 reference videos, and 3 standalone audio clips
- Reference inputs by tag in the exact order connected: `<Picture 1>`, `<Video 1>`, `<Audio 1>`

---

## 11. Troubleshooting

| Symptom | Fix |
| --- | --- |
| UI opens Settings instead of Node Manager | Ensure `--enable-manager` is present in `command:` |
| Manager button missing entirely | Confirm both `pip install comfyui-manager` and `-r manager_requirements.txt` lines exist in the Dockerfile, then rebuild |
| Manager shows no installed nodes | Reinstall one node via UI, then restart the container (see §8) |
| Container starts but no GPU | Verify `/dev/kfd` and `/dev/dri` are passed through, and the `render` GID matches the host |
| OOM during generation | Lower `--vram-headroom` or remove `--cache-none` |
| Slow first inference | MIOpen is compiling kernels; subsequent runs are faster |

---

## 12. References

### MiniMax H3 INT8 Fast ROCm Loader
- **DrBearJew/ComfyUI-INT8-Fast-ROCM-ConvRot** — https://github.com/DrBearJew/ComfyUI-INT8-Fast-ROCM-ConvRot
  The validated INT8 ConvRot loader for MiniMax H3 on AMD ROCm. Includes the `MiniMaxH3INT8FastLoader` node, LoRA compatibility notes, and validated model list (FL2VA and Ref2VA INT8 ConvRot).

### ROCm / PyTorch Installation
- **Install PyTorch for ROCm (AMD official docs)** — https://rocm.docs.amd.com/projects/ai-ecosystem/en/latest/frameworks/pytorch/install.html?fam=radeon&gpu=amd-radeon-rx-7900-xtx&os=linux&rocm-ver=7.14.0&pytorch-ver=2.12.0&i=docker&w=compute&gfx=gfx1100
  The official Docker-based install guide for PyTorch 2.12.0 + ROCm 7.14.0 on RX 7900 XTX. Covers the base image tags used in this Dockerfile and the required `docker run` device flags (`/dev/kfd`, `/dev/dri`, `--group-add=video`, `--ipc=host`, `--security-opt seccomp=unconfined`).

### ComfyUI MiniMax H3 Workflows
- **ComfyUI MiniMax H3 Native Tutorial (official docs)** — https://docs.comfy.org/tutorials/video/minimax/minimax-h3-native
  Official documentation for T2V, I2V, and R2V workflows. Contains exact model filenames, storage layout, prompting tips, resolution/duration grids, and advanced native-node techniques (`MiniMaxH3AddGuide` for arbitrary-frame anchoring, latent noise masks for inpainting/extension).

### Community References
- **MiniMax H3 local Ubuntu install discussion (Xiaohongshu)** — https://www.xiaohongshu.com/search_result_ai?keyword=minimax%2520h3%25E6%259C%25AC%25E5%259C%25B0%25E9%2583%25A8%25E7%25BD%25B2ubuntu&source=web_explore_feed
  Community notes and troubleshooting for running MiniMax H3 locally on Ubuntu.

- **a756598009-cmyk/MiniMax-H3-AMD7900XTX-Win11** — https://github.com/a756598009-cmyk/MiniMax-H3-AMD7900XTX-Win11
  A Windows 11 + RX 7900 XTX counterpart setup. Useful for cross-referencing model paths, environment variables, and workflow JSON files even when running on Linux/ROCm.