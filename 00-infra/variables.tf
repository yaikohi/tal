variable "PROXMOX_VE_ENDPOINT" {
  description = "The endpoint for the Proxmox Virtual Environment API (example: https://host:port)"
  type        = string
  default     = "https://192.168.10.5:8006"
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


variable "virtual_environment_node_name" {
  description = "Name of the Proxmox node"
  type        = string
  default     = "dusk"
}

variable "virtual_environment_storage" {
  description = "Name of the Proxmox storage"
  type        = string
  default     = "local-lvm"
}

variable "datastore_id" {
  description = "The datastore for VM disks (must be block-based storage)."
  type        = string
  default     = "local-lvm"
}

variable "snippets_datastore_id" {
  description = "The datastore for snippets (must be file-based storage)."
  type        = string
  default     = "local" # 'local' is the default directory-based storage in Proxmox
}

variable "cloud_image_url" {
  description = "URL of the cloud image to use"
  type        = string
  default     = "https://cloud-images.ubuntu.com/plucky/current/plucky-server-cloudimg-amd64.img"
}
