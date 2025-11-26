variable "PROXMOX_VE_ENDPOINT" {
  description = "The endpoint for the Proxmox Virtual Environment API (example: https://host:port)"
  type        = string
  default     = "https://192.168.10.5:8006"
  sensitive   = false
}

variable "PROXMOX_VE_NODENAME" {
  description = "Name of the proxmox node"
  type        = string
  default     = "dusk"
  sensitive   = false
}

variable "PROXMOX_VE_USERNAME" {
  description = "Proxmox User for API Access"
  type        = string
  default     = "tofu_provisioner@pve"
}

variable "PROXMOX_VE_PASSWORD" {
  description = "Password for Proxmox API User"
  type        = string
  sensitive   = true
  default     = "do not use default passwords!"
}
