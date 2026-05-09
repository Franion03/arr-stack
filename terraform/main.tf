terraform {
  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2.1"
    }
  }
}

resource "null_resource" "prepare_server" {
  # This triggers re-provisioning if any of these variables change
  triggers = {
    server_ip       = var.server_ip
    media_directory = var.media_directory
  }

  connection {
    type        = "ssh"
    user        = var.ssh_user
    private_key = file(pathexpand(var.ssh_private_key_path))
    host        = var.server_ip
  }

  provisioner "remote-exec" {
    inline = [
      "cat << 'EOF' > /tmp/prepare_server.sh",
      "#!/bin/bash",
      "set -e",
      "echo '==> Updating system packages...'",
      "apt-get update -y && apt-get upgrade -y && apt-get autoremove -y",
      "echo '==> Installing required dependencies for Docker...'",
      "apt-get install -y ca-certificates curl gnupg lsb-release",
      "echo '==> Installing Docker...'",
      "if ! command -v docker >/dev/null 2>&1; then curl -fsSL https://get.docker.com -o get-docker.sh && sh get-docker.sh; else echo 'Docker is already installed'; fi",
      "echo '==> Enabling and starting Docker service...'",
      "systemctl enable docker && systemctl start docker",
      "echo '==> Adding user to docker group...'",
      "usermod -aG docker ${var.ssh_user}",
      "echo '==> Installing k3d...'",
      "if ! command -v k3d >/dev/null 2>&1; then curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash; else echo 'k3d is already installed'; fi",
      "echo '==> Installing kubectl...'",
      "if ! command -v kubectl >/dev/null 2>&1; then curl -LO \"https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl\" && install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl && rm kubectl; else echo 'kubectl is already installed'; fi",
      "echo '==> Preparing host directories...'",
      "mkdir -p ${var.media_directory}",
      "chmod -R 775 ${var.media_directory}",
      "echo '==> Server preparation complete!'",
      "EOF",
      "chmod +x /tmp/prepare_server.sh",
      "echo '${var.sudo_password}' | sudo -S /tmp/prepare_server.sh",
      "rm /tmp/prepare_server.sh"
    ]
  }
}
