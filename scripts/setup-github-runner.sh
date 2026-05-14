#!/bin/bash
# ==============================================
# Setup GitHub Actions Self-Hosted Runner
# ==============================================
# This installs a GitHub Actions runner on your
# Debian server (192.168.1.114) so that workflows
# can reach the K3s cluster directly.
#
# The runner executes the sync-secrets workflow
# which pulls tokens from GitHub repository secrets
# and creates Kubernetes Secrets in the cluster.
#
# Prerequisites:
#   - GitHub repo: Franion03/arr-stack
#   - Server has kubectl + cluster access already
# ==============================================

set -e

REPO="Franion03/arr-stack"
RUNNER_DIR="$HOME/actions-runner"

echo "=============================================="
echo " GitHub Actions Self-Hosted Runner Setup"
echo "=============================================="
echo ""
echo "This script should be run ON your Debian server"
echo "(fran@192.168.1.114), not on your local machine."
echo ""

# --- Step 1: Create runner directory ---
echo "==> Step 1: Creating runner directory at $RUNNER_DIR"
mkdir -p "$RUNNER_DIR"
cd "$RUNNER_DIR"

# --- Step 2: Download the runner ---
echo "==> Step 2: Downloading GitHub Actions runner"
RUNNER_VERSION=$(curl -s https://api.github.com/repos/actions/runner/releases/latest | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/' | sed 's/^v//')
if [ -z "$RUNNER_VERSION" ]; then
    RUNNER_VERSION="2.323.0"  # fallback
fi

echo "   Runner version: $RUNNER_VERSION"
curl -o actions-runner-linux-x64.tar.gz -L \
    "https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz"

# --- Step 3: Extract ---
echo "==> Step 3: Extracting runner"
tar xzf actions-runner-linux-x64.tar.gz
rm actions-runner-linux-x64.tar.gz

# --- Step 4: Configure ---
echo "==> Step 4: Configuring runner"
echo ""
echo "You need a GitHub Personal Access Token (PAT) with 'repo' scope."
echo "Create one at: https://github.com/settings/tokens"
echo ""
read -rp "Enter your PAT: " PAT

./config.sh \
    --url "https://github.com/$REPO" \
    --token "$PAT" \
    --name "fran-server" \
    --labels "self-hosted,Linux,x64" \
    --unattended \
    --replace

# --- Step 5: Install as a service ---
echo "==> Step 5: Installing runner as a systemd service"
sudo ./svc.sh install
sudo ./svc.sh start

echo ""
echo "=============================================="
echo " Runner installed and running!"
echo ""
echo " Check status:  sudo ./svc.sh status"
echo " Stop runner:   sudo ./svc.sh stop"
echo " Uninstall:     sudo ./svc.sh uninstall"
echo ""
echo " Now go to GitHub repo Settings:"
echo "   → Secrets and variables → Actions"
echo "   → Add secret: CLOUDFLARE_TUNNEL_TOKEN"
echo ""
echo " The sync-secrets workflow will run on every"
echo " push that touches secrets configuration."
echo "=============================================="
