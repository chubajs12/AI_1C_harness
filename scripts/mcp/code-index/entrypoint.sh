#!/bin/bash
# One container: daemon (writer) + serve (read-only MCP HTTP).
# Logs go to stdout/stderr so `docker logs <PROJECT>_code_index` shows indexing progress.
set -euo pipefail

: "${CODE_INDEX_HOME:=/data/code-index-home}"
: "${MCP_HTTP_HOST:=0.0.0.0}"
: "${MCP_HTTP_PORT:=8030}"
export CODE_INDEX_HOME
mkdir -p "$CODE_INDEX_HOME"

if [[ ! -f "$CODE_INDEX_HOME/daemon.toml" ]]; then
  echo "[code-index] ERROR: missing $CODE_INDEX_HOME/daemon.toml" >&2
  exit 1
fi

# Fresh PID namespace after docker stop/kill — drop stale pid/json from volume.
rm -f "$CODE_INDEX_HOME/daemon.pid" "$CODE_INDEX_HOME/daemon.json"

echo "[code-index] starting daemon (writer)…"
bsl-indexer daemon run 2>&1 &
DAEMON_PID=$!

echo "[code-index] waiting for $CODE_INDEX_HOME/daemon.json…"
for _ in $(seq 1 180); do
  [[ -f "$CODE_INDEX_HOME/daemon.json" ]] && break
  if ! kill -0 "$DAEMON_PID" 2>/dev/null; then
    echo "[code-index] daemon exited early" >&2
    wait "$DAEMON_PID" || true
    exit 1
  fi
  sleep 1
done

if [[ ! -f "$CODE_INDEX_HOME/daemon.json" ]]; then
  echo "[code-index] timeout waiting for daemon.json" >&2
  kill "$DAEMON_PID" 2>/dev/null || true
  exit 1
fi

echo "[code-index] MCP HTTP on ${MCP_HTTP_HOST}:${MCP_HTTP_PORT}/mcp"
bsl-indexer serve --transport http --host "$MCP_HTTP_HOST" --port "${MCP_HTTP_PORT}" \
  --config "$CODE_INDEX_HOME/daemon.toml" 2>&1 &
SERVE_PID=$!

# Periodic status to docker logs (like graph/meta visibility).
status_loop() {
  while true; do
    sleep 60
    if ! kill -0 "$DAEMON_PID" 2>/dev/null; then
      return
    fi
    echo "[code-index] --- daemon status ---"
    bsl-indexer daemon status 2>&1 || true
  done
}
status_loop &
STATUS_PID=$!

wait -n "$DAEMON_PID" "$SERVE_PID"
echo "[code-index] process exited — stopping container" >&2
kill "$DAEMON_PID" "$SERVE_PID" "$STATUS_PID" 2>/dev/null || true
exit 1
