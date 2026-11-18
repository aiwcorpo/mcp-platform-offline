# Shared by build-platform-package.sh and build-servers-package.sh. Sourced, not run. Needs bash 3.2 (macOS) or newer.

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
PLATFORM=linux/amd64

say()  { printf '%s\n' "$*"; }
ok()   { printf 'ok    %s\n' "$*"; }
warn() { printf 'warn  %s\n' "$*" >&2; }
die()  { printf 'error: %s\n' "$*" >&2; exit 1; }

need() { command -v "$1" >/dev/null 2>&1 || die "$1 is required"; }

if command -v sha256sum >/dev/null 2>&1; then
  sha256() { sha256sum "$@"; }
else
  sha256() { shasum -a 256 "$@"; }
fi

# Options both builders share. Sets the variables below; returns 0 when it consumed the option, 1 otherwise. $2 is the value.
SRC=$(dirname "$ROOT")
OUT="$ROOT/dist"
FETCH=1
LOCAL=0
DRY_RUN=0
FORCE=0
IMAGES_FILE=""
parse_common() {
  case "$1" in
    --src)         SRC=${2:?--src needs a directory}; return 0 ;;
    --out)         OUT=${2:?--out needs a directory}; return 0 ;;
    --images-file) IMAGES_FILE=${2:?--images-file needs a file}; return 0 ;;
    --no-fetch)    FETCH=0; return 2 ;;
    --local)       LOCAL=1; return 2 ;;
    --dry-run)     DRY_RUN=1; return 2 ;;
    --force)       FORCE=1; return 2 ;;
  esac
  return 1
}

# resolve_ref <repo> <ref>: prints the commit; fetches origin first unless --no-fetch.
resolve_ref() {
  local dir="$SRC/$1" sha
  [ -d "$dir/.git" ] || [ -f "$dir/.git" ] || die "$dir is not a git checkout (--src sets the directory that holds the component repositories)"
  if [ "$FETCH" = 1 ]; then git -C "$dir" fetch -q --tags origin || die "git fetch failed in $dir"; fi
  sha=$(git -C "$dir" rev-parse --verify --quiet "$2^{commit}") || die "$1: unknown ref $2"
  printf '%s\n' "$sha"
}

# export_tree <repo> <commit> <dest> [path]: the committed files, never the working tree of the checkout. With a path, its
# content goes straight into <dest>.
export_tree() {
  mkdir -p "$3"
  if [ -n "${4:-}" ]; then
    git -C "$SRC/$1" archive --format=tar "$2" "$4" | tar -x -C "$3" --strip-components=1
  else
    git -C "$SRC/$1" archive --format=tar "$2" | tar -x -C "$3"
  fi
}

# compose_images <project dir> <compose file>...: every image Compose would use, variable defaults resolved. "config" reads
# the files only, it neither talks to the registry nor creates a network. The dummy domain satisfies a required variable.
compose_images() {
  local dir="$1" f; local -a files=(); shift
  for f in "$@"; do files+=(-f "$dir/$f"); done
  env -u COMPOSE_FILE -u MCP_REGISTRY -u MCP_THIRD_PARTY_REGISTRY MCP_DOMAIN="${MCP_DOMAIN:-mcp.invalid}" \
    docker compose -p "offline-pkg-$$" --project-directory "$dir" "${files[@]}" --profile '*' config --images
}

strip_digest() { sed 's/@sha256:[0-9a-f]*$//'; }

# image_file <reference>: the image tag without registry host, "library/" and separators: aiwcorpo_mcp-gateway_2.0.1.tar.
image_file() {
  local ref
  ref=$(printf '%s' "${1%%@*}" | sed -e 's|^[^/]*[.:][^/]*/||' -e 's|^library/||' -e 's|[/:]|_|g')
  printf '%s.tar\n' "$ref"
}

read_images_file() {
  [ -f "$1" ] || die "no such file: $1"
  sed -e 's/#.*//' -e 's/[[:space:]]*$//' -e '/^$/d' "$1"
}

