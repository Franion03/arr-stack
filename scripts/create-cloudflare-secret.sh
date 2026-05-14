#!/bin/bash
# ==============================================
# Create Cloudflare Tunnel Secret (manual)
# ==============================================
# For automated sync, use the GitHub Actions workflow:
#   .github/workflows/sync-secrets.yml
#
# That workflow pulls CLOUDFLARE_TUNNEL_TOKEN from
# GitHub Secrets and creates the K8s Secret automatically.
#
# Use this script only for manual one-off creation.
# ==============================================

set -e
NAMESPACE="media"
SECRET_NAME="cloudflared-tunnel-token"

if kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" &>/dev/null 2>&1; then
    echo "✓ Secret '$SECRET_NAME' already exists."
    echo "  Run the GitHub Actions workflow to update it."
    exit 0
fi

if [ -n "$CLOUDFLARE_TUNNEL_TOKEN" ]; then
    kubectl create secret generic "$SECRET_NAME" \
        --namespace="$NAMESPACE" \
        --from-literal=token="$CLOUDFLARE_TUNNEL_TOKEN"
    echo "✓ Secret '$SECRET_NAME' created from \$CLOUDFLARE_TUNNEL_TOKEN."
else
    echo "Set CLOUDFLARE_TUNNEL_TOKEN and rerun:"
    echo "  export CLOUDFLARE_TUNNEL_TOKEN='your-token'"
    echo "  $0"
    echo ""
    echo "Or use the automated GitHub Actions workflow:"
    echo "  .github/workflows/sync-secrets.yml"
fi
