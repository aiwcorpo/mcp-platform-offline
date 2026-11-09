# MCP platform, offline packages

Docker images of the aiwcorpo MCP platform and its MCP servers for linux/amd64 (x86_64), packed for hosts without access to
image registries. Each package is a zip with the images (`docker save`), their checksums, load scripts for Linux (`bash`) and
Windows (PowerShell) and the Compose files to start them. Download them from
[Releases](https://github.com/aiwcorpo/mcp-platform-offline/releases).

| Package | Content | Size |
| --- | --- | --- |
| `mcp-platform-<version>-offline.zip` | gateway, credential broker, portal, Keycloak, OpenBao, PostgreSQL, Redis, nginx, Eclipse Temurin, Compose bundle | about 1.0 GB |
| `mcp-servers-<version>-offline.zip` | MCP servers for GitLab, Jira, Confluence, OpenSearch and a service desk, the adapter server, their `deploy/` directories | about 1.1 GB |

Targets: Docker Engine on Linux x86_64 and Docker Desktop on Windows with the WSL 2 backend. On an ARM machine the images run
under emulation only.

Each zip has a `README.md` with the steps: check and load the images, then install as the bundle or server README describes.
`SHA256SUMS` in the release lists the checksums of the zips.

With registry access the same images are on `ghcr.io/aiwcorpo` and need no package.

## Licenses

The aiwcorpo images are under the Apache License 2.0 (`LICENSE`). The third-party images in the platform package are the
unmodified upstream images under their own licenses; the package README lists them.
