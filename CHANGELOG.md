# Changelog

## 2026-11-23: MCP Proxy v0.15.0 (first release)

- Breaking changes: none (first release).
- MCP Proxy `v0.15.0`, image `ghcr.io/sparfenyuk/mcp-proxy:v0.15.0-debian-node@sha256:29265b23ef7517a095083714d582fcf47803287a3c3d66513e2a661d4b9ce3e9`.
- Caddy `2.11.9` front on `$PORT` with an unauthenticated `/healthz`; mcp-proxy on loopback with `MCP_PROXY_AUTH_TOKEN` required on every request.
- Bundled stdio servers: `mcp-server-fetch` 2026.11.18, `mcp-server-time` 2026.11.18, `@modelcontextprotocol/server-memory` 2.2.1 (graph in `/data/memory.jsonl`).
- `MCP_SERVERS_JSON` or `/data/servers.json` replaces the bundled servers; `HOME=/data/home` caches `npx`/`uvx` downloads on the volume.