# save_images <list file> <images dir>: the list holds one reference per line, digest included where compose.yaml pins one.
# The tar carries the tag only (compose.offline.yaml names the images by tag), so a digest pull is tagged before saving.
save_images() {
  local ref tagref file os_arch old new
  while IFS= read -r ref; do
    tagref=${ref%%@*}
    file=$(image_file "$ref")
    if [ "$DRY_RUN" = 1 ]; then
      say "plan  images/$file  <-  $ref"
      continue
    fi
    if [ "$LOCAL" = 1 ]; then
      docker image inspect "$tagref" >/dev/null 2>&1 || die "no local image $tagref (--local uses images already in this Docker)"
    else
      say "pull  $ref"
      docker pull -q --platform "$PLATFORM" "$ref" >/dev/null || die "pull failed: $ref"
      if [ "$ref" != "$tagref" ]; then
        old=$(docker image inspect --format '{{.Id}}' "$tagref" 2>/dev/null || true)
        new=$(docker image inspect --format '{{.Id}}' "$ref")
        [ -z "$old" ] || [ "$old" = "$new" ] || say "retag $tagref moves from $old to $new"
        docker tag "$ref" "$tagref"
      fi
    fi
    # The containerd image store keeps every platform of a tag; without --platform inspect reports the host's.
    os_arch=$(docker image inspect --platform "$PLATFORM" --format '{{.Os}}/{{.Architecture}}' "$tagref" 2>/dev/null) ||
      os_arch=$(docker image inspect --format '{{.Os}}/{{.Architecture}}' "$tagref")
    [ "$os_arch" = "$PLATFORM" ] || die "$tagref is $os_arch, expected $PLATFORM"
    say "save  images/$file"
    if docker save --help 2>&1 | grep -q -- '--platform'; then
      docker save --platform "$PLATFORM" -o "$2/$file" "$tagref"
    else
      docker save -o "$2/$file" "$tagref"
    fi
    chmod 644 "$2/$file"
  done < "$1"
}

# image_rows <list file>: Markdown table rows, "| `registry/name` | tag |".
image_rows() {
  strip_digest < "$1" | sed -e 's/^\(.*\):\([^:/]*\)$/| `\1` | \2 |/'
}

write_sums() {
  (cd "$1" && for f in $(ls | LC_ALL=C sort); do sha256 "$f"; done) > "$2"
}

# render <template> <out>: replaces @VERSION@, @REF@, @IMAGE_COUNT@, @SERVERS_PACKAGE@, @PLATFORM_PACKAGE@, @NOTE@ inside a line from
# the environment variables of the same name, and a line holding only @IMAGE_ROWS@, @CHECKED@ or @PINNED_NOTE@ with the variable
# of that name. An empty block takes the following blank line with it.
render() {
  awk '
    function repl(s, key,   v, i) {
      v = ENVIRON[key]
      while ((i = index(s, "@" key "@")) > 0) s = substr(s, 1, i - 1) v substr(s, i + length(key) + 2)
      return s
    }
    BEGIN { n = split("VERSION REF IMAGE_COUNT SERVERS_PACKAGE PLATFORM_PACKAGE NOTE", keys, " ") }
    skip_blank { skip_blank = 0; if ($0 == "") next }
    /^@(IMAGE_ROWS|CHECKED|PINNED_NOTE)@$/ {
      v = ENVIRON[substr($0, 2, length($0) - 2)]
      if (v == "") skip_blank = 1; else print v
      next
    }
    { for (i = 1; i <= n; i++) $0 = repl($0, keys[i]); print }
  ' "$1" > "$2"
}

# prepare_stage <name>: an empty <out>/<name>; sets STAGE and ZIP.
prepare_stage() {
  mkdir -p "$OUT"
  STAGE="$OUT/$1"
  ZIP="$OUT/$1.zip"
  if [ -e "$STAGE" ] || [ -e "$ZIP" ]; then
    [ "$FORCE" = 1 ] || die "$STAGE or $ZIP exists (--force replaces it)"
    rm -rf "$STAGE" "$ZIP"
  fi
  mkdir -p "$STAGE/images"
}

# make_zip <name>: deflated. The classic image store saves layers uncompressed, and GitHub refuses release assets of 2 GiB or
# more; layers that are compressed already cost only the time of a deflate pass.
make_zip() {
  (cd "$OUT" && zip -qr -X -6 "$1.zip" "$1")
}

finish() {
  if [ "$DRY_RUN" = 1 ]; then
    ok "dry run: tree in $STAGE, no images saved, no SHA256SUMS, no zip"
    return
  fi
  write_sums "$STAGE/images" "$STAGE/SHA256SUMS"
  make_zip "$(basename "$STAGE")"
  ok "$ZIP ($(du -h "$ZIP" | cut -f1))"
}
