# AGENTS.md

Offline packages of [MCP Platform](https://github.com/aiwcorpo/mcp-platform): zips of linux/amd64 Docker images for hosts
without registry access. The packages themselves are GitHub Release assets, built and published by a person. The repository
holds only `README.md` (what the packages contain and where to get them) and `LICENSE`. It has no build script, no CI and no
checks on pull requests, so every claim in the README must be checked by hand against the release it describes.

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

`compose.offline.yaml` names the third-party images by tag because Docker Engine with the classic image store drops the registry
digest on `docker load`, and `compose.yaml` pins them by digest. Installs set `PULL_POLICY=never`. Keep both points in any README
or package change; the user docs in `mcp-docs` (`admin/install/offline.md`) describe the same steps.

## Commands

Nothing to build or test in the repository. To check a published release:

```bash
gh release list -R aiwcorpo/mcp-platform-offline
gh release download v2.0.1 -R aiwcorpo/mcp-platform-offline -D <empty dir>
shasum -a 256 -c SHA256SUMS          # sha256sum -c on Linux; the zips are about 1 GB each
```

## Rules

- Images are linux/amd64 only. Do not add arm64 or multi-arch claims.
- aiwcorpo images come from `ghcr.io/aiwcorpo` at the released version. Third-party images (Keycloak, OpenBao, PostgreSQL,
  Redis, nginx, Eclipse Temurin) are pulled by the digests that `mcp-platform/compose.yaml` pins. Docker Hub is never a
  publish target for anything in this project.
- The README table (package names, contents, sizes) must match the latest release. When the platform and the servers are
  released at different versions, say which zip of which release to use, as the v2.0.1 release notes do.
- Never commit zips, image tars, `SHA256SUMS` of a package or anything extracted from one; they belong in releases only.

## Boundaries

Ask a person before: creating, editing or deleting a GitHub Release or its assets, pushing a tag, pushing to main, or pushing
images to any registry. Never commit secrets, `.env` files, internal host names or IP addresses.

## Pull requests

One change per PR, reviewed by a person since nothing runs automatically. Commit subject in English, imperative; the body says
why. Docs-only changes still need the README to match the published release.
