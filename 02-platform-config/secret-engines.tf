# Enables Key-Value `Version 2 Storage engine` at path 'apps'
resource "vault_mount" "kvv2" {
  path        = "apps"
  type        = "kv"
  options     = { version = "2" }
  description = "Encrypted storage path for Yaya Cluster workloads"
}
