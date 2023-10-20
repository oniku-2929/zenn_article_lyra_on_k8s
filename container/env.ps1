$ENV_FILE = ""

if ($CONFIG -eq "Debug") {
    $ENV_FILE = ".env.debug"
}

if ($CONFIG -eq "Development") {
    $ENV_FILE = ".env.development"
}

if ($CONFIG -eq "Shipping") {
    $ENV_FILE = ".env.shipping"
}

if (-not $ENV_FILE) {
    Write-Host "Invalid config: $CONFIG, must be one of Debug, Development, Shipping"
}

echo "ENV_FILE is $ENV_FILE"
