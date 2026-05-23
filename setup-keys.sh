#!/usr/bin/env bash
# setup-keys.sh — Generate LiteLLM virtual keys for the Pi sandbox
# Run this once after `docker compose up -d litellm`
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# ── Load .env ──────────────────────────────────────────────
if [[ ! -f .env ]]; then
  echo "❌ No .env file found. Copy .env.example and fill it in first:"
  echo "   cp .env.example .env && nano .env"
  exit 1
fi

set -a; source .env; set +a

if [[ -z "${LITELLM_MASTER_KEY:-}" ]]; then
  echo "❌ LITELLM_MASTER_KEY not set in .env"
  exit 1
fi

BASE_URL="http://localhost:${LITELLM_PORT:-4000}"
HEALTH_URL="${BASE_URL}/health"

# ── Wait for LiteLLM to be healthy ────────────────────────
echo "⏳ Waiting for LiteLLM proxy at ${BASE_URL}..."
for i in $(seq 1 30); do
  if curl -sf "$HEALTH_URL" > /dev/null 2>&1; then
    echo "✅ LiteLLM is healthy"
    break
  fi
  if [[ $i -eq 30 ]]; then
    echo "❌ LiteLLM did not become healthy within 30 attempts"
    exit 1
  fi
  sleep 2
done

# ── Helper: create a virtual key ──────────────────────────
create_key() {
  local key_name="$1"
  local models="$2"    # comma-separated model names, or empty for all
  local max_budget="$3"

  local payload="{\"key_name\": \"${key_name}\""
  if [[ -n "$models" ]]; then
    payload="${payload}, \"models\": [${models}]}"
  else
    payload="${payload}}"
  fi

  echo ""
  echo "🔑 Creating virtual key: ${key_name}"
  RESPONSE=$(curl -sf -X POST "${BASE_URL}/key/generate" \
    -H "Authorization: Bearer ${LITELLM_MASTER_KEY}" \
    -H "Content-Type: application/json" \
    -d "${payload}")

  if [[ $? -ne 0 ]]; then
    echo "❌ Failed to create key ${key_name}"
    echo "   Make sure LITELLM_MASTER_KEY in .env matches the running proxy"
    return 1
  fi

  VIRTUAL_KEY=$(echo "$RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin)['key'])" 2>/dev/null)

  if [[ -z "$VIRTUAL_KEY" ]]; then
    echo "❌ Could not parse key from response"
    echo "   Response: $RESPONSE"
    return 1
  fi

  echo "   Key: ${VIRTUAL_KEY}"
  echo "   Models: ${models:-ALL}"
  echo ""
  echo "$VIRTUAL_KEY"
}

# ── Create keys ────────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════════════════════"
echo "  Creating LiteLLM Virtual Keys"
echo "═══════════════════════════════════════════════════════"

# Key 1: Full access — all models
FULL_KEY=$(create_key "pi-sandbox-full" "" "")

# Key 2: Fast/cheap tier — budget models only
BUDGET_KEY=$(create_key "pi-sandbox-budget" \
  '"claude-haiku", "gpt-4.1-mini", "gemini-2.5-flash", "llama-4-maverick"' "")

# ── Write keys to .env ────────────────────────────────────
echo ""
echo "═══════════════════════════════════════════════════════"
echo "  Updating .env with virtual keys"
echo "═══════════════════════════════════════════════════════"

update_env() {
  local key="$1"
  local value="$2"
  local file=".env"
  if grep -q "^${key}=" "$file"; then
    sed -i "s|^${key}=.*|${key}=${value}|" "$file"
  else
    echo "${key}=${value}" >> "$file"
  fi
}

update_env "LITELLM_VIRTUAL_KEY" "${FULL_KEY}"
update_env "LITELLM_VIRTUAL_KEY_BUDGET" "${BUDGET_KEY}"

echo ""
echo "✅ Done! Virtual keys written to .env"
echo ""
echo "   LITELLM_VIRTUAL_KEY         → full access (all models)"
echo "   LITELLM_VIRTUAL_KEY_BUDGET   → budget tier (haiku, mini, flash, llama)"
echo ""
echo "   Pi sandbox will use LITELLM_VIRTUAL_KEY by default."
echo "   To use the budget key on a one-shot run:"
echo ""
echo "     docker compose run --rm -e OPENAI_API_KEY=\${LITELLM_VIRTUAL_KEY_BUDGET} pi-sandbox"
echo ""