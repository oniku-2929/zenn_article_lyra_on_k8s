Push-Location (Get-Item -Path "." -Verbose).DirectoryName

$CONFIG = $args[0]
. .\env.ps1

if (-not $ENV_FILE) {
    echo "ENV_FILE is must be set, check env.ps1"
    exit 1
}

. ..\read_env_file.ps1
ReadEnvFile ".\config\$ENV_FILE"

if (-not $env:PACKAGE_DIR) {
    echo "PACKAGE_DIR is must be set, check config/$ENV_FILE"
    exit 1
}

if (-not (Test-Path .\build)) {
    New-Item -Path .\build -ItemType Directory
}

echo "package location is $env:UE_ENGINE_ROOT/LyraStarterGame/Package/$env:PACKAGE_DIR"
Copy-Item -Path ./.linux.Dockerfile -Destination ./build/Dockerfile -Force
Copy-Item -Path ./config -Destination ./build -Recurse -Force
Copy-Item -Path $env:UE_ENGINE_ROOT/LyraStarterGame/Package/$env:PACKAGE_DIR -Destination ./build -Recurse -Force

$env:DOCKER_BUILDKIT = 1
docker compose --env-file ./config/$ENV_FILE build

Pop-Location
