#!/usr/bin/env bash
# Checks the image files against SHA256SUMS and loads them into the local Docker. Nothing is pulled from the network.
set -euo pipefail
cd "$(dirname "$0")"

if command -v sha256sum >/dev/null 2>&1; then
  (cd images && sha256sum -c ../SHA256SUMS)
else
  (cd images && shasum -a 256 -c ../SHA256SUMS)
fi

for file in images/*.tar; do
  docker load -i "$file"
done
echo "ok    all images loaded"
