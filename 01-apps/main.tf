# 1. Networking (Cilium)
module "cilium" {
  source          = "./modules/cilium"
  kubeconfig_path = var.kubeconfig_path
}

# 2. Storage (NFS Provisioner)
module "nfs_provisioner" {
  source            = "./modules/nfs-provisioner"
  nfs_server        = var.nfs_server
  nfs_path          = var.nfs_path
  depends_on_cilium = module.cilium
}

# 3. GitOps (ArgoCD)
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

module "storage_classes" {
  source     = "./modules/storage_classes"
  depends_on = [module.nfs_provisioner]
}

# 4. Test
# module "test-workload" {
#   source     = "./modules/test-workload"
#   depends_on = [module.cilium]
# }
