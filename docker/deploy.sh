#!/usr/bin/env bash
# Update the running server to the latest code. Safe to run any time.
set -euo pipefail
cd "$(dirname "$0")/.."
BRANCH=${BRANCH:-$(git rev-parse --abbrev-ref HEAD)}
git fetch origin "$BRANCH" && git reset --hard "origin/$BRANCH"
docker build -f docker/Dockerfile -t astrasun:dev .
cd docker
C="docker compose -f compose.yml -f compose.prod.yml"
$C up -d
# Wait for the site to exist (first run creates it), then apply updates
until $C exec -T backend test -d "sites/$(grep ^SITE_NAME .env | cut -d= -f2)"; do sleep 5; done
$C exec -T backend bench --site "$(grep ^SITE_NAME .env | cut -d= -f2)" migrate
docker image prune -f >/dev/null
