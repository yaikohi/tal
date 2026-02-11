variable "persistence_enabled" {
  description = "Enable persistent storage for DragonflyDB"
  type        = bool
  default     = true
}

variable "storage_size" {
  description = "Storage size for DragonflyDB persistence"
  type        = string
  default     = "10Gi"
}

variable "storage_class" {
  description = "Storage class for DragonflyDB persistence"
  type        = string
  default     = ""
}

variable "auth_enabled" {
  description = "Enable authentication for DragonflyDB"
  type        = bool
  default     = false
}

variable "password" {
  description = "Password for DragonflyDB (if auth enabled)"
  type        = string
  default     = ""
  sensitive   = true
}
