#!/usr/bin/env bash
# Offline checks only. Touches nothing in AWS. Needs cfn-lint, kustomize (or kubectl) and kubeconform.
set -euo pipefail
cd "$(dirname "$0")"
cfn-lint cloudformation/*.yaml
echo "CloudFormation templates: OK"
IMAGE=x/y:1 SITE_NAME=mill.example.com DB_HOST=db.example REDIS_CACHE=c.example REDIS_QUEUE=q.example \
EFS_ID=fs-1 EFS_ACCESS_POINT=fsap-1 CERT_ARN=arn:aws:acm:ap-south-1:1:certificate/x \
  ./render.sh | kubeconform -strict -summary
