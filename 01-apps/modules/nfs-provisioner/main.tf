resource "helm_release" "nfs_provisioner" {
  name       = "nfs-subdir-external-provisioner"
  repository = "https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner"
  chart      = "nfs-subdir-external-provisioner"
  version    = "4.0.18"
  namespace  = "kube-system"

  values = [
    yamlencode({
      nfs = {
        server = var.nfs_server
        path   = var.nfs_path
      }
      storageClass = {
        name                 = "nfs"
        defaultClass         = true
        reclaimPolicy        = "Retain"
        allowVolumeExpansion = true
        archiveOnDelete      = true
      }
      resources = {
        limits = {
          cpu    = "100m"
          memory = "128Mi"
        }
        requests = {
          cpu    = "10m"
          memory = "64Mi"
        }
      }
    })
  ]

  depends_on = [var.depends_on_cilium]
}
