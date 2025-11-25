terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.85.1" # Check for latest
    }
    talos = {
      source  = "siderolabs/talos"
      version = "0.9.0"
    }
  }
}

provider "proxmox" {
  # Configuration options are read from Environment Variables
  # (PROXMOX_VE_ENDPOINT, PROXMOX_VE_API_TOKEN, etc.)
  endpoint = var.PROXMOX_VE_ENDPOINT
  username = var.PROXMOX_VE_USERNAME
  password = var.PROXMOX_VE_PASSWORD
  insecure = true
  ssh {
      agent       = true
      username    = "root"
      private_key = file("~/.ssh/proxmox-pve") # <--- Point to the private key
    }
}

provider "talos" {
  # No specific config needed here, it acts as a client
}
