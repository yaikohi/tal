# DragonflyDB for Immich (Redis-compatible)
resource "kubernetes_namespace_v1" "dragonflydb" {
  metadata {
    name = "dragonflydb"
  }
}

resource "helm_release" "dragonflydb" {
  name       = "dragonflydb"
  repository = "oci://ghcr.io/dragonflydb/dragonfly/helm"
  chart      = "dragonfly"
  namespace  = kubernetes_namespace_v1.dragonflydb.metadata[0].name
  version    = "v1.23.1"

  values = [
    yamlencode({
      replicaCount = 1

      resources = {
        requests = {
          cpu    = "100m"
          memory = "256Mi"
        }
        limits = {
          cpu    = "1000m"
          memory = "2Gi"
        }
      }

      storage = {
        enabled = var.persistence_enabled
        size    = var.storage_size
        storageClassName = var.storage_class
      }

      service = {
        type = "ClusterIP"
        port = 6379
      }

      # DragonflyDB specific settings
      extraArgs = [
        "--maxmemory=1.5G",
        "--proactor_threads=2",
        "--cache_mode"
      ]

      # Optional: Enable authentication
      auth = {
        enabled  = var.auth_enabled
        password = var.password
      }

      metrics = {
        enabled = false
      }
    })
  ]
}

output "host" {
  value       = "${helm_release.dragonflydb.name}.${kubernetes_namespace_v1.dragonflydb.metadata[0].name}.svc.cluster.local"
  description = "DragonflyDB hostname for connecting within the cluster"
}

output "port" {
  value       = "6379"
  description = "DragonflyDB port"
}

output "password" {
  value       = var.auth_enabled ? var.password : ""
  sensitive   = true
  description = "DragonflyDB password (if auth enabled)"
}
