# MCP servers @VERSION@, offline package

The images of the aiwcorpo MCP servers for linux/amd64 (x86_64) and their `deploy/` directories, for a Docker host without
access to image registries: Docker Engine on Linux x86_64, or Docker Desktop on Windows with the WSL 2 backend. The platform
(gateway, broker, portal, identity provider) is in `@PLATFORM_PACKAGE@`.

| Path | Content |
| --- | --- |
| `images/` | @IMAGE_COUNT@ images saved with `docker save`, linux/amd64 |
| `SHA256SUMS` | checksums of the files in `images/` |
| `load-images.sh`, `load-images.ps1` | check the checksums and load the images (Linux, Windows) |
| `servers/mcp-server-<system>/` | the `deploy/` directory of each server, from `@REF@` |

| Image | Version |
| --- | --- |
@IMAGE_ROWS@

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

## 2. Start a server

In the directory of the server, for example `servers/mcp-server-gitlab/`, fill in its environment file (`mcp-gitlab.env`) as its
`README.md` describes, put `PULL_POLICY=never` in a `.env` file next to `compose.yaml`, and run `docker compose up -d`. The
image is already loaded, so nothing is pulled or built.

When the platform certificate comes from your own CA, the server needs it in a trust store (`README.md` of the server, "The
platform certificate comes from a company CA").

## License

Apache License 2.0.
