terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.95.0"
    }
    talos = {
      source  = "siderolabs/talos"
      version = "0.10.1"
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
    agent    = false
    username = "root"
    private_key = file("~/.ssh/proxmox-pve")
  }
}

provider "talos" {}

provider "helm" {
  kubernetes = {
    config_path = "${path.module}/kubeconfig"
  }
}
