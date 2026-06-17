terraform {
  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "~> 4.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.30"
    }
    argocd = {
      source  = "oboukili/argocd"
      version = "~> 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "vault" {
  # address = "http://127.0.0.1:8200" # Changed temporarily for the tunnel
  address = "https://bao.ykhi.xyz"
  token   = var.vault_root_token
}

provider "kubernetes" {
  config_path = var.kubeconfig_path
}

# ArgoCD provider — mints API tokens that we then store in OpenBao.
# Admin password is read from the cluster-stored `argocd-initial-admin-secret`
# so it never needs to be committed.
data "kubernetes_secret_v1" "argocd_initial_admin" {
  metadata {
    name      = "argocd-initial-admin-secret"
    namespace = "argocd"
  }
}

provider "argocd" {
  server_addr = var.argocd_server_addr
  username    = "admin"
  password    = var.argocd_password
  # password    = data.kubernetes_secret_v1.argocd_initial_admin.data["password"]
  plain_text  = true # ArgoCD server runs with --insecure behind LAN-only LB
  insecure    = true
}
