#!/usr/bin/env bash
# Writes SHA256SUMS for the offline zips in a directory (the release assets) and checks the file it wrote.
# usage: scripts/release-sums.sh [dir]     (default: dist/)
set -euo pipefail
. "$(dirname "$0")/lib.sh"

dir=${1:-$ROOT/dist}
[ -d "$dir" ] || die "no such directory: $dir"
cd "$dir"
zips=$(ls mcp-platform-*-offline.zip mcp-servers-*-offline.zip 2>/dev/null | LC_ALL=C sort || true)
[ -n "$zips" ] || die "no mcp-*-offline.zip in $dir"
# shellcheck disable=SC2086
sha256 $zips > SHA256SUMS
sha256 -c SHA256SUMS
ok "$dir/SHA256SUMS"
