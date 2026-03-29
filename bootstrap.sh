#!/bin/bash
set -e

# ==========================================
# Arr Stack k3d & ArgoCD Bootstrap Script
# ==========================================

CLUSTER_NAME="arr-cluster"
HOST_MEDIA_PATH="/mnt/media" # Change this to the actual media directory on your host

# 1. Check dependencies
command -v k3d >/dev/null 2>&1 || { echo >&2 "k3d is required but not installed. Aborting."; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo >&2 "kubectl is required but not installed. Aborting."; exit 1; }

echo "Creating media directory on host if it doesn't exist..."
sudo mkdir -p "${HOST_MEDIA_PATH}"

echo "Creating k3d cluster '${CLUSTER_NAME}'..."
k3d cluster create ${CLUSTER_NAME} \
  --port "80:80@loadbalancer" \
  --port "443:443@loadbalancer" \
  --volume "${HOST_MEDIA_PATH}:/data/media@all" \
  --k3s-arg "--disable=traefik@server:0"

echo "Waiting for cluster to be ready..."
kubectl wait --for=condition=Ready nodes --all --timeout=60s

echo "Installing ArgoCD..."
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/my-kustomization/manifests/install.yaml || \
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.10.1/manifests/install.yaml

echo "Waiting for ArgoCD server to be ready..."
kubectl wait --for=condition=available deployment/argocd-server -n argocd --timeout=300s

echo "Applying root application..."
# Note: You MUST push your repository to GitHub before this root app will succeed in syncing!
kubectl apply -f argocd/root.yaml

echo "=========================================="
echo "Bootstrap complete!"
echo "ArgoCD initial password:"
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo
echo ""
echo "Access ArgoCD by port-forwarding:"
echo "kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "Then access https://localhost:8080"
echo "=========================================="
