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
  # By default talks to `https://bao.ykhi.xyz` via the cluster's wildcard cert.
  # During bootstrap (cert/HA not yet ready) override with VAULT_ADDR env, e.g.:
  #   VAULT_ADDR=http://127.0.0.1:18200 tofu apply
  # while running `kubectl -n openbao port-forward openbao-0 18200:8200`.
  address         = coalesce(var.vault_addr_override, "https://bao.ykhi.xyz")
  token           = var.vault_root_token
  skip_tls_verify = true
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
  plain_text = true # ArgoCD server runs with --insecure behind LAN-only LB
  insecure   = true
}
