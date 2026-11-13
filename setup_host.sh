#!/usr/bin/env bash
# ============================================================
#  Prepara las carpetas del host para docker-compose.yml.
#  Se corre una vez:  bash <carpeta_docker>/setup_host.sh
#  La carpeta de Docker puede llamarse como quieras (docker/, vc_docker/...).
#  Crea repos/, workspace/, models/ y llama.cpp/ JUNTO a ella, no dentro.
# ============================================================
set -euo pipefail

DOCKER_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(dirname "$DOCKER_DIR")"
ENV_FILE="$DOCKER_DIR/.env"
cd "$ROOT_DIR"

mkdir -p repos workspace/src models llama.cpp

if ! command -v git-lfs >/dev/null 2>&1; then
    echo "AVISO: git-lfs no está instalado. Los .onnx de voisis (voces, silero) son LFS."
    echo "       Instálalo con: sudo apt install git-lfs"
fi

# Clona solo si la carpeta no existe: si ya tienes tu propia copia, no se toca.
if [[ ! -d repos/voisis ]]; then
    git clone https://github.com/Cattyun-s/voisis.git repos/voisis
fi
if [[ -d repos/voisis/.git ]]; then
    git -C repos/voisis lfs pull || true
fi

if [[ ! -d repos/smart-turn ]]; then
    git clone https://github.com/pipecat-ai/smart-turn.git repos/smart-turn
fi

# smart-turn no es un paquete ROS: que colcon no entre ahí
# (tiene subcarpetas con pyproject.toml que podría intentar compilar)
touch repos/smart-turn/COLCON_IGNORE

# Los modelos se enlazan dentro de los repos: que git los ignore
# (exclude local, no modifica los repos)
add_exclude() {
    local repo="$1" pattern="$2"
    [[ -d "$repo/.git" ]] || return 0
    local file="$repo/.git/info/exclude"
    grep -qxF "$pattern" "$file" 2>/dev/null || echo "$pattern" >> "$file"
}
add_exclude repos/voisis      "llama/*.gguf"
add_exclude repos/smart-turn  "*.onnx"
add_exclude repos/smart-turn  "COLCON_IGNORE"

