variable "nfs_server" {
  description = "NFS server IP address or hostname"
  type        = string
}

variable "nfs_path" {
  description = "NFS export path on the server"
  type        = string
}

variable "depends_on_cilium" {
  description = "Dependency on Cilium module"
  type        = any
  default     = null
}
