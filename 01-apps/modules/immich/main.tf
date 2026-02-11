variable "node_name" {
  description = "The Talos node where the disk is attached"
  type        = string
  default     = "w-01"
}

variable "disk_mount_path" {
  description = "The path where Talos mounts the userVolume"
  type        = string
  default     = "/var/mnt/immich-data"
}

variable "db_hostname" {
  description = "PostgreSQL hostname"
  type        = string
}

variable "db_port" {
  description = "PostgreSQL port"
  type        = string
  default     = "5432"
}

variable "db_username" {
  description = "PostgreSQL username"
  type        = string
}

variable "db_password" {
  description = "PostgreSQL password"
  type        = string
  sensitive   = true
}

variable "db_name" {
  description = "PostgreSQL database name"
  type        = string
}

variable "redis_hostname" {
  description = "Redis/DragonflyDB hostname"
  type        = string
}

variable "redis_port" {
  description = "Redis/DragonflyDB port"
  type        = string
  default     = "6379"
}

variable "redis_password" {
  description = "Redis/DragonflyDB password (optional)"
  type        = string
  default     = ""
  sensitive   = true
}

resource "kubernetes_namespace_v1" "immich" {
  metadata {
    name = "immich"
  }
}

# 1. Create a Persistent Volume tied to w-01 and the Talos mount path
resource "kubernetes_persistent_volume_v1" "immich_data" {
  metadata {
    name = "immich-data-pv"
  }
  spec {
    capacity = {
      storage = "3Ti"
    }
    access_modes                     = ["ReadWriteMany"]
    persistent_volume_reclaim_policy = "Retain"
    storage_class_name               = "local-storage"

    persistent_volume_source {
      local {
        path = var.disk_mount_path
      }
    }

    node_affinity {
      required {
        node_selector_term {
          match_expressions {
            key      = "kubernetes.io/hostname"
            operator = "In"
            values   = [var.node_name]
          }
        }
      }
    }
  }
}

# 2. Create the Claim that Immich will use
resource "kubernetes_persistent_volume_claim_v1" "immich_data" {
  metadata {
    name      = "immich-data-pvc"
    namespace = kubernetes_namespace_v1.immich.metadata[0].name
  }
  spec {
    access_modes       = ["ReadWriteMany"]
    storage_class_name = "local-storage"
    resources {
      requests = {
        storage = "3Ti"
      }
    }
    volume_name = kubernetes_persistent_volume_v1.immich_data.metadata[0].name
  }
}

# 3. Deploy Immich via Helm
resource "helm_release" "immich" {
  name       = "immich"
  repository = "https://immich-app.github.io/immich-charts"
  chart      = "immich"
  namespace  = kubernetes_namespace_v1.immich.metadata[0].name
  version    = "0.10.3"
  wait       = false

  values = [
    yamlencode({
      # Root-level controllers for bjw-s common library
      controllers = {
        main = {
          containers = {
            main = {
              env = {
                DB_HOSTNAME      = var.db_hostname
                DB_PORT          = var.db_port
                DB_USERNAME      = var.db_username
                DB_PASSWORD      = var.db_password
                DB_DATABASE_NAME = var.db_name
                REDIS_HOSTNAME   = var.redis_hostname
                REDIS_PORT       = var.redis_port
              }
            }
          }
        }
      }
      immich = {
        persistence = {
          library = {
            enabled       = true
            existingClaim = kubernetes_persistent_volume_claim_v1.immich_data.metadata[0].name
          }
        }
      }
      server = {
        service = {
          main = {
            type = "LoadBalancer"
          }
        }
      }
    })
  ]
}
