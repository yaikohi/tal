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
# module "test-workload" {
#   source     = "./modules/test-workload"
#   depends_on = [module.cilium]
# }

# 4. PostgreSQL for Immich
module "postgresql" {
  source              = "./modules/postgresql"
  persistence_enabled = false
  postgres_password   = "immich-postgres-password"
  db_username         = "immich"
  db_password         = "immich-password"
  db_name             = "immich"
  storage_class       = ""
  storage_size        = "1Gi"
  depends_on          = [module.cilium]
}

# 5. DragonflyDB for Immich
module "dragonflydb" {
  source              = "./modules/dragonflydb"
  persistence_enabled = false
  storage_size        = "10Gi"
  storage_class       = ""
  auth_enabled        = false
  depends_on          = [module.cilium]
}

# 6. Immich
module "immich" {
  source         = "./modules/immich"
  db_hostname    = module.postgresql.host
  db_port        = module.postgresql.port
  db_username    = module.postgresql.username
  db_password    = module.postgresql.password
  db_name        = module.postgresql.database
  redis_hostname = module.dragonflydb.host
  redis_port     = module.dragonflydb.port
  redis_password = module.dragonflydb.password
  depends_on     = [module.postgresql, module.dragonflydb]
}
