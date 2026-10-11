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


# Install ComfyUI-Manager via pip (v4.x)
RUN /opt/venv/bin/python -m pip install --no-cache-dir --upgrade comfyui-manager
# Install new ComfyUI-Manager dependencies
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
