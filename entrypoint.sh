#!/usr/bin/env bash
# ============================================================
#  Entrypoint de voisis
#   1. Carga ROS 2, el venv y la config de CycloneDDS
#   2. Descarga los modelos a /models si faltan (solo la 1ª vez)
#   3. Los enlaza donde el código espera encontrarlos
#   4. Compila el workspace si nunca se compiló (o VOISIS_REBUILD=1)
#   5. Ejecuta el comando pedido (por defecto: bash)
# ============================================================
set -eo pipefail   # sin -u: los setup.bash de ROS usan variables no definidas

WS=/home/voice_ws
MODELS_DIR="${MODELS_DIR:-/models}"

LLM_REPO="${LLM_REPO:-bartowski/Qwen2.5-3B-GGUF}"
LLM_FILE="${LLM_FILE:-Qwen2.5-3B-Q4_K_M.gguf}"
SMART_TURN_REPO="${SMART_TURN_REPO:-pipecat-ai/smart-turn-v3}"
SMART_TURN_FILE="${SMART_TURN_FILE:-smart-turn-v3.1-cpu.onnx}"

# Dónde los buscan los nodos:
#  - BERT_Node:  .../src/voisis/llama/Qwen2.5-3B-Q4_K_M.gguf
#  - smart-turn: "smart-turn-v3.1.onnx" relativo al cwd (src/smart-turn, según el launch)
LLM_LINK="${LLM_LINK:-$WS/src/voisis/llama/$LLM_FILE}"
SMART_TURN_LINK="${SMART_TURN_LINK:-$WS/src/smart-turn/smart-turn-v3.1.onnx}"

export CYCLONEDDS_URI="${CYCLONEDDS_URI:-file:///cyclonedds.xml}"

log() { echo "[entrypoint] $*"; }

source /opt/ros/jazzy/setup.bash
source /opt/venv/bin/activate

# ---------- modelos ----------

file_size() { stat -c %s "$1" 2>/dev/null || echo 0; }

download_if_missing() {
    local repo="$1" file="$2" min_bytes="$3"
    local dest="$MODELS_DIR/$file"

    if (( $(file_size "$dest") >= min_bytes )); then
        return 0
    fi

    log "Descargando $repo / $file -> $MODELS_DIR"
    mkdir -p "$MODELS_DIR"
    hf download "$repo" "$file" --local-dir "$MODELS_DIR"

    local size
    size=$(file_size "$dest")
    if (( size < min_bytes )); then
        log "ERROR: $dest pesa $size bytes, parece incompleto"
        exit 1
    fi
    log "OK: $file ($size bytes)"
}

# Crea el enlace solo si el repo correspondiente está montado y
# no hay ya un archivo real en esa ruta.
link_model() {
    local target="$1" link="$2" repo_root="$3"

    [[ -d "$repo_root" ]] || return 0
    [[ -e "$link" && ! -L "$link" ]] && return 0

    mkdir -p "$(dirname "$link")"
    ln -sfn "$target" "$link"
}

if [[ "${SKIP_MODEL_DOWNLOAD:-0}" != "1" ]]; then
    download_if_missing "$LLM_REPO"        "$LLM_FILE"        100000000
    download_if_missing "$SMART_TURN_REPO" "$SMART_TURN_FILE" 1000000

    link_model "$MODELS_DIR/$LLM_FILE"        "$LLM_LINK"        "$WS/src/voisis"
    link_model "$MODELS_DIR/$SMART_TURN_FILE" "$SMART_TURN_LINK" "$WS/src/smart-turn"
fi

# Aviso si los .onnx del repo son punteros de Git LFS sin descargar
for f in "$WS/src/voisis/silero_vad.onnx" "$WS"/src/voisis/voices/*.onnx; do
    [[ -f "$f" ]] || continue
    if (( $(file_size "$f") < 1000 )) && grep -q "git-lfs" "$f" 2>/dev/null; then
        log "AVISO: $f es un puntero de Git LFS. En el host corre: git -C repos/voisis lfs pull"
    fi
done

# ---------- workspace ----------

if [[ -d "$WS/src/voisis" ]]; then
    if [[ "${VOISIS_REBUILD:-0}" == "1" || ! -f "$WS/install/setup.bash" ]]; then
        log "Compilando workspace..."
        (
            cd "$WS"
            colcon build \
                --symlink-install \
                --cmake-args -DPython3_EXECUTABLE=/opt/venv/bin/python
        )
    fi
else
    log "AVISO: $WS/src/voisis no está montado; no se compila el workspace"
fi

if [[ -f "$WS/install/setup.bash" ]]; then
    source "$WS/install/setup.bash"
fi

exec "$@"
