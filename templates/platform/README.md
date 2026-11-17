# MCP platform @VERSION@, offline package

The images of the aiwcorpo MCP platform for linux/amd64 (x86_64) and the Compose bundle, for a Docker host without access to
image registries: Docker Engine on Linux x86_64, or Docker Desktop on Windows with the WSL 2 backend. The MCP servers are in a
separate package, `@SERVERS_PACKAGE@`.@NOTE@

@CHECKED@

| Path | Content |
| --- | --- |
| `images/` | @IMAGE_COUNT@ images saved with `docker save`, linux/amd64 |
| `SHA256SUMS` | checksums of the files in `images/` |
| `load-images.sh`, `load-images.ps1` | check the checksums and load the images (Linux, Windows) |
| `mcp-platform/` | the Compose bundle, plus `compose.offline.yaml` |

| Image | Version |
| --- | --- |
@IMAGE_ROWS@

@PINNED_NOTE@

## 1. Load the images

Linux:

```bash
./load-images.sh
```

Windows (PowerShell, Docker Desktop running):

```powershell
powershell -ExecutionPolicy Bypass -File .\load-images.ps1
```

Both stop on a checksum mismatch.

## 2. Install the platform

Follow `mcp-platform/README.md` (certificates in `certs/`, `.env` from `platform.env`) and add two lines to `.env`:

```bash
COMPOSE_FILE=compose.yaml:compose.offline.yaml
PULL_POLICY=never
```

On Windows the separator in `COMPOSE_FILE` is a semicolon: `COMPOSE_FILE=compose.yaml;compose.offline.yaml`.

`compose.offline.yaml` is needed because Docker Engine with the classic image store does not keep the registry digest of an
image loaded with `docker load`, and `compose.yaml` names the third-party images by digest, so it would try to pull them. The
file names the same images by tag; `SHA256SUMS` checks the bytes before they are loaded.

Platform and server on one computer without a domain: `mcp-platform/README.md`, "Platform and server on one computer, without
a domain".

## Windows

- Extract the archive with the Windows extractor or 7-Zip and keep the line endings: the shell scripts run inside Linux
  containers and stop working when an editor rewrites them with CRLF.
- A certificate from your own CA must be trusted by Windows for the browser and for Claude Code: `certutil -addstore -f Root
  ca.crt` as administrator, and `NODE_EXTRA_CA_CERTS` for Claude Code.
- `host.docker.internal` exists on Docker Desktop, so the "without a domain" setup of the bundle README works as described.

## Licenses

The aiwcorpo images are under the Apache License 2.0. The third-party images keep their own licenses: Keycloak (Apache 2.0),
OpenBao (MPL 2.0), PostgreSQL (PostgreSQL License), Redis 8 (RSALv2, SSPLv1 or AGPLv3, at your choice), nginx (BSD 2-clause),
Eclipse Temurin (GPLv2 with the Classpath Exception). They are the unmodified upstream images; their sources are at the
projects' sites.
