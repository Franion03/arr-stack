variable "server_ip" {
  description = "The IP address of the homelab server"
  type        = string
}

variable "ssh_user" {
  description = "The SSH username for the homelab server"
  type        = string
  default     = "root"
}

variable "ssh_private_key_path" {
  description = "Path to the SSH private key for authentication"
  type        = string
  default     = "~/.ssh/id_ed25519"
}

variable "media_directory" {
  description = "The path for the media directory on the host"
  type        = string
  default     = "/srv/media"
}

variable "sudo_password" {
  description = "The sudo password for the SSH user"
  type        = string
  sensitive   = true
}
