#!/usr/bin/env bash
set -euo pipefail

# Tiny HTTP benchmark harness for comparing Haskell segmented rendering
# against the CopilotKit/Mastra Next baseline.

requests="${REQUESTS:-200}"

bench() {
  local name="$1"
  local url="$2"
  local header_mode="${3:-}"
  local header_target="${4:-}"
  local total_ms=0
  local ok=0

  for _ in $(seq 1 "$requests"); do
    local start end status
    start="$(date +%s%3N)"
    if [ -n "$header_mode" ]; then
      status="$(
        curl -s -o /dev/null -w '%{http_code}' \
          -H "X-Render-Mode: $header_mode" \
          -H "X-Render-Target: $header_target" \
          "$url"
      )"
    else
      status="$(curl -s -o /dev/null -w '%{http_code}' "$url")"
    fi
    end="$(date +%s%3N)"
    total_ms=$((total_ms + end - start))
    if [ "$status" = "200" ]; then
      ok=$((ok + 1))
    fi
  done

  printf '%-34s ok=%s/%s avg_ms=%s\n' "$name" "$ok" "$requests" "$((total_ms / requests))"
}

bench "haskell full client page" "http://127.0.0.1:8099/clients/1/ai"
bench "haskell client-panel fragment" "http://127.0.0.1:8099/clients/1/invoices" "fragment" "client-panel"
bench "haskell health" "http://127.0.0.1:8099/health"
bench "next copilotkit page" "http://127.0.0.1:3100/"
bench "next copilotkit info" "http://127.0.0.1:3100/api/copilotkit/info"
