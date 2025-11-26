terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.87.0"
    }
    talos = {
      source  = "siderolabs/talos"
      version = "0.9.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "3.1.1"
    }
  }
}

provider "proxmox" {
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

provider "talos" {}

provider "helm" {
  kubernetes = {
    config_path = "${path.module}/kubeconfig"
  }
}
