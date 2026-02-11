# PostgreSQL for Immich with pgvecto.rs/vectors extension
resource "kubernetes_namespace_v1" "postgresql" {
  metadata {
    name = "postgresql"
  }
}

resource "helm_release" "postgresql" {
  name       = "postgresql"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "postgresql"
  namespace  = kubernetes_namespace_v1.postgresql.metadata[0].name
  version    = "18.2.3"

  values = [
    yamlencode({
      global = {
        security = {
          allowInsecureImages = true
        }
      }
      image = {
        repository = "pgvector/pgvector"
        tag        = "pg16"
      }
      auth = {
        enablePostgresUser = true
        postgresPassword   = var.postgres_password
        username           = var.db_username
        password           = var.db_password
        database           = var.db_name
      }
      primary = {
        persistence = {
          enabled      = var.persistence_enabled
          storageClass = var.storage_class
          size         = var.storage_size
        }
        # Create basic extensions for Immich
        initdb = {
          scripts = {
            "create-extensions.sql" = <<-EOT
              -- Create required extensions for Immich
              CREATE EXTENSION IF NOT EXISTS vector;
              CREATE EXTENSION IF NOT EXISTS cube;
              CREATE EXTENSION IF NOT EXISTS earthdistance;

              -- Grant necessary privileges to immich user
              GRANT ALL PRIVILEGES ON DATABASE ${var.db_name} TO ${var.db_username};
            EOT
          }
        }
      }
      metrics = {
        enabled = false
      }
    })
  ]
}

output "host" {
  value       = "${helm_release.postgresql.name}.${kubernetes_namespace_v1.postgresql.metadata[0].name}.svc.cluster.local"
  description = "PostgreSQL hostname for connecting within the cluster"
}

output "port" {
  value       = "5432"
  description = "PostgreSQL port"
}

output "database" {
  value       = var.db_name
  description = "Database name"
}

output "username" {
  value       = var.db_username
  description = "Database username"
}

output "password" {
  value       = var.db_password
  sensitive   = true
  description = "Database password"
}
