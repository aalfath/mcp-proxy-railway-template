# MCP Proxy (sparfenyuk/mcp-proxy) for Railway.
# Official image, debian-node flavour (Python 3.13 + Node.js 24, so both uvx and npx servers run).
FROM caddy:2.11.9-alpine@sha256:003a97808e781aa9f7e75cc2f43d34d461099031faf5e20faefb9f61126836f0 AS caddy

FROM ghcr.io/sparfenyuk/mcp-proxy:v0.15.0-debian-node@sha256:29265b23ef7517a095083714d582fcf47803287a3c3d66513e2a661d4b9ce3e9

COPY --from=caddy /usr/bin/caddy /usr/local/bin/caddy

# Bundled stdio MCP servers, pinned and hash-checked, in their own environments
# (they need a newer MCP SDK than mcp-proxy itself).
WORKDIR /opt/mcp-servers
COPY servers/requirements.txt servers/package.json servers/package-lock.json ./
RUN uv venv --quiet --python /usr/local/bin/python3 /opt/mcp-servers/venv \
 && uv pip install --quiet --no-cache --python /opt/mcp-servers/venv/bin/python --require-hashes -r requirements.txt \
 && npm ci --omit=dev --no-audit --no-fund --loglevel=error \
 && npm cache clean --force

COPY servers/servers.json Caddyfile start.sh /etc/mcp-proxy/
RUN chmod 755 /etc/mcp-proxy/start.sh

ENV PORT=8080 \
    MCP_PROXY_INTERNAL_PORT=8096 \
    DATA_DIR=/data \
    PYTHONUNBUFFERED=1 \
    UV_NO_PROGRESS=1 \
    NPM_CONFIG_UPDATE_NOTIFIER=false \
    NPM_CONFIG_FUND=false

WORKDIR /data
EXPOSE 8080
ENTRYPOINT ["/usr/bin/catatonit", "--", "/etc/mcp-proxy/start.sh"]
