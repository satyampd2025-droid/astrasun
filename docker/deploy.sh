#!/usr/bin/env bash
# Update the running server to the latest code. Safe to run any time.
set -euo pipefail
cd "$(dirname "$0")/.."
BRANCH=${BRANCH:-$(git rev-parse --abbrev-ref HEAD)}
git fetch origin "$BRANCH" && git reset --hard "origin/$BRANCH"
docker build -f docker/Dockerfile -t astrasun:dev .
cd docker
C="docker compose -f compose.yml -f compose.prod.yml"
# Managed database (AWS RDS): use it instead of the local db container
grep -q ^DB_HOST= .env && C="$C -f compose.rds.yml"
$C up -d
# Wait until create-site has finished (first run creates the site and its database user).
# Checking only for the site folder raced: the folder appears before the database user exists.
if ! $C wait create-site >/dev/null; then $C logs --tail 50 create-site; exit 1; fi
$C exec -T backend bench --site "$(grep ^SITE_NAME .env | cut -d= -f2)" migrate
docker image prune -f >/dev/null
