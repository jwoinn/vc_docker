bash vc_docker/setup_host.bash

(inside vc_docker)

docker compose --profile base build voisis-base # una vez (la parte larga) 
docker compose up -d #compose corto, el que se hace siempre a menos que se cambien dependencias

docker exec -it voisis bash

# ============================================================
#  voisis con GPU, audio y volúmenes
#
#  Estructura esperada en el host (la crea docker/setup_host.sh):
#    voisis/
#    ├── docker/             <- este archivo y todo lo de Docker
#    ├── repos/voisis        <- git clone (tu código)
#    ├── repos/smart-turn    <- git clone
#    ├── workspace/          <- build/ install/ log/ de colcon
#    ├── models/             <- GGUF y ONNX (se descargan solos)
#    └── llama.cpp/          <- opcional, para build_llama_cpp
#
#  Las rutas relativas se resuelven desde docker/, por eso usan ../
#
#  Uso (desde docker/):
#    docker compose --profile base build voisis-base   # 1 vez (la parte larga)
#    docker compose run --rm voisis                    # siempre
#
#  Las opciones del build (arquitectura CUDA, etc.) se leen de .env,
#  que setup_host.sh crea detectando tu GPU.
# ============================================================