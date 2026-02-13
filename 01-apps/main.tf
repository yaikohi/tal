# 1. Networking (Cilium)
module "cilium" {
  source          = "./modules/cilium"
  kubeconfig_path = var.kubeconfig_path
  lb_cidr         = "192.168.20.220/28"
}

# 2. Storage (NFS Provisioner)
module "nfs_provisioner" {
  source              = "./modules/nfs-provisioner"
  nfs_server          = var.nfs_server
  nfs_path            = var.nfs_path
  storage_class_name  = "nfs"
  set_default_class   = true
  reclaim_policy      = "Retain"
  archive_on_delete   = true
  depends_on_cilium   = module.cilium
}

# 3. GitOps (ArgoCD)
module "argocd" {
  source     = "./modules/argocd"
  depends_on = [module.cilium]
}

# 4. Test
module "test-workload" {
  source     = "./modules/test-workload"
  depends_on = [module.cilium]
}
