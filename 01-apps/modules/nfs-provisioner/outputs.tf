output "namespace_name" {
  description = "Name of the immich namespace"
  value       = kubernetes_namespace_v1.immich.metadata[0].name
}

output "nfs_storage_class_name" {
  description = "Name of the default NFS storage class"
  value       = var.storage_class_name
}

output "nfs_rwx_storage_class_name" {
  description = "Name of the RWX storage class"
  value       = kubernetes_storage_class_v1.nfs_rwx.metadata[0].name
}

output "nfs_rwo_storage_class_name" {
  description = "Name of the RWO storage class"
  value       = kubernetes_storage_class_v1.nfs_rwo.metadata[0].name
}

output "nfs_server" {
  description = "NFS server address"
  value       = var.nfs_server
}

output "nfs_path" {
  description = "NFS export path"
  value       = var.nfs_path
}
