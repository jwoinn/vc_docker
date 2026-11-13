bash vc_docker/setup_host.bash

(inside vc_docker)

docker compose --profile base build voisis-base # una vez (la parte larga) 
docker compose up -d #compose corto, el que se hace siempre a menos que se cambien dependencias

docker exec -it voisis bash