#!/bin/bash
# ==============================================
# Create Cloudflare Tunnel Secret (local dev only)
# ==============================================
# Production: use the GitHub Actions workflow
#   .github/workflows/seal-secrets.yml
#
# It pulls the token from GitHub Secrets, seals it,
# commits the SealedSecret, and ArgoCD deploys it.
#
# This script is for local dev / bootstrapping only.
# ==============================================

set -e
NAMESPACE="media"
SECRET_NAME="cloudflared-tunnel-token"

if [ -n "$CLOUDFLARE_TUNNEL_TOKEN" ]; then
    kubectl create secret generic "$SECRET_NAME" \
        --namespace="$NAMESPACE" \
        --from-literal=token="$CLOUDFLARE_TUNNEL_TOKEN" \
        --dry-run=client -o yaml | kubectl apply -f -
    echo "✓ Secret '$SECRET_NAME' created from \$CLOUDFLARE_TUNNEL_TOKEN."
else
    echo "For production: push to master → Actions → Seal Secrets"
    echo "For local dev:  export CLOUDFLARE_TUNNEL_TOKEN='token' && $0"
fi
