$CONFIG = $args[0]
. .\env.ps1

docker compose --env-file ./config/$ENV_FILE up
