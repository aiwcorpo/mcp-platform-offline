# AGENTS.md

Offline packages of [MCP Platform](https://github.com/aiwcorpo/mcp-platform): zips of linux/amd64 Docker images for hosts
without registry access. The packages themselves are GitHub Release assets, built and published by a person. The repository
holds the scripts that build them (`scripts/`), the files that go into every package (`templates/`), `README.md` (what the
packages contain and where to get them) and `LICENSE`. It has no CI and no checks on pull requests, so every claim in the
README must be checked by hand against the release it describes.

## What a package contains

Two zips per release, `mcp-platform-<version>-offline.zip` and `mcp-servers-<version>-offline.zip`, plus a `SHA256SUMS` of
the zips. Inside each zip, under `<package>-<version>-offline/`:

- `images/`: one `docker save` tar per image, named after the image reference (`aiwcorpo_mcp-gateway_2.0.1.tar`,
  `keycloak_keycloak_26.8.1.tar`).
- `SHA256SUMS`: checksums of the files in `images/`.
- `load-images.sh` (bash) and `load-images.ps1` (PowerShell): verify the checksums, stop on a mismatch, then `docker load`.
  They never pull from the network.
- `README.md`: images and versions, then the install steps.
- Platform zip: `mcp-platform/`, the Compose bundle plus `compose.offline.yaml`. Servers zip: `servers/mcp-server-<system>/`,
  the `deploy/` directory of each server.

`compose.offline.yaml` lives in `templates/platform/` (it is not in the mcp-platform repository) and names the third-party images by tag because Docker Engine with the classic image store drops the registry
digest on `docker load`, and `compose.yaml` pins them by digest. Installs set `PULL_POLICY=never`. Keep both points in any README
or package change; the user docs in `mcp-docs` (`admin/install/offline.md`) describe the same steps.

## Commands

Build a package (needs Docker, git, zip; the component repositories are expected next to this one, or give `--src DIR`):

```bash
scripts/build-platform-package.sh --ref <tag or commit of mcp-platform> <version>
scripts/build-servers-package.sh [--ref <ref, default v<version>>] <version>
scripts/release-sums.sh               # SHA256SUMS of the zips in dist/
```

Output goes to `dist/` (ignored by git). The image list is read from `compose.yaml` of the bundle (platform) and from
`deploy/compose.yaml` of each server, with variable defaults resolved by `docker compose config --images`. Files come from
`git archive` of the given ref after `git fetch`, never from a working tree. The platform script refuses to run when
`templates/platform/compose.offline.yaml` and `compose.yaml` name different images.

- `--dry-run` builds everything except pulling and saving images: tree, README, image list, no zip. Use it to check a ref.
- `--local` takes the images from the local Docker for versions that are not published yet. Not for a release: the third-party
  images are then not the pinned digests.
- `--images-file FILE` replaces the image list, for a quick real run with one small image.
- Digest-pinned third-party images are pulled by digest and tagged `name:tag` in the local Docker before `docker save`, which
  moves a local tag of that name to the pinned digest.
- `--checked-on DATE` (platform) writes the "Checked on" line of the README. Pass it only after the package was loaded into a
  clean Docker Engine and the platform started from it; the scripts cannot check that.

To check a published release:

```bash
gh release list -R aiwcorpo/mcp-platform-offline
gh release download v2.0.1 -R aiwcorpo/mcp-platform-offline -D <empty dir>
shasum -a 256 -c SHA256SUMS          # sha256sum -c on Linux; the zips are about 1 GB each
```

## Releasing

The scripts stop short of everything that needs a person: publishing the images to ghcr.io first (the packages pull them from
there), choosing the refs, testing an install from the zip on a clean host, then `gh release create` with the zips and
`SHA256SUMS`, and updating the README table. Run the builds from a tag or commit, not from `origin/main`, so that the package
can be built again.

## Rules

- Images are linux/amd64 only. Do not add arm64 or multi-arch claims.
- aiwcorpo images come from `ghcr.io/aiwcorpo` at the released version. Third-party images (Keycloak, OpenBao, PostgreSQL,
  Redis, nginx, Eclipse Temurin) are pulled by the digests that `mcp-platform/compose.yaml` pins. Docker Hub is never a
  publish target for anything in this project.
- The README table (package names, contents, sizes) must match the latest release. When the platform and the servers are
  released at different versions, say which zip of which release to use, as the v2.0.1 release notes do.
- Never commit zips, image tars, `SHA256SUMS` of a package or anything extracted from one; they belong in releases only.
- Keep `templates/load-images.sh` and `.ps1` identical for both packages; their behaviour is described in the package README.

## Boundaries

Ask a person before: creating, editing or deleting a GitHub Release or its assets, pushing a tag, pushing to main, or pushing
images to any registry. Never commit secrets, `.env` files, internal host names or IP addresses.

## Pull requests

One change per PR, reviewed by a person since nothing runs automatically. Commit subject in English, imperative; the body says
why. Docs-only changes still need the README to match the published release.
