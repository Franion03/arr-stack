#!/usr/bin/env bash
# ==============================================
# Create the palworld Secret (local dev / bootstrap only)
# ==============================================
# Production: seal it and commit the SealedSecret, like every other secret
# in this repo. See .github/workflows/seal-secrets.yml.
#
#   TS_AUTHKEY      Tailscale auth key or OAuth client secret. Generate at
#                   https://login.tailscale.com/admin/settings/keys
#                   Use a REUSABLE key with a tag -- an ephemeral key makes
#                   the node disappear on every nightly restart.
#   TS_EXTRA_ARGS   Optional. Required only with an OAuth client, which must
#                   advertise a tag: --advertise-tags=tag:games
#   ADMIN_PASSWORD  RCON / in-game admin password.
#   SERVER_PASSWORD Join password. Empty means anyone on your tailnet can
#                   join, which may well be what you want.
# ==============================================
set -euo pipefail

NAMESPACE="${NAMESPACE:-palworld}"
SECRET="${SECRET:-palworld-secrets}"

KEYS=(TS_AUTHKEY TS_EXTRA_ARGS ADMIN_PASSWORD SERVER_PASSWORD)

args=()
set_count=0
for k in "${KEYS[@]}"; do
  v="${!k-}"
  args+=(--from-literal="$k=${v}")
  [ -n "$v" ] && set_count=$((set_count + 1))
done

if [ -z "${TS_AUTHKEY-}" ]; then
  echo "ERROR: TS_AUTHKEY is empty. The pod will never join the tailnet." >&2
  exit 1
fi

kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f - >/dev/null

kubectl create secret generic "$SECRET" \
  --namespace="$NAMESPACE" \
  "${args[@]}" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "✓ Secret '$SECRET' applied to namespace '$NAMESPACE' (${set_count}/${#KEYS[@]} values set)."
echo "  Restart to pick it up:  kubectl -n $NAMESPACE rollout restart deploy/palworld"