# Revisa que los .onnx de voisis no sean punteros de Git LFS
for f in repos/voisis/voices/*.onnx repos/voisis/silero_vad.onnx; do
    [[ -f "$f" ]] || continue
    if (( $(stat -c %s "$f") < 1000 )); then
        echo "AVISO: $f pesa menos de 1 KB: es un puntero de Git LFS, no el modelo."
    fi
done

# Detecta la arquitectura de la GPU y la guarda en .env
# (ej: compute_cap 8.9 -> CUDA_ARCHITECTURES="89"). No pisa un valor existente.
touch "$ENV_FILE"
if grep -q '^CUDA_ARCHITECTURES=' "$ENV_FILE"; then
    echo "CUDA_ARCHITECTURES ya definido en $ENV_FILE: $(grep '^CUDA_ARCHITECTURES=' "$ENV_FILE")"
elif command -v nvidia-smi >/dev/null 2>&1; then
    arch=$(nvidia-smi --query-gpu=compute_cap --format=csv,noheader \
           | tr -d ' .' | sort -u | paste -sd ';' -)
    if [[ -n "$arch" ]]; then
        echo "CUDA_ARCHITECTURES=\"$arch\"" >> "$ENV_FILE"
        echo "GPU detectada: CUDA_ARCHITECTURES=$arch (guardado en $ENV_FILE)"
    fi
else
    echo "AVISO: no se encontró nvidia-smi; se compilará para varias GPUs (más lento)."
    echo "       Puedes fijarlo a mano en $ENV_FILE, ej: CUDA_ARCHITECTURES=\"89\""
fi

echo
echo "Listo. Siguientes pasos:"
echo "  cd $DOCKER_DIR"
echo "  docker compose --profile base build voisis-base   # una vez, demora"
echo "  docker compose run --rm voisis"#!/usr/bin/env bash
# ============================================================
#  Prepara las carpetas del host para docker-compose.yml.
#  Se corre una vez:  bash <carpeta_docker>/setup_host.sh
#  La carpeta de Docker puede llamarse como quieras (docker/, vc_docker/...).
#  Crea repos/, workspace/, models/ y llama.cpp/ JUNTO a ella, no dentro.
# ============================================================
set -euo pipefail

DOCKER_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(dirname "$DOCKER_DIR")"
ENV_FILE="$DOCKER_DIR/.env"
cd "$ROOT_DIR"

mkdir -p repos workspace/src models llama.cpp

if ! command -v git-lfs >/dev/null 2>&1; then
    echo "AVISO: git-lfs no está instalado. Los .onnx de voisis (voces, silero) son LFS."
    echo "       Instálalo con: sudo apt install git-lfs"
fi

# Clona solo si la carpeta no existe: si ya tienes tu propia copia, no se toca.
if [[ ! -d repos/voisis ]]; then
    git clone https://github.com/Cattyun-s/voisis.git repos/voisis
fi
if [[ -d repos/voisis/.git ]]; then
    git -C repos/voisis lfs pull || true
fi

if [[ ! -d repos/smart-turn ]]; then
    git clone https://github.com/pipecat-ai/smart-turn.git repos/smart-turn
fi

# smart-turn no es un paquete ROS: que colcon no entre ahí
# (tiene subcarpetas con pyproject.toml que podría intentar compilar)
touch repos/smart-turn/COLCON_IGNORE

# Los modelos se enlazan dentro de los repos: que git los ignore
# (exclude local, no modifica los repos)
add_exclude() {
    local repo="$1" pattern="$2"
    [[ -d "$repo/.git" ]] || return 0
    local file="$repo/.git/info/exclude"
    grep -qxF "$pattern" "$file" 2>/dev/null || echo "$pattern" >> "$file"
}
add_exclude repos/voisis      "llama/*.gguf"
add_exclude repos/smart-turn  "*.onnx"
add_exclude repos/smart-turn  "COLCON_IGNORE"

# Revisa que los .onnx de voisis no sean punteros de Git LFS
for f in repos/voisis/voices/*.onnx repos/voisis/silero_vad.onnx; do
    [[ -f "$f" ]] || continue
    if (( $(stat -c %s "$f") < 1000 )); then
        echo "AVISO: $f pesa menos de 1 KB: es un puntero de Git LFS, no el modelo."
    fi
done

# Detecta la arquitectura de la GPU y la guarda en .env
# (ej: compute_cap 8.9 -> CUDA_ARCHITECTURES="89"). No pisa un valor existente.
touch "$ENV_FILE"
if grep -q '^CUDA_ARCHITECTURES=' "$ENV_FILE"; then
    echo "CUDA_ARCHITECTURES ya definido en $ENV_FILE: $(grep '^CUDA_ARCHITECTURES=' "$ENV_FILE")"
elif command -v nvidia-smi >/dev/null 2>&1; then
    arch=$(nvidia-smi --query-gpu=compute_cap --format=csv,noheader \
           | tr -d ' .' | sort -u | paste -sd ';' -)
    if [[ -n "$arch" ]]; then
        echo "CUDA_ARCHITECTURES=\"$arch\"" >> "$ENV_FILE"
        echo "GPU detectada: CUDA_ARCHITECTURES=$arch (guardado en $ENV_FILE)"
    fi
else
    echo "AVISO: no se encontró nvidia-smi; se compilará para varias GPUs (más lento)."
    echo "       Puedes fijarlo a mano en $ENV_FILE, ej: CUDA_ARCHITECTURES=\"89\""
fi

echo
echo "Listo. Siguientes pasos:"
echo "  cd $DOCKER_DIR"
echo "  docker compose --profile base build voisis-base   # una vez, demora"
echo "  docker compose run --rm voisis"