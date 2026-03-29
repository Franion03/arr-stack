# Arr Stack GitOps on k3d

This repository contains the complete definitions to run the Arr Stack (Sonarr, Radarr, Prowlarr, Transmission, Jellyfin) on a local `k3d` cluster, fully managed by ArgoCD.

## Prerequisites

1. Install `k3d`, `kubectl`, and `docker`.
2. Push this repository to your GitHub account.

## Setup Instructions

1. **Update GitHub URL**: Open `argocd/root.yaml` and replace the placeholder `repoURL` with the actual URL of your GitHub repository.
2. **Commit and Push**:
   ```bash
   git init
   git add .
   git commit -m "Initial commit"
   git branch -M main
   git remote add origin https://github.com/YOUR_Franion03/arr-stack.git
   git push -u origin main
   ```
3. **Bootstrap differences**: Run the bootstrap script locally on the server.
   ```bash
   chmod +x bootstrap.sh
   ./bootstrap.sh
   ```

## What it does

- `bootstrap.sh`: Creates a k3d cluster binding ports 80/443 to the host, and mounting `/mnt/media` to `/data/media` inside the cluster. It then installs ArgoCD and applies the GitOps root application.
- `apps/`: The ArgoCD application syncs everything inside the `apps` directory using Kustomize, providing persistent storage, deployments, services, and ingress routes for all the media applications.
- Routes exposed on localhost:
  - `http://localhost/sonarr`
  - `http://localhost/radarr`
  - `http://localhost/prowlarr`
  - `http://localhost/transmission`
  - `http://localhost/jellyfin`
