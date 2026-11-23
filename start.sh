#!/bin/sh
# Start mcp-proxy on loopback and Caddy on $PORT; exit non-zero if either stops,
# so Railway's ON_FAILURE restart policy brings the service back.
set -eu

fail() { echo "start.sh: $*" >&2; exit 1; }

[ -n "${MCP_PROXY_AUTH_TOKEN:-}" ] || fail "MCP_PROXY_AUTH_TOKEN is empty; refusing to serve MCP servers without a bearer token"
case "$MCP_PROXY_AUTH_TOKEN" in
  *[!A-Za-z0-9._~+/=-]*) fail "MCP_PROXY_AUTH_TOKEN may only use letters, digits and . _ ~ + / = -" ;;
esac

export PORT="${PORT:-8080}"
export MCP_PROXY_INTERNAL_PORT="${MCP_PROXY_INTERNAL_PORT:-8096}"
DATA_DIR="${DATA_DIR:-/data}"
mkdir -p "$DATA_DIR/home" || fail "cannot write to $DATA_DIR (is the volume mounted?)"
# Child MCP servers inherit HOME, so uvx/npx caches and dotfiles land on the volume.
export HOME="$DATA_DIR/home"

# Which stdio servers to run: MCP_SERVERS_JSON, else $DATA_DIR/servers.json, else the bundled set.
CONFIG=/etc/mcp-proxy/servers.json
if [ -n "${MCP_SERVERS_JSON:-}" ]; then
  CONFIG=/tmp/mcp-servers.json
  printf '%s' "$MCP_SERVERS_JSON" > "$CONFIG"
  echo "start.sh: using MCP_SERVERS_JSON"
elif [ -f "$DATA_DIR/servers.json" ]; then
  CONFIG="$DATA_DIR/servers.json"
  echo "start.sh: using $CONFIG"
else
  echo "start.sh: using the bundled servers (fetch, time, memory)"
fi
python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); assert isinstance(d.get("mcpServers"), dict) and d["mcpServers"], "no mcpServers"' "$CONFIG" \
  || fail "$CONFIG is not valid JSON with a non-empty \"mcpServers\" object"

set -- --host 127.0.0.1 --port "$MCP_PROXY_INTERNAL_PORT" \
  --named-server-config "$CONFIG" \
  --initialization-timeout "${MCP_PROXY_INIT_TIMEOUT:-120}" \
  --log-level "${MCP_PROXY_LOG_LEVEL:-INFO}"
if [ "${MCP_PROXY_PASS_ENVIRONMENT:-false}" = "true" ]; then
  set -- "$@" --pass-environment
fi
# CORS for browser-based MCP clients (MCP Inspector and the like). Every request still
# needs the bearer token, so allowing any origin doesn't open the server.
if [ -n "${MCP_PROXY_ALLOW_ORIGIN-*}" ]; then
  set -- "$@" --allow-origin "${MCP_PROXY_ALLOW_ORIGIN-*}"
fi
# Extra flags, for example: --allow-origin https://example.com --stateless
# shellcheck disable=SC2086
set -- "$@" ${MCP_PROXY_EXTRA_ARGS:-}

mcp-proxy "$@" &
PROXY_PID=$!
caddy run --config /etc/mcp-proxy/Caddyfile --adapter caddyfile &
CADDY_PID=$!

trap 'kill "$PROXY_PID" "$CADDY_PID" 2>/dev/null; exit 0' TERM INT

# Poll: BusyBox/dash "wait -n" isn't reliable, and either process dying must stop the container.
while kill -0 "$PROXY_PID" 2>/dev/null && kill -0 "$CADDY_PID" 2>/dev/null; do
  sleep 2
done
if ! kill -0 "$PROXY_PID" 2>/dev/null; then
  code=0; wait "$PROXY_PID" || code=$?
  echo "start.sh: mcp-proxy stopped (exit $code)" >&2
else
  code=0; wait "$CADDY_PID" || code=$?
  echo "start.sh: caddy stopped (exit $code)" >&2
fi
kill "$PROXY_PID" "$CADDY_PID" 2>/dev/null || true
exit 1
