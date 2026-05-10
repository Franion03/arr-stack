# Arr Stack GitOps on k3d

This repository contains the complete definitions to run the Arr Stack (Sonarr, Radarr, Prowlarr, Transmission, Jellyfin) on a local `k3d` cluster, fully managed by ArgoCD.

## Prerequisites

1. Install `k3d`, `kubectl`, and `docker`.
2. Push this repository to your GitHub account.

## Setup Instructions

### 0. Prepare Server Infrastructure (Terraform)

If you are deploying this on a fresh Ubuntu/Debian server, you can use the provided Terraform code to automatically install Docker, k3d, and kubectl, and configure the necessary host directories.

1. Ensure you have an SSH key configured to access your server without a password.
2. Go to the terraform directory:
   ```bash
   cd terraform
   ```
3. Copy the variables template:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```
4. Edit `terraform.tfvars` with your server's IP, SSH username, SSH key path, and the user's sudo password (if required).
5. Initialize and apply the configuration:
   ```bash
   terraform init
   terraform apply
   ```
6. Once complete, return to the root directory (`cd ..`) and proceed with the remaining steps.

### 1. Configure the Cluster

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
  - `http://localhost/jellyseerr`
