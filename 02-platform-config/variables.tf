variable "vault_root_token" {
  type        = string
  description = "The root token for OpenBao (required)"
  sensitive   = true
}

variable "zitadel_client_id" {
  type        = string
  description = "The ZITADEL client ID (required)"
  sensitive   = true
}

variable "zitadel_client_secret" {
  type        = string
  description = "The ZITADEL client secret (required)"
  sensitive   = true
}

variable "kubeconfig_path" {
  type        = string
  description = "Path to the kubeconfig file for the yaya cluster"
  default     = "../00-infra/kubeconfig"
}

variable "argocd_server_addr" {
  type        = string
  description = "ArgoCD server address (host:port) used by the argocd provider"
  default     = "192.168.20.222:80"
}

variable "media_vpn_provider" {
  type        = string
  description = "VPN provider name passed to gluetun (e.g. protonvpn)"
  sensitive   = true
}

variable "media_wireguard_private_key" {
  type        = string
  description = "WireGuard private key for the media downloader VPN"
  sensitive   = true
}

variable "media_wireguard_addresses" {
  type        = string
  description = "WireGuard interface address(es), e.g. 10.2.0.2/32"
  sensitive   = true
}

variable "immich_db_password" {
  type        = string
  description = "Password shared by the immich postgres user and the immich app"
  sensitive   = true
}

variable "argocd_password" {
  type = string
  description = "Password for the ArgoCD admin account (used by the argocd provider)"
  sensitive   = true
}

# ---- Homepage widget credentials that can't be auto-generated ----
# The *arr API keys (radarr/sonarr/prowlarr) ARE auto-generated via random_id
# resources in apps-secrets.tf and do NOT need to be provided here.

variable "jellyfin_api_key" {
  type        = string
  description = "Jellyfin API key (Admin Dashboard > API Keys). Leave empty on first apply; widget will simply error until set."
  sensitive   = true
  default     = ""
}

variable "immich_api_key" {
  type        = string
  description = "Immich API key (Account Settings > API Keys, requires server.statistics). Leave empty on first apply."
  sensitive   = true
  default     = ""
}

variable "qbit_username" {
  type        = string
  description = "qBittorrent WebUI username"
  sensitive   = true
  default     = "admin"
}

variable "qbit_password" {
  type        = string
  description = "qBittorrent WebUI password"
  sensitive   = true
  default     = "adminadmin"
}