#!/bin/bash
# ==============================================
# Create Cloudflare Tunnel Secret
# ==============================================
# The Cloudflare tunnel token is stored as a GitHub
# repository secret (Settings → Secrets and variables → Actions)
# and is NEVER committed to this repository.
#
# This script guides you through creating the Kubernetes Secret.
# ==============================================

set -e

NAMESPACE="media"
SECRET_NAME="cloudflared-tunnel-token"

echo "=============================================="
echo " Cloudflare Tunnel Secret Setup"
echo "=============================================="
echo ""
echo "The tunnel token lives as a GitHub secret:"
echo "  Repo → Settings → Secrets and variables → Actions"
echo "  Secret name: CLOUDFLARE_TUNNEL_TOKEN"
echo ""
echo "To create the Kubernetes Secret, run ONE of the following:"
echo ""

# Check if secret already exists
if kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" &>/dev/null 2>&1; then
    echo "  ✓ Secret '$SECRET_NAME' already exists in namespace '$NAMESPACE'."
    echo ""
    echo "  To update it, delete first:"
    echo "    kubectl delete secret $SECRET_NAME -n $NAMESPACE"
    echo "  Then recreate using one of the methods below."
else
    echo "  Secret '$SECRET_NAME' does NOT exist in namespace '$NAMESPACE'."
fi

echo ""
echo "=== Method 1: From environment variable (recommended) ==="
echo ""
echo "  export CLOUDFLARE_TUNNEL_TOKEN=\"your-token-here\""
echo "  kubectl create secret generic $SECRET_NAME \\"
echo "    --namespace=$NAMESPACE \\"
echo "    --from-literal=token=\"\$CLOUDFLARE_TUNNEL_TOKEN\""
echo ""
echo "=== Method 2: Direct value ==="
echo ""
echo "  kubectl create secret generic $SECRET_NAME \\"
echo "    --namespace=$NAMESPACE \\"
echo "    --from-literal=token='YOUR_TUNNEL_TOKEN'"
echo ""
echo "=== Method 3: From GitHub Actions (CI/CD) ==="
echo ""
echo "  If using GitHub Actions, add your kubeconfig as a secret"
echo "  (KUBECONFIG) and the tunnel token (CLOUDFLARE_TUNNEL_TOKEN),"
echo "  then use:"
echo ""
echo "    kubectl create secret generic $SECRET_NAME \\"
echo "      --namespace=$NAMESPACE \\"
echo "      --from-literal=token=\"\${{ secrets.CLOUDFLARE_TUNNEL_TOKEN }}\""
echo ""
echo "After creation, ArgoCD will deploy cloudflared automatically."
