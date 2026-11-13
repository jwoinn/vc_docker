# syntax=docker/dockerfile:1.7
#
# ============================================================
#  voisis: capa liviana sobre voisis-base (se construye en segundos)
# ============================================================
#  Requiere haber construido antes voisis-base (ver Dockerfile.base).
#
#    docker compose build
#
#  El código (voisis, smart-turn) y los modelos NO están en la
#  imagen: se montan como volúmenes desde el host.
# ============================================================

ARG BASE_IMAGE=voisis-base:latest
FROM ${BASE_IMAGE}

COPY config/cyclonedds.xml /cyclonedds.xml
COPY entrypoint.sh /entrypoint.sh
COPY scripts/build_llama_cpp.sh /usr/local/bin/build_llama_cpp

RUN chmod +x /entrypoint.sh /usr/local/bin/build_llama_cpp

# Binarios de llama.cpp, si los compilas con build_llama_cpp
ENV PATH="/opt/llama.cpp/build/bin:${PATH}"

WORKDIR /home/voice_ws

ENTRYPOINT ["/entrypoint.sh"]
CMD ["bash"]
