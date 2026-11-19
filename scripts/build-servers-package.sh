#!/usr/bin/env bash
# Builds mcp-servers-<version>-offline.zip: the images of the MCP servers (linux/amd64, docker save), their checksums, the load
# scripts, the package README and the deploy/ directory of every server, the adapter's included, from one git ref.
set -euo pipefail
. "$(dirname "$0")/lib.sh"

usage() {
  cat <<'USAGE'
usage: scripts/build-servers-package.sh [options] <version>

  --ref REF            git ref taken in every server repository (default v<version>)
  --ref-for REPO=REF   take REF in this one repository instead (repeatable), for a server released at another version
  --src DIR            directory with the component repositories (default: the parent of this repository)
  --out DIR            where the package directory and the zip go (default: dist/)
  --images-file FILE   save these images (one reference per line) instead of the ones the deploy/compose.yaml files name
  --local              use the images already in the local Docker instead of pulling them (unpublished versions)
  --dry-run            build the tree, print the images that would be saved, pull and save nothing, write no zip
  --no-fetch           do not run git fetch in the component repositories
  --force              replace an existing package directory and zip in --out
  --platform-package N file name of the platform zip the README names (default mcp-platform-<version>-offline.zip)

The image versions are the defaults in each deploy/compose.yaml at REF (MCP_<SYSTEM>_VERSION in the environment overrides
them, for a version that is not in the file yet).
USAGE
}

SERVERS="gitlab jira confluence opensearch servicedesk adapter"
REF=""
REF_FOR=""
PLATFORM_PACKAGE=""
VERSION=""
while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --ref) REF=${2:?--ref needs a value}; shift 2 ;;
    --ref-for) case "${2:-}" in mcp-server-?*=?*) REF_FOR="$REF_FOR $2" ;; *) die "--ref-for needs mcp-server-<system>=<ref>" ;; esac
               shift 2 ;;
    --platform-package) PLATFORM_PACKAGE=${2:?}; shift 2 ;;
    -*) rc=0; parse_common "$1" "${2:-}" || rc=$?
        case $rc in 0) shift 2 ;; 2) shift ;; *) usage >&2; die "unknown option $1" ;; esac ;;
    *) [ -z "$VERSION" ] || die "one version only"; VERSION=$1; shift ;;
  esac
done
[ -n "$VERSION" ] || { usage >&2; exit 2; }
case "$VERSION" in *[!0-9A-Za-z._-]*|'') die "bad version: $VERSION" ;; esac
[ -n "$REF" ] || REF="v$VERSION"
[ -n "$PLATFORM_PACKAGE" ] || PLATFORM_PACKAGE="mcp-platform-$VERSION-offline.zip"

ref_of() {
  local entry ref=$REF
  for entry in $REF_FOR; do [ "${entry%%=*}" = "$1" ] && ref=${entry#*=}; done
  printf '%s\n' "$ref"
}
for entry in $REF_FOR; do
  repo=${entry%%=*}
  case " $SERVERS " in *" ${repo#mcp-server-} "*) ;; *) die "--ref-for: $repo is not one of the servers" ;; esac
done

need git; need tar; need docker; need zip
NAME="mcp-servers-$VERSION-offline"
prepare_stage "$NAME"
LIST="$STAGE/.images"
: > "$LIST"

for s in $SERVERS; do
  repo="mcp-server-$s"
  ref=$(ref_of "$repo")
  sha=$(resolve_ref "$repo" "$ref")
  say "$repo $ref = $sha"
  export_tree "$repo" "$sha" "$STAGE/servers/$repo" deploy
  [ -f "$STAGE/servers/$repo/compose.yaml" ] || die "$repo has no deploy/compose.yaml at $ref"
  compose_images "$STAGE/servers/$repo" compose.yaml >> "$LIST"
done
LC_ALL=C sort -u "$LIST" > "$LIST.sorted"
mv "$LIST.sorted" "$LIST"
if [ -n "$IMAGES_FILE" ]; then
  read_images_file "$IMAGES_FILE" > "$LIST"
  warn "images come from $IMAGES_FILE, not from the compose files: not a complete package"
fi
[ -s "$LIST" ] || die "no images"
say "images: $(wc -l < "$LIST" | tr -d ' ')"

save_images "$LIST" "$STAGE/images"

cp "$ROOT/templates/load-images.sh" "$ROOT/templates/load-images.ps1" "$STAGE/"
for entry in $REF_FOR; do REF="$REF, ${entry%%=*} at ${entry#*=}"; done
export VERSION REF PLATFORM_PACKAGE IMAGE_COUNT IMAGE_ROWS
IMAGE_COUNT=$(wc -l < "$LIST" | tr -d ' ')
IMAGE_ROWS=$(image_rows "$LIST")
[ "$LOCAL" = 0 ] || warn "--local: for testing, do not publish"
render "$ROOT/templates/servers/README.md" "$STAGE/README.md"

rm -f "$LIST"
finish
