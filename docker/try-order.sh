#!/usr/bin/env bash
# Tries the order the phone sends ("Send for approval") on this server and prints the server's own
# reason if it is refused. Nothing is saved: every try is rolled back.
#   cd /opt/astrasun && git pull && bash docker/try-order.sh              first customer, first priced item
#   bash docker/try-order.sh "Customer name"                              a particular customer
set -euo pipefail
cd "$(dirname "$0")"
C="docker compose -f compose.yml -f compose.prod.yml"
grep -q ^DB_HOST= .env && C="$C -f compose.rds.yml"
SITE=$(grep ^SITE_NAME .env | cut -d= -f2)
$C exec -T -e SITE="$SITE" -e CUSTOMER="${1:-}" backend bash -c 'cd sites && ../env/bin/python -' < try_order.py
