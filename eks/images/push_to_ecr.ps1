$CONFIG = $args[0]
. ..\..\container\env.ps1

. ..\..\read_env_file.ps1
ReadEnvFile "..\..\container\config\$ENV_FILE"

$AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text)
$REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.ap-northeast-1.amazonaws.com"
$IMAGE="lyra-on-k8s-agones"
$TAG=$env:TAG

aws ecr get-login-password --region ap-northeast-1 | docker login --username AWS --password-stdin $REGISTRY

docker tag "${IMAGE}:${TAG}" "${REGISTRY}/${IMAGE}:${TAG}"
docker push "${REGISTRY}/${IMAGE}:${TAG}"
