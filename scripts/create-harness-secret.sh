#!/usr/bin/env bash
# ==============================================
# Create the harness Secret (local dev / bootstrap only)
# ==============================================
# Production: use the GitHub Actions workflow
#   .github/workflows/seal-secrets.yml
#
# It pulls the values from GitHub Secrets, seals them, commits the
# SealedSecret, and ArgoCD deploys it.
# ==============================================
set -euo pipefail

NAMESPACE="${NAMESPACE:-assistant}"
SECRET="${SECRET:-harness-secrets}"

KEYS=(
  CF_ACCOUNT_ID CF_AI_GATEWAY CF_AI_GATEWAY_TOKEN
  ANTHROPIC_API_KEY OPENAI_API_KEY GOOGLE_AI_API_KEY OPENROUTER_API_KEY
  GROQ_API_KEY CF_WORKERS_AI_TOKEN ELEVENLABS_API_KEY DEEPGRAM_API_KEY
  HA_URL HA_TOKEN
  GOOGLE_CLIENT_ID GOOGLE_CLIENT_SECRET GOOGLE_REFRESH_TOKEN GOOGLE_CALENDAR_ID
  HARNESS_API_KEY
)

args=()
set_count=0
for k in "${KEYS[@]}"; do
  v="${!k-}"
  args+=(--from-literal="$k=${v}")
  [ -n "$v" ] && set_count=$((set_count + 1))
done

kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f - >/dev/null

kubectl create secret generic "$SECRET" \
  --namespace="$NAMESPACE" \
  "${args[@]}" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "✓ Secret '$SECRET' applied to namespace '$NAMESPACE' (${set_count}/${#KEYS[@]} values set)."
echo "  Restart to pick it up:  kubectl -n $NAMESPACE rollout restart deploy/harness"
