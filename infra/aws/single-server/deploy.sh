#!/usr/bin/env bash
# Deploy one self-contained environment (test or prod). Run once per environment.
# DRY RUN by default: checks the template and prints the command. Add --apply to really create it (costs money).
#
#   ./deploy.sh test mill-test.example.com            # dry run
#   ./deploy.sh prod mill.example.com --apply
# Test and prod use the same sizes on purpose (test must match prod).
# On the AWS Free plan use DB_BACKUP_DAYS=1 (and DB_INSTANCE_CLASS=db.t4g.micro if the size is refused).
# Optional: REGION (default ap-southeast-2, the only region this AWS account allows), INSTANCE_TYPE, GITHUB_TOKEN_SECRET_ARN, AWS_PROFILE (use a different
# profile, or a different AWS account, for each environment if you want the strongest separation).
set -euo pipefail
cd "$(dirname "$0")"
ENV_NAME=${1:?usage: deploy.sh test|prod <domain> [--apply]}
DOMAIN=${2:?usage: deploy.sh test|prod <domain> [--apply]}
REGION=${REGION:-ap-southeast-2}
case "$ENV_NAME" in
  prod) TYPE=${INSTANCE_TYPE:-c7i-flex.large}; CIDR=10.20.0.0/24 ;;
  test) TYPE=${INSTANCE_TYPE:-c7i-flex.large};  CIDR=10.21.0.0/24 ;;
  *) echo "first argument must be test or prod"; exit 1 ;;
esac
APPLY=no; [ "${3:-}" = "--apply" ] && APPLY=yes

cfn-lint server.yaml
CMD=(aws cloudformation deploy --region "$REGION" --stack-name "astrasun-$ENV_NAME" --template-file server.yaml
  --capabilities CAPABILITY_IAM
  --parameter-overrides EnvName="$ENV_NAME" DomainName="$DOMAIN" InstanceType="$TYPE" VpcCidr="$CIDR"
  GitHubTokenSecretArn="${GITHUB_TOKEN_SECRET_ARN:-}"
  DbBackupDays="${DB_BACKUP_DAYS:-7}" DbInstanceClass="${DB_INSTANCE_CLASS:-db.t4g.small}")
echo "+ ${CMD[*]}"
if [ "$APPLY" != yes ]; then echo "DRY RUN: nothing created. Add --apply to deploy."; exit 0; fi
"${CMD[@]}"
aws cloudformation describe-stacks --region "$REGION" --stack-name "astrasun-$ENV_NAME" --query 'Stacks[0].Outputs' --output table
echo "Next: point a DNS A record for $DOMAIN at ServerAddress. The site is ready about 15 minutes after the stack finishes."
