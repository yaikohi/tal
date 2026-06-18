resource "kubernetes_manifest" "sc_nfs_rwo" {
  manifest = {
    apiVersion = "storage.k8s.io/v1"
    kind       = "StorageClass"
    metadata = {
      name = "nfs-rwo"
    }
    provisioner = "cluster.local/nfs-subdir-external-provisioner"
    reclaimPolicy = "Retain"
    parameters = {
      archiveOnDelete = "true"
    }
  }
}

resource "kubernetes_manifest" "sc_nfs_rwx" {
  manifest = {
    apiVersion = "storage.k8s.io/v1"
    kind       = "StorageClass"
    metadata = {
      name = "nfs-rwx"
    }
    provisioner = "cluster.local/nfs-subdir-external-provisioner"
    reclaimPolicy = "Retain"
    parameters = {
      archiveOnDelete = "true"
    }
  }
}