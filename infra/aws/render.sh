#!/usr/bin/env bash
# Prints the Kubernetes manifests with ${VARS} filled from the environment.
set -euo pipefail
cd "$(dirname "$0")/k8s"
if command -v kustomize >/dev/null; then kustomize build .; else kubectl kustomize .; fi |
python3 -c '
import os,re,sys
t=sys.stdin.read()
def sub(m):
    k=m.group(1)
    if k not in os.environ: sys.exit("missing variable: "+k)
    return os.environ[k]
sys.stdout.write(re.sub(r"\$\{([A-Z_]+)\}",sub,t))'
