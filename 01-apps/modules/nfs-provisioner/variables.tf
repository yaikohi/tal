variable "nfs_server" {
  description = "NFS server IP address or hostname"
  type        = string
}

variable "nfs_path" {
  description = "NFS export path"
  type        = string
}

variable "storage_class_name" {
  description = "Name of the default storage class"
  type        = string
  default     = "nfs"
}

variable "set_default_class" {
  description = "Set this storage class as default"
  type        = bool
  default     = true
}

variable "reclaim_policy" {
  description = "Reclaim policy for the storage class (Delete or Retain)"
  type        = string
  default     = "Retain"
}

variable "archive_on_delete" {
  description = "Archive PVCs on delete instead of deleting them"
  type        = bool
  default     = true
}

variable "depends_on_cilium" {
  description = "Dependency on Cilium module"
  type        = any
  default     = null
}
