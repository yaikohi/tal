# 1. Networking (Cilium)
module "cilium" {
  source          = "./modules/cilium"
  kubeconfig_path = var.kubeconfig_path
  lb_cidr         = "192.168.20.220/28"
}

# 2. GitOps (ArgoCD)
module "argocd" {
  source     = "./modules/argocd"
  depends_on = [module.cilium]
}

# 3. Test
module "test-workload" {
  source     = "./modules/test-workload"
  depends_on = [module.cilium]
}
