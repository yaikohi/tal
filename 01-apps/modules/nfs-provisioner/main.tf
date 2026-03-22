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
        name              = var.storage_class_name
        defaultClass      = var.set_default_class
        reclaimPolicy     = var.reclaim_policy
        allowVolumeExpansion = true
        archiveOnDelete   = var.archive_on_delete
      }
      # Resource requests/limits for the provisioner
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
      # Node affinity to prefer worker nodes
      affinity = {
        nodeAffinity = {
          preferredDuringSchedulingIgnoredDuringExecution = [
            {
              weight = 100
              preference = {
                matchExpressions = [
                  {
                    key      = "node-role.kubernetes.io/control-plane"
                    operator = "DoesNotExist"
                  }
                ]
              }
            }
          ]
        }
      }
    })
  ]

  depends_on = [var.depends_on_cilium]
}

# Storage Class for RWX (ReadWriteMany) workloads
resource "kubernetes_storage_class_v1" "nfs_rwx" {
  metadata {
    name = "nfs-rwx"
  }

  storage_provisioner    = "cluster.local/nfs-subdir-external-provisioner"
  reclaim_policy        = var.reclaim_policy
  allow_volume_expansion = true
  volume_binding_mode   = "Immediate"

  parameters = {
    archiveOnDelete = var.archive_on_delete
  }

  depends_on = [helm_release.nfs_provisioner]
}

# Storage Class for RWO (ReadWriteOnce) workloads with better performance
resource "kubernetes_storage_class_v1" "nfs_rwo" {
  metadata {
    name = "nfs-rwo"
  }

  storage_provisioner    = "cluster.local/nfs-subdir-external-provisioner"
  reclaim_policy        = "Retain"
  allow_volume_expansion = true
  volume_binding_mode   = "WaitForFirstConsumer"

  parameters = {
    archiveOnDelete = "true"
  }

  depends_on = [helm_release.nfs_provisioner]
}

# Create namespace for immich and related services
resource "kubernetes_namespace_v1" "immich" {
  metadata {
    name = "immich"
    labels = {
      name = "immich"
      app  = "immich"
    }
  }
}
