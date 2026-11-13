#!/usr/bin/env bash
# ============================================================
#  Compila los binarios de llama.cpp DENTRO del container.
#  Opcional: los nodos usan llama-cpp-python y no necesitan esto.
#
#  Uso:
#    build_llama_cpp                      # llama-server y llama-cli
#    build_llama_cpp llama-bench          # targets a elección
#    JOBS=8 build_llama_cpp
#
#  /opt/llama.cpp es un volumen, así que se compila una sola vez
#  y sobrevive aunque recrees el container.
# ============================================================
set -euo pipefail

SRC=/opt/llama.cpp
JOBS="${JOBS:-4}"

if (( $# )); then
    targets=("$@")
else
    targets=(llama-server llama-cli)
fi

if [[ ! -d "$SRC/.git" ]]; then
    git clone --depth 1 https://github.com/ggml-org/llama.cpp.git "$SRC"
fi

# Aquí sí hay GPU, así que "native" compila solo para la tuya.
cmake -S "$SRC" -B "$SRC/build" -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DGGML_CUDA=ON \
    -DGGML_NATIVE=ON \
    -DCMAKE_CUDA_ARCHITECTURES="${CUDA_ARCHITECTURES:-native}" \
    -DLLAMA_CURL=OFF \
    -DLLAMA_BUILD_TESTS=OFF \
    -DLLAMA_BUILD_EXAMPLES=OFF

cmake --build "$SRC/build" --config Release --target "${targets[@]}" -j "$JOBS"

echo "Listo. Binarios en $SRC/build/bin (ya están en el PATH)."
