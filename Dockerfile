ARG BASE_OS=ros:jazzy-ros-base
FROM ${BASE_OS}

ARG DEBIAN_FRONTEND=noninteractive

ENV LANG=en_US.UTF-8
ENV RMW_IMPLEMENTATION=rmw_cyclonedds_cpp

RUN apt-get update && \
    apt-get full-upgrade -y && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        gnupg \
        wget \
        git \
        git-lfs \
        nano \
        python3-dev \
        python3-full \
        python3-pip \
        python3-setuptools \
        python3-wheel \
        python3-venv \
        python3-lark \
        python3-requests \
        portaudio19-dev \
        ros-jazzy-rmw-cyclonedds-cpp && \
    rm -rf /var/lib/apt/lists/*

##### CUDA 1 #####

RUN wget -4 \
        --tries=10 \
        --timeout=120 \
        --waitretry=15 \
        https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64/cuda-keyring_1.1-1_all.deb \
    && dpkg -i cuda-keyring_1.1-1_all.deb \
    && rm cuda-keyring_1.1-1_all.deb \
    && echo 'Acquire::Retries "10";' \
        > /etc/apt/apt.conf.d/80-retries \
    && echo 'Acquire::http::Timeout "120";' \
        >> /etc/apt/apt.conf.d/80-retries \
    && echo 'Acquire::https::Timeout "120";' \
        >> /etc/apt/apt.conf.d/80-retries \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        cuda-toolkit-12-8 \
    && rm -rf /var/lib/apt/lists/*

ENV PATH="/usr/local/cuda/bin:${PATH}"
ENV LD_LIBRARY_PATH="/usr/local/cuda/lib64:${LD_LIBRARY_PATH}"

##### nodos y smart-turn #####

WORKDIR /home/voice_ws/src

RUN git clone https://github.com/Cattyun-s/voisis.git && \
    git clone https://github.com/pipecat-ai/smart-turn.git

RUN mv /home/voice_ws/src/voisis/voisis_interfaces \
        /home/voice_ws/src

##### venv #####
WORKDIR /home/voice_ws

RUN python3 -m venv /opt/venv

ENV VIRTUAL_ENV=/opt/venv
ENV PATH="${VIRTUAL_ENV}/bin:${PATH}"

RUN python -m pip install --upgrade pip wheel \
    && python -m pip install "setuptools==75.8.2"

##### Python / ROS / audio dependencias #####

RUN python -m pip install --no-cache-dir \
        huggingface_hub \
        faster-whisper \
        sounddevice \
        pyaudio \
        catkin_pkg \
        Cython \
        lark \
        numpy \
        scipy \
        empy \
        soundfile

##### PyTorch CUDA #####

RUN python -m pip install --no-cache-dir \
        torch \
        torchaudio \
        torchvision

##### OmniVoice #####

RUN python -m pip install --no-cache-dir \
        omnivoice

##### verificar PyTorch y OmniVoice #####

RUN python - <<'PY'
import torch
from omnivoice import OmniVoice

print("PyTorch:", torch.__version__)
print("CUDA disponible:", torch.cuda.is_available())

if torch.cuda.is_available():
    print("GPU:", torch.cuda.get_device_name(0))

print("OmniVoice import OK")
PY

##### smart turn dependencias #####

RUN /opt/venv/bin/pip install --no-cache-dir \
        transformers \
        huggingface_hub \
        onnxruntime

##### smart turn v3.1 modelo #####

#repo github no tiene los onnx se tienen que instalar aparte
#esta parte es eso

RUN /opt/venv/bin/python - <<'PY'
from huggingface_hub import hf_hub_download
import os
import shutil

repo_id = "pipecat-ai/smart-turn-v3"
filename = "smart-turn-v3.1-cpu.onnx"

destination = "/home/voice_ws/src/smart-turn/smart-turn-v3.1.onnx"

print("========================================")
print("Downloading Smart Turn v3.1")
print("========================================")
print(f"Repository:  {repo_id}")
print(f"File:        {filename}")
print(f"Destination: {destination}")

model_path = hf_hub_download(
    repo_id=repo_id,
    filename=filename,
)

os.makedirs(os.path.dirname(destination), exist_ok=True)

shutil.copy2(model_path, destination)

size = os.path.getsize(destination)

print(f"Downloaded:  {size:,} bytes")

if size < 1_000_000:
    raise RuntimeError(
        f"Smart Turn model is suspiciously small: {size} bytes"
    )

print("Smart Turn model downloaded successfully.")
print("========================================")
PY

##### verificar modelo smart turn #####

RUN /opt/venv/bin/python - <<'PY'
import os
import onnxruntime as ort

path = "/home/voice_ws/src/smart-turn/smart-turn-v3.1.onnx"

print("========================================")
print("Verifying Smart Turn ONNX")
print("========================================")

if not os.path.isfile(path):
    raise RuntimeError(f"Smart Turn model does not exist: {path}")

size = os.path.getsize(path)

print(f"Model: {path}")
print(f"Size:  {size:,} bytes")

if size < 1_000_000:
    raise RuntimeError(
        f"Smart Turn model is invalid or incomplete: {size} bytes"
    )

session = ort.InferenceSession(path)

print("Smart Turn ONNX loaded successfully")
print("Inputs:", [x.name for x in session.get_inputs()])
print("Outputs:", [x.name for x in session.get_outputs()])

print("========================================")
print("SMART TURN OK")
print("========================================")
PY

##### FIN COSAS SMART TURN #####

##### CUDA 2 y llama-cpp #####


ENV CMAKE_ARGS="-DGGML_CUDA=ON -DGGML_NATIVE=OFF"
ENV FORCE_CMAKE=1

RUN /opt/venv/bin/python -m pip install --no-cache-dir \
        --upgrade \
        "scikit-build-core>=0.10" \
        ninja \
        cmake

RUN /opt/venv/bin/python -m pip install --no-cache-dir \
        --verbose \
        llama-cpp-python


##### verificar llama cpp #####

RUN /opt/venv/bin/python - <<'PY'
import sys
import importlib.util

print("========================================")
print("Verifying llama_cpp installation")
print("========================================")

print("Python:", sys.executable)

spec = importlib.util.find_spec("llama_cpp")

if spec is None:
    raise RuntimeError(
        "llama_cpp was not installed"
    )

print("llama_cpp found:")
print(spec.origin)

print("========================================")
print("LLAMA CPP PACKAGE INSTALLED")
print("GPU import test deferred to runtime")
print("========================================")
PY


WORKDIR /opt

RUN git clone https://github.com/ggml-org/llama.cpp.git

RUN cmake \
        -S /opt/llama.cpp \
        -B /opt/llama.cpp/build \
        -DGGML_CUDA=ON \
        -DGGML_NATIVE=OFF \
        -DCMAKE_EXE_LINKER_FLAGS="-L/usr/local/cuda/lib64/stubs -lcuda" \
        -DCMAKE_SHARED_LINKER_FLAGS="-L/usr/local/cuda/lib64/stubs -lcuda"

RUN cmake \
        --build /opt/llama.cpp/build \
        --config Release \
        -j2

ENV PATH="/opt/llama.cpp/build/bin:${PATH}"

##### modelo llm #####

WORKDIR /home/voice_ws/src/voisis/llama

RUN hf download \
        bartowski/Qwen2.5-3B-GGUF \
        --include "Qwen2.5-3B-Q4_K_M.gguf" \
        --local-dir /home/voice_ws/src/voisis/llama

##### build ws #####

WORKDIR /home/voice_ws

RUN rm -rf build install log

RUN /bin/bash -c "\
    source /opt/ros/jazzy/setup.bash && \
    source /opt/venv/bin/activate && \
    which python && \
    python --version && \
    python -c 'import sys; print(sys.executable)' && \
    colcon build \
        --symlink-install \
        --cmake-args \
            -DPython3_EXECUTABLE=/opt/venv/bin/python \
"


##### verificar entrypoints #####

RUN echo "========================================" && \
    echo "Checking ROS Python entrypoints" && \
    echo "========================================" && \
    head -n 1 /home/voice_ws/install/voisis/lib/voisis/BERT_Node && \
    head -n 1 /home/voice_ws/install/voisis/lib/voisis/Omni_Node && \
    head -n 1 /home/voice_ws/install/voisis/lib/voisis/smartVAD_Node && \
    head -n 1 /home/voice_ws/install/voisis/lib/voisis/whisper_Node


##### shell #####

RUN echo "source /opt/ros/jazzy/setup.bash" >> /root/.bashrc && \
    echo "source /opt/venv/bin/activate" >> /root/.bashrc && \
    echo "source /home/voice_ws/install/setup.bash" >> /root/.bashrc


##### cyclonedds y entrypoint #####

WORKDIR /home/voice_ws

COPY config/cyclonedds.xml /
COPY entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh


##### enviroment final #####
ENV PYTHONPATH="/home/voice_ws/install/voisis/lib/python3.12/site-packages:/opt/venv/lib/python3.12/site-packages:${PYTHONPATH}"

WORKDIR /home/voice_ws


ENTRYPOINT ["/entrypoint.sh"]

CMD ["bash"]
