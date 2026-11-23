[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/new/template/mcp-proxy?utm_medium=integration&utm_source=button&utm_campaign=mcp-proxy)

# MCP Proxy on Railway

One-click Railway template for [MCP Proxy](https://github.com/sparfenyuk/mcp-proxy) (`sparfenyuk/mcp-proxy`, MIT): it runs stdio-only MCP servers and serves them to remote clients over **Streamable HTTP** and **SSE**, behind a generated bearer token.

- **App:** MCP Proxy `v0.15.0`, official image `ghcr.io/sparfenyuk/mcp-proxy:v0.15.0-debian-node` pinned by digest (`sha256:29265b23ef75…`), Python 3.13 + Node.js 24, so both `uvx` and `npx` servers run.
- **Bundled stdio servers** (pinned, hash-checked): `fetch` (`mcp-server-fetch` 2026.11.18), `time` (`mcp-server-time` 2026.11.18) and `memory` (`@modelcontextprotocol/server-memory` 2.2.1, knowledge graph stored in `/data/memory.jsonl`).
- **One service**, one volume at `/data`. A small Caddy front listens on `$PORT`, serves `/healthz` without a token and passes everything else to mcp-proxy on `127.0.0.1:8096`.

## Variables

| Variable | Default | What it does |
|---|---|---|
| `MCP_PROXY_AUTH_TOKEN` | `${{secret(48,…)}}` | Bearer token every client must send. Generated per deploy; copy it from the service's **Variables** tab. |
| `PORT` | `8080` | Port Caddy listens on (the public domain points here). |

Optional, add them on the service only if you need them:

| Variable | What it does |
|---|---|
| `MCP_SERVERS_JSON` | Replaces the bundled servers. Standard `{"mcpServers": {"name": {"command": "...", "args": [...], "env": {...}}}}` JSON. |
| `MCP_PROXY_PASS_ENVIRONMENT` | `true` passes the service's variables to every stdio server (the auth token is always removed). Off by default: servers get only `HOME`, `PATH` and what you put in their `env`. |
| `MCP_PROXY_ALLOW_ORIGIN` | CORS origin for browser clients. Default `*` (every request still needs the token). |
| `MCP_PROXY_INIT_TIMEOUT` | Seconds a stdio server may take to start (default `120`, enough for a first `npx`/`uvx` download). |
| `MCP_PROXY_EXTRA_ARGS` | Extra `mcp-proxy` flags, for example `--stateless`. |

A `servers.json` file in `/data` is used when `MCP_SERVERS_JSON` is not set.

## Endpoints

For each server `NAME`:

- Streamable HTTP: `https://YOUR-DOMAIN/servers/NAME/mcp`
- SSE: `https://YOUR-DOMAIN/servers/NAME/sse`

`/healthz` answers `200 ok` without a token (Railway's health check). `/status` lists the servers and needs the token.

Client config (Claude Code, Cursor, VS Code and other clients that accept remote MCP servers with headers):

```json
{
  "mcpServers": {
    "railway-fetch": {
      "type": "http",
      "url": "https://YOUR-DOMAIN/servers/fetch/mcp",
      "headers": { "Authorization": "Bearer YOUR-MCP_PROXY_AUTH_TOKEN" }
    }
  }
}
```

Claude Code: `claude mcp add --transport http railway-fetch https://YOUR-DOMAIN/servers/fetch/mcp --header "Authorization: Bearer YOUR-MCP_PROXY_AUTH_TOKEN"`

## Adding your own servers

Set `MCP_SERVERS_JSON` on the service, for example:

```json
{"mcpServers":{"github":{"command":"npx","args":["-y","@modelcontextprotocol/server-github@2025.4.8"],"env":{"GITHUB_PERSONAL_ACCESS_TOKEN":"YOUR-TOKEN"}},"time":{"command":"uvx","args":["mcp-server-time==2026.11.18"]}}}
```

`HOME` is `/data/home`, so `npx` and `uvx` downloads are cached on the volume and a restart doesn't download them again. Pin package versions. If any server fails to start, the others still run; if none start, the service exits with an error and Railway restarts it.

## Resources

Idle with the three bundled servers: about 180 MB RAM. With two `npx`/`uvx` servers: about 300 MB. It fits Railway's Free plan (0.5 GB); each extra server adds 40–120 MB, so give the service more memory if you run many.

## Notes

- No Docker-in-Docker: servers that are only published as Docker images can't run here. Use their `npx`/`uvx` package instead.
- If mcp-proxy or a running stdio server stops, the container exits non-zero and Railway restarts it.
- The token may only use letters, digits and `. _ ~ + / = -`. An empty token stops the service instead of serving an open proxy.

## Updates

This template builds from this repository. When the `main` branch changes (a new mcp-proxy release or new pins for the bundled servers), Railway shows deployers an "update available" notice and they choose when to apply it. Read [CHANGELOG.md](CHANGELOG.md) first; breaking changes are listed at the top of each entry.

## Licence

The wrapper files in this repo are MIT. MCP Proxy is MIT (Sergey Parfenyuk); the bundled reference servers are from [modelcontextprotocol/servers](https://github.com/modelcontextprotocol/servers) (MIT/Apache-2.0); Caddy is Apache-2.0.
