#!/usr/bin/env bash
# What a browser gets for the India Compliance script from the stack on localhost:8080:
# which script URLs the desk page asks for, and whether each one is served.
set -uo pipefail
cj=$(mktemp)
curl -fsS -c "$cj" -X POST -d "usr=Administrator&pwd=${ADMIN_PASSWORD:?}" http://localhost:8080/api/method/login >/dev/null || echo "login failed"
html=$(curl -fsS -b "$cj" http://localhost:8080/app || true)
urls=$(printf '%s' "$html" | grep -oE '[^"'"'"' ]*india_compliance[^"'"'"' ]*\.js' | sort -u)
if [ -z "$urls" ]; then echo "the desk page does not mention any india_compliance script"; fi
for u in $urls; do
  printf '%s -> ' "$u"
  curl -s -b "$cj" -o /dev/null -w '%{http_code} %{content_type} %{size_download} bytes\n' "http://localhost:8080$u"
done
rm -f "$cj"
