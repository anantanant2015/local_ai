#!/usr/bin/env bash
set -euo pipefail

# One-token Ollama generate smoke. Prompt is a fixed string, never user source.
MODEL="${1:-${MODEL:-}}"
API="http://127.0.0.1:11434/api/generate"

if [ -z "$MODEL" ]; then
  echo "Usage: $0 <model_tag>" >&2
  echo "   or: MODEL=<model_tag> $0" >&2
  exit 1
fi

if ! curl -sS --max-time 5 "http://127.0.0.1:11434" > /dev/null; then
  echo "❌ Ollama is not reachable at http://127.0.0.1:11434" >&2
  exit 1
fi

echo "🔎 Smoke generate: $MODEL"

RESP="$(curl -sS --max-time 120 "$API" \
  -H 'Content-Type: application/json' \
  -d "{\"model\":\"$MODEL\",\"prompt\":\"hi\",\"stream\":false,\"keep_alive\":0}")" || {
  echo "❌ Generate request failed for $MODEL" >&2
  exit 1
}

if echo "$RESP" | grep -q '"error"'; then
  echo "❌ Generate error for $MODEL: $RESP" >&2
  exit 1
fi

if ! echo "$RESP" | grep -q '"response"'; then
  echo "❌ Unexpected generate payload for $MODEL: $RESP" >&2
  exit 1
fi

echo "✅ Smoke generate ok: $MODEL"
