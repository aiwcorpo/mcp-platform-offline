#!/usr/bin/env bash
# Builds mcp-platform-<version>-offline.zip: the images of the platform's Compose bundle (linux/amd64, docker save), their
# checksums, the load scripts, the package README and the bundle taken from a git ref of mcp-platform.
set -euo pipefail
. "$(dirname "$0")/lib.sh"

usage() {
  cat <<'USAGE'
usage: scripts/build-platform-package.sh [options] <version>

  --ref REF            git ref of mcp-platform to take the bundle from (default origin/main); a tag or a commit for a release
  --src DIR            directory with the component repositories (default: the parent of this repository)
  --out DIR            where the package directory and the zip go (default: dist/)
  --images-file FILE   save these images (one reference per line) instead of the ones compose.yaml names
  --local              use the images already in the local Docker instead of pulling them (unpublished versions; the
                       third-party images then are not the pinned digests, and the README says nothing about it)
  --dry-run            build the tree, print the images that would be saved, pull and save nothing, write no zip
  --no-fetch           do not run git fetch in the component repository
  --force              replace an existing package directory and zip in --out
  --servers-package N  file name of the servers zip the README names (default mcp-servers-<version>-offline.zip)
  --note TEXT          sentence appended to the first paragraph of the README
  --checked-on DATE    add the line "Checked on DATE: ..." to the README; only after the package really was tested

The image versions are the defaults in compose.yaml at REF. To package a version that compose.yaml does not name yet, set
MCP_GATEWAY_VERSION, MCP_BROKER_VERSION or MCP_PORTAL_VERSION in the environment.
USAGE
}

REF=origin/main
SERVERS_PACKAGE=""
NOTE=""
CHECKED_ON=""
VERSION=""
while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --ref) REF=${2:?--ref needs a value}; shift 2 ;;
    --servers-package) SERVERS_PACKAGE=${2:?}; shift 2 ;;
    --note) NOTE=${2:?}; shift 2 ;;
    --checked-on) CHECKED_ON=${2:?}; shift 2 ;;
    -*) rc=0; parse_common "$1" "${2:-}" || rc=$?
        case $rc in 0) shift 2 ;; 2) shift ;; *) usage >&2; die "unknown option $1" ;; esac ;;
    *) [ -z "$VERSION" ] || die "one version only"; VERSION=$1; shift ;;
  esac
done
[ -n "$VERSION" ] || { usage >&2; exit 2; }
case "$VERSION" in *[!0-9A-Za-z._-]*|'') die "bad version: $VERSION" ;; esac
[ -n "$SERVERS_PACKAGE" ] || SERVERS_PACKAGE="mcp-servers-$VERSION-offline.zip"

need git; need tar; need docker; need zip
NAME="mcp-platform-$VERSION-offline"
SHA=$(resolve_ref mcp-platform "$REF")
say "mcp-platform $REF = $SHA"

prepare_stage "$NAME"
BUNDLE="$STAGE/mcp-platform"
export_tree mcp-platform "$SHA" "$BUNDLE"
# What a person running the platform does not need. LICENSE and NOTICE stay: the package redistributes Apache-2.0 software.
(cd "$BUNDLE" && rm -rf .github AGENTS.md CLAUDE.md SECURITY.md CONTRIBUTING.md scripts)
if [ -f "$BUNDLE/compose.offline.yaml" ]; then
  say "compose.offline.yaml: from mcp-platform $REF"
else
  cp "$ROOT/templates/platform/compose.offline.yaml" "$BUNDLE/compose.offline.yaml"
  say "note  mcp-platform $REF has no compose.offline.yaml: using templates/platform/compose.offline.yaml"
fi

LIST="$STAGE/.images"
if [ -n "$IMAGES_FILE" ]; then
  read_images_file "$IMAGES_FILE" > "$LIST"
  warn "images come from $IMAGES_FILE, not from compose.yaml: not a complete package"
else
  compose_images "$BUNDLE" compose.yaml | LC_ALL=C sort -u > "$LIST"
fi
[ -s "$LIST" ] || die "no images"

# compose.offline.yaml must name exactly the images compose.yaml does, or an offline install pulls something that is not loaded.
strip_digest < "$LIST" > "$STAGE/.compose"
compose_images "$BUNDLE" compose.yaml compose.offline.yaml | LC_ALL=C sort -u > "$STAGE/.offline"
if [ -z "$IMAGES_FILE" ] && ! diff "$STAGE/.compose" "$STAGE/.offline" >/dev/null; then
  diff "$STAGE/.compose" "$STAGE/.offline" >&2 || true
  die "compose.offline.yaml does not match compose.yaml at $REF (lines marked < are only in compose.yaml)"
fi
say "images: $(wc -l < "$LIST" | tr -d ' ')"

save_images "$LIST" "$STAGE/images"

cp "$ROOT/templates/load-images.sh" "$ROOT/templates/load-images.ps1" "$STAGE/"
export VERSION IMAGE_COUNT NOTE SERVERS_PACKAGE
IMAGE_COUNT=$(wc -l < "$LIST" | tr -d ' ')
[ -z "$NOTE" ] || NOTE=" $NOTE"
export IMAGE_ROWS CHECKED PINNED_NOTE
IMAGE_ROWS=$(image_rows "$LIST")
CHECKED=""
[ -z "$CHECKED_ON" ] || CHECKED="Checked on $CHECKED_ON: the images loaded into a clean Docker Engine (classic image store, no registry access) and the whole
platform started from them, every service healthy."
PINNED_NOTE="The third-party images were pulled by the digests that \`mcp-platform/compose.yaml\` pins."
if [ "$LOCAL" = 1 ]; then PINNED_NOTE=""; warn "--local: for testing, do not publish"; fi
render "$ROOT/templates/platform/README.md" "$STAGE/README.md"

rm -f "$STAGE/.images" "$STAGE/.compose" "$STAGE/.offline"
finish
