module "cilium" {
  source          = "./modules/cilium"
  kubeconfig_path = var.kubeconfig_path
}

module "argocd" {
  source     = "./modules/argocd"
  depends_on = [module.cilium]
}

# 3a. cert-manager DNS01 bootstrap
# Pre-creates the Cloudflare API token Secret so the wildcard Certificate can
# issue as soon as Argo deploys cert-manager-manifests. Breaks the cert
# ↔ OpenBao circular dependency by owning this Secret in Terraform.
module "cert_manager_bootstrap" {
  source               = "./modules/cert-manager-bootstrap"
  cloudflare_api_token = var.cloudflare_api_token
  depends_on           = [module.argocd]
}
