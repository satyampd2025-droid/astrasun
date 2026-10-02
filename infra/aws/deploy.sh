#!/usr/bin/env bash
# Deploys ERPNext + astrasun to AWS (CloudFormation + EKS).
# DRY RUN by default: prints what it would do. Add --apply to really create resources (costs money).
# Needs: aws, kubectl, docker, python3, and credentials for the target account.
#
#   ENV_NAME=astrasun REGION=ap-south-1 SITE_NAME=mill.example.com CERT_ARN=arn:aws:acm:... \
#   ./deploy.sh [--apply]
set -euo pipefail
cd "$(dirname "$0")"
ENV_NAME=${ENV_NAME:-astrasun}
REGION=${REGION:-ap-south-1}
SITE_NAME=${SITE_NAME:?set SITE_NAME, the domain users will open}
CERT_ARN=${CERT_ARN:?set CERT_ARN, an ACM certificate for that domain in the same region}
TAG=${TAG:-$(git rev-parse --short HEAD)}
APPLY=no; [ "${1:-}" = "--apply" ] && APPLY=yes

run() { echo "+ $*"; [ "$APPLY" = yes ] && "$@" || true; }
out() { aws cloudformation describe-stacks --region "$REGION" --stack-name "$ENV_NAME-$1" \
          --query "Stacks[0].Outputs[?OutputKey=='$2'].OutputValue" --output text; }
stack() {  # name template [extra params]
  run aws cloudformation deploy --region "$REGION" --stack-name "$ENV_NAME-$1" \
    --template-file "cloudformation/$2" --capabilities CAPABILITY_NAMED_IAM \
    --parameter-overrides EnvName="$ENV_NAME" "${@:3}"
}

[ "$APPLY" = yes ] || echo "DRY RUN: nothing will be created. Re-run with --apply to deploy."
./validate.sh

stack network 01-network.yaml
stack data 02-data.yaml
stack eks 03-eks.yaml

if [ "$APPLY" != yes ]; then
  echo "Dry run stops here: the steps below need the stacks to exist."
  echo "Next would be: build and push the image, create the secret, apply k8s/, wait for the setup job."
  exit 0
fi

ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
REPO=$(out data RepositoryUri)
aws ecr get-login-password --region "$REGION" | docker login --username AWS --password-stdin "${REPO%%/*}"
docker build -f ../../docker/Dockerfile -t "$REPO:$TAG" ../..
docker push "$REPO:$TAG"

aws eks update-kubeconfig --region "$REGION" --name "$ENV_NAME"
kubectl apply -f - <<< '{"apiVersion":"v1","kind":"Namespace","metadata":{"name":"astrasun"}}'
DB_PASS=$(aws secretsmanager get-secret-value --region "$REGION" --secret-id "$(out data DbSecretArn)" --query SecretString --output text | python3 -c 'import json,sys;print(json.load(sys.stdin)["password"])')
ADMIN_PASS=$(aws secretsmanager get-secret-value --region "$REGION" --secret-id "$(out data AdminSecretArn)" --query SecretString --output text)
kubectl -n astrasun create secret generic astrasun-secrets \
  --from-literal=DB_ROOT_PASSWORD="$DB_PASS" --from-literal=ADMIN_PASSWORD="$ADMIN_PASS" \
  --dry-run=client -o yaml | kubectl apply -f -

export IMAGE="$REPO:$TAG" SITE_NAME CERT_ARN \
  DB_HOST=$(out data DbEndpoint) REDIS_CACHE=$(out data RedisCacheEndpoint) REDIS_QUEUE=$(out data RedisQueueEndpoint) \
  EFS_ID=$(out data FileSystemId) EFS_ACCESS_POINT=$(out data SitesAccessPointId)
kubectl -n astrasun delete job astrasun-setup --ignore-not-found
./render.sh | kubectl apply -f -
kubectl -n astrasun wait --for=condition=complete job/astrasun-setup --timeout=30m
kubectl -n astrasun rollout status deploy/backend deploy/frontend --timeout=10m
echo "Load balancer address (point your domain's CNAME here):"
kubectl -n astrasun get svc frontend -o jsonpath='{.status.loadBalancer.ingress[0].hostname}{"\n"}'
echo "Admin password is in Secrets Manager: $(out data AdminSecretArn)"
